import 'dart:ui';

import 'package:flutter/painting.dart';

import '../../core/geometry/layout_solver.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';

/// Configuration for selection rendering appearance.
class SelectionStyle {
  /// The fill color for selected cells.
  final Color fillColor;

  /// The border color for the selection outline.
  final Color borderColor;

  /// The border width for the selection outline.
  final double borderWidth;

  /// The fill color for the focus cell (active cell).
  final Color focusFillColor;

  /// The border color for the focus cell.
  final Color focusBorderColor;

  /// The border width for the focus cell.
  final double focusBorderWidth;

  const SelectionStyle({
    this.fillColor = const Color(0x220078D4),
    this.borderColor = const Color(0xFF0078D4),
    this.borderWidth = 1.0, // Thin like Excel
    this.focusFillColor = const Color(0x00000000),
    this.focusBorderColor = const Color(0xFF0078D4),
    this.focusBorderWidth = 1.0, // Thin like Excel
  });

  /// Default Excel-like selection style.
  static const SelectionStyle defaultStyle = SelectionStyle();
}

/// Renders selection overlays for worksheets.
///
/// Supports rendering:
/// - Single cell selection with focus border
/// - Range selection with fill and border
/// - Row/column header highlighting
class SelectionRenderer {
  /// The layout solver for cell positions.
  final LayoutSolver layoutSolver;

  /// The selection style configuration.
  final SelectionStyle style;

  // Pre-allocated paint objects for performance
  late final Paint _fillPaint;
  late final Paint _borderPaint;
  late final Paint _focusBorderPaint;

  /// Creates a selection renderer.
  SelectionRenderer({
    required this.layoutSolver,
    this.style = SelectionStyle.defaultStyle,
  }) {
    _fillPaint = Paint()
      ..color = style.fillColor
      ..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // Crisp 1px lines

    _focusBorderPaint = Paint()
      ..color = style.focusBorderColor
      ..strokeWidth = style.focusBorderWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // Crisp 1px lines
  }

  /// Paints the selection for a cell range.
  ///
  /// [canvas] is the canvas to paint on.
  /// [viewportOffset] is the scroll offset of the viewport.
  /// [zoom] is the current zoom level.
  /// [range] is the selected cell range.
  /// [focus] is the focus cell (active cell within the selection).
  void paintSelection({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required CellRange range,
    CellCoordinate? focus,
  }) {
    // Get the bounds of the selection in worksheet coordinates
    final bounds = layoutSolver.getRangeBounds(
      startRow: range.startRow,
      startColumn: range.startColumn,
      endRow: range.endRow,
      endColumn: range.endColumn,
    );

    // Convert to screen coordinates
    final screenBounds = Rect.fromLTRB(
      (bounds.left - viewportOffset.dx) * zoom,
      (bounds.top - viewportOffset.dy) * zoom,
      (bounds.right - viewportOffset.dx) * zoom,
      (bounds.bottom - viewportOffset.dy) * zoom,
    );

    // Draw selection fill
    canvas.drawRect(screenBounds, _fillPaint);

    // Draw selection border
    canvas.drawRect(screenBounds, _borderPaint);

    // Draw focus cell border if specified
    if (focus != null && range.contains(focus)) {
      _paintFocusCell(canvas, viewportOffset, zoom, focus);
    }
  }

  /// Paints just the focus cell (single cell selection).
  void paintSingleCell({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required CellCoordinate cell,
  }) {
    _paintFocusCell(canvas, viewportOffset, zoom, cell);
  }

  void _paintFocusCell(
    Canvas canvas,
    Offset viewportOffset,
    double zoom,
    CellCoordinate cell,
  ) {
    final cellBounds = layoutSolver.getCellBounds(cell);

    // Convert to screen coordinates
    final screenBounds = Rect.fromLTRB(
      (cellBounds.left - viewportOffset.dx) * zoom,
      (cellBounds.top - viewportOffset.dy) * zoom,
      (cellBounds.right - viewportOffset.dx) * zoom,
      (cellBounds.bottom - viewportOffset.dy) * zoom,
    );

    // Draw focus border (slightly inset to not overlap with selection border)
    final inset = style.borderWidth / 2;
    final focusRect = screenBounds.deflate(inset);
    canvas.drawRect(focusRect, _focusBorderPaint);
  }

  /// Paints row header highlight for selected rows.
  ///
  /// [startRow] and [endRow] define the selected row range.
  /// [headerWidth] is the width of the row header area.
  void paintRowHeaderHighlight({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required int startRow,
    required int endRow,
    required double headerWidth,
  }) {
    final top = layoutSolver.getRowTop(startRow);
    final bottom = layoutSolver.getRowEnd(endRow);

    final screenRect = Rect.fromLTRB(
      0,
      (top - viewportOffset.dy) * zoom,
      headerWidth,
      (bottom - viewportOffset.dy) * zoom,
    );

    canvas.drawRect(screenRect, _fillPaint);
  }

  /// Paints column header highlight for selected columns.
  ///
  /// [startColumn] and [endColumn] define the selected column range.
  /// [headerHeight] is the height of the column header area.
  void paintColumnHeaderHighlight({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required int startColumn,
    required int endColumn,
    required double headerHeight,
  }) {
    final left = layoutSolver.getColumnLeft(startColumn);
    final right = layoutSolver.getColumnEnd(endColumn);

    final screenRect = Rect.fromLTRB(
      (left - viewportOffset.dx) * zoom,
      0,
      (right - viewportOffset.dx) * zoom,
      headerHeight,
    );

    canvas.drawRect(screenRect, _fillPaint);
  }
}
