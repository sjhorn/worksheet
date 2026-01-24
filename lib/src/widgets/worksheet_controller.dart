import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import '../interaction/controllers/selection_controller.dart';
import '../interaction/controllers/zoom_controller.dart';

/// Controller for programmatic interaction with a worksheet.
///
/// Provides methods to:
/// - Scroll to specific cells
/// - Select cells or ranges
/// - Get/set zoom level
/// - Access current visible range and selection
///
/// The controller should be passed to [WorksheetWidget] and disposed
/// when no longer needed.
class WorksheetController extends ChangeNotifier {
  /// The selection controller.
  final SelectionController selectionController;

  /// The zoom controller.
  final ZoomController zoomController;

  /// The horizontal scroll controller.
  final ScrollController horizontalScrollController;

  /// The vertical scroll controller.
  final ScrollController verticalScrollController;

  /// Creates a worksheet controller.
  ///
  /// If controllers are not provided, default instances are created.
  WorksheetController({
    SelectionController? selectionController,
    ZoomController? zoomController,
    ScrollController? horizontalScrollController,
    ScrollController? verticalScrollController,
  })  : selectionController = selectionController ?? SelectionController(),
        zoomController = zoomController ?? ZoomController(),
        horizontalScrollController =
            horizontalScrollController ?? ScrollController(),
        verticalScrollController =
            verticalScrollController ?? ScrollController() {
    this.selectionController.addListener(_onControllerChanged);
    this.zoomController.addListener(_onControllerChanged);
    this.horizontalScrollController.addListener(_onControllerChanged);
    this.verticalScrollController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    notifyListeners();
  }

  // Selection methods

  /// The currently selected range, or null if no selection.
  CellRange? get selectedRange => selectionController.selectedRange;

  /// The focus cell (active cell), or null if no selection.
  CellCoordinate? get focusCell => selectionController.focus;

  /// Whether there is an active selection.
  bool get hasSelection => selectionController.hasSelection;

  /// The current selection mode.
  SelectionMode get selectionMode => selectionController.mode;

  /// Selects a single cell.
  void selectCell(CellCoordinate cell) {
    selectionController.selectCell(cell);
  }

  /// Selects a range of cells.
  void selectRange(CellRange range) {
    selectionController.selectRange(range);
  }

  /// Selects an entire row.
  void selectRow(int row, {required int columnCount}) {
    selectionController.selectRow(row, columnCount: columnCount);
  }

  /// Selects an entire column.
  void selectColumn(int column, {required int rowCount}) {
    selectionController.selectColumn(column, rowCount: rowCount);
  }

  /// Clears the selection.
  void clearSelection() {
    selectionController.clear();
  }

  /// Moves the focus by the given delta.
  void moveFocus({
    required int rowDelta,
    required int columnDelta,
    bool extend = false,
    int maxRow = 999999,
    int maxColumn = 999999,
  }) {
    selectionController.moveFocus(
      rowDelta: rowDelta,
      columnDelta: columnDelta,
      extend: extend,
      maxRow: maxRow,
      maxColumn: maxColumn,
    );
  }

  // Zoom methods

  /// The current zoom level (1.0 = 100%).
  double get zoom => zoomController.value;

  /// Sets the zoom level.
  void setZoom(double value) {
    zoomController.value = value;
  }

  /// Zooms in by the controller's zoom step.
  void zoomIn() {
    zoomController.zoomIn();
  }

  /// Zooms out by the controller's zoom step.
  void zoomOut() {
    zoomController.zoomOut();
  }

  /// Resets zoom to 100%.
  void resetZoom() {
    zoomController.reset();
  }

  // Scroll methods

  /// The current horizontal scroll offset.
  double get scrollX =>
      horizontalScrollController.hasClients ? horizontalScrollController.offset : 0.0;

  /// The current vertical scroll offset.
  double get scrollY =>
      verticalScrollController.hasClients ? verticalScrollController.offset : 0.0;

  /// Scrolls to show the given cell.
  ///
  /// [rowHeight] and [columnWidth] are used to calculate the cell position.
  /// [viewportSize] is the size of the visible area.
  ///
  /// Set [animate] to true for smooth scrolling.
  void scrollToCell(
    CellCoordinate cell, {
    required double Function(int row) getRowTop,
    required double Function(int column) getColumnLeft,
    required double Function(int row) getRowHeight,
    required double Function(int column) getColumnWidth,
    required Size viewportSize,
    required double headerWidth,
    required double headerHeight,
    bool animate = false,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
  }) {
    if (!horizontalScrollController.hasClients ||
        !verticalScrollController.hasClients) {
      return;
    }

    final cellLeft = getColumnLeft(cell.column) * zoom;
    final cellTop = getRowTop(cell.row) * zoom;
    final cellWidth = getColumnWidth(cell.column) * zoom;
    final cellHeight = getRowHeight(cell.row) * zoom;

    final visibleWidth = viewportSize.width - headerWidth;
    final visibleHeight = viewportSize.height - headerHeight;

    // Calculate target scroll positions
    double? targetX;
    double? targetY;

    // Horizontal scrolling
    if (cellLeft < scrollX) {
      // Cell is to the left of the viewport
      targetX = cellLeft;
    } else if (cellLeft + cellWidth > scrollX + visibleWidth) {
      // Cell is to the right of the viewport
      targetX = cellLeft + cellWidth - visibleWidth;
    }

    // Vertical scrolling
    if (cellTop < scrollY) {
      // Cell is above the viewport
      targetY = cellTop;
    } else if (cellTop + cellHeight > scrollY + visibleHeight) {
      // Cell is below the viewport
      targetY = cellTop + cellHeight - visibleHeight;
    }

    // Perform scrolling
    if (animate) {
      if (targetX != null) {
        horizontalScrollController.animateTo(
          targetX,
          duration: duration,
          curve: curve,
        );
      }
      if (targetY != null) {
        verticalScrollController.animateTo(
          targetY,
          duration: duration,
          curve: curve,
        );
      }
    } else {
      if (targetX != null) {
        horizontalScrollController.jumpTo(targetX);
      }
      if (targetY != null) {
        verticalScrollController.jumpTo(targetY);
      }
    }
  }

  /// Scrolls to the given offset.
  void scrollTo({
    double? x,
    double? y,
    bool animate = false,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
  }) {
    if (animate) {
      if (x != null && horizontalScrollController.hasClients) {
        horizontalScrollController.animateTo(x, duration: duration, curve: curve);
      }
      if (y != null && verticalScrollController.hasClients) {
        verticalScrollController.animateTo(y, duration: duration, curve: curve);
      }
    } else {
      if (x != null && horizontalScrollController.hasClients) {
        horizontalScrollController.jumpTo(x);
      }
      if (y != null && verticalScrollController.hasClients) {
        verticalScrollController.jumpTo(y);
      }
    }
  }

  @override
  void dispose() {
    selectionController.removeListener(_onControllerChanged);
    zoomController.removeListener(_onControllerChanged);
    horizontalScrollController.removeListener(_onControllerChanged);
    verticalScrollController.removeListener(_onControllerChanged);

    // Dispose controllers that were created internally
    selectionController.dispose();
    zoomController.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();

    super.dispose();
  }
}
