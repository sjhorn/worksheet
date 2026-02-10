import 'package:any_date/any_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('CellValue', () {
    group('CellValue.text', () {
      test('creates text value', () {
        final value = CellValue.text('Hello');
        expect(value.type, CellValueType.text);
        expect(value.rawValue, 'Hello');
        expect(value.displayValue, 'Hello');
      });

      test('handles empty string', () {
        final value = CellValue.text('');
        expect(value.type, CellValueType.text);
        expect(value.rawValue, '');
        expect(value.displayValue, '');
      });

      test('preserves whitespace', () {
        final value = CellValue.text('  spaces  ');
        expect(value.rawValue, '  spaces  ');
      });

      test('handles multiline text', () {
        final value = CellValue.text('line1\nline2');
        expect(value.rawValue, 'line1\nline2');
      });
    });

    group('CellValue.number', () {
      test('creates integer value', () {
        final value = CellValue.number(42);
        expect(value.type, CellValueType.number);
        expect(value.rawValue, 42.0);
        expect(value.displayValue, '42');
      });

      test('creates double value', () {
        final value = CellValue.number(3.14159);
        expect(value.type, CellValueType.number);
        expect(value.rawValue, 3.14159);
      });

      test('handles zero', () {
        final value = CellValue.number(0);
        expect(value.rawValue, 0.0);
        expect(value.displayValue, '0');
      });

      test('handles negative numbers', () {
        final value = CellValue.number(-42.5);
        expect(value.rawValue, -42.5);
      });

      test('handles very large numbers', () {
        final value = CellValue.number(1e15);
        expect(value.rawValue, 1e15);
      });

      test('handles very small numbers', () {
        final value = CellValue.number(1e-10);
        expect(value.rawValue, 1e-10);
      });

      test('isInteger returns true for whole numbers', () {
        expect(CellValue.number(42).isInteger, isTrue);
        expect(CellValue.number(42.0).isInteger, isTrue);
        expect(CellValue.number(-5).isInteger, isTrue);
      });

      test('isInteger returns false for decimals', () {
        expect(CellValue.number(42.5).isInteger, isFalse);
        expect(CellValue.number(0.1).isInteger, isFalse);
      });

      test('asInt returns integer value', () {
        expect(CellValue.number(42).asInt, 42);
        expect(CellValue.number(42.9).asInt, 42);
      });

      test('asDouble returns double value', () {
        expect(CellValue.number(42).asDouble, 42.0);
        expect(CellValue.number(3.14).asDouble, 3.14);
      });
    });

    group('CellValue.boolean', () {
      test('creates true value', () {
        final value = CellValue.boolean(true);
        expect(value.type, CellValueType.boolean);
        expect(value.rawValue, true);
        expect(value.displayValue, 'TRUE');
      });

      test('creates false value', () {
        final value = CellValue.boolean(false);
        expect(value.type, CellValueType.boolean);
        expect(value.rawValue, false);
        expect(value.displayValue, 'FALSE');
      });
    });

    group('CellValue.formula', () {
      test('creates formula value', () {
        final value = CellValue.formula('=SUM(A1:A10)');
        expect(value.type, CellValueType.formula);
        expect(value.rawValue, '=SUM(A1:A10)');
      });

      test('formula is stored as-is', () {
        final value = CellValue.formula('=A1+B1');
        expect(value.rawValue, '=A1+B1');
      });

      test('displayValue shows formula by default', () {
        final value = CellValue.formula('=A1+B1');
        expect(value.displayValue, '=A1+B1');
      });
    });

    group('CellValue.error', () {
      test('creates error value', () {
        final value = CellValue.error('#DIV/0!');
        expect(value.type, CellValueType.error);
        expect(value.rawValue, '#DIV/0!');
        expect(value.displayValue, '#DIV/0!');
      });

      test('handles various error types', () {
        expect(CellValue.error('#VALUE!').rawValue, '#VALUE!');
        expect(CellValue.error('#REF!').rawValue, '#REF!');
        expect(CellValue.error('#NAME?').rawValue, '#NAME?');
        expect(CellValue.error('#N/A').rawValue, '#N/A');
      });
    });

    group('CellValue.date', () {
      test('creates date value', () {
        final date = DateTime(2024, 1, 15);
        final value = CellValue.date(date);
        expect(value.type, CellValueType.date);
        expect(value.rawValue, date);
      });

      test('asDateTime returns the date', () {
        final date = DateTime(2024, 1, 15, 10, 30);
        final value = CellValue.date(date);
        expect(value.asDateTime, date);
      });
    });

    group('CellValue.duration', () {
      test('creates duration value', () {
        const d = Duration(hours: 1, minutes: 30, seconds: 5);
        final value = CellValue.duration(d);
        expect(value.type, CellValueType.duration);
        expect(value.rawValue, d);
      });

      test('isDuration returns true', () {
        expect(CellValue.duration(Duration.zero).isDuration, isTrue);
        expect(CellValue.number(42).isDuration, isFalse);
      });

      test('asDuration returns the duration', () {
        const d = Duration(hours: 2, minutes: 15);
        final value = CellValue.duration(d);
        expect(value.asDuration, d);
      });

      test('displayValue formats as H:mm:ss', () {
        const d = Duration(hours: 1, minutes: 30, seconds: 5);
        expect(CellValue.duration(d).displayValue, '1:30:05');
      });

      test('displayValue for zero duration', () {
        expect(CellValue.duration(Duration.zero).displayValue, '0:00:00');
      });

      test('displayValue for negative duration', () {
        const d = Duration(hours: 1, minutes: 30);
        expect(CellValue.duration(-d).displayValue, '-1:30:00');
      });
    });

    group('equality', () {
      test('text values with same content are equal', () {
        final a = CellValue.text('Hello');
        final b = CellValue.text('Hello');
        expect(a, b);
      });

      test('text values with different content are not equal', () {
        final a = CellValue.text('Hello');
        final b = CellValue.text('World');
        expect(a == b, isFalse);
      });

      test('number values with same content are equal', () {
        final a = CellValue.number(42);
        final b = CellValue.number(42.0);
        expect(a, b);
      });

      test('number values with different content are not equal', () {
        final a = CellValue.number(42);
        final b = CellValue.number(43);
        expect(a == b, isFalse);
      });

      test('different types are not equal', () {
        final text = CellValue.text('42');
        final number = CellValue.number(42);
        expect(text == number, isFalse);
      });

      test('boolean values are equal', () {
        final a = CellValue.boolean(true);
        final b = CellValue.boolean(true);
        expect(a, b);
      });
    });

    group('hashCode', () {
      test('equal values have same hashCode', () {
        final a = CellValue.text('Hello');
        final b = CellValue.text('Hello');
        expect(a.hashCode, b.hashCode);
      });

      test('can be used in set', () {
        final set = <CellValue>{};
        set.add(CellValue.text('Hello'));
        set.add(CellValue.text('Hello'));
        expect(set.length, 1);
      });

      test('can be used as map key', () {
        final map = <CellValue, String>{};
        map[CellValue.number(42)] = 'test';
        expect(map[CellValue.number(42)], 'test');
      });
    });

    group('toString', () {
      test('text value', () {
        expect(CellValue.text('Hello').toString(), 'CellValue.text(Hello)');
      });

      test('number value', () {
        expect(CellValue.number(42).toString(), 'CellValue.number(42.0)');
      });

      test('boolean value', () {
        expect(CellValue.boolean(true).toString(), 'CellValue.boolean(true)');
      });

      test('formula value', () {
        expect(CellValue.formula('=A1').toString(), 'CellValue.formula(=A1)');
      });

      test('error value', () {
        expect(CellValue.error('#DIV/0!').toString(), 'CellValue.error(#DIV/0!)');
      });
    });

    group('type checking', () {
      test('isText', () {
        expect(CellValue.text('Hello').isText, isTrue);
        expect(CellValue.number(42).isText, isFalse);
      });

      test('isNumber', () {
        expect(CellValue.number(42).isNumber, isTrue);
        expect(CellValue.text('42').isNumber, isFalse);
      });

      test('isBoolean', () {
        expect(CellValue.boolean(true).isBoolean, isTrue);
        expect(CellValue.text('true').isBoolean, isFalse);
      });

      test('isFormula', () {
        expect(CellValue.formula('=A1').isFormula, isTrue);
        expect(CellValue.text('=A1').isFormula, isFalse);
      });

      test('isError', () {
        expect(CellValue.error('#DIV/0!').isError, isTrue);
        expect(CellValue.text('#DIV/0!').isError, isFalse);
      });

      test('isDate', () {
        expect(CellValue.date(DateTime.now()).isDate, isTrue);
        expect(CellValue.text('2024-01-15').isDate, isFalse);
      });
    });

    group('parse', () {
      group('empty / whitespace', () {
        test('empty string returns null', () {
          expect(CellValue.parse(''), isNull);
        });

        test('whitespace-only returns null', () {
          expect(CellValue.parse('   '), isNull);
        });

        test('tab-only returns null', () {
          expect(CellValue.parse('\t'), isNull);
        });
      });

      group('formulas', () {
        test('=SUM(A1:A5) is parsed as formula', () {
          final result = CellValue.parse('=SUM(A1:A5)');
          expect(result, const CellValue.formula('=SUM(A1:A5)'));
        });

        test('=A1+B1 is parsed as formula', () {
          final result = CellValue.parse('=A1+B1');
          expect(result, const CellValue.formula('=A1+B1'));
        });

        test('formula with leading whitespace is trimmed', () {
          final result = CellValue.parse('  =SUM(A1)  ');
          expect(result, const CellValue.formula('=SUM(A1)'));
        });

        test('=SUM(A1:A5) with allowFormulas:false becomes text', () {
          final result =
              CellValue.parse('=SUM(A1:A5)', allowFormulas: false);
          expect(result, const CellValue.text('=SUM(A1:A5)'));
        });

        test('=IMPORTRANGE(...) with allowFormulas:false becomes text', () {
          final result = CellValue.parse('=IMPORTRANGE("url","A1")',
              allowFormulas: false);
          expect(
            result,
            const CellValue.text('=IMPORTRANGE("url","A1")'),
          );
        });
      });

      group('booleans', () {
        test('TRUE is parsed as boolean true', () {
          expect(CellValue.parse('TRUE'), const CellValue.boolean(true));
        });

        test('FALSE is parsed as boolean false', () {
          expect(CellValue.parse('FALSE'), const CellValue.boolean(false));
        });

        test('true (lowercase) is parsed as boolean', () {
          expect(CellValue.parse('true'), const CellValue.boolean(true));
        });

        test('false (lowercase) is parsed as boolean', () {
          expect(CellValue.parse('false'), const CellValue.boolean(false));
        });

        test('True (mixed case) is parsed as boolean', () {
          expect(CellValue.parse('True'), const CellValue.boolean(true));
        });

        test('boolean with surrounding whitespace is trimmed', () {
          expect(CellValue.parse(' true '), const CellValue.boolean(true));
        });
      });

      group('numbers', () {
        test('integer string is parsed as number', () {
          final result = CellValue.parse('42');
          expect(result, CellValue.number(42));
          expect(result!.isNumber, isTrue);
        });

        test('decimal string is parsed as number', () {
          expect(CellValue.parse('3.14'), CellValue.number(3.14));
        });

        test('negative number is parsed', () {
          expect(CellValue.parse('-7'), CellValue.number(-7));
        });

        test('scientific notation is parsed as number', () {
          expect(CellValue.parse('1e10'), CellValue.number(1e10));
        });

        test('number with whitespace is trimmed', () {
          expect(CellValue.parse(' 42 '), CellValue.number(42));
        });

        test('zero is parsed as number', () {
          expect(CellValue.parse('0'), CellValue.number(0));
        });

        test('Infinity is parsed as number', () {
          final result = CellValue.parse('Infinity');
          expect(result!.isNumber, isTrue);
          expect(result.asDouble, double.infinity);
        });

        test('NaN is parsed as number', () {
          final result = CellValue.parse('NaN');
          expect(result!.isNumber, isTrue);
          expect(result.asDouble.isNaN, isTrue);
        });

        test('42 is number, NOT a date', () {
          final result = CellValue.parse('42');
          expect(result!.isNumber, isTrue);
          expect(result.isDate, isFalse);
        });

        test('20250115 (bare digits) is number, not date', () {
          final result = CellValue.parse('20250115');
          expect(result!.isNumber, isTrue);
        });
      });

      group('dates', () {
        test('ISO date 2025-01-15 is parsed as date', () {
          final result = CellValue.parse('2025-01-15');
          expect(result!.isDate, isTrue);
          expect(result.asDateTime, DateTime(2025, 1, 15));
        });

        test('ISO datetime 2025-01-15T10:30:00 is parsed as date', () {
          final result = CellValue.parse('2025-01-15T10:30:00');
          expect(result!.isDate, isTrue);
          expect(result.asDateTime, DateTime(2025, 1, 15, 10, 30));
        });

        test('Jan 15, 2025 is parsed as date', () {
          final result = CellValue.parse('Jan 15, 2025');
          expect(result!.isDate, isTrue);
          expect(result.asDateTime.year, 2025);
          expect(result.asDateTime.month, 1);
          expect(result.asDateTime.day, 15);
        });

        test('15/01/2025 with dayFirst parser is Jan 15', () {
          final parser =
              AnyDate(info: const DateParserInfo(dayFirst: true));
          final result =
              CellValue.parse('15/01/2025', dateParser: parser);
          expect(result!.isDate, isTrue);
          expect(result.asDateTime, DateTime(2025, 1, 15));
        });

        test('null dateParser uses default AnyDate', () {
          // ISO format should work with default parser
          final result = CellValue.parse('2025-06-30');
          expect(result!.isDate, isTrue);
          expect(result.asDateTime, DateTime(2025, 6, 30));
        });
      });

      group('duration parsing', () {
        test('1:30:05 parses as duration', () {
          final result = CellValue.parse('1:30:05');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration,
              const Duration(hours: 1, minutes: 30, seconds: 5));
        });

        test('0:45 parses as duration (h:mm)', () {
          final result = CellValue.parse('0:45');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration, const Duration(minutes: 45));
        });

        test('-1:30:00 parses as negative duration', () {
          final result = CellValue.parse('-1:30:00');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration,
              const Duration(hours: -1, minutes: -30));
        });

        test('100:00:00 parses as 100 hours', () {
          final result = CellValue.parse('100:00:00');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration, const Duration(hours: 100));
        });

        test('1:60:00 returns null (invalid minutes)', () {
          final result = CellValue.parse('1:60:00');
          expect(result!.isDuration, isFalse);
        });

        test('1:3 returns non-duration (not zero-padded)', () {
          final result = CellValue.parse('1:3');
          expect(result!.isDuration, isFalse);
        });

        test('14:30 parses as duration, not date', () {
          final result = CellValue.parse('14:30');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration,
              const Duration(hours: 14, minutes: 30));
        });

        test('0:00:00 parses as zero duration', () {
          final result = CellValue.parse('0:00:00');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration, Duration.zero);
        });

        test('1:00:59 parses correctly', () {
          final result = CellValue.parse('1:00:59');
          expect(result!.isDuration, isTrue);
          expect(result.asDuration,
              const Duration(hours: 1, seconds: 59));
        });

        test('1:00:60 returns null (invalid seconds)', () {
          final result = CellValue.parse('1:00:60');
          expect(result!.isDuration, isFalse);
        });
      });

      group('text fallback', () {
        test('plain text is parsed as text', () {
          expect(CellValue.parse('hello'), const CellValue.text('hello'));
        });

        test('text with whitespace is trimmed', () {
          expect(
              CellValue.parse(' hello '), const CellValue.text('hello'));
        });

        test('non-date non-number string is text', () {
          expect(CellValue.parse('abc123xyz'),
              const CellValue.text('abc123xyz'));
        });
      });
    });
  });
}
