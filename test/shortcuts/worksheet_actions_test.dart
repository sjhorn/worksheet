import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_serializer.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/shortcuts/worksheet_action_context.dart';
import 'package:worksheet/src/shortcuts/worksheet_actions.dart';
import 'package:worksheet/src/shortcuts/worksheet_intents.dart';

class MockWorksheetActionContext implements WorksheetActionContext {
  @override
  final SelectionController selectionController;
  @override
  final int maxRow;
  @override
  final int maxColumn;
  @override
  final WorksheetData worksheetData;
  @override
  final ClipboardHandler clipboardHandler;
  @override
  final bool readOnly;
  @override
  final void Function(CellCoordinate)? onEditCell;
  @override
  final EditController? editController;

  int ensureSelectionVisibleCount = 0;
  int invalidateAndRebuildCount = 0;

  MockWorksheetActionContext({
    required this.selectionController,
    required this.maxRow,
    required this.maxColumn,
    required this.worksheetData,
    required this.clipboardHandler,
    this.readOnly = false,
    this.onEditCell,
    this.editController,
  });

  @override
  void ensureSelectionVisible() {
    ensureSelectionVisibleCount++;
  }

  @override
  void invalidateAndRebuild() {
    invalidateAndRebuildCount++;
  }
}

void main() {
  late SparseWorksheetData data;
  late SelectionController selectionController;
  late ClipboardHandler clipboardHandler;
  late MockWorksheetActionContext ctx;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    selectionController = SelectionController();
    clipboardHandler = ClipboardHandler(
      data: data,
      selectionController: selectionController,
      serializer: const TsvClipboardSerializer(),
    );
    ctx = MockWorksheetActionContext(
      selectionController: selectionController,
      maxRow: 100,
      maxColumn: 26,
      worksheetData: data,
      clipboardHandler: clipboardHandler,
    );
    selectionController.selectCell(const CellCoordinate(5, 5));
  });

  tearDown(() {
    selectionController.dispose();
    data.dispose();
  });

  group('MoveSelectionAction', () {
    test('moves focus by delta', () {
      final action = MoveSelectionAction(ctx);
      action.invoke(const MoveSelectionIntent(rowDelta: 1));
      expect(selectionController.focus, const CellCoordinate(6, 5));
      expect(ctx.ensureSelectionVisibleCount, 1);
    });

    test('moves focus left', () {
      final action = MoveSelectionAction(ctx);
      action.invoke(const MoveSelectionIntent(columnDelta: -1));
      expect(selectionController.focus, const CellCoordinate(5, 4));
    });

    test('extends selection when extend is true', () {
      final action = MoveSelectionAction(ctx);
      action.invoke(
        const MoveSelectionIntent(rowDelta: 2, extend: true),
      );
      expect(selectionController.mode, SelectionMode.range);
      expect(selectionController.anchor, const CellCoordinate(5, 5));
      expect(selectionController.focus, const CellCoordinate(7, 5));
    });

    test('clamps at boundaries', () {
      selectionController.selectCell(const CellCoordinate(0, 0));
      final action = MoveSelectionAction(ctx);
      action.invoke(const MoveSelectionIntent(rowDelta: -1));
      expect(selectionController.focus, const CellCoordinate(0, 0));
    });

    test('page down moves by 10', () {
      final action = MoveSelectionAction(ctx);
      action.invoke(const MoveSelectionIntent(rowDelta: 10));
      expect(selectionController.focus, const CellCoordinate(15, 5));
    });
  });

  group('GoToCellAction', () {
    test('selects target cell', () {
      final action = GoToCellAction(ctx);
      action.invoke(const GoToCellIntent(CellCoordinate(0, 0)));
      expect(selectionController.focus, const CellCoordinate(0, 0));
      expect(ctx.ensureSelectionVisibleCount, 1);
    });
  });

  group('GoToLastCellAction', () {
    test('navigates to last cell', () {
      final action = GoToLastCellAction(ctx);
      action.invoke(const GoToLastCellIntent());
      expect(selectionController.focus, const CellCoordinate(99, 25));
      expect(ctx.ensureSelectionVisibleCount, 1);
    });
  });

  group('GoToRowBoundaryAction', () {
    test('home moves to start of row', () {
      final action = GoToRowBoundaryAction(ctx);
      action.invoke(const GoToRowBoundaryIntent(end: false));
      expect(selectionController.focus, const CellCoordinate(5, 0));
      expect(ctx.ensureSelectionVisibleCount, 1);
    });

    test('end moves to end of row', () {
      final action = GoToRowBoundaryAction(ctx);
      action.invoke(const GoToRowBoundaryIntent(end: true));
      expect(selectionController.focus, const CellCoordinate(5, 25));
    });

    test('shift+home extends selection to start of row', () {
      final action = GoToRowBoundaryAction(ctx);
      action.invoke(
        const GoToRowBoundaryIntent(end: false, extend: true),
      );
      expect(selectionController.mode, SelectionMode.range);
      expect(selectionController.anchor, const CellCoordinate(5, 5));
      expect(selectionController.focus, const CellCoordinate(5, 0));
    });

    test('shift+end extends selection to end of row', () {
      final action = GoToRowBoundaryAction(ctx);
      action.invoke(
        const GoToRowBoundaryIntent(end: true, extend: true),
      );
      expect(selectionController.mode, SelectionMode.range);
      expect(selectionController.anchor, const CellCoordinate(5, 5));
      expect(selectionController.focus, const CellCoordinate(5, 25));
    });

    test('does nothing with no focus', () {
      selectionController.clear();
      final action = GoToRowBoundaryAction(ctx);
      action.invoke(const GoToRowBoundaryIntent(end: false));
      expect(selectionController.focus, isNull);
    });
  });

  group('SelectAllCellsAction', () {
    test('selects entire grid', () {
      final action = SelectAllCellsAction(ctx);
      action.invoke(const SelectAllCellsIntent());
      expect(selectionController.mode, SelectionMode.range);
      final range = selectionController.selectedRange!;
      expect(range.startRow, 0);
      expect(range.startColumn, 0);
      expect(range.endRow, 99);
      expect(range.endColumn, 25);
    });
  });

  group('CancelSelectionAction', () {
    test('collapses range to focus cell', () {
      selectionController.extendSelection(const CellCoordinate(8, 8));
      expect(selectionController.mode, SelectionMode.range);
      final focusBefore = selectionController.focus;

      final action = CancelSelectionAction(ctx);
      action.invoke(const CancelSelectionIntent());

      expect(selectionController.mode, SelectionMode.single);
      expect(selectionController.focus, focusBefore);
    });
  });

  group('EditCellAction', () {
    test('calls onEditCell with focus cell', () {
      CellCoordinate? edited;
      final editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        onEditCell: (cell) => edited = cell,
      );
      final action = EditCellAction(editCtx);
      action.invoke(const EditCellIntent());
      expect(edited, const CellCoordinate(5, 5));
    });

    test('does nothing without onEditCell', () {
      final action = EditCellAction(ctx);
      // Should not throw
      action.invoke(const EditCellIntent());
    });
  });

  group('ClearCellsAction', () {
    test('clears selected range', () {
      data.setCell(const CellCoordinate(5, 5), CellValue.text('hello'));
      selectionController.selectCell(const CellCoordinate(5, 5));

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent());

      expect(data.getCell(const CellCoordinate(5, 5)), isNull);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = ClearCellsAction(roCtx);
      expect(action.isEnabled(const ClearCellsIntent()), false);
    });

    test('is enabled when not readOnly', () {
      final action = ClearCellsAction(ctx);
      expect(action.isEnabled(const ClearCellsIntent()), true);
    });

    test('does nothing without selection', () {
      selectionController.clear();
      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent());
      expect(ctx.invalidateAndRebuildCount, 0);
    });
  });

  group('FillDownAction', () {
    test('fills down from first row of selection', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('source'));
      selectionController.selectRange(const CellRange(0, 0, 2, 0));

      final action = FillDownAction(ctx);
      action.invoke(const FillDownIntent());

      expect(data.getCell(const CellCoordinate(1, 0))?.displayValue, 'source');
      expect(data.getCell(const CellCoordinate(2, 0))?.displayValue, 'source');
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('requires at least 2 rows', () {
      selectionController.selectCell(const CellCoordinate(0, 0));
      final action = FillDownAction(ctx);
      action.invoke(const FillDownIntent());
      expect(ctx.invalidateAndRebuildCount, 0);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = FillDownAction(roCtx);
      expect(action.isEnabled(const FillDownIntent()), false);
    });
  });

  group('FillRightAction', () {
    test('fills right from first column of selection', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('source'));
      selectionController.selectRange(const CellRange(0, 0, 0, 2));

      final action = FillRightAction(ctx);
      action.invoke(const FillRightIntent());

      expect(data.getCell(const CellCoordinate(0, 1))?.displayValue, 'source');
      expect(data.getCell(const CellCoordinate(0, 2))?.displayValue, 'source');
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('requires at least 2 columns', () {
      selectionController.selectCell(const CellCoordinate(0, 0));
      final action = FillRightAction(ctx);
      action.invoke(const FillRightIntent());
      expect(ctx.invalidateAndRebuildCount, 0);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = FillRightAction(roCtx);
      expect(action.isEnabled(const FillRightIntent()), false);
    });
  });

  group('CutCellsAction', () {
    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = CutCellsAction(roCtx);
      expect(action.isEnabled(const CutCellsIntent()), false);
    });

    test('is enabled when not readOnly', () {
      final action = CutCellsAction(ctx);
      expect(action.isEnabled(const CutCellsIntent()), true);
    });
  });

  group('PasteCellsAction', () {
    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = PasteCellsAction(roCtx);
      expect(action.isEnabled(const PasteCellsIntent()), false);
    });

    test('is enabled when not readOnly', () {
      final action = PasteCellsAction(ctx);
      expect(action.isEnabled(const PasteCellsIntent()), true);
    });
  });
}
