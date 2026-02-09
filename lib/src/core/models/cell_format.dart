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

  /// Duration/elapsed time format (e.g., [h]:mm:ss).
  duration,

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
      case CellValueType.duration:
        return _formatDuration(value.rawValue as Duration, fmt);
      case CellValueType.text:
        if (fmt.type == CellFormatType.number ||
            fmt.type == CellFormatType.currency ||
            fmt.type == CellFormatType.accounting) {
          return _formatTextSection(value.rawValue as String, fmt.formatCode);
        }
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
      case CellFormatType.fraction:
        return _formatFraction(number);
      case CellFormatType.number:
      case CellFormatType.currency:
      case CellFormatType.accounting:
        return _formatWithSections(number, fmt.formatCode);
      case CellFormatType.custom:
      case CellFormatType.special:
        return _formatNumericCode(number, fmt.formatCode);
      case CellFormatType.date:
      case CellFormatType.time:
        // Number treated as-is when format expects a date
        return _formatNumericCode(number, fmt.formatCode);
      case CellFormatType.duration:
      case CellFormatType.general:
      case CellFormatType.text:
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
  static String _formatWithSections(double number, String code) {
    final sections = _splitSections(code);

    String section;
    double value;
    var prependMinus = false;

    if (sections.length == 1) {
      section = sections[0];
      value = number.abs();
      if (number < 0) prependMinus = true;
    } else if (sections.length == 2) {
      if (number < 0) {
        section = sections[1];
        value = number.abs();
      } else {
        section = sections[0];
        value = number;
      }
    } else {
      // 3+ sections
      if (number > 0) {
        section = sections[0];
        value = number;
      } else if (number < 0) {
        section = sections[1];
        value = number.abs();
      } else {
        section = sections[2];
        value = 0;
      }
    }

    final result = _applyFormatSection(section, value);
    return prependMinus ? '-$result' : result;
  }

  /// Applies a single format section to a number value.
  ///
  /// Processes Excel metacharacters:
  /// - `"text"` — quoted literal strings
  /// - `\X` — escaped literal character
  /// - `_X` — space equal to width of character X (→ single space)
  /// - `*X` — repeat fill character (→ single space)
  /// - `?` — digit placeholder showing space for insignificant zeros
  /// Returns a single PUA character for the given index, used as a
  /// placeholder that cannot collide with format metacharacters or digits.
  static String _placeholder(int index) =>
      String.fromCharCode(0xE000 + index);

  static String _applyFormatSection(String section, double number) {
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
        // Step 2: Extract escape sequences \X
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

    // Step 3: Replace _X with single space (skip PUA placeholder chars)
    code = code.replaceAllMapped(
        RegExp('_[^\uE000-\uE0FF]'), (_) => ' ');

    // Step 4: Replace *X with single space (skip PUA placeholder chars)
    code = code.replaceAllMapped(
        RegExp('\\*[^\uE000-\uE0FF]'), (_) => ' ');

    // Step 5: Replace ? with space
    code = code.replaceAll('?', ' ');

    // Step 6: Find numeric pattern and format via _formatNumericCode
    final numericPattern = RegExp(r'[#0][#0,]*\.?[0#]*');
    final match = numericPattern.firstMatch(code);
    if (match != null) {
      final formatted = _formatNumericCode(number, match.group(0)!);
      code = code.replaceFirst(numericPattern, formatted);
    }

    // Step 7: Restore literal placeholders
    for (var j = 0; j < literals.length; j++) {
      code = code.replaceAll(_placeholder(j), literals[j]);
    }

    return code;
  }

  /// Formats a text value using section-aware format codes.
  ///
  /// Uses the 4th section (index 3) if available for text formatting.
  /// Falls back to raw text if no text section exists.
  static String _formatTextSection(String text, String code) {
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

    // Replace *X with single space (skip PUA placeholder chars)
    result = result.replaceAllMapped(
        RegExp('\\*[^\uE000-\uE0FF]'), (_) => ' ');

    // Replace @ with the text value
    result = result.replaceAll('@', text);

    // Restore literal placeholders
    for (var j = 0; j < literals.length; j++) {
      result = result.replaceAll(_placeholder(j), literals[j]);
    }

    return result;
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

  // --- Duration formatting ---

  /// Formats a Duration value using bracket-notation format codes.
  ///
  /// Supported codes: `[h]:mm:ss`, `[h]:mm`, `[m]:ss`, `[s]`,
  /// and bare `h:mm:ss` (treated as `[h]:mm:ss` for duration type).
  static String _formatDuration(Duration duration, CellFormat fmt) {
    final negative = duration.isNegative;
    final abs = duration.abs();
    final totalSeconds = abs.inSeconds;
    final totalMinutes = abs.inMinutes;
    final totalHours = abs.inHours;

    final code = fmt.formatCode.toLowerCase();

    String result;
    if (code.contains('[h]')) {
      // Total hours, modular minutes and seconds
      final mm = totalMinutes.remainder(60).toString().padLeft(2, '0');
      if (code.contains('ss')) {
        final ss = totalSeconds.remainder(60).toString().padLeft(2, '0');
        result = '$totalHours:$mm:$ss';
      } else {
        result = '$totalHours:$mm';
      }
    } else if (code.contains('[m]')) {
      // Total minutes, modular seconds
      if (code.contains('ss')) {
        final ss = totalSeconds.remainder(60).toString().padLeft(2, '0');
        result = '$totalMinutes:$ss';
      } else {
        result = '$totalMinutes';
      }
    } else if (code.contains('[s]')) {
      // Total seconds
      result = '$totalSeconds';
    } else {
      // No brackets — treat h as [h] (sensible default for duration type)
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

  /// Extracts quoted literals (`"..."`) and escape sequences (`\X`) from a
  /// format string, replacing them with PUA placeholders.
  /// Returns the processed string and the list of extracted literals.
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
  /// Uses left-to-right greedy longest-match scanning.
  static List<_FmtToken> _tokenizeDateFormat(String code) {
    final tokens = <_FmtToken>[];
    var i = 0;

    // Ordered by priority: AM/PM markers first (contain '/'), then
    // longest-to-shortest for each letter group.
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
      } else {
        // Literal character (including PUA placeholders)
        tokens.add(_FmtToken(_DateToken.literal, code[i]));
        i++;
      }
    }
    return tokens;
  }

  /// AM/PM pattern table: (pattern, token type), checked first.
  static const _ampmPatterns = [
    ('AM/PM', _DateToken.ampmUpper),
    ('am/pm', _DateToken.ampmLower),
    ('A/P', _DateToken.apUpper),
    ('a/p', _DateToken.apLower),
  ];

  /// Date/time pattern table: (pattern, token type), longest first per group.
  static const _dateTimePatterns = [
    // Year
    ('yyyy', _DateToken.yyyy),
    ('yy', _DateToken.yy),
    // Month (5-letter first-letter, then 4/3/2-letter explicit, then ambiguous)
    ('mmmmm', _DateToken.mmmmm),
    ('mmmm', _DateToken.mmmm),
    ('mmm', _DateToken.mmm),
    ('MM', _DateToken.monthPadded),
    ('mm', _DateToken.mmAmbig),
    ('m', _DateToken.mAmbig),
    // Day
    ('dddd', _DateToken.dddd),
    ('ddd', _DateToken.ddd),
    ('dd', _DateToken.dd),
    ('d', _DateToken.d),
    // Hour (24h uppercase)
    ('HH', _DateToken.hourH24Padded),
    ('H', _DateToken.hourH24),
    // Hour (12h lowercase)
    ('hh', _DateToken.hh),
    ('h', _DateToken.h),
    // Seconds
    ('ss', _DateToken.ss),
    ('s', _DateToken.s),
  ];

  /// Resolves ambiguous `m`/`mm` tokens to either month or minute based on
  /// context: adjacent to hour → minute; adjacent to second → minute;
  /// otherwise → month. Time format type forces all to minutes.
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

  /// Checks whether the ambiguous m/mm at [index] is in a minute context:
  /// scan left for an hour token (skipping literals), scan right for a
  /// second token (skipping literals).
  static bool _isMinuteContext(List<_FmtToken> tokens, int index) {
    // Scan left for hour token
    for (var j = index - 1; j >= 0; j--) {
      final tt = tokens[j].type;
      if (tt == _DateToken.literal) continue;
      if (tt == _DateToken.hourH24Padded ||
          tt == _DateToken.hourH24 ||
          tt == _DateToken.hh ||
          tt == _DateToken.h) {
        return true;
      }
      break; // non-literal, non-hour → stop
    }
    // Scan right for second token
    for (var j = index + 1; j < tokens.length; j++) {
      final tt = tokens[j].type;
      if (tt == _DateToken.literal) continue;
      if (tt == _DateToken.ss || tt == _DateToken.s) {
        return true;
      }
      break; // non-literal, non-second → stop
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
  ) {
    switch (token.type) {
      case _DateToken.yyyy:
        return date.year.toString().padLeft(4, '0');
      case _DateToken.yy:
        return (date.year % 100).toString().padLeft(2, '0');
      case _DateToken.mmmmm:
        return _monthNames[date.month - 1][0];
      case _DateToken.mmmm:
        return _monthNames[date.month - 1];
      case _DateToken.mmm:
        return _monthAbbr[date.month - 1];
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
        return _dayNames[date.weekday - 1];
      case _DateToken.ddd:
        return _dayAbbr[date.weekday - 1];
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
      // Ambiguous tokens should be resolved before formatting
      case _DateToken.mmAmbig:
      case _DateToken.mAmbig:
        return token.raw;
    }
  }

  /// Formats a DateTime value using date/time format codes.
  ///
  /// Uses a 6-step token-based pipeline:
  /// 1. Extract literals (quoted strings, escape sequences)
  /// 2. Tokenize left-to-right with greedy longest-match
  /// 3. Resolve ambiguous m/mm to month or minute by context
  /// 4. Detect AM/PM mode and compute 12-hour values
  /// 5. Format each token
  /// 6. Restore literal placeholders
  static String _formatDateTime(DateTime date, CellFormat fmt) {
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
      buf.write(_formatToken(token, date, hour12, hasAmPm, isPM));
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
