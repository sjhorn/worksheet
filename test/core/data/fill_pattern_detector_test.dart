import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/fill_pattern_detector.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('FillPatternDetector', () {
    group('constant pattern', () {
      test('detects single cell as constant', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(42),
        ]);

        expect(pattern.type, FillPatternType.constant);
        expect(pattern.generate(0)?.value, CellValue.number(42));
        expect(pattern.generate(1)?.value, CellValue.number(42));
        expect(pattern.generate(10)?.value, CellValue.number(42));
      });

      test('detects all identical values as constant', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Hello'),
          Cell.text('Hello'),
          Cell.text('Hello'),
        ]);

        expect(pattern.type, FillPatternType.constant);
        expect(pattern.generate(0)?.value, CellValue.text('Hello'));
        expect(pattern.generate(5)?.value, CellValue.text('Hello'));
      });

      test('empty list returns constant null pattern', () {
        final pattern = FillPatternDetector.detect([]);

        expect(pattern.type, FillPatternType.constant);
        expect(pattern.generate(0), isNull);
        expect(pattern.generate(5), isNull);
      });

      test('all null cells returns constant null pattern', () {
        final pattern = FillPatternDetector.detect([null, null, null]);

        expect(pattern.type, FillPatternType.constant);
        expect(pattern.generate(0), isNull);
      });
    });

    group('linear numeric pattern', () {
      test('detects step of 1', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(1),
          Cell.number(2),
          Cell.number(3),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
        expect(pattern.generate(0)?.value, CellValue.number(1));
        expect(pattern.generate(3)?.value, CellValue.number(4));
        expect(pattern.generate(4)?.value, CellValue.number(5));
      });

      test('detects step of 10', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(10),
          Cell.number(20),
          Cell.number(30),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
        expect(pattern.generate(3)?.value, CellValue.number(40));
      });

      test('detects negative step', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(30),
          Cell.number(20),
          Cell.number(10),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
        expect(pattern.generate(3)?.value, CellValue.number(0));
      });

      test('detects decimal step', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(0.5),
          Cell.number(1.0),
          Cell.number(1.5),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
        expect(pattern.generate(3)?.value, CellValue.number(2.0));
      });

      test('detects two-cell linear sequence', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(5),
          Cell.number(10),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
        expect(pattern.generate(2)?.value, CellValue.number(15));
      });

      test('preserves style through generate', () {
        const style = CellStyle(backgroundColor: Color(0xFF00FF00));
        final pattern = FillPatternDetector.detect([
          Cell.number(1, style: style),
          Cell.number(2, style: style),
          Cell.number(3, style: style),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.number(4));
        expect(generated?.style, style);
      });

      test('preserves format through generate', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(100, format: CellFormat.currency),
          Cell.number(200, format: CellFormat.currency),
          Cell.number(300, format: CellFormat.currency),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.number(400));
        expect(generated?.format, CellFormat.currency);
      });

      test('preserves richText through generate', () {
        const spans = [
          TextSpan(
            text: '1',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ];
        final pattern = FillPatternDetector.detect([
          Cell.number(1, richText: spans),
          Cell.number(2, richText: spans),
          Cell.number(3, richText: spans),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.number(4));
        expect(generated?.richText, spans);
      });
    });

    group('date sequence pattern', () {
      test('detects daily sequence', () {
        final pattern = FillPatternDetector.detect([
          Cell.date(DateTime(2024, 1, 1)),
          Cell.date(DateTime(2024, 1, 2)),
          Cell.date(DateTime(2024, 1, 3)),
        ]);

        expect(pattern.type, FillPatternType.dateSequence);
        expect(
          pattern.generate(3)?.value,
          CellValue.date(DateTime(2024, 1, 4)),
        );
        expect(
          pattern.generate(4)?.value,
          CellValue.date(DateTime(2024, 1, 5)),
        );
      });

      test('detects weekly sequence', () {
        final pattern = FillPatternDetector.detect([
          Cell.date(DateTime(2024, 1, 1)),
          Cell.date(DateTime(2024, 1, 8)),
          Cell.date(DateTime(2024, 1, 15)),
        ]);

        expect(pattern.type, FillPatternType.dateSequence);
        expect(
          pattern.generate(3)?.value,
          CellValue.date(DateTime(2024, 1, 22)),
        );
      });

      test('preserves style and format on dates', () {
        const style = CellStyle(backgroundColor: Color(0xFFFF0000));
        final pattern = FillPatternDetector.detect([
          Cell.date(DateTime(2024, 1, 1), style: style),
          Cell.date(DateTime(2024, 1, 2), style: style),
        ]);

        final generated = pattern.generate(2);
        expect(generated?.style, style);
      });

      test('preserves richText on dates', () {
        const spans = [
          TextSpan(
            text: '2024-01-01',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ];
        final pattern = FillPatternDetector.detect([
          Cell(value: CellValue.date(DateTime(2024, 1, 1)), richText: spans),
          Cell(value: CellValue.date(DateTime(2024, 1, 2)), richText: spans),
          Cell(value: CellValue.date(DateTime(2024, 1, 3)), richText: spans),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.date(DateTime(2024, 1, 4)));
        expect(generated?.richText, spans);
      });
    });

    group('text with numeric suffix pattern', () {
      test('detects Item1, Item2, Item3', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Item1'),
          Cell.text('Item2'),
          Cell.text('Item3'),
        ]);

        expect(pattern.type, FillPatternType.textWithNumericSuffix);
        expect(pattern.generate(3)?.value, CellValue.text('Item4'));
        expect(pattern.generate(4)?.value, CellValue.text('Item5'));
      });

      test('detects Q1, Q2, Q3', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Q1'),
          Cell.text('Q2'),
          Cell.text('Q3'),
        ]);

        expect(pattern.type, FillPatternType.textWithNumericSuffix);
        expect(pattern.generate(3)?.value, CellValue.text('Q4'));
      });

      test('detects Row10, Row20', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Row10'),
          Cell.text('Row20'),
        ]);

        expect(pattern.type, FillPatternType.textWithNumericSuffix);
        expect(pattern.generate(2)?.value, CellValue.text('Row30'));
      });

      test('preserves style on text suffix pattern', () {
        const style = CellStyle(backgroundColor: Color(0xFF0000FF));
        final pattern = FillPatternDetector.detect([
          Cell.text('A1', style: style),
          Cell.text('A2', style: style),
          Cell.text('A3', style: style),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.text('A4'));
        expect(generated?.style, style);
      });

      test('preserves richText on text suffix pattern', () {
        const spans = [
          TextSpan(
            text: 'A1',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ];
        final pattern = FillPatternDetector.detect([
          Cell.text('A1', richText: spans),
          Cell.text('A2', richText: spans),
          Cell.text('A3', richText: spans),
        ]);

        final generated = pattern.generate(3);
        expect(generated?.value, CellValue.text('A4'));
        expect(generated?.richText, spans);
      });
    });

    group('repeating cycle pattern', () {
      test('detects A, B, C cycle', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('A'),
          Cell.text('B'),
          Cell.text('C'),
        ]);

        expect(pattern.type, FillPatternType.repeatingCycle);
        expect(pattern.generate(0)?.value, CellValue.text('A'));
        expect(pattern.generate(1)?.value, CellValue.text('B'));
        expect(pattern.generate(2)?.value, CellValue.text('C'));
        expect(pattern.generate(3)?.value, CellValue.text('A'));
        expect(pattern.generate(4)?.value, CellValue.text('B'));
        expect(pattern.generate(5)?.value, CellValue.text('C'));
      });

      test('detects mixed text cycle', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Yes'),
          Cell.text('No'),
        ]);

        expect(pattern.type, FillPatternType.repeatingCycle);
        expect(pattern.generate(2)?.value, CellValue.text('Yes'));
        expect(pattern.generate(3)?.value, CellValue.text('No'));
      });

      test('preserves individual cell styles in cycle', () {
        const style1 = CellStyle(backgroundColor: Color(0xFFAABBCC));
        const style2 = CellStyle(backgroundColor: Color(0xFFDDEEFF));
        final pattern = FillPatternDetector.detect([
          Cell.text('X', style: style1),
          Cell.text('Y', style: style2),
        ]);

        expect(pattern.generate(0)?.style, style1);
        expect(pattern.generate(1)?.style, style2);
        expect(pattern.generate(2)?.style, style1);
        expect(pattern.generate(3)?.style, style2);
      });
    });

    group('pattern priority', () {
      test('numeric sequence beats repeating cycle', () {
        // 1, 2, 3 could be a cycle but should be linear numeric
        final pattern = FillPatternDetector.detect([
          Cell.number(1),
          Cell.number(2),
          Cell.number(3),
        ]);

        expect(pattern.type, FillPatternType.linearNumeric);
      });

      test('non-linear numbers fall back to repeating cycle', () {
        final pattern = FillPatternDetector.detect([
          Cell.number(1),
          Cell.number(3),
          Cell.number(7),
        ]);

        expect(pattern.type, FillPatternType.repeatingCycle);
      });

      test('text with non-linear suffix falls back to cycle', () {
        final pattern = FillPatternDetector.detect([
          Cell.text('Item1'),
          Cell.text('Item5'),
          Cell.text('Item2'),
        ]);

        expect(pattern.type, FillPatternType.repeatingCycle);
      });
    });
  });
}
