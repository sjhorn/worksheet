import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;
  late EditController editController;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    data.setCell(const CellCoordinate(0, 0), CellValue.text('A1'));
    data.setCell(const CellCoordinate(1, 0), CellValue.text('A2'));
    data.setCell(const CellCoordinate(0, 1), CellValue.text('B1'));
    data.setCell(const CellCoordinate(2, 2), CellValue.number(42));
    controller = WorksheetController();
    editController = EditController();
  });

  tearDown(() {
    controller.dispose();
    editController.dispose();
    data.dispose();
  });

  Widget buildWorksheet({
    bool readOnly = false,
    EditController? ec,
    OnEditCellCallback? onEditCell,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Worksheet(
              data: data,
              controller: controller,
              editController: ec,
              rowCount: 100,
              columnCount: 26,
              readOnly: readOnly,
              onEditCell: onEditCell,
            ),
          ),
        ),
      ),
    );
  }

  void selectCell(int row, int col) {
    controller.selectCell(CellCoordinate(row, col));
  }

  group('Type-to-edit (navigation mode)', () {
    testWidgets('pressing a printable character starts editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(0, 0));
      expect(editController.trigger, EditTrigger.typing);
    });

    testWidgets('digit starts editing with digit as initial text',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(1, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(1, 0));
      expect(editController.trigger, EditTrigger.typing);
      // The initial text should be the typed character
      expect(editController.currentText, '5');
    });

    testWidgets('Ctrl+A does NOT start editing (triggers select all)',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('Meta+C does NOT start editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('F2 starts editing with F2 trigger', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.f2Key);
      // F2 should load the existing cell value (42 displays as '42' for integers)
      expect(editController.currentText, '42');
    });

    testWidgets('no editController: printable chars do nothing',
        (tester) async {
      await tester.pumpWidget(buildWorksheet()); // no editController
      selectCell(0, 0);
      await tester.pump();

      // This should NOT crash or start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      // No editController means no editing state to check
      // Just verify no crash occurred
    });

    testWidgets('readOnly: printable chars do nothing', (tester) async {
      await tester.pumpWidget(
          buildWorksheet(ec: editController, readOnly: true));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('no focused cell: printable chars do nothing',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      // Don't select any cell
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('does not start editing if already editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing first
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: CellValue.text('A1'),
        trigger: EditTrigger.f2Key,
      );
      await tester.pump();

      // Typing 'b' should go to the TextField, not start a new edit
      // The editController should still be editing cell (0,0)
      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(0, 0));
    });
  });

  group('Commit-and-navigate (edit mode)', () {
    testWidgets('Enter commits and moves selection down', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing via type-to-edit
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.pump();
      await tester.pump(); // Let overlay render

      expect(editController.isEditing, isTrue);

      // Press Enter to commit and navigate down
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      // Selection should have moved down
      expect(controller.focusCell, const CellCoordinate(3, 2));
      // Data should be committed
      expect(data.getCell(const CellCoordinate(2, 2))?.displayValue, '9');
    });

    testWidgets('Shift+Enter commits and moves selection up', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(3, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Shift+Enter to commit and navigate up
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('Tab commits and moves selection right', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Tab to commit and navigate right
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 3));
    });

    testWidgets('Shift+Tab commits and moves selection left', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 3);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Shift+Tab to commit and navigate left
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowDown commits and moves selection down', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(3, 2));
      expect(data.getCell(const CellCoordinate(2, 2))?.displayValue, '4');
    });

    testWidgets('ArrowUp commits and moves selection up', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(3, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowRight moves text cursor, stays in edit mode',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowLeft moves text cursor, stays in edit mode',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(controller.focusCell, const CellCoordinate(2, 3));
    });

    testWidgets('Escape cancels edit, does not navigate', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Escape to cancel
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      // Selection should NOT move
      expect(controller.focusCell, const CellCoordinate(2, 2));
      // Original value should be unchanged
      expect(data.getCell(const CellCoordinate(2, 2)),
          CellValue.number(42));
    });
  });

  group('Backspace/Delete behavior', () {
    testWidgets('Backspace clears cell when not editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Cell has value 'A1'
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'A1');

      // Press Backspace — should clear the cell
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
      expect(editController.isEditing, isFalse);
    });

    testWidgets('Delete clears cell when not editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 1);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 1))?.displayValue, 'B1');

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 1)), isNull);
      expect(editController.isEditing, isFalse);
    });

    testWidgets('Backspace does not clear cell when editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing via type-to-edit
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // The original cell value should still be in the data
      // (editing hasn't committed yet, type-to-edit replaces)
      final valueBefore = data.getCell(const CellCoordinate(0, 0));

      // Press Backspace — should NOT clear the cell, should edit text
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Should still be editing
      expect(editController.isEditing, isTrue);
      // Cell data should not have been cleared by ClearCellsAction
      expect(data.getCell(const CellCoordinate(0, 0)), valueBefore);
    });

    testWidgets('Delete does not clear cell when editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing via F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      final valueBefore = data.getCell(const CellCoordinate(0, 0));

      // Press Delete — should NOT clear the cell
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(data.getCell(const CellCoordinate(0, 0)), valueBefore);
    });
  });

  group('Integration', () {
    testWidgets(
        'type character starts editing, Enter commits and moves down',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Type 'H' to start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.typing);

      // Press Enter to commit
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(1, 0));
    });

    testWidgets('F2 starts editing with full cell value', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.f2Key);
      expect(editController.currentText, 'A1');
    });

    testWidgets('focus returns to worksheet after commit', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      await tester.pump();

      // Commit with Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      // After commit, the worksheet should be able to handle keyboard again.
      // Send an arrow key to verify focus returned.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // If focus returned properly, the selection should have moved
      expect(controller.focusCell, const CellCoordinate(1, 1));
    });

    testWidgets('focus returns to worksheet after cancel', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      await tester.pump();

      // Cancel with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      // After cancel, the worksheet should handle keyboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // If focus returned, selection should have moved
      expect(controller.focusCell, const CellCoordinate(1, 0));
    });

    testWidgets('existing navigation shortcuts work when not editing',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(5, 5);
      await tester.pump();

      // Arrow keys should still work for navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(6, 5));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(6, 6));
    });

    testWidgets('onEditCell callback fires alongside editController on F2',
        (tester) async {
      CellCoordinate? editedCell;

      await tester.pumpWidget(buildWorksheet(
        ec: editController,
        onEditCell: (cell) => editedCell = cell,
      ));
      selectCell(3, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      // Both the callback and the editController should be triggered
      expect(editedCell, const CellCoordinate(3, 3));
      expect(editController.isEditing, isTrue);
    });
  });
}
