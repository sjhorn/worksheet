import 'package:flutter/painting.dart';

import '../../core/data/worksheet_data.dart';
import '../../core/geometry/layout_solver.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_format.dart';
import '../../core/models/cell_style.dart';
import '../../core/models/cell_value.dart';
import '../../core/models/freeze_config.dart';
import 'render_layer.dart';

/// Callback when the layer needs to be repainted.
typedef FrozenLayerNeedsPaintCallback = void Function();

/// Renders frozen (pinned) rows and columns.
///
/// Frozen panes are split into three regions:
/// 1. Corner: Frozen rows AND columns (fixed position)
/// 2. Frozen rows: Top strip (scrolls horizontally, fixed vertically)
/// 3. Frozen columns: Left strip (fixed horizontally, scrolls vertically)
///
/// This layer is painted on top of the content layer to ensure frozen
/// cells obscure scrolling content beneath them.
class FrozenLayer extends RenderLayer {
  FreezeConfig _freezeConfig;
  final WorksheetData data;
  final LayoutSolver layoutSolver;
  final FrozenLayerNeedsPaintCallback? onNeedsPaint;

  // Style configuration
  final Color backgroundColor;
  final Color gridlineColor;
  final Color separatorColor;
  final double separatorWidth;
  final Color defaultTextColor;
  final double defaultFontSize;
  final String defaultFontFamily;
  final double cellPadding;

  /// Device pixel ratio for crisp 1-physical-pixel lines on Retina displays.
  final double? devicePixelRatio;

  // Pre-allocated paints
  late final Paint _backgroundPaint;
  late final Paint _gridlinePaint;
  late final Paint _separatorPaint;
  late final Paint _cellBackgroundPaint;

  /// Creates a frozen layer.
  FrozenLayer({
    required FreezeConfig freezeConfig,
    required this.data,
    required this.layoutSolver,
    this.onNeedsPaint,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.gridlineColor = const Color(0xFFE0E0E0),
    this.separatorColor = const Color(0xFF9E9E9E),
    this.separatorWidth = 2.0,
    this.defaultTextColor = const Color(0xFF000000),
    this.defaultFontSize = 14.0,
    this.defaultFontFamily = 'Roboto',
    this.cellPadding = 4.0,
    this.devicePixelRatio,
  })  : _freezeConfig = freezeConfig,
        super(enabled: freezeConfig.hasFrozenPanes) {
    _initPaints();
  }

  void _initPaints() {
    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final gridlineWidth = devicePixelRatio != null && devicePixelRatio! > 1.0
        ? 1.0 / devicePixelRatio!
        : 1.0;

    _gridlinePaint = Paint()
      ..color = gridlineColor
      ..strokeWidth = gridlineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;

    _separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = separatorWidth
      ..style = PaintingStyle.stroke;

    _cellBackgroundPaint = Paint()..style = PaintingStyle.fill;
  }

  /// Frozen layers paint on top of content (order 4).
  @override
  int get order => 4;

  /// The current freeze configuration.
  FreezeConfig get freezeConfig => _freezeConfig;

  /// Updates the freeze configuration.
  void updateFreezeConfig(FreezeConfig config) {
    if (_freezeConfig == config) return;
    _freezeConfig = config;
    enabled = config.hasFrozenPanes;
    markNeedsPaint();
  }

  /// The height of frozen rows in pixels.
  double get frozenRowsHeight {
    if (!_freezeConfig.hasFrozenRows) return 0.0;
    double height = 0.0;
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      height += layoutSolver.getRowHeight(row);
    }
    return height;
  }

  /// The width of frozen columns in pixels.
  double get frozenColumnsWidth {
    if (!_freezeConfig.hasFrozenColumns) return 0.0;
    double width = 0.0;
    for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
      width += layoutSolver.getColumnWidth(col);
    }
    return width;
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled) return;

    final canvas = context.canvas;
    final viewportSize = context.viewportSize;
    final scrollOffset = context.scrollOffset;
    final zoom = context.zoom;

    // Calculate frozen dimensions at current zoom
    final frozenRowsH = frozenRowsHeight * zoom;
    final frozenColsW = frozenColumnsWidth * zoom;

    // Paint corner region (if both rows and columns are frozen)
    if (_freezeConfig.hasFrozenRows && _freezeConfig.hasFrozenColumns) {
      _paintCorner(
        canvas,
        Rect.fromLTWH(0, 0, frozenColsW, frozenRowsH),
        zoom,
      );
    }

    // Paint frozen rows (top strip, excluding corner)
    if (_freezeConfig.hasFrozenRows) {
      final rowsLeft = _freezeConfig.hasFrozenColumns ? frozenColsW : 0.0;
      _paintFrozenRows(
        canvas,
        Rect.fromLTWH(
          rowsLeft,
          0,
          viewportSize.width - rowsLeft,
          frozenRowsH,
        ),
        scrollOffset.dx,
        zoom,
      );
    }

    // Paint frozen columns (left strip, excluding corner)
    if (_freezeConfig.hasFrozenColumns) {
      final colsTop = _freezeConfig.hasFrozenRows ? frozenRowsH : 0.0;
      _paintFrozenColumns(
        canvas,
        Rect.fromLTWH(
          0,
          colsTop,
          frozenColsW,
          viewportSize.height - colsTop,
        ),
        scrollOffset.dy,
        zoom,
      );
    }

    // Draw separator lines
    _paintSeparators(canvas, viewportSize, frozenRowsH, frozenColsW);
  }

  void _paintCorner(Canvas canvas, Rect bounds, double zoom) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Paint cells in corner region
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
        final coord = CellCoordinate(row, col);
        final cellBounds = layoutSolver.getCellBounds(coord);
        final scaledBounds = Rect.fromLTWH(
          cellBounds.left * zoom,
          cellBounds.top * zoom,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );
        _paintCell(canvas, coord, scaledBounds, zoom);
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      0,
      _freezeConfig.frozenRows - 1,
      0,
      _freezeConfig.frozenColumns - 1,
      0,
      0,
      zoom,
    );

    canvas.restore();
  }

  void _paintFrozenRows(
    Canvas canvas,
    Rect bounds,
    double scrollX,
    double zoom,
  ) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Calculate visible column range
    final visibleColStart = layoutSolver.getColumnAt(scrollX);
    final visibleColEnd = layoutSolver.getColumnAt(
      scrollX + bounds.width / zoom,
    );

    final startCol = _freezeConfig.hasFrozenColumns
        ? _freezeConfig.frozenColumns
        : visibleColStart;
    final endCol = (visibleColEnd + 1).clamp(0, layoutSolver.columnCount - 1);

    // Paint cells
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      for (int col = startCol; col <= endCol; col++) {
        final coord = CellCoordinate(row, col);
        final cellBounds = layoutSolver.getCellBounds(coord);
        final scaledBounds = Rect.fromLTWH(
          (cellBounds.left - scrollX) * zoom + bounds.left,
          cellBounds.top * zoom,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );

        if (scaledBounds.right > bounds.left && scaledBounds.left < bounds.right) {
          _paintCell(canvas, coord, scaledBounds, zoom);
        }
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      0,
      _freezeConfig.frozenRows - 1,
      startCol,
      endCol,
      scrollX,
      0,
      zoom,
      offsetX: bounds.left,
    );

    canvas.restore();
  }

  void _paintFrozenColumns(
    Canvas canvas,
    Rect bounds,
    double scrollY,
    double zoom,
  ) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Calculate visible row range
    final visibleRowStart = layoutSolver.getRowAt(scrollY);
    final visibleRowEnd = layoutSolver.getRowAt(
      scrollY + bounds.height / zoom,
    );

    final startRow = _freezeConfig.hasFrozenRows
        ? _freezeConfig.frozenRows
        : visibleRowStart;
    final endRow = (visibleRowEnd + 1).clamp(0, layoutSolver.rowCount - 1);

    // Paint cells
    for (int row = startRow; row <= endRow; row++) {
      for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
        final coord = CellCoordinate(row, col);
        final cellBounds = layoutSolver.getCellBounds(coord);
        final scaledBounds = Rect.fromLTWH(
          cellBounds.left * zoom,
          (cellBounds.top - scrollY) * zoom + bounds.top,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );

        if (scaledBounds.bottom > bounds.top && scaledBounds.top < bounds.bottom) {
          _paintCell(canvas, coord, scaledBounds, zoom);
        }
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      startRow,
      endRow,
      0,
      _freezeConfig.frozenColumns - 1,
      0,
      scrollY,
      zoom,
      offsetY: bounds.top,
    );

    canvas.restore();
  }

  void _paintCell(
    Canvas canvas,
    CellCoordinate coord,
    Rect bounds,
    double zoom,
  ) {
    // Paint background
    final style = data.getStyle(coord);
    final bgColor = style?.backgroundColor;
    if (bgColor != null) {
      _cellBackgroundPaint.color = bgColor;
      canvas.drawRect(bounds, _cellBackgroundPaint);
    }

    // Paint content
    final value = data.getCell(coord);
    if (value != null && zoom >= 0.25) {
      final format = data.getFormat(coord);
      _paintCellContent(canvas, bounds, value, style, zoom, format);
    }
  }

  void _paintCellContent(
    Canvas canvas,
    Rect bounds,
    CellValue value,
    CellStyle? style,
    double zoom,
    CellFormat? format,
  ) {
    final mergedStyle = CellStyle.defaultStyle.merge(style);
    final text = format != null ? format.format(value) : value.displayValue;

    // Create text painter
    final textStyle = TextStyle(
      color: value.isError
          ? const Color(0xFFCC0000)
          : mergedStyle.textColor ?? defaultTextColor,
      fontSize: (mergedStyle.fontSize ?? defaultFontSize) * zoom,
      fontWeight: mergedStyle.fontWeight ?? FontWeight.normal,
      fontStyle: mergedStyle.fontStyle ?? FontStyle.normal,
      fontFamily: mergedStyle.fontFamily ?? defaultFontFamily,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '\u2026',
    );

    // Layout text
    final padding = cellPadding * zoom;
    final availableWidth = bounds.width - (padding * 2);
    textPainter.layout(maxWidth: availableWidth > 0 ? availableWidth : 0);

    // Calculate position
    final offset = _calculateTextOffset(bounds, textPainter, mergedStyle, padding);

    // Paint
    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, offset);
    canvas.restore();

    textPainter.dispose();
  }

  Offset _calculateTextOffset(
    Rect bounds,
    TextPainter textPainter,
    CellStyle style,
    double padding,
  ) {
    double dx;
    double dy;

    switch (style.textAlignment ?? CellTextAlignment.left) {
      case CellTextAlignment.left:
        dx = bounds.left + padding;
        break;
      case CellTextAlignment.center:
        dx = bounds.left + (bounds.width - textPainter.width) / 2;
        break;
      case CellTextAlignment.right:
        dx = bounds.right - padding - textPainter.width;
        break;
    }

    switch (style.verticalAlignment ?? CellVerticalAlignment.middle) {
      case CellVerticalAlignment.top:
        dy = bounds.top + padding;
        break;
      case CellVerticalAlignment.middle:
        dy = bounds.top + (bounds.height - textPainter.height) / 2;
        break;
      case CellVerticalAlignment.bottom:
        dy = bounds.bottom - padding - textPainter.height;
        break;
    }

    return Offset(dx, dy);
  }

  void _paintGridlines(
    Canvas canvas,
    Rect bounds,
    int startRow,
    int endRow,
    int startCol,
    int endCol,
    double scrollX,
    double scrollY,
    double zoom, {
    double offsetX = 0,
    double offsetY = 0,
  }) {
    final path = Path();

    // Vertical gridlines
    for (int col = startCol; col <= endCol + 1; col++) {
      final x = ((layoutSolver.getColumnLeft(col) - scrollX) * zoom + offsetX).roundToDouble();
      if (x >= bounds.left && x <= bounds.right) {
        path.moveTo(x, bounds.top);
        path.lineTo(x, bounds.bottom);
      }
    }

    // Horizontal gridlines
    for (int row = startRow; row <= endRow + 1; row++) {
      final y = ((layoutSolver.getRowTop(row) - scrollY) * zoom + offsetY).roundToDouble();
      if (y >= bounds.top && y <= bounds.bottom) {
        path.moveTo(bounds.left, y);
        path.lineTo(bounds.right, y);
      }
    }

    canvas.drawPath(path, _gridlinePaint);
  }

  void _paintSeparators(
    Canvas canvas,
    Size viewportSize,
    double frozenRowsH,
    double frozenColsW,
  ) {
    // Horizontal separator below frozen rows
    if (_freezeConfig.hasFrozenRows) {
      final y = frozenRowsH.roundToDouble();
      canvas.drawLine(
        Offset(0, y),
        Offset(viewportSize.width, y),
        _separatorPaint,
      );
    }

    // Vertical separator to the right of frozen columns
    if (_freezeConfig.hasFrozenColumns) {
      final x = frozenColsW.roundToDouble();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, viewportSize.height),
        _separatorPaint,
      );
    }
  }

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }
}
