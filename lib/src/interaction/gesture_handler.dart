import 'dart:math' as math;
import 'dart:ui';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import 'controllers/selection_controller.dart';
import 'hit_testing/hit_test_result.dart';
import 'hit_testing/hit_tester.dart';

/// The axis along which a fill drag is constrained.
enum FillAxis { vertical, horizontal }

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

/// Callback for when the fill preview range changes during drag.
typedef OnFillPreviewUpdate = void Function(CellRange previewRange);

/// Callback for when a fill drag completes.
typedef OnFillComplete = void Function(
    CellRange sourceRange, CellCoordinate destination);

/// Callback for when a fill drag is cancelled.
typedef OnFillCancel = void Function();

/// Callback for when a move drag completes.
typedef OnMoveComplete = void Function(
    CellRange source, CellCoordinate destination);

/// Callback for when the move preview range changes during drag.
typedef OnMovePreviewUpdate = void Function(CellRange previewRange);

/// Callback for when a move drag is cancelled.
typedef OnMoveCancel = void Function();

/// Callback for auto-fitting a column to its content width.
typedef OnAutoFitColumn = void Function(int column);

/// Callback for auto-fitting a row to its content height.
typedef OnAutoFitRow = void Function(int row);

/// Callback for jumping to a data edge (Ctrl+Arrow behavior).
///
/// [from] is the starting cell (focus cell), [rowDelta] and [colDelta]
/// indicate the direction (-1/0/+1). The widget is responsible for
/// performing the actual data-edge scan since it has access to the data.
typedef OnJumpToEdge = void Function(
    CellCoordinate from, int rowDelta, int colDelta);

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

  /// Callback when the fill preview range changes during drag.
  final OnFillPreviewUpdate? onFillPreviewUpdate;

  /// Callback when a fill drag completes.
  final OnFillComplete? onFillComplete;

  /// Callback when a fill drag is cancelled.
  final OnFillCancel? onFillCancel;

  /// Callback when a move drag completes.
  final OnMoveComplete? onMoveComplete;

  /// Callback when the move preview range changes during drag.
  final OnMovePreviewUpdate? onMovePreviewUpdate;

  /// Callback when a move drag is cancelled.
  final OnMoveCancel? onMoveCancel;

  /// Callback for auto-fitting a column to its content width.
  final OnAutoFitColumn? onAutoFitColumn;

  /// Callback for auto-fitting a row to its content height.
  final OnAutoFitRow? onAutoFitRow;

  /// Callback for jumping to a data edge (Ctrl+Arrow behavior).
  final OnJumpToEdge? onJumpToEdge;

  // Internal state
  WorksheetHitTestResult? _dragStartHit;
  Offset? _dragStartPosition;
  Offset? _lastDragPosition;
  bool _isResizing = false;
  bool _isSelectingRange = false;
  bool _isFilling = false;
  bool _isMoving = false;
  bool _isHandleDragging = false;
  CellRange? _fillSourceRange;
  CellCoordinate? _lastFillDestination;
  FillAxis? _fillAxis;
  CellRange? _moveSourceRange;
  CellCoordinate? _lastMoveDestination;

  /// Creates a gesture handler.
  WorksheetGestureHandler({
    required this.hitTester,
    required this.selectionController,
    this.onEditCell,
    this.onResizeRow,
    this.onResizeColumn,
    this.onResizeRowEnd,
    this.onResizeColumnEnd,
    this.onFillPreviewUpdate,
    this.onFillComplete,
    this.onFillCancel,
    this.onMoveComplete,
    this.onMovePreviewUpdate,
    this.onMoveCancel,
    this.onAutoFitColumn,
    this.onAutoFitRow,
    this.onJumpToEdge,
  });

  /// Whether a resize operation is in progress.
  bool get isResizing => _isResizing;

  /// Whether a range selection drag is in progress.
  bool get isSelectingRange => _isSelectingRange;

  /// Whether a fill handle drag is in progress.
  bool get isFilling => _isFilling;

  /// Whether a move drag is in progress.
  bool get isMoving => _isMoving;

  /// Whether a selection handle drag is in progress.
  bool get isHandleDragging => _isHandleDragging;

  /// Handles tap down event.
  void onTapDown({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
    bool isShiftPressed = false,
    double selectionHandleSize = 0,
    double resizeHandleTolerance = 4.0,
    double selectionBorderTolerance = 4.0,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
      selectionHandleSize: selectionHandleSize,
      resizeHandleTolerance: resizeHandleTolerance,
      selectionBorderTolerance: selectionBorderTolerance,
    );

    // Don't change selection when tapping fill, resize, or selection handles —
    // those are handled by onDragStart.
    if (hit.isFillHandle || hit.isResizeHandle || hit.isSelectionBorder ||
        hit.isSelectionHandle) {
      return;
    }

    if (hit.isCell) {
      if (isShiftPressed && selectionController.hasSelection) {
        selectionController.extendSelection(hit.cell!);
      } else {
        selectionController.selectCell(hit.cell!);
      }
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
  ///
  /// Routes to different behaviors based on hit zone:
  /// - Resize handle: auto-fit column/row
  /// - Selection border: jump to data edge
  /// - Cell: enter edit mode
  void onDoubleTap({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    // Hit test with selectionRange to detect resize handles and selection border
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
    );

    // Auto-fit on double-click resize handle
    if (hit.type == HitTestType.columnResizeHandle && onAutoFitColumn != null) {
      onAutoFitColumn!(hit.headerIndex!);
      // Reset drag state so the subsequent onDragEnd (from the second
      // pointer-up of the double-click) doesn't fire a spurious
      // onResizeColumnEnd that would apply the auto-fitted width to all
      // selected columns.
      _resetDragState();
      return;
    }
    if (hit.type == HitTestType.rowResizeHandle && onAutoFitRow != null) {
      onAutoFitRow!(hit.headerIndex!);
      _resetDragState();
      return;
    }

    // Jump to data edge on double-click selection border
    if (hit.isSelectionBorder && onJumpToEdge != null) {
      final direction = _computeJumpDirection(position, scrollOffset, zoom);
      if (direction != null) {
        final focus = selectionController.focus ??
            selectionController.selectedRange?.topLeft;
        if (focus != null) {
          onJumpToEdge!(focus, direction.$1, direction.$2);
        }
      }
      _resetDragState();
      return;
    }

    if (hit.isCell && onEditCell != null) {
      onEditCell!(hit.cell!);
    }
  }

  /// Handles drag start event.
  void onDragStart({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
    bool isShiftPressed = false,
    double selectionHandleSize = 0,
    double resizeHandleTolerance = 4.0,
    double selectionBorderTolerance = 4.0,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
      selectionHandleSize: selectionHandleSize,
      resizeHandleTolerance: resizeHandleTolerance,
      selectionBorderTolerance: selectionBorderTolerance,
    );

    _dragStartHit = hit;
    _dragStartPosition = position;
    _lastDragPosition = position;

    if (hit.isSelectionHandle) {
      _isHandleDragging = true;
      _isSelectingRange = true;
      // Determine which handle was grabbed by comparing hit coordinate
      // to selection corners and anchor at the OPPOSITE corner.
      final sel = selectionController.selectedRange;
      if (sel != null && hit.cell != null) {
        final isTopLeft = hit.cell!.row == sel.startRow &&
            hit.cell!.column == sel.startColumn;
        if (isTopLeft) {
          // Anchor at bottom-right
          selectionController.selectCell(
            CellCoordinate(sel.endRow, sel.endColumn),
          );
        } else {
          // Anchor at top-left
          selectionController.selectCell(
            CellCoordinate(sel.startRow, sel.startColumn),
          );
        }
      }
    } else if (hit.isFillHandle) {
      _isFilling = true;
      _fillSourceRange = selectionController.selectedRange;
      _lastFillDestination = null;
      _fillAxis = null;
    } else if (hit.isSelectionBorder) {
      _isMoving = true;
      _moveSourceRange = selectionController.selectedRange;
    } else if (hit.isResizeHandle) {
      _isResizing = true;
    } else if (hit.isCell) {
      _isSelectingRange = true;
      // Don't reset selection when shift is held — onTapDown already
      // called extendSelection() and we just need the drag state.
      if (!isShiftPressed) {
        selectionController.selectCell(hit.cell!);
      }
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

    if (_isFilling) {
      _handleFillUpdate(position, scrollOffset, zoom);
    } else if (_isMoving) {
      _handleMoveUpdate(position, scrollOffset, zoom);
    } else if (_isResizing) {
      _handleResizeUpdate(position, zoom);
    } else if (_isSelectingRange) {
      _handleSelectionUpdate(position, scrollOffset, zoom);
    }
  }

  /// Handles drag end event.
  void onDragEnd() {
    // Handle fill drag completion
    if (_isFilling) {
      if (_lastFillDestination != null && _fillSourceRange != null) {
        onFillComplete?.call(_fillSourceRange!, _lastFillDestination!);
      } else {
        onFillCancel?.call();
      }
      _resetDragState();
      return;
    }

    // Handle move drag completion
    if (_isMoving) {
      if (_moveSourceRange != null && _lastMoveDestination != null) {
        onMoveComplete?.call(_moveSourceRange!, _lastMoveDestination!);
      } else {
        onMoveCancel?.call();
      }
      _resetDragState();
      return;
    }

    // Call resize end callbacks if we were resizing
    if (_isResizing && _dragStartHit != null) {
      if (_dragStartHit!.type == HitTestType.rowResizeHandle) {
        onResizeRowEnd?.call(_dragStartHit!.headerIndex!);
      } else if (_dragStartHit!.type == HitTestType.columnResizeHandle) {
        onResizeColumnEnd?.call(_dragStartHit!.headerIndex!);
      }
    }

    _resetDragState();
  }

  /// Resets all drag-related state flags and positions.
  void _resetDragState() {
    _dragStartHit = null;
    _dragStartPosition = null;
    _lastDragPosition = null;
    _isResizing = false;
    _isSelectingRange = false;
    _isMoving = false;
    _isHandleDragging = false;
    _moveSourceRange = null;
    _lastMoveDestination = null;
    _isFilling = false;
    _fillSourceRange = null;
    _lastFillDestination = null;
    _fillAxis = null;
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

  void _handleFillUpdate(
    Offset position,
    Offset scrollOffset,
    double zoom,
  ) {
    if (_fillSourceRange == null) return;

    // Hit test without selectionRange to get the cell under the cursor
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (!hit.isCell || hit.cell == null) return;
    final cell = hit.cell!;
    final source = _fillSourceRange!;

    // Single-cell source: no series to disambiguate, expand freely
    final isSingleCell = source.startRow == source.endRow &&
        source.startColumn == source.endColumn;
    if (isSingleCell) {
      _lastFillDestination = cell;
      final previewRange = source.expand(cell);
      onFillPreviewUpdate?.call(previewRange);
      return;
    }

    // If cursor is still inside the source range and axis not yet locked, skip
    if (source.contains(cell) && _fillAxis == null) return;

    // Lock axis on first cell outside source range
    if (_fillAxis == null) {
      final outsideRow =
          cell.row < source.startRow || cell.row > source.endRow;
      final outsideCol =
          cell.column < source.startColumn || cell.column > source.endColumn;

      if (outsideRow && outsideCol) {
        // Diagonal — use pixel displacement to break tie
        final dx = (position.dx - _dragStartPosition!.dx).abs();
        final dy = (position.dy - _dragStartPosition!.dy).abs();
        _fillAxis = dy >= dx ? FillAxis.vertical : FillAxis.horizontal;
      } else if (outsideRow) {
        _fillAxis = FillAxis.vertical;
      } else if (outsideCol) {
        _fillAxis = FillAxis.horizontal;
      } else {
        return; // Still inside source (shouldn't reach here)
      }
    }

    // Constrain destination to the locked axis
    final CellCoordinate constrained;
    if (_fillAxis == FillAxis.vertical) {
      constrained = CellCoordinate(cell.row, source.endColumn);
    } else {
      constrained = CellCoordinate(source.endRow, cell.column);
    }

    _lastFillDestination = constrained;

    // Build the preview range: source expanded along the locked axis only
    final CellRange previewRange;
    if (_fillAxis == FillAxis.vertical) {
      previewRange = CellRange(
        math.min(source.startRow, constrained.row),
        source.startColumn,
        math.max(source.endRow, constrained.row),
        source.endColumn,
      );
    } else {
      previewRange = CellRange(
        source.startRow,
        math.min(source.startColumn, constrained.column),
        source.endRow,
        math.max(source.endColumn, constrained.column),
      );
    }

    onFillPreviewUpdate?.call(previewRange);
  }

  void _handleSelectionUpdate(
    Offset position,
    Offset scrollOffset,
    double zoom,
  ) {
    final worksheetPos = hitTester.screenToWorksheet(
      screenPosition: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    // Row header drag: always extend as row selection regardless of cursor position
    if (_dragStartHit?.isRowHeader == true) {
      final endRow = hitTester.layoutSolver.getRowAt(worksheetPos.dy);
      if (endRow < 0) return;

      final startRow = _dragStartHit!.headerIndex!;
      final minRow = startRow < endRow ? startRow : endRow;
      final maxRow = startRow > endRow ? startRow : endRow;

      selectionController.selectRange(
        CellRange(minRow, 0, maxRow, hitTester.layoutSolver.columnCount - 1),
      );
      return;
    }

    // Column header drag: always extend as column selection
    if (_dragStartHit?.isColumnHeader == true) {
      final endCol = hitTester.layoutSolver.getColumnAt(worksheetPos.dx);
      if (endCol < 0) return;

      final startCol = _dragStartHit!.headerIndex!;
      final minCol = startCol < endCol ? startCol : endCol;
      final maxCol = startCol > endCol ? startCol : endCol;

      selectionController.selectRange(
        CellRange(0, minCol, hitTester.layoutSolver.rowCount - 1, maxCol),
      );
      return;
    }

    // Cell drag: hit test and extend to cell
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
    if (hit.isCell) {
      selectionController.extendSelection(hit.cell!);
    }
  }

  void _handleMoveUpdate(
    Offset position,
    Offset scrollOffset,
    double zoom,
  ) {
    if (_moveSourceRange == null) return;

    // Hit test without selectionRange to get the cell under the cursor
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (!hit.isCell || hit.cell == null) return;
    final cell = hit.cell!;
    final source = _moveSourceRange!;

    _lastMoveDestination = cell;

    // Compute preview range: source dimensions translated to drop position
    final previewRange = CellRange(
      cell.row,
      cell.column,
      cell.row + source.endRow - source.startRow,
      cell.column + source.endColumn - source.startColumn,
    );

    onMovePreviewUpdate?.call(previewRange);
  }

  /// Handles long-press start for mobile move gesture.
  ///
  /// If the long-press is on a cell within the current selection,
  /// starts a move drag.
  void onLongPressStart({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
    );

    if (!hit.isCell && !hit.isSelectionBorder) return;

    final selection = selectionController.selectedRange;
    if (selection == null) return;

    // Only start move if the long-press is within the selection
    final cell = hit.cell;
    if (cell == null || !selection.contains(cell)) return;

    _isMoving = true;
    _moveSourceRange = selection;
    _dragStartPosition = position;
    _lastDragPosition = position;
  }

  /// Handles long-press move update for mobile move gesture.
  void onLongPressMoveUpdate({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    if (!_isMoving) return;
    _handleMoveUpdate(position, scrollOffset, zoom);
  }

  /// Handles long-press end for mobile move gesture.
  void onLongPressEnd() {
    if (!_isMoving) return;
    if (_moveSourceRange != null && _lastMoveDestination != null) {
      onMoveComplete?.call(_moveSourceRange!, _lastMoveDestination!);
    } else {
      onMoveCancel?.call();
    }
    _resetDragState();
  }

  /// Computes the jump direction for a double-click on a selection border.
  ///
  /// Determines which edge the pointer is closest to (top/bottom/left/right)
  /// and returns (rowDelta, colDelta) for that direction.
  (int, int)? _computeJumpDirection(
    Offset position,
    Offset scrollOffset,
    double zoom,
  ) {
    final selection = selectionController.selectedRange;
    if (selection == null) return null;

    // Get selection bounds in screen coordinates
    final selTop = hitTester.layoutSolver.getRowTop(selection.startRow);
    final selBottom = hitTester.layoutSolver.getRowEnd(selection.endRow);
    final selLeft = hitTester.layoutSolver.getColumnLeft(selection.startColumn);
    final selRight = hitTester.layoutSolver.getColumnEnd(selection.endColumn);

    final screenTopLeft = hitTester.worksheetToScreen(
      worksheetPosition: Offset(selLeft, selTop),
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
    final screenBottomRight = hitTester.worksheetToScreen(
      worksheetPosition: Offset(selRight, selBottom),
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    // Find which edge is closest
    final distTop = (position.dy - screenTopLeft.dy).abs();
    final distBottom = (position.dy - screenBottomRight.dy).abs();
    final distLeft = (position.dx - screenTopLeft.dx).abs();
    final distRight = (position.dx - screenBottomRight.dx).abs();

    final minDist = [distTop, distBottom, distLeft, distRight]
        .reduce((a, b) => a < b ? a : b);

    if (minDist == distTop) {
      return (-1, 0);
    } else if (minDist == distBottom) {
      return (1, 0);
    } else if (minDist == distLeft) {
      return (0, -1);
    } else {
      return (0, 1);
    }
  }
}
