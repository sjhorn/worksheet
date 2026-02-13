import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
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

  group('Worksheet keyboard navigation', () {
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

    testWidgets('readOnly mode ignores keyboard events', (tester) async {
      await tester.pumpWidget(buildWorksheet(readOnly: true));
      selectCell(3, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Focus should not have moved
      expect(controller.focusCell, const CellCoordinate(3, 3));
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

  group('Escape cancels active drag', () {
    // Layout: WorksheetThemeData defaults, zoom=1.0
    // Row header width: 50, Column header height: 24
    // Default cell: 100 wide, 24 tall
    //
    // Cell (r,c): x=[50+c*100, 50+(c+1)*100], y=[24+r*24, 24+(r+1)*24]

    testWidgets('Escape cancels range selection drag', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pump();

      // Select cell (1,1) first
      selectCell(1, 1);
      await tester.pump();

      // Start a mouse drag from cell (1,1) — this puts the gesture
      // handler into selection-drag mode with selectionBeforeDrag=(1,1).
      // Cell (1,1) center: x=200, y=60
      final gesture = await tester.startGesture(
        const Offset(200.0, 60.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move pointer (may or may not extend selection depending on event
      // routing, but the gesture handler is in drag mode either way).
      await gesture.moveTo(const Offset(400.0, 108.0));
      await tester.pump();

      // Press Escape while dragging — should restore to original (1,1)
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final range = controller.selectedRange!;
      expect(range.startRow, equals(1));
      expect(range.startColumn, equals(1));
      expect(range.endRow, equals(1));
      expect(range.endColumn, equals(1));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Escape cancels move drag and restores selection',
        (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pump();

      // Select range (1,1) to (2,2) programmatically
      controller.selectionController.selectRange(
        const CellRange(1, 1, 2, 2),
      );
      await tester.pump();

      // Start drag on selection border to move.
      // Selection (1,1)-(2,2): screen TL=(150,48), BR=(350,96).
      // Border tolerance=4 → outer=(146,44,354,100), inner=(154,52,346,92).
      // Position (200, 48): in outer (yes), in inner (48<52 → no) → border.
      final gesture = await tester.startGesture(
        const Offset(200.0, 48.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move pointer
      await gesture.moveTo(const Offset(200.0, 200.0));
      await tester.pump();

      // Press Escape to cancel — should restore to original (1,1)-(2,2)
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final range = controller.selectedRange!;
      expect(range.startRow, equals(1));
      expect(range.startColumn, equals(1));
      expect(range.endRow, equals(2));
      expect(range.endColumn, equals(2));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Escape during column resize cancels without crash',
        (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pump();

      // Column 0 right edge resize handle: x ≈ 148 (near 50+100=150),
      // y=12 (in header area, y < 24)
      final gesture = await tester.startGesture(
        const Offset(148.0, 12.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Drag right to widen column
      await gesture.moveTo(const Offset(200.0, 12.0));
      await tester.pump();

      // Press Escape to cancel resize
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Release pointer — should not crash or re-apply resize
      await gesture.up();
      await tester.pumpAndSettle();

      // Widget should still be functional — select a cell
      selectCell(0, 0);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(0, 0));
    });

    testWidgets('mouse up after Escape does not re-complete drag',
        (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pump();

      // Select cell (1,1) to have a starting point
      selectCell(1, 1);
      await tester.pump();

      // Start mouse drag — puts handler in drag mode
      final gesture = await tester.startGesture(
        const Offset(200.0, 60.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move pointer
      await gesture.moveTo(const Offset(400.0, 108.0));
      await tester.pump();

      // Press Escape to cancel drag
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Selection should be restored to (1,1)
      expect(controller.selectedRange!.endRow, equals(1));

      // Release mouse — should not re-extend or re-apply the drag
      await gesture.up();
      await tester.pumpAndSettle();

      // Selection should still be single cell (1,1)
      final range = controller.selectedRange!;
      expect(range.endRow, equals(1));
      expect(range.endColumn, equals(1));
    });
  });
}
