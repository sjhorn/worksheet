import 'dart:math' as math;
import 'dart:ui' show Color;

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

  /// Duration/elapsed time format (e.g., [h]:mm:ss).
  duration,

  /// User-defined custom format code.
  custom,
}

/// The result of formatting a [CellValue] with rich metadata.
///
/// Holds the formatted text and an optional color override from the format
/// code (e.g., `[Red]#,##0`).
@immutable
class CellFormatResult {
  /// The formatted text string.
  final String text;

  /// Optional color override from the format code (e.g., `[Red]`).
  ///
  /// When non-null, renderers should use this color instead of the default
  /// text color or style color.
  final Color? color;

  /// Creates a format result.
  const CellFormatResult(this.text, {this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellFormatResult &&
          other.text == text &&
          other.color == color;

  @override
  int get hashCode => Object.hash(text, color);

  @override
  String toString() =>
      color != null ? 'CellFormatResult($text, color=$color)' : 'CellFormatResult($text)';
}

/// Locale-specific formatting data for cell formats.
///
/// Controls month/day names, decimal/thousands separators, and currency
/// symbols used when formatting values. The `[$-LCID]` bracket code in
/// Excel format strings selects a locale by Windows LCID hex code.
///
/// Built-in locales: [enUs], [enGb], [deDe], [frFr], [jaJp], [zhCn].
@immutable
class FormatLocale {
  /// Full month names (January, February, ...).
  final List<String> monthNames;

  /// Abbreviated month names (Jan, Feb, ...).
  final List<String> monthAbbr;

  /// Full day names (Monday, Tuesday, ...).
  final List<String> dayNames;

  /// Abbreviated day names (Mon, Tue, ...).
  final List<String> dayAbbr;

  /// Decimal separator character (e.g., `.` or `,`).
  final String decimalSeparator;

  /// Thousands separator character (e.g., `,` or `.`).
  final String thousandsSeparator;

  /// Default currency symbol (e.g., `$`, `€`, `£`).
  final String currencySymbol;

  /// Whether day comes before month in numeric date formats (e.g., d/m/yyyy).
  ///
  /// Used by [DateFormatDetector] to resolve ambiguous date inputs like
  /// `01/02/2024` (Jan 2 in US, Feb 1 in UK).
  final bool dayFirst;

  /// Creates a format locale with the given parameters.
  const FormatLocale({
    required this.monthNames,
    required this.monthAbbr,
    required this.dayNames,
    required this.dayAbbr,
    this.decimalSeparator = '.',
    this.thousandsSeparator = ',',
    this.currencySymbol = r'$',
    this.dayFirst = false,
  });

  /// English (US) locale — the default.
  static const enUs = FormatLocale(
    monthNames: _enMonthNames,
    monthAbbr: _enMonthAbbr,
    dayNames: _enDayNames,
    dayAbbr: _enDayAbbr,
  );

  /// English (GB) locale.
  static const enGb = FormatLocale(
    monthNames: _enMonthNames,
    monthAbbr: _enMonthAbbr,
    dayNames: _enDayNames,
    dayAbbr: _enDayAbbr,
    currencySymbol: '£',
    dayFirst: true,
  );

  /// German (Germany) locale.
  static const deDe = FormatLocale(
    monthNames: [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ],
    monthAbbr: [
      'Jan', 'Feb', 'Mrz', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ],
    dayNames: [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
      'Freitag', 'Samstag', 'Sonntag',
    ],
    dayAbbr: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    decimalSeparator: ',',
    thousandsSeparator: '.',
    currencySymbol: '€',
    dayFirst: true,
  );

  /// French (France) locale.
  static const frFr = FormatLocale(
    monthNames: [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ],
    monthAbbr: [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ],
    dayNames: [
      'lundi', 'mardi', 'mercredi', 'jeudi',
      'vendredi', 'samedi', 'dimanche',
    ],
    dayAbbr: ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
    decimalSeparator: ',',
    thousandsSeparator: ' ',
    currencySymbol: '€',
    dayFirst: true,
  );

  /// Japanese locale.
  static const jaJp = FormatLocale(
    monthNames: [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ],
    monthAbbr: [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ],
    dayNames: [
      '月曜日', '火曜日', '水曜日', '木曜日',
      '金曜日', '土曜日', '日曜日',
    ],
    dayAbbr: ['月', '火', '水', '木', '金', '土', '日'],
    currencySymbol: '¥',
  );

  /// Chinese (Simplified) locale.
  static const zhCn = FormatLocale(
    monthNames: [
      '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月',
    ],
    monthAbbr: [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ],
    dayNames: [
      '星期一', '星期二', '星期三', '星期四',
      '星期五', '星期六', '星期日',
    ],
    dayAbbr: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
    currencySymbol: '¥',
  );

  /// Maps Windows LCID hex codes to built-in locales.
  static const _lcidMap = <String, FormatLocale>{
    '0409': enUs,
    '0809': enGb,
    '0407': deDe,
    '040C': frFr,
    '040c': frFr,
    '0411': jaJp,
    '0804': zhCn,
  };

  /// Looks up a locale by Windows LCID hex code (e.g., `"0409"` for en-US).
  ///
  /// Returns [enUs] if the code is not recognized.
  static FormatLocale fromLcid(String code) =>
      _lcidMap[code] ?? enUs;

  // Shared English name lists
  static const _enMonthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _enMonthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _enDayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _enDayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
///
/// ## Case sensitivity for `MM` vs `mm`
///
/// This implementation intentionally diverges from Excel for `MM`:
/// - `MM` — always month (padded), never ambiguous
/// - `mm` — context-sensitive: month when standalone, minute when adjacent
///   to hour or second tokens
///
/// This allows `yyyy-MM-dd HH:mm:ss` to work unambiguously, which is useful
/// for ISO 8601 formats. Excel treats all case variants identically.
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

  /// Short date with 4-digit year: 15-Jan-2024
  static const dateShortLong =
      CellFormat(type: CellFormatType.date, formatCode: 'd-mmm-yyyy');

  /// Full month name date: 15 January 2024
  static const dateLong =
      CellFormat(type: CellFormatType.date, formatCode: 'd mmmm yyyy');

  /// EU date with slashes: 15/1/2024
  static const dateEu =
      CellFormat(type: CellFormatType.date, formatCode: 'd/m/yyyy');

  /// US date with dashes: 1-15-2024
  static const dateUsDash =
      CellFormat(type: CellFormatType.date, formatCode: 'm-d-yyyy');

  /// EU date with dashes: 15-1-2024
  static const dateEuDash =
      CellFormat(type: CellFormatType.date, formatCode: 'd-m-yyyy');

  /// US date with dots: 1.15.2024
  static const dateUsDot =
      CellFormat(type: CellFormatType.date, formatCode: 'm.d.yyyy');

  /// EU date with dots: 15.1.2024
  static const dateEuDot =
      CellFormat(type: CellFormatType.date, formatCode: 'd.m.yyyy');

  /// US date zero-padded: 01/15/2024
  static const dateUsPadded =
      CellFormat(type: CellFormatType.date, formatCode: 'mm/dd/yyyy');

  /// EU date zero-padded: 15/01/2024
  static const dateEuPadded =
      CellFormat(type: CellFormatType.date, formatCode: 'dd/mm/yyyy');

  /// Year-month-day with abbreviated month: 2024-Jan-15
  static const dateYearMonthDay =
      CellFormat(type: CellFormatType.date, formatCode: 'yyyy-mmm-dd');

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

  /// Duration hours:minutes:seconds — 1:30:05
  static const duration =
      CellFormat(type: CellFormatType.duration, formatCode: '[h]:mm:ss');

  /// Duration hours:minutes — 1:30
  static const durationShort =
      CellFormat(type: CellFormatType.duration, formatCode: '[h]:mm');

  /// Duration minutes:seconds — 90:05
  static const durationMinSec =
      CellFormat(type: CellFormatType.duration, formatCode: '[m]:ss');

  /// Formats a [CellValue] according to this format code.
  ///
  /// Convenience wrapper around [formatRich] that returns just the text.
  String format(CellValue value) =>
      formatRich(value).text;

  /// Formats a [CellValue] with rich metadata including color overrides.
  ///
  /// When [availableWidth] is provided, `*X` repeat-fill characters will
  /// expand to fill the remaining space using estimated character widths.
  /// When null, `*X` renders as a single space.
  ///
  /// When [locale] is provided, month/day names and number separators use
  /// the given locale. Otherwise defaults to [FormatLocale.enUs].
  CellFormatResult formatRich(
    CellValue value, {
    double? availableWidth,
    FormatLocale? locale,
  }) =>
      _CellFormatEngine.formatRich(value, this,
          availableWidth: availableWidth, locale: locale);

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

/// Detects the date format a user typed by round-tripping through candidates.
///
/// Given the raw input text and the parsed [DateTime], formats the date through
/// each candidate [CellFormat] and returns the first one whose output matches
/// the original input. Returns `null` if no candidate matches.
///
/// The [dayFirst] flag (from [FormatLocale.dayFirst]) controls whether
/// day-first (EU) or month-first (US) numeric formats are tried first,
/// resolving ambiguous inputs like `01/02/2024`.
class DateFormatDetector {
  DateFormatDetector._();

  /// Candidate formats ordered from most specific to most general.
  ///
  /// When [dayFirst] is true, EU variants (d/m, d-m, d.m) appear before
  /// their US counterparts.
  static List<CellFormat> _candidates({required bool dayFirst}) {
    if (dayFirst) {
      return const [
        CellFormat.dateIso,           // yyyy-MM-dd
        CellFormat.dateYearMonthDay,  // yyyy-mmm-dd
        CellFormat.dateShort,         // d-mmm-yy
        CellFormat.dateShortLong,     // d-mmm-yyyy
        CellFormat.dateLong,          // d mmmm yyyy
        CellFormat.dateEuPadded,      // dd/mm/yyyy
        CellFormat.dateEu,            // d/m/yyyy
        CellFormat.dateUsPadded,      // mm/dd/yyyy
        CellFormat.dateUs,            // m/d/yyyy
        CellFormat.dateEuDash,        // d-m-yyyy
        CellFormat.dateUsDash,        // m-d-yyyy
        CellFormat.dateEuDot,         // d.m.yyyy
        CellFormat.dateUsDot,         // m.d.yyyy
      ];
    }
    return const [
      CellFormat.dateIso,           // yyyy-MM-dd
      CellFormat.dateYearMonthDay,  // yyyy-mmm-dd
      CellFormat.dateShort,         // d-mmm-yy
      CellFormat.dateShortLong,     // d-mmm-yyyy
      CellFormat.dateLong,          // d mmmm yyyy
      CellFormat.dateUsPadded,      // mm/dd/yyyy
      CellFormat.dateUs,            // m/d/yyyy
      CellFormat.dateEuPadded,      // dd/mm/yyyy
      CellFormat.dateEu,            // d/m/yyyy
      CellFormat.dateUsDash,        // m-d-yyyy
      CellFormat.dateEuDash,        // d-m-yyyy
      CellFormat.dateUsDot,         // m.d.yyyy
      CellFormat.dateEuDot,         // d.m.yyyy
    ];
  }

  /// Detects the [CellFormat] that reproduces [input] when applied to [parsed].
  ///
  /// Returns `null` if no candidate matches (cell uses ISO default).
  static CellFormat? detect(
    String input,
    DateTime parsed, {
    bool dayFirst = false,
    FormatLocale locale = FormatLocale.enUs,
  }) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final candidate in _candidates(dayFirst: dayFirst)) {
      final formatted = candidate
          .formatRich(CellValue.date(parsed), locale: locale)
          .text
          .toLowerCase();
      if (formatted == normalized) return candidate;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Bracket metadata types
// ---------------------------------------------------------------------------

/// A condition parsed from a bracket code like `[>100]`.
class _Condition {
  final String operator;
  final double threshold;
  const _Condition(this.operator, this.threshold);

  bool evaluate(double value) {
    switch (operator) {
      case '>':
        return value > threshold;
      case '<':
        return value < threshold;
      case '>=':
        return value >= threshold;
      case '<=':
        return value <= threshold;
      case '=':
        return value == threshold;
      case '<>':
        return value != threshold;
      default:
        return false;
    }
  }
}

/// Metadata extracted from bracket codes at the start of a format section.
class _SectionMetadata {
  final Color? color;
  final _Condition? condition;
  final String? localeCode;
  final String? currencySymbol;
  final String cleanedPattern;

  const _SectionMetadata({
    this.color,
    this.condition,
    this.localeCode,
    this.currencySymbol,
    required this.cleanedPattern,
  });
}

// ---------------------------------------------------------------------------
// Excel color palette
// ---------------------------------------------------------------------------

/// The 8 named Excel format colors.
const _namedColors = <String, Color>{
  'black': Color(0xFF000000),
  'blue': Color(0xFF0000FF),
  'cyan': Color(0xFF00FFFF),
  'green': Color(0xFF008000),
  'magenta': Color(0xFFFF00FF),
  'red': Color(0xFFFF0000),
  'white': Color(0xFFFFFFFF),
  'yellow': Color(0xFFFFFF00),
};

/// The standard Excel 56-color palette (Color1 through Color56).
const _indexedColors = <Color>[
  Color(0xFF000000), // 1
  Color(0xFFFFFFFF), // 2
  Color(0xFFFF0000), // 3
  Color(0xFF00FF00), // 4
  Color(0xFF0000FF), // 5
  Color(0xFFFFFF00), // 6
  Color(0xFFFF00FF), // 7
  Color(0xFF00FFFF), // 8
  Color(0xFF800000), // 9
  Color(0xFF008000), // 10
  Color(0xFF000080), // 11
  Color(0xFF808000), // 12
  Color(0xFF800080), // 13
  Color(0xFF008080), // 14
  Color(0xFFC0C0C0), // 15
  Color(0xFF808080), // 16
  Color(0xFF9999FF), // 17
  Color(0xFF993366), // 18
  Color(0xFFFFFFCC), // 19
  Color(0xFFCCFFFF), // 20
  Color(0xFF660066), // 21
  Color(0xFFFF8080), // 22
  Color(0xFF0066CC), // 23
  Color(0xFFCCCCFF), // 24
  Color(0xFF000080), // 25
  Color(0xFFFF00FF), // 26
  Color(0xFFFFFF00), // 27
  Color(0xFF00FFFF), // 28
  Color(0xFF800080), // 29
  Color(0xFF800000), // 30
  Color(0xFF008080), // 31
  Color(0xFF0000FF), // 32
  Color(0xFF00CCFF), // 33
  Color(0xFFCCFFFF), // 34
  Color(0xFFCCFFCC), // 35
  Color(0xFFFFFF99), // 36
  Color(0xFF99CCFF), // 37
  Color(0xFFFF99CC), // 38
  Color(0xFFCC99FF), // 39
  Color(0xFFFFCC99), // 40
  Color(0xFF3366FF), // 41
  Color(0xFF33CCCC), // 42
  Color(0xFF99CC00), // 43
  Color(0xFFFFCC00), // 44
  Color(0xFFFF9900), // 45
  Color(0xFFFF6600), // 46
  Color(0xFF666699), // 47
  Color(0xFF969696), // 48
  Color(0xFF003366), // 49
  Color(0xFF339966), // 50
  Color(0xFF003300), // 51
  Color(0xFF333300), // 52
  Color(0xFF993300), // 53
  Color(0xFF993366), // 54
  Color(0xFF333399), // 55
  Color(0xFF333333), // 56
];

// ---------------------------------------------------------------------------
// Internal formatting engine
// ---------------------------------------------------------------------------

/// Internal formatting engine that applies Excel-style format codes.
class _CellFormatEngine {
  _CellFormatEngine._();

  static CellFormatResult formatRich(
    CellValue value,
    CellFormat fmt, {
    double? availableWidth,
    FormatLocale? locale,
  }) {
    final loc = locale ?? FormatLocale.enUs;

    if (fmt.type == CellFormatType.general) {
      return CellFormatResult(value.displayValue);
    }
    if (fmt.type == CellFormatType.text) {
      return CellFormatResult(value.rawValue.toString());
    }

    switch (value.type) {
      case CellValueType.number:
        return _formatNumberRich(
            value.rawValue as double, fmt, availableWidth, loc);
      case CellValueType.date:
        return CellFormatResult(
            _formatDateTime(value.rawValue as DateTime, fmt, loc));
      case CellValueType.duration:
        return CellFormatResult(_formatDuration(value.rawValue as Duration, fmt));
      case CellValueType.text:
        if (fmt.type == CellFormatType.number ||
            fmt.type == CellFormatType.currency ||
            fmt.type == CellFormatType.accounting) {
          return CellFormatResult(
              _formatTextSection(value.rawValue as String, fmt.formatCode, availableWidth));
        }
        return CellFormatResult(value.rawValue as String);
      case CellValueType.boolean:
        return CellFormatResult((value.rawValue as bool) ? 'TRUE' : 'FALSE');
      case CellValueType.formula:
      case CellValueType.error:
        return CellFormatResult(value.displayValue);
    }
  }

  static CellFormatResult _formatNumberRich(
    double number,
    CellFormat fmt,
    double? availableWidth,
    FormatLocale locale,
  ) {
    switch (fmt.type) {
      case CellFormatType.percentage:
        return CellFormatResult(_formatPercentage(number, fmt.formatCode, locale));
      case CellFormatType.scientific:
        return CellFormatResult(_formatScientific(number, fmt.formatCode));
      case CellFormatType.fraction:
        return CellFormatResult(_formatFraction(number, fmt.formatCode));
      case CellFormatType.number:
      case CellFormatType.currency:
      case CellFormatType.accounting:
        return _formatWithSections(number, fmt.formatCode, availableWidth, locale);
      case CellFormatType.custom:
      case CellFormatType.special:
        return CellFormatResult(_formatNumericCode(number, fmt.formatCode, locale));
      case CellFormatType.date:
      case CellFormatType.time:
        return CellFormatResult(_formatNumericCode(number, fmt.formatCode, locale));
      case CellFormatType.duration:
      case CellFormatType.general:
      case CellFormatType.text:
        return CellFormatResult(number.toString());
    }
  }

  /// Formats a number using a numeric format code like `#,##0`, `0.00`,
  /// `#,##0.00`.
  static String _formatNumericCode(
    double number,
    String code,
    FormatLocale locale,
  ) {
    final isNegative = number < 0;
    final absNumber = number.abs();

    // Detect comma-as-scaler: trailing commas after the last digit placeholder
    final scalerResult = _detectCommaScaler(code);
    final scaledNumber = absNumber / math.pow(1000, scalerResult.scalerCount);
    final cleanCode = scalerResult.cleanedCode;

    // Parse decimal places from format code
    final dotIndex = cleanCode.indexOf('.');
    int decimalPlaces = 0;
    if (dotIndex != -1) {
      final afterDot = cleanCode.substring(dotIndex + 1);
      decimalPlaces = afterDot.replaceAll(RegExp(r'[^0#?]'), '').length;
    }

    // Detect thousands separator (comma that is NOT a scaler)
    final useThousands = cleanCode.contains(',');

    // Format the number
    var formatted = scaledNumber.toStringAsFixed(decimalPlaces);

    // Insert thousands separators
    if (useThousands) {
      final parts = formatted.split('.');
      parts[0] = _insertThousands(parts[0], locale.thousandsSeparator);
      formatted = parts.join(locale.decimalSeparator);
    } else if (dotIndex != -1 && locale.decimalSeparator != '.') {
      formatted = formatted.replaceFirst('.', locale.decimalSeparator);
    }

    return isNegative ? '-$formatted' : formatted;
  }

  /// Detects trailing comma scalers in a format code.
  ///
  /// In Excel, commas after the last digit placeholder (`0`, `#`, `?`) scale
  /// the number by dividing by 1000 per comma. E.g., `#,##0,` divides by
  /// 1000; `#,##0,,` divides by 1,000,000.
  static ({int scalerCount, String cleanedCode}) _detectCommaScaler(String code) {
    // Find the position of the last digit placeholder
    var lastDigitPos = -1;
    for (var i = code.length - 1; i >= 0; i--) {
      if (code[i] == '0' || code[i] == '#' || code[i] == '?') {
        lastDigitPos = i;
        break;
      }
    }
    if (lastDigitPos == -1) return (scalerCount: 0, cleanedCode: code);

    // Count consecutive commas immediately after the last digit placeholder
    var scalerCount = 0;
    var pos = lastDigitPos + 1;
    while (pos < code.length && code[pos] == ',') {
      scalerCount++;
      pos++;
    }

    if (scalerCount == 0) return (scalerCount: 0, cleanedCode: code);

    // Remove the scaler commas from the code
    final cleaned = code.substring(0, lastDigitPos + 1) +
        code.substring(lastDigitPos + 1 + scalerCount);
    return (scalerCount: scalerCount, cleanedCode: cleaned);
  }

  /// Inserts thousands separators into an integer string.
  static String _insertThousands(String integerPart, [String separator = ',']) {
    if (integerPart.length <= 3) return integerPart;

    final result = <String>[];
    final chars = integerPart.split('').reversed.toList();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) result.add(separator);
      result.add(chars[i]);
    }
    return result.reversed.join();
  }

  /// Formats a percentage value. Multiplies by 100 and appends %.
  static String _formatPercentage(
    double number,
    String code,
    FormatLocale locale,
  ) {
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

    var formatted = percentage.toStringAsFixed(decimalPlaces);
    if (locale.decimalSeparator != '.' && formatted.contains('.')) {
      formatted = formatted.replaceFirst('.', locale.decimalSeparator);
    }
    return '$formatted%';
  }

  /// Formats scientific notation: 0.00E+00 or 0.00e+00
  static String _formatScientific(double number, String code) {
    // Detect case of E
    final eIndex = code.indexOf('E');
    final eLowerIndex = code.indexOf('e');
    final bool useLowercase;
    final int actualEIndex;
    if (eIndex >= 0 && (eLowerIndex < 0 || eIndex <= eLowerIndex)) {
      useLowercase = false;
      actualEIndex = eIndex;
    } else if (eLowerIndex >= 0) {
      useLowercase = true;
      actualEIndex = eLowerIndex;
    } else {
      useLowercase = false;
      actualEIndex = -1;
    }

    int decimalPlaces = 2;
    if (actualEIndex > 0) {
      final beforeE = code.substring(0, actualEIndex);
      final dotIndex = beforeE.indexOf('.');
      if (dotIndex != -1) {
        decimalPlaces =
            beforeE.substring(dotIndex + 1).replaceAll(RegExp(r'[^0#]'), '').length;
      }
    }

    if (number == 0) {
      final zeros = '0' * decimalPlaces;
      final eLetter = useLowercase ? 'e' : 'E';
      return '0.$zeros$eLetter+00';
    }

    final isNegative = number < 0;
    final absNumber = number.abs();
    final exponent = (math.log(absNumber) / math.ln10).floor();
    final mantissa = absNumber / math.pow(10, exponent);
    final mantissaStr = mantissa.toStringAsFixed(decimalPlaces);

    final eLetter = useLowercase ? 'e' : 'E';
    final expSign = exponent >= 0 ? '+' : '-';
    final expStr = exponent.abs().toString().padLeft(2, '0');

    final result = '$mantissaStr$eLetter$expSign$expStr';
    return isNegative ? '-$result' : result;
  }

  /// Parses bracket metadata from a format section.
  ///
  /// Strips `[...]` codes from the start of a section, extracting:
  /// - `[Red]`, `[Blue]`, etc. → named color
  /// - `[Color1]`–`[Color56]` → indexed color
  /// - `[>100]`, `[<=50]` → condition
  /// - `[$-0409]` → locale code
  /// - `[$EUR]` → currency symbol override
  static _SectionMetadata _parseBracketMetadata(String section) {
    Color? color;
    _Condition? condition;
    String? localeCode;
    String? currencySymbol;

    var remaining = section;

    // Process bracket codes from the start of the section
    while (remaining.startsWith('[')) {
      final closeIndex = remaining.indexOf(']');
      if (closeIndex == -1) break;

      final bracketContent = remaining.substring(1, closeIndex);
      remaining = remaining.substring(closeIndex + 1);

      // Check for named colors (case-insensitive)
      final lowerContent = bracketContent.toLowerCase();
      if (_namedColors.containsKey(lowerContent)) {
        color = _namedColors[lowerContent];
        continue;
      }

      // Check for indexed colors: Color1-Color56
      final colorMatch = RegExp(r'^[Cc]olor(\d+)$').firstMatch(bracketContent);
      if (colorMatch != null) {
        final index = int.parse(colorMatch.group(1)!);
        if (index >= 1 && index <= 56) {
          color = _indexedColors[index - 1];
        }
        continue;
      }

      // Check for conditions: >100, <=50, =0, <>0
      final condMatch = RegExp(r'^(>=|<=|<>|>|<|=)(.+)$').firstMatch(bracketContent);
      if (condMatch != null) {
        final op = condMatch.group(1)!;
        final threshold = double.tryParse(condMatch.group(2)!);
        if (threshold != null) {
          condition = _Condition(op, threshold);
        }
        continue;
      }

      // Check for locale/currency: $-0409, $EUR, $EUR-0409
      if (bracketContent.startsWith(r'$')) {
        final inner = bracketContent.substring(1); // remove $
        final dashIndex = inner.indexOf('-');
        if (dashIndex == 0) {
          // [$-0409] — locale only
          localeCode = inner.substring(1);
        } else if (dashIndex > 0) {
          // [$EUR-0409] — currency + locale
          currencySymbol = inner.substring(0, dashIndex);
          localeCode = inner.substring(dashIndex + 1);
        } else if (inner.isNotEmpty) {
          // [$EUR] — currency only
          currencySymbol = inner;
        }
        continue;
      }

      // Duration brackets [h], [m], [s] — don't strip, put back
      if (lowerContent == 'h' || lowerContent == 'm' || lowerContent == 's') {
        remaining = '[$bracketContent]$remaining';
        break;
      }

      // Unknown bracket — put back and stop processing
      remaining = '[$bracketContent]$remaining';
      break;
    }

    return _SectionMetadata(
      color: color,
      condition: condition,
      localeCode: localeCode,
      currencySymbol: currencySymbol,
      cleanedPattern: remaining,
    );
  }

  /// Splits a format code on `;` outside quoted strings.
  static List<String> _splitSections(String code) {
    final sections = <String>[];
    final buffer = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < code.length; i++) {
      final ch = code[i];
      if (ch == '"') {
        inQuote = !inQuote;
        buffer.write(ch);
      } else if (ch == ';' && !inQuote) {
        sections.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    sections.add(buffer.toString());
    return sections;
  }

  /// Formats a number using section-aware format codes.
  ///
  /// Supports Excel section separators:
  /// - 1 section: used for all values, negative gets '-' prefix
  /// - 2 sections: [0]=positive+zero, [1]=negative (abs value)
  /// - 3+ sections: [0]=positive, [1]=negative (abs), [2]=zero
  ///
  /// Also supports conditional sections: `[>100]#,##0;0.00` — first matching
  /// condition wins, unconditional section is fallback.
  static CellFormatResult _formatWithSections(
    double number,
    String code,
    double? availableWidth,
    FormatLocale locale,
  ) {
    final sections = _splitSections(code);
    final metadata = sections.map(_parseBracketMetadata).toList();

    // Resolve locale from bracket metadata if present
    var effectiveLocale = locale;
    for (final m in metadata) {
      if (m.localeCode != null) {
        effectiveLocale = FormatLocale.fromLcid(m.localeCode!);
        break;
      }
    }

    // Check if any section has a condition — use condition-based selection
    final hasConditions = metadata.any((m) => m.condition != null);

    String section;
    double value;
    var prependMinus = false;
    Color? sectionColor;

    if (hasConditions) {
      // Condition-based section selection
      _SectionMetadata? matched;
      _SectionMetadata? fallback;

      for (final m in metadata) {
        if (m.condition != null) {
          if (m.condition!.evaluate(number)) {
            matched = m;
            break;
          }
        } else {
          fallback ??= m;
        }
      }

      final selected = matched ?? fallback ?? metadata.first;
      section = selected.cleanedPattern;
      sectionColor = selected.color;
      value = number.abs();
      if (number < 0 && selected.condition == null && matched == null) {
        prependMinus = true;
      }
    } else if (sections.length == 1) {
      section = metadata[0].cleanedPattern;
      sectionColor = metadata[0].color;
      value = number.abs();
      if (number < 0) prependMinus = true;
    } else if (sections.length == 2) {
      if (number < 0) {
        section = metadata[1].cleanedPattern;
        sectionColor = metadata[1].color;
        value = number.abs();
      } else {
        section = metadata[0].cleanedPattern;
        sectionColor = metadata[0].color;
        value = number;
      }
    } else {
      // 3+ sections
      if (number > 0) {
        section = metadata[0].cleanedPattern;
        sectionColor = metadata[0].color;
        value = number;
      } else if (number < 0) {
        section = metadata[1].cleanedPattern;
        sectionColor = metadata[1].color;
        value = number.abs();
      } else {
        section = metadata[2].cleanedPattern;
        sectionColor = metadata[2].color;
        value = 0;
      }
    }

    // Inject currency symbol override if present
    final currencyOverride = metadata
        .where((m) => m.currencySymbol != null && m.currencySymbol!.isNotEmpty)
        .map((m) => m.currencySymbol!)
        .firstOrNull;

    final result = _applyFormatSection(
        section, value, availableWidth, effectiveLocale, currencyOverride);
    final text = prependMinus ? '-$result' : result;
    return CellFormatResult(text, color: sectionColor);
  }

  /// Applies a single format section to a number value.
  ///
  /// Processes Excel metacharacters:
  /// - `"text"` — quoted literal strings
  /// - `\X` — escaped literal character
  /// - `_X` — space equal to width of character X (→ single space)
  /// - `*X` — repeat fill character
  /// - `?` — digit placeholder showing space for insignificant zeros
  static String _placeholder(int index) =>
      String.fromCharCode(0xE000 + index);

  /// Sentinel for *X repeat-fill position.
  static const _fillPlaceholder = '\uE100';

  static String _applyFormatSection(
    String section,
    double number,
    double? availableWidth,
    FormatLocale locale,
    String? currencyOverride,
  ) {
    final literals = <String>[];
    var code = section;
    var processed = StringBuffer();

    // Step 1: Extract quoted literals "..." and escape sequences \X
    var i = 0;
    while (i < code.length) {
      if (code[i] == '"') {
        final end = code.indexOf('"', i + 1);
        if (end != -1) {
          final ph = _placeholder(literals.length);
          literals.add(code.substring(i + 1, end));
          processed.write(ph);
          i = end + 1;
        } else {
          processed.write(code[i]);
          i++;
        }
      } else if (code[i] == '\\' && i + 1 < code.length) {
        final ph = _placeholder(literals.length);
        literals.add(code[i + 1]);
        processed.write(ph);
        i += 2;
      } else {
        processed.write(code[i]);
        i++;
      }
    }
    code = processed.toString();

    // Step 2: Replace _X with single space (skip PUA placeholder chars)
    code = code.replaceAllMapped(
        RegExp('_[^\uE000-\uE0FF]'), (_) => ' ');

    // Step 3: Replace *X with fill placeholder + character
    String? fillChar;
    code = code.replaceAllMapped(
        RegExp('\\*([^\uE000-\uE0FF])'), (m) {
      fillChar = m.group(1);
      return _fillPlaceholder;
    });

    // Step 4: Handle ? as space-padded digit — only replace ? that are NOT
    // part of a fraction pattern (e.g., # ?/?)
    final hasFractionSlash = RegExp(r'[?#]\s*/\s*[?#0-9]').hasMatch(code);
    if (!hasFractionSlash) {
      code = code.replaceAll('?', ' ');
    }

    // Step 5: Inject currency override if present
    if (currencyOverride != null) {
      // Replace any bare $ in the code; if none found, prepend to output later
      if (code.contains(r'$')) {
        code = code.replaceAll(r'$', currencyOverride);
      }
    }

    // Step 6: Detect comma scaler (trailing commas after last digit placeholder)
    final scalerResult = _detectCommaScaler(code);
    var effectiveNumber = number;
    if (scalerResult.scalerCount > 0) {
      effectiveNumber = number / math.pow(1000, scalerResult.scalerCount);
      code = scalerResult.cleanedCode;
    }

    // Step 7: Find numeric pattern and format via _formatNumericCode
    final numericPattern = RegExp(r'[#0][#0,]*\.?[0#?]*');
    final match = numericPattern.firstMatch(code);
    if (match != null) {
      final formatted = _formatNumericCode(effectiveNumber, match.group(0)!, locale);
      code = code.replaceFirst(numericPattern, formatted);
    }

    // Step 7b: Prepend currency override if no $ was in code to replace
    if (currencyOverride != null && !section.contains(r'$')) {
      // No $ was in the original pattern — the currency was only in brackets
      // Prepend the currency symbol to the formatted output
      code = '$currencyOverride$code';
    }

    // Step 8: Handle repeat fill
    if (fillChar != null && code.contains(_fillPlaceholder)) {
      code = _applyRepeatFill(code, fillChar!, availableWidth);
    }

    // Step 9: Restore literal placeholders
    for (var j = 0; j < literals.length; j++) {
      code = code.replaceAll(_placeholder(j), literals[j]);
    }

    return code;
  }

  /// Applies repeat fill for `*X` format codes.
  static String _applyRepeatFill(
    String code,
    String fillChar,
    double? availableWidth,
  ) {
    if (availableWidth == null || availableWidth <= 0) {
      return code.replaceAll(_fillPlaceholder, ' ');
    }

    // Estimate character width as 0.6 * assumed font size (14px default)
    const estimatedCharWidth = 14.0 * 0.6;
    final textWithoutFill = code.replaceAll(_fillPlaceholder, '');
    final textWidth = textWithoutFill.length * estimatedCharWidth;
    final remainingWidth = availableWidth - textWidth;

    if (remainingWidth <= 0) {
      return code.replaceAll(_fillPlaceholder, '');
    }

    final fillCount = (remainingWidth / estimatedCharWidth).floor();
    final fill = fillChar * (fillCount > 0 ? fillCount : 0);
    return code.replaceAll(_fillPlaceholder, fill);
  }

  /// Formats a text value using section-aware format codes.
  ///
  /// Uses the 4th section (index 3) if available for text formatting.
  /// Falls back to raw text if no text section exists.
  static String _formatTextSection(
    String text,
    String code,
    double? availableWidth,
  ) {
    final sections = _splitSections(code);
    if (sections.length < 4) return text;

    final section = sections[3];
    final literals = <String>[];
    var processed = StringBuffer();

    // Extract quoted literals and escape sequences
    var i = 0;
    while (i < section.length) {
      if (section[i] == '"') {
        final end = section.indexOf('"', i + 1);
        if (end != -1) {
          final ph = _placeholder(literals.length);
          literals.add(section.substring(i + 1, end));
          processed.write(ph);
          i = end + 1;
        } else {
          processed.write(section[i]);
          i++;
        }
      } else if (section[i] == '\\' && i + 1 < section.length) {
        final ph = _placeholder(literals.length);
        literals.add(section[i + 1]);
        processed.write(ph);
        i += 2;
      } else {
        processed.write(section[i]);
        i++;
      }
    }
    var result = processed.toString();

    // Replace _X with single space (skip PUA placeholder chars)
    result = result.replaceAllMapped(
        RegExp('_[^\uE000-\uE0FF]'), (_) => ' ');

    // Replace *X with fill placeholder
    String? fillChar;
    result = result.replaceAllMapped(
        RegExp('\\*([^\uE000-\uE0FF])'), (m) {
      fillChar = m.group(1);
      return _fillPlaceholder;
    });

    // Replace @ with the text value
    result = result.replaceAll('@', text);

    // Handle repeat fill
    if (fillChar != null && result.contains(_fillPlaceholder)) {
      result = _applyRepeatFill(result, fillChar!, availableWidth);
    }

    // Restore literal placeholders
    for (var j = 0; j < literals.length; j++) {
      result = result.replaceAll(_placeholder(j), literals[j]);
    }

    return result;
  }

  /// Formats a number as a fraction.
  ///
  /// Parses the format code to determine denominator constraints:
  /// - `# ?/?` — max denominator 9 (1 digit)
  /// - `# ??/??` — max denominator 99 (2 digits)
  /// - `# ???/???` — max denominator 999 (3 digits)
  /// - `# ?/8` — fixed denominator 8
  static String _formatFraction(double number, String formatCode) {
    final isNegative = number < 0;
    final absNumber = number.abs();
    final intPart = absNumber.truncate();
    final fracPart = absNumber - intPart;

    if (fracPart < 0.0001) {
      final result = intPart.toString();
      return isNegative ? '-$result' : result;
    }

    // Parse fraction format to determine constraints
    final fractionMatch = RegExp(r'([?#]+)\s*/\s*([?#0-9]+)').firstMatch(formatCode);
    int maxDen = 9; // default: single digit
    int? fixedDen;

    if (fractionMatch != null) {
      final denomPart = fractionMatch.group(2)!;
      // Check if denominator is a fixed number
      if (RegExp(r'^\d+$').hasMatch(denomPart)) {
        fixedDen = int.parse(denomPart);
      } else {
        // Count placeholder characters to determine max denominator
        final digitCount = denomPart.replaceAll(RegExp(r'[^?#]'), '').length;
        maxDen = math.pow(10, digitCount).toInt() - 1;
        if (maxDen < 1) maxDen = 9;
      }
    }

    int bestNum = 0;
    int bestDen = 1;

    if (fixedDen != null) {
      // Fixed denominator
      bestNum = (fracPart * fixedDen).round();
      bestDen = fixedDen;
      if (bestNum == 0) {
        final result = intPart.toString();
        return isNegative ? '-$result' : result;
      }
    } else {
      // Best-fit with max denominator
      double bestError = double.infinity;

      for (int den = 1; den <= maxDen; den++) {
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
    }

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

  // --- Duration formatting ---

  /// Formats a Duration value using bracket-notation format codes.
  static String _formatDuration(Duration duration, CellFormat fmt) {
    final negative = duration.isNegative;
    final abs = duration.abs();
    final totalSeconds = abs.inSeconds;
    final totalMinutes = abs.inMinutes;
    final totalHours = abs.inHours;

    final code = fmt.formatCode.toLowerCase();

    String result;
    if (code.contains('[h]')) {
      final mm = totalMinutes.remainder(60).toString().padLeft(2, '0');
      if (code.contains('ss')) {
        final ss = totalSeconds.remainder(60).toString().padLeft(2, '0');
        result = '$totalHours:$mm:$ss';
      } else {
        result = '$totalHours:$mm';
      }
    } else if (code.contains('[m]')) {
      if (code.contains('ss')) {
        final ss = totalSeconds.remainder(60).toString().padLeft(2, '0');
        result = '$totalMinutes:$ss';
      } else {
        result = '$totalMinutes';
      }
    } else if (code.contains('[s]')) {
      result = '$totalSeconds';
    } else {
      final mm = totalMinutes.remainder(60).toString().padLeft(2, '0');
      if (code.contains('ss')) {
        final ss = totalSeconds.remainder(60).toString().padLeft(2, '0');
        result = '$totalHours:$mm:$ss';
      } else if (code.contains('mm')) {
        result = '$totalHours:$mm';
      } else {
        result = '$totalHours';
      }
    }

    return negative ? '-$result' : result;
  }

  // --- Date/Time formatting ---

  /// Extracts quoted literals (`"..."`) and escape sequences (`\X`) from a
  /// format string, replacing them with PUA placeholders.
  static (String, List<String>) _extractLiterals(String code) {
    final literals = <String>[];
    final buf = StringBuffer();
    var i = 0;
    while (i < code.length) {
      if (code[i] == '"') {
        final end = code.indexOf('"', i + 1);
        if (end != -1) {
          final ph = _placeholder(literals.length);
          literals.add(code.substring(i + 1, end));
          buf.write(ph);
          i = end + 1;
        } else {
          buf.write(code[i]);
          i++;
        }
      } else if (code[i] == '\\' && i + 1 < code.length) {
        final ph = _placeholder(literals.length);
        literals.add(code[i + 1]);
        buf.write(ph);
        i += 2;
      } else {
        buf.write(code[i]);
        i++;
      }
    }
    return (buf.toString(), literals);
  }

  /// Case-sensitive substring match at a specific position.
  static bool _matchAt(String source, int pos, String target) {
    if (pos + target.length > source.length) return false;
    for (var i = 0; i < target.length; i++) {
      if (source.codeUnitAt(pos + i) != target.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Tokenizes a date/time format string into a list of [_FmtToken]s.
  static List<_FmtToken> _tokenizeDateFormat(String code) {
    final tokens = <_FmtToken>[];
    var i = 0;

    while (i < code.length) {
      _FmtToken? matched;

      // AM/PM markers (checked first because they contain '/')
      for (final entry in _ampmPatterns) {
        if (_matchAt(code, i, entry.$1)) {
          matched = _FmtToken(entry.$2, entry.$1);
          break;
        }
      }

      // Date/time token patterns (longest first per group)
      if (matched == null) {
        for (final entry in _dateTimePatterns) {
          if (_matchAt(code, i, entry.$1)) {
            matched = _FmtToken(entry.$2, entry.$1);
            break;
          }
        }
      }

      if (matched != null) {
        tokens.add(matched);
        i += matched.raw.length;

        // Check for fractional seconds after ss or s token
        if ((matched.type == _DateToken.ss || matched.type == _DateToken.s) &&
            i < code.length &&
            code[i] == '.') {
          // Count consecutive '0' characters after the dot
          var fracDigits = 0;
          var j = i + 1;
          while (j < code.length && code[j] == '0') {
            fracDigits++;
            j++;
          }
          if (fracDigits > 0) {
            final _DateToken fracType;
            if (fracDigits >= 3) {
              fracType = _DateToken.fracSec3;
            } else if (fracDigits == 2) {
              fracType = _DateToken.fracSec2;
            } else {
              fracType = _DateToken.fracSec1;
            }
            final raw = code.substring(i, i + 1 + fracDigits);
            tokens.add(_FmtToken(fracType, raw));
            i = i + 1 + fracDigits;
          }
        }
      } else {
        // Literal character (including PUA placeholders)
        tokens.add(_FmtToken(_DateToken.literal, code[i]));
        i++;
      }
    }
    return tokens;
  }

  /// AM/PM pattern table.
  static const _ampmPatterns = [
    ('AM/PM', _DateToken.ampmUpper),
    ('am/pm', _DateToken.ampmLower),
    ('A/P', _DateToken.apUpper),
    ('a/p', _DateToken.apLower),
  ];

  /// Date/time pattern table: longest first per group.
  static const _dateTimePatterns = [
    ('yyyy', _DateToken.yyyy),
    ('yy', _DateToken.yy),
    ('mmmmm', _DateToken.mmmmm),
    ('mmmm', _DateToken.mmmm),
    ('mmm', _DateToken.mmm),
    ('MM', _DateToken.monthPadded),
    ('mm', _DateToken.mmAmbig),
    ('m', _DateToken.mAmbig),
    ('dddd', _DateToken.dddd),
    ('ddd', _DateToken.ddd),
    ('dd', _DateToken.dd),
    ('d', _DateToken.d),
    ('HH', _DateToken.hourH24Padded),
    ('H', _DateToken.hourH24),
    ('hh', _DateToken.hh),
    ('h', _DateToken.h),
    ('ss', _DateToken.ss),
    ('s', _DateToken.s),
  ];

  /// Resolves ambiguous `m`/`mm` tokens to either month or minute.
  static List<_FmtToken> _resolveAmbiguousM(
    List<_FmtToken> tokens,
    CellFormatType type,
  ) {
    final result = <_FmtToken>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.type == _DateToken.mmAmbig || t.type == _DateToken.mAmbig) {
        final padded = t.type == _DateToken.mmAmbig;
        if (type == CellFormatType.time || _isMinuteContext(tokens, i)) {
          result.add(_FmtToken(
            padded ? _DateToken.minPadded : _DateToken.minUnpadded,
            t.raw,
          ));
        } else {
          result.add(_FmtToken(
            padded ? _DateToken.monPadded : _DateToken.monUnpadded,
            t.raw,
          ));
        }
      } else {
        result.add(t);
      }
    }
    return result;
  }

  /// Checks whether the ambiguous m/mm at [index] is in a minute context.
  static bool _isMinuteContext(List<_FmtToken> tokens, int index) {
    for (var j = index - 1; j >= 0; j--) {
      final tt = tokens[j].type;
      if (tt == _DateToken.literal) continue;
      if (tt == _DateToken.hourH24Padded ||
          tt == _DateToken.hourH24 ||
          tt == _DateToken.hh ||
          tt == _DateToken.h) {
        return true;
      }
      break;
    }
    for (var j = index + 1; j < tokens.length; j++) {
      final tt = tokens[j].type;
      if (tt == _DateToken.literal) continue;
      if (tt == _DateToken.ss || tt == _DateToken.s) {
        return true;
      }
      break;
    }
    return false;
  }

  /// Formats a single token into its string representation.
  static String _formatToken(
    _FmtToken token,
    DateTime date,
    int hour12,
    bool hasAmPm,
    bool isPM,
    FormatLocale locale,
  ) {
    switch (token.type) {
      case _DateToken.yyyy:
        return date.year.toString().padLeft(4, '0');
      case _DateToken.yy:
        return (date.year % 100).toString().padLeft(2, '0');
      case _DateToken.mmmmm:
        return locale.monthNames[date.month - 1][0];
      case _DateToken.mmmm:
        return locale.monthNames[date.month - 1];
      case _DateToken.mmm:
        return locale.monthAbbr[date.month - 1];
      case _DateToken.monthPadded:
        return date.month.toString().padLeft(2, '0');
      case _DateToken.monPadded:
        return date.month.toString().padLeft(2, '0');
      case _DateToken.monUnpadded:
        return date.month.toString();
      case _DateToken.minPadded:
        return date.minute.toString().padLeft(2, '0');
      case _DateToken.minUnpadded:
        return date.minute.toString();
      case _DateToken.dddd:
        return locale.dayNames[date.weekday - 1];
      case _DateToken.ddd:
        return locale.dayAbbr[date.weekday - 1];
      case _DateToken.dd:
        return date.day.toString().padLeft(2, '0');
      case _DateToken.d:
        return date.day.toString();
      case _DateToken.hourH24Padded:
        return date.hour.toString().padLeft(2, '0');
      case _DateToken.hourH24:
        return date.hour.toString();
      case _DateToken.hh:
        return (hasAmPm ? hour12 : date.hour).toString().padLeft(2, '0');
      case _DateToken.h:
        return (hasAmPm ? hour12 : date.hour).toString();
      case _DateToken.ss:
        return date.second.toString().padLeft(2, '0');
      case _DateToken.s:
        return date.second.toString();
      case _DateToken.fracSec1:
        return '.${(date.millisecond ~/ 100)}';
      case _DateToken.fracSec2:
        return '.${(date.millisecond ~/ 10).toString().padLeft(2, '0')}';
      case _DateToken.fracSec3:
        return '.${date.millisecond.toString().padLeft(3, '0')}';
      case _DateToken.ampmUpper:
        return isPM ? 'PM' : 'AM';
      case _DateToken.ampmLower:
        return isPM ? 'pm' : 'am';
      case _DateToken.apUpper:
        return isPM ? 'P' : 'A';
      case _DateToken.apLower:
        return isPM ? 'p' : 'a';
      case _DateToken.literal:
        return token.raw;
      case _DateToken.mmAmbig:
      case _DateToken.mAmbig:
        return token.raw;
    }
  }

  /// Formats a DateTime value using date/time format codes.
  static String _formatDateTime(DateTime date, CellFormat fmt, FormatLocale locale) {
    // Step 1: Extract literals into PUA placeholders
    final (stripped, literals) = _extractLiterals(fmt.formatCode);

    // Step 2: Tokenize
    var tokens = _tokenizeDateFormat(stripped);

    // Step 3: Resolve ambiguous m/mm
    tokens = _resolveAmbiguousM(tokens, fmt.type);

    // Step 4: Detect AM/PM
    final hasAmPm = tokens.any((t) =>
        t.type == _DateToken.ampmUpper ||
        t.type == _DateToken.ampmLower ||
        t.type == _DateToken.apUpper ||
        t.type == _DateToken.apLower);
    final isPM = date.hour >= 12;
    var hour12 = date.hour % 12;
    if (hour12 == 0) hour12 = 12;

    // Step 5: Format each token
    final buf = StringBuffer();
    for (final token in tokens) {
      buf.write(_formatToken(token, date, hour12, hasAmPm, isPM, locale));
    }
    var result = buf.toString();

    // Step 6: Restore literal placeholders
    for (var j = 0; j < literals.length; j++) {
      result = result.replaceAll(_placeholder(j), literals[j]);
    }

    return result;
  }
}

/// Classifies every token in a date/time format string.
enum _DateToken {
  yyyy, yy,
  mmmmm, mmmm, mmm,
  monthPadded,  // MM — explicit month, never ambiguous
  mmAmbig,      // mm — ambiguous, resolved to monPadded or minPadded
  mAmbig,       // m — ambiguous, resolved to monUnpadded or minUnpadded
  monPadded, monUnpadded,   // resolved month tokens
  minPadded, minUnpadded,   // resolved minute tokens
  dddd, ddd, dd, d,
  hourH24Padded, hourH24,   // HH, H — 24-hour
  hh, h,                    // hh, h — 12-hour (or 24-hour without AM/PM)
  ss, s,
  fracSec1,                 // .0 — tenths of a second
  fracSec2,                 // .00 — hundredths of a second
  fracSec3,                 // .000 — milliseconds
  ampmUpper, ampmLower,     // AM/PM, am/pm
  apUpper, apLower,         // A/P, a/p
  literal,
}

/// A single token from a date/time format string.
class _FmtToken {
  final _DateToken type;
  final String raw;
  const _FmtToken(this.type, this.raw);
}
