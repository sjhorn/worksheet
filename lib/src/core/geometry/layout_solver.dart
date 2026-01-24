import 'dart:ui';

import '../models/cell_coordinate.dart';
import 'span_list.dart';

/// Converts between worksheet positions and cell indices.
///
/// LayoutSolver wraps row and column [SpanList]s to provide convenient
/// methods for calculating cell bounds, finding cells at positions,
/// and determining visible ranges.
class LayoutSolver {
  /// The row sizes and positions.
  final SpanList _rows;

  /// The column sizes and positions.
  final SpanList _columns;

  /// Creates a layout solver with the given row and column span lists.
  LayoutSolver({
    required SpanList rows,
    required SpanList columns,
  })  : _rows = rows,
        _columns = columns;

  /// The number of rows.
  int get rowCount => _rows.count;

  /// The number of columns.
  int get columnCount => _columns.count;

  /// The default row height.
  double get defaultRowHeight => _rows.defaultSize;

  /// The default column width.
  double get defaultColumnWidth => _columns.defaultSize;

  /// The total height of all rows.
  double get totalHeight => _rows.totalSize;

  /// The total width of all columns.
  double get totalWidth => _columns.totalSize;

  /// The total content size as a [Size].
  Size get totalSize => Size(totalWidth, totalHeight);

  /// Returns the bounds of the cell at [coord].
  Rect getCellBounds(CellCoordinate coord) {
    final left = _columns.positionAt(coord.column);
    final top = _rows.positionAt(coord.row);
    final width = _columns.sizeAt(coord.column);
    final height = _rows.sizeAt(coord.row);

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Returns the cell coordinate at the given [position], or null if
  /// the position is outside the content bounds.
  CellCoordinate? getCellAt(Offset position) {
    final row = getRowAt(position.dy);
    final column = getColumnAt(position.dx);

    if (row < 0 || column < 0) return null;

    return CellCoordinate(row, column);
  }

  /// Returns the row index at the given y [position], or -1 if invalid.
  int getRowAt(double position) {
    return _rows.indexAtPosition(position);
  }

  /// Returns the column index at the given x [position], or -1 if invalid.
  int getColumnAt(double position) {
    return _columns.indexAtPosition(position);
  }

  /// Returns the top y position of the given [row].
  double getRowTop(int row) {
    return _rows.positionAt(row);
  }

  /// Returns the left x position of the given [column].
  double getColumnLeft(int column) {
    return _columns.positionAt(column);
  }

  /// Returns the height of the given [row].
  double getRowHeight(int row) {
    return _rows.sizeAt(row);
  }

  /// Returns the bottom y position of the given [row].
  double getRowEnd(int row) {
    return _rows.positionAt(row) + _rows.sizeAt(row);
  }

  /// Returns the width of the given [column].
  double getColumnWidth(int column) {
    return _columns.sizeAt(column);
  }

  /// Returns the right x position of the given [column].
  double getColumnEnd(int column) {
    return _columns.positionAt(column) + _columns.sizeAt(column);
  }

  /// Sets the height of the given [row].
  void setRowHeight(int row, double height) {
    _rows.setSize(row, height);
  }

  /// Sets the width of the given [column].
  void setColumnWidth(int column, double width) {
    _columns.setSize(column, width);
  }

  /// Returns the range of visible rows for a viewport.
  ///
  /// [startY] is the top of the viewport, [height] is the viewport height.
  SpanRange getVisibleRows(double startY, double height) {
    return _rows.getRange(startY, startY + height);
  }

  /// Returns the range of visible columns for a viewport.
  ///
  /// [startX] is the left of the viewport, [width] is the viewport width.
  SpanRange getVisibleColumns(double startX, double width) {
    return _columns.getRange(startX, startX + width);
  }

  /// Returns the bounds of a cell range.
  Rect getRangeBounds({
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
  }) {
    final left = _columns.positionAt(startColumn);
    final top = _rows.positionAt(startRow);
    final right = _columns.positionAt(endColumn + 1);
    final bottom = _rows.positionAt(endRow + 1);

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
