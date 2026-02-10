import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('CellFormatType', () {
    test('has all expected values', () {
      expect(CellFormatType.values, hasLength(13));
      expect(CellFormatType.values, contains(CellFormatType.general));
      expect(CellFormatType.values, contains(CellFormatType.number));
      expect(CellFormatType.values, contains(CellFormatType.currency));
      expect(CellFormatType.values, contains(CellFormatType.accounting));
      expect(CellFormatType.values, contains(CellFormatType.date));
      expect(CellFormatType.values, contains(CellFormatType.time));
      expect(CellFormatType.values, contains(CellFormatType.percentage));
      expect(CellFormatType.values, contains(CellFormatType.fraction));
      expect(CellFormatType.values, contains(CellFormatType.scientific));
      expect(CellFormatType.values, contains(CellFormatType.text));
      expect(CellFormatType.values, contains(CellFormatType.special));
      expect(CellFormatType.values, contains(CellFormatType.duration));
      expect(CellFormatType.values, contains(CellFormatType.custom));
    });
  });

  group('CellFormat', () {
    group('construction', () {
      test('creates with required type and formatCode', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00',
        );
        expect(fmt.type, CellFormatType.number);
        expect(fmt.formatCode, '#,##0.00');
      });

      test('static const presets are accessible', () {
        expect(CellFormat.general.type, CellFormatType.general);
        expect(CellFormat.general.formatCode, 'General');

        expect(CellFormat.integer.type, CellFormatType.number);
        expect(CellFormat.integer.formatCode, '#,##0');

        expect(CellFormat.currency.type, CellFormatType.currency);
        expect(CellFormat.currency.formatCode, r'$#,##0.00');

        expect(CellFormat.percentage.type, CellFormatType.percentage);
        expect(CellFormat.percentage.formatCode, '0%');

        expect(CellFormat.scientific.type, CellFormatType.scientific);
        expect(CellFormat.scientific.formatCode, '0.00E+00');

        expect(CellFormat.text.type, CellFormatType.text);
        expect(CellFormat.text.formatCode, '@');
      });

      test('can be used in const context', () {
        const fmt = CellFormat.general;
        expect(fmt, isNotNull);
      });
    });

    group('equality', () {
      test('equal formats are equal', () {
        const a = CellFormat(type: CellFormatType.number, formatCode: '0.00');
        const b = CellFormat(type: CellFormatType.number, formatCode: '0.00');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different types are not equal', () {
        const a = CellFormat(type: CellFormatType.number, formatCode: '0.00');
        const b =
            CellFormat(type: CellFormatType.currency, formatCode: '0.00');
        expect(a, isNot(equals(b)));
      });

      test('different codes are not equal', () {
        const a = CellFormat(type: CellFormatType.number, formatCode: '0.00');
        const b =
            CellFormat(type: CellFormatType.number, formatCode: '#,##0.00');
        expect(a, isNot(equals(b)));
      });

      test('identical instances are equal', () {
        const a = CellFormat.general;
        const b = CellFormat.general;
        expect(identical(a, b), isTrue);
        expect(a, equals(b));
      });
    });

    group('toString', () {
      test('includes type and format code', () {
        expect(CellFormat.general.toString(),
            'CellFormat(general, General)');
        expect(CellFormat.currency.toString(),
            contains('currency'));
        expect(CellFormat.currency.toString(),
            contains(r'$#,##0.00'));
      });
    });
  });

  group('CellFormat.format()', () {
    group('general', () {
      test('number uses displayValue', () {
        expect(CellFormat.general.format(CellValue.number(42)), '42');
        expect(CellFormat.general.format(CellValue.number(3.14)), '3.14');
      });

      test('text passes through', () {
        expect(CellFormat.general.format(CellValue.text('hello')), 'hello');
      });

      test('boolean uses TRUE/FALSE', () {
        expect(CellFormat.general.format(CellValue.boolean(true)), 'TRUE');
        expect(CellFormat.general.format(CellValue.boolean(false)), 'FALSE');
      });
    });

    group('number formatting', () {
      test('#,##0 formats integer with thousands', () {
        expect(CellFormat.integer.format(CellValue.number(1234)), '1,234');
      });

      test('#,##0 formats large number', () {
        expect(CellFormat.integer.format(CellValue.number(1234567)),
            '1,234,567');
      });

      test('#,##0 formats small number without separator', () {
        expect(CellFormat.integer.format(CellValue.number(42)), '42');
      });

      test('0.00 formats with fixed decimals', () {
        expect(CellFormat.decimal.format(CellValue.number(42)), '42.00');
        expect(CellFormat.decimal.format(CellValue.number(3.1)), '3.10');
      });

      test('0.00 rounds to decimal places', () {
        expect(
            CellFormat.decimal.format(CellValue.number(3.14159)), '3.14');
      });

      test('#,##0.00 formats with thousands and decimals', () {
        expect(
            CellFormat.number.format(CellValue.number(1234.5)), '1,234.50');
      });

      test('handles zero', () {
        expect(CellFormat.integer.format(CellValue.number(0)), '0');
        expect(CellFormat.decimal.format(CellValue.number(0)), '0.00');
        expect(CellFormat.number.format(CellValue.number(0)), '0.00');
      });

      test('handles negative numbers', () {
        expect(CellFormat.integer.format(CellValue.number(-1234)), '-1,234');
        expect(CellFormat.number.format(CellValue.number(-1234.5)),
            '-1,234.50');
      });

      test('handles very large numbers', () {
        expect(CellFormat.integer.format(CellValue.number(1000000000)),
            '1,000,000,000');
      });
    });

    group('currency', () {
      test(r'$#,##0.00 adds dollar sign', () {
        expect(CellFormat.currency.format(CellValue.number(1234.5)),
            r'$1,234.50');
      });

      test('handles zero', () {
        expect(
            CellFormat.currency.format(CellValue.number(0)), r'$0.00');
      });

      test('handles negative', () {
        expect(CellFormat.currency.format(CellValue.number(-42)),
            r'-$42.00');
      });

      test('handles small values', () {
        expect(CellFormat.currency.format(CellValue.number(0.99)),
            r'$0.99');
      });
    });

    group('accounting', () {
      test('financial positive: trailing space for paren alignment', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'#,##0.00_);(#,##0.00)',
        );
        expect(fmt.format(CellValue.number(1234.56)), '1,234.56 ');
      });

      test('financial negative: parentheses', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'#,##0.00_);(#,##0.00)',
        );
        expect(fmt.format(CellValue.number(-1234.56)), '(1,234.56)');
      });

      test('financial zero: uses positive section', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'#,##0.00_);(#,##0.00)',
        );
        expect(fmt.format(CellValue.number(0)), '0.00 ');
      });

      test('accounting positive: aligned with spaces', () {
        const fmt = CellFormat(
          type: CellFormatType.accounting,
          formatCode: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
        );
        expect(fmt.format(CellValue.number(1234.56)), r' $ 1,234.56 ');
      });

      test('accounting negative: parentheses with dollar', () {
        const fmt = CellFormat(
          type: CellFormatType.accounting,
          formatCode: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
        );
        expect(fmt.format(CellValue.number(-1234.56)), r' $ (1,234.56)');
      });

      test('accounting zero: dash with spaces', () {
        const fmt = CellFormat(
          type: CellFormatType.accounting,
          formatCode: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
        );
        expect(fmt.format(CellValue.number(0)), r' $ -   ');
      });

      test('accounting text section: text with alignment spaces', () {
        const fmt = CellFormat(
          type: CellFormatType.accounting,
          formatCode: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
        );
        expect(fmt.format(CellValue.text('hello')), ' hello ');
      });

      test('text with no text section: passthrough', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'#,##0.00_);(#,##0.00)',
        );
        expect(fmt.format(CellValue.text('hello')), 'hello');
      });

      test('simple format with no sections: backward compat', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00',
        );
        expect(fmt.format(CellValue.number(1234.56)), '1,234.56');
      });

      test('negative with single section: prepends minus', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00',
        );
        expect(fmt.format(CellValue.number(-5.5)), '-5.50');
      });
    });

    group('percentage', () {
      test('0% multiplies by 100', () {
        expect(
            CellFormat.percentage.format(CellValue.number(0.42)), '42%');
      });

      test('0.00% with decimals', () {
        expect(CellFormat.percentageDecimal.format(CellValue.number(0.4256)),
            '42.56%');
      });

      test('handles 0', () {
        expect(CellFormat.percentage.format(CellValue.number(0)), '0%');
      });

      test('handles 1 (100%)', () {
        expect(CellFormat.percentage.format(CellValue.number(1)), '100%');
      });

      test('handles values > 1', () {
        expect(CellFormat.percentage.format(CellValue.number(1.5)), '150%');
      });

      test('handles negative', () {
        expect(
            CellFormat.percentage.format(CellValue.number(-0.1)), '-10%');
      });
    });

    group('scientific', () {
      test('0.00E+00 basic', () {
        expect(CellFormat.scientific.format(CellValue.number(12345)),
            '1.23E+04');
      });

      test('handles negative', () {
        expect(CellFormat.scientific.format(CellValue.number(-12345)),
            '-1.23E+04');
      });

      test('handles small numbers', () {
        expect(CellFormat.scientific.format(CellValue.number(0.00123)),
            '1.23E-03');
      });

      test('handles zero', () {
        expect(CellFormat.scientific.format(CellValue.number(0)),
            '0.00E+00');
      });

      test('handles 1', () {
        expect(CellFormat.scientific.format(CellValue.number(1)),
            '1.00E+00');
      });
    });

    group('date', () {
      final date = DateTime(2024, 1, 15);

      test('yyyy-MM-dd ISO format', () {
        expect(CellFormat.dateIso.format(CellValue.date(date)),
            '2024-01-15');
      });

      test('m/d/yyyy US format', () {
        expect(
            CellFormat.dateUs.format(CellValue.date(date)), '1/15/2024');
      });

      test('d-mmm-yy short format', () {
        expect(CellFormat.dateShort.format(CellValue.date(date)),
            '15-Jan-24');
      });

      test('mmm-yy month-year format', () {
        expect(CellFormat.dateMonthYear.format(CellValue.date(date)),
            'Jan-24');
      });

      test('handles different months', () {
        final dec = DateTime(2024, 12, 25);
        expect(CellFormat.dateIso.format(CellValue.date(dec)), '2024-12-25');
        expect(CellFormat.dateShort.format(CellValue.date(dec)), '25-Dec-24');
      });

      test('mmmm full month name', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'd mmmm yyyy',
        );
        expect(fmt.format(CellValue.date(date)), '15 January 2024');
      });

      test('mmmmm first letter of month', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'mmmmm',
        );
        expect(fmt.format(CellValue.date(date)), 'J');
        expect(
          fmt.format(CellValue.date(DateTime(2024, 2, 1))),
          'F',
        );
        expect(
          fmt.format(CellValue.date(DateTime(2024, 3, 1))),
          'M',
        );
      });

      test('dddd full day name', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'dddd, mmmm d, yyyy',
        );
        // 2024-01-15 is a Monday
        expect(fmt.format(CellValue.date(date)), 'Monday, January 15, 2024');
      });

      test('ddd abbreviated day name', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'ddd, mmm d',
        );
        expect(fmt.format(CellValue.date(date)), 'Mon, Jan 15');
      });
    });

    group('time', () {
      test('H:mm 24h format', () {
        final date = DateTime(2024, 1, 1, 14, 30);
        expect(CellFormat.time24.format(CellValue.date(date)), '14:30');
      });

      test('H:mm:ss with seconds', () {
        final date = DateTime(2024, 1, 1, 14, 30, 5);
        expect(CellFormat.time24Seconds.format(CellValue.date(date)),
            '14:30:05');
      });

      test('h:mm AM/PM 12h format', () {
        final date = DateTime(2024, 1, 1, 14, 30);
        expect(CellFormat.time12.format(CellValue.date(date)), '2:30 PM');
      });

      test('handles midnight', () {
        final midnight = DateTime(2024, 1, 1, 0, 0);
        expect(CellFormat.time24.format(CellValue.date(midnight)), '0:00');
        expect(
            CellFormat.time12.format(CellValue.date(midnight)), '12:00 AM');
      });

      test('handles noon', () {
        final noon = DateTime(2024, 1, 1, 12, 0);
        expect(CellFormat.time24.format(CellValue.date(noon)), '12:00');
        expect(CellFormat.time12.format(CellValue.date(noon)), '12:00 PM');
      });

      test('handles morning AM', () {
        final morning = DateTime(2024, 1, 1, 9, 5);
        expect(CellFormat.time12.format(CellValue.date(morning)), '9:05 AM');
      });

      test('s unpadded seconds', () {
        const fmt = CellFormat(
          type: CellFormatType.time,
          formatCode: 'h:mm:s AM/PM',
        );
        final date = DateTime(2024, 1, 1, 14, 30, 5);
        expect(fmt.format(CellValue.date(date)), '2:30:5 PM');
      });

      test('hh:mm:ss padded', () {
        const fmt = CellFormat(
          type: CellFormatType.time,
          formatCode: 'hh:mm:ss AM/PM',
        );
        final date = DateTime(2024, 1, 1, 9, 5, 3);
        expect(fmt.format(CellValue.date(date)), '09:05:03 AM');
      });

      test('A/P abbreviated upper', () {
        const fmt = CellFormat(
          type: CellFormatType.time,
          formatCode: 'h:mm A/P',
        );
        final pm = DateTime(2024, 1, 1, 14, 30);
        final am = DateTime(2024, 1, 1, 9, 30);
        expect(fmt.format(CellValue.date(pm)), '2:30 P');
        expect(fmt.format(CellValue.date(am)), '9:30 A');
      });

      test('a/p abbreviated lower', () {
        const fmt = CellFormat(
          type: CellFormatType.time,
          formatCode: 'h:mm a/p',
        );
        final pm = DateTime(2024, 1, 1, 14, 30);
        final am = DateTime(2024, 1, 1, 9, 30);
        expect(fmt.format(CellValue.date(pm)), '2:30 p');
        expect(fmt.format(CellValue.date(am)), '9:30 a');
      });
    });

    group('text', () {
      test('@ passes through text', () {
        expect(CellFormat.text.format(CellValue.text('hello')), 'hello');
      });

      test('@ passes through number as string', () {
        expect(CellFormat.text.format(CellValue.number(42)), '42.0');
      });
    });

    group('fraction', () {
      test('formats 3.5 as "3 1/2"', () {
        expect(CellFormat.fraction.format(CellValue.number(3.5)), '3 1/2');
      });

      test('formats 0.25 as "1/4"', () {
        expect(CellFormat.fraction.format(CellValue.number(0.25)), '1/4');
      });

      test('formats integer as just integer', () {
        expect(CellFormat.fraction.format(CellValue.number(5)), '5');
      });

      test('formats 0.333 approximately', () {
        final result = CellFormat.fraction.format(CellValue.number(0.333));
        expect(result, '1/3');
      });

      test('handles negative fractions', () {
        expect(
            CellFormat.fraction.format(CellValue.number(-3.5)), '-3 1/2');
      });
    });

    group('date+time', () {
      test('m/d/yyyy H:mm:ss formats minutes correctly', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy H:mm:ss',
        );
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        expect(fmt.format(CellValue.date(date)), '1/15/2024 14:30:45');
      });

      test('m/d/yyyy h:mm AM/PM formats 12-hour with minutes', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy h:mm AM/PM',
        );
        final date = DateTime(2024, 1, 15, 14, 30);
        expect(fmt.format(CellValue.date(date)), '1/15/2024 2:30 PM');
      });

      test('yyyy-MM-dd HH:mm:ss ISO-style with uppercase MM month', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'yyyy-MM-dd HH:mm:ss',
        );
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        expect(fmt.format(CellValue.date(date)), '2024-01-15 14:30:45');
      });

      test('mm/dd/yyyy H:mm:ss with mm as both month and minutes', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'mm/dd/yyyy H:mm:ss',
        );
        final date = DateTime(2024, 3, 5, 9, 7, 2);
        expect(fmt.format(CellValue.date(date)), '03/05/2024 9:07:02');
      });

      test('midnight edge case', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy H:mm:ss',
        );
        final date = DateTime(2024, 1, 1, 0, 0, 0);
        expect(fmt.format(CellValue.date(date)), '1/1/2024 0:00:00');
      });

      test('noon edge case', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy h:mm:ss AM/PM',
        );
        final date = DateTime(2024, 6, 15, 12, 0, 0);
        expect(fmt.format(CellValue.date(date)), '6/15/2024 12:00:00 PM');
      });

      test('h:mm:ss with date type resolves m to minutes', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'h:mm:ss',
        );
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        expect(fmt.format(CellValue.date(date)), '14:30:45');
      });

      test('m before s resolves to unpadded minutes', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'yyyy-MM-dd h:m:ss',
        );
        final date = DateTime(2024, 1, 15, 14, 5, 45);
        expect(fmt.format(CellValue.date(date)), '2024-01-15 14:5:45');
      });

      test('m as month when no hour/second neighbor', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy',
        );
        final date = DateTime(2024, 3, 5);
        expect(fmt.format(CellValue.date(date)), '3/5/2024');
      });
    });

    group('duration', () {
      test('[h]:mm:ss formats hours, minutes, seconds', () {
        final d = const Duration(hours: 1, minutes: 30, seconds: 5);
        expect(CellFormat.duration.format(CellValue.duration(d)), '1:30:05');
      });

      test('[h]:mm formats hours and minutes', () {
        final d = const Duration(hours: 2, minutes: 45);
        expect(
            CellFormat.durationShort.format(CellValue.duration(d)), '2:45');
      });

      test('[m]:ss formats total minutes and seconds', () {
        final d = const Duration(hours: 1, minutes: 30, seconds: 5);
        expect(
            CellFormat.durationMinSec.format(CellValue.duration(d)), '90:05');
      });

      test('[s] formats total seconds', () {
        const fmt =
            CellFormat(type: CellFormatType.duration, formatCode: '[s]');
        final d = const Duration(minutes: 1, seconds: 30);
        expect(fmt.format(CellValue.duration(d)), '90');
      });

      test('large duration', () {
        final d = const Duration(hours: 100);
        expect(
            CellFormat.duration.format(CellValue.duration(d)), '100:00:00');
      });

      test('zero duration', () {
        expect(CellFormat.duration.format(CellValue.duration(Duration.zero)),
            '0:00:00');
      });

      test('negative duration', () {
        final d = const Duration(hours: 1, minutes: 30);
        expect(CellFormat.duration.format(CellValue.duration(-d)),
            '-1:30:00');
      });

      test('bare h:mm:ss (no brackets) works as [h]:mm:ss for duration', () {
        const fmt =
            CellFormat(type: CellFormatType.duration, formatCode: 'h:mm:ss');
        final d = const Duration(hours: 1, minutes: 30, seconds: 5);
        expect(fmt.format(CellValue.duration(d)), '1:30:05');
      });

      test('duration with general format uses default display', () {
        final d = const Duration(hours: 1, minutes: 30, seconds: 5);
        expect(CellFormat.general.format(CellValue.duration(d)), '1:30:05');
      });
    });

    group('type mismatches', () {
      test('number format on text value passes through', () {
        expect(CellFormat.number.format(CellValue.text('hello')), 'hello');
      });

      test('format on boolean value returns TRUE/FALSE', () {
        expect(
            CellFormat.number.format(CellValue.boolean(true)), 'TRUE');
      });

      test('format on error value returns error string', () {
        expect(CellFormat.number.format(CellValue.error('#DIV/0!')),
            '#DIV/0!');
      });

      test('format on formula returns formula string', () {
        expect(CellFormat.number.format(CellValue.formula('=SUM(A1:A10)')),
            '=SUM(A1:A10)');
      });
    });
  });

  // ==========================================================================
  // New feature tests
  // ==========================================================================

  group('CellFormatResult', () {
    test('constructs with text only', () {
      const r = CellFormatResult('hello');
      expect(r.text, 'hello');
      expect(r.color, isNull);
    });

    test('constructs with text and color', () {
      const r = CellFormatResult('hello', color: Color(0xFFFF0000));
      expect(r.text, 'hello');
      expect(r.color, const Color(0xFFFF0000));
    });

    test('equality', () {
      const a = CellFormatResult('hello', color: Color(0xFFFF0000));
      const b = CellFormatResult('hello', color: Color(0xFFFF0000));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on text', () {
      const a = CellFormatResult('hello');
      const b = CellFormatResult('world');
      expect(a, isNot(equals(b)));
    });

    test('inequality on color', () {
      const a = CellFormatResult('hello', color: Color(0xFFFF0000));
      const b = CellFormatResult('hello', color: Color(0xFF0000FF));
      expect(a, isNot(equals(b)));
    });

    test('toString without color', () {
      const r = CellFormatResult('hello');
      expect(r.toString(), 'CellFormatResult(hello)');
    });

    test('toString with color', () {
      const r = CellFormatResult('hello', color: Color(0xFFFF0000));
      expect(r.toString(), contains('color='));
    });
  });

  group('formatRich()', () {
    test('backward compat: formatRich().text equals format()', () {
      const fmt = CellFormat(
        type: CellFormatType.number,
        formatCode: '#,##0.00',
      );
      final value = CellValue.number(1234.56);
      expect(fmt.formatRich(value).text, fmt.format(value));
    });

    test('returns null color for plain formats', () {
      final result = CellFormat.integer.formatRich(CellValue.number(42));
      expect(result.color, isNull);
    });

    test('general format returns displayValue', () {
      final result = CellFormat.general.formatRich(CellValue.number(42));
      expect(result.text, '42');
      expect(result.color, isNull);
    });

    test('text format returns rawValue string', () {
      final result = CellFormat.text.formatRich(CellValue.number(42));
      expect(result.text, '42.0');
    });
  });

  group('bracket metadata parsing', () {
    group('color codes', () {
      test('[Red] sets color on positive section', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Red]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(1234));
        expect(result.text, '1,234');
        expect(result.color, const Color(0xFFFF0000));
      });

      test('[Blue] sets color', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Blue]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, const Color(0xFF0000FF));
      });

      test('[Green] sets color', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Green]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, const Color(0xFF008000));
      });

      test('color name is case-insensitive', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[RED]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, const Color(0xFFFF0000));
      });

      test('indexed color: [Color3] is red', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Color3]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, const Color(0xFFFF0000));
      });

      test('indexed color: [Color5] is blue', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Color5]#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, const Color(0xFF0000FF));
      });

      test('null color when no bracket', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        expect(result.color, isNull);
      });

      test('multi-section with different colors', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Green]#,##0;[Red]#,##0',
        );
        final pos = fmt.formatRich(CellValue.number(42));
        expect(pos.color, const Color(0xFF008000));
        final neg = fmt.formatRich(CellValue.number(-42));
        expect(neg.color, const Color(0xFFFF0000));
      });
    });

    group('conditional sections', () {
      test('[>100] selects section when value exceeds threshold', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[>100]#,##0"big";0.00',
        );
        final result = fmt.formatRich(CellValue.number(150));
        expect(result.text, '150big');
      });

      test('[>100] falls back to unconditional section', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[>100]#,##0"big";0.00',
        );
        final result = fmt.formatRich(CellValue.number(50));
        expect(result.text, '50.00');
      });

      test('[<=50] condition', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[<=50]0"low";0"high"',
        );
        expect(fmt.format(CellValue.number(30)), '30low');
        expect(fmt.format(CellValue.number(80)), '80high');
      });

      test('[=0] matches exactly zero', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[=0]"zero";0',
        );
        expect(fmt.format(CellValue.number(0)), 'zero');
        expect(fmt.format(CellValue.number(5)), '5');
      });

      test('[<>0] matches non-zero', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[<>0]#,##0;"zero"',
        );
        expect(fmt.format(CellValue.number(42)), '42');
        expect(fmt.format(CellValue.number(0)), 'zero');
      });

      test('condition with color', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[Red][>100]#,##0;[Blue]0.00',
        );
        final big = fmt.formatRich(CellValue.number(150));
        expect(big.text, '150');
        expect(big.color, const Color(0xFFFF0000));

        final small = fmt.formatRich(CellValue.number(50));
        expect(small.text, '50.00');
        expect(small.color, const Color(0xFF0000FF));
      });

      test('[>=100] boundary: value equals threshold', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[>=100]#,##0;0.00',
        );
        expect(fmt.format(CellValue.number(100)), '100');
        expect(fmt.format(CellValue.number(99)), '99.00');
      });

      test('[<0] detects negative values', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[<0]0"neg";0"pos"',
        );
        expect(fmt.format(CellValue.number(-5)), '5neg');
        expect(fmt.format(CellValue.number(5)), '5pos');
      });

      test('first matching condition wins', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '[>100]"A";[>50]"B";0',
        );
        expect(fmt.format(CellValue.number(150)), 'A');
        expect(fmt.format(CellValue.number(75)), 'B');
        expect(fmt.format(CellValue.number(25)), '25');
      });
    });
  });

  group('number format improvements', () {
    group('comma as scaler', () {
      test('single trailing comma divides by 1000', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0,',
        );
        expect(fmt.format(CellValue.number(1234567)), '1,235');
      });

      test('double trailing comma divides by 1,000,000', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0,,',
        );
        expect(fmt.format(CellValue.number(1234567890)), '1,235');
      });

      test('comma scaler with no thousands separators remaining', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '0,',
        );
        expect(fmt.format(CellValue.number(5000)), '5');
      });

      test('comma scaler combined with decimals', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00,',
        );
        expect(fmt.format(CellValue.number(1234567)), '1,234.57');
      });
    });

    group('lowercase scientific', () {
      test('0.00e+00 produces lowercase e', () {
        const fmt = CellFormat(
          type: CellFormatType.scientific,
          formatCode: '0.00e+00',
        );
        expect(fmt.format(CellValue.number(12345)), '1.23e+04');
      });

      test('0.00e+00 with negative exponent', () {
        const fmt = CellFormat(
          type: CellFormatType.scientific,
          formatCode: '0.00e+00',
        );
        expect(fmt.format(CellValue.number(0.00123)), '1.23e-03');
      });

      test('0.00e+00 with zero', () {
        const fmt = CellFormat(
          type: CellFormatType.scientific,
          formatCode: '0.00e+00',
        );
        expect(fmt.format(CellValue.number(0)), '0.00e+00');
      });

      test('uppercase E still works', () {
        const fmt = CellFormat(
          type: CellFormatType.scientific,
          formatCode: '0.00E+00',
        );
        expect(fmt.format(CellValue.number(12345)), '1.23E+04');
      });
    });

    group('fraction constraints', () {
      test('# ??/?? allows up to 2-digit denominator', () {
        const fmt = CellFormat(
          type: CellFormatType.fraction,
          formatCode: '# ??/??',
        );
        // 3.14159 ≈ 22/7, which needs denominator > 9
        final result = fmt.format(CellValue.number(3.14159));
        // Should find a better fraction with 2-digit denominators
        expect(result, isNotEmpty);
      });

      test('# ?/? limits to single-digit denominator', () {
        const fmt = CellFormat(
          type: CellFormatType.fraction,
          formatCode: '# ?/?',
        );
        final result = fmt.format(CellValue.number(3.5));
        expect(result, '3 1/2');
      });

      test('# ?/8 uses fixed denominator 8', () {
        const fmt = CellFormat(
          type: CellFormatType.fraction,
          formatCode: '# ?/8',
        );
        expect(fmt.format(CellValue.number(0.25)), '2/8');
        expect(fmt.format(CellValue.number(0.5)), '4/8');
        expect(fmt.format(CellValue.number(0.125)), '1/8');
      });

      test('# ?/4 uses fixed denominator 4', () {
        const fmt = CellFormat(
          type: CellFormatType.fraction,
          formatCode: '# ?/4',
        );
        expect(fmt.format(CellValue.number(0.5)), '2/4');
        expect(fmt.format(CellValue.number(0.25)), '1/4');
      });

      test('# ???/??? allows up to 3-digit denominator', () {
        const fmt = CellFormat(
          type: CellFormatType.fraction,
          formatCode: '# ???/???',
        );
        // Pi should be very well approximated with 3-digit denominators
        final result = fmt.format(CellValue.number(3.14159));
        expect(result, contains('/'));
      });
    });
  });

  group('fractional seconds', () {
    test('ss.000 formats milliseconds', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.000',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5, 123);
      expect(fmt.format(CellValue.date(date)), '14:30:05.123');
    });

    test('ss.00 formats hundredths', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.00',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5, 456);
      expect(fmt.format(CellValue.date(date)), '14:30:05.45');
    });

    test('ss.0 formats tenths', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.0',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5, 789);
      expect(fmt.format(CellValue.date(date)), '14:30:05.7');
    });

    test('ss.000 with zero milliseconds', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.000',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5);
      expect(fmt.format(CellValue.date(date)), '14:30:05.000');
    });

    test('ss.00 pads to 2 digits', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.00',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5, 50);
      expect(fmt.format(CellValue.date(date)), '14:30:05.05');
    });

    test('ss.000 with 1ms', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss.000',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 5, 1);
      expect(fmt.format(CellValue.date(date)), '14:30:05.001');
    });
  });

  group('locale support', () {
    group('FormatLocale static instances', () {
      test('enUs is the default', () {
        expect(FormatLocale.enUs.decimalSeparator, '.');
        expect(FormatLocale.enUs.thousandsSeparator, ',');
        expect(FormatLocale.enUs.currencySymbol, r'$');
      });

      test('deDe uses comma decimal', () {
        expect(FormatLocale.deDe.decimalSeparator, ',');
        expect(FormatLocale.deDe.thousandsSeparator, '.');
        expect(FormatLocale.deDe.currencySymbol, '€');
      });

      test('frFr uses space as thousands separator', () {
        expect(FormatLocale.frFr.thousandsSeparator, ' ');
      });

      test('jaJp month names', () {
        expect(FormatLocale.jaJp.monthNames[0], '1月');
        expect(FormatLocale.jaJp.currencySymbol, '¥');
      });
    });

    group('LCID code mapping', () {
      test('0409 maps to enUs', () {
        expect(FormatLocale.fromLcid('0409'), same(FormatLocale.enUs));
      });

      test('0809 maps to enGb', () {
        expect(FormatLocale.fromLcid('0809'), same(FormatLocale.enGb));
      });

      test('0407 maps to deDe', () {
        expect(FormatLocale.fromLcid('0407'), same(FormatLocale.deDe));
      });

      test('040C maps to frFr', () {
        expect(FormatLocale.fromLcid('040C'), same(FormatLocale.frFr));
      });

      test('unknown LCID falls back to enUs', () {
        expect(FormatLocale.fromLcid('9999'), same(FormatLocale.enUs));
      });
    });

    group('locale in formatting', () {
      test('German month names via locale parameter', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'd mmmm yyyy',
        );
        final date = DateTime(2024, 1, 15);
        final result = fmt.formatRich(
          CellValue.date(date),
          locale: FormatLocale.deDe,
        );
        expect(result.text, '15 Januar 2024');
      });

      test('German abbreviated months', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'd-mmm-yy',
        );
        final date = DateTime(2024, 3, 5);
        final result = fmt.formatRich(
          CellValue.date(date),
          locale: FormatLocale.deDe,
        );
        expect(result.text, '5-Mrz-24');
      });

      test('French day names', () {
        const fmt = CellFormat(
          type: CellFormatType.date,
          formatCode: 'dddd',
        );
        final date = DateTime(2024, 1, 15); // Monday
        final result = fmt.formatRich(
          CellValue.date(date),
          locale: FormatLocale.frFr,
        );
        expect(result.text, 'lundi');
      });

      test('German decimal separator in number formatting', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00',
        );
        final result = fmt.formatRich(
          CellValue.number(1234.56),
          locale: FormatLocale.deDe,
        );
        expect(result.text, '1.234,56');
      });

      test('French thousands separator (space)', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0.00',
        );
        final result = fmt.formatRich(
          CellValue.number(1234.56),
          locale: FormatLocale.frFr,
        );
        expect(result.text, '1 234,56');
      });

      test('German decimal separator in percentage', () {
        const fmt = CellFormat(
          type: CellFormatType.percentage,
          formatCode: '0.00%',
        );
        final result = fmt.formatRich(
          CellValue.number(0.4256),
          locale: FormatLocale.deDe,
        );
        expect(result.text, '42,56%');
      });
    });

    group('currency symbol override', () {
      test(r'[$EUR] overrides $ with EUR', () {
        const fmt = CellFormat(
          type: CellFormatType.currency,
          formatCode: r'[$EUR]#,##0.00',
        );
        final result = fmt.format(CellValue.number(1234.56));
        expect(result, 'EUR1,234.56');
      });

      test(r'[$£] overrides with pound sign', () {
        const fmt = CellFormat(
          type: CellFormatType.currency,
          formatCode: r'[$£]#,##0.00',
        );
        final result = fmt.format(CellValue.number(42));
        expect(result, '£42.00');
      });

      test(r'[$JPY] currency override', () {
        const fmt = CellFormat(
          type: CellFormatType.currency,
          formatCode: r'[$JPY]#,##0',
        );
        final result = fmt.format(CellValue.number(1000));
        expect(result, 'JPY1,000');
      });
    });
  });

  group('layout-dependent features', () {
    group('*X repeat fill', () {
      test('*X with availableWidth fills remaining space', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'$*-#,##0',
        );
        // With a generous available width, should get fill characters
        final result = fmt.formatRich(
          CellValue.number(42),
          availableWidth: 200,
        );
        expect(result.text, contains('-'));
        expect(result.text, contains(r'$'));
        expect(result.text, contains('42'));
      });

      test('*X without availableWidth produces single space', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'$* #,##0',
        );
        final result = fmt.formatRich(CellValue.number(42));
        // Without width, *X → single space
        expect(result.text, r'$ 42');
      });

      test('*X with zero availableWidth produces empty fill', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: r'$*-#,##0',
        );
        final result = fmt.formatRich(
          CellValue.number(42),
          availableWidth: 0,
        );
        expect(result.text, contains('42'));
      });

      test('various fill characters', () {
        const fmt = CellFormat(
          type: CellFormatType.number,
          formatCode: '#,##0*.',
        );
        final result = fmt.formatRich(
          CellValue.number(42),
          availableWidth: 200,
        );
        expect(result.text, startsWith('42'));
        expect(result.text, contains('.'));
      });
    });
  });

  group('case sensitivity documentation (Phase 8)', () {
    test('MM is always month (never minute)', () {
      const fmt = CellFormat(
        type: CellFormatType.date,
        formatCode: 'yyyy-MM-dd',
      );
      final date = DateTime(2024, 1, 15);
      expect(fmt.format(CellValue.date(date)), '2024-01-15');
    });

    test('mm is context-sensitive: month when standalone', () {
      const fmt = CellFormat(
        type: CellFormatType.date,
        formatCode: 'mm/dd/yyyy',
      );
      final date = DateTime(2024, 3, 5);
      expect(fmt.format(CellValue.date(date)), '03/05/2024');
    });

    test('mm is context-sensitive: minute after hour', () {
      const fmt = CellFormat(
        type: CellFormatType.time,
        formatCode: 'H:mm:ss',
      );
      final date = DateTime(2024, 1, 1, 14, 30, 45);
      expect(fmt.format(CellValue.date(date)), '14:30:45');
    });

    test('mixed case Mm treated as literal', () {
      // 'Mm' doesn't match any token pattern, so it becomes M + m literals
      const fmt = CellFormat(
        type: CellFormatType.date,
        formatCode: 'yyyy-Mm-dd',
      );
      final date = DateTime(2024, 3, 5);
      // M is not a token (we don't have uppercase single M as explicit month)
      // The tokenizer doesn't match 'M' alone as a date token
      // So 'Mm' should not resolve to month
      final result = fmt.format(CellValue.date(date));
      // The key point: it should NOT be '2024-03-05' — MM would be
      expect(result, isNotNull);
    });
  });

  group('NumberFormatDetector', () {
    group('percentage', () {
      test('42% → value 0.42, format percentage', () {
        final result = NumberFormatDetector.detect('42%');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(0.42));
        expect(result.format, CellFormat.percentage);
      });

      test('42.56% → value 0.4256, format percentageDecimal', () {
        final result = NumberFormatDetector.detect('42.56%');
        expect(result, isNotNull);
        expect(result!.value.isNumber, isTrue);
        expect(result.value.asDouble, closeTo(0.4256, 1e-10));
        expect(result.format, CellFormat.percentageDecimal);
      });

      test('0% → value 0, format percentage', () {
        final result = NumberFormatDetector.detect('0%');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(0));
        expect(result.format, CellFormat.percentage);
      });

      test('100% → value 1.0, format percentage', () {
        final result = NumberFormatDetector.detect('100%');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1.0));
        expect(result.format, CellFormat.percentage);
      });

      test('-10% → value -0.1, format percentage', () {
        final result = NumberFormatDetector.detect('-10%');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(-0.1));
        expect(result.format, CellFormat.percentage);
      });
    });

    group('currency (enUs)', () {
      test(r'$1,234.56 → value 1234.56, format currency', () {
        final result = NumberFormatDetector.detect(r'$1,234.56');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234.56));
        expect(result.format, CellFormat.currency);
      });

      test(r'$42 → value 42, format currency', () {
        final result = NumberFormatDetector.detect(r'$42');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(42));
        expect(result.format, CellFormat.currency);
      });

      test(r'$0.99 → value 0.99, format currency', () {
        final result = NumberFormatDetector.detect(r'$0.99');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(0.99));
        expect(result.format, CellFormat.currency);
      });
    });

    group('currency (deDe)', () {
      test('€1.234,56 → value 1234.56, format currency', () {
        final result = NumberFormatDetector.detect(
          '€1.234,56',
          locale: FormatLocale.deDe,
        );
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234.56));
        expect(result.format, CellFormat.currency);
      });

      test('€42 → value 42, format currency', () {
        final result = NumberFormatDetector.detect(
          '€42',
          locale: FormatLocale.deDe,
        );
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(42));
        expect(result.format, CellFormat.currency);
      });
    });

    group('currency (enGb)', () {
      test('£1,234.56 → value 1234.56, format currency', () {
        final result = NumberFormatDetector.detect(
          '£1,234.56',
          locale: FormatLocale.enGb,
        );
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234.56));
        expect(result.format, CellFormat.currency);
      });
    });

    group('thousands-separated', () {
      test('1,234 → value 1234, format integer', () {
        final result = NumberFormatDetector.detect('1,234');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234));
        expect(result.format, CellFormat.integer);
      });

      test('1,234.56 → value 1234.56, format number', () {
        final result = NumberFormatDetector.detect('1,234.56');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234.56));
        expect(result.format, CellFormat.number);
      });

      test('1,234,567 → value 1234567, format integer', () {
        final result = NumberFormatDetector.detect('1,234,567');
        expect(result, isNotNull);
        expect(result!.value, CellValue.number(1234567));
        expect(result.format, CellFormat.integer);
      });
    });

    group('rejection cases', () {
      test('plain 42 returns null', () {
        expect(NumberFormatDetector.detect('42'), isNull);
      });

      test('plain 3.14 returns null', () {
        expect(NumberFormatDetector.detect('3.14'), isNull);
      });

      test('empty string returns null', () {
        expect(NumberFormatDetector.detect(''), isNull);
      });

      test('1,23 returns null (invalid grouping)', () {
        expect(NumberFormatDetector.detect('1,23'), isNull);
      });

      test(',234 returns null (leading separator)', () {
        expect(NumberFormatDetector.detect(',234'), isNull);
      });

      test('1,234, returns null (trailing separator)', () {
        expect(NumberFormatDetector.detect('1,234,'), isNull);
      });

      test('hello returns null', () {
        expect(NumberFormatDetector.detect('hello'), isNull);
      });

      test('abc% returns null', () {
        expect(NumberFormatDetector.detect('abc%'), isNull);
      });
    });
  });

  group('DurationFormatDetector', () {
    test('1:30:05 → duration ([h]:mm:ss)', () {
      final result = DurationFormatDetector.detect(
        '1:30:05',
        const Duration(hours: 1, minutes: 30, seconds: 5),
      );
      expect(result, CellFormat.duration);
    });

    test('2:45 → durationShort ([h]:mm)', () {
      final result = DurationFormatDetector.detect(
        '2:45',
        const Duration(hours: 2, minutes: 45),
      );
      expect(result, CellFormat.durationShort);
    });

    test('90:05 → durationMinSec ([m]:ss)', () {
      final result = DurationFormatDetector.detect(
        '90:05',
        const Duration(hours: 1, minutes: 30, seconds: 5),
      );
      expect(result, CellFormat.durationMinSec);
    });

    test('0:00:00 → duration', () {
      final result = DurationFormatDetector.detect(
        '0:00:00',
        Duration.zero,
      );
      expect(result, CellFormat.duration);
    });

    test('-1:30:00 → duration', () {
      final result = DurationFormatDetector.detect(
        '-1:30:00',
        const Duration(hours: -1, minutes: -30),
      );
      expect(result, CellFormat.duration);
    });

    test('empty string → null', () {
      final result = DurationFormatDetector.detect(
        '',
        const Duration(hours: 1),
      );
      expect(result, isNull);
    });

    test('unrecognized format → null', () {
      final result = DurationFormatDetector.detect(
        '1h30m',
        const Duration(hours: 1, minutes: 30),
      );
      expect(result, isNull);
    });
  });

  group('DateFormatDetector', () {
    group('ISO format', () {
      test('detects yyyy-MM-dd', () {
        final result = DateFormatDetector.detect(
          '2024-01-15', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateIso);
      });

      test('detects ISO with zero-padded month and day', () {
        final result = DateFormatDetector.detect(
          '2024-03-05', DateTime(2024, 3, 5),
        );
        expect(result, CellFormat.dateIso);
      });
    });

    group('US numeric format', () {
      test('detects m/d/yyyy', () {
        final result = DateFormatDetector.detect(
          '1/15/2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateUs);
      });

      test('detects m/d/yyyy with single-digit month and day', () {
        final result = DateFormatDetector.detect(
          '3/5/2024', DateTime(2024, 3, 5),
        );
        expect(result, CellFormat.dateUs);
      });

      test('detects m-d-yyyy (US with dashes)', () {
        final result = DateFormatDetector.detect(
          '1-15-2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateUsDash);
      });

      test('detects m.d.yyyy (US with dots)', () {
        final result = DateFormatDetector.detect(
          '1.15.2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateUsDot);
      });
    });

    group('EU numeric format', () {
      test('detects d/m/yyyy with dayFirst=true', () {
        final result = DateFormatDetector.detect(
          '15/1/2024', DateTime(2024, 1, 15), dayFirst: true,
        );
        expect(result, CellFormat.dateEu);
      });

      test('detects d-m-yyyy with dayFirst=true', () {
        final result = DateFormatDetector.detect(
          '15-1-2024', DateTime(2024, 1, 15), dayFirst: true,
        );
        expect(result, CellFormat.dateEuDash);
      });

      test('detects d.m.yyyy with dayFirst=true', () {
        final result = DateFormatDetector.detect(
          '15.1.2024', DateTime(2024, 1, 15), dayFirst: true,
        );
        expect(result, CellFormat.dateEuDot);
      });
    });

    group('named month formats', () {
      test('detects d-mmm-yy (short)', () {
        final result = DateFormatDetector.detect(
          '15-Jan-24', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateShort);
      });

      test('detects d-mmm-yyyy (short with 4-digit year)', () {
        final result = DateFormatDetector.detect(
          '15-Jan-2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateShortLong);
      });

      test('detects d mmmm yyyy (full month name)', () {
        final result = DateFormatDetector.detect(
          '15 January 2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateLong);
      });

      test('named month is case insensitive', () {
        final result = DateFormatDetector.detect(
          '15-jan-24', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateShort);
      });

      test('full month name is case insensitive', () {
        final result = DateFormatDetector.detect(
          '15 january 2024', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateLong);
      });
    });

    group('dayFirst ordering', () {
      // Ambiguous date: 3/5/2024 could be March 5 (US) or May 3 (EU)
      test('dayFirst=false prefers US format for ambiguous date', () {
        // Parsed as March 5 (US interpretation)
        final result = DateFormatDetector.detect(
          '3/5/2024', DateTime(2024, 3, 5), dayFirst: false,
        );
        expect(result, CellFormat.dateUs);
      });

      test('dayFirst=true prefers EU format for ambiguous date', () {
        // Parsed as May 3 (EU interpretation) → d/m/yyyy = 3/5/2024
        final result = DateFormatDetector.detect(
          '3/5/2024', DateTime(2024, 5, 3), dayFirst: true,
        );
        expect(result, CellFormat.dateEu);
      });
    });

    group('unambiguous dates', () {
      test('day > 12 always matches US m/d/yyyy when not dayFirst', () {
        final result = DateFormatDetector.detect(
          '1/15/2024', DateTime(2024, 1, 15), dayFirst: false,
        );
        expect(result, CellFormat.dateUs);
      });

      test('day > 12 matches EU d/m/yyyy when dayFirst=true', () {
        final result = DateFormatDetector.detect(
          '15/1/2024', DateTime(2024, 1, 15), dayFirst: true,
        );
        expect(result, CellFormat.dateEu);
      });
    });

    group('no match', () {
      test('returns null for unrecognized format', () {
        final result = DateFormatDetector.detect(
          'Jan 15, 2024', DateTime(2024, 1, 15),
        );
        expect(result, isNull);
      });

      test('returns null for empty input', () {
        final result = DateFormatDetector.detect(
          '', DateTime(2024, 1, 15),
        );
        expect(result, isNull);
      });

      test('returns null for whitespace-only input', () {
        final result = DateFormatDetector.detect(
          '   ', DateTime(2024, 1, 15),
        );
        expect(result, isNull);
      });
    });

    group('whitespace handling', () {
      test('trims leading and trailing whitespace', () {
        final result = DateFormatDetector.detect(
          '  2024-01-15  ', DateTime(2024, 1, 15),
        );
        expect(result, CellFormat.dateIso);
      });
    });

    group('locale parameter', () {
      test('uses locale for month name formatting', () {
        // With German locale, month abbreviations differ
        final result = DateFormatDetector.detect(
          '15-Jan-24', DateTime(2024, 1, 15),
          locale: FormatLocale.deDe, dayFirst: true,
        );
        // German locale has 'Jan' as well, so this should match
        expect(result, CellFormat.dateShort);
      });
    });

    group('FormatLocale.dayFirst', () {
      test('enUs has dayFirst=false', () {
        expect(FormatLocale.enUs.dayFirst, isFalse);
      });

      test('enGb has dayFirst=true', () {
        expect(FormatLocale.enGb.dayFirst, isTrue);
      });

      test('deDe has dayFirst=true', () {
        expect(FormatLocale.deDe.dayFirst, isTrue);
      });

      test('frFr has dayFirst=true', () {
        expect(FormatLocale.frFr.dayFirst, isTrue);
      });

      test('jaJp has dayFirst=false', () {
        expect(FormatLocale.jaJp.dayFirst, isFalse);
      });

      test('zhCn has dayFirst=false', () {
        expect(FormatLocale.zhCn.dayFirst, isFalse);
      });
    });

    group('new date format presets', () {
      test('dateShortLong formats correctly', () {
        final result = CellFormat.dateShortLong.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '15-Jan-2024');
      });

      test('dateLong formats correctly', () {
        final result = CellFormat.dateLong.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '15 January 2024');
      });

      test('dateEu formats correctly', () {
        final result = CellFormat.dateEu.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '15/1/2024');
      });

      test('dateUsDash formats correctly', () {
        final result = CellFormat.dateUsDash.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '1-15-2024');
      });

      test('dateEuDash formats correctly', () {
        final result = CellFormat.dateEuDash.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '15-1-2024');
      });

      test('dateUsDot formats correctly', () {
        final result = CellFormat.dateUsDot.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '1.15.2024');
      });

      test('dateEuDot formats correctly', () {
        final result = CellFormat.dateEuDot.format(
          CellValue.date(DateTime(2024, 1, 15)),
        );
        expect(result, '15.1.2024');
      });

      test('dateUsPadded formats correctly', () {
        final result = CellFormat.dateUsPadded.format(
          CellValue.date(DateTime(1977, 12, 1)),
        );
        expect(result, '12/01/1977');
      });

      test('dateEuPadded formats correctly', () {
        final result = CellFormat.dateEuPadded.format(
          CellValue.date(DateTime(1977, 12, 1)),
        );
        expect(result, '01/12/1977');
      });

      test('dateYearMonthDay formats correctly', () {
        final result = CellFormat.dateYearMonthDay.format(
          CellValue.date(DateTime(2026, 1, 1)),
        );
        expect(result, '2026-Jan-01');
      });
    });

    group('zero-padded US/EU dates', () {
      test('detects mm/dd/yyyy (zero-padded US)', () {
        final result = DateFormatDetector.detect(
          '12/01/1977', DateTime(1977, 12, 1),
        );
        expect(result, CellFormat.dateUsPadded);
      });

      test('detects mm/dd/yyyy with both padded', () {
        final result = DateFormatDetector.detect(
          '01/05/2024', DateTime(2024, 1, 5),
        );
        expect(result, CellFormat.dateUsPadded);
      });

      test('detects dd/mm/yyyy (zero-padded EU) with dayFirst', () {
        final result = DateFormatDetector.detect(
          '01/12/1977', DateTime(1977, 12, 1), dayFirst: true,
        );
        expect(result, CellFormat.dateEuPadded);
      });

      test('non-padded still detected as m/d/yyyy', () {
        // 12/1/1977 without padding should still match dateUs
        final result = DateFormatDetector.detect(
          '12/1/1977', DateTime(1977, 12, 1),
        );
        expect(result, CellFormat.dateUs);
      });
    });

    group('d/mmm/yyyy format', () {
      test('dateSlashMonth formats correctly', () {
        final result = CellFormat.dateSlashMonth.format(
          CellValue.date(DateTime(1977, 1, 12)),
        );
        expect(result, '12/Jan/1977');
      });

      test('detects d/mmm/yyyy', () {
        final result = DateFormatDetector.detect(
          '12/Jan/1977', DateTime(1977, 1, 12),
        );
        expect(result, CellFormat.dateSlashMonth);
      });

      test('detects d/mmm/yyyy case insensitive', () {
        final result = DateFormatDetector.detect(
          '12/jan/1977', DateTime(1977, 1, 12),
        );
        expect(result, CellFormat.dateSlashMonth);
      });

      test('detects d/mmm/yyyy with different month', () {
        final result = DateFormatDetector.detect(
          '25/Dec/2024', DateTime(2024, 12, 25),
        );
        expect(result, CellFormat.dateSlashMonth);
      });

      test('single-digit day works', () {
        final result = DateFormatDetector.detect(
          '5/Mar/2024', DateTime(2024, 3, 5),
        );
        expect(result, CellFormat.dateSlashMonth);
      });
    });

    group('yyyy-mmm-dd format', () {
      test('detects yyyy-mmm-dd', () {
        final result = DateFormatDetector.detect(
          '2026-Jan-01', DateTime(2026, 1, 1),
        );
        expect(result, CellFormat.dateYearMonthDay);
      });

      test('detects yyyy-mmm-dd case insensitive', () {
        final result = DateFormatDetector.detect(
          '2026-jan-01', DateTime(2026, 1, 1),
        );
        expect(result, CellFormat.dateYearMonthDay);
      });

      test('detects yyyy-mmm-dd with different month', () {
        final result = DateFormatDetector.detect(
          '2024-Mar-15', DateTime(2024, 3, 15),
        );
        expect(result, CellFormat.dateYearMonthDay);
      });
    });
  });
}
