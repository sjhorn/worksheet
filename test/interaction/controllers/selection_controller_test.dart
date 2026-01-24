import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/models/cell_coordinate.dart';
import 'package:worksheet2/src/core/models/cell_range.dart';
import 'package:worksheet2/src/interaction/controllers/selection_controller.dart';

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
  });
}
