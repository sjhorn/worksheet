import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/shortcuts/worksheet_intents.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    data.setCell(const CellCoordinate(0, 0), CellValue.text('A1'));
    controller = WorksheetController();
  });

  tearDown(() {
    controller.dispose();
    data.dispose();
  });

  Widget buildWorksheet({
    bool readOnly = false,
    OnEditCellCallback? onEditCell,
    Map<ShortcutActivator, Intent>? shortcuts,
    Map<Type, Action<Intent>>? actions,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Worksheet(
              data: data,
              controller: controller,
              rowCount: 100,
              columnCount: 26,
              readOnly: readOnly,
              onEditCell: onEditCell,
              shortcuts: shortcuts,
              actions: actions,
            ),
          ),
        ),
      ),
    );
  }

  /// Selects a cell via the controller so keyboard nav has a starting point.
  void selectCell(int row, int col) {
    controller.selectCell(CellCoordinate(row, col));
  }

  group('Arrow key navigation', () {
    testWidgets('arrow down moves focus down', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(2, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(3, 3));
    });

    testWidgets('arrow up moves focus up', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(5, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(4, 3));
    });

    testWidgets('arrow left moves focus left', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(2, 5);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(2, 4));
    });

    testWidgets('arrow right moves focus right', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(2, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(2, 4));
    });

    testWidgets('arrow keys clamp at grid boundaries', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(0, 0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(0, 0));
    });

    testWidgets('shift+arrow extends selection range', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(3, 3);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(
        controller.selectedRange,
        const CellRange(3, 3, 4, 4),
      );
    });
  });

  group('Tab and Enter navigation', () {
    testWidgets('tab moves focus right', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(1, 1);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(1, 2));
    });

    testWidgets('shift+tab moves focus left', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(1, 3);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(1, 2));
    });

    testWidgets('enter moves focus down', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(3, 2));
    });

    testWidgets('shift+enter moves focus up', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(5, 2);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(4, 2));
    });
  });

  group('Home/End navigation', () {
    testWidgets('home moves to start of row', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(3, 10);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(3, 0));
    });

    testWidgets('ctrl+home moves to A1', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(10, 10);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(0, 0));
    });
  });

  group('Page navigation', () {
    testWidgets('page down moves by 10 rows', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(5, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(15, 3));
    });

    testWidgets('page up moves by 10 rows', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(20, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(10, 3));
    });
  });

  group('Edit and Escape', () {
    testWidgets('F2 triggers onEditCell callback', (tester) async {
      CellCoordinate? editedCell;
      await tester.pumpWidget(buildWorksheet(
        onEditCell: (cell) => editedCell = cell,
      ));
      selectCell(3, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editedCell, const CellCoordinate(3, 2));
    });

    testWidgets('F2 does nothing without onEditCell callback', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(3, 2);
      await tester.pump();

      // Should not throw
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(3, 2));
    });

    testWidgets('escape collapses range to single cell', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      selectCell(3, 3);
      await tester.pump();

      // Extend selection
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.selectedRange, const CellRange(3, 3, 5, 3));

      // Escape collapses to focus cell
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final range = controller.selectedRange;
      expect(range, isNotNull);
      expect(range!.startRow, range.endRow);
      expect(range.startColumn, range.endColumn);
    });
  });

  group('Read-only mode', () {
    testWidgets('ignores keyboard events', (tester) async {
      await tester.pumpWidget(buildWorksheet(readOnly: true));
      selectCell(3, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Focus should not have moved
      expect(controller.focusCell, const CellCoordinate(3, 3));
    });
  });

  group('Consumer customization', () {
    testWidgets('custom shortcuts override defaults', (tester) async {
      // Override Enter to do nothing instead of moving down
      await tester.pumpWidget(buildWorksheet(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.enter):
              const DoNothingAndStopPropagationIntent(),
        },
      ));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Should NOT have moved because we overrode Enter
      expect(controller.focusCell, const CellCoordinate(2, 2));

      // Other shortcuts should still work
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(3, 2));
    });

    testWidgets('custom actions override defaults', (tester) async {
      // Override ClearCellsAction with a custom action that tracks invocations
      var customActionInvoked = false;
      await tester.pumpWidget(buildWorksheet(
        actions: {
          ClearCellsIntent: CallbackAction<ClearCellsIntent>(
            onInvoke: (_) {
              customActionInvoked = true;
              return null;
            },
          ),
        },
      ));
      data.setCell(const CellCoordinate(5, 5), CellValue.text('keep me'));
      selectCell(5, 5);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      // Our custom action was invoked instead of the default
      expect(customActionInvoked, true);
      // Data was NOT cleared because our custom action doesn't do that
      expect(data.getCell(const CellCoordinate(5, 5))?.displayValue, 'keep me');
    });

    testWidgets('shortcuts and actions params are optional', (tester) async {
      // Without any customization, default behavior works
      await tester.pumpWidget(buildWorksheet());
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.focusCell, const CellCoordinate(3, 2));
    });
  });
}
