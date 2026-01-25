import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_tester.dart';

/// Benchmark tests for hit testing performance.
///
/// Target: Hit test latency < 100 microseconds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LayoutSolver layoutSolver;
  late WorksheetHitTester hitTester;
  final random = Random(42); // Fixed seed for reproducibility

  setUp(() {
    final rows = SpanList(defaultSize: 24.0, count: 10000);
    final columns = SpanList(defaultSize: 80.0, count: 1000);

    // Add some variable row/column sizes
    for (int i = 0; i < 100; i++) {
      rows.setSize(i * 100, 48.0); // Double height every 100 rows
      columns.setSize(i * 10, 120.0); // Wider every 10 columns
    }

    layoutSolver = LayoutSolver(rows: rows, columns: columns);

    hitTester = WorksheetHitTester(
      layoutSolver: layoutSolver,
      headerWidth: 50.0,
      headerHeight: 30.0,
    );
  });

  group('HitTestBenchmark', () {
    test('hit test completes in under 100 microseconds', () {
      const iterations = 10000;
      final times = <int>[];

      // Generate random positions within a reasonable viewport
      final positions = <Offset>[];
      for (int i = 0; i < iterations; i++) {
        positions.add(Offset(
          random.nextDouble() * 2000,
          random.nextDouble() * 2000,
        ));
      }

      // Warm up
      for (int i = 0; i < 100; i++) {
        hitTester.hitTest(
          position: positions[i],
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
      }

      // Benchmark
      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        hitTester.hitTest(
          position: positions[i],
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicroseconds = times.reduce((a, b) => a + b) / times.length;
      final maxMicroseconds = times.reduce((a, b) => a > b ? a : b);
      final minMicroseconds = times.reduce((a, b) => a < b ? a : b);

      // Calculate percentiles
      times.sort();
      final p50 = times[times.length ~/ 2];
      final p95 = times[(times.length * 0.95).floor()];
      final p99 = times[(times.length * 0.99).floor()];

      // ignore: avoid_print
      print('Hit test benchmark ($iterations iterations):');
      // ignore: avoid_print
      print('  Average: ${avgMicroseconds.toStringAsFixed(1)} us');
      // ignore: avoid_print
      print('  Min: $minMicroseconds us');
      // ignore: avoid_print
      print('  Max: $maxMicroseconds us');
      // ignore: avoid_print
      print('  P50: $p50 us');
      // ignore: avoid_print
      print('  P95: $p95 us');
      // ignore: avoid_print
      print('  P99: $p99 us');

      // Target: average under 100 microseconds
      expect(
        avgMicroseconds,
        lessThan(100),
        reason: 'Average hit test should be under 100 microseconds',
      );
    });

    test('hit test performance at different scroll offsets', () {
      const iterations = 1000;
      final scrollOffsets = [
        Offset.zero,
        const Offset(1000, 500),
        const Offset(50000, 25000),
        const Offset(100000, 100000),
      ];

      for (final offset in scrollOffsets) {
        final times = <int>[];

        for (int i = 0; i < iterations; i++) {
          final position = Offset(
            random.nextDouble() * 800,
            random.nextDouble() * 600,
          );

          final stopwatch = Stopwatch()..start();
          hitTester.hitTest(
            position: position,
            scrollOffset: offset,
            zoom: 1.0,
          );
          stopwatch.stop();
          times.add(stopwatch.elapsedMicroseconds);
        }

        final avgUs = times.reduce((a, b) => a + b) / times.length;
        // ignore: avoid_print
        print('Scroll offset $offset: ${avgUs.toStringAsFixed(1)} us avg');

        // Should be consistent regardless of scroll position
        expect(avgUs, lessThan(100));
      }
    });

    test('hit test performance at different zoom levels', () {
      const iterations = 1000;
      const zooms = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0];

      for (final zoom in zooms) {
        final times = <int>[];

        for (int i = 0; i < iterations; i++) {
          final position = Offset(
            random.nextDouble() * 800,
            random.nextDouble() * 600,
          );

          final stopwatch = Stopwatch()..start();
          hitTester.hitTest(
            position: position,
            scrollOffset: const Offset(1000, 500),
            zoom: zoom,
          );
          stopwatch.stop();
          times.add(stopwatch.elapsedMicroseconds);
        }

        final avgUs = times.reduce((a, b) => a + b) / times.length;
        // ignore: avoid_print
        print('Zoom $zoom: ${avgUs.toStringAsFixed(1)} us avg');

        // Should be consistent regardless of zoom level
        expect(avgUs, lessThan(100));
      }
    });

    test('header hit test performance', () {
      const iterations = 5000;
      final times = <int>[];

      // Generate positions in header areas
      final positions = <Offset>[];
      for (int i = 0; i < iterations; i++) {
        final isRowHeader = random.nextBool();
        if (isRowHeader) {
          // Row header area
          positions.add(Offset(
            random.nextDouble() * 50, // Within header width
            30 + random.nextDouble() * 570, // Below column header
          ));
        } else {
          // Column header area
          positions.add(Offset(
            50 + random.nextDouble() * 750, // Right of row header
            random.nextDouble() * 30, // Within header height
          ));
        }
      }

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        hitTester.hitTest(
          position: positions[i],
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('Header hit test: ${avgUs.toStringAsFixed(1)} us avg');

      // Header hit tests should be even faster than cell hit tests
      expect(avgUs, lessThan(50));
    });
  });
}
