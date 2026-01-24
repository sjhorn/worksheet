import 'dart:math' as math;
import 'dart:ui';

import '../models/cell_range.dart';
import 'layout_solver.dart';

/// Calculates which cells are visible within a viewport.
///
/// Uses a [LayoutSolver] to convert between pixel positions and cell
/// coordinates, determining which cells intersect with a given viewport rect.
class VisibleRangeCalculator {
  /// The layout solver for position calculations.
  final LayoutSolver layoutSolver;

  /// Creates a visible range calculator with the given [layoutSolver].
  VisibleRangeCalculator({required this.layoutSolver});

  /// Returns the range of cells visible within the [viewport].
  ///
  /// The returned range includes all cells that are at least partially
  /// visible within the viewport bounds.
  CellRange getVisibleRange({required Rect viewport}) {
    final rowRange = layoutSolver.getVisibleRows(viewport.top, viewport.height);
    final colRange = layoutSolver.getVisibleColumns(viewport.left, viewport.width);

    return CellRange(
      rowRange.startIndex,
      colRange.startIndex,
      rowRange.endIndex,
      colRange.endIndex,
    );
  }

  /// Returns the visible range with additional padding cells.
  ///
  /// Useful for prefetching cells that are about to scroll into view.
  /// The [rowPadding] and [columnPadding] specify how many extra cells
  /// to include beyond the visible area.
  CellRange getVisibleRangeWithPadding({
    required Rect viewport,
    int rowPadding = 1,
    int columnPadding = 1,
  }) {
    final baseRange = getVisibleRange(viewport: viewport);

    final startRow = math.max(0, baseRange.startRow - rowPadding);
    final endRow = math.min(layoutSolver.rowCount - 1, baseRange.endRow + rowPadding);
    final startColumn = math.max(0, baseRange.startColumn - columnPadding);
    final endColumn = math.min(layoutSolver.columnCount - 1, baseRange.endColumn + columnPadding);

    return CellRange(startRow, startColumn, endRow, endColumn);
  }

  /// Returns true if [range] intersects with the [viewport].
  bool isRangeVisible(CellRange range, Rect viewport) {
    final visibleRange = getVisibleRange(viewport: viewport);
    return range.intersects(visibleRange);
  }

  /// Returns true if the cell at ([row], [column]) is visible in [viewport].
  bool isCellVisible(int row, int column, Rect viewport) {
    final visibleRange = getVisibleRange(viewport: viewport);
    return row >= visibleRange.startRow &&
        row <= visibleRange.endRow &&
        column >= visibleRange.startColumn &&
        column <= visibleRange.endColumn;
  }

  /// Returns the minimum viewport rect that would make [range] fully visible.
  Rect getViewportForRange(CellRange range) {
    return layoutSolver.getRangeBounds(
      startRow: range.startRow,
      startColumn: range.startColumn,
      endRow: range.endRow,
      endColumn: range.endColumn,
    );
  }
}
