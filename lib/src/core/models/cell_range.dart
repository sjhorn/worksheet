import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'cell_coordinate.dart';

/// An immutable rectangular range of cells in a worksheet.
///
/// The range is defined by its top-left ([startRow], [startColumn]) and
/// bottom-right ([endRow], [endColumn]) corners, inclusive.
@immutable
class CellRange {
  /// The starting row index (inclusive).
  final int startRow;

  /// The starting column index (inclusive).
  final int startColumn;

  /// The ending row index (inclusive).
  final int endRow;

  /// The ending column index (inclusive).
  final int endColumn;

  /// Creates a cell range from corner indices.
  ///
  /// The start indices must be less than or equal to the end indices.
  const CellRange(this.startRow, this.startColumn, this.endRow, this.endColumn)
      : assert(startRow >= 0, 'startRow must be non-negative'),
        assert(startColumn >= 0, 'startColumn must be non-negative'),
        assert(endRow >= startRow, 'endRow must be >= startRow'),
        assert(endColumn >= startColumn, 'endColumn must be >= startColumn');

  /// Creates a cell range from two coordinates, normalizing the order.
  ///
  /// The coordinates can be in any order; the range will be normalized
  /// so that [startRow] <= [endRow] and [startColumn] <= [endColumn].
  factory CellRange.fromCoordinates(CellCoordinate a, CellCoordinate b) {
    return CellRange(
      math.min(a.row, b.row),
      math.min(a.column, b.column),
      math.max(a.row, b.row),
      math.max(a.column, b.column),
    );
  }

  /// Creates a range containing only a single cell.
  factory CellRange.single(CellCoordinate coord) {
    return CellRange(coord.row, coord.column, coord.row, coord.column);
  }

  /// The number of rows in this range.
  int get rowCount => endRow - startRow + 1;

  /// The number of columns in this range.
  int get columnCount => endColumn - startColumn + 1;

  /// The total number of cells in this range.
  int get cellCount => rowCount * columnCount;

  /// The top-left corner of this range.
  CellCoordinate get topLeft => CellCoordinate(startRow, startColumn);

  /// The bottom-right corner of this range.
  CellCoordinate get bottomRight => CellCoordinate(endRow, endColumn);

  /// Returns true if [coord] is within this range.
  bool contains(CellCoordinate coord) {
    return coord.row >= startRow &&
        coord.row <= endRow &&
        coord.column >= startColumn &&
        coord.column <= endColumn;
  }

  /// Returns true if this range overlaps with [other].
  bool intersects(CellRange other) {
    return !(other.endRow < startRow ||
        other.startRow > endRow ||
        other.endColumn < startColumn ||
        other.startColumn > endColumn);
  }

  /// Returns the intersection of this range with [other], or null if they
  /// don't overlap.
  CellRange? intersection(CellRange other) {
    if (!intersects(other)) return null;

    return CellRange(
      math.max(startRow, other.startRow),
      math.max(startColumn, other.startColumn),
      math.min(endRow, other.endRow),
      math.min(endColumn, other.endColumn),
    );
  }

  /// Returns the smallest range that contains both this range and [other].
  CellRange union(CellRange other) {
    return CellRange(
      math.min(startRow, other.startRow),
      math.min(startColumn, other.startColumn),
      math.max(endRow, other.endRow),
      math.max(endColumn, other.endColumn),
    );
  }

  /// Returns a range expanded to include [coord].
  CellRange expand(CellCoordinate coord) {
    if (contains(coord)) return this;

    return CellRange(
      math.min(startRow, coord.row),
      math.min(startColumn, coord.column),
      math.max(endRow, coord.row),
      math.max(endColumn, coord.column),
    );
  }

  /// Iterates over all cells in this range, row by row.
  Iterable<CellCoordinate> get cells sync* {
    for (var row = startRow; row <= endRow; row++) {
      for (var col = startColumn; col <= endColumn; col++) {
        yield CellCoordinate(row, col);
      }
    }
  }

  /// Creates a copy with optionally modified fields.
  CellRange copyWith({
    int? startRow,
    int? startColumn,
    int? endRow,
    int? endColumn,
  }) {
    return CellRange(
      startRow ?? this.startRow,
      startColumn ?? this.startColumn,
      endRow ?? this.endRow,
      endColumn ?? this.endColumn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellRange &&
        other.startRow == startRow &&
        other.startColumn == startColumn &&
        other.endRow == endRow &&
        other.endColumn == endColumn;
  }

  @override
  int get hashCode => Object.hash(startRow, startColumn, endRow, endColumn);

  @override
  String toString() {
    final topLeftNotation = topLeft.toNotation();
    final bottomRightNotation = bottomRight.toNotation();
    return 'CellRange($topLeftNotation:$bottomRightNotation)';
  }
}
