import 'dart:ui' as ui;

import 'package:flutter/painting.dart' hide BorderStyle;

import '../../core/core.dart';
import '../../widgets/worksheet_theme.dart';
import '../painters/cell_border_renderer.dart';
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
  late final Paint _gridlinePaint;

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

    _gridlinePaint = Paint()
      ..color = gridlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          0 // hairline: always 1 device pixel regardless of zoom
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
    // Extend the tile by 1 worksheet pixel on the right and bottom edges.
    // This creates a guaranteed physical overlap with adjacent tiles so that
    // sub-pixel gaps (caused by fractional zoom scaling of the clip boundary
    // inside the recorded Picture) are always covered by the neighbouring
    // tile's opaque content.  Tiles are painted left-to-right, top-to-bottom,
    // so later tiles overwrite earlier tiles' margins.
    const overlap = 1.0;
    final extendedRect = ui.Rect.fromLTWH(
      0,
      0,
      bounds.width + overlap,
      bounds.height + overlap,
    );
    final canvas = Canvas(recorder, extendedRect);

    // Hard-clip to extended bounds — cullRect is only a performance hint, not
    // a clip.  Without this, cell backgrounds that straddle a tile boundary
    // overflow into the Picture and get composited on top of adjacent tiles,
    // hiding text in neighbouring cells.
    canvas.clipRect(extendedRect, doAntiAlias: false);

    // Fill extended background so the overlap margin is opaque white,
    // covering any sub-pixel gap at the tile seam.
    canvas.drawRect(extendedRect, _backgroundPaint);

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
    final tileLocalRect = ui.Rect.fromLTWH(
      0,
      0,
      tileBounds.width,
      tileBounds.height,
    );

    // Clamp cell range to valid bounds
    final maxRow = layoutSolver.rowCount - 1;
    final maxCol = layoutSolver.columnCount - 1;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = cellRange.endRow.clamp(0, maxRow);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = cellRange.endColumn.clamp(0, maxCol);

    // Expand column range so cells just outside the tile whose text spills
    // into the tile are rendered (content only, no background).
    const maxSpillColumns = 10;
    final expandedStartCol = (startCol - maxSpillColumns).clamp(0, maxCol);
    final expandedEndCol = (endCol + maxSpillColumns).clamp(0, maxCol);

    // Track merged anchors we've already drawn text for in this tile (once).
    final renderedAnchors = <CellCoordinate>{};

    for (var row = startRow; row <= endRow; row++) {
      for (var col = expandedStartCol; col <= expandedEndCol; col++) {
        final coord = CellCoordinate(row, col);
        final isExpansionZone = col < startCol || col > endCol;

        // For merged cells, resolve to the anchor so that every tile
        // overlapping the merge renders the anchor's content.
        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;

        if (isExpansionZone && data.getCell(renderCoord) == null) {
          if (region == null) continue;
        }

        // In the expansion zone, only process cells with values (for spillover).
        if (isExpansionZone && data.getCell(renderCoord) == null) continue;

        final cellBounds = layoutSolver.getCellBounds(renderCoord);

        // Convert to tile-local coordinates
        final localBounds = ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );

        // Skip background for expansion zone cells — their background
        // belongs to their own tile.
        if (!isExpansionZone) {
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
        }
      }
    }

    // Two passes: first render backgrounds, then content. Backgrounds must
    // be rendered before content to avoid text being covered by merged cells.
    for (var row = startRow; row <= endRow; row++) {
      for (var col = expandedStartCol; col <= expandedEndCol; col++) {
        final coord = CellCoordinate(row, col);
        final isExpansionZone = col < startCol || col > endCol;

        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;

        if (isExpansionZone && data.getCell(renderCoord) == null) {
          if (region == null) continue;
        }

        if (region != null) {
          if (renderedAnchors.contains(renderCoord)) continue;
          renderedAnchors.add(renderCoord);
        }

        final cellBounds = layoutSolver.getCellBounds(renderCoord);
        final localBounds = ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );

        // Render cell content (skip the cell being edited — the overlay
        // TextField renders its text instead).
        // Use full localBounds for text layout so text is positioned
        // relative to the merge region, but clip to tile bounds.
        if (shouldRenderText && editingRange?.contains(renderCoord) != true) {
          final value = data.getCell(renderCoord);
          if (value != null) {
            final style = data.getStyle(renderCoord);
            final format = data.getFormat(renderCoord);
            if (region != null) {
              // Clip merged cell content to tile boundary
              canvas.save();
              canvas.clipRect(tileLocalRect);
              _renderCellContent(
                canvas,
                localBounds,
                value,
                style,
                zoomBucket,
                format,
                textPainters,
                tileLocalRect: tileLocalRect,
                coord: renderCoord,
              );
              canvas.restore();
            } else {
              _renderCellContent(
                canvas,
                localBounds,
                value,
                style,
                zoomBucket,
                format,
                textPainters,
                tileLocalRect: tileLocalRect,
                coord: renderCoord,
              );
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

    CellBorderRenderer.renderBorders(
      canvas: canvas,
      borderPaint: _borderPaint,
      data: data,
      mergedCells: mergedCells,
      startRow: startRow,
      endRow: endRow,
      startCol: startCol,
      endCol: endCol,
      maxRow: maxRow,
      maxCol: maxCol,
      getBounds: (coord) {
        final cellBounds = layoutSolver.getCellBounds(coord);
        return ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );
      },
      widthScale: _getGridlineStrokeWidth(zoomBucket),
    );
  }

  void _renderCellContent(
    Canvas canvas,
    ui.Rect bounds,
    CellValue value,
    CellStyle? style,
    ZoomBucket zoomBucket,
    CellFormat? format,
    List<TextPainter> textPainters, {
    ui.Rect? tileLocalRect,
    CellCoordinate? coord,
  }) {
    final mergedStyle = CellStyle.defaultStyle.merge(style);
    final availableWidth = bounds.width - (cellPadding * 2);
    final wrapText = mergedStyle.wrapText == true;
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
      if (richText.length == 1 &&
          (richText.first.text == null || richText.first.text!.isEmpty)) {
        // Cell-level style: apply span's style to the display text
        textSpan = TextSpan(
          text: text,
          style: baseTextStyle.merge(richText.first.style),
        );
      } else {
        textSpan = TextSpan(style: baseTextStyle, children: richText);
      }
    } else {
      textSpan = TextSpan(text: text, style: baseTextStyle);
    }

    // For non-wrap cells, attempt spillover before falling back to ellipsis.
    if (!wrapText) {
      // Measure unconstrained text width
      final unconstrained = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: _toTextAlign(
          mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type),
        ),
        maxLines: 1,
      )..layout();
      final textWidth = unconstrained.width;

      if (textWidth <= availableWidth || availableWidth <= 0) {
        // Text fits — paint normally clipped to cell bounds.
        final offset = _calculateTextOffset(
          bounds,
          unconstrained,
          mergedStyle,
          value,
        );
        canvas.save();
        canvas.clipRect(bounds);
        unconstrained.paint(canvas, offset);
        canvas.restore();
        textPainters.add(unconstrained);
        return;
      }

      // Text overflows — compute spillover.
      final alignment =
          mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type);
      final maxCol = layoutSolver.columnCount - 1;

      final extent = SpilloverCalculator.compute(
        row: coord?.row ?? 0,
        column: coord?.column ?? 0,
        textWidth: textWidth,
        cellWidth: bounds.width,
        cellPadding: cellPadding,
        alignment: alignment,
        valueType: value.type,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        mergedCells: mergedCells,
        maxColumn: maxCol,
      );

      if (extent.showHashFill) {
        // Numeric/date/duration/boolean overflow → paint ######
        unconstrained.dispose();
        final hashPainter = TextPainter(
          text: TextSpan(text: '######', style: baseTextStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0.0);
        final offset = _calculateTextOffset(
          bounds,
          hashPainter,
          mergedStyle,
          value,
        );
        canvas.save();
        canvas.clipRect(bounds);
        hashPainter.paint(canvas, offset);
        canvas.restore();
        textPainters.add(hashPainter);
        return;
      }

      if (extent.hasSpillover) {
        // Compute spill bounds in tile-local coordinates.
        final spillLeft =
            layoutSolver.getColumnLeft(extent.startColumn) -
            _tileBoundsLeft(bounds, coord);
        final spillBounds = ui.Rect.fromLTWH(
          spillLeft,
          bounds.top,
          extent.totalWidth,
          bounds.height,
        );

        // Clip to intersection of spill bounds and tile rect.
        final clipRect = tileLocalRect != null
            ? spillBounds.intersect(tileLocalRect)
            : spillBounds;

        // Re-layout unconstrained text within the full spill width for
        // correct TextAlign positioning.
        unconstrained.dispose();
        final spillPainter =
            TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
              textAlign: _toTextAlign(alignment),
              maxLines: 1,
            )..layout(
              minWidth: extent.totalWidth - 2 * cellPadding,
              maxWidth: extent.totalWidth - 2 * cellPadding,
            );
        final offset = _calculateTextOffset(
          spillBounds,
          spillPainter,
          mergedStyle,
          value,
        );
        canvas.save();
        canvas.clipRect(clipRect);
        spillPainter.paint(canvas, offset);
        canvas.restore();
        textPainters.add(spillPainter);
        return;
      }

      // Blocked — fall through to ellipsis rendering.
      unconstrained.dispose();
    }

    // Wrapped text or blocked non-wrap: render with ellipsis / wrapping.
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: _toTextAlign(
        mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type),
      ),
      maxLines: wrapText ? null : 1,
      ellipsis: wrapText ? null : '\u2026',
    );

    final layoutWidth = availableWidth > 0 ? availableWidth : 0.0;
    textPainter.layout(
      minWidth: wrapText ? layoutWidth : 0,
      maxWidth: layoutWidth,
    );

    final offset = _calculateTextOffset(
      bounds,
      textPainter,
      mergedStyle,
      value,
    );

    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, offset);
    canvas.restore();

    textPainters.add(textPainter);
  }

  /// Computes the tile-local left offset for the given cell bounds and coord.
  /// For cells in the expansion zone, [bounds.left] is already tile-local.
  double _tileBoundsLeft(ui.Rect bounds, CellCoordinate? coord) {
    if (coord == null) return 0;
    // bounds.left is already tile-local (cellBounds.left - tileBounds.left),
    // so we recover tileBounds.left as cellBounds.left - bounds.left.
    return layoutSolver.getCellBounds(coord).left - bounds.left;
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
      // Draw at the exact integer worksheet position.  The paint uses a
      // hairline stroke (width 0) which always renders as exactly 1 device
      // pixel regardless of the canvas zoom transform — no invisible or
      // double-width gridlines at any zoom level.
      final x = layoutSolver.getColumnLeft(col) - tileBounds.left;
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
          final gapTop =
              (layoutSolver.getRowTop(gap.range.startRow) - tileBounds.top)
                  .roundToDouble();
          final gapBottom =
              (layoutSolver.getRowTop(gap.range.endRow + 1) - tileBounds.top)
                  .roundToDouble();
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
      final y = layoutSolver.getRowTop(row) - tileBounds.top;
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
          final gapLeft =
              (layoutSolver.getColumnLeft(gap.range.startColumn) -
                      tileBounds.left)
                  .roundToDouble();
          final gapRight =
              (layoutSolver.getColumnLeft(gap.range.endColumn + 1) -
                      tileBounds.left)
                  .roundToDouble();
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

    canvas.drawPath(path, _gridlinePaint);
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
  /// The value is chosen so that `strokeWidth * zoom_max_in_bucket < 1.0`,
  /// guaranteeing each gridline covers at most 1 screen pixel (no doubles).
  /// At lower zoom levels the worksheet-space value is larger to compensate
  /// for the scale-down; at higher levels it is smaller.
  double _getGridlineStrokeWidth(ZoomBucket zoomBucket) {
    switch (zoomBucket) {
      case ZoomBucket.tenth:
      case ZoomBucket.quarter:
        // Below 40% - gridlines hidden, but return value for completeness
        return 5.0;
      case ZoomBucket.forty:
        // 40-49% zoom: 2.0 * 0.49 = 0.98 screen px (≤ 1px)
        return 2.0;
      case ZoomBucket.half:
        // 50-99% zoom: 1.0 * 0.99 = 0.99 screen px (≤ 1px)
        return 1.0;
      case ZoomBucket.full:
        // 100-199% zoom: 1.0 * 1.0 = 1.0, 1.0 * 1.99 = 1.99 — can be 2px
        // at the high end, but 100% is the most common zoom and 1.0 gives
        // a clean single-pixel gridline there.
        return 1.0;
      case ZoomBucket.twoX:
        // 200-299% zoom: 0.5 * 2.99 = 1.495 — borderline, but visually
        // acceptable; thinner values risk invisible lines at 200%.
        return 0.5;
      case ZoomBucket.quadruple:
        // 300-400% zoom: 0.25 * 4.0 = 1.0 screen px (≤ 1px)
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
