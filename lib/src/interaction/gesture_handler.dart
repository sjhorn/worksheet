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

  // Internal state
  WorksheetHitTestResult? _dragStartHit;
  Offset? _dragStartPosition;
  Offset? _lastDragPosition;
  bool _isResizing = false;
  bool _isSelectingRange = false;
  bool _isFilling = false;
  CellRange? _fillSourceRange;
  CellCoordinate? _lastFillDestination;
  FillAxis? _fillAxis;

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
  });

  /// Whether a resize operation is in progress.
  bool get isResizing => _isResizing;

  /// Whether a range selection drag is in progress.
  bool get isSelectingRange => _isSelectingRange;

  /// Whether a fill handle drag is in progress.
  bool get isFilling => _isFilling;

  /// Handles tap down event.
  void onTapDown({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
    bool isShiftPressed = false,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
    );

    // Don't change selection when tapping fill or resize handles —
    // those are handled by onDragStart.
    if (hit.isFillHandle || hit.isResizeHandle) return;

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
    bool isShiftPressed = false,
  }) {
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
      selectionRange: selectionController.selectedRange,
    );

    _dragStartHit = hit;
    _dragStartPosition = position;
    _lastDragPosition = position;

    if (hit.isFillHandle) {
      _isFilling = true;
      _fillSourceRange = selectionController.selectedRange;
      _lastFillDestination = null;
      _fillAxis = null;
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
      _isFilling = false;
      _fillSourceRange = null;
      _lastFillDestination = null;
      _fillAxis = null;
      _dragStartHit = null;
      _dragStartPosition = null;
      _lastDragPosition = null;
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
}
