import 'package:flutter/widgets.dart';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import 'worksheet_action_context.dart';
import 'worksheet_intents.dart';

/// Moves the selection focus by a row/column delta.
///
/// Handles arrow keys, page up/down, tab, and enter navigation.
class MoveSelectionAction extends Action<MoveSelectionIntent> {
  final WorksheetActionContext _context;

  MoveSelectionAction(this._context);

  @override
  bool isEnabled(MoveSelectionIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(MoveSelectionIntent intent) {
    _context.selectionController.moveFocus(
      rowDelta: intent.rowDelta,
      columnDelta: intent.columnDelta,
      extend: intent.extend,
      maxRow: _context.maxRow,
      maxColumn: _context.maxColumn,
    );
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to a specific cell coordinate.
class GoToCellAction extends Action<GoToCellIntent> {
  final WorksheetActionContext _context;

  GoToCellAction(this._context);

  @override
  Object? invoke(GoToCellIntent intent) {
    _context.selectionController.selectCell(intent.coordinate);
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to the last cell in the worksheet.
class GoToLastCellAction extends Action<GoToLastCellIntent> {
  final WorksheetActionContext _context;

  GoToLastCellAction(this._context);

  @override
  Object? invoke(GoToLastCellIntent intent) {
    _context.selectionController.selectCell(
      CellCoordinate(_context.maxRow - 1, _context.maxColumn - 1),
    );
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to the start or end of the current row.
class GoToRowBoundaryAction extends Action<GoToRowBoundaryIntent> {
  final WorksheetActionContext _context;

  GoToRowBoundaryAction(this._context);

  @override
  Object? invoke(GoToRowBoundaryIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus == null) return null;

    final targetColumn = intent.end ? _context.maxColumn - 1 : 0;
    final target = CellCoordinate(focus.row, targetColumn);

    if (intent.extend) {
      _context.selectionController.extendSelection(target);
    } else {
      _context.selectionController.selectCell(target);
    }
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Selects all cells in the worksheet.
class SelectAllCellsAction extends Action<SelectAllCellsIntent> {
  final WorksheetActionContext _context;

  SelectAllCellsAction(this._context);

  @override
  bool isEnabled(SelectAllCellsIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(SelectAllCellsIntent intent) {
    _context.selectionController.selectRange(
      CellRange(0, 0, _context.maxRow - 1, _context.maxColumn - 1),
    );
    return null;
  }
}

/// Cancels the current selection extension, collapsing to the focus cell.
class CancelSelectionAction extends Action<CancelSelectionIntent> {
  final WorksheetActionContext _context;

  CancelSelectionAction(this._context);

  @override
  Object? invoke(CancelSelectionIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus != null) {
      _context.selectionController.selectCell(focus);
    }
    return null;
  }
}

/// Enters edit mode on the currently focused cell.
class EditCellAction extends Action<EditCellIntent> {
  final WorksheetActionContext _context;

  EditCellAction(this._context);

  @override
  Object? invoke(EditCellIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus != null) {
      _context.onEditCell?.call(focus);
    }
    return null;
  }
}

/// Copies the selected cells to the system clipboard.
class CopyCellsAction extends Action<CopyCellsIntent> {
  final WorksheetActionContext _context;

  CopyCellsAction(this._context);

  @override
  bool isEnabled(CopyCellsIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(CopyCellsIntent intent) {
    _context.clipboardHandler.copy();
    return null;
  }
}

/// Cuts the selected cells to the system clipboard.
class CutCellsAction extends Action<CutCellsIntent> {
  final WorksheetActionContext _context;

  CutCellsAction(this._context);

  @override
  bool isEnabled(CutCellsIntent intent) =>
      !_context.readOnly && _context.editController?.isEditing != true;

  @override
  Object? invoke(CutCellsIntent intent) {
    _context.clipboardHandler.cut().then((_) {
      _context.invalidateAndRebuild();
    });
    return null;
  }
}

/// Pastes from the system clipboard at the current selection.
class PasteCellsAction extends Action<PasteCellsIntent> {
  final WorksheetActionContext _context;

  PasteCellsAction(this._context);

  @override
  bool isEnabled(PasteCellsIntent intent) =>
      !_context.readOnly && _context.editController?.isEditing != true;

  @override
  Object? invoke(PasteCellsIntent intent) {
    _context.clipboardHandler.paste().then((_) {
      _context.invalidateAndRebuild();
    });
    return null;
  }
}

/// Clears the contents of the selected cells.
class ClearCellsAction extends Action<ClearCellsIntent> {
  final WorksheetActionContext _context;

  ClearCellsAction(this._context);

  @override
  bool isEnabled(ClearCellsIntent intent) =>
      !_context.readOnly && _context.editController?.isEditing != true;

  @override
  Object? invoke(ClearCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null) return null;

    if (intent.clearValue && intent.clearStyle && intent.clearFormat) {
      _context.worksheetData.clearRange(range);
    } else {
      _context.worksheetData.batchUpdate((batch) {
        if (intent.clearValue) batch.clearValues(range);
        if (intent.clearStyle) batch.clearStyles(range);
        if (intent.clearFormat) batch.clearFormats(range);
      });
    }

    _context.invalidateAndRebuild();
    return null;
  }
}

/// Fills the selected range downward from the first row.
class FillDownAction extends Action<FillDownIntent> {
  final WorksheetActionContext _context;

  FillDownAction(this._context);

  @override
  bool isEnabled(FillDownIntent intent) => !_context.readOnly;

  @override
  Object? invoke(FillDownIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.rowCount < 2) return null;
    for (int col = range.startColumn; col <= range.endColumn; col++) {
      _context.worksheetData.fillRange(
        CellCoordinate(range.startRow, col),
        CellRange(range.startRow + 1, col, range.endRow, col),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Fills the selected range rightward from the first column.
class FillRightAction extends Action<FillRightIntent> {
  final WorksheetActionContext _context;

  FillRightAction(this._context);

  @override
  bool isEnabled(FillRightIntent intent) => !_context.readOnly;

  @override
  Object? invoke(FillRightIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.columnCount < 2) return null;
    for (int row = range.startRow; row <= range.endRow; row++) {
      _context.worksheetData.fillRange(
        CellCoordinate(row, range.startColumn),
        CellRange(row, range.startColumn + 1, row, range.endColumn),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges all cells in the current selection into a single merged cell.
class MergeCellsAction extends Action<MergeCellsIntent> {
  final WorksheetActionContext _context;

  MergeCellsAction(this._context);

  @override
  bool isEnabled(MergeCellsIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.cellCount >= 2;
  }

  @override
  Object? invoke(MergeCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.cellCount < 2) return null;

    _context.worksheetData.mergeCells(range);
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges each row of the current selection separately.
class MergeCellsHorizontallyAction extends Action<MergeCellsHorizontallyIntent> {
  final WorksheetActionContext _context;

  MergeCellsHorizontallyAction(this._context);

  @override
  bool isEnabled(MergeCellsHorizontallyIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.columnCount >= 2;
  }

  @override
  Object? invoke(MergeCellsHorizontallyIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.columnCount < 2) return null;

    for (int row = range.startRow; row <= range.endRow; row++) {
      _context.worksheetData.mergeCells(
        CellRange(row, range.startColumn, row, range.endColumn),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges each column of the current selection separately.
class MergeCellsVerticallyAction extends Action<MergeCellsVerticallyIntent> {
  final WorksheetActionContext _context;

  MergeCellsVerticallyAction(this._context);

  @override
  bool isEnabled(MergeCellsVerticallyIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.rowCount >= 2;
  }

  @override
  Object? invoke(MergeCellsVerticallyIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.rowCount < 2) return null;

    for (int col = range.startColumn; col <= range.endColumn; col++) {
      _context.worksheetData.mergeCells(
        CellRange(range.startRow, col, range.endRow, col),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles bold formatting on the current text selection during editing.
///
/// Unlike most worksheet actions which are disabled during editing, this
/// action is **enabled only during editing** (inverse pattern).
class ToggleBoldAction extends Action<ToggleBoldIntent> {
  final WorksheetActionContext _context;

  ToggleBoldAction(this._context);

  @override
  bool isEnabled(ToggleBoldIntent intent) =>
      _context.editController?.isEditing == true &&
      _context.editController?.richTextController != null;

  @override
  Object? invoke(ToggleBoldIntent intent) {
    _context.editController!.richTextController!.toggleBold();
    return null;
  }
}

/// Toggles italic formatting on the current text selection during editing.
class ToggleItalicAction extends Action<ToggleItalicIntent> {
  final WorksheetActionContext _context;

  ToggleItalicAction(this._context);

  @override
  bool isEnabled(ToggleItalicIntent intent) =>
      _context.editController?.isEditing == true &&
      _context.editController?.richTextController != null;

  @override
  Object? invoke(ToggleItalicIntent intent) {
    _context.editController!.richTextController!.toggleItalic();
    return null;
  }
}

/// Toggles underline formatting on the current text selection during editing.
class ToggleUnderlineAction extends Action<ToggleUnderlineIntent> {
  final WorksheetActionContext _context;

  ToggleUnderlineAction(this._context);

  @override
  bool isEnabled(ToggleUnderlineIntent intent) =>
      _context.editController?.isEditing == true &&
      _context.editController?.richTextController != null;

  @override
  Object? invoke(ToggleUnderlineIntent intent) {
    _context.editController!.richTextController!.toggleUnderline();
    return null;
  }
}

/// Toggles strikethrough formatting on the current text selection during editing.
class ToggleStrikethroughAction extends Action<ToggleStrikethroughIntent> {
  final WorksheetActionContext _context;

  ToggleStrikethroughAction(this._context);

  @override
  bool isEnabled(ToggleStrikethroughIntent intent) =>
      _context.editController?.isEditing == true &&
      _context.editController?.richTextController != null;

  @override
  Object? invoke(ToggleStrikethroughIntent intent) {
    _context.editController!.richTextController!.toggleStrikethrough();
    return null;
  }
}

/// Unmerges all merge regions overlapping the current selection.
class UnmergeCellsAction extends Action<UnmergeCellsIntent> {
  final WorksheetActionContext _context;

  UnmergeCellsAction(this._context);

  @override
  bool isEnabled(UnmergeCellsIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    if (range == null) return false;
    final mergedCells = _context.worksheetData.mergedCells;
    return mergedCells.regionsInRange(range).isNotEmpty;
  }

  @override
  Object? invoke(UnmergeCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null) return null;

    final mergedCells = _context.worksheetData.mergedCells;
    // Collect anchors first to avoid modifying during iteration
    final anchors = mergedCells
        .regionsInRange(range)
        .map((r) => r.anchor)
        .toList();

    for (final anchor in anchors) {
      _context.worksheetData.unmergeCells(anchor);
    }

    _context.invalidateAndRebuild();
    return null;
  }
}
