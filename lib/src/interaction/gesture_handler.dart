import 'dart:ui';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import 'controllers/selection_controller.dart';
import 'hit_testing/hit_test_result.dart';
import 'hit_testing/hit_tester.dart';

/// Callback for when a cell should be edited.
typedef OnEditCell = void Function(CellCoordinate cell);

/// Callback for when a row is being resized.
typedef OnResizeRow = void Function(int row, double delta);

/// Callback for when a column is being resized.
typedef OnResizeColumn = void Function(int column, double delta);

/// Callback for when row resize ends.
typedef OnResizeRowEnd = void Function(int row);

/// Callback for when column resize ends.
typedef OnResizeColumnEnd = void Function(int column);

/// Handles gesture events for worksheet interaction.
///
/// Coordinates between hit testing and selection/resize operations.
/// Call the appropriate methods from your gesture detector:
/// - [onTapDown] / [onTapUp] for taps
/// - [onDoubleTap] for double taps (edit mode)
/// - [onDragStart] / [onDragUpdate] / [onDragEnd] for drags
class WorksheetGestureHandler {
  /// The hit tester for coordinate resolution.
  final WorksheetHitTester hitTester;

  /// The selection controller.
  final SelectionController selectionController;

  /// Callback when a cell should enter edit mode.
  final OnEditCell? onEditCell;

  /// Callback when a row is being resized.
  final OnResizeRow? onResizeRow;

  /// Callback when a column is being resized.
  final OnResizeColumn? onResizeColumn;

  /// Callback when row resize ends.
  final OnResizeRowEnd? onResizeRowEnd;

  /// Callback when column resize ends.
  final OnResizeColumnEnd? onResizeColumnEnd;

  // Internal state
  WorksheetHitTestResult? _dragStartHit;
  Offset? _dragStartPosition;
  Offset? _lastDragPosition;
  bool _isResizing = false;
  bool _isSelectingRange = false;

  /// Creates a gesture handler.
  WorksheetGestureHandler({
    required this.hitTester,
    required this.selectionController,
    this.onEditCell,
    this.onResizeRow,
    this.onResizeColumn,
    this.onResizeRowEnd,
    this.onResizeColumnEnd,
  });

  /// Whether a resize operation is in progress.
  bool get isResizing => _isResizing;

  /// Whether a range selection drag is in progress.
  bool get isSelectingRange => _isSelectingRange;

  /// Handles tap down event.
  void onTapDown({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (hit.isCell) {
      selectionController.selectCell(hit.cell!);
    } else if (hit.isRowHeader) {
      selectionController.selectRow(
        hit.headerIndex!,
        columnCount: hitTester.layoutSolver.columnCount,
      );
    } else if (hit.isColumnHeader) {
      selectionController.selectColumn(
        hit.headerIndex!,
        rowCount: hitTester.layoutSolver.rowCount,
      );
    }
  }

  /// Handles tap up event.
  void onTapUp({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    // Tap up is currently a no-op, but can be extended for
    // context menu or other tap completion behaviors
  }

  /// Handles double tap event.
  void onDoubleTap({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (hit.isCell && onEditCell != null) {
      onEditCell!(hit.cell!);
    }
  }

  /// Handles drag start event.
  void onDragStart({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    _dragStartHit = hit;
    _dragStartPosition = position;
    _lastDragPosition = position;

    if (hit.isResizeHandle) {
      _isResizing = true;
    } else if (hit.isCell) {
      _isSelectingRange = true;
      selectionController.selectCell(hit.cell!);
    } else if (hit.isRowHeader) {
      _isSelectingRange = true;
      selectionController.selectRow(
        hit.headerIndex!,
        columnCount: hitTester.layoutSolver.columnCount,
      );
    } else if (hit.isColumnHeader) {
      _isSelectingRange = true;
      selectionController.selectColumn(
        hit.headerIndex!,
        rowCount: hitTester.layoutSolver.rowCount,
      );
    }
  }

  /// Handles drag update event.
  void onDragUpdate({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    if (_dragStartHit == null || _dragStartPosition == null) return;

    if (_isResizing) {
      _handleResizeUpdate(position, zoom);
    } else if (_isSelectingRange) {
      _handleSelectionUpdate(position, scrollOffset, zoom);
    }
  }

  /// Handles drag end event.
  void onDragEnd() {
    // Call resize end callbacks if we were resizing
    if (_isResizing && _dragStartHit != null) {
      if (_dragStartHit!.type == HitTestType.rowResizeHandle) {
        onResizeRowEnd?.call(_dragStartHit!.headerIndex!);
      } else if (_dragStartHit!.type == HitTestType.columnResizeHandle) {
        onResizeColumnEnd?.call(_dragStartHit!.headerIndex!);
      }
    }

    _dragStartHit = null;
    _dragStartPosition = null;
    _lastDragPosition = null;
    _isResizing = false;
    _isSelectingRange = false;
  }

  void _handleResizeUpdate(Offset position, double zoom) {
    if (_dragStartHit == null || _lastDragPosition == null) return;

    // Calculate incremental delta from last position
    final delta = position - _lastDragPosition!;
    _lastDragPosition = position;

    if (_dragStartHit!.type == HitTestType.rowResizeHandle) {
      // Vertical resize - use y delta, convert from screen to worksheet
      final worksheetDelta = delta.dy / zoom;
      onResizeRow?.call(_dragStartHit!.headerIndex!, worksheetDelta);
    } else if (_dragStartHit!.type == HitTestType.columnResizeHandle) {
      // Horizontal resize - use x delta, convert from screen to worksheet
      final worksheetDelta = delta.dx / zoom;
      onResizeColumn?.call(_dragStartHit!.headerIndex!, worksheetDelta);
    }
  }

  void _handleSelectionUpdate(
    Offset position,
    Offset scrollOffset,
    double zoom,
  ) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (hit.isCell) {
      selectionController.extendSelection(hit.cell!);
    } else if (hit.isRowHeader && _dragStartHit?.isRowHeader == true) {
      // Extending row selection
      final startRow = _dragStartHit!.headerIndex!;
      final endRow = hit.headerIndex!;
      final minRow = startRow < endRow ? startRow : endRow;
      final maxRow = startRow > endRow ? startRow : endRow;

      selectionController.selectRange(
        CellRange(
          minRow,
          0,
          maxRow,
          hitTester.layoutSolver.columnCount - 1,
        ),
      );
    } else if (hit.isColumnHeader && _dragStartHit?.isColumnHeader == true) {
      // Extending column selection
      final startCol = _dragStartHit!.headerIndex!;
      final endCol = hit.headerIndex!;
      final minCol = startCol < endCol ? startCol : endCol;
      final maxCol = startCol > endCol ? startCol : endCol;

      selectionController.selectRange(
        CellRange(
          0,
          minCol,
          hitTester.layoutSolver.rowCount - 1,
          maxCol,
        ),
      );
    }
  }
}
