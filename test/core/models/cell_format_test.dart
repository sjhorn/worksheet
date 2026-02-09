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
}
