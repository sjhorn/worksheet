import 'package:flutter/foundation.dart';

import 'cell_format.dart';
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
///     (0, 0): 'Name'.cell,
///     (0, 1): 'Amount'.cell,
///     (1, 0): Cell.number(42, style: boldStyle),
///   },
/// );
///
/// data[(2, 0)] = Cell.text('Bananas');
/// final cell = data[(1, 0)];
/// ```
@immutable
class Cell {
  /// The cell's value, or null if the cell has no value.
  final CellValue? value;

  /// The cell's style, or null for the default style.
  final CellStyle? style;

  /// The cell's display format, or null for General format.
  ///
  /// Controls how the [value] is displayed using Excel-style format codes:
  ///
  /// ```dart
  /// Cell.number(1234.56, format: CellFormat.currency)   // "$1,234.56"
  /// Cell.number(0.42, format: CellFormat.percentage)     // "42%"
  /// ```
  final CellFormat? format;

  /// Creates a cell with an optional [value], [style], and [format].
  const Cell({this.value, this.style, this.format});

  /// Creates a cell with a text value.
  Cell.text(String text, {this.style, this.format})
      : value = CellValue.text(text);

  /// Creates a cell with a numeric value.
  Cell.number(num n, {this.style, this.format})
      : value = CellValue.number(n);

  /// Creates a cell with a boolean value.
  Cell.boolean(bool b, {this.style, this.format})
      : value = CellValue.boolean(b);

  /// Creates a cell with a formula.
  Cell.formula(String formula, {this.style, this.format})
      : value = CellValue.formula(formula);

  /// Creates a cell with a date value.
  Cell.date(DateTime date, {this.style, this.format})
      : value = CellValue.date(date);

  /// Creates a cell with a duration value.
  Cell.duration(Duration duration, {this.style, this.format})
      : value = CellValue.duration(duration);

  /// Creates a cell with only a style (no value).
  const Cell.withStyle(CellStyle this.style)
      : value = null,
        format = null;

  /// Whether this cell has a value.
  bool get hasValue => value != null;

  /// Whether this cell has a style.
  bool get hasStyle => style != null;

  /// Whether this cell has a non-null format.
  bool get hasFormat => format != null;

  /// Whether this cell is completely empty (no value, style, or format).
  bool get isEmpty => value == null && style == null && format == null;

  /// The display string for this cell's value, using the [format] if present.
  ///
  /// Returns an empty string if the cell has no value.
  String get displayValue {
    if (value == null) return '';
    if (format != null) return format!.format(value!);
    return value!.displayValue;
  }

  /// Returns a copy of this cell with the given [format].
  Cell copyWithFormat(CellFormat? format) =>
      Cell(value: value, style: style, format: format);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          value == other.value &&
          style == other.style &&
          format == other.format;

  @override
  int get hashCode => Object.hash(value, style, format);

  @override
  String toString() => 'Cell(value: $value, style: $style, format: $format)';
}

extension WorksheetString on String {
  Cell get cell => Cell.text(this);
  Cell get formula => Cell.formula(this);
}

extension WorksheetNum on num {
  Cell get cell => Cell.number(this);
}

extension WorksheetBool on bool {
  Cell get cell => Cell.boolean(this);
}

extension WorksheetDate on DateTime {
  Cell get cell => Cell.date(this);
}

extension WorksheetDuration on Duration {
  Cell get cell => Cell.duration(this);
}
