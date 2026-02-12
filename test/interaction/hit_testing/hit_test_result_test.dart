import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_test_result.dart';

void main() {
  group('HitTestType', () {
    test('has all expected values', () {
      expect(HitTestType.values, containsAll([
        HitTestType.none,
        HitTestType.cell,
        HitTestType.rowHeader,
        HitTestType.columnHeader,
        HitTestType.rowResizeHandle,
        HitTestType.columnResizeHandle,
        HitTestType.fillHandle,
        HitTestType.selectionBorder,
      ]));
    });
  });

  group('WorksheetHitTestResult', () {
    group('none', () {
      test('creates none result', () {
        const result = WorksheetHitTestResult.none();

        expect(result.type, HitTestType.none);
        expect(result.cell, isNull);
        expect(result.headerIndex, isNull);
        expect(result.isNone, isTrue);
        expect(result.isCell, isFalse);
      });
    });

    group('cell', () {
      test('creates cell result', () {
        final coord = CellCoordinate(5, 10);
        final result = WorksheetHitTestResult.cell(coord);

        expect(result.type, HitTestType.cell);
        expect(result.cell, coord);
        expect(result.headerIndex, isNull);
        expect(result.isCell, isTrue);
        expect(result.isNone, isFalse);
      });
    });

    group('rowHeader', () {
      test('creates row header result', () {
        const result = WorksheetHitTestResult.rowHeader(15);

        expect(result.type, HitTestType.rowHeader);
        expect(result.cell, isNull);
        expect(result.headerIndex, 15);
        expect(result.isRowHeader, isTrue);
      });
    });

    group('columnHeader', () {
      test('creates column header result', () {
        const result = WorksheetHitTestResult.columnHeader(8);

        expect(result.type, HitTestType.columnHeader);
        expect(result.cell, isNull);
        expect(result.headerIndex, 8);
        expect(result.isColumnHeader, isTrue);
      });
    });

    group('rowResizeHandle', () {
      test('creates row resize handle result', () {
        const result = WorksheetHitTestResult.rowResizeHandle(20);

        expect(result.type, HitTestType.rowResizeHandle);
        expect(result.headerIndex, 20);
        expect(result.isResizeHandle, isTrue);
      });
    });

    group('columnResizeHandle', () {
      test('creates column resize handle result', () {
        const result = WorksheetHitTestResult.columnResizeHandle(5);

        expect(result.type, HitTestType.columnResizeHandle);
        expect(result.headerIndex, 5);
        expect(result.isResizeHandle, isTrue);
      });
    });

    group('fillHandle', () {
      test('creates fill handle result', () {
        final coord = CellCoordinate(3, 5);
        final result = WorksheetHitTestResult.fillHandle(coord);

        expect(result.type, HitTestType.fillHandle);
        expect(result.cell, coord);
        expect(result.headerIndex, isNull);
        expect(result.isFillHandle, isTrue);
        expect(result.isCell, isFalse);
        expect(result.isNone, isFalse);
      });

      test('toString contains fillHandle', () {
        final result = WorksheetHitTestResult.fillHandle(CellCoordinate(2, 3));
        expect(result.toString(), contains('fillHandle'));
      });

      test('equality works for fill handle', () {
        final a = WorksheetHitTestResult.fillHandle(CellCoordinate(1, 2));
        final b = WorksheetHitTestResult.fillHandle(CellCoordinate(1, 2));
        final c = WorksheetHitTestResult.fillHandle(CellCoordinate(1, 3));

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });
    });

    group('selectionBorder', () {
      test('creates selection border result', () {
        final coord = CellCoordinate(2, 4);
        final result = WorksheetHitTestResult.selectionBorder(coord);

        expect(result.type, HitTestType.selectionBorder);
        expect(result.cell, coord);
        expect(result.headerIndex, isNull);
        expect(result.isSelectionBorder, isTrue);
        expect(result.isCell, isFalse);
        expect(result.isNone, isFalse);
      });

      test('toString contains selectionBorder', () {
        final result =
            WorksheetHitTestResult.selectionBorder(CellCoordinate(2, 3));
        expect(result.toString(), contains('selectionBorder'));
      });

      test('equality works for selection border', () {
        final a =
            WorksheetHitTestResult.selectionBorder(CellCoordinate(1, 2));
        final b =
            WorksheetHitTestResult.selectionBorder(CellCoordinate(1, 2));
        final c =
            WorksheetHitTestResult.selectionBorder(CellCoordinate(1, 3));

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });
    });

    group('convenience getters', () {
      test('isHeader returns true for row header', () {
        const result = WorksheetHitTestResult.rowHeader(0);
        expect(result.isHeader, isTrue);
      });

      test('isHeader returns true for column header', () {
        const result = WorksheetHitTestResult.columnHeader(0);
        expect(result.isHeader, isTrue);
      });

      test('isHeader returns false for cell', () {
        final result = WorksheetHitTestResult.cell(CellCoordinate(0, 0));
        expect(result.isHeader, isFalse);
      });

      test('isResizeHandle returns true for row resize', () {
        const result = WorksheetHitTestResult.rowResizeHandle(0);
        expect(result.isResizeHandle, isTrue);
      });

      test('isResizeHandle returns true for column resize', () {
        const result = WorksheetHitTestResult.columnResizeHandle(0);
        expect(result.isResizeHandle, isTrue);
      });

      test('isResizeHandle returns false for cell', () {
        final result = WorksheetHitTestResult.cell(CellCoordinate(0, 0));
        expect(result.isResizeHandle, isFalse);
      });
    });

    group('equality', () {
      test('equal none results are equal', () {
        const a = WorksheetHitTestResult.none();
        const b = WorksheetHitTestResult.none();

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('equal cell results are equal', () {
        final a = WorksheetHitTestResult.cell(CellCoordinate(5, 10));
        final b = WorksheetHitTestResult.cell(CellCoordinate(5, 10));

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different cells are not equal', () {
        final a = WorksheetHitTestResult.cell(CellCoordinate(5, 10));
        final b = WorksheetHitTestResult.cell(CellCoordinate(5, 11));

        expect(a, isNot(b));
      });

      test('different types are not equal', () {
        const a = WorksheetHitTestResult.rowHeader(5);
        const b = WorksheetHitTestResult.columnHeader(5);

        expect(a, isNot(b));
      });
    });

    group('toString', () {
      test('none has readable string', () {
        const result = WorksheetHitTestResult.none();
        expect(result.toString(), 'WorksheetHitTestResult.none');
      });

      test('cell has readable string', () {
        final result = WorksheetHitTestResult.cell(CellCoordinate(5, 10));
        expect(result.toString(), contains('cell'));
        expect(result.toString(), contains('CellCoordinate'));
      });

      test('rowHeader has readable string', () {
        const result = WorksheetHitTestResult.rowHeader(15);
        expect(result.toString(), contains('rowHeader'));
        expect(result.toString(), contains('15'));
      });
    });
  });
}
