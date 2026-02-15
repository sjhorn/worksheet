import 'package:any_date/any_date.dart';
import 'package:flutter/widgets.dart';

import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_format.dart';
import '../../core/models/cell_value.dart';
import 'rich_text_editing_controller.dart';

/// The result of committing a cell edit, including navigation direction.
///
/// Used by [CellEditorOverlay] to communicate both the committed value
/// and the desired post-commit navigation to the [Worksheet] widget.
@immutable
class EditCommitResult {
  /// The cell that was edited.
  final CellCoordinate cell;

  /// The committed value, or null if the cell was cleared.
  final CellValue? value;

  /// Row offset to move after commit (e.g. 1 for Enter, -1 for Shift+Enter).
  final int rowDelta;

  /// Column offset to move after commit (e.g. 1 for Tab, -1 for Shift+Tab).
  final int columnDelta;

  const EditCommitResult({
    required this.cell,
    required this.value,
    this.rowDelta = 0,
    this.columnDelta = 0,
  });
}

/// The current state of cell editing.
enum EditState {
  /// No editing is in progress.
  idle,

  /// A cell is being edited.
  editing,

  /// An edit is being committed.
  committing,
}

/// How the edit was initiated.
enum EditTrigger {
  /// Double-tap/click on a cell.
  doubleTap,

  /// Pressing F2 key.
  f2Key,

  /// Typing a character (starts with that character).
  typing,

  /// Programmatic start.
  programmatic,
}

/// Controls cell editing state for a worksheet.
///
/// Manages the lifecycle of cell editing:
/// - Start edit on: double-tap, F2, typing
/// - Commit on: Enter, Tab, click away
/// - Cancel on: Escape
///
/// Notifies listeners when edit state changes.
class EditController extends ChangeNotifier {
  /// Date parser for type detection. Set by [Worksheet] when provided.
  AnyDate? dateParser;

  /// Locale for date format detection. Set by [Worksheet] when provided.
  FormatLocale locale = FormatLocale.enUs;

  /// Callback registered by the overlay to extract rich text spans from the
  /// active editing controller. Used by external commit paths (e.g. click-away)
  /// that don't go through the overlay's own `_commit()` method.
  List<TextSpan>? Function()? richTextExtractor;

  /// The active rich text editing controller, registered by [CellEditorOverlay]
  /// during editing and cleared on dispose.
  ///
  /// Enables toolbar buttons and other external code to invoke formatting
  /// operations (bold, italic, etc.) and query the current selection style.
  RichTextEditingController? richTextController;

  /// The editor's focus node, registered by [CellEditorOverlay] during editing
  /// and cleared on dispose. Used by [requestEditorFocus] to restore focus
  /// after toolbar actions steal it.
  FocusNode? editorFocusNode;

  EditState _state = EditState.idle;
  CellCoordinate? _editingCell;
  CellValue? _originalValue;
  String _currentText = '';
  EditTrigger? _trigger;

  /// The current edit state.
  EditState get state => _state;

  /// The cell currently being edited, or null if not editing.
  CellCoordinate? get editingCell => _editingCell;

  /// The original value before editing started.
  CellValue? get originalValue => _originalValue;

  /// The current text being edited.
  String get currentText => _currentText;

  /// How the current edit was triggered.
  EditTrigger? get trigger => _trigger;

  /// Whether editing is currently in progress.
  bool get isEditing => _state == EditState.editing;

  /// Starts editing a cell.
  ///
  /// [cell] is the cell to edit.
  /// [currentValue] is the current value of the cell.
  /// [trigger] is how the edit was initiated.
  /// [initialText] is optional initial text (for typing trigger).
  ///
  /// Returns true if editing was started successfully.
  bool startEdit({
    required CellCoordinate cell,
    CellValue? currentValue,
    EditTrigger trigger = EditTrigger.programmatic,
    String? initialText,
  }) {
    if (_state != EditState.idle) {
      return false;
    }

    _state = EditState.editing;
    _editingCell = cell;
    _originalValue = currentValue;
    _trigger = trigger;

    // Set initial text
    if (initialText != null) {
      _currentText = initialText;
    } else if (trigger == EditTrigger.typing) {
      _currentText = initialText ?? '';
    } else {
      _currentText = currentValue?.displayValue ?? '';
    }

    notifyListeners();
    return true;
  }

  /// Updates the current text being edited.
  ///
  /// Only valid while editing.
  void updateText(String text) {
    if (_state != EditState.editing) return;

    _currentText = text;
    notifyListeners();
  }

  /// Commits the current edit.
  ///
  /// [onCommit] is called with the cell, new value, and an optional detected
  /// format if the input was recognized as a formatted number, date, or
  /// duration.
  /// Returns the committed value, or null if commit was cancelled.
  CellValue? commitEdit({
    required void Function(
      CellCoordinate cell,
      CellValue? value, {
      CellFormat? detectedFormat,
    }) onCommit,
  }) {
    if (_state != EditState.editing) return null;

    _state = EditState.committing;

    final cell = _editingCell!;
    final inputText = _currentText;

    CellValue? newValue;
    CellFormat? detectedFormat;

    // 1. Try formatted number (coupled parse + detect)
    final numberResult = NumberFormatDetector.detect(inputText, locale: locale);
    if (numberResult != null) {
      newValue = numberResult.value;
      detectedFormat = numberResult.format;
    } else {
      // 2. Standard parse (formula, boolean, plain number, duration, date, text)
      newValue = _parseText(inputText);

      if (newValue != null && newValue.isDate) {
        detectedFormat = DateFormatDetector.detect(
          inputText,
          newValue.asDateTime,
          dayFirst: locale.dayFirst,
          locale: locale,
        );
      } else if (newValue != null && newValue.isDuration) {
        detectedFormat = DurationFormatDetector.detect(
          inputText,
          newValue.asDuration,
        );
      }
    }

    // Call commit callback
    onCommit(cell, newValue, detectedFormat: detectedFormat);

    // Reset state
    _state = EditState.idle;
    _editingCell = null;
    _originalValue = null;
    _currentText = '';
    _trigger = null;

    notifyListeners();
    return newValue;
  }

  /// Cancels the current edit.
  ///
  /// Reverts to the original value.
  void cancelEdit() {
    if (_state != EditState.editing) return;

    _state = EditState.idle;
    _editingCell = null;
    _originalValue = null;
    _currentText = '';
    _trigger = null;

    notifyListeners();
  }

  /// Parses text into a cell value.
  ///
  /// Delegates to [CellValue.parse] for unified type detection.
  CellValue? _parseText(String text) =>
      CellValue.parse(text, dateParser: dateParser);

  /// Checks if the current value has changed from the original.
  bool get hasChanges {
    if (_state != EditState.editing) return false;

    final newValue = _parseText(_currentText);
    if (_originalValue == null && newValue == null) return false;
    if (_originalValue == null || newValue == null) return true;

    return _originalValue != newValue;
  }

  // -- Rich text formatting convenience methods --
  // These delegate to [richTextController] for use by toolbars and other
  // external code that doesn't have direct access to the overlay.

  /// Toggles bold on the active editing selection. No-op if not editing.
  void toggleBold() => richTextController?.toggleBold();

  /// Toggles italic on the active editing selection. No-op if not editing.
  void toggleItalic() => richTextController?.toggleItalic();

  /// Toggles underline on the active editing selection. No-op if not editing.
  void toggleUnderline() => richTextController?.toggleUnderline();

  /// Toggles strikethrough on the active editing selection. No-op if not editing.
  void toggleStrikethrough() => richTextController?.toggleStrikethrough();

  /// Returns the common [TextStyle] across the current editing selection.
  ///
  /// Returns null when not editing or no rich text controller is active.
  TextStyle? getSelectionStyle() => richTextController?.getSelectionStyle();

  /// Whether all characters in the editing selection are bold.
  bool get isSelectionBold => richTextController?.isSelectionBold ?? false;

  /// Whether all characters in the editing selection are italic.
  bool get isSelectionItalic => richTextController?.isSelectionItalic ?? false;

  /// Whether all characters in the editing selection are underlined.
  bool get isSelectionUnderline =>
      richTextController?.isSelectionUnderline ?? false;

  /// Whether all characters in the editing selection have strikethrough.
  bool get isSelectionStrikethrough =>
      richTextController?.isSelectionStrikethrough ?? false;

  /// Requests focus on the editor overlay.
  ///
  /// Call this after toolbar actions that may steal focus from the editor
  /// (e.g. clicking an [IconButton] while editing). Schedules focus
  /// restoration via a post-frame callback so it runs after the current
  /// build phase completes.
  void requestEditorFocus() {
    final node = editorFocusNode;
    if (node == null || !isEditing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEditing && !node.hasFocus && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }
}
