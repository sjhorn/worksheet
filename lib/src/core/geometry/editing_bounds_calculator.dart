import 'package:flutter/painting.dart';

import '../data/merged_cell_registry.dart';
import '../models/cell_coordinate.dart';
import 'layout_solver.dart';

/// The result of computing expanded editing bounds.
class ExpandedEditingBounds {
  /// The expanded bounds in worksheet coordinates.
  final Rect bounds;

  /// The last column index reached by horizontal expansion.
  final int endColumn;

  /// The last row index reached by vertical expansion.
  final int endRow;

  const ExpandedEditingBounds({
    required this.bounds,
    required this.endColumn,
    required this.endRow,
  });
}

/// Pure utility for computing expanded editing bounds.
///
/// When a cell is being edited and the text overflows, this calculator
/// determines how many adjacent columns (non-wrap) or rows (wrap) the
/// editor should expand into, stopping at merged cells or sheet edges.
class EditingBoundsCalculator {
  /// Computes horizontal expansion for non-wrap editing.
  ///
  /// Measures unconstrained text width, then walks columns rightward
  /// from [cell] until the total width accommodates the text.
  /// Stops at merged cells or [maxColumn].
  static ExpandedEditingBounds computeHorizontal({
    required CellCoordinate cell,
    required String text,
    required LayoutSolver layoutSolver,
    required TextStyle textStyle,
    required double cellPadding,
    required int maxColumn,
    MergedCellRegistry? mergedCells,
  }) {
    final cellBounds = layoutSolver.getCellBounds(cell);

    if (text.isEmpty) {
      return ExpandedEditingBounds(
        bounds: cellBounds,
        endColumn: cell.column,
        endRow: cell.row,
      );
    }

    // Measure unconstrained text width
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final textWidth = textPainter.width;
    textPainter.dispose();

    final neededWidth = textWidth + 2 * cellPadding;

    // Walk columns rightward until we have enough width
    var totalWidth = cellBounds.width;
    var endCol = cell.column;

    while (totalWidth < neededWidth && endCol < maxColumn) {
      final nextCol = endCol + 1;

      // Stop at merged cells
      if (mergedCells != null) {
        final region = mergedCells.getRegion(CellCoordinate(cell.row, nextCol));
        if (region != null) break;
      }

      totalWidth += layoutSolver.getColumnWidth(nextCol);
      endCol = nextCol;
    }

    // If no expansion needed, return original bounds
    if (endCol == cell.column) {
      return ExpandedEditingBounds(
        bounds: cellBounds,
        endColumn: cell.column,
        endRow: cell.row,
      );
    }

    final expandedBounds = Rect.fromLTWH(
      cellBounds.left,
      cellBounds.top,
      totalWidth,
      cellBounds.height,
    );

    return ExpandedEditingBounds(
      bounds: expandedBounds,
      endColumn: endCol,
      endRow: cell.row,
    );
  }

  /// Computes vertical expansion for wrap-text editing.
  ///
  /// Measures wrapped text height (constrained to cell width), then walks
  /// rows downward from [cell] until the total height accommodates the text.
  /// Stops at merged cells or [maxRow].
  ///
  /// [verticalOffset] is the fixed top offset (in worksheet coordinates)
  /// where the editor positions the text inside the cell. For top-aligned
  /// cells this equals [cellPadding]; for middle/bottom it is larger,
  /// computed from the initial text height at edit start. When provided,
  /// the needed height is `verticalOffset + textHeight + cellPadding`
  /// instead of `textHeight + 2 * cellPadding`.
  static ExpandedEditingBounds computeVertical({
    required CellCoordinate cell,
    required String text,
    required LayoutSolver layoutSolver,
    required TextStyle textStyle,
    required double cellPadding,
    required int maxRow,
    MergedCellRegistry? mergedCells,
    double? verticalOffset,
  }) {
    final cellBounds = layoutSolver.getCellBounds(cell);

    if (text.isEmpty) {
      return ExpandedEditingBounds(
        bounds: cellBounds,
        endColumn: cell.column,
        endRow: cell.row,
      );
    }

    // Measure wrapped text height at cell width.
    // Append a zero-width space when text ends with a newline so
    // TextPainter accounts for the trailing blank line (it normally
    // ignores trailing newlines when computing height).
    final measureText = text.endsWith('\n') ? '$text\u200B' : text;
    final availableWidth = cellBounds.width - 2 * cellPadding;
    final textPainter = TextPainter(
      text: TextSpan(text: measureText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(
        minWidth: availableWidth > 0 ? availableWidth : 0,
        maxWidth: availableWidth > 0 ? availableWidth : 0,
      );
    final textHeight = textPainter.height;
    textPainter.dispose();

    // When verticalOffset is provided, it represents where the text
    // actually starts inside the cell (fixed at edit start for
    // middle/bottom alignment). Total needed from cell top:
    //   verticalOffset + textHeight + cellPadding (bottom padding)
    final topOffset = verticalOffset ?? cellPadding;
    final neededHeight = topOffset + textHeight + cellPadding;

    // Walk rows downward until we have enough height
    var totalHeight = cellBounds.height;
    var endRow = cell.row;

    while (totalHeight < neededHeight && endRow < maxRow) {
      final nextRow = endRow + 1;

      // Stop at merged cells
      if (mergedCells != null) {
        final region = mergedCells.getRegion(CellCoordinate(nextRow, cell.column));
        if (region != null) break;
      }

      totalHeight += layoutSolver.getRowHeight(nextRow);
      endRow = nextRow;
    }

    // If no expansion needed, return original bounds
    if (endRow == cell.row) {
      return ExpandedEditingBounds(
        bounds: cellBounds,
        endColumn: cell.column,
        endRow: cell.row,
      );
    }

    final expandedBounds = Rect.fromLTWH(
      cellBounds.left,
      cellBounds.top,
      cellBounds.width,
      totalHeight,
    );

    return ExpandedEditingBounds(
      bounds: expandedBounds,
      endColumn: cell.column,
      endRow: endRow,
    );
  }
}
