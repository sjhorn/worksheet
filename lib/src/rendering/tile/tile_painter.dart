import 'dart:ui' as ui;

import 'package:flutter/painting.dart' hide BorderStyle;

import '../../core/data/merged_cell_registry.dart';
import '../../core/data/worksheet_data.dart';
import '../../core/geometry/layout_solver.dart';
import '../../core/geometry/zoom_transformer.dart';
import '../../core/models/border_resolver.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../../core/models/cell_format.dart';
import '../../core/models/cell_style.dart';
import '../../core/models/cell_value.dart';
import '../../widgets/worksheet_theme.dart';
import '../painters/border_painter.dart';
import 'tile_coordinate.dart';
import 'tile_manager.dart';

/// Renders worksheet tiles to GPU-backed Pictures.
///
/// TilePainter implements [TileRenderer] to provide the actual cell and
/// gridline rendering for the tile-based rendering system. It supports
/// level-of-detail rendering based on zoom level for optimal performance.
class TilePainter implements TileRenderer {
  /// The worksheet data source.
  final WorksheetData data;

  /// The layout solver for cell positions.
  final LayoutSolver layoutSolver;

  /// Whether to render gridlines.
  final bool showGridlines;

  /// The gridline color.
  final Color gridlineColor;

  /// The default cell background color.
  final Color backgroundColor;

  /// The default text color.
  final Color defaultTextColor;

  /// The default font size.
  final double defaultFontSize;

  /// The default font family.
  final String defaultFontFamily;

  /// Cell padding in pixels.
  final double cellPadding;

  /// Device pixel ratio for true 1-physical-pixel gridlines on Retina displays.
  /// When null, uses logical pixels (strokeWidth = 1.0).
  /// When provided, adjusts strokeWidth to 1.0 / devicePixelRatio for crisp lines.
  final double? devicePixelRatio;

  /// Merged cell registry for merge-aware rendering.
  MergedCellRegistry? mergedCells;

  /// Cell range currently being edited, whose text should be skipped
  /// during tile rendering (the overlay TextField renders it instead).
  /// Covers the editing cell and any cells the editor expands into.
  CellRange? editingRange;

  // Pre-allocated paint objects for performance
  late final Paint _backgroundPaint;
  late final Paint _cellBackgroundPaint;
  late final Paint _borderPaint;

  /// Creates a tile painter.
  TilePainter({
    required this.data,
    required this.layoutSolver,
    this.showGridlines = true,
    this.gridlineColor = const Color(0xFFD4D4D4),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.defaultTextColor = const Color(0xFF000000),
    this.defaultFontSize = 14.0,
    this.defaultFontFamily = CellStyle.defaultFontFamily,
    this.cellPadding = 4.0,
    this.devicePixelRatio,
  }) {
    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    _cellBackgroundPaint = Paint()..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
  }

  @override
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  }) {
    final recorder = ui.PictureRecorder();
    // Use tile-local cullRect starting at (0,0), not absolute worksheet coordinates
    final localCullRect = ui.Rect.fromLTWH(0, 0, bounds.width, bounds.height);
    final canvas = Canvas(recorder, localCullRect);

    // Hard-clip to tile bounds — cullRect is only a performance hint, not a
    // clip.  Without this, cell backgrounds that straddle a tile boundary
    // overflow into the Picture and get composited on top of adjacent tiles,
    // hiding text in neighbouring cells.
    canvas.clipRect(localCullRect);

    // Fill background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      _backgroundPaint,
    );

    // Render gridlines FIRST (so cell backgrounds cover them, like Excel)
    if (showGridlines && _shouldRenderGridlines(zoomBucket)) {
      _renderGridlines(canvas, bounds, cellRange, zoomBucket);
    }

    // Render cells on top (backgrounds will cover gridlines where present)
    // Collect TextPainters for deferred disposal — disposing native Paragraph
    // resources before endRecording() can cause missing text on some backends.
    final textPainters = <TextPainter>[];
    _renderCells(canvas, bounds, cellRange, zoomBucket, textPainters);

    // Render borders on top of backgrounds and gridlines (Excel behavior)
    if (_shouldRenderGridlines(zoomBucket)) {
      _renderBorders(canvas, bounds, cellRange, zoomBucket);
    }

    final picture = recorder.endRecording();

    // Now safe to dispose TextPainters — picture has captured all draw commands
    for (final tp in textPainters) {
      tp.dispose();
    }

    return picture;
  }

  void _renderCells(
    Canvas canvas,
    ui.Rect tileBounds,
    CellRange cellRange,
    ZoomBucket zoomBucket,
    List<TextPainter> textPainters,
  ) {
    final shouldRenderText = _shouldRenderText(zoomBucket);
    final tileLocalRect = ui.Rect.fromLTWH(0, 0, tileBounds.width, tileBounds.height);

    // Clamp cell range to valid bounds
    final maxRow = layoutSolver.rowCount - 1;
    final maxCol = layoutSolver.columnCount - 1;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = cellRange.endRow.clamp(0, maxRow);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = cellRange.endColumn.clamp(0, maxCol);

    // Track which merged anchors we've already rendered in this tile,
    // so we don't render them multiple times.
    final renderedAnchors = <CellCoordinate>{};

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final coord = CellCoordinate(row, col);

        // For merged cells, resolve to the anchor so that every tile
        // overlapping the merge renders the anchor's content.
        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;

        // Skip if we've already rendered this merge anchor in this tile.
        if (region != null) {
          if (renderedAnchors.contains(renderCoord)) continue;
          renderedAnchors.add(renderCoord);
        }

        final cellBounds = layoutSolver.getCellBounds(renderCoord);

        // Convert to tile-local coordinates
        final localBounds = ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );

        // Skip if cell is outside tile bounds
        if (!_boundsIntersect(localBounds, tileLocalRect)) {
          continue;
        }

        // For merged cells that cross tile boundaries, clip to tile bounds
        final clippedBounds = region != null
            ? localBounds.intersect(tileLocalRect)
            : localBounds;

        // Render cell background (use clipped bounds for painting area)
        final style = data.getStyle(renderCoord);
        _renderCellBackground(canvas, clippedBounds, style);

        // Render cell content (skip the cell being edited — the overlay
        // TextField renders its text instead).
        // Use full localBounds for text layout so text is positioned
        // relative to the merge region, but clip to tile bounds.
        if (shouldRenderText && editingRange?.contains(renderCoord) != true) {
          final value = data.getCell(renderCoord);
          if (value != null) {
            final format = data.getFormat(renderCoord);
            if (region != null) {
              // Clip merged cell content to tile boundary
              canvas.save();
              canvas.clipRect(tileLocalRect);
              _renderCellContent(
                  canvas, localBounds, value, style, zoomBucket, format,
                  textPainters, coord: renderCoord);
              canvas.restore();
            } else {
              _renderCellContent(
                  canvas, localBounds, value, style, zoomBucket, format,
                  textPainters, coord: renderCoord);
            }
          }
        }
      }
    }
  }

  void _renderCellBackground(Canvas canvas, ui.Rect bounds, CellStyle? style) {
    final bgColor = style?.backgroundColor;
    if (bgColor != null) {
      _cellBackgroundPaint.color = bgColor;
      canvas.drawRect(bounds, _cellBackgroundPaint);
    }
  }

  void _renderBorders(
    Canvas canvas,
    ui.Rect tileBounds,
    CellRange cellRange,
    ZoomBucket zoomBucket,
  ) {
    final maxRow = layoutSolver.rowCount - 1;
    final maxCol = layoutSolver.columnCount - 1;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = cellRange.endRow.clamp(0, maxRow);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = cellRange.endColumn.clamp(0, maxCol);

    final strokeWidth = _getGridlineStrokeWidth(zoomBucket);

    final renderedBorderAnchors = <CellCoordinate>{};

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final coord = CellCoordinate(row, col);

        // For merged cells, resolve to anchor for border rendering.
        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;

        if (region != null) {
          if (renderedBorderAnchors.contains(renderCoord)) continue;
          renderedBorderAnchors.add(renderCoord);
        }

        final style = data.getStyle(renderCoord);
        final borders = style?.borders;
        if (borders == null || borders.isNone) continue;

        final cellBounds = layoutSolver.getCellBounds(renderCoord);
        final localBounds = ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );

        // Top border
        if (!borders.top.isNone) {
          final resolved = row > 0
              ? BorderResolver.resolve(
                  data.getStyle(CellCoordinate(row - 1, col))?.borders?.bottom ?? BorderStyle.none,
                  borders.top,
                )
              : borders.top;
          if (!resolved.isNone) {
            _borderPaint
              ..color = resolved.color
              ..strokeWidth = resolved.width * strokeWidth;
            final y = localBounds.top.roundToDouble() + 0.5;
            BorderPainter.drawBorderEdge(
              canvas,
              Offset(localBounds.left, y),
              Offset(localBounds.right, y),
              _borderPaint,
              resolved.lineStyle,
              resolved.width * strokeWidth,
            );
          }
        }

        // Bottom border
        if (!borders.bottom.isNone) {
          final resolved = row < maxRow
              ? BorderResolver.resolve(
                  borders.bottom,
                  data.getStyle(CellCoordinate(row + 1, col))?.borders?.top ?? BorderStyle.none,
                )
              : borders.bottom;
          if (!resolved.isNone) {
            _borderPaint
              ..color = resolved.color
              ..strokeWidth = resolved.width * strokeWidth;
            final y = localBounds.bottom.roundToDouble() + 0.5;
            BorderPainter.drawBorderEdge(
              canvas,
              Offset(localBounds.left, y),
              Offset(localBounds.right, y),
              _borderPaint,
              resolved.lineStyle,
              resolved.width * strokeWidth,
            );
          }
        }

        // Left border
        if (!borders.left.isNone) {
          final resolved = col > 0
              ? BorderResolver.resolve(
                  data.getStyle(CellCoordinate(row, col - 1))?.borders?.right ?? BorderStyle.none,
                  borders.left,
                )
              : borders.left;
          if (!resolved.isNone) {
            _borderPaint
              ..color = resolved.color
              ..strokeWidth = resolved.width * strokeWidth;
            final x = localBounds.left.roundToDouble() + 0.5;
            BorderPainter.drawBorderEdge(
              canvas,
              Offset(x, localBounds.top),
              Offset(x, localBounds.bottom),
              _borderPaint,
              resolved.lineStyle,
              resolved.width * strokeWidth,
            );
          }
        }

        // Right border
        if (!borders.right.isNone) {
          final resolved = col < maxCol
              ? BorderResolver.resolve(
                  borders.right,
                  data.getStyle(CellCoordinate(row, col + 1))?.borders?.left ?? BorderStyle.none,
                )
              : borders.right;
          if (!resolved.isNone) {
            _borderPaint
              ..color = resolved.color
              ..strokeWidth = resolved.width * strokeWidth;
            final x = localBounds.right.roundToDouble() + 0.5;
            BorderPainter.drawBorderEdge(
              canvas,
              Offset(x, localBounds.top),
              Offset(x, localBounds.bottom),
              _borderPaint,
              resolved.lineStyle,
              resolved.width * strokeWidth,
            );
          }
        }
      }
    }
  }

  void _renderCellContent(
    Canvas canvas,
    ui.Rect bounds,
    CellValue value,
    CellStyle? style,
    ZoomBucket zoomBucket,
    CellFormat? format,
    List<TextPainter> textPainters, {
    CellCoordinate? coord,
  }) {
    final mergedStyle = CellStyle.defaultStyle.merge(style);
    final availableWidth = bounds.width - (cellPadding * 2);
    final CellFormatResult? formatResult;
    final String text;
    if (format != null) {
      formatResult = format.formatRich(value, availableWidth: availableWidth);
      text = formatResult.text;
    } else {
      formatResult = null;
      text = value.displayValue;
    }

    // Base style from theme defaults — text appearance comes from rich text spans
    final baseTextStyle = TextStyle(
      color: formatResult?.color ?? _getBaseTextColor(value),
      fontSize: defaultFontSize,
      fontFamily: defaultFontFamily,
      package: WorksheetThemeData.resolveFontPackage(defaultFontFamily),
    );

    // Use rich text spans when available for inline styling
    final TextSpan textSpan;
    final richText = coord != null ? data.getRichText(coord) : null;
    if (richText != null && richText.isNotEmpty) {
      textSpan = TextSpan(style: baseTextStyle, children: richText);
    } else {
      textSpan = TextSpan(text: text, style: baseTextStyle);
    }

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: _toTextAlign(
          mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type)),
      maxLines: mergedStyle.wrapText == true ? null : 1,
      ellipsis: mergedStyle.wrapText == true ? null : '\u2026',
    );

    // Layout text within available width.
    // For wrapped text, set minWidth = maxWidth so TextPainter spans the full
    // cell width — this lets textAlign (center/right) align each line correctly.
    final layoutWidth = availableWidth > 0 ? availableWidth : 0.0;
    textPainter.layout(
      minWidth: mergedStyle.wrapText == true ? layoutWidth : 0,
      maxWidth: layoutWidth,
    );

    // Calculate position based on alignment
    final offset = _calculateTextOffset(bounds, textPainter, mergedStyle, value);

    // Clip to cell bounds and paint
    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, offset);
    canvas.restore();

    // Defer disposal — the PictureRecorder may reference the native Paragraph
    // until endRecording() finalizes the picture.
    textPainters.add(textPainter);
  }

  Color _getBaseTextColor(CellValue value) {
    // Error values are red by default
    if (value.isError) {
      return const Color(0xFFCC0000);
    }
    return defaultTextColor;
  }

  Offset _calculateTextOffset(
    ui.Rect bounds,
    TextPainter textPainter,
    CellStyle style,
    CellValue value,
  ) {
    double dx;
    double dy;

    // Horizontal alignment
    // For wrapped text, TextPainter handles per-line alignment via textAlign,
    // so always position at left + padding.
    if (style.wrapText == true) {
      dx = bounds.left + cellPadding;
    } else {
      switch (style.textAlignment ?? CellStyle.implicitAlignment(value.type)) {
        case CellTextAlignment.left:
          dx = bounds.left + cellPadding;
          break;
        case CellTextAlignment.center:
          dx = bounds.left + (bounds.width - textPainter.width) / 2;
          break;
        case CellTextAlignment.right:
          dx = bounds.right - cellPadding - textPainter.width;
          break;
      }
    }

    // Vertical alignment
    switch (style.verticalAlignment ?? CellVerticalAlignment.middle) {
      case CellVerticalAlignment.top:
        dy = bounds.top + cellPadding;
        break;
      case CellVerticalAlignment.middle:
        dy = bounds.top + (bounds.height - textPainter.height) / 2;
        break;
      case CellVerticalAlignment.bottom:
        dy = bounds.bottom - cellPadding - textPainter.height;
        break;
    }

    return Offset(dx, dy);
  }

  void _renderGridlines(
    Canvas canvas,
    ui.Rect tileBounds,
    CellRange cellRange,
    ZoomBucket zoomBucket,
  ) {
    final path = Path();

    // Clamp to valid bounds
    final maxRow = layoutSolver.rowCount;
    final maxCol = layoutSolver.columnCount;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = cellRange.endRow.clamp(0, maxRow - 1);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = cellRange.endColumn.clamp(0, maxCol - 1);

    // Collect merge regions intersecting this tile for gridline suppression.
    final mergeRegions = mergedCells != null && mergedCells!.regionCount > 0
        ? mergedCells!.regionsInRange(cellRange).toList()
        : const <MergeRegion>[];

    // Vertical gridlines - draw ONLY the left edge of each column
    // Do NOT draw trailing edges (they belong to the next tile's leading edge)
    // Skip col 0: its left edge is the worksheet's outer boundary, not a cell separator
    for (var col = startCol; col <= endCol; col++) {
      if (col == 0) continue;
      // +0.5 centers the 1px stroke on a pixel boundary so it covers exactly
      // one pixel row instead of straddling two (which Impeller renders as gray).
      final x = (layoutSolver.getColumnLeft(col) - tileBounds.left).roundToDouble() + 0.5;
      if (x < 0 || x > tileBounds.width) continue;

      // Find merge regions whose interior crosses this vertical line
      // (i.e., the merge spans across this column boundary).
      final gaps = <MergeRegion>[];
      for (final region in mergeRegions) {
        final r = region.range;
        if (r.startColumn < col && r.endColumn >= col) {
          gaps.add(region);
        }
      }

      if (gaps.isEmpty) {
        path.moveTo(x, 0);
        path.lineTo(x, tileBounds.height);
      } else {
        gaps.sort((a, b) => a.range.startRow.compareTo(b.range.startRow));
        var currentY = 0.0;
        for (final gap in gaps) {
          final gapTop = (layoutSolver.getRowTop(gap.range.startRow) - tileBounds.top).roundToDouble();
          final gapBottom = (layoutSolver.getRowTop(gap.range.endRow + 1) - tileBounds.top).roundToDouble();
          if (gapTop > currentY) {
            path.moveTo(x, currentY);
            path.lineTo(x, gapTop);
          }
          currentY = gapBottom;
        }
        if (currentY < tileBounds.height) {
          path.moveTo(x, currentY);
          path.lineTo(x, tileBounds.height);
        }
      }
    }

    // Horizontal gridlines - draw ONLY the top edge of each row
    // Do NOT draw trailing edges (they belong to the next tile's leading edge)
    // Skip row 0: its top edge is the worksheet's outer boundary, not a cell separator
    for (var row = startRow; row <= endRow; row++) {
      if (row == 0) continue;
      final y = (layoutSolver.getRowTop(row) - tileBounds.top).roundToDouble() + 0.5;
      if (y < 0 || y > tileBounds.height) continue;

      // Find merge regions whose interior crosses this horizontal line.
      final gaps = <MergeRegion>[];
      for (final region in mergeRegions) {
        final r = region.range;
        if (r.startRow < row && r.endRow >= row) {
          gaps.add(region);
        }
      }

      if (gaps.isEmpty) {
        path.moveTo(0, y);
        path.lineTo(tileBounds.width, y);
      } else {
        gaps.sort((a, b) => a.range.startColumn.compareTo(b.range.startColumn));
        var currentX = 0.0;
        for (final gap in gaps) {
          final gapLeft = (layoutSolver.getColumnLeft(gap.range.startColumn) - tileBounds.left).roundToDouble();
          final gapRight = (layoutSolver.getColumnLeft(gap.range.endColumn + 1) - tileBounds.left).roundToDouble();
          if (gapLeft > currentX) {
            path.moveTo(currentX, y);
            path.lineTo(gapLeft, y);
          }
          currentX = gapRight;
        }
        if (currentX < tileBounds.width) {
          path.moveTo(currentX, y);
          path.lineTo(tileBounds.width, y);
        }
      }
    }

    // Adjust stroke width based on zoom to keep gridlines visible
    // At low zoom levels, increase worksheet stroke width so it remains
    // visible when scaled down
    final strokeWidth = _getGridlineStrokeWidth(zoomBucket);

    final paint = Paint()
      ..color = gridlineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // Crisp lines like Excel

    canvas.drawPath(path, paint);
  }

  /// Determines whether gridlines should be rendered at the given zoom level.
  ///
  /// Gridlines are hidden below 40% zoom to reduce visual clutter and
  /// improve performance at low zoom levels.
  bool _shouldRenderGridlines(ZoomBucket zoomBucket) {
    switch (zoomBucket) {
      case ZoomBucket.tenth:
      case ZoomBucket.quarter:
        // Below 40% zoom - hide gridlines
        return false;
      case ZoomBucket.forty:
      case ZoomBucket.half:
      case ZoomBucket.full:
      case ZoomBucket.twoX:
      case ZoomBucket.quadruple:
        return true;
    }
  }

  /// Gets the gridline stroke width adjusted for the zoom bucket.
  ///
  /// At lower zoom levels, gridlines need to be thicker in worksheet
  /// coordinates to remain visible when scaled down.
  /// At higher zoom levels, gridlines need to be thinner so they don't
  /// appear too thick when scaled up.
  double _getGridlineStrokeWidth(ZoomBucket zoomBucket) {
    switch (zoomBucket) {
      case ZoomBucket.tenth:
      case ZoomBucket.quarter:
        // Below 40% - gridlines hidden, but return value for completeness
        return 5.0;
      case ZoomBucket.forty:
        // 40-49% zoom: need ~2x thicker lines
        return 2.0;
      case ZoomBucket.half:
        // 50-99% zoom: need ~1.5x thicker lines
        return 1.5;
      case ZoomBucket.full:
        // 100-199% zoom: 1px lines
        return 1.0;
      case ZoomBucket.twoX:
        // 200-299% zoom: need thinner lines (0.5 * 2 = 1px on screen)
        return 0.5;
      case ZoomBucket.quadruple:
        // 300-400% zoom: need even thinner lines (0.25 * 4 = 1px on screen)
        return 0.25;
    }
  }

  /// Determines whether text should be rendered at the given zoom level.
  ///
  /// At very low zoom levels, text is too small to read and rendering
  /// it wastes GPU resources.
  bool _shouldRenderText(ZoomBucket zoomBucket) {
    switch (zoomBucket) {
      case ZoomBucket.tenth:
        // 10-24% zoom - skip text entirely
        return false;
      case ZoomBucket.quarter:
      case ZoomBucket.forty:
      case ZoomBucket.half:
      case ZoomBucket.full:
      case ZoomBucket.twoX:
      case ZoomBucket.quadruple:
        return true;
    }
  }

  static TextAlign _toTextAlign(CellTextAlignment alignment) {
    switch (alignment) {
      case CellTextAlignment.left:
        return TextAlign.left;
      case CellTextAlignment.center:
        return TextAlign.center;
      case CellTextAlignment.right:
        return TextAlign.right;
    }
  }

  bool _boundsIntersect(ui.Rect a, ui.Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }
}
