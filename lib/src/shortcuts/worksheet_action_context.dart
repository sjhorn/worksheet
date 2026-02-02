import '../core/data/worksheet_data.dart';
import '../core/models/cell_coordinate.dart';
import '../interaction/clipboard/clipboard_handler.dart';
import '../interaction/controllers/selection_controller.dart';

/// Interface providing the dependencies that worksheet [Action] classes need.
///
/// Implemented by the worksheet widget's state to avoid threading many
/// constructor parameters into every Action.
abstract class WorksheetActionContext {
  /// The selection controller for reading and updating selection state.
  SelectionController get selectionController;

  /// Maximum row count (exclusive) for clamping.
  int get maxRow;

  /// Maximum column count (exclusive) for clamping.
  int get maxColumn;

  /// The worksheet data source for cell operations.
  WorksheetData get worksheetData;

  /// The clipboard handler for copy/cut/paste.
  ClipboardHandler get clipboardHandler;

  /// Whether the worksheet is in read-only mode.
  bool get readOnly;

  /// Callback to enter edit mode on a cell, or null if editing is disabled.
  void Function(CellCoordinate)? get onEditCell;

  /// Scrolls to ensure the currently focused cell is visible.
  void ensureSelectionVisible();

  /// Invalidates tiles and triggers a rebuild of the widget.
  void invalidateAndRebuild();
}
