import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/data_change_event.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  group('DataChangeEvent', () {
    group('cellValue', () {
      test('creates cell value event', () {
        final coord = CellCoordinate(5, 10);
        final event = DataChangeEvent.cellValue(coord);

        expect(event.type, DataChangeType.cellValue);
        expect(event.cell, coord);
        expect(event.range, isNull);
        expect(event.rowIndex, isNull);
        expect(event.columnIndex, isNull);
      });

      test('toString returns correct format', () {
        final coord = CellCoordinate(0, 0);
        final event = DataChangeEvent.cellValue(coord);

        expect(event.toString(), 'DataChangeEvent.cellValue(CellCoordinate(A1))');
      });
    });

    group('cellStyle', () {
      test('creates cell style event', () {
        final coord = CellCoordinate(3, 7);
        final event = DataChangeEvent.cellStyle(coord);

        expect(event.type, DataChangeType.cellStyle);
        expect(event.cell, coord);
        expect(event.range, isNull);
      });

      test('toString returns correct format', () {
        final coord = CellCoordinate(0, 1);
        final event = DataChangeEvent.cellStyle(coord);

        expect(event.toString(), 'DataChangeEvent.cellStyle(CellCoordinate(B1))');
      });
    });

    group('cellFormat', () {
      test('creates cell format event', () {
        final coord = CellCoordinate(2, 4);
        final event = DataChangeEvent.cellFormat(coord);

        expect(event.type, DataChangeType.cellFormat);
        expect(event.cell, coord);
        expect(event.range, isNull);
      });

      test('toString returns correct format', () {
        final coord = CellCoordinate(0, 2);
        final event = DataChangeEvent.cellFormat(coord);

        expect(
            event.toString(), 'DataChangeEvent.cellFormat(CellCoordinate(C1))');
      });
    });

    group('range', () {
      test('creates range event', () {
        final range = CellRange(0, 0, 10, 10);
        final event = DataChangeEvent.range(range);

        expect(event.type, DataChangeType.range);
        expect(event.range, range);
        expect(event.cell, isNull);
      });

      test('toString returns correct format', () {
        final range = CellRange(0, 0, 5, 5);
        final event = DataChangeEvent.range(range);

        expect(event.toString(), 'DataChangeEvent.range(CellRange(A1:F6))');
      });
    });

    group('rowInserted', () {
      test('creates row inserted event', () {
        final event = DataChangeEvent.rowInserted(5);

        expect(event.type, DataChangeType.rowInserted);
        expect(event.rowIndex, 5);
        expect(event.columnIndex, isNull);
        expect(event.cell, isNull);
        expect(event.range, isNull);
      });

      test('toString returns correct format', () {
        final event = DataChangeEvent.rowInserted(10);

        expect(event.toString(), 'DataChangeEvent.rowInserted(10)');
      });
    });

    group('rowDeleted', () {
      test('creates row deleted event', () {
        final event = DataChangeEvent.rowDeleted(3);

        expect(event.type, DataChangeType.rowDeleted);
        expect(event.rowIndex, 3);
      });

      test('toString returns correct format', () {
        final event = DataChangeEvent.rowDeleted(7);

        expect(event.toString(), 'DataChangeEvent.rowDeleted(7)');
      });
    });

    group('columnInserted', () {
      test('creates column inserted event', () {
        final event = DataChangeEvent.columnInserted(2);

        expect(event.type, DataChangeType.columnInserted);
        expect(event.columnIndex, 2);
        expect(event.rowIndex, isNull);
      });

      test('toString returns correct format', () {
        final event = DataChangeEvent.columnInserted(4);

        expect(event.toString(), 'DataChangeEvent.columnInserted(4)');
      });
    });

    group('columnDeleted', () {
      test('creates column deleted event', () {
        final event = DataChangeEvent.columnDeleted(8);

        expect(event.type, DataChangeType.columnDeleted);
        expect(event.columnIndex, 8);
      });

      test('toString returns correct format', () {
        final event = DataChangeEvent.columnDeleted(1);

        expect(event.toString(), 'DataChangeEvent.columnDeleted(1)');
      });
    });

    group('reset', () {
      test('creates reset event', () {
        final event = DataChangeEvent.reset();

        expect(event.type, DataChangeType.reset);
        expect(event.cell, isNull);
        expect(event.range, isNull);
        expect(event.rowIndex, isNull);
        expect(event.columnIndex, isNull);
      });

      test('toString returns correct format', () {
        final event = DataChangeEvent.reset();

        expect(event.toString(), 'DataChangeEvent.reset()');
      });
    });
  });

  group('DataChangeType enum', () {
    test('has expected values', () {
      expect(DataChangeType.values.length, 11);
      expect(DataChangeType.cellValue.index, 0);
      expect(DataChangeType.cellStyle.index, 1);
      expect(DataChangeType.cellFormat.index, 2);
      expect(DataChangeType.range.index, 3);
      expect(DataChangeType.rowInserted.index, 4);
      expect(DataChangeType.rowDeleted.index, 5);
      expect(DataChangeType.columnInserted.index, 6);
      expect(DataChangeType.columnDeleted.index, 7);
      expect(DataChangeType.merge.index, 8);
      expect(DataChangeType.unmerge.index, 9);
      expect(DataChangeType.reset.index, 10);
    });
  });
}
