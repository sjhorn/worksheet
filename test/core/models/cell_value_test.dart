import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/models/cell_value.dart';

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
  });
}
