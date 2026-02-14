import 'dart:async';

import 'package:flutter/painting.dart';
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
        final style = CellStyle(backgroundColor: Color(0xFFFF0000));
        data.setStyle(coord, style);

        expect(data.getStyle(coord), style);
      });

      test('clears style when set to null', () {
        final coord = CellCoordinate(5, 10);
        data.setStyle(coord, CellStyle(backgroundColor: Color(0xFFFF0000)));
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

        data.setStyle(coord, CellStyle(backgroundColor: Color(0xFFFF0000)));

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
          batch.setStyle(CellCoordinate(0, 0), const CellStyle(backgroundColor: Color(0xFFFF0000)));
          batch.setStyle(CellCoordinate(1, 1), const CellStyle(backgroundColor: Color(0xFF00FF00)));
        });

        expect(data.getStyle(CellCoordinate(0, 0))?.backgroundColor, const Color(0xFFFF0000));
        expect(data.getStyle(CellCoordinate(1, 1))?.backgroundColor, const Color(0xFF00FF00));
      });

      test('batch setStyle with null removes style', () {
        data.setStyle(CellCoordinate(0, 0), const CellStyle(backgroundColor: Color(0xFFFF0000)));

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
        data.setStyle(CellCoordinate(0, 0), const CellStyle(backgroundColor: Color(0xFFFF0000)));
        data.setStyle(CellCoordinate(5, 5), const CellStyle(backgroundColor: Color(0xFF00FF00)));

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
        data.setStyle(CellCoordinate(0, 0), const CellStyle(backgroundColor: Color(0xFFFF0000)));
        data.setStyle(CellCoordinate(5, 5), const CellStyle(backgroundColor: Color(0xFF00FF00)));
        data.setStyle(CellCoordinate(100, 50), const CellStyle(backgroundColor: Color(0xFF0000FF)));

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
              style: const CellStyle(backgroundColor: Color(0xFF00FF00)),
            ),
            (1, 0): Cell.number(42),
          },
        );

        expect(d.getCell(const CellCoordinate(0, 0)), CellValue.text('Name'));
        expect(
          d.getStyle(const CellCoordinate(0, 0))?.backgroundColor,
          const Color(0xFF00FF00),
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
          cells: {(0, 0): const Cell.withStyle(CellStyle(backgroundColor: Color(0xFFFF0000)))},
        );

        expect(d.getCell(const CellCoordinate(0, 0)), isNull);
        expect(d.getStyle(const CellCoordinate(0, 0))?.backgroundColor, const Color(0xFFFF0000));

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
          const CellStyle(backgroundColor: Color(0xFFFF0000)),
        );

        final cell = data[(0, 0)];
        expect(cell, isNotNull);
        expect(cell!.value, CellValue.text('hi'));
        expect(cell.style?.backgroundColor, const Color(0xFFFF0000));
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
          const CellStyle(backgroundColor: Color(0xFF00FF00)),
        );

        final cell = data[(2, 2)];
        expect(cell, isNotNull);
        expect(cell!.value, isNull);
        expect(cell.style?.backgroundColor, const Color(0xFF00FF00));
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
          style: const CellStyle(backgroundColor: Color(0xFFFF0000)),
        );

        expect(
          data.getCell(const CellCoordinate(0, 0)),
          CellValue.text('hello'),
        );
        expect(data.getStyle(const CellCoordinate(0, 0))?.backgroundColor, const Color(0xFFFF0000));
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
          const CellStyle(backgroundColor: Color(0xFFFF0000)),
        );

        data[(0, 0)] = null;

        expect(data.getCell(const CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(const CellCoordinate(0, 0)), isNull);
      });

      test('overwrites existing value and style', () {
        data[(0, 0)] = Cell.text('old', style: const CellStyle(backgroundColor: Color(0xFFFF0000)));
        data[(0, 0)] = Cell.number(99, style: const CellStyle(backgroundColor: Color(0xFF00FF00)));

        expect(data.getCell(const CellCoordinate(0, 0)), CellValue.number(99));
        expect(data.getStyle(const CellCoordinate(0, 0))?.backgroundColor, const Color(0xFF00FF00));
      });

      test('Cell with null value clears existing value', () {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('hi'));
        data[(0, 0)] = const Cell.withStyle(CellStyle(backgroundColor: Color(0xFFFF0000)));

        expect(data.getCell(const CellCoordinate(0, 0)), isNull);
        expect(data.getStyle(const CellCoordinate(0, 0))?.backgroundColor, const Color(0xFFFF0000));
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
          const CellStyle(backgroundColor: Color(0xFFFF0000)),
        );
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(backgroundColor: Color(0xFF00FF00)),
        );

        final cells = data.cells;
        expect(cells.length, 3);
        expect(cells[const CellCoordinate(0, 0)]?.value, CellValue.text('A'));
        expect(cells[const CellCoordinate(1, 1)]?.value, CellValue.number(42));
        expect(cells[const CellCoordinate(1, 1)]?.style?.backgroundColor, const Color(0xFFFF0000));
        expect(cells[const CellCoordinate(2, 2)]?.value, isNull);
        expect(
          cells[const CellCoordinate(2, 2)]?.style?.backgroundColor,
          const Color(0xFF00FF00),
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
            const CellStyle(backgroundColor: Color(0xFFFF0000)),
          );
          batch.setFormat(CellCoordinate(0, 0), CellFormat.currency);
        });

        data.batchUpdate((batch) {
          batch.copyRange(CellRange(0, 0, 0, 0), CellCoordinate(3, 3));
        });

        expect(data.getCell(CellCoordinate(3, 3)), CellValue.number(42));
        expect(data.getStyle(CellCoordinate(3, 3))?.backgroundColor, const Color(0xFFFF0000));
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
          style: const CellStyle(backgroundColor: Color(0xFFFF0000)),
          format: CellFormat.currency,
        );

        data.fillRange(
          CellCoordinate(0, 0),
          CellRange(1, 0, 2, 0),
        );

        expect(data.getCell(CellCoordinate(1, 0)), CellValue.number(100));
        expect(data.getStyle(CellCoordinate(1, 0))?.backgroundColor, const Color(0xFFFF0000));
        expect(data.getFormat(CellCoordinate(1, 0)), CellFormat.currency);
        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(100));
        expect(data.getStyle(CellCoordinate(2, 0))?.backgroundColor, const Color(0xFFFF0000));
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
          style: const CellStyle(backgroundColor: Color(0xFFFF0000)),
          format: CellFormat.currency,
        );
        data[(1, 0)] = Cell.number(
          20,
          style: const CellStyle(backgroundColor: Color(0xFFFF0000)),
          format: CellFormat.currency,
        );

        data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(3, 0),
        );

        expect(data.getCell(CellCoordinate(2, 0)), CellValue.number(30));
        expect(data.getStyle(CellCoordinate(2, 0))?.backgroundColor, const Color(0xFFFF0000));
        expect(data.getFormat(CellCoordinate(2, 0)), CellFormat.currency);
      });
    });

    group('unmergeCellsInRange', () {
      test('unmerges single merge in range', () {
        data.mergeCells(CellRange(0, 0, 1, 1));

        data.unmergeCellsInRange(CellRange(0, 0, 1, 1));

        expect(data.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
      });

      test('unmerges multiple merges in range', () {
        data.mergeCells(CellRange(0, 0, 0, 1));
        data.mergeCells(CellRange(1, 0, 1, 1));

        data.unmergeCellsInRange(CellRange(0, 0, 1, 1));

        expect(data.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
        expect(data.mergedCells.getRegion(CellCoordinate(1, 0)), isNull);
      });

      test('merges outside range untouched', () {
        data.mergeCells(CellRange(0, 0, 0, 1));
        data.mergeCells(CellRange(5, 5, 6, 6));

        data.unmergeCellsInRange(CellRange(0, 0, 2, 2));

        expect(data.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
        expect(
          data.mergedCells.getRegion(CellCoordinate(5, 5))!.range,
          CellRange(5, 5, 6, 6),
        );
      });

      test('no-op when no merges in range', () async {
        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.unmergeCellsInRange(CellRange(0, 0, 5, 5));

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events, isEmpty);
      });

      test('emits change event', () async {
        data.mergeCells(CellRange(0, 0, 1, 1));

        final events = <DataChangeEvent>[];
        final subscription = data.changes.listen(events.add);

        data.unmergeCellsInRange(CellRange(0, 0, 3, 3));

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(events, hasLength(1));
        expect(events[0].type, DataChangeType.range);
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

    group('richText', () {
      test('getRichText returns null by default', () {
        expect(data.getRichText(CellCoordinate(0, 0)), isNull);
      });

      test('setRichText stores and retrieves spans', () {
        const spans = [
          TextSpan(
              text: 'Bold',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' text'),
        ];
        data.setRichText(CellCoordinate(0, 0), spans);
        expect(data.getRichText(CellCoordinate(0, 0)), spans);
      });

      test('setRichText null clears spans', () {
        const spans = [TextSpan(text: 'hello')];
        data.setRichText(CellCoordinate(0, 0), spans);
        data.setRichText(CellCoordinate(0, 0), null);
        expect(data.getRichText(CellCoordinate(0, 0)), isNull);
      });

      test('setRichText emits change event', () async {
        final events = <DataChangeEvent>[];
        data.changes.listen(events.add);

        data.setRichText(CellCoordinate(1, 2), const [TextSpan(text: 'hi')]);
        await Future.delayed(Duration.zero);

        expect(events, isNotEmpty);
        expect(events.last.type, DataChangeType.cellValue);
      });

      test('clearRange clears richText', () {
        data.setRichText(
            CellCoordinate(0, 0), const [TextSpan(text: 'hello')]);
        data.clearRange(CellRange(0, 0, 0, 0));
        expect(data.getRichText(CellCoordinate(0, 0)), isNull);
      });

      test('operator[] includes richText', () {
        const spans = [TextSpan(text: 'hi')];
        data[(0, 0)] = const Cell(
          value: CellValue.text('hi'),
          richText: spans,
        );
        final cell = data[(0, 0)];
        expect(cell, isNotNull);
        expect(cell!.richText, spans);
      });

      test('operator[]= null clears richText', () {
        data[(0, 0)] = const Cell(
          value: CellValue.text('hi'),
          richText: [TextSpan(text: 'hi')],
        );
        data[(0, 0)] = null;
        expect(data.getRichText(CellCoordinate(0, 0)), isNull);
      });

      test('constructor initializes richText from cells map', () {
        final d = SparseWorksheetData(
          rowCount: 10,
          columnCount: 10,
          cells: {
            (0, 0): const Cell(
              value: CellValue.text('test'),
              richText: [TextSpan(text: 'test')],
            ),
          },
        );
        expect(d.getRichText(CellCoordinate(0, 0)), isNotNull);
        d.dispose();
      });

      test('cells getter includes richText', () {
        data.setRichText(
            CellCoordinate(0, 0), const [TextSpan(text: 'hello')]);
        data.setCell(CellCoordinate(0, 0), CellValue.text('hello'));
        final cells = data.cells;
        expect(cells[CellCoordinate(0, 0)]?.richText, isNotNull);
      });

      test('batch setRichText works', () {
        data.batchUpdate((batch) {
          batch.setRichText(
              CellCoordinate(0, 0), const [TextSpan(text: 'hi')]);
        });
        expect(data.getRichText(CellCoordinate(0, 0)), isNotNull);
      });

      test('batch clearValues clears richText', () {
        data.setRichText(
            CellCoordinate(0, 0), const [TextSpan(text: 'hello')]);
        data.batchUpdate((batch) {
          batch.clearValues(CellRange(0, 0, 0, 0));
        });
        expect(data.getRichText(CellCoordinate(0, 0)), isNull);
      });
    });

    group('replicateMerges', () {
      test('fill down tiles single-row merge', () {
        // Source row 0 has a 1×2 merge at (0,0)-(0,1)
        data.setCell(CellCoordinate(0, 0), CellValue.text('merged'));
        data.mergeCells(CellRange(0, 0, 0, 1));

        // Fill down 3 rows: target rows 1-3
        data.replicateMerges(
          sourceRange: CellRange(0, 0, 0, 1),
          targetRange: CellRange(1, 0, 3, 1),
          vertical: true,
        );

        // Each target row gets the same 1×2 merge
        expect(data.mergedCells.getRegion(CellCoordinate(1, 0)), isNotNull);
        expect(
          data.mergedCells.getRegion(CellCoordinate(1, 0))!.range,
          CellRange(1, 0, 1, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 2, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(3, 0))!.range,
          CellRange(3, 0, 3, 1),
        );
      });

      test('fill down tiles multi-row pattern', () {
        // 2-row source with 2×2 merge at (0,0)-(1,1)
        data.setCell(CellCoordinate(0, 0), CellValue.text('big'));
        data.mergeCells(CellRange(0, 0, 1, 1));

        // Fill 4 target rows: rows 2-5 → merge appears twice
        data.replicateMerges(
          sourceRange: CellRange(0, 0, 1, 1),
          targetRange: CellRange(2, 0, 5, 1),
          vertical: true,
        );

        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 3, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(4, 0))!.range,
          CellRange(4, 0, 5, 1),
        );
      });

      test('fill right tiles single-col merge', () {
        // Source col 0 has a 2×1 merge at (0,0)-(1,0)
        data.setCell(CellCoordinate(0, 0), CellValue.text('merged'));
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Fill right 3 cols: target cols 1-3
        data.replicateMerges(
          sourceRange: CellRange(0, 0, 1, 0),
          targetRange: CellRange(0, 1, 1, 3),
          vertical: false,
        );

        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 1))!.range,
          CellRange(0, 1, 1, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 2))!.range,
          CellRange(0, 2, 1, 2),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 3))!.range,
          CellRange(0, 3, 1, 3),
        );
      });

      test('fill right tiles multi-col pattern', () {
        // 2-col source with 2×2 merge at (0,0)-(1,1)
        data.setCell(CellCoordinate(0, 0), CellValue.text('big'));
        data.mergeCells(CellRange(0, 0, 1, 1));

        // Fill 4 target cols: cols 2-5 → merge appears twice
        data.replicateMerges(
          sourceRange: CellRange(0, 0, 1, 1),
          targetRange: CellRange(0, 2, 1, 5),
          vertical: false,
        );

        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 2))!.range,
          CellRange(0, 2, 1, 3),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 4))!.range,
          CellRange(0, 4, 1, 5),
        );
      });

      test('incomplete tile at boundary skipped', () {
        // Source: 2-row merge
        data.setCell(CellCoordinate(0, 0), CellValue.text('merged'));
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Target has 3 rows (not evenly divisible by 2)
        data.replicateMerges(
          sourceRange: CellRange(0, 0, 1, 0),
          targetRange: CellRange(2, 0, 4, 0),
          vertical: true,
        );

        // First tile fits: rows 2-3
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 3, 0),
        );
        // Second tile would be rows 4-5, but row 5 > target end → skipped
        expect(data.mergedCells.getRegion(CellCoordinate(4, 0)), isNull);
      });

      test('existing merges in target cleared', () {
        // Pre-existing merge in target
        data.setCell(CellCoordinate(2, 0), CellValue.text('old'));
        data.mergeCells(CellRange(2, 0, 2, 1));

        // Source merge
        data.setCell(CellCoordinate(0, 0), CellValue.text('new'));
        data.mergeCells(CellRange(0, 0, 0, 1));

        data.replicateMerges(
          sourceRange: CellRange(0, 0, 0, 1),
          targetRange: CellRange(1, 0, 3, 1),
          vertical: true,
        );

        // Old merge at (2,0)-(2,1) is replaced by the new tiled merge
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 2, 1),
        );
      });

      test('no merges in source = no-op', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('plain'));

        data.replicateMerges(
          sourceRange: CellRange(0, 0, 0, 0),
          targetRange: CellRange(1, 0, 3, 0),
          vertical: true,
        );

        expect(data.mergedCells.isEmpty, isTrue);
      });

      test('non-anchor values cleared', () {
        // Source: merge at (0,0)-(0,1) with anchor value
        data.setCell(CellCoordinate(0, 0), CellValue.text('anchor'));
        data.mergeCells(CellRange(0, 0, 0, 1));

        // Set values in target that should be cleared
        data.setCell(CellCoordinate(1, 0), CellValue.text('keep'));
        data.setCell(CellCoordinate(1, 1), CellValue.text('clear me'));

        data.replicateMerges(
          sourceRange: CellRange(0, 0, 0, 1),
          targetRange: CellRange(1, 0, 1, 1),
          vertical: true,
        );

        // Anchor cell (1,0) keeps its value
        expect(data.getCell(CellCoordinate(1, 0)), CellValue.text('keep'));
        // Non-anchor cell (1,1) has value cleared
        expect(data.getCell(CellCoordinate(1, 1)), isNull);
      });
    });

    group('moveMerges', () {
      test('single merge moves to destination', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('merged'));
        data.mergeCells(CellRange(0, 0, 1, 1));

        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));

        // Source merge removed
        expect(data.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
        // Destination merge created
        expect(
          data.mergedCells.getRegion(CellCoordinate(5, 5))!.range,
          CellRange(5, 5, 6, 6),
        );
      });

      test('multiple merges move together', () {
        data.mergeCells(CellRange(0, 0, 0, 1));
        data.mergeCells(CellRange(1, 0, 1, 1));

        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));

        expect(data.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
        expect(data.mergedCells.getRegion(CellCoordinate(1, 0)), isNull);
        expect(
          data.mergedCells.getRegion(CellCoordinate(5, 5))!.range,
          CellRange(5, 5, 5, 6),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(6, 5))!.range,
          CellRange(6, 5, 6, 6),
        );
      });

      test('source merges are removed', () {
        data.mergeCells(CellRange(2, 2, 3, 3));

        data.moveMerges(CellRange(2, 2, 3, 3), CellCoordinate(0, 0));

        expect(data.mergedCells.getRegion(CellCoordinate(2, 2)), isNull);
        expect(data.mergedCells.getRegion(CellCoordinate(3, 3)), isNull);
      });

      test('non-merge cells unaffected', () {
        // Merge outside the source range
        data.mergeCells(CellRange(8, 8, 9, 9));
        // Merge inside the source range
        data.mergeCells(CellRange(0, 0, 1, 1));

        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));

        // Outside merge untouched
        expect(
          data.mergedCells.getRegion(CellCoordinate(8, 8))!.range,
          CellRange(8, 8, 9, 9),
        );
      });

      test('out-of-bounds merge skipped', () {
        final smallData =
            SparseWorksheetData(rowCount: 5, columnCount: 5);
        smallData.mergeCells(CellRange(0, 0, 1, 1));

        // Move to (4,4) would create merge at (4,4)-(5,5) which is out of bounds
        smallData.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(4, 4));

        // Source merge removed
        expect(smallData.mergedCells.getRegion(CellCoordinate(0, 0)), isNull);
        // Destination merge not created (out of bounds)
        expect(smallData.mergedCells.getRegion(CellCoordinate(4, 4)), isNull);

        smallData.dispose();
      });

      test('no-op when no merges', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('plain'));

        // Should not throw
        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));

        expect(data.mergedCells.regions, isEmpty);
      });

      test('destination existing merges are cleared', () {
        // Merge at destination
        data.mergeCells(CellRange(5, 5, 6, 6));
        // Merge at source
        data.mergeCells(CellRange(0, 0, 1, 1));

        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));

        // Old destination merge replaced by moved merge
        expect(
          data.mergedCells.getRegion(CellCoordinate(5, 5))!.range,
          CellRange(5, 5, 6, 6),
        );
      });

      test('emits change event', () async {
        data.mergeCells(CellRange(0, 0, 1, 1));

        final events = <DataChangeEvent>[];
        data.changes.listen(events.add);

        data.moveMerges(CellRange(0, 0, 1, 1), CellCoordinate(5, 5));
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
      });
    });

    group('smartFill with merges', () {
      test('smart fill down preserves merges', () {
        // Source: row 0 with 1×2 merge and values
        data[(0, 0)] = Cell.number(1);
        data[(0, 2)] = Cell.number(2);
        data.mergeCells(CellRange(0, 0, 0, 1));

        // Smart fill down to row 2
        data.smartFill(
          CellRange(0, 0, 0, 2),
          CellCoordinate(2, 2),
        );

        // Merges tiled into target rows
        expect(
          data.mergedCells.getRegion(CellCoordinate(1, 0))!.range,
          CellRange(1, 0, 1, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 2, 1),
        );
      });

      test('smart fill right preserves merges', () {
        // Source: col 0 with 2×1 merge and values
        data[(0, 0)] = Cell.number(1);
        data[(2, 0)] = Cell.number(2);
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Smart fill right to col 2
        data.smartFill(
          CellRange(0, 0, 2, 0),
          CellCoordinate(2, 2),
        );

        // Merges tiled into target cols
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 1))!.range,
          CellRange(0, 1, 1, 1),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 2))!.range,
          CellRange(0, 2, 1, 2),
        );
      });

      test('fill down expands for incomplete tile', () {
        // Source: rows 0-1 with a 2-row merge in cols 0-1
        data[(0, 0)] = Cell.number(1);
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Drag to row 4 → target is rows 2-4 (3 rows, not divisible by 2)
        final result = data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(4, 0),
        );

        // Should expand to row 5 (4 target rows = 2 complete tiles)
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 3, 0),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(4, 0))!.range,
          CellRange(4, 0, 5, 0),
        );
        expect(result, CellRange(0, 0, 5, 0));
      });

      test('fill right expands for incomplete tile', () {
        // Source: cols 0-1 with a 1×2 merge in row 0
        data[(0, 0)] = Cell.number(1);
        data.mergeCells(CellRange(0, 0, 0, 1));

        // Drag to col 4 → target is cols 2-4 (3 cols, not divisible by 2)
        final result = data.smartFill(
          CellRange(0, 0, 0, 1),
          CellCoordinate(0, 4),
        );

        // Should expand to col 5 (4 target cols = 2 complete tiles)
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 2))!.range,
          CellRange(0, 2, 0, 3),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 4))!.range,
          CellRange(0, 4, 0, 5),
        );
        expect(result, CellRange(0, 0, 0, 5));
      });

      test('fill up expands startRow', () {
        // Source: rows 8-9 with a 2-row merge
        data[(8, 0)] = Cell.number(1);
        data.mergeCells(CellRange(8, 0, 9, 0));

        // Fill up to row 6 → target is rows 6-7 (2 rows = exact fit)
        // Now try with 3-row gap: fill up to row 5 → target rows 5-7
        final result = data.smartFill(
          CellRange(8, 0, 9, 0),
          CellCoordinate(5, 0),
        );

        // Should expand startRow to 4 (4 target rows = 2 complete tiles)
        expect(
          data.mergedCells.getRegion(CellCoordinate(4, 0))!.range,
          CellRange(4, 0, 5, 0),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(6, 0))!.range,
          CellRange(6, 0, 7, 0),
        );
        expect(result, CellRange(4, 0, 9, 0));
      });

      test('fill left expands startColumn', () {
        // Source: cols 8-9 with a 1×2 merge
        data[(0, 8)] = Cell.number(1);
        data.mergeCells(CellRange(0, 8, 0, 9));

        // Fill left to col 5 → target cols 5-7 (3 cols, not divisible by 2)
        final result = data.smartFill(
          CellRange(0, 8, 0, 9),
          CellCoordinate(0, 5),
        );

        // Should expand startColumn to 4 (4 target cols = 2 complete tiles)
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 4))!.range,
          CellRange(0, 4, 0, 5),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(0, 6))!.range,
          CellRange(0, 6, 0, 7),
        );
        expect(result, CellRange(0, 4, 0, 9));
      });

      test('no expansion when evenly divisible', () {
        // Source: rows 0-1 with a 2-row merge
        data[(0, 0)] = Cell.number(1);
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Drag to row 5 → target is rows 2-5 (4 rows, divisible by 2)
        final result = data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(5, 0),
        );

        // Exactly 2 tiles, no expansion needed
        expect(
          data.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 3, 0),
        );
        expect(
          data.mergedCells.getRegion(CellCoordinate(4, 0))!.range,
          CellRange(4, 0, 5, 0),
        );
        expect(result, CellRange(0, 0, 5, 0));
      });

      test('no expansion when no merges', () {
        // Source: rows 0-1 with plain values, no merges
        data[(0, 0)] = Cell.number(1);
        data[(1, 0)] = Cell.number(2);

        // Drag to row 4 → target is rows 2-4 (3 rows)
        final result = data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(4, 0),
        );

        // No expansion — return is source union original target
        expect(result, CellRange(0, 0, 4, 0));
      });

      test('no expansion when exceeds worksheet bounds', () {
        // Small worksheet
        final smallData =
            SparseWorksheetData(rowCount: 5, columnCount: 5);

        // Source: rows 0-1 with a 2-row merge
        smallData[(0, 0)] = Cell.number(1);
        smallData.mergeCells(CellRange(0, 0, 1, 0));

        // Drag to row 4 → target rows 2-4, expansion would need row 5
        // but rowCount is 5 so max row is 4
        final result = smallData.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(4, 0),
        );

        // Only 1 complete tile (rows 2-3), row 4 is unfilled merge
        expect(
          smallData.mergedCells.getRegion(CellCoordinate(2, 0))!.range,
          CellRange(2, 0, 3, 0),
        );
        // No merge at row 4 since expansion was blocked
        expect(smallData.mergedCells.getRegion(CellCoordinate(4, 0)), isNull);
        expect(result, CellRange(0, 0, 4, 0));

        smallData.dispose();
      });

      test('returns null when destination inside source', () {
        data[(0, 0)] = Cell.number(1);
        data.mergeCells(CellRange(0, 0, 1, 0));

        final result = data.smartFill(
          CellRange(0, 0, 3, 0),
          CellCoordinate(2, 0),
        );

        expect(result, isNull);
      });

      test('values also fill expanded area', () {
        // Source: rows 0-1 with merge and a pattern
        data[(0, 0)] = Cell.number(10);
        data[(1, 0)] = Cell.number(20);
        data.mergeCells(CellRange(0, 1, 1, 1)); // merge in col 1

        // Drag to row 4 → target rows 2-4, expanded to row 5
        data.smartFill(
          CellRange(0, 0, 1, 1),
          CellCoordinate(4, 0),
        );

        // Values in col 0 should fill the expanded area too
        expect(data.getCell(CellCoordinate(4, 0)), isNotNull);
        expect(data.getCell(CellCoordinate(5, 0)), isNotNull);
      });

      test('return value includes expanded area', () {
        // Source: rows 0-1 with 2-row merge
        data[(0, 0)] = Cell.number(1);
        data.mergeCells(CellRange(0, 0, 1, 0));

        // Drag to row 4 → target rows 2-4, should expand to row 5
        final result = data.smartFill(
          CellRange(0, 0, 1, 0),
          CellCoordinate(4, 0),
        );

        // Result should cover source (0-1) union expanded target (2-5)
        expect(result, CellRange(0, 0, 5, 0));
      });
    });
  });
}
