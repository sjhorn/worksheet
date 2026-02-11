import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/merged_cell_registry.dart';
import 'package:worksheet/src/core/geometry/editing_bounds_calculator.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  const textStyle = TextStyle(fontSize: 14.0, fontFamily: 'Roboto');
  const cellPadding = 4.0;

  late LayoutSolver layoutSolver;

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
  });

  group('EditingBoundsCalculator.computeHorizontal', () {
    test('empty text returns original cell bounds', () {
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(0, 0),
        text: '',
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 25,
      );

      expect(result.endColumn, 0);
      expect(result.endRow, 0);
      expect(result.bounds, layoutSolver.getCellBounds(const CellCoordinate(0, 0)));
    });

    test('short text that fits returns no expansion', () {
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(0, 0),
        text: 'Hi',
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 25,
      );

      expect(result.endColumn, 0);
      expect(result.bounds, layoutSolver.getCellBounds(const CellCoordinate(0, 0)));
    });

    test('long text expands across columns', () {
      // Create a very long text that needs multiple columns
      final longText = 'A' * 200;
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(0, 0),
        text: longText,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 25,
      );

      expect(result.endColumn, greaterThan(0));
      expect(result.endRow, 0);
      expect(result.bounds.width, greaterThan(100.0));
      expect(result.bounds.left, 0.0);
      expect(result.bounds.top, 0.0);
      expect(result.bounds.height, 24.0);
    });

    test('stops at last column', () {
      // Use a solver with only 3 columns
      final smallSolver = LayoutSolver(
        rows: SpanList(count: 10, defaultSize: 24.0),
        columns: SpanList(count: 3, defaultSize: 50.0),
      );

      final longText = 'A' * 200;
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(0, 0),
        text: longText,
        layoutSolver: smallSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 2,
      );

      expect(result.endColumn, lessThanOrEqualTo(2));
    });

    test('stops at merged cell boundary', () {
      final mergedCells = MergedCellRegistry();
      // Merge cells at (0,2) and (0,3) — expansion from (0,0) should stop at col 1
      mergedCells.merge(const CellRange(0, 2, 0, 3));

      final longText = 'A' * 200;
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(0, 0),
        text: longText,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 25,
        mergedCells: mergedCells,
      );

      expect(result.endColumn, lessThanOrEqualTo(1));
    });

    test('expansion starts from correct cell position', () {
      // Edit cell at column 3
      final result = EditingBoundsCalculator.computeHorizontal(
        cell: const CellCoordinate(2, 3),
        text: 'A' * 200,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxColumn: 25,
      );

      final cellBounds = layoutSolver.getCellBounds(const CellCoordinate(2, 3));
      expect(result.bounds.left, cellBounds.left);
      expect(result.bounds.top, cellBounds.top);
      expect(result.endRow, 2);
    });
  });

  group('EditingBoundsCalculator.computeVertical', () {
    test('empty text returns original cell bounds', () {
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: '',
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );

      expect(result.endRow, 0);
      expect(result.endColumn, 0);
      expect(result.bounds, layoutSolver.getCellBounds(const CellCoordinate(0, 0)));
    });

    test('short text that fits returns no expansion', () {
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: 'Hi',
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );

      expect(result.endRow, 0);
    });

    test('multi-line text expands across rows', () {
      // Text with newlines that wraps and needs more height
      final multiLineText = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5';
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: multiLineText,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );

      expect(result.endRow, greaterThan(0));
      expect(result.endColumn, 0);
      expect(result.bounds.height, greaterThan(24.0));
      expect(result.bounds.width, 100.0);
    });

    test('stops at last row', () {
      final smallSolver = LayoutSolver(
        rows: SpanList(count: 3, defaultSize: 24.0),
        columns: SpanList(count: 10, defaultSize: 100.0),
      );

      final multiLineText = List.generate(20, (i) => 'Line $i').join('\n');
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: multiLineText,
        layoutSolver: smallSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 2,
      );

      expect(result.endRow, lessThanOrEqualTo(2));
    });

    test('stops at merged cell boundary', () {
      final mergedCells = MergedCellRegistry();
      // Merge cells at rows 2-3 in column 0 — expansion from (0,0) should stop at row 1
      mergedCells.merge(const CellRange(2, 0, 3, 0));

      final multiLineText = List.generate(20, (i) => 'Line $i').join('\n');
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: multiLineText,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
        mergedCells: mergedCells,
      );

      expect(result.endRow, lessThanOrEqualTo(1));
    });

    test('expansion starts from correct cell position', () {
      final multiLineText = List.generate(10, (i) => 'Line $i').join('\n');
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(5, 2),
        text: multiLineText,
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );

      final cellBounds = layoutSolver.getCellBounds(const CellCoordinate(5, 2));
      expect(result.bounds.left, cellBounds.left);
      expect(result.bounds.top, cellBounds.top);
      expect(result.endColumn, 2);
    });

    test('trailing newline counts as an extra line', () {
      // "Hi\n" should measure as two lines (the cursor sits on the blank
      // line below), requiring expansion beyond a single 24px row.
      final result = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: 'Hi\n',
        layoutSolver: layoutSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );

      expect(result.endRow, greaterThan(0),
          reason: 'Trailing newline should expand into next row');
      expect(result.bounds.height, greaterThan(24.0));
    });

    test('verticalOffset accounts for bottom-aligned text position', () {
      // A 60px tall cell with bottom-aligned text starting at offset 22px.
      // After adding a newline, 2 lines of ~16.8px text = ~33.6px.
      // Without offset: needed = 33.6 + 8 = 41.6 < 60 → no expansion.
      // With offset: needed = 22 + 33.6 + 4 = 59.6 < 60 → borderline.
      // With a slightly larger offset, expansion should trigger.
      final tallSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 60.0),
        columns: SpanList(count: 26, defaultSize: 200.0),
      );

      // Without verticalOffset: text fits in 60px cell, no expansion
      final noOffset = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: 'Line1\nLine2\nLine3',
        layoutSolver: tallSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
      );
      expect(noOffset.endRow, 0,
          reason: '3 lines fit in 60px without offset');

      // With verticalOffset of 25px: text no longer fits
      // needed = 25 + ~50.4 + 4 = ~79.4 > 60 → expansion
      final withOffset = EditingBoundsCalculator.computeVertical(
        cell: const CellCoordinate(0, 0),
        text: 'Line1\nLine2\nLine3',
        layoutSolver: tallSolver,
        textStyle: textStyle,
        cellPadding: cellPadding,
        maxRow: 99,
        verticalOffset: 25.0,
      );
      expect(withOffset.endRow, greaterThan(0),
          reason: 'With vertical offset, text overflows and expands');
    });
  });
}
