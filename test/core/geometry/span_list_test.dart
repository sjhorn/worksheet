import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/geometry/span_list.dart';

void main() {
  group('SpanList', () {
    group('construction', () {
      test('creates with default sizes', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.count, 100);
        expect(spanList.defaultSize, 25.0);
      });

      test('throws for zero count', () {
        expect(
          () => SpanList(count: 0, defaultSize: 25.0),
          throwsAssertionError,
        );
      });

      test('throws for negative count', () {
        expect(
          () => SpanList(count: -1, defaultSize: 25.0),
          throwsAssertionError,
        );
      });

      test('throws for zero default size', () {
        expect(
          () => SpanList(count: 100, defaultSize: 0),
          throwsAssertionError,
        );
      });

      test('throws for negative default size', () {
        expect(
          () => SpanList(count: 100, defaultSize: -10),
          throwsAssertionError,
        );
      });

      test('applies custom sizes', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {0: 50.0, 5: 100.0},
        );
        expect(spanList.sizeAt(0), 50.0);
        expect(spanList.sizeAt(1), 25.0);
        expect(spanList.sizeAt(5), 100.0);
      });
    });

    group('sizeAt', () {
      test('returns default size for unmodified indices', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.sizeAt(0), 25.0);
        expect(spanList.sizeAt(50), 25.0);
        expect(spanList.sizeAt(99), 25.0);
      });

      test('returns custom size for modified indices', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {10: 50.0},
        );
        expect(spanList.sizeAt(9), 25.0);
        expect(spanList.sizeAt(10), 50.0);
        expect(spanList.sizeAt(11), 25.0);
      });

      test('throws for negative index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.sizeAt(-1), throwsRangeError);
      });

      test('throws for out of bounds index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.sizeAt(100), throwsRangeError);
      });
    });

    group('positionAt', () {
      test('returns 0 for index 0', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.positionAt(0), 0.0);
      });

      test('returns cumulative sum for uniform sizes', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.positionAt(1), 25.0);
        expect(spanList.positionAt(2), 50.0);
        expect(spanList.positionAt(10), 250.0);
      });

      test('returns cumulative sum with custom sizes', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {0: 50.0, 2: 100.0},
        );
        // index 0: pos 0, size 50
        // index 1: pos 50, size 25
        // index 2: pos 75, size 100
        // index 3: pos 175, size 25
        expect(spanList.positionAt(0), 0.0);
        expect(spanList.positionAt(1), 50.0);
        expect(spanList.positionAt(2), 75.0);
        expect(spanList.positionAt(3), 175.0);
      });

      test('returns total size for count (one past last)', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.positionAt(100), 2500.0);
      });

      test('throws for negative index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.positionAt(-1), throwsRangeError);
      });

      test('throws for out of bounds index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.positionAt(101), throwsRangeError);
      });
    });

    group('indexAtPosition', () {
      test('returns 0 for position 0', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.indexAtPosition(0), 0);
      });

      test('returns correct index for uniform sizes', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.indexAtPosition(0.0), 0);
        expect(spanList.indexAtPosition(24.9), 0);
        expect(spanList.indexAtPosition(25.0), 1);
        expect(spanList.indexAtPosition(49.9), 1);
        expect(spanList.indexAtPosition(50.0), 2);
      });

      test('returns correct index with custom sizes', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {0: 50.0, 2: 100.0},
        );
        // index 0: 0-50
        // index 1: 50-75
        // index 2: 75-175
        // index 3: 175-200
        expect(spanList.indexAtPosition(0), 0);
        expect(spanList.indexAtPosition(49.9), 0);
        expect(spanList.indexAtPosition(50.0), 1);
        expect(spanList.indexAtPosition(74.9), 1);
        expect(spanList.indexAtPosition(75.0), 2);
        expect(spanList.indexAtPosition(174.9), 2);
        expect(spanList.indexAtPosition(175.0), 3);
      });

      test('returns last index for position at end', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.indexAtPosition(2499.9), 99);
      });

      test('returns -1 for negative position', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.indexAtPosition(-1), -1);
      });

      test('returns -1 for position beyond total', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.indexAtPosition(2500), -1);
        expect(spanList.indexAtPosition(3000), -1);
      });
    });

    group('totalSize', () {
      test('returns sum of all sizes', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.totalSize, 2500.0);
      });

      test('accounts for custom sizes', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {0: 50.0, 1: 50.0}, // +50 total
        );
        expect(spanList.totalSize, 2550.0);
      });
    });

    group('setSize', () {
      test('updates size and recalculates cumulative', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.sizeAt(5), 25.0);

        spanList.setSize(5, 100.0);

        expect(spanList.sizeAt(5), 100.0);
        // Position of index 5 unchanged (still 125)
        expect(spanList.positionAt(5), 125.0);
        // Position of index 6 changed (was 150, now 225)
        expect(spanList.positionAt(6), 225.0);
      });

      test('throws for negative index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.setSize(-1, 50.0), throwsRangeError);
      });

      test('throws for out of bounds index', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.setSize(100, 50.0), throwsRangeError);
      });

      test('throws for zero size', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.setSize(5, 0), throwsAssertionError);
      });

      test('throws for negative size', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(() => spanList.setSize(5, -10), throwsAssertionError);
      });

      test('updates total size', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        expect(spanList.totalSize, 2500.0);

        spanList.setSize(0, 100.0);

        expect(spanList.totalSize, 2575.0);
      });
    });

    group('property: positionAt(indexAtPosition(p)) <= p', () {
      test('for any valid position', () {
        final spanList = SpanList(
          count: 1000,
          defaultSize: 25.0,
          customSizes: {5: 50.0, 100: 10.0, 500: 200.0},
        );

        for (var p = 0.0; p < spanList.totalSize; p += 73.7) {
          final index = spanList.indexAtPosition(p);
          if (index >= 0) {
            final reconstructed = spanList.positionAt(index);
            expect(reconstructed, lessThanOrEqualTo(p));
            expect(reconstructed + spanList.sizeAt(index), greaterThan(p));
          }
        }
      });
    });

    group('property: indexAtPosition(positionAt(i)) == i', () {
      test('for any valid index', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {5: 50.0, 10: 10.0, 50: 200.0},
        );

        for (var i = 0; i < spanList.count; i++) {
          final position = spanList.positionAt(i);
          final index = spanList.indexAtPosition(position);
          expect(index, i);
        }
      });
    });

    group('performance', () {
      test('handles large count efficiently', () {
        final stopwatch = Stopwatch()..start();
        final spanList = SpanList(count: 100000, defaultSize: 25.0);
        stopwatch.stop();

        // Construction should be fast (under 100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        // Binary search should be fast
        stopwatch
          ..reset()
          ..start();
        for (var i = 0; i < 10000; i++) {
          spanList.indexAtPosition(i * 100.0);
        }
        stopwatch.stop();

        // 10000 lookups should be under 100ms
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('getRange', () {
      test('returns correct range for positions', () {
        final spanList = SpanList(
          count: 100,
          defaultSize: 25.0,
          customSizes: {2: 100.0},
        );

        // Range from 0 to 100 should include indices 0, 1, 2
        // index 0: 0-25
        // index 1: 25-50
        // index 2: 50-150 (custom size 100)
        // index 3: 150-175
        final range = spanList.getRange(0, 100);
        expect(range.startIndex, 0);
        expect(range.endIndex, 2);
      });

      test('handles partial overlap at start', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        final range = spanList.getRange(10, 60);
        expect(range.startIndex, 0); // index 0 starts at 0
        expect(range.endIndex, 2); // index 2 ends at 75
      });

      test('handles range beyond total size', () {
        final spanList = SpanList(count: 100, defaultSize: 25.0);
        final range = spanList.getRange(2400, 3000);
        expect(range.startIndex, 96);
        expect(range.endIndex, 99);
      });
    });
  });
}
