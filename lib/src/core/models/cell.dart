import 'package:flutter/foundation.dart';

import 'cell_style.dart';
import 'cell_value.dart';

/// A worksheet cell combining a [CellValue] and [CellStyle].
///
/// Used for Map-like access on [SparseWorksheetData]:
///
/// ```dart
/// final data = SparseWorksheetData(
///   rowCount: 100,
///   columnCount: 10,
///   cells: {
///     CellCoordinate(0, 0): Cell.text('Name'),
///     CellCoordinate(1, 0): Cell.number(42, style: boldStyle),
///   },
/// );
///
/// data[CellCoordinate(2, 0)] = Cell.text('Bananas');
/// final cell = data[CellCoordinate(1, 0)];
/// ```
@immutable
class Cell {
  /// The cell's value, or null if the cell has no value.
  final CellValue? value;

  /// The cell's style, or null for the default style.
  final CellStyle? style;

  /// Creates a cell with an optional [value] and [style].
  const Cell({this.value, this.style});

  /// Creates a cell with a text value.
  Cell.text(String text, {this.style}) : value = CellValue.text(text);

  /// Creates a cell with a numeric value.
  Cell.number(num n, {this.style}) : value = CellValue.number(n);

  /// Creates a cell with a boolean value.
  Cell.boolean(bool b, {this.style}) : value = CellValue.boolean(b);

  /// Creates a cell with a formula.
  Cell.formula(String formula, {this.style})
    : value = CellValue.formula(formula);

  /// Creates a cell with a date value.
  Cell.date(DateTime date, {this.style}) : value = CellValue.date(date);

  /// Creates a cell with only a style (no value).
  const Cell.withStyle(CellStyle this.style) : value = null;

  /// Whether this cell has a value.
  bool get hasValue => value != null;

  /// Whether this cell has a style.
  bool get hasStyle => style != null;

  /// Whether this cell is completely empty (no value and no style).
  bool get isEmpty => value == null && style == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell && value == other.value && style == other.style;

  @override
  int get hashCode => Object.hash(value, style);

  @override
  String toString() => 'Cell(value: $value, style: $style)';
}

extension WorksheetString on String {
  Cell get text => Cell.text(this);
  Cell get number => Cell.number(double.parse(this));
  Cell get boolean => Cell.boolean(!(toLowerCase() != 'true' && this != '1'));
  Cell get formula => Cell.formula(this);
}
