import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/data_change_event.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
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

    group('getFormat/setFormat', () {
      test('returns null for default format', () {
        expect(data.getFormat(CellCoordinate(0, 0)), isNull);
      });

      test('stores and retrieves format', () {
        final coord = CellCoordinate(5, 10);
        data.setFormat(coord, CellFormat.currency);

        expect(data.getFormat(coord), CellFormat.currency);
      });

      test('clears format when set to null', () {
        final coord = CellCoordinate(5, 10);
        data.setFormat(coord, CellFormat.currency);
        expect(data.getFormat(coord), isNotNull);

        data.setFormat(coord, null);
        expect(data.getFormat(coord), isNull);
      });

      test('emits cellFormat event on change', () async {
        final coord = CellCoordinate(5, 10);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.setFormat(coord, CellFormat.percentage);

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.cellFormat);
        expect(events[0].cell, coord);
      });

      test('does not emit event when clearing non-existent format', () async {
        final coord = CellCoordinate(5, 10);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.setFormat(coord, null);

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 0);
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

      test(
        'batch setCell with null on non-existent cell does nothing',
        () async {
          final events = <DataChangeEvent>[];
          final subscription = data.changes.listen(events.add);

          data.batchUpdate((batch) {
            batch.setCell(CellCoordinate(0, 0), null); // Cell doesn't exist
          });

          await Future.delayed(Duration.zero);
          await subscription.cancel();

          // No event emitted because no change was made
          expect(events.length, 0);
        },
      );

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

      test('batch setFormat applies formats', () {
        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.number(42));
          batch.setFormat(CellCoordinate(0, 0), CellFormat.currency);
        });

        expect(data.getFormat(CellCoordinate(0, 0)), CellFormat.currency);
        expect(data.getCell(CellCoordinate(0, 0)), CellValue.number(42));
      });

      test('batch setFormat with null removes format', () {
        data.setFormat(CellCoordinate(0, 0), CellFormat.currency);

        data.batchUpdate((batch) {
          batch.setFormat(CellCoordinate(0, 0), null);
        });

        expect(data.getFormat(CellCoordinate(0, 0)), isNull);
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
        expect(cells.any((e) => e.key == CellCoordinate(0, 0)), isTrue);
        expect(cells.any((e) => e.key == CellCoordinate(5, 5)), isTrue);
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
        expect(
          data.getCell(CellCoordinate(100, 50)),
          CellValue.text('outside'),
        );
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

      test('clears formats in range', () {
        data.setFormat(CellCoordinate(0, 0), CellFormat.currency);
        data.setFormat(CellCoordinate(5, 5), CellFormat.percentage);
        data.setFormat(CellCoordinate(100, 50), CellFormat.scientific);

        data.clearRange(CellRange(0, 0, 10, 10));

        expect(data.getFormat(CellCoordinate(0, 0)), isNull);
        expect(data.getFormat(CellCoordinate(5, 5)), isNull);
        expect(data.getFormat(CellCoordinate(100, 50)), CellFormat.scientific);
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

    group('cells constructor', () {
      test('populates values and styles from map', () {
        final d = SparseWorksheetData(
          rowCount: 100,
          columnCount: 10,
          cells: {
            (0, 0): Cell.text(
              'Name',
              style: const CellStyle(fontWeight: FontWeight.bold),
            ),
            (1, 0): Cell.number(42),
          },
        );

        expect(d.getCell(const CellCoordinate(0, 0)), CellValue.text('Name'));
        expect(
          d.getStyle(const CellCoordinate(0, 0))?.fontWeight,
          FontWeight.bold,
        );
        expect(d.getCell(const CellCoordinate(1, 0)), CellValue.number(42));
        expect(d.getStyle(const CellCoordinate(1, 0)), isNull);
        expect(d.populatedCellCount, 2);

        d.dispose();
      });

      test('handles style-only cells', () {
        final d = SparseWorksheetData(
          rowCount: 10,
          columnCount: 10,
          cells: {(0, 0): const Cell.withStyle(CellStyle(fontSize: 14.0))},
        );

        expect(d.getCell(const CellCoordinate(0, 0)), isNull);
        expect(d.getStyle(const CellCoordinate(0, 0))?.fontSize, 14.0);

        d.dispose();
      });

      test('updates bounds from initial cells', () {
        final d = SparseWorksheetData(
          rowCount: 100,
          columnCount: 100,
          cells: {(10, 20): Cell.text('A'), (50, 5): Cell.number(1)},
        );

        expect(d.maxPopulatedRow, 50);
        expect(d.maxPopulatedColumn, 20);

        d.dispose();
      });

      test('null cells parameter works like empty', () {
        final d = SparseWorksheetData(rowCount: 10, columnCount: 10);
        expect(d.populatedCellCount, 0);
        d.dispose();
      });

      test('populates formats from cells map', () {
        final d = SparseWorksheetData(
          rowCount: 100,
          columnCount: 10,
          cells: {
            (0, 0): Cell.number(1234.56, format: CellFormat.currency),
            (1, 0): Cell.number(0.42, format: CellFormat.percentage),
            (2, 0): Cell.number(99),
          },
        );

        expect(d.getFormat(const CellCoordinate(0, 0)), CellFormat.currency);
        expect(d.getFormat(const CellCoordinate(1, 0)), CellFormat.percentage);
        expect(d.getFormat(const CellCoordinate(2, 0)), isNull);

        d.dispose();
      });
    });

    group('operator[]', () {
      test('returns Cell with value and style', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('hi'));
        data.setStyle(
          const CellCoordinate(0, 0),
          const CellStyle(fontSize: 12.0),
        );

        final cell = data[(0, 0)];
        expect(cell, isNotNull);
        expect(cell!.value, CellValue.text('hi'));
        expect(cell.style?.fontSize, 12.0);
      });

      test('returns Cell with value only', () {
        data.setCell(const CellCoordinate(1, 1), CellValue.number(99));

        final cell = data[(1, 1)];
        expect(cell, isNotNull);
        expect(cell!.value, CellValue.number(99));
        expect(cell.style, isNull);
      });

      test('returns Cell with style only', () {
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(fontWeight: FontWeight.bold),
        );

        final cell = data[(2, 2)];
        expect(cell, isNotNull);
        expect(cell!.value, isNull);
        expect(cell.style?.fontWeight, FontWeight.bold);
      });

      test('returns null for empty cell', () {
        expect(data[(5, 5)], isNull);
      });

      test('returns Cell with format', () {
        data.setCell(const CellCoordinate(3, 3), CellValue.number(42));
        data.setFormat(const CellCoordinate(3, 3), CellFormat.currency);

        final cell = data[(3, 3)];
        expect(cell, isNotNull);
        expect(cell!.format, CellFormat.currency);
      });

      test('returns Cell with format only', () {
        data.setFormat(const CellCoordinate(4, 4), CellFormat.percentage);

        final cell = data[(4, 4)];
        expect(cell, isNotNull);
        expect(cell!.value, isNull);
        expect(cell.format, CellFormat.percentage);
      });
    });

    group('operator[]=', () {
      test('sets both value and style', () {
        data[(0, 0)] = Cell.text(
          'hello',
          style: const CellStyle(fontSize: 14.0),
        );

        expect(
          data.getCell(const CellCoordinate(0, 0)),
          CellValue.text('hello'),
        );
        expect(data.getStyle(const CellCoordinate(0, 0))?.fontSize, 14.0);
      });

      test('sets value only when style is null', () {
        data[(0, 0)] = Cell.number(42);

        expect(data.getCell(const CellCoordinate(0, 0)), CellValue.number(42));
        expect(data.getStyle(const CellCoordinate(0, 0)), isNull);
      });

      test('null clears both value and style', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('hi'));
        data.setStyle(
          const CellCoordinate(0, 0),
          const CellStyle(fontSize: 12.0),
        );

        data[(0, 0)] = null;

        expect(data.getCell(const CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(const CellCoordinate(0, 0)), isNull);
      });

      test('overwrites existing value and style', () {
        data[(0, 0)] = Cell.text('old', style: const CellStyle(fontSize: 10.0));
        data[(0, 0)] = Cell.number(99, style: const CellStyle(fontSize: 20.0));

        expect(data.getCell(const CellCoordinate(0, 0)), CellValue.number(99));
        expect(data.getStyle(const CellCoordinate(0, 0))?.fontSize, 20.0);
      });

      test('Cell with null value clears existing value', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('hi'));
        data[(0, 0)] = const Cell.withStyle(CellStyle(fontSize: 14.0));

        expect(data.getCell(const CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(const CellCoordinate(0, 0))?.fontSize, 14.0);
      });

      test('emits change event', () async {
        final events = <DataChangeEvent>[];
        data.changes.listen(events.add);

        data[(3, 3)] = Cell.text('test');
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.cell, const CellCoordinate(3, 3));
      });

      test('sets format via Cell', () {
        data[(0, 0)] = Cell.number(1234, format: CellFormat.currency);

        expect(data.getFormat(const CellCoordinate(0, 0)), CellFormat.currency);
        expect(data.getCell(const CellCoordinate(0, 0)), CellValue.number(1234));
      });

      test('null clears format', () {
        data[(0, 0)] = Cell.number(1234, format: CellFormat.currency);
        data[(0, 0)] = null;

        expect(data.getFormat(const CellCoordinate(0, 0)), isNull);
      });

      test('Cell without format clears existing format', () {
        data[(0, 0)] = Cell.number(42, format: CellFormat.currency);
        data[(0, 0)] = Cell.number(42);

        expect(data.getFormat(const CellCoordinate(0, 0)), isNull);
      });
    });

    group('cells getter', () {
      test('returns all populated cells', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('A'));
        data.setCell(const CellCoordinate(1, 1), CellValue.number(42));
        data.setStyle(
          const CellCoordinate(1, 1),
          const CellStyle(fontSize: 12.0),
        );
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(fontWeight: FontWeight.bold),
        );

        final cells = data.cells;
        expect(cells.length, 3);
        expect(cells[const CellCoordinate(0, 0)]?.value, CellValue.text('A'));
        expect(cells[const CellCoordinate(1, 1)]?.value, CellValue.number(42));
        expect(cells[const CellCoordinate(1, 1)]?.style?.fontSize, 12.0);
        expect(cells[const CellCoordinate(2, 2)]?.value, isNull);
        expect(
          cells[const CellCoordinate(2, 2)]?.style?.fontWeight,
          FontWeight.bold,
        );
      });

      test('returns empty map when no data', () {
        expect(data.cells, isEmpty);
      });

      test('returns snapshot not live view', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('A'));
        final snapshot = data.cells;

        data.setCell(const CellCoordinate(1, 1), CellValue.text('B'));

        expect(snapshot.length, 1);
        expect(data.cells.length, 2);
      });
    });

    group('copyRange', () {
      test('multi-row copy maps columns correctly', () {
        // Set up a 2x2 source block at (0,0)
        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.text('A1'));
          batch.setCell(CellCoordinate(0, 1), CellValue.text('B1'));
          batch.setCell(CellCoordinate(1, 0), CellValue.text('A2'));
          batch.setCell(CellCoordinate(1, 1), CellValue.text('B2'));
        });

        // Copy to (5,5)
        data.batchUpdate((batch) {
          batch.copyRange(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));
        });

        expect(data.getCell(CellCoordinate(5, 5)), CellValue.text('A1'));
        expect(data.getCell(CellCoordinate(5, 6)), CellValue.text('B1'));
        expect(data.getCell(CellCoordinate(6, 5)), CellValue.text('A2'));
        expect(data.getCell(CellCoordinate(6, 6)), CellValue.text('B2'));
      });

      test('copies styles and formats', () {
        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.number(42));
          batch.setStyle(
            CellCoordinate(0, 0),
            const CellStyle(fontSize: 14.0),
          );
          batch.setFormat(CellCoordinate(0, 0), CellFormat.currency);
        });

        data.batchUpdate((batch) {
          batch.copyRange(CellRange(0, 0, 0, 0), CellCoordinate(3, 3));
        });

        expect(data.getCell(CellCoordinate(3, 3)), CellValue.number(42));
        expect(data.getStyle(CellCoordinate(3, 3))?.fontSize, 14.0);
        expect(data.getFormat(CellCoordinate(3, 3)), CellFormat.currency);
      });
    });

    group('fillRange', () {
      test('fills range with source value', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(42));

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 3, 0),
        );

        expect(data.getCell(CellCoordinate(1, 0)), CellValue.number(42));
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(42));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(42));
      });

      test('copies style and format from source', () {
        data[(0, 0)] = Cell.number(
          100,
          style: const CellStyle(fontSize: 14.0),
          format: CellFormat.currency,
        );

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 2, 0),
        );

        expect(data.getCell(CellCoordinate(1, 0)), CellValue.number(100));
        expect(data.getStyle(CellCoordinate(1, 0))?.fontSize, 14.0);
        expect(data.getFormat(CellCoordinate(1, 0)), CellFormat.currency);
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(100));
        expect(data.getStyle(CellCoordinate(2, 0))?.fontSize, 14.0);
        expect(data.getFormat(CellCoordinate(2, 0)), CellFormat.currency);
      });

      test('emits single change event', () async {
        data.setCell(CellCoordinate(0, 0), CellValue.text('fill'));
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 5, 0),
        );

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.range);
      });

      test('empty source makes no changes', () async {
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.fillRange(
          CellCoordinate(0, 0), // empty cell
          CellRange(1, 0, 3, 0),
        );

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 0);
        expect(data.getCell(CellCoordinate(1, 0)), isNull);
      });

      test('valueGenerator overrides source', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(1));

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 3, 0),
          (coord, sourceCell) => Cell.number(coord.row * 10),
        );

        expect(data.getCell(CellCoordinate(1, 0)), CellValue.number(10));
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(20));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(30));
      });

      test('source inside target range is safe', () {
        data.setCell(CellCoordinate(1, 0), CellValue.text('original'));

        data.fillRange(
          CellCoordinate(1, 0),
          CellRange(0, 0, 2, 0),
        );

        expect(data.getCell(CellCoordinate(0, 0)), CellValue.text('original'));
        expect(data.getCell(CellCoordinate(1, 0)), CellValue.text('original'));
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.text('original'));
      });

      test('fills 2D range', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('fill'));

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 2, 2),
        );

        for (int row = 1; row <= 2; row++) {
          for (int col = 0; col <= 2; col++) {
            expect(
              data.getCell(CellCoordinate(row, col)),
              CellValue.text('fill'),
            );
          }
        }
      });
    });

    group('smartFill', () {
      test('fill down: constant value', () {
        data[(0, 0)] = Cell.number(42);

        // Source is row 0, destination is below at row 3
        data.smartFill(
          CellRange(0, 0, 0, 0),
          CellCoordinate(3, 0),
        );

        expect(data.getCell(CellCoordinate(1, 0)), CellValue.number(42));
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(42));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(42));
      });

      test('fill down: linear sequence', () {
        data[(0, 0)] = Cell.number(1);
        data[(1, 0)] = Cell.number(2);
        data[(2, 0)] = Cell.number(3);

        // Source rows 0-2, destination below at row 5
        data.smartFill(
          CellRange(0, 0, 2, 0),
          CellCoordinate(5, 0),
        );

        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(4));
        expect(data.getCell(CellCoordinate(4, 0)), CellValue.number(5));
        expect(data.getCell(CellCoordinate(5, 0)), CellValue.number(6));
      });

      test('fill down: text with suffix', () {
        data[(0, 0)] = Cell.text('Item1');
        data[(1, 0)] = Cell.text('Item2');
        data[(2, 0)] = Cell.text('Item3');

        data.smartFill(
          CellRange(0, 0, 2, 0),
          CellCoordinate(5, 0),
        );

        expect(data.getCell(CellCoordinate(3, 0)), CellValue.text('Item4'));
        expect(data.getCell(CellCoordinate(4, 0)), CellValue.text('Item5'));
        expect(data.getCell(CellCoordinate(5, 0)), CellValue.text('Item6'));
      });

      test('fill down: repeating cycle', () {
        data[(0, 0)] = Cell.text('A');
        data[(1, 0)] = Cell.text('B');
        data[(2, 0)] = Cell.text('C');

        data.smartFill(
          CellRange(0, 0, 2, 0),
          CellCoordinate(8, 0),
        );

        expect(data.getCell(CellCoordinate(3, 0)), CellValue.text('A'));
        expect(data.getCell(CellCoordinate(4, 0)), CellValue.text('B'));
        expect(data.getCell(CellCoordinate(5, 0)), CellValue.text('C'));
        expect(data.getCell(CellCoordinate(6, 0)), CellValue.text('A'));
        expect(data.getCell(CellCoordinate(7, 0)), CellValue.text('B'));
        expect(data.getCell(CellCoordinate(8, 0)), CellValue.text('C'));
      });

      test('fill down: date sequence', () {
        data[(0, 0)] = Cell.date(DateTime(2024, 1, 1));
        data[(1, 0)] = Cell.date(DateTime(2024, 1, 2));
        data[(2, 0)] = Cell.date(DateTime(2024, 1, 3));

        data.smartFill(
          CellRange(0, 0, 2, 0),
          CellCoordinate(4, 0),
        );

        expect(
          data.getCell(CellCoordinate(3, 0)),
          CellValue.date(DateTime(2024, 1, 4)),
        );
        expect(
          data.getCell(CellCoordinate(4, 0)),
          CellValue.date(DateTime(2024, 1, 5)),
        );
      });

      test('fill right: linear sequence', () {
        data[(0, 0)] = Cell.number(10);
        data[(0, 1)] = Cell.number(20);
        data[(0, 2)] = Cell.number(30);

        // Source cols 0-2, destination to the right at col 5
        data.smartFill(
          CellRange(0, 0, 0, 2),
          CellCoordinate(0, 5),
        );

        expect(data.getCell(CellCoordinate(0, 3)), CellValue.number(40));
        expect(data.getCell(CellCoordinate(0, 4)), CellValue.number(50));
        expect(data.getCell(CellCoordinate(0, 5)), CellValue.number(60));
      });

      test('fill up: reversed extrapolation', () {
        data[(5, 0)] = Cell.number(1);
        data[(6, 0)] = Cell.number(2);
        data[(7, 0)] = Cell.number(3);

        // Source rows 5-7, destination above at row 2
        data.smartFill(
          CellRange(5, 0, 7, 0),
          CellCoordinate(2, 0),
        );

        // Filling upward: row 4 = 0, row 3 = -1, row 2 = -2
        expect(data.getCell(CellCoordinate(4, 0)), CellValue.number(0));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(-1));
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(-2));
      });

      test('fill left: reversed extrapolation', () {
        data[(0, 5)] = Cell.number(10);
        data[(0, 6)] = Cell.number(20);
        data[(0, 7)] = Cell.number(30);

        // Source cols 5-7, destination to the left at col 2
        data.smartFill(
          CellRange(0, 5, 0, 7),
          CellCoordinate(0, 2),
        );

        // Filling leftward: col 4 = 0, col 3 = -10, col 2 = -20
        expect(data.getCell(CellCoordinate(0, 4)), CellValue.number(0));
        expect(data.getCell(CellCoordinate(0, 3)), CellValue.number(-10));
        expect(data.getCell(CellCoordinate(0, 2)), CellValue.number(-20));
      });

      test('multi-column fill down with independent patterns', () {
        // Column 0: numeric sequence
        data[(0, 0)] = Cell.number(1);
        data[(1, 0)] = Cell.number(2);

        // Column 1: text sequence
        data[(0, 1)] = Cell.text('Q1');
        data[(1, 1)] = Cell.text('Q2');

        data.smartFill(
          CellRange(0, 0, 1, 1),
          CellCoordinate(3, 1),
        );

        // Column 0 continues: 3, 4
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(3));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.number(4));

        // Column 1 continues: Q3, Q4
        expect(data.getCell(CellCoordinate(2, 1)), CellValue.text('Q3'));
        expect(data.getCell(CellCoordinate(3, 1)), CellValue.text('Q4'));
      });

      test('emits single change event', () async {
        data[(0, 0)] = Cell.number(1);
        data[(1, 0)] = Cell.number(2);
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(5, 0),
        );

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, DataChangeType.range);
      });

      test('valueGenerator overrides auto-detection', () {
        data[(0, 0)] = Cell.number(1);
        data[(1, 0)] = Cell.number(2);

        data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(4, 0),
          (coord, sourceCell) => Cell.text('custom${coord.row}'),
        );

        expect(data.getCell(CellCoordinate(2, 0)), CellValue.text('custom2'));
        expect(data.getCell(CellCoordinate(3, 0)), CellValue.text('custom3'));
        expect(data.getCell(CellCoordinate(4, 0)), CellValue.text('custom4'));
      });

      test('preserves style and format', () {
        data[(0, 0)] = Cell.number(
          10,
          style: const CellStyle(fontSize: 14.0),
          format: CellFormat.currency,
        );
        data[(1, 0)] = Cell.number(
          20,
          style: const CellStyle(fontSize: 14.0),
          format: CellFormat.currency,
        );

        data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(3, 0),
        );

        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(30));
        expect(data.getStyle(CellCoordinate(2, 0))?.fontSize, 14.0);
        expect(data.getFormat(CellCoordinate(2, 0)), CellFormat.currency);
      });
    });

    group('dispose', () {
      test('closes change stream', () async {
        final completer = Completer<void>();
        data.changes.listen((_) {}, onDone: () => completer.complete());

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
