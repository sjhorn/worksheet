import 'dart:ui';

import '../../core/core.dart';
import '../hit_testing/hit_test_result.dart';
import '../hit_testing/hit_tester.dart';

/// Callback for when a move drag completes.
typedef OnMoveComplete =
    void Function(CellRange source, CellCoordinate destination);

/// Callback for when the move preview range changes during drag.
typedef OnMovePreviewUpdate = void Function(CellRange previewRange);

/// Callback for when a move drag is cancelled.
typedef OnMoveCancel = void Function();

/// Handles drag-to-move and long-press-to-move operations.
///
/// Encapsulates the move-specific state (source range, grab offset, last
/// destination) and bounds-clamping logic. Created and owned by
/// [WorksheetGestureHandler].
class MoveDragHandler {
  /// The hit tester for coordinate resolution.
  final WorksheetHitTester hitTester;

  /// Callback when the move preview range changes during drag.
  final OnMovePreviewUpdate? onMovePreviewUpdate;

  /// Callback when a move drag completes.
  final OnMoveComplete? onMoveComplete;

  /// Callback when a move drag is cancelled.
  final OnMoveCancel? onMoveCancel;

  // Move-specific state
  bool _isMoving = false;
  CellRange? _moveSourceRange;
  CellCoordinate? _lastMoveDestination;
  CellCoordinate _moveGrabOffset = const CellCoordinate(0, 0);

  /// Creates a move drag handler.
  MoveDragHandler({
    required this.hitTester,
    this.onMovePreviewUpdate,
    this.onMoveComplete,
    this.onMoveCancel,
  });

  /// Whether a move drag is in progress.
  bool get isMoving => _isMoving;

	/// Whether move operations are enabled by callbacks wiring.
	bool get isEnabled =>
			onMovePreviewUpdate != null ||
			onMoveComplete != null ||
			onMoveCancel != null;

  /// Starts a move drag from a selection border hit.
  ///
  /// [hit] is the hit test result on the selection border.
  /// [selectionRange] is the current selection being moved.
  void start(WorksheetHitTestResult hit, CellRange? selectionRange) {
    _isMoving = true;
    _moveSourceRange = selectionRange;
    if (hit.cell != null && _moveSourceRange != null) {
      final src = _moveSourceRange!;
      _moveGrabOffset = CellCoordinate(
        (hit.cell!.row - src.startRow).clamp(0, src.endRow - src.startRow),
        (hit.cell!.column - src.startColumn).clamp(
          0,
          src.endColumn - src.startColumn,
        ),
      );
    }
  }

  /// Starts a move drag from a long-press gesture (mobile).
  ///
  /// [cell] is the cell under the long-press point.
  /// [selectionRange] is the current selection being moved.
  void longPressStart(CellCoordinate cell, CellRange selectionRange) {
    _isMoving = true;
    _moveSourceRange = selectionRange;
    _moveGrabOffset = CellCoordinate(
      cell.row - selectionRange.startRow,
      cell.column - selectionRange.startColumn,
    );
  }

  /// Updates the move drag with a new pointer position.
  void update(Offset position, Offset scrollOffset, double zoom) {
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

    // Apply grab offset so the cursor stays over the same relative position
    final sourceHeight = source.endRow - source.startRow;
    final sourceWidth = source.endColumn - source.startColumn;
    final maxRow = hitTester.layoutSolver.rowCount - 1 - sourceHeight;
    final maxCol = hitTester.layoutSolver.columnCount - 1 - sourceWidth;
    final destRow = (cell.row - _moveGrabOffset.row).clamp(0, maxRow);
    final destCol = (cell.column - _moveGrabOffset.column).clamp(0, maxCol);
    _lastMoveDestination = CellCoordinate(destRow, destCol);

    // Compute preview range: source dimensions translated to drop position
    final previewRange = CellRange(
      destRow,
      destCol,
      destRow + sourceHeight,
      destCol + sourceWidth,
    );

    onMovePreviewUpdate?.call(previewRange);
  }

  /// Ends the move drag, completing or cancelling the operation.
  void end() {
    if (_moveSourceRange != null &&
        _lastMoveDestination != null &&
        _lastMoveDestination != _moveSourceRange!.topLeft) {
      onMoveComplete?.call(_moveSourceRange!, _lastMoveDestination!);
    } else {
      onMoveCancel?.call();
    }
    reset();
  }

  /// Cancels the move drag without completing.
  void cancel() {
    onMoveCancel?.call();
    reset();
  }

  /// Resets all move-specific state.
  void reset() {
    _isMoving = false;
    _moveSourceRange = null;
    _lastMoveDestination = null;
    _moveGrabOffset = const CellCoordinate(0, 0);
  }
}
