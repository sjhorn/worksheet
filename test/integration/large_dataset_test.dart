import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet2/src/core/geometry/layout_solver.dart';
import 'package:worksheet2/src/core/geometry/span_list.dart';
import 'package:worksheet2/src/core/geometry/visible_range_calculator.dart';
import 'package:worksheet2/src/core/models/cell_coordinate.dart';
import 'package:worksheet2/src/core/models/cell_range.dart';
import 'package:worksheet2/src/core/models/cell_value.dart';
import 'package:worksheet2/src/interaction/controllers/selection_controller.dart';

/// Integration tests for large dataset handling.
///
/// Tests worksheet functionality with 1 million cells to ensure
/// scalability and performance don't degrade significantly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LargeDatasetTest', () {
    test('handles 1 million cells in sparse data', () {
      // 1000 rows x 1000 columns = 1 million potential cells
      final data = SparseWorksheetData(rowCount: 1000, columnCount: 1000);

      // Populate 10% of cells (100k cells)
      final stopwatch = Stopwatch()..start();
      for (int row = 0; row < 1000; row += 3) {
        for (int col = 0; col < 1000; col += 3) {
          data.setCell(
            CellCoordinate(row, col),
            CellValue.number(row * 1000.0 + col),
          );
        }
      }
      stopwatch.stop();

      // ignore: avoid_print
      print('Time to populate ~111k cells: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Under 5 seconds

      // Verify data integrity
      expect(data.getCell(const CellCoordinate(0, 0))?.rawValue, 0.0);
      expect(data.getCell(const CellCoordinate(998, 998)), isNull); // Not on 3-grid (998 % 3 = 2)
      expect(data.getCell(const CellCoordinate(999, 996))?.rawValue, 999996.0);
    });

    test('layout solver handles 100k rows', () {
      final rows = SpanList(defaultSize: 24.0, count: 100000);
      final columns = SpanList(defaultSize: 80.0, count: 100);

      // Add some custom sizes
      for (int i = 0; i < 100000; i += 100) {
        rows.setSize(i, 48.0);
      }

      final layoutSolver = LayoutSolver(rows: rows, columns: columns);

      // Verify total size calculation
      expect(layoutSolver.rowCount, 100000);
      expect(layoutSolver.totalHeight, greaterThan(0));

      // Test cell bounds at various positions
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        final row = (i * 11) % 100000;
        layoutSolver.getCellBounds(CellCoordinate(row, 0));
      }
      stopwatch.stop();

      // ignore: avoid_print
      print('10k cell bounds lookups: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Under 100ms
    });

    test('visible range calculation scales with worksheet size', () {
      // Test with increasingly large worksheets
      final sizes = [
        (1000, 100),
        (10000, 100),
        (100000, 100),
        (100000, 1000),
      ];

      for (final (rowCount, colCount) in sizes) {
        final rows = SpanList(defaultSize: 24.0, count: rowCount);
        final columns = SpanList(defaultSize: 80.0, count: colCount);
        final layoutSolver = LayoutSolver(rows: rows, columns: columns);
        final rangeCalculator = VisibleRangeCalculator(layoutSolver: layoutSolver);

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          rangeCalculator.getVisibleRange(
            viewport: Rect.fromLTWH(i * 10.0, i * 10.0, 1200, 800),
          );
        }
        stopwatch.stop();

        final avgMs = stopwatch.elapsedMilliseconds / 1000;
        // ignore: avoid_print
        print('${rowCount}x$colCount: ${avgMs.toStringAsFixed(3)}ms avg per calculation');

        // Visible range calculation should be O(log n) or better
        expect(avgMs, lessThan(1.0));
      }
    });

    test('selection controller handles large ranges', () {
      final controller = SelectionController();
      addTearDown(controller.dispose);

      // Select a large range
      final stopwatch = Stopwatch()..start();
      controller.selectRange(const CellRange(0, 0, 9999, 999));
      stopwatch.stop();

      // ignore: avoid_print
      print('Large range selection: ${stopwatch.elapsedMicroseconds}us');
      expect(stopwatch.elapsedMicroseconds, lessThan(1000));

      // Verify range
      expect(controller.selectedRange?.startRow, 0);
      expect(controller.selectedRange?.endRow, 9999);
      expect(controller.selectedRange?.startColumn, 0);
      expect(controller.selectedRange?.endColumn, 999);
    });

    test('data changes stream scales', () async {
      final data = SparseWorksheetData(rowCount: 10000, columnCount: 1000);

      var changeCount = 0;
      final subscription = data.changes.listen((_) => changeCount++);
      addTearDown(subscription.cancel);

      // Make many changes rapidly
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        data.setCell(
          CellCoordinate(i, i % 1000),
          CellValue.number(i.toDouble()),
        );
      }
      stopwatch.stop();

      // ignore: avoid_print
      print('1000 rapid changes: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Allow stream to process
      await Future.delayed(const Duration(milliseconds: 10));
      expect(changeCount, 1000);
    });

    test('batch operations on large dataset', () {
      final data = SparseWorksheetData(rowCount: 10000, columnCount: 1000);

      final stopwatch = Stopwatch()..start();
      data.batchUpdate((batch) {
        for (int row = 0; row < 100; row++) {
          for (int col = 0; col < 100; col++) {
            batch.setCell(
              CellCoordinate(row, col),
              CellValue.text('$row,$col'),
            );
          }
        }
      });
      stopwatch.stop();

      // ignore: avoid_print
      print('Batch set 10k cells: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      // Verify
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, '0,0');
      expect(data.getCell(const CellCoordinate(99, 99))?.displayValue, '99,99');
    });
  });
}
