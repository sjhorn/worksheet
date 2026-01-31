import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('Cell', () {
    test('default constructor creates empty cell', () {
      const cell = Cell();
      expect(cell.value, isNull);
      expect(cell.style, isNull);
      expect(cell.format, isNull);
      expect(cell.isEmpty, isTrue);
      expect(cell.hasValue, isFalse);
      expect(cell.hasStyle, isFalse);
      expect(cell.hasFormat, isFalse);
    });

    test('constructor with value only', () {
      const cell = Cell(value: CellValue.text('hello'));
      expect(cell.value, CellValue.text('hello'));
      expect(cell.style, isNull);
      expect(cell.hasValue, isTrue);
      expect(cell.hasStyle, isFalse);
      expect(cell.isEmpty, isFalse);
    });

    test('constructor with style only', () {
      const style = CellStyle(fontSize: 14.0);
      const cell = Cell(style: style);
      expect(cell.value, isNull);
      expect(cell.style, style);
      expect(cell.hasValue, isFalse);
      expect(cell.hasStyle, isTrue);
      expect(cell.isEmpty, isFalse);
    });

    test('constructor with both value and style', () {
      const style = CellStyle(fontWeight: FontWeight.bold);
      const cell = Cell(value: CellValue.text('hi'), style: style);
      expect(cell.value, CellValue.text('hi'));
      expect(cell.style, style);
      expect(cell.hasValue, isTrue);
      expect(cell.hasStyle, isTrue);
    });

    group('named constructors', () {
      test('Cell.text creates text cell', () {
        final cell = Cell.text('hello');
        expect(cell.value, CellValue.text('hello'));
        expect(cell.style, isNull);
      });

      test('Cell.text with style', () {
        const style = CellStyle(fontSize: 12.0);
        final cell = Cell.text('hello', style: style);
        expect(cell.value, CellValue.text('hello'));
        expect(cell.style, style);
      });

      test('Cell.number creates numeric cell', () {
        final cell = Cell.number(42);
        expect(cell.value, CellValue.number(42));
        expect(cell.style, isNull);
      });

      test('Cell.number with style', () {
        const style = CellStyle(textAlignment: CellTextAlignment.right);
        final cell = Cell.number(3.14, style: style);
        expect(cell.value, CellValue.number(3.14));
        expect(cell.style, style);
      });

      test('Cell.boolean creates boolean cell', () {
        final cell = Cell.boolean(true);
        expect(cell.value, CellValue.boolean(true));
        expect(cell.style, isNull);
      });

      test('Cell.formula creates formula cell', () {
        final cell = Cell.formula('=SUM(A1:A10)');
        expect(cell.value, CellValue.formula('=SUM(A1:A10)'));
        expect(cell.style, isNull);
      });

      test('Cell.date creates date cell', () {
        final date = DateTime(2024, 6, 15);
        final cell = Cell.date(date);
        expect(cell.value, CellValue.date(date));
        expect(cell.style, isNull);
      });

      test('Cell.withStyle creates style-only cell', () {
        const style = CellStyle(backgroundColor: Color(0xFFFF0000));
        const cell = Cell.withStyle(style);
        expect(cell.value, isNull);
        expect(cell.style, style);
        expect(cell.hasValue, isFalse);
        expect(cell.hasStyle, isTrue);
      });
    });

    group('equality', () {
      test('equal cells are equal', () {
        final a = Cell.text('hi');
        final b = Cell.text('hi');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different values are not equal', () {
        final a = Cell.text('hi');
        final b = Cell.text('bye');
        expect(a, isNot(equals(b)));
      });

      test('different styles are not equal', () {
        final a = Cell.text('hi', style: const CellStyle(fontSize: 12.0));
        final b = Cell.text('hi', style: const CellStyle(fontSize: 14.0));
        expect(a, isNot(equals(b)));
      });

      test('value vs no value are not equal', () {
        final a = Cell.text('hi');
        const b = Cell();
        expect(a, isNot(equals(b)));
      });

      test('empty cells are equal', () {
        const a = Cell();
        const b = Cell();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    test('toString includes value and style', () {
      final cell = Cell.text('hi');
      expect(cell.toString(), contains('Cell'));
      expect(cell.toString(), contains('value:'));
      expect(cell.toString(), contains('style:'));
      expect(cell.toString(), contains('format:'));
    });

    group('format field', () {
      test('constructor accepts format', () {
        final cell = Cell(
          value: CellValue.number(42),
          format: CellFormat.currency,
        );
        expect(cell.format, CellFormat.currency);
        expect(cell.hasFormat, isTrue);
      });

      test('named constructors accept format', () {
        final cell = Cell.number(1234.56, format: CellFormat.currency);
        expect(cell.format, CellFormat.currency);
        expect(cell.hasFormat, isTrue);

        final textCell = Cell.text('hello', format: CellFormat.text);
        expect(textCell.format, CellFormat.text);

        final dateCell = Cell.date(DateTime(2024), format: CellFormat.dateIso);
        expect(dateCell.format, CellFormat.dateIso);

        final boolCell = Cell.boolean(true, format: CellFormat.general);
        expect(boolCell.format, CellFormat.general);

        final formulaCell =
            Cell.formula('=A1', format: CellFormat.number);
        expect(formulaCell.format, CellFormat.number);
      });

      test('Cell.withStyle has null format', () {
        const cell = Cell.withStyle(CellStyle(fontSize: 12.0));
        expect(cell.format, isNull);
        expect(cell.hasFormat, isFalse);
      });

      test('isEmpty considers format', () {
        const cellWithFormat = Cell(format: CellFormat.currency);
        expect(cellWithFormat.isEmpty, isFalse);

        const emptyCell = Cell();
        expect(emptyCell.isEmpty, isTrue);
      });

      test('equality considers format', () {
        final a = Cell.number(42, format: CellFormat.currency);
        final b = Cell.number(42, format: CellFormat.currency);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        final c = Cell.number(42, format: CellFormat.percentage);
        expect(a, isNot(equals(c)));

        final d = Cell.number(42);
        expect(a, isNot(equals(d)));
      });
    });

    group('displayValue', () {
      test('returns empty string for null value', () {
        const cell = Cell();
        expect(cell.displayValue, '');
      });

      test('uses CellValue.displayValue when no format', () {
        final cell = Cell.number(42);
        expect(cell.displayValue, '42');
      });

      test('uses format when present', () {
        final cell = Cell.number(1234.56, format: CellFormat.currency);
        expect(cell.displayValue, r'$1,234.56');
      });

      test('percentage format', () {
        final cell = Cell.number(0.42, format: CellFormat.percentage);
        expect(cell.displayValue, '42%');
      });

      test('date format', () {
        final cell = Cell.date(
          DateTime(2024, 1, 15),
          format: CellFormat.dateIso,
        );
        expect(cell.displayValue, '2024-01-15');
      });
    });

    group('copyWithFormat', () {
      test('copies with new format', () {
        final original = Cell.number(42, style: const CellStyle(fontSize: 14));
        final copied = original.copyWithFormat(CellFormat.currency);
        expect(copied.value, original.value);
        expect(copied.style, original.style);
        expect(copied.format, CellFormat.currency);
      });

      test('copies with null format', () {
        final original = Cell.number(42, format: CellFormat.currency);
        final copied = original.copyWithFormat(null);
        expect(copied.format, isNull);
        expect(copied.value, original.value);
      });
    });
  });
}
