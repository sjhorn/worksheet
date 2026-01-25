import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/visible_range_calculator.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

/// Benchmark tests for scroll-related calculations.
///
/// Target: Maintain calculations fast enough for 60fps scrolling.
/// At 60fps, we have ~16.67ms per frame. Scroll calculations should
/// take < 2ms to leave room for rendering.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LayoutSolver layoutSolver;
  late VisibleRangeCalculator rangeCalculator;
  late SparseWorksheetData data;

  setUp(() {
    // Large worksheet: 10,000 rows x 1,000 columns
    final rows = SpanList(defaultSize: 24.0, count: 10000);
    final columns = SpanList(defaultSize: 80.0, count: 1000);

    // Add variable sizes
    for (int i = 0; i < 1000; i++) {
      if (i % 10 == 0) {
        rows.setSize(i, 48.0);
      }
      if (i % 50 == 0) {
        columns.setSize(i ~/ 50, 120.0);
      }
    }

    layoutSolver = LayoutSolver(rows: rows, columns: columns);
    rangeCalculator = VisibleRangeCalculator(layoutSolver: layoutSolver);

    // Create data with some populated cells
    data = SparseWorksheetData(rowCount: 10000, columnCount: 1000);
    for (int row = 0; row < 1000; row += 10) {
      for (int col = 0; col < 100; col += 5) {
        data.setCell(
          CellCoordinate(row, col),
          CellValue.text('R${row}C$col'),
        );
      }
    }
  });

  group('ScrollPerformanceBenchmark', () {
    test('visible range calculation under 2ms', () {
      const iterations = 1000;
      final times = <int>[];
      const viewportWidth = 1200.0;
      const viewportHeight = 800.0;

      // Simulate scrolling through the worksheet
      for (int i = 0; i < iterations; i++) {
        final scrollY = (i * 50.0) % (layoutSolver.totalHeight - viewportHeight);
        final scrollX = (i * 30.0) % (layoutSolver.totalWidth - viewportWidth);

        final stopwatch = Stopwatch()..start();
        rangeCalculator.getVisibleRange(
          viewport: Rect.fromLTWH(scrollX, scrollY, viewportWidth, viewportHeight),
        );
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;
      final maxUs = times.reduce((a, b) => a > b ? a : b);

      // ignore: avoid_print
      print('Visible range calculation:');
      // ignore: avoid_print
      print('  Average: ${(avgUs / 1000).toStringAsFixed(3)} ms');
      // ignore: avoid_print
      print('  Max: ${(maxUs / 1000).toStringAsFixed(3)} ms');

      // Target: under 2ms average (leaving 14ms for rendering)
      expect(avgUs / 1000, lessThan(2.0));
    });

    test('cell bounds lookup under 10 microseconds', () {
      const iterations = 10000;
      final times = <int>[];

      // Test various cell locations
      for (int i = 0; i < iterations; i++) {
        final row = (i * 7) % 10000;
        final col = (i * 3) % 1000;

        final stopwatch = Stopwatch()..start();
        layoutSolver.getCellBounds(CellCoordinate(row, col));
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;

      // ignore: avoid_print
      print('Cell bounds lookup: ${avgUs.toStringAsFixed(2)} us avg');

      // Cell bounds lookup should be O(1) or O(log n) - very fast
      expect(avgUs, lessThan(10));
    });

    test('row/column position lookup performance', () {
      const iterations = 10000;
      final rowTimes = <int>[];
      final colTimes = <int>[];

      for (int i = 0; i < iterations; i++) {
        final row = (i * 7) % 10000;
        var stopwatch = Stopwatch()..start();
        layoutSolver.getRowTop(row);
        stopwatch.stop();
        rowTimes.add(stopwatch.elapsedMicroseconds);

        final col = (i * 3) % 1000;
        stopwatch = Stopwatch()..start();
        layoutSolver.getColumnLeft(col);
        stopwatch.stop();
        colTimes.add(stopwatch.elapsedMicroseconds);
      }

      final avgRowUs = rowTimes.reduce((a, b) => a + b) / rowTimes.length;
      final avgColUs = colTimes.reduce((a, b) => a + b) / colTimes.length;

      // ignore: avoid_print
      print('Row position lookup: ${avgRowUs.toStringAsFixed(2)} us avg');
      // ignore: avoid_print
      print('Column position lookup: ${avgColUs.toStringAsFixed(2)} us avg');

      expect(avgRowUs, lessThan(5));
      expect(avgColUs, lessThan(5));
    });

    test('position to cell index lookup performance', () {
      const iterations = 10000;
      final times = <int>[];

      // Generate various y positions throughout the worksheet
      for (int i = 0; i < iterations; i++) {
        final y = (i * 123.456) % layoutSolver.totalHeight;

        final stopwatch = Stopwatch()..start();
        layoutSolver.getRowAt(y);
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;

      // ignore: avoid_print
      print('Position to row lookup: ${avgUs.toStringAsFixed(2)} us avg');

      // Binary search should be O(log n)
      expect(avgUs, lessThan(10));
    });

    test('visible range at different zoom levels', () {
      const zooms = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0];
      const iterations = 500;
      const viewportWidth = 1200.0;
      const viewportHeight = 800.0;

      for (final zoom in zooms) {
        final times = <int>[];

        for (int i = 0; i < iterations; i++) {
          // At different zoom levels, the content spans different pixel areas
          final maxScrollY = (layoutSolver.totalHeight * zoom - viewportHeight).clamp(0.0, double.infinity);
          final maxScrollX = (layoutSolver.totalWidth * zoom - viewportWidth).clamp(0.0, double.infinity);
          final scrollY = maxScrollY > 0 ? (i * 100.0) % maxScrollY : 0.0;
          final scrollX = maxScrollX > 0 ? (i * 80.0) % maxScrollX : 0.0;

          // Convert viewport to content coordinates for range calculation
          final contentLeft = scrollX / zoom;
          final contentTop = scrollY / zoom;
          final contentWidth = viewportWidth / zoom;
          final contentHeight = viewportHeight / zoom;

          final stopwatch = Stopwatch()..start();
          rangeCalculator.getVisibleRange(
            viewport: Rect.fromLTWH(contentLeft, contentTop, contentWidth, contentHeight),
          );
          stopwatch.stop();
          times.add(stopwatch.elapsedMicroseconds);
        }

        final avgUs = times.reduce((a, b) => a + b) / times.length;
        // ignore: avoid_print
        print('Visible range at zoom $zoom: ${(avgUs / 1000).toStringAsFixed(3)} ms avg');

        expect(avgUs / 1000, lessThan(2.0));
      }
    });

    test('sparse data access performance', () {
      const iterations = 10000;
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final row = (i * 7) % 10000;
        final col = (i * 3) % 1000;

        final stopwatch = Stopwatch()..start();
        data.getCell(CellCoordinate(row, col));
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;

      // ignore: avoid_print
      print('Sparse data access: ${avgUs.toStringAsFixed(2)} us avg');

      // HashMap lookup should be O(1)
      expect(avgUs, lessThan(5));
    });
  });
}
