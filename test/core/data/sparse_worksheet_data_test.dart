import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/data_change_event.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('SparseWorksheetData', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 1000, columnCount: 100);
    });

    tearDown(() {
      data.dispose();
    });

    group('construction', () {
      test('creates with specified dimensions', () {
        expect(data.rowCount, 1000);
        expect(data.columnCount, 100);
      });

      test('starts with empty cells', () {
        expect(data.getCell(CellCoordinate(0, 0)), isNull);
        expect(data.getCell(CellCoordinate(500, 50)), isNull);
      });
    });

    group('getCell/setCell', () {
      test('stores and retrieves text value', () {
        final coord = CellCoordinate(5, 10);
        data.setCell(coord, CellValue.text('Hello'));

        expect(data.getCell(coord), CellValue.text('Hello'));
      });

      test('stores and retrieves number value', () {
        final coord = CellCoordinate(5, 10);
        data.setCell(coord, CellValue.number(42.5));

        expect(data.getCell(coord), CellValue.number(42.5));
      });

      test('stores and retrieves boolean value', () {
        final coord = CellCoordinate(5, 10);
        data.setCell(coord, CellValue.boolean(true));

        expect(data.getCell(coord), CellValue.boolean(true));
      });

      test('clears cell when set to null', () {
        final coord = CellCoordinate(5, 10);
        data.setCell(coord, CellValue.text('Hello'));
        expect(data.getCell(coord), isNotNull);

        data.setCell(coord, null);
        expect(data.getCell(coord), isNull);
      });

      test('hasValue returns correct state', () {
        final coord = CellCoordinate(5, 10);
        expect(data.hasValue(coord), isFalse);

        data.setCell(coord, CellValue.text('Hello'));
        expect(data.hasValue(coord), isTrue);

        data.setCell(coord, null);
        expect(data.hasValue(coord), isFalse);
      });
    });

    group('getStyle/setStyle', () {
      test('returns null for default style', () {
        expect(data.getStyle(CellCoordinate(0, 0)), isNull);
      });

      test('stores and retrieves custom style', () {
        final coord = CellCoordinate(5, 10);
        final style = CellStyle(fontSize: 16.0);
        data.setStyle(coord, style);

        expect(data.getStyle(coord), style);
      });

      test('clears style when set to null', () {
        final coord = CellCoordinate(5, 10);
        data.setStyle(coord, CellStyle(fontSize: 16.0));
        expect(data.getStyle(coord), isNotNull);

        data.setStyle(coord, null);
        expect(data.getStyle(coord), isNull);
      });
    });

    group('change events', () {
      test('emits event on cell value change', () async {
        final coord = CellCoordinate(5, 10);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.setCell(coord, CellValue.text('Hello'));

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.cellValue);
        expect(events[0].cell, coord);
      });

      test('emits event on cell style change', () async {
        final coord = CellCoordinate(5, 10);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.setStyle(coord, CellStyle(fontSize: 16.0));

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.cellStyle);
        expect(events[0].cell, coord);
      });

      test('does not emit event when clearing non-existent cell', () async {
        final coord = CellCoordinate(5, 10);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.setCell(coord, null); // Cell doesn't exist

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 0);
      });
    });

    group('batchUpdate', () {
      test('applies all changes', () {
        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
          batch.setCell(CellCoordinate(0, 1), CellValue.text('B1'));
          batch.setCell(CellCoordinate(1, 0), CellValue.text('A2'));
        });

        expect(data.getCell(CellCoordinate(0, 0)), CellValue.text('A1'));
        expect(data.getCell(CellCoordinate(0, 1)), CellValue.text('B1'));
        expect(data.getCell(CellCoordinate(1, 0)), CellValue.text('A2'));
      });

      test('emits single range event for batch', () async {
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
          batch.setCell(CellCoordinate(5, 5), CellValue.text('F6'));
        });

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.range);
        expect(events[0].range!.contains(CellCoordinate(0, 0)), isTrue);
        expect(events[0].range!.contains(CellCoordinate(5, 5)), isTrue);
      });

      test('batch setCell with null removes existing cell', () {
        // First set a value
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
        expect(data.getCell(CellCoordinate(0, 0)), isNotNull);

        // Remove it in a batch
        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), null);
        });

        expect(data.getCell(CellCoordinate(0, 0)), isNull);
      });

      test('batch setCell with null on non-existent cell does nothing', () async {
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), null); // Cell doesn't exist
        });

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        // No event emitted because no change was made
        expect(events.length, 0);
      });

      test('batch setStyle applies styles', () {
        data.batchUpdate((batch) {
          batch.setStyle(CellCoordinate(0, 0), const CellStyle(fontSize: 14.0));
          batch.setStyle(CellCoordinate(1, 1), const CellStyle(fontSize: 16.0));
        });

        expect(data.getStyle(CellCoordinate(0, 0))?.fontSize, 14.0);
        expect(data.getStyle(CellCoordinate(1, 1))?.fontSize, 16.0);
      });

      test('batch setStyle with null removes style', () {
        data.setStyle(CellCoordinate(0, 0), const CellStyle(fontSize: 14.0));

        data.batchUpdate((batch) {
          batch.setStyle(CellCoordinate(0, 0), null);
        });

        expect(data.getStyle(CellCoordinate(0, 0)), isNull);
      });

      test('batch clearRange clears cells and styles', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
        data.setCell(CellCoordinate(5, 5), CellValue.text('F6'));
        data.setStyle(CellCoordinate(0, 0), const CellStyle(fontSize: 14.0));
        data.setStyle(CellCoordinate(5, 5), const CellStyle(fontSize: 16.0));

        data.batchUpdate((batch) {
          batch.clearRange(CellRange(0, 0, 10, 10));
        });

        expect(data.getCell(CellCoordinate(0, 0)), isNull);
        expect(data.getCell(CellCoordinate(5, 5)), isNull);
        expect(data.getStyle(CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(CellCoordinate(5, 5)), isNull);
      });

      test('batch clearRange expands affected range', () async {
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));

        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(20, 20), CellValue.text('U21'));
          batch.clearRange(CellRange(0, 0, 5, 5));
        });

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].range!.contains(CellCoordinate(0, 0)), isTrue);
        expect(events[0].range!.contains(CellCoordinate(20, 20)), isTrue);
      });

      test('batch with no changes emits no event', () async {
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.batchUpdate((batch) {
          // No operations
        });

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 0);
      });
    });

    group('getCellsInRange', () {
      test('returns empty for empty range', () {
        final range = CellRange(0, 0, 10, 10);
        final cells = data.getCellsInRange(range).toList();
        expect(cells, isEmpty);
      });

      test('returns only populated cells in range', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
        data.setCell(CellCoordinate(5, 5), CellValue.text('F6'));
        data.setCell(CellCoordinate(100, 50), CellValue.text('outside'));

        final range = CellRange(0, 0, 10, 10);
        final cells = data.getCellsInRange(range).toList();

        expect(cells.length, 2);
        expect(
          cells.any((e) => e.key == CellCoordinate(0, 0)),
          isTrue,
        );
        expect(
          cells.any((e) => e.key == CellCoordinate(5, 5)),
          isTrue,
        );
      });
    });

    group('clearRange', () {
      test('clears all cells in range', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
        data.setCell(CellCoordinate(5, 5), CellValue.text('F6'));
        data.setCell(CellCoordinate(100, 50), CellValue.text('outside'));

        data.clearRange(CellRange(0, 0, 10, 10));

        expect(data.getCell(CellCoordinate(0, 0)), isNull);
        expect(data.getCell(CellCoordinate(5, 5)), isNull);
        expect(data.getCell(CellCoordinate(100, 50)), CellValue.text('outside'));
      });

      test('clears styles in range', () {
        data.setStyle(CellCoordinate(0, 0), const CellStyle(fontSize: 14.0));
        data.setStyle(CellCoordinate(5, 5), const CellStyle(fontSize: 16.0));
        data.setStyle(CellCoordinate(100, 50), const CellStyle(fontSize: 18.0));

        data.clearRange(CellRange(0, 0, 10, 10));

        expect(data.getStyle(CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(CellCoordinate(5, 5)), isNull);
        expect(data.getStyle(CellCoordinate(100, 50)), isNotNull);
      });

      test('emits range event', () async {
        data.setCell(CellCoordinate(0, 0), CellValue.text('A1'));

        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.clearRange(CellRange(0, 0, 10, 10));

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.range);
      });
    });

    group('memory efficiency', () {
      test('handles sparse data efficiently', () {
        // Set values at far corners
        data.setCell(CellCoordinate(0, 0), CellValue.text('start'));
        data.setCell(CellCoordinate(999, 99), CellValue.text('end'));

        // Verify only 2 cells are stored
        expect(data.populatedCellCount, 2);
      });

      test('tracks populated bounds', () {
        data.setCell(CellCoordinate(10, 20), CellValue.text('A'));
        data.setCell(CellCoordinate(50, 30), CellValue.text('B'));

        expect(data.maxPopulatedRow, 50);
        expect(data.maxPopulatedColumn, 30);
      });
    });

    group('dispose', () {
      test('closes change stream', () async {
        final completer = Completer<void>();
        data.changes.listen(
          (_) {},
          onDone: () => completer.complete(),
        );

        data.dispose();

        await expectLater(completer.future, completes);
      });

      test('prevents further operations', () {
        data.dispose();

        expect(
          () => data.setCell(CellCoordinate(0, 0), CellValue.text('test')),
          throwsStateError,
        );
      });
    });
  });
}
