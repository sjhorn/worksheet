import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/merged_cell_registry.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';

void main() {
  group('SelectionMode', () {
    test('has all expected values', () {
      expect(SelectionMode.values, containsAll([
        SelectionMode.none,
        SelectionMode.single,
        SelectionMode.range,
      ]));
    });
  });

  group('SelectionController', () {
    late SelectionController controller;

    setUp(() {
      controller = SelectionController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('initial state', () {
      test('starts with no selection', () {
        expect(controller.anchor, isNull);
        expect(controller.focus, isNull);
        expect(controller.mode, SelectionMode.none);
        expect(controller.hasSelection, isFalse);
      });

      test('selectedRange is null when no selection', () {
        expect(controller.selectedRange, isNull);
      });
    });

    group('selectCell', () {
      test('selects single cell', () {
        final cell = CellCoordinate(5, 10);
        controller.selectCell(cell);

        expect(controller.anchor, cell);
        expect(controller.focus, cell);
        expect(controller.mode, SelectionMode.single);
        expect(controller.hasSelection, isTrue);
      });

      test('selectedRange equals single cell', () {
        final cell = CellCoordinate(5, 10);
        controller.selectCell(cell);

        expect(controller.selectedRange, CellRange(5, 10, 5, 10));
      });

      test('notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.selectCell(CellCoordinate(0, 0));

        expect(notified, isTrue);
      });

      test('replaces previous selection', () {
        controller.selectCell(CellCoordinate(0, 0));
        controller.selectCell(CellCoordinate(5, 5));

        expect(controller.anchor, CellCoordinate(5, 5));
        expect(controller.focus, CellCoordinate(5, 5));
      });
    });

    group('extendSelection', () {
      test('extends from anchor to focus', () {
        controller.selectCell(CellCoordinate(2, 2));
        controller.extendSelection(CellCoordinate(5, 8));

        expect(controller.anchor, CellCoordinate(2, 2));
        expect(controller.focus, CellCoordinate(5, 8));
        expect(controller.mode, SelectionMode.range);
      });

      test('selectedRange covers anchor to focus', () {
        controller.selectCell(CellCoordinate(2, 2));
        controller.extendSelection(CellCoordinate(5, 8));

        expect(controller.selectedRange, CellRange(2, 2, 5, 8));
      });

      test('handles focus before anchor', () {
        controller.selectCell(CellCoordinate(5, 8));
        controller.extendSelection(CellCoordinate(2, 2));

        // Range should normalize start/end
        final range = controller.selectedRange!;
        expect(range.startRow, 2);
        expect(range.startColumn, 2);
        expect(range.endRow, 5);
        expect(range.endColumn, 8);
      });

      test('notifies listeners', () {
        controller.selectCell(CellCoordinate(0, 0));

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.extendSelection(CellCoordinate(5, 5));

        expect(notifyCount, 1);
      });

      test('does nothing if no anchor', () {
        controller.extendSelection(CellCoordinate(5, 5));

        expect(controller.hasSelection, isFalse);
      });
    });

    group('clear', () {
      test('clears selection', () {
        controller.selectCell(CellCoordinate(5, 10));
        controller.clear();

        expect(controller.anchor, isNull);
        expect(controller.focus, isNull);
        expect(controller.mode, SelectionMode.none);
        expect(controller.hasSelection, isFalse);
      });

      test('notifies listeners', () {
        controller.selectCell(CellCoordinate(0, 0));

        var notified = false;
        controller.addListener(() => notified = true);

        controller.clear();

        expect(notified, isTrue);
      });

      test('does not notify if already empty', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clear();

        expect(notifyCount, 0);
      });
    });

    group('selectRange', () {
      test('selects range directly', () {
        final range = CellRange(2, 3, 8, 10);
        controller.selectRange(range);

        expect(controller.anchor, CellCoordinate(2, 3));
        expect(controller.focus, CellCoordinate(8, 10));
        expect(controller.mode, SelectionMode.range);
      });

      test('selectedRange equals input range', () {
        final range = CellRange(2, 3, 8, 10);
        controller.selectRange(range);

        expect(controller.selectedRange, range);
      });
    });

    group('selectRow', () {
      test('selects entire row', () {
        controller.selectRow(5, columnCount: 100);

        expect(controller.anchor, CellCoordinate(5, 0));
        expect(controller.focus, CellCoordinate(5, 99));
        expect(controller.mode, SelectionMode.range);
      });
    });

    group('selectColumn', () {
      test('selects entire column', () {
        controller.selectColumn(10, rowCount: 1000);

        expect(controller.anchor, CellCoordinate(0, 10));
        expect(controller.focus, CellCoordinate(999, 10));
        expect(controller.mode, SelectionMode.range);
      });
    });

    group('moveFocus', () {
      test('moves focus by delta', () {
        controller.selectCell(CellCoordinate(5, 5));
        controller.moveFocus(rowDelta: 1, columnDelta: 2, extend: false);

        expect(controller.anchor, CellCoordinate(6, 7));
        expect(controller.focus, CellCoordinate(6, 7));
        expect(controller.mode, SelectionMode.single);
      });

      test('extends selection when extend is true', () {
        controller.selectCell(CellCoordinate(5, 5));
        controller.moveFocus(rowDelta: 2, columnDelta: 3, extend: true);

        expect(controller.anchor, CellCoordinate(5, 5));
        expect(controller.focus, CellCoordinate(7, 8));
        expect(controller.mode, SelectionMode.range);
      });

      test('clamps to bounds', () {
        controller.selectCell(CellCoordinate(0, 0));
        controller.moveFocus(
          rowDelta: -5,
          columnDelta: -5,
          extend: false,
          maxRow: 100,
          maxColumn: 50,
        );

        expect(controller.focus, CellCoordinate(0, 0));
      });

      test('clamps to max bounds', () {
        controller.selectCell(CellCoordinate(99, 49));
        controller.moveFocus(
          rowDelta: 5,
          columnDelta: 5,
          extend: false,
          maxRow: 100,
          maxColumn: 50,
        );

        expect(controller.focus, CellCoordinate(99, 49));
      });

      test('does nothing if no selection', () {
        controller.moveFocus(rowDelta: 1, columnDelta: 1, extend: false);

        expect(controller.hasSelection, isFalse);
      });
    });

    group('containsCell', () {
      test('returns true for cell in selection', () {
        controller.selectCell(CellCoordinate(5, 5));
        controller.extendSelection(CellCoordinate(10, 10));

        expect(controller.containsCell(CellCoordinate(7, 7)), isTrue);
      });

      test('returns false for cell outside selection', () {
        controller.selectCell(CellCoordinate(5, 5));
        controller.extendSelection(CellCoordinate(10, 10));

        expect(controller.containsCell(CellCoordinate(2, 2)), isFalse);
      });

      test('returns false when no selection', () {
        expect(controller.containsCell(CellCoordinate(0, 0)), isFalse);
      });
    });

    group('dispose', () {
      test('disposes cleanly', () {
        // Create a separate controller for this test
        final testController = SelectionController();
        testController.selectCell(CellCoordinate(0, 0));
        testController.dispose();
        // Should not throw
      });
    });

    group('merged cells', () {
      late MergedCellRegistry mergedCells;

      setUp(() {
        mergedCells = MergedCellRegistry();
        controller.mergedCells = mergedCells;
      });

      test('selectCell resolves to merge anchor', () {
        mergedCells.merge(CellRange(1, 1, 2, 2));
        controller.selectCell(const CellCoordinate(2, 2));
        expect(controller.focus, const CellCoordinate(1, 1));
        expect(controller.anchor, const CellCoordinate(1, 1));
      });

      test('selectCell works normally for unmerged cell', () {
        mergedCells.merge(CellRange(1, 1, 2, 2));
        controller.selectCell(const CellCoordinate(0, 0));
        expect(controller.focus, const CellCoordinate(0, 0));
      });

      test('selectedRange expands to include full merge regions', () {
        mergedCells.merge(CellRange(1, 1, 3, 3));
        // Select range that partially overlaps the merge
        controller.selectCell(const CellCoordinate(0, 0));
        controller.extendSelection(const CellCoordinate(2, 2));
        final range = controller.selectedRange!;
        // Should expand to include full merge (0,0)-(3,3)
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 3);
        expect(range.endColumn, 3);
      });

      test('selectedRange does not expand without merge overlap', () {
        mergedCells.merge(CellRange(5, 5, 6, 6));
        controller.selectCell(const CellCoordinate(0, 0));
        controller.extendSelection(const CellCoordinate(2, 2));
        final range = controller.selectedRange!;
        expect(range.endRow, 2);
        expect(range.endColumn, 2);
      });

      test('moveFocus down skips over merge region', () {
        mergedCells.merge(CellRange(1, 0, 2, 0));
        controller.selectCell(const CellCoordinate(1, 0));
        controller.moveFocus(rowDelta: 1, columnDelta: 0, extend: false);
        // Should skip to row 3 (past the merge end at row 2)
        expect(controller.focus, const CellCoordinate(3, 0));
      });

      test('moveFocus up skips over merge region', () {
        mergedCells.merge(CellRange(1, 0, 2, 0));
        controller.selectCell(const CellCoordinate(1, 0));
        controller.moveFocus(rowDelta: -1, columnDelta: 0, extend: false);
        // Should go to row 0 (before the merge start at row 1)
        expect(controller.focus, const CellCoordinate(0, 0));
      });

      test('moveFocus right skips over merge region', () {
        mergedCells.merge(CellRange(0, 1, 0, 3));
        controller.selectCell(const CellCoordinate(0, 1));
        controller.moveFocus(rowDelta: 0, columnDelta: 1, extend: false);
        // Should skip to col 4 (past the merge end at col 3)
        expect(controller.focus, const CellCoordinate(0, 4));
      });

      test('moveFocus left skips over merge region', () {
        mergedCells.merge(CellRange(0, 1, 0, 3));
        controller.selectCell(const CellCoordinate(0, 1));
        controller.moveFocus(rowDelta: 0, columnDelta: -1, extend: false);
        // Should go to col 0 (before the merge start at col 1)
        expect(controller.focus, const CellCoordinate(0, 0));
      });

      test('moveFocus into a merge resolves to anchor', () {
        mergedCells.merge(CellRange(2, 2, 3, 3));
        controller.selectCell(const CellCoordinate(1, 2));
        controller.moveFocus(rowDelta: 1, columnDelta: 0, extend: false);
        // Should resolve to merge anchor (2, 2)
        expect(controller.focus, const CellCoordinate(2, 2));
      });

      test('moveFocus extend does not skip merges', () {
        mergedCells.merge(CellRange(1, 0, 2, 0));
        controller.selectCell(const CellCoordinate(0, 0));
        controller.moveFocus(rowDelta: 1, columnDelta: 0, extend: true);
        // Extend should not apply merge-skipping logic
        expect(controller.focus, const CellCoordinate(1, 0));
      });

      test('moveFocus clamps to bounds with merge', () {
        mergedCells.merge(CellRange(0, 0, 1, 1));
        controller.selectCell(const CellCoordinate(0, 0));
        controller.moveFocus(
          rowDelta: -1, columnDelta: 0, extend: false,
          maxRow: 10, maxColumn: 10,
        );
        expect(controller.focus, const CellCoordinate(0, 0));
      });

      test('selectedRange expansion cascades through chained merges', () {
        // Two adjacent merges that form a chain
        mergedCells.merge(CellRange(0, 0, 1, 1));
        mergedCells.merge(CellRange(2, 2, 3, 3));
        // Select range that overlaps first merge, which expands,
        // then overlaps second merge
        controller.selectCell(const CellCoordinate(0, 0));
        controller.extendSelection(const CellCoordinate(2, 2));
        final range = controller.selectedRange!;
        // Should include both merges
        expect(range.startRow, 0);
        expect(range.endRow, 3);
        expect(range.endColumn, 3);
      });
    });
  });
}
