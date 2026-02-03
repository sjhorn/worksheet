import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/data/worksheet_data.dart';
import '../../core/geometry/layout_solver.dart';
import '../../core/geometry/zoom_transformer.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../../core/models/cell_format.dart';
import '../../core/models/cell_style.dart';
import '../../core/models/cell_value.dart';
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

  /// Cell currently being edited, whose text should be skipped during
  /// tile rendering (the overlay TextField renders it instead).
  CellCoordinate? editingCell;

  // Pre-allocated paint objects for performance
  late final Paint _backgroundPaint;
  late final Paint _cellBackgroundPaint;

  /// Creates a tile painter.
  TilePainter({
    required this.data,
    required this.layoutSolver,
    this.showGridlines = true,
    this.gridlineColor = const Color(0xFFD0D0D0), // Light gray like Excel
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.defaultTextColor = const Color(0xFF000000),
    this.defaultFontSize = 14.0,
    this.defaultFontFamily = 'Roboto',
    this.cellPadding = 4.0,
  }) {
    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    _cellBackgroundPaint = Paint()..style = PaintingStyle.fill;
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

    // Clamp cell range to valid bounds
    final maxRow = layoutSolver.rowCount - 1;
    final maxCol = layoutSolver.columnCount - 1;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = cellRange.endRow.clamp(0, maxRow);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = cellRange.endColumn.clamp(0, maxCol);

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final coord = CellCoordinate(row, col);
        final cellBounds = layoutSolver.getCellBounds(coord);

        // Convert to tile-local coordinates
        final localBounds = ui.Rect.fromLTWH(
          cellBounds.left - tileBounds.left,
          cellBounds.top - tileBounds.top,
          cellBounds.width,
          cellBounds.height,
        );

        // Skip if cell is outside tile bounds
        if (!_boundsIntersect(localBounds, ui.Rect.fromLTWH(0, 0, tileBounds.width, tileBounds.height))) {
          continue;
        }

        // Render cell background
        final style = data.getStyle(coord);
        _renderCellBackground(canvas, localBounds, style);

        // Render cell content (skip the cell being edited — the overlay
        // TextField renders its text instead).
        if (shouldRenderText && coord != editingCell) {
          final value = data.getCell(coord);
          if (value != null) {
            final format = data.getFormat(coord);
            _renderCellContent(
                canvas, localBounds, value, style, zoomBucket, format,
                textPainters);
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

  void _renderCellContent(
    Canvas canvas,
    ui.Rect bounds,
    CellValue value,
    CellStyle? style,
    ZoomBucket zoomBucket,
    CellFormat? format,
    List<TextPainter> textPainters,
  ) {
    final mergedStyle = CellStyle.defaultStyle.merge(style);
    final text = format != null ? format.format(value) : value.displayValue;

    // Create text painter
    final textStyle = TextStyle(
      color: _getTextColor(value, mergedStyle),
      fontSize: mergedStyle.fontSize ?? defaultFontSize,
      fontWeight: mergedStyle.fontWeight ?? FontWeight.normal,
      fontStyle: mergedStyle.fontStyle ?? FontStyle.normal,
      fontFamily: mergedStyle.fontFamily ?? defaultFontFamily,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: mergedStyle.wrapText == true ? null : 1,
      ellipsis: mergedStyle.wrapText == true ? null : '\u2026',
    );

    // Layout text within available width
    final availableWidth = bounds.width - (cellPadding * 2);
    textPainter.layout(maxWidth: availableWidth > 0 ? availableWidth : 0);

    // Calculate position based on alignment
    final offset = _calculateTextOffset(bounds, textPainter, mergedStyle);

    // Clip to cell bounds and paint
    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, offset);
    canvas.restore();

    // Defer disposal — the PictureRecorder may reference the native Paragraph
    // until endRecording() finalizes the picture.
    textPainters.add(textPainter);
  }

  Color _getTextColor(CellValue value, CellStyle style) {
    // Error values are red by default
    if (value.isError) {
      return style.textColor ?? const Color(0xFFCC0000);
    }
    return style.textColor ?? defaultTextColor;
  }

  Offset _calculateTextOffset(
    ui.Rect bounds,
    TextPainter textPainter,
    CellStyle style,
  ) {
    double dx;
    double dy;

    // Horizontal alignment
    switch (style.textAlignment ?? CellTextAlignment.left) {
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

    // Clamp to valid bounds (columns can go to count for the trailing edge)
    final maxRow = layoutSolver.rowCount;
    final maxCol = layoutSolver.columnCount;
    final startRow = cellRange.startRow.clamp(0, maxRow);
    final endRow = (cellRange.endRow + 1).clamp(0, maxRow);
    final startCol = cellRange.startColumn.clamp(0, maxCol);
    final endCol = (cellRange.endColumn + 1).clamp(0, maxCol);

    // Vertical gridlines (column separators)
    for (var col = startCol; col <= endCol; col++) {
      final x = layoutSolver.getColumnLeft(col) - tileBounds.left;
      if (x >= 0 && x <= tileBounds.width) {
        path.moveTo(x, 0);
        path.lineTo(x, tileBounds.height);
      }
    }

    // Horizontal gridlines (row separators)
    for (var row = startRow; row <= endRow; row++) {
      final y = layoutSolver.getRowTop(row) - tileBounds.top;
      if (y >= 0 && y <= tileBounds.height) {
        path.moveTo(0, y);
        path.lineTo(tileBounds.width, y);
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

  bool _boundsIntersect(ui.Rect a, ui.Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }
}
