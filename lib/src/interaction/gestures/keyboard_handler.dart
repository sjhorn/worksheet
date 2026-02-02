import 'package:flutter/services.dart';

import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../controllers/selection_controller.dart';

/// Callback when edit mode should start.
typedef OnStartEditCallback = void Function();

/// Callback to scroll to ensure a cell is visible.
typedef OnEnsureVisibleCallback = void Function();

/// Handles keyboard input for worksheet navigation.
///
/// Supports:
/// - Arrow keys: move selection
/// - Shift+arrows: extend selection
/// - Ctrl/Cmd+Home: jump to start (A1)
/// - Ctrl/Cmd+End: jump to last populated cell
/// - Tab: move to next cell
/// - Enter: move to cell below (or start edit)
/// - Escape: cancel selection/editing
/// - F2: enter edit mode
@Deprecated('Use the Shortcuts/Actions pattern. See worksheet_intents.dart.')
class KeyboardHandler {
  /// The selection controller to update.
  final SelectionController selectionController;

  /// Maximum row index (exclusive).
  final int maxRow;

  /// Maximum column index (exclusive).
  final int maxColumn;

  /// Called when edit mode should start.
  final OnStartEditCallback? onStartEdit;

  /// Called when the view should scroll to ensure the selection is visible.
  final OnEnsureVisibleCallback? onEnsureVisible;

  /// Called when Ctrl+C (copy) is pressed.
  final VoidCallback? onCopy;

  /// Called when Ctrl+X (cut) is pressed.
  final VoidCallback? onCut;

  /// Called when Ctrl+V (paste) is pressed.
  final VoidCallback? onPaste;

  /// Called when Delete or Backspace is pressed (clear selection).
  final VoidCallback? onDelete;

  /// Called when Ctrl+D (fill down) is pressed.
  final VoidCallback? onFillDown;

  /// Called when Ctrl+R (fill right) is pressed.
  final VoidCallback? onFillRight;

  /// Creates a keyboard handler.
  KeyboardHandler({
    required this.selectionController,
    required this.maxRow,
    required this.maxColumn,
    this.onStartEdit,
    this.onEnsureVisible,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.onDelete,
    this.onFillDown,
    this.onFillRight,
  });

  /// Handles a key event.
  ///
  /// Returns true if the event was handled, false otherwise.
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final logicalKey = event.logicalKey;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Navigation keys
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(rowDelta: -1, extend: isShiftPressed);
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(rowDelta: 1, extend: isShiftPressed);
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveSelection(columnDelta: -1, extend: isShiftPressed);
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveSelection(columnDelta: 1, extend: isShiftPressed);
      return true;
    }

    // Page navigation
    if (logicalKey == LogicalKeyboardKey.pageUp) {
      _moveSelection(rowDelta: -10, extend: isShiftPressed);
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.pageDown) {
      _moveSelection(rowDelta: 10, extend: isShiftPressed);
      return true;
    }

    // Home/End navigation
    if (logicalKey == LogicalKeyboardKey.home) {
      if (isControlPressed) {
        // Ctrl+Home: go to A1
        selectionController.selectCell(const CellCoordinate(0, 0));
      } else {
        // Home: go to start of row
        final focus = selectionController.focus;
        if (focus != null) {
          if (isShiftPressed) {
            selectionController.extendSelection(CellCoordinate(focus.row, 0));
          } else {
            selectionController.selectCell(CellCoordinate(focus.row, 0));
          }
        }
      }
      onEnsureVisible?.call();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.end) {
      if (isControlPressed) {
        // Ctrl+End: go to last cell
        selectionController.selectCell(
          CellCoordinate(maxRow - 1, maxColumn - 1),
        );
      } else {
        // End: go to end of row
        final focus = selectionController.focus;
        if (focus != null) {
          if (isShiftPressed) {
            selectionController.extendSelection(
              CellCoordinate(focus.row, maxColumn - 1),
            );
          } else {
            selectionController.selectCell(
              CellCoordinate(focus.row, maxColumn - 1),
            );
          }
        }
      }
      onEnsureVisible?.call();
      return true;
    }

    // Tab navigation
    if (logicalKey == LogicalKeyboardKey.tab) {
      if (isShiftPressed) {
        // Shift+Tab: move left
        _moveSelection(columnDelta: -1, extend: false);
      } else {
        // Tab: move right
        _moveSelection(columnDelta: 1, extend: false);
      }
      return true;
    }

    // Enter key
    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (isShiftPressed) {
        // Shift+Enter: move up
        _moveSelection(rowDelta: -1, extend: false);
      } else {
        // Enter: move down (or start edit in some modes)
        _moveSelection(rowDelta: 1, extend: false);
      }
      return true;
    }

    // Escape key
    if (logicalKey == LogicalKeyboardKey.escape) {
      // Clear extension, keep focus cell
      final focus = selectionController.focus;
      if (focus != null) {
        selectionController.selectCell(focus);
      }
      return true;
    }

    // F2 key: enter edit mode
    if (logicalKey == LogicalKeyboardKey.f2) {
      onStartEdit?.call();
      return true;
    }

    // Select all (Ctrl+A)
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyA) {
      selectionController.selectRange(
        CellRange(0, 0, maxRow - 1, maxColumn - 1),
      );
      return true;
    }

    // Clipboard: Ctrl+C (copy)
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyC) {
      onCopy?.call();
      return true;
    }

    // Clipboard: Ctrl+X (cut)
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyX) {
      onCut?.call();
      return true;
    }

    // Clipboard: Ctrl+V (paste)
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyV) {
      onPaste?.call();
      return true;
    }

    // Fill down: Ctrl+D
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyD) {
      onFillDown?.call();
      return true;
    }

    // Fill right: Ctrl+R
    if (isControlPressed && logicalKey == LogicalKeyboardKey.keyR) {
      onFillRight?.call();
      return true;
    }

    // Delete/Backspace: clear selected cells
    if (logicalKey == LogicalKeyboardKey.delete ||
        logicalKey == LogicalKeyboardKey.backspace) {
      onDelete?.call();
      return true;
    }

    return false;
  }

  void _moveSelection({
    int rowDelta = 0,
    int columnDelta = 0,
    required bool extend,
  }) {
    selectionController.moveFocus(
      rowDelta: rowDelta,
      columnDelta: columnDelta,
      extend: extend,
      maxRow: maxRow,
      maxColumn: maxColumn,
    );
    onEnsureVisible?.call();
  }
}

