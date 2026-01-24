import 'package:flutter/foundation.dart';

/// Immutable cell address representing a position in a worksheet.
///
/// Row and column indices are zero-based internally, but can be converted
/// to/from Excel-style notation (A1, B2, AA100) using [fromNotation] and
/// [toNotation].
@immutable
class CellCoordinate {
  /// The zero-based row index.
  final int row;

  /// The zero-based column index.
  final int column;

  /// Creates a cell coordinate with the given [row] and [column] indices.
  ///
  /// Both indices must be non-negative.
  const CellCoordinate(this.row, this.column)
      : assert(row >= 0, 'Row must be non-negative'),
        assert(column >= 0, 'Column must be non-negative');

  /// Creates a cell coordinate from Excel-style notation (e.g., "A1", "AB10").
  ///
  /// The notation consists of column letters followed by a row number.
  /// Column letters are case-insensitive. The row number is 1-based in
  /// notation but converted to 0-based internally.
  ///
  /// Throws [FormatException] if the notation is invalid.
  factory CellCoordinate.fromNotation(String notation) {
    if (notation.isEmpty) {
      throw FormatException('Cell notation cannot be empty');
    }

    final upper = notation.toUpperCase();
    final letterMatch = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(upper);

    if (letterMatch == null) {
      throw FormatException('Invalid cell notation: $notation');
    }

    final letters = letterMatch.group(1)!;
    final rowString = letterMatch.group(2)!;
    final rowNumber = int.parse(rowString);

    if (rowNumber < 1) {
      throw FormatException('Row number must be at least 1: $notation');
    }

    // Convert column letters to index (A=0, B=1, ..., Z=25, AA=26, ...)
    var columnIndex = 0;
    for (var i = 0; i < letters.length; i++) {
      columnIndex = columnIndex * 26 + (letters.codeUnitAt(i) - 64);
    }
    columnIndex--; // Convert from 1-based to 0-based

    return CellCoordinate(rowNumber - 1, columnIndex);
  }

  /// Converts this coordinate to Excel-style notation (e.g., "A1", "AB10").
  String toNotation() {
    // Convert column index to letters
    var col = column + 1; // Convert to 1-based for calculation
    final letters = StringBuffer();

    while (col > 0) {
      col--; // Adjust for 0-based calculation
      letters.write(String.fromCharCode(65 + (col % 26)));
      col ~/= 26;
    }

    // Reverse the letters (built from right to left)
    final columnLetters = letters.toString().split('').reversed.join();

    return '$columnLetters${row + 1}';
  }

  /// Returns a new coordinate offset by the given deltas.
  ///
  /// The resulting row and column are clamped to be non-negative.
  CellCoordinate offset(int rowDelta, int colDelta) {
    final newRow = (row + rowDelta).clamp(0, double.maxFinite.toInt());
    final newCol = (column + colDelta).clamp(0, double.maxFinite.toInt());
    return CellCoordinate(newRow, newCol);
  }

  /// Creates a copy with optionally modified fields.
  CellCoordinate copyWith({int? row, int? column}) {
    return CellCoordinate(
      row ?? this.row,
      column ?? this.column,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellCoordinate && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'CellCoordinate(${toNotation()})';
}
