import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/models/cell_coordinate.dart';
import 'worksheet_intents.dart';

/// Provides the default keyboard shortcut bindings for [Worksheet].
///
/// Consumers can override individual bindings by passing a custom `shortcuts`
/// map to the [Worksheet] widget, which is merged on top of these defaults.
class DefaultWorksheetShortcuts {
  DefaultWorksheetShortcuts._();

  /// The default shortcut-to-intent map.
  ///
  /// Contains ~40 bindings covering navigation, selection, clipboard, and
  /// editing. Both `control` and `meta` variants are included for
  /// cross-platform compatibility.
  static final Map<ShortcutActivator, Intent> shortcuts =
      <ShortcutActivator, Intent>{
    // Arrow navigation
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const MoveSelectionIntent(rowDelta: -1),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const MoveSelectionIntent(rowDelta: 1),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const MoveSelectionIntent(columnDelta: -1),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const MoveSelectionIntent(columnDelta: 1),

    // Shift+Arrow: extend selection
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        const MoveSelectionIntent(rowDelta: -1, extend: true),
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        const MoveSelectionIntent(rowDelta: 1, extend: true),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        const MoveSelectionIntent(columnDelta: -1, extend: true),
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        const MoveSelectionIntent(columnDelta: 1, extend: true),

    // Page navigation
    const SingleActivator(LogicalKeyboardKey.pageUp):
        const MoveSelectionIntent(rowDelta: -10),
    const SingleActivator(LogicalKeyboardKey.pageDown):
        const MoveSelectionIntent(rowDelta: 10),
    const SingleActivator(LogicalKeyboardKey.pageUp, shift: true):
        const MoveSelectionIntent(rowDelta: -10, extend: true),
    const SingleActivator(LogicalKeyboardKey.pageDown, shift: true):
        const MoveSelectionIntent(rowDelta: 10, extend: true),

    // Tab navigation
    const SingleActivator(LogicalKeyboardKey.tab):
        const MoveSelectionIntent(columnDelta: 1),
    const SingleActivator(LogicalKeyboardKey.tab, shift: true):
        const MoveSelectionIntent(columnDelta: -1),

    // Enter navigation
    const SingleActivator(LogicalKeyboardKey.enter):
        const MoveSelectionIntent(rowDelta: 1),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const MoveSelectionIntent(rowDelta: 1),
    const SingleActivator(LogicalKeyboardKey.enter, shift: true):
        const MoveSelectionIntent(rowDelta: -1),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
        const MoveSelectionIntent(rowDelta: -1),

    // Home/End: row boundaries
    const SingleActivator(LogicalKeyboardKey.home):
        const GoToRowBoundaryIntent(end: false),
    const SingleActivator(LogicalKeyboardKey.end):
        const GoToRowBoundaryIntent(end: true),
    const SingleActivator(LogicalKeyboardKey.home, shift: true):
        const GoToRowBoundaryIntent(end: false, extend: true),
    const SingleActivator(LogicalKeyboardKey.end, shift: true):
        const GoToRowBoundaryIntent(end: true, extend: true),

    // Ctrl+Home: go to A1
    const SingleActivator(LogicalKeyboardKey.home, control: true):
        const GoToCellIntent(CellCoordinate(0, 0)),
    const SingleActivator(LogicalKeyboardKey.home, meta: true):
        const GoToCellIntent(CellCoordinate(0, 0)),

    // Ctrl+End: go to last cell
    const SingleActivator(LogicalKeyboardKey.end, control: true):
        const GoToLastCellIntent(),
    const SingleActivator(LogicalKeyboardKey.end, meta: true):
        const GoToLastCellIntent(),

    // Escape: cancel selection
    const SingleActivator(LogicalKeyboardKey.escape):
        const CancelSelectionIntent(),

    // F2: edit cell
    const SingleActivator(LogicalKeyboardKey.f2): const EditCellIntent(),

    // Ctrl+A: select all
    const SingleActivator(LogicalKeyboardKey.keyA, control: true):
        const SelectAllCellsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
        const SelectAllCellsIntent(),

    // Ctrl+C: copy
    const SingleActivator(LogicalKeyboardKey.keyC, control: true):
        const CopyCellsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
        const CopyCellsIntent(),

    // Ctrl+X: cut
    const SingleActivator(LogicalKeyboardKey.keyX, control: true):
        const CutCellsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX, meta: true):
        const CutCellsIntent(),

    // Ctrl+V: paste
    const SingleActivator(LogicalKeyboardKey.keyV, control: true):
        const PasteCellsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
        const PasteCellsIntent(),

    // Delete/Backspace: clear cells
    const SingleActivator(LogicalKeyboardKey.delete):
        const ClearCellsIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace):
        const ClearCellsIntent(),

    // Ctrl+\: clear formatting (preserve values)
    const SingleActivator(LogicalKeyboardKey.backslash, control: true):
        const ClearCellsIntent(
            clearValue: false, clearStyle: true, clearFormat: true),
    const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
        const ClearCellsIntent(
            clearValue: false, clearStyle: true, clearFormat: true),

    // Ctrl+D: fill down
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        const FillDownIntent(),
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        const FillDownIntent(),

    // Ctrl+R: fill right
    const SingleActivator(LogicalKeyboardKey.keyR, control: true):
        const FillRightIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
        const FillRightIntent(),

    // Rich text formatting (active only during editing)
    // Ctrl+B: toggle bold
    const SingleActivator(LogicalKeyboardKey.keyB, control: true):
        const ToggleBoldIntent(),
    const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
        const ToggleBoldIntent(),

    // Ctrl+I: toggle italic
    const SingleActivator(LogicalKeyboardKey.keyI, control: true):
        const ToggleItalicIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
        const ToggleItalicIntent(),

    // Ctrl+U: toggle underline
    const SingleActivator(LogicalKeyboardKey.keyU, control: true):
        const ToggleUnderlineIntent(),
    const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
        const ToggleUnderlineIntent(),

    // Ctrl+Shift+S: toggle strikethrough
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
        const ToggleStrikethroughIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
        const ToggleStrikethroughIntent(),
  };
}
