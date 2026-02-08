import 'package:flutter/widgets.dart';

import '../core/models/cell_coordinate.dart';

/// Moves the selection focus by [rowDelta] rows and [columnDelta] columns.
///
/// When [extend] is true, the anchor stays fixed and the selection becomes a
/// range. Used for arrow keys, page up/down, tab, and enter navigation.
class MoveSelectionIntent extends Intent {
  /// Number of rows to move (negative = up, positive = down).
  final int rowDelta;

  /// Number of columns to move (negative = left, positive = right).
  final int columnDelta;

  /// Whether to extend the existing selection instead of moving it.
  final bool extend;

  const MoveSelectionIntent({
    this.rowDelta = 0,
    this.columnDelta = 0,
    this.extend = false,
  });
}

/// Navigates to a specific cell coordinate.
///
/// Used for Ctrl+Home (go to A1).
class GoToCellIntent extends Intent {
  /// The target cell coordinate.
  final CellCoordinate coordinate;

  const GoToCellIntent(this.coordinate);
}

/// Navigates to the last cell in the worksheet (bottom-right corner).
///
/// Separate from [GoToCellIntent] because the target depends on runtime
/// [maxRow]/[maxColumn] values that cannot be const in the shortcuts map.
///
/// Used for Ctrl+End.
class GoToLastCellIntent extends Intent {
  const GoToLastCellIntent();
}

/// Navigates to the start or end of the current row.
///
/// When [extend] is true, extends the selection instead of moving it.
///
/// Used for Home/End and Shift+Home/Shift+End.
class GoToRowBoundaryIntent extends Intent {
  /// Whether to go to the end of the row (true) or the start (false).
  final bool end;

  /// Whether to extend the existing selection.
  final bool extend;

  const GoToRowBoundaryIntent({required this.end, this.extend = false});
}

/// Selects all cells in the worksheet.
///
/// Used for Ctrl+A.
class SelectAllCellsIntent extends Intent {
  const SelectAllCellsIntent();
}

/// Cancels the current selection extension, collapsing to the focus cell.
///
/// Used for Escape.
class CancelSelectionIntent extends Intent {
  const CancelSelectionIntent();
}

/// Enters edit mode on the currently focused cell.
///
/// Used for F2.
class EditCellIntent extends Intent {
  const EditCellIntent();
}

/// Copies the selected cells to the system clipboard.
///
/// Used for Ctrl+C.
class CopyCellsIntent extends Intent {
  const CopyCellsIntent();
}

/// Cuts the selected cells to the system clipboard.
///
/// Used for Ctrl+X.
class CutCellsIntent extends Intent {
  const CutCellsIntent();
}

/// Pastes from the system clipboard at the current selection.
///
/// Used for Ctrl+V.
class PasteCellsIntent extends Intent {
  const PasteCellsIntent();
}

/// Clears the contents, styles, and/or formats of the selected cells.
///
/// By default all three flags are `true`, so `const ClearCellsIntent()` clears
/// everything (backward compatible with Delete/Backspace behavior).
///
/// Common combinations:
/// - Clear all: `ClearCellsIntent()` (default)
/// - Clear formatting only: `ClearCellsIntent(clearValue: false)`
/// - Clear values only: `ClearCellsIntent(clearStyle: false, clearFormat: false)`
class ClearCellsIntent extends Intent {
  /// Whether to clear cell values.
  final bool clearValue;

  /// Whether to clear cell styles (background, font, alignment, borders, etc.).
  final bool clearStyle;

  /// Whether to clear cell formats (number format, date format, etc.).
  final bool clearFormat;

  const ClearCellsIntent({
    this.clearValue = true,
    this.clearStyle = true,
    this.clearFormat = true,
  });
}

/// Fills the selected range downward from the first row.
///
/// Used for Ctrl+D.
class FillDownIntent extends Intent {
  const FillDownIntent();
}

/// Fills the selected range rightward from the first column.
///
/// Used for Ctrl+R.
class FillRightIntent extends Intent {
  const FillRightIntent();
}
