import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_serializer.dart';

void main() {
  late TsvClipboardSerializer serializer;
  late SparseWorksheetData data;

  setUp(() {
    serializer = const TsvClipboardSerializer();
    data = SparseWorksheetData(rowCount: 10, columnCount: 10);
  });

  tearDown(() {
    data.dispose();
  });

  group('TsvClipboardSerializer.serialize', () {
    test('produces correct TSV for multi-row/multi-column range', () {
      data[(0, 0)] = 'A'.cell;
      data[(0, 1)] = 'B'.cell;
      data[(1, 0)] = 'C'.cell;
      data[(1, 1)] = 'D'.cell;

      final result = serializer.serialize(const CellRange(0, 0, 1, 1), data);

      expect(result, 'A\tB\nC\tD');
    });

    test('handles empty cells with consecutive tabs', () {
      data[(0, 0)] = 'A'.cell;
      // (0,1) is empty
      data[(0, 2)] = 'C'.cell;

      final result = serializer.serialize(const CellRange(0, 0, 0, 2), data);

      expect(result, 'A\t\tC');
    });

    test('uses formatted display values', () {
      data[(0, 0)] = Cell.number(0.42, format: CellFormat.percentage);

      final result = serializer.serialize(const CellRange(0, 0, 0, 0), data);

      expect(result, '42%');
    });

    test('handles single cell', () {
      data[(0, 0)] = 'Hello'.cell;

      final result = serializer.serialize(const CellRange(0, 0, 0, 0), data);

      expect(result, 'Hello');
    });

    test('handles all-empty range', () {
      final result = serializer.serialize(const CellRange(0, 0, 1, 1), data);

      expect(result, '\t\n\t');
    });

    test('handles numeric values', () {
      data[(0, 0)] = 42.cell;
      data[(0, 1)] = Cell.number(3.14);

      final result = serializer.serialize(const CellRange(0, 0, 0, 1), data);

      expect(result, '42\t3.14');
    });

    test('handles boolean values', () {
      data[(0, 0)] = true.cell;
      data[(0, 1)] = false.cell;

      final result = serializer.serialize(const CellRange(0, 0, 0, 1), data);

      expect(result, 'TRUE\tFALSE');
    });
  });

  group('TsvClipboardSerializer.deserialize', () {
    test('parses TSV into correct grid', () {
      final grid = serializer.deserialize('A\tB\nC\tD');

      expect(grid.length, 2);
      expect(grid[0].length, 2);
      expect(grid[0][0], const CellValue.text('A'));
      expect(grid[0][1], const CellValue.text('B'));
      expect(grid[1][0], const CellValue.text('C'));
      expect(grid[1][1], const CellValue.text('D'));
    });

    test('detects numbers', () {
      final grid = serializer.deserialize('42\t3.14\t-7');

      expect(grid[0][0], CellValue.number(42));
      expect(grid[0][1], CellValue.number(3.14));
      expect(grid[0][2], CellValue.number(-7));
    });

    test('detects booleans', () {
      final grid = serializer.deserialize('true\tFALSE\tTrue');

      expect(grid[0][0], const CellValue.boolean(true));
      expect(grid[0][1], const CellValue.boolean(false));
      expect(grid[0][2], const CellValue.boolean(true));
    });

    test('handles empty cells', () {
      final grid = serializer.deserialize('A\t\tC');

      expect(grid[0].length, 3);
      expect(grid[0][0], const CellValue.text('A'));
      expect(grid[0][1], isNull);
      expect(grid[0][2], const CellValue.text('C'));
    });

    test('handles single value (no tabs/newlines)', () {
      final grid = serializer.deserialize('Hello');

      expect(grid.length, 1);
      expect(grid[0].length, 1);
      expect(grid[0][0], const CellValue.text('Hello'));
    });

    test('handles empty string', () {
      final grid = serializer.deserialize('');

      expect(grid, isEmpty);
    });
  });

  group('round-trip', () {
    test('serialize then deserialize preserves text values', () {
      data[(0, 0)] = 'Hello'.cell;
      data[(0, 1)] = 'World'.cell;
      data[(1, 0)] = 'Foo'.cell;
      data[(1, 1)] = 'Bar'.cell;

      final range = const CellRange(0, 0, 1, 1);
      final tsv = serializer.serialize(range, data);
      final grid = serializer.deserialize(tsv);

      expect(grid[0][0], const CellValue.text('Hello'));
      expect(grid[0][1], const CellValue.text('World'));
      expect(grid[1][0], const CellValue.text('Foo'));
      expect(grid[1][1], const CellValue.text('Bar'));
    });

    test('serialize then deserialize preserves numeric values', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      data.setCell(const CellCoordinate(0, 1), CellValue.number(3.14));

      final range = const CellRange(0, 0, 0, 1);
      final tsv = serializer.serialize(range, data);
      final grid = serializer.deserialize(tsv);

      expect(grid[0][0], CellValue.number(42));
      expect(grid[0][1], CellValue.number(3.14));
    });

    test('serialize then deserialize preserves boolean values', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.boolean(true));
      data.setCell(const CellCoordinate(0, 1), const CellValue.boolean(false));

      final range = const CellRange(0, 0, 0, 1);
      final tsv = serializer.serialize(range, data);
      final grid = serializer.deserialize(tsv);

      expect(grid[0][0], const CellValue.boolean(true));
      expect(grid[0][1], const CellValue.boolean(false));
    });
  });
}
