import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/visible_range_calculator.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  group('VisibleRangeCalculator', () {
    late LayoutSolver layoutSolver;
    late VisibleRangeCalculator calculator;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      calculator = VisibleRangeCalculator(layoutSolver: layoutSolver);
    });

    group('getVisibleRange', () {
      test('calculates range for viewport at origin', () {
        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(0, 0, 500, 200),
        );

        // 500px wide = 5 columns (0-4), 200px tall = 8 rows (0-7)
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 7);
        expect(range.endColumn, 4);
      });

      test('calculates range for offset viewport', () {
        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(150, 50, 500, 200),
        );

        // x=150-650, y=50-250
        // columns: 150/100=1 to 650/100=6 (cols 1-6)
        // rows: 50/25=2 to 250/25=9 (rows 2-9)
        expect(range.startColumn, 1);
        expect(range.endColumn, 6);
        expect(range.startRow, 2);
        expect(range.endRow, 9);
      });

      test('clamps to content bounds', () {
        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(9500, 24800, 1000, 500),
        );

        // Should clamp to max row/column
        expect(range.endRow, 999);
        expect(range.endColumn, 99);
      });

      test('handles viewport larger than content', () {
        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(0, 0, 20000, 50000),
        );

        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 999);
        expect(range.endColumn, 99);
      });

      test('handles partial cell visibility at edges', () {
        // Viewport starts at 10px into first row/column
        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(10, 10, 100, 25),
        );

        // Should include partially visible cells
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        // 10+100=110 is in column 1, 10+25=35 is in row 1
        expect(range.endColumn, 1);
        expect(range.endRow, 1);
      });
    });

    group('getVisibleRangeWithPadding', () {
      test('adds padding around visible range', () {
        final range = calculator.getVisibleRangeWithPadding(
          viewport: const Rect.fromLTWH(500, 250, 500, 200),
          rowPadding: 2,
          columnPadding: 1,
        );

        // Base range: rows 10-17, cols 5-9
        // With padding: rows 8-19, cols 4-10
        final baseRange = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(500, 250, 500, 200),
        );

        expect(range.startRow, baseRange.startRow - 2);
        expect(range.endRow, baseRange.endRow + 2);
        expect(range.startColumn, baseRange.startColumn - 1);
        expect(range.endColumn, baseRange.endColumn + 1);
      });

      test('clamps padding to valid range', () {
        final range = calculator.getVisibleRangeWithPadding(
          viewport: const Rect.fromLTWH(0, 0, 500, 200),
          rowPadding: 10,
          columnPadding: 10,
        );

        // Should not go below 0
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
      });

      test('clamps padding at content end', () {
        final range = calculator.getVisibleRangeWithPadding(
          viewport: const Rect.fromLTWH(9500, 24800, 500, 200),
          rowPadding: 10,
          columnPadding: 10,
        );

        // Should not exceed max
        expect(range.endRow, 999);
        expect(range.endColumn, 99);
      });
    });

    group('isRangeVisible', () {
      test('returns true for fully visible range', () {
        final viewport = const Rect.fromLTWH(0, 0, 500, 200);
        final range = CellRange(0, 0, 3, 2);

        expect(calculator.isRangeVisible(range, viewport), isTrue);
      });

      test('returns true for partially visible range', () {
        final viewport = const Rect.fromLTWH(0, 0, 500, 200);
        final range = CellRange(5, 3, 10, 8); // Partially overlaps

        expect(calculator.isRangeVisible(range, viewport), isTrue);
      });

      test('returns false for non-visible range', () {
        final viewport = const Rect.fromLTWH(0, 0, 500, 200);
        final range = CellRange(100, 50, 110, 60); // Way outside

        expect(calculator.isRangeVisible(range, viewport), isFalse);
      });
    });

    group('isCellVisible', () {
      test('returns true for visible cell', () {
        final viewport = const Rect.fromLTWH(0, 0, 500, 200);

        expect(calculator.isCellVisible(0, 0, viewport), isTrue);
        expect(calculator.isCellVisible(3, 2, viewport), isTrue);
      });

      test('returns false for non-visible cell', () {
        final viewport = const Rect.fromLTWH(0, 0, 500, 200);

        expect(calculator.isCellVisible(100, 0, viewport), isFalse);
        expect(calculator.isCellVisible(0, 50, viewport), isFalse);
      });
    });

    group('getViewportForRange', () {
      test('calculates minimum viewport to show range', () {
        final range = CellRange(5, 3, 10, 7);
        final viewport = calculator.getViewportForRange(range);

        // Range: rows 5-10, cols 3-7
        // Position: col 3 starts at 300, col 8 starts at 800 (width 500)
        // Position: row 5 starts at 125, row 11 starts at 275 (height 150)
        expect(viewport.left, 300.0);
        expect(viewport.top, 125.0);
        expect(viewport.width, 500.0);
        expect(viewport.height, 150.0);
      });

      test('handles single cell', () {
        final range = CellRange(0, 0, 0, 0);
        final viewport = calculator.getViewportForRange(range);

        expect(viewport.left, 0.0);
        expect(viewport.top, 0.0);
        expect(viewport.width, 100.0);
        expect(viewport.height, 25.0);
      });
    });

    group('with custom sizes', () {
      test('accounts for custom row heights', () {
        layoutSolver.setRowHeight(0, 100.0); // 4x normal

        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(0, 0, 500, 200),
        );

        // Row 0 is 100px, leaves 100px for ~4 more rows
        expect(range.startRow, 0);
        expect(range.endRow, 4); // row 0 (100px) + rows 1-4 (100px)
      });

      test('accounts for custom column widths', () {
        layoutSolver.setColumnWidth(0, 300.0); // 3x normal

        final range = calculator.getVisibleRange(
          viewport: const Rect.fromLTWH(0, 0, 500, 200),
        );

        // Column 0 is 300px, leaves 200px for 2 more columns
        expect(range.startColumn, 0);
        expect(range.endColumn, 2);
      });
    });
  });
}
