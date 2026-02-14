import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_serializer.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/rich_text_editing_controller.dart';
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

    test('clears only values when clearStyle and clearFormat are false', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      data.setFormat(coord, CellFormat.currency);
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: true,
        clearStyle: false,
        clearFormat: false,
      ));

      expect(data.getCell(coord), isNull);
      expect(data.getStyle(coord), isNotNull);
      expect(data.getStyle(coord)!.backgroundColor, const Color(0xFF00FF00));
      expect(data.getFormat(coord), CellFormat.currency);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('clears only style and format when clearValue is false', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      data.setFormat(coord, CellFormat.currency);
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: true,
      ));

      expect(data.getCell(coord)?.displayValue, 'hello');
      expect(data.getStyle(coord), isNull);
      expect(data.getFormat(coord), isNull);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('clears everything by default (backward compatible)', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      data.setFormat(coord, CellFormat.currency);
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent());

      expect(data.getCell(coord), isNull);
      expect(data.getStyle(coord), isNull);
      expect(data.getFormat(coord), isNull);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('no-op when all flags are false', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: false,
        clearFormat: false,
      ));

      expect(data.getCell(coord)?.displayValue, 'hello');
      expect(data.getStyle(coord)!.backgroundColor, const Color(0xFF00FF00));
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('clearing format on cell with no format is safe', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: false,
        clearFormat: true,
      ));

      expect(data.getCell(coord)?.displayValue, 'hello');
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('clearing style on cell with no style is safe', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      selectionController.selectCell(coord);

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: false,
      ));

      expect(data.getCell(coord)?.displayValue, 'hello');
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('selective clear works over multi-cell range', () {
      const coord1 = CellCoordinate(0, 0);
      const coord2 = CellCoordinate(1, 1);
      data.setCell(coord1, CellValue.text('a'));
      data.setStyle(coord1, const CellStyle(
        backgroundColor: Color(0xFFFF0000),
      ));
      data.setCell(coord2, CellValue.text('b'));
      data.setStyle(coord2, const CellStyle(
        backgroundColor: Color(0xFF00FF00),
      ));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: true,
      ));

      expect(data.getCell(coord1)?.displayValue, 'a');
      expect(data.getCell(coord2)?.displayValue, 'b');
      expect(data.getStyle(coord1), isNull);
      expect(data.getStyle(coord2), isNull);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('isEnabled respects readOnly for flagged intent', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = ClearCellsAction(roCtx);
      expect(
        action.isEnabled(const ClearCellsIntent(
          clearValue: false,
          clearStyle: true,
          clearFormat: true,
        )),
        false,
      );
    });

    test('clear-all unmerges cells', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('hello'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent());

      expect(data.mergedCells.isEmpty, isTrue);
      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
    });

    test('clear formats-only unmerges but preserves values', () {
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.text('hello'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: false,
        clearFormat: true,
      ));

      expect(data.mergedCells.isEmpty, isTrue);
      expect(data.getCell(coord)?.displayValue, 'hello');
    });

    test('clear values-only does NOT unmerge', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('hello'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = ClearCellsAction(ctx);
      action.invoke(const ClearCellsIntent(
        clearValue: true,
        clearStyle: false,
        clearFormat: false,
      ));

      expect(data.mergedCells.isEmpty, isFalse);
      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
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

    test('preserves merge from first row', () {
      // First row has a 1×2 merge at (0,0)-(0,1)
      data.setCell(const CellCoordinate(0, 0), CellValue.text('merged'));
      data.mergeCells(const CellRange(0, 0, 0, 1));

      selectionController.selectRange(const CellRange(0, 0, 2, 1));
      final action = FillDownAction(ctx);
      action.invoke(const FillDownIntent());

      // Merge replicated to rows 1 and 2
      expect(
        data.mergedCells.getRegion(const CellCoordinate(1, 0))?.range,
        const CellRange(1, 0, 1, 1),
      );
      expect(
        data.mergedCells.getRegion(const CellCoordinate(2, 0))?.range,
        const CellRange(2, 0, 2, 1),
      );
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

    test('preserves merge from first column', () {
      // First column has a 2×1 merge at (0,0)-(1,0)
      data.setCell(const CellCoordinate(0, 0), CellValue.text('merged'));
      data.mergeCells(const CellRange(0, 0, 1, 0));

      selectionController.selectRange(const CellRange(0, 0, 1, 2));
      final action = FillRightAction(ctx);
      action.invoke(const FillRightIntent());

      // Merge replicated to cols 1 and 2
      expect(
        data.mergedCells.getRegion(const CellCoordinate(0, 1))?.range,
        const CellRange(0, 1, 1, 1),
      );
      expect(
        data.mergedCells.getRegion(const CellCoordinate(0, 2))?.range,
        const CellRange(0, 2, 1, 2),
      );
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

  group('MergeCellsAction', () {
    test('merges selected range', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('anchor'));
      data.setCell(const CellCoordinate(0, 1), CellValue.text('child'));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = MergeCellsAction(ctx);
      action.invoke(const MergeCellsIntent());

      expect(data.mergedCells.isMerged(const CellCoordinate(0, 0)), isTrue);
      expect(data.mergedCells.isAnchor(const CellCoordinate(0, 0)), isTrue);
      // Child values should be cleared
      expect(data.getCell(const CellCoordinate(0, 1)), isNull);
      // Anchor value preserved
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'anchor');
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('is disabled for single cell', () {
      selectionController.selectCell(const CellCoordinate(0, 0));
      final action = MergeCellsAction(ctx);
      expect(action.isEnabled(const MergeCellsIntent()), false);
    });

    test('is disabled when readOnly', () {
      selectionController.selectRange(const CellRange(0, 0, 1, 1));
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
      );
      final action = MergeCellsAction(roCtx);
      expect(action.isEnabled(const MergeCellsIntent()), false);
    });

    test('is enabled for multi-cell selection', () {
      selectionController.selectRange(const CellRange(0, 0, 1, 1));
      final action = MergeCellsAction(ctx);
      expect(action.isEnabled(const MergeCellsIntent()), true);
    });
  });

  group('MergeCellsHorizontallyAction', () {
    test('merges each row separately', () {
      selectionController.selectRange(const CellRange(0, 0, 1, 2));

      final action = MergeCellsHorizontallyAction(ctx);
      action.invoke(const MergeCellsHorizontallyIntent());

      // Row 0 should be merged
      expect(data.mergedCells.getRegion(const CellCoordinate(0, 0))?.range,
          const CellRange(0, 0, 0, 2));
      // Row 1 should be merged separately
      expect(data.mergedCells.getRegion(const CellCoordinate(1, 0))?.range,
          const CellRange(1, 0, 1, 2));
      expect(data.mergedCells.regionCount, 2);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('is disabled for single column', () {
      selectionController.selectRange(const CellRange(0, 0, 2, 0));
      final action = MergeCellsHorizontallyAction(ctx);
      expect(action.isEnabled(const MergeCellsHorizontallyIntent()), false);
    });
  });

  group('MergeCellsVerticallyAction', () {
    test('merges each column separately', () {
      selectionController.selectRange(const CellRange(0, 0, 2, 1));

      final action = MergeCellsVerticallyAction(ctx);
      action.invoke(const MergeCellsVerticallyIntent());

      // Col 0 should be merged
      expect(data.mergedCells.getRegion(const CellCoordinate(0, 0))?.range,
          const CellRange(0, 0, 2, 0));
      // Col 1 should be merged separately
      expect(data.mergedCells.getRegion(const CellCoordinate(0, 1))?.range,
          const CellRange(0, 1, 2, 1));
      expect(data.mergedCells.regionCount, 2);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('is disabled for single row', () {
      selectionController.selectRange(const CellRange(0, 0, 0, 2));
      final action = MergeCellsVerticallyAction(ctx);
      expect(action.isEnabled(const MergeCellsVerticallyIntent()), false);
    });
  });

  group('UnmergeCellsAction', () {
    test('unmerges regions overlapping selection', () {
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = UnmergeCellsAction(ctx);
      action.invoke(const UnmergeCellsIntent());

      expect(data.mergedCells.isEmpty, isTrue);
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('unmerges multiple overlapping regions', () {
      data.mergeCells(const CellRange(0, 0, 1, 1));
      data.mergeCells(const CellRange(0, 2, 1, 3));
      selectionController.selectRange(const CellRange(0, 0, 1, 3));

      final action = UnmergeCellsAction(ctx);
      action.invoke(const UnmergeCellsIntent());

      expect(data.mergedCells.isEmpty, isTrue);
    });

    test('is disabled when no merges overlap selection', () {
      data.mergeCells(const CellRange(5, 5, 6, 6));
      selectionController.selectCell(const CellCoordinate(0, 0));

      final action = UnmergeCellsAction(ctx);
      expect(action.isEnabled(const UnmergeCellsIntent()), false);
    });

    test('is enabled when merges overlap selection', () {
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = UnmergeCellsAction(ctx);
      expect(action.isEnabled(const UnmergeCellsIntent()), true);
    });

    test('preserves anchor value after unmerge', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('kept'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = UnmergeCellsAction(ctx);
      action.invoke(const UnmergeCellsIntent());

      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'kept');
    });
  });

  group('ToggleBoldAction', () {
    late EditController editController;
    late RichTextEditingController rtc;
    late MockWorksheetActionContext editCtx;

    setUp(() {
      editController = EditController();
      rtc = RichTextEditingController();
      rtc.initFromSpans([const TextSpan(text: 'Hello')]);
      rtc.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );
    });

    tearDown(() {
      rtc.dispose();
    });

    test('is enabled when not editing with selection', () {
      final action = ToggleBoldAction(editCtx);
      expect(action.isEnabled(const ToggleBoldIntent()), isTrue);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
        editController: editController,
      );
      final action = ToggleBoldAction(roCtx);
      expect(action.isEnabled(const ToggleBoldIntent()), isFalse);
    });

    test('is disabled when editing but no richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );

      final action = ToggleBoldAction(editCtx);
      expect(action.isEnabled(const ToggleBoldIntent()), isFalse);
    });

    test('is enabled when editing with richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );
      editController.richTextController = rtc;

      final action = ToggleBoldAction(editCtx);
      expect(action.isEnabled(const ToggleBoldIntent()), isTrue);
    });

    test('invoke toggles bold on richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );
      editController.richTextController = rtc;

      final action = ToggleBoldAction(editCtx);
      action.invoke(const ToggleBoldIntent());

      expect(rtc.isSelectionBold, isTrue);
    });

    test('toggles bold on data-layer spans when not editing', () {
      data.setCell(
        const CellCoordinate(5, 5),
        CellValue.text('Hello'),
      );
      selectionController.selectCell(const CellCoordinate(5, 5));

      final action = ToggleBoldAction(editCtx);
      action.invoke(const ToggleBoldIntent());

      final spans = data.getRichText(const CellCoordinate(5, 5));
      expect(spans, isNotNull);
      expect(spans!.first.style?.fontWeight, FontWeight.bold);
    });
  });

  group('ToggleItalicAction', () {
    late EditController editController;
    late RichTextEditingController rtc;
    late MockWorksheetActionContext editCtx;

    setUp(() {
      editController = EditController();
      rtc = RichTextEditingController();
      rtc.initFromSpans([const TextSpan(text: 'Hello')]);
      rtc.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );
    });

    tearDown(() {
      rtc.dispose();
    });

    test('is enabled when not editing with selection', () {
      final action = ToggleItalicAction(editCtx);
      expect(action.isEnabled(const ToggleItalicIntent()), isTrue);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
        editController: editController,
      );
      final action = ToggleItalicAction(roCtx);
      expect(action.isEnabled(const ToggleItalicIntent()), isFalse);
    });

    test('invoke toggles italic on richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );
      editController.richTextController = rtc;

      final action = ToggleItalicAction(editCtx);
      action.invoke(const ToggleItalicIntent());

      expect(rtc.isSelectionItalic, isTrue);
    });

    test('toggles italic on data-layer spans when not editing', () {
      data.setCell(
        const CellCoordinate(5, 5),
        CellValue.text('Hello'),
      );
      selectionController.selectCell(const CellCoordinate(5, 5));

      final action = ToggleItalicAction(editCtx);
      action.invoke(const ToggleItalicIntent());

      final spans = data.getRichText(const CellCoordinate(5, 5));
      expect(spans, isNotNull);
      expect(spans!.first.style?.fontStyle, FontStyle.italic);
    });
  });

  group('ToggleUnderlineAction', () {
    late EditController editController;
    late RichTextEditingController rtc;
    late MockWorksheetActionContext editCtx;

    setUp(() {
      editController = EditController();
      rtc = RichTextEditingController();
      rtc.initFromSpans([const TextSpan(text: 'Hello')]);
      rtc.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );
    });

    tearDown(() {
      rtc.dispose();
    });

    test('is enabled when not editing with selection', () {
      final action = ToggleUnderlineAction(editCtx);
      expect(action.isEnabled(const ToggleUnderlineIntent()), isTrue);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
        editController: editController,
      );
      final action = ToggleUnderlineAction(roCtx);
      expect(action.isEnabled(const ToggleUnderlineIntent()), isFalse);
    });

    test('invoke toggles underline on richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );
      editController.richTextController = rtc;

      final action = ToggleUnderlineAction(editCtx);
      action.invoke(const ToggleUnderlineIntent());

      expect(rtc.isSelectionUnderline, isTrue);
    });

    test('toggles underline on data-layer spans when not editing', () {
      data.setCell(
        const CellCoordinate(5, 5),
        CellValue.text('Hello'),
      );
      selectionController.selectCell(const CellCoordinate(5, 5));

      final action = ToggleUnderlineAction(editCtx);
      action.invoke(const ToggleUnderlineIntent());

      final spans = data.getRichText(const CellCoordinate(5, 5));
      expect(spans, isNotNull);
      expect(spans!.first.style?.decoration, TextDecoration.underline);
    });
  });

  group('ToggleStrikethroughAction', () {
    late EditController editController;
    late RichTextEditingController rtc;
    late MockWorksheetActionContext editCtx;

    setUp(() {
      editController = EditController();
      rtc = RichTextEditingController();
      rtc.initFromSpans([const TextSpan(text: 'Hello')]);
      rtc.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );
    });

    tearDown(() {
      rtc.dispose();
    });

    test('is enabled when not editing with selection', () {
      final action = ToggleStrikethroughAction(editCtx);
      expect(action.isEnabled(const ToggleStrikethroughIntent()), isTrue);
    });

    test('is disabled when readOnly', () {
      final roCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        readOnly: true,
        editController: editController,
      );
      final action = ToggleStrikethroughAction(roCtx);
      expect(action.isEnabled(const ToggleStrikethroughIntent()), isFalse);
    });

    test('invoke toggles strikethrough on richTextController', () {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
      );
      editController.richTextController = rtc;

      final action = ToggleStrikethroughAction(editCtx);
      action.invoke(const ToggleStrikethroughIntent());

      expect(rtc.isSelectionStrikethrough, isTrue);
    });

    test('toggles strikethrough on data-layer spans when not editing', () {
      data.setCell(
        const CellCoordinate(5, 5),
        CellValue.text('Hello'),
      );
      selectionController.selectCell(const CellCoordinate(5, 5));

      final action = ToggleStrikethroughAction(editCtx);
      action.invoke(const ToggleStrikethroughIntent());

      final spans = data.getRichText(const CellCoordinate(5, 5));
      expect(spans, isNotNull);
      expect(spans!.first.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('SetCellStyleAction', () {
    test('sets background on selected cell', () {
      selectionController.selectCell(const CellCoordinate(2, 3));

      final action = SetCellStyleAction(ctx);
      action.invoke(const SetCellStyleIntent(
        CellStyle(backgroundColor: Color(0xFFFF0000)),
      ));

      final style = data.getStyle(const CellCoordinate(2, 3));
      expect(style, isNotNull);
      expect(style!.backgroundColor, const Color(0xFFFF0000));
      expect(ctx.invalidateAndRebuildCount, 1);
    });

    test('merges style into existing style', () {
      const coord = CellCoordinate(2, 3);
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      selectionController.selectCell(coord);

      final action = SetCellStyleAction(ctx);
      action.invoke(const SetCellStyleIntent(
        CellStyle(wrapText: true),
      ));

      final style = data.getStyle(coord);
      expect(style, isNotNull);
      expect(style!.backgroundColor, const Color(0xFF00FF00));
      expect(style.wrapText, isTrue);
    });

    test('works during editing (not disabled)', () {
      final editController = EditController();
      editController.startEdit(cell: const CellCoordinate(2, 3));
      final editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );

      final action = SetCellStyleAction(editCtx);
      expect(action.isEnabled(const SetCellStyleIntent(
        CellStyle(backgroundColor: Color(0xFFFF0000)),
      )), isTrue);
    });

    test('no-op without selection', () {
      selectionController.clear();

      final action = SetCellStyleAction(ctx);
      action.invoke(const SetCellStyleIntent(
        CellStyle(backgroundColor: Color(0xFFFF0000)),
      ));

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
      final action = SetCellStyleAction(roCtx);
      expect(action.isEnabled(const SetCellStyleIntent(
        CellStyle(backgroundColor: Color(0xFFFF0000)),
      )), isFalse);
    });

    test('applies to multi-cell range', () {
      selectionController.selectRange(const CellRange(0, 0, 1, 1));

      final action = SetCellStyleAction(ctx);
      action.invoke(const SetCellStyleIntent(
        CellStyle(backgroundColor: Color(0xFFAABBCC)),
      ));

      for (int r = 0; r <= 1; r++) {
        for (int c = 0; c <= 1; c++) {
          final style = data.getStyle(CellCoordinate(r, c));
          expect(style?.backgroundColor, const Color(0xFFAABBCC));
        }
      }
    });
  });

  group('ClearCellsAction during editing', () {
    late EditController editController;
    late RichTextEditingController rtc;
    late MockWorksheetActionContext editCtx;

    setUp(() {
      editController = EditController();
      rtc = RichTextEditingController();
      rtc.initFromSpans([
        const TextSpan(
          text: 'Hello',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
      rtc.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      editCtx = MockWorksheetActionContext(
        selectionController: selectionController,
        maxRow: 100,
        maxColumn: 26,
        worksheetData: data,
        clipboardHandler: clipboardHandler,
        editController: editController,
      );
    });

    tearDown(() {
      rtc.dispose();
    });

    test('is enabled during editing for style-only clearing', () {
      editController.startEdit(cell: const CellCoordinate(5, 5));
      editController.richTextController = rtc;

      final action = ClearCellsAction(editCtx);
      expect(action.isEnabled(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: false,
      )), isTrue);
    });

    test('is disabled during editing when clearValue is true', () {
      editController.startEdit(cell: const CellCoordinate(5, 5));
      editController.richTextController = rtc;

      final action = ClearCellsAction(editCtx);
      expect(action.isEnabled(const ClearCellsIntent()), isFalse);
    });

    test('clears styles while editing', () {
      const coord = CellCoordinate(5, 5);
      data.setStyle(coord, const CellStyle(backgroundColor: Color(0xFF00FF00)));
      selectionController.selectCell(coord);
      editController.startEdit(cell: coord);
      editController.richTextController = rtc;

      final action = ClearCellsAction(editCtx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: false,
      ));

      expect(data.getStyle(coord), isNull);
      expect(editCtx.invalidateAndRebuildCount, 1);
    });

    test('strips rich text spans when clearing styles during editing', () {
      const coord = CellCoordinate(5, 5);
      selectionController.selectCell(coord);
      editController.startEdit(cell: coord);
      editController.richTextController = rtc;

      // Verify rich styles exist before clearing
      expect(rtc.hasRichStyles, isTrue);

      final action = ClearCellsAction(editCtx);
      action.invoke(const ClearCellsIntent(
        clearValue: false,
        clearStyle: true,
        clearFormat: false,
      ));

      expect(rtc.hasRichStyles, isFalse);
    });

    test('does not strip rich text when only clearing values', () {
      const coord = CellCoordinate(5, 5);
      data.setCell(coord, CellValue.text('hello'));
      selectionController.selectCell(coord);
      editController.startEdit(cell: coord);
      editController.richTextController = rtc;

      final action = ClearCellsAction(editCtx);
      action.invoke(const ClearCellsIntent(
        clearValue: true,
        clearStyle: false,
        clearFormat: false,
      ));

      // Rich styles should still be present
      expect(rtc.hasRichStyles, isTrue);
    });
  });
}
