import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'cell_value.dart';

/// The category of a cell format, aligned with Excel format categories.
enum CellFormatType {
  /// Default format: displays values using their natural representation.
  general,

  /// Numeric format with decimal places and thousands separators.
  number,

  /// Monetary values with currency symbols.
  currency,

  /// Accounting format: aligns currency symbols and decimal points.
  accounting,

  /// Date display formats.
  date,

  /// Time display formats.
  time,

  /// Percentage format: multiplies by 100 and appends %.
  percentage,

  /// Fraction display (e.g., 1/2, 3/4).
  fraction,

  /// Scientific/exponential notation.
  scientific,

  /// Treats content as plain text.
  text,

  /// Special formats (phone numbers, postal codes, etc.).
  special,

  /// User-defined custom format code.
  custom,
}

/// An immutable cell format that controls how a [CellValue] is displayed.
///
/// Uses Excel-style format codes to format values:
///
/// ```dart
/// // Static const presets
/// Cell.number(1234.56, format: CellFormat.currency)   // "$1,234.56"
/// Cell.number(0.42, format: CellFormat.percentage)     // "42%"
/// Cell.number(1234, format: CellFormat.integer)        // "1,234"
///
/// // Custom format codes
/// const myFormat = CellFormat(
///   type: CellFormatType.number,
///   formatCode: '#,##0.000',
/// );
/// ```
@immutable
class CellFormat {
  /// The format type category.
  final CellFormatType type;

  /// The Excel-style format code string.
  final String formatCode;

  /// Creates a cell format with the given [type] and [formatCode].
  const CellFormat({required this.type, required this.formatCode});

  // --- Static const presets ---

  /// General format: default display behaviour.
  static const general =
      CellFormat(type: CellFormatType.general, formatCode: 'General');

  /// Number with thousands separator, no decimals: 1,234
  static const integer =
      CellFormat(type: CellFormatType.number, formatCode: '#,##0');

  /// Number with 2 decimal places, no thousands: 1234.56
  static const decimal =
      CellFormat(type: CellFormatType.number, formatCode: '0.00');

  /// Number with thousands separator and 2 decimals: 1,234.56
  static const number =
      CellFormat(type: CellFormatType.number, formatCode: '#,##0.00');

  /// Currency: $1,234.56
  static const currency =
      CellFormat(type: CellFormatType.currency, formatCode: r'$#,##0.00');

  /// Percentage, no decimals: 42%
  static const percentage =
      CellFormat(type: CellFormatType.percentage, formatCode: '0%');

  /// Percentage with 2 decimals: 42.56%
  static const percentageDecimal =
      CellFormat(type: CellFormatType.percentage, formatCode: '0.00%');

  /// Scientific notation: 1.23E+04
  static const scientific =
      CellFormat(type: CellFormatType.scientific, formatCode: '0.00E+00');

  /// ISO date: 2024-01-15
  static const dateIso =
      CellFormat(type: CellFormatType.date, formatCode: 'yyyy-MM-dd');

  /// US date: 1/15/2024
  static const dateUs =
      CellFormat(type: CellFormatType.date, formatCode: 'm/d/yyyy');

  /// Short date: 15-Jan-24
  static const dateShort =
      CellFormat(type: CellFormatType.date, formatCode: 'd-mmm-yy');

  /// Month-year: Jan-24
  static const dateMonthYear =
      CellFormat(type: CellFormatType.date, formatCode: 'mmm-yy');

  /// 24-hour time: 14:30
  static const time24 =
      CellFormat(type: CellFormatType.time, formatCode: 'H:mm');

  /// 24-hour time with seconds: 14:30:05
  static const time24Seconds =
      CellFormat(type: CellFormatType.time, formatCode: 'H:mm:ss');

  /// 12-hour time: 2:30 PM
  static const time12 =
      CellFormat(type: CellFormatType.time, formatCode: 'h:mm AM/PM');

  /// Text pass-through.
  static const text =
      CellFormat(type: CellFormatType.text, formatCode: '@');

  /// Basic fraction: # ?/?
  static const fraction =
      CellFormat(type: CellFormatType.fraction, formatCode: '# ?/?');

  /// Formats a [CellValue] according to this format code.
  String format(CellValue value) => _CellFormatEngine.format(value, this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellFormat &&
          other.type == type &&
          other.formatCode == formatCode;

  @override
  int get hashCode => Object.hash(type, formatCode);

  @override
  String toString() => 'CellFormat(${type.name}, $formatCode)';
}

/// Internal formatting engine that applies Excel-style format codes.
class _CellFormatEngine {
  _CellFormatEngine._();

  static String format(CellValue value, CellFormat fmt) {
    if (fmt.type == CellFormatType.general) {
      return value.displayValue;
    }
    if (fmt.type == CellFormatType.text) {
      return value.rawValue.toString();
    }

    switch (value.type) {
      case CellValueType.number:
        return _formatNumber(value.rawValue as double, fmt);
      case CellValueType.date:
        return _formatDateTime(value.rawValue as DateTime, fmt);
      case CellValueType.text:
        return value.rawValue as String;
      case CellValueType.boolean:
        return (value.rawValue as bool) ? 'TRUE' : 'FALSE';
      case CellValueType.formula:
      case CellValueType.error:
        return value.displayValue;
    }
  }

  static String _formatNumber(double number, CellFormat fmt) {
    switch (fmt.type) {
      case CellFormatType.percentage:
        return _formatPercentage(number, fmt.formatCode);
      case CellFormatType.scientific:
        return _formatScientific(number, fmt.formatCode);
      case CellFormatType.currency:
        return _formatCurrency(number, fmt.formatCode);
      case CellFormatType.fraction:
        return _formatFraction(number);
      case CellFormatType.number:
      case CellFormatType.accounting:
      case CellFormatType.custom:
      case CellFormatType.special:
        return _formatNumericCode(number, fmt.formatCode);
      case CellFormatType.date:
      case CellFormatType.time:
        // Number treated as-is when format expects a date
        return _formatNumericCode(number, fmt.formatCode);
      default:
        return number.toString();
    }
  }

  /// Formats a number using a numeric format code like `#,##0`, `0.00`,
  /// `#,##0.00`.
  static String _formatNumericCode(double number, String code) {
    final isNegative = number < 0;
    final absNumber = number.abs();

    // Parse decimal places from format code
    final dotIndex = code.indexOf('.');
    int decimalPlaces = 0;
    if (dotIndex != -1) {
      final afterDot = code.substring(dotIndex + 1);
      decimalPlaces = afterDot.replaceAll(RegExp(r'[^0#?]'), '').length;
    }

    // Detect thousands separator
    final useThousands = code.contains(',');

    // Format the number
    var formatted = absNumber.toStringAsFixed(decimalPlaces);

    // Insert thousands separators
    if (useThousands) {
      final parts = formatted.split('.');
      parts[0] = _insertThousands(parts[0]);
      formatted = parts.join('.');
    }

    return isNegative ? '-$formatted' : formatted;
  }

  /// Inserts thousands separators into an integer string.
  static String _insertThousands(String integerPart) {
    if (integerPart.length <= 3) return integerPart;

    final result = <String>[];
    final chars = integerPart.split('').reversed.toList();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) result.add(',');
      result.add(chars[i]);
    }
    return result.reversed.join();
  }

  /// Formats a percentage value. Multiplies by 100 and appends %.
  static String _formatPercentage(double number, String code) {
    final percentage = number * 100;

    // Parse decimal places from code (before the % sign)
    final percentIndex = code.indexOf('%');
    final beforePercent =
        percentIndex > 0 ? code.substring(0, percentIndex) : code;
    final dotIndex = beforePercent.indexOf('.');
    int decimalPlaces = 0;
    if (dotIndex != -1) {
      decimalPlaces =
          beforePercent.substring(dotIndex + 1).replaceAll(RegExp(r'[^0#]'), '').length;
    }

    final formatted = percentage.toStringAsFixed(decimalPlaces);
    return '$formatted%';
  }

  /// Formats scientific notation: 0.00E+00
  static String _formatScientific(double number, String code) {
    // Parse decimal places
    final eIndex = code.toUpperCase().indexOf('E');
    int decimalPlaces = 2;
    if (eIndex > 0) {
      final beforeE = code.substring(0, eIndex);
      final dotIndex = beforeE.indexOf('.');
      if (dotIndex != -1) {
        decimalPlaces =
            beforeE.substring(dotIndex + 1).replaceAll(RegExp(r'[^0#]'), '').length;
      }
    }

    if (number == 0) {
      final zeros = '0' * decimalPlaces;
      return '0.${zeros}E+00';
    }

    final isNegative = number < 0;
    final absNumber = number.abs();
    final exponent = (math.log(absNumber) / math.ln10).floor();
    final mantissa = absNumber / math.pow(10, exponent);
    final mantissaStr = mantissa.toStringAsFixed(decimalPlaces);

    final expSign = exponent >= 0 ? '+' : '-';
    final expStr = exponent.abs().toString().padLeft(2, '0');

    final result = '${mantissaStr}E$expSign$expStr';
    return isNegative ? '-$result' : result;
  }

  /// Formats currency: extracts symbol, formats number part.
  static String _formatCurrency(double number, String code) {
    // Extract currency symbol (everything before the first # or 0)
    final firstDigitPlaceholder = code.indexOf(RegExp(r'[#0]'));
    final symbol =
        firstDigitPlaceholder > 0 ? code.substring(0, firstDigitPlaceholder) : '';

    // Extract the numeric format part
    final numericPart =
        firstDigitPlaceholder >= 0 ? code.substring(firstDigitPlaceholder) : code;

    final isNegative = number < 0;
    final formatted = _formatNumericCode(number.abs(), numericPart);

    return isNegative ? '-$symbol$formatted' : '$symbol$formatted';
  }

  /// Formats a number as a fraction: # ?/?
  static String _formatFraction(double number) {
    final isNegative = number < 0;
    final absNumber = number.abs();
    final intPart = absNumber.truncate();
    final fracPart = absNumber - intPart;

    if (fracPart < 0.0001) {
      final result = intPart.toString();
      return isNegative ? '-$result' : result;
    }

    // Find best fraction with small denominator (1-9)
    int bestNum = 0;
    int bestDen = 1;
    double bestError = double.infinity;

    for (int den = 1; den <= 9; den++) {
      final num = (fracPart * den).round();
      if (num > 0 && num <= den) {
        final error = (fracPart - num / den).abs();
        if (error < bestError) {
          bestError = error;
          bestNum = num;
          bestDen = den;
        }
      }
    }

    if (bestNum == 0) {
      final result = intPart.toString();
      return isNegative ? '-$result' : result;
    }

    // Simplify the fraction
    final gcd = _gcd(bestNum, bestDen);
    bestNum = bestNum ~/ gcd;
    bestDen = bestDen ~/ gcd;

    String result;
    if (intPart == 0) {
      result = '$bestNum/$bestDen';
    } else {
      result = '$intPart $bestNum/$bestDen';
    }
    return isNegative ? '-$result' : result;
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  // --- Date/Time formatting ---

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Formats a DateTime value using date/time format codes.
  static String _formatDateTime(DateTime date, CellFormat fmt) {
    var code = fmt.formatCode;

    // Determine AM/PM mode
    final hasAmPm =
        code.contains('AM/PM') || code.contains('am/pm') || code.contains('A/P');
    var hour = date.hour;
    String ampm = '';
    if (hasAmPm) {
      ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
    }

    // Replace tokens from longest to shortest to avoid partial matches.
    // Use placeholder substitution to prevent double-replacement.

    // Year
    code = code.replaceAll('yyyy', date.year.toString().padLeft(4, '0'));
    code = code.replaceAll('yy', (date.year % 100).toString().padLeft(2, '0'));

    // Month (full, abbreviated, 2-digit, 1-digit)
    // Must handle before single 'm' to avoid partial matches
    code = code.replaceAll('mmmm', _monthNames[date.month - 1]);
    code = code.replaceAll('mmm', _monthAbbr[date.month - 1]);

    // Day names (before numeric day replacement)
    code = code.replaceAll('dddd',
        _dayNames[date.weekday - 1]); // DateTime.weekday is 1=Mon
    code = code.replaceAll('ddd', _dayAbbr[date.weekday - 1]);

    // For 'MM' and 'm' — context determines month vs. minute.
    // In Excel: 'm' after 'h' or before 's' means minutes; otherwise month.
    // Our approach: for date formats, treat 'mm' and 'm' as month.
    // For time formats, treat them as minutes.
    if (fmt.type == CellFormatType.time) {
      // Time context: mm/m = minutes, H/h = hours, ss/s = seconds
      code = code.replaceAll('HH', date.hour.toString().padLeft(2, '0'));
      code = code.replaceAll(RegExp(r'(?<!H)H(?!H)'),
          date.hour.toString());
      code = code.replaceAll('hh', hour.toString().padLeft(2, '0'));
      code = code.replaceAll(RegExp(r'(?<!h)h(?!h)'), hour.toString());
      code = code.replaceAll('ss', date.second.toString().padLeft(2, '0'));
      code = code.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
      code = code.replaceAll('AM/PM', ampm);
      code = code.replaceAll('am/pm', ampm.toLowerCase());
    } else {
      // Date context: MM/m = month, dd/d = day
      code = code.replaceAll('MM', date.month.toString().padLeft(2, '0'));
      code = code.replaceAll('dd', date.day.toString().padLeft(2, '0'));
      // Single 'm' for month (no padding)
      code = code.replaceAll(RegExp(r'(?<!m)m(?!m)'), date.month.toString());
      // Single 'd' for day (no padding)
      code = code.replaceAll(RegExp(r'(?<!d)d(?!d)'), date.day.toString());

      // Handle time tokens in date formats (e.g., 'm/d/yyyy H:mm')
      if (code.contains('H') || code.contains('h')) {
        code = code.replaceAll('HH', date.hour.toString().padLeft(2, '0'));
        code = code.replaceAll(RegExp(r'(?<!H)H(?!H)'),
            date.hour.toString());
        code = code.replaceAll('hh', hour.toString().padLeft(2, '0'));
        code = code.replaceAll(RegExp(r'(?<!h)h(?!h)'), hour.toString());
        code = code.replaceAll('ss', date.second.toString().padLeft(2, '0'));
        code = code.replaceAll('AM/PM', ampm);
        code = code.replaceAll('am/pm', ampm.toLowerCase());
      }
    }

    return code;
  }
}
