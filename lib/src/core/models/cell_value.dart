import 'package:any_date/any_date.dart';
import 'package:flutter/foundation.dart';

/// The type of value stored in a cell.
enum CellValueType {
  text,
  number,
  boolean,
  formula,
  error,
  date,
  duration,
}

/// An immutable value that can be stored in a worksheet cell.
///
/// CellValue is a union type that can hold text, numbers, booleans,
/// formulas, errors, or dates. Use the named constructors to create
/// values of specific types.
@immutable
class CellValue {
  /// The type of this value.
  final CellValueType type;

  /// The raw value stored. Type depends on [type]:
  /// - text: String
  /// - number: double
  /// - boolean: bool
  /// - formula: String
  /// - error: String
  /// - date: DateTime
  final Object rawValue;

  const CellValue._(this.type, this.rawValue);

  /// Creates a text value.
  const CellValue.text(String value) : this._(CellValueType.text, value);

  /// Creates a numeric value.
  CellValue.number(num value) : this._(CellValueType.number, value.toDouble());

  /// Creates a boolean value.
  const CellValue.boolean(bool value) : this._(CellValueType.boolean, value);

  /// Creates a formula value.
  const CellValue.formula(String formula) : this._(CellValueType.formula, formula);

  /// Creates an error value.
  const CellValue.error(String error) : this._(CellValueType.error, error);

  /// Creates a date value.
  const CellValue.date(DateTime date) : this._(CellValueType.date, date);

  /// Creates a duration value.
  const CellValue.duration(Duration duration)
      : this._(CellValueType.duration, duration);

  /// Parses text into a [CellValue], detecting the type automatically.
  ///
  /// Detection order: empty → formula → boolean → number → duration → date → text.
  ///
  /// [allowFormulas]: set to false for clipboard paste (prevents `=` prefix
  /// being treated as a formula).
  ///
  /// [dateParser]: configures date format detection. Defaults to [AnyDate()]
  /// which handles ISO 8601 and common locale formats. Use
  /// [AnyDate.fromLocale] or [DateParserInfo] for custom format preferences.
  ///
  /// Returns null for empty or whitespace-only input.
  static CellValue? parse(
    String text, {
    bool allowFormulas = true,
    AnyDate? dateParser,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Formula
    if (allowFormulas && trimmed.startsWith('=')) {
      return CellValue.formula(trimmed);
    }

    // Boolean (case-insensitive)
    final upper = trimmed.toUpperCase();
    if (upper == 'TRUE') return const CellValue.boolean(true);
    if (upper == 'FALSE') return const CellValue.boolean(false);

    // Number (before date — any_date treats plain numbers as UNIX timestamps)
    final number = double.tryParse(trimmed);
    if (number != null) return CellValue.number(number);

    // Duration (before date — so "14:30" becomes a duration, not a time)
    final duration = DurationParser.tryParse(trimmed);
    if (duration != null) return CellValue.duration(duration);

    // Date
    final parser = dateParser ?? const AnyDate();
    final date = parser.tryParse(trimmed);
    if (date != null) return CellValue.date(date);

    // Text fallback
    return CellValue.text(trimmed);
  }

  /// Returns the display string for this value.
  String get displayValue {
    switch (type) {
      case CellValueType.text:
        return rawValue as String;
      case CellValueType.number:
        final num = rawValue as double;
        if (num == num.truncateToDouble()) {
          return num.toInt().toString();
        }
        return num.toString();
      case CellValueType.boolean:
        return (rawValue as bool) ? 'TRUE' : 'FALSE';
      case CellValueType.formula:
        return rawValue as String;
      case CellValueType.error:
        return rawValue as String;
      case CellValueType.date:
        final date = rawValue as DateTime;
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case CellValueType.duration:
        final d = rawValue as Duration;
        final negative = d.isNegative;
        final abs = d.abs();
        final h = abs.inHours;
        final m = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
        return '${negative ? '-' : ''}$h:$m:$s';
    }
  }

  /// Returns true if this is a text value.
  bool get isText => type == CellValueType.text;

  /// Returns true if this is a numeric value.
  bool get isNumber => type == CellValueType.number;

  /// Returns true if this is a boolean value.
  bool get isBoolean => type == CellValueType.boolean;

  /// Returns true if this is a formula.
  bool get isFormula => type == CellValueType.formula;

  /// Returns true if this is an error value.
  bool get isError => type == CellValueType.error;

  /// Returns true if this is a date value.
  bool get isDate => type == CellValueType.date;

  /// Returns true if this is a duration value.
  bool get isDuration => type == CellValueType.duration;

  /// Returns true if this numeric value is an integer.
  ///
  /// Only valid for number type values.
  bool get isInteger {
    if (type != CellValueType.number) return false;
    final num = rawValue as double;
    return num == num.truncateToDouble();
  }

  /// Returns this value as an int.
  ///
  /// Only valid for number type values.
  int get asInt {
    assert(type == CellValueType.number);
    return (rawValue as double).toInt();
  }

  /// Returns this value as a double.
  ///
  /// Only valid for number type values.
  double get asDouble {
    assert(type == CellValueType.number);
    return rawValue as double;
  }

  /// Returns this value as a DateTime.
  ///
  /// Only valid for date type values.
  DateTime get asDateTime {
    assert(type == CellValueType.date);
    return rawValue as DateTime;
  }

  /// Returns this value as a Duration.
  ///
  /// Only valid for duration type values.
  Duration get asDuration {
    assert(type == CellValueType.duration);
    return rawValue as Duration;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellValue && other.type == type && other.rawValue == rawValue;
  }

  @override
  int get hashCode => Object.hash(type, rawValue);

  @override
  String toString() {
    final typeName = type.name;
    return 'CellValue.$typeName($rawValue)';
  }
}

/// Parses duration strings in `H:mm:ss` or `H:mm` format.
///
/// Pattern: `^(-?)(\d+):(\d{2})(?::(\d{2}))?$`
///
/// Examples:
/// - `1:30:05` → Duration(hours: 1, minutes: 30, seconds: 5)
/// - `1:30` → Duration(hours: 1, minutes: 30)
/// - `-1:30:00` → negative duration
/// - `100:00:00` → 100 hours
///
/// Minutes and seconds must be 0–59 and zero-padded to 2 digits.
class DurationParser {
  DurationParser._();

  static final _pattern = RegExp(r'^(-?)(\d+):(\d{2})(?::(\d{2}))?$');

  /// Tries to parse [input] as a duration. Returns null if not matched.
  static Duration? tryParse(String input) {
    final match = _pattern.firstMatch(input);
    if (match == null) return null;

    final negative = match.group(1) == '-';
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    final secondsStr = match.group(4);
    final seconds = secondsStr != null ? int.parse(secondsStr) : 0;

    if (minutes > 59 || seconds > 59) return null;

    var duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    if (negative) duration = -duration;
    return duration;
  }
}
