import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/data/merged_cell_registry.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';

/// The mode of the current selection.
enum SelectionMode {
  /// No selection.
  none,

  /// Single cell selected.
  single,

  /// Range of cells selected.
  range,
}

/// Controls selection state for a worksheet.
///
/// Supports single cell selection, range selection, and row/column selection.
/// Notifies listeners when selection changes.
class SelectionController extends ChangeNotifier {
  CellCoordinate? _anchor;
  CellCoordinate? _focus;
  SelectionMode _mode = SelectionMode.none;

  /// Optional merged cell registry for merge-aware selection.
  MergedCellRegistry? mergedCells;

  /// The anchor cell (start of selection).
  CellCoordinate? get anchor => _anchor;

  /// The focus cell (end of selection, where cursor is).
  CellCoordinate? get focus => _focus;

  /// The current selection mode.
  SelectionMode get mode => _mode;

  /// Whether there is an active selection.
  bool get hasSelection => _anchor != null && _focus != null;

  /// The currently selected range, or null if no selection.
  ///
  /// Normalizes anchor and focus so start <= end.
  /// If merged cells are present, expands the range to include any
  /// partially-overlapping merge regions.
  CellRange? get selectedRange {
    if (_anchor == null || _focus == null) return null;

    var range = CellRange(
      math.min(_anchor!.row, _focus!.row),
      math.min(_anchor!.column, _focus!.column),
      math.max(_anchor!.row, _focus!.row),
      math.max(_anchor!.column, _focus!.column),
    );

    if (mergedCells != null) {
      range = _expandRangeForMerges(range);
    }

    return range;
  }

  /// Expands a range to include full merge regions that partially overlap.
  ///
  /// Iterates until stable (no more partial overlaps).
  CellRange _expandRangeForMerges(CellRange range) {
    var current = range;
    bool changed = true;
    while (changed) {
      changed = false;
      for (final region in mergedCells!.regionsInRange(current)) {
        final expanded = current.union(region.range);
        if (expanded != current) {
          current = expanded;
          changed = true;
        }
      }
    }
    return current;
  }

  /// Selects a single cell.
  ///
  /// Sets both anchor and focus to the given cell.
  /// If the cell is part of a merged region, resolves to the anchor cell.
  void selectCell(CellCoordinate cell) {
    final resolved = mergedCells?.resolveAnchor(cell) ?? cell;
    _anchor = resolved;
    _focus = resolved;
    _mode = SelectionMode.single;
    notifyListeners();
  }

  /// Extends the selection from anchor to the given cell.
  ///
  /// Does nothing if there is no anchor.
  void extendSelection(CellCoordinate cell) {
    if (_anchor == null) return;

    _focus = cell;
    _mode = SelectionMode.range;
    notifyListeners();
  }

  /// Clears the selection.
  void clear() {
    if (_anchor == null && _focus == null) return;

    _anchor = null;
    _focus = null;
    _mode = SelectionMode.none;
    notifyListeners();
  }

  /// Selects a range directly.
  void selectRange(CellRange range) {
    _anchor = CellCoordinate(range.startRow, range.startColumn);
    _focus = CellCoordinate(range.endRow, range.endColumn);
    _mode = SelectionMode.range;
    notifyListeners();
  }

  /// Selects an entire row.
  void selectRow(int row, {required int columnCount}) {
    _anchor = CellCoordinate(row, 0);
    _focus = CellCoordinate(row, columnCount - 1);
    _mode = SelectionMode.range;
    notifyListeners();
  }

  /// Selects an entire column.
  void selectColumn(int column, {required int rowCount}) {
    _anchor = CellCoordinate(0, column);
    _focus = CellCoordinate(rowCount - 1, column);
    _mode = SelectionMode.range;
    notifyListeners();
  }

  /// Moves the focus by the given delta.
  ///
  /// If [extend] is true, extends the selection. Otherwise, moves the
  /// entire selection.
  ///
  /// [maxRow] and [maxColumn] are used to clamp the new position.
  /// When merged cells are present, skips over merge children so that
  /// arrow navigation lands on the next non-child cell.
  void moveFocus({
    required int rowDelta,
    required int columnDelta,
    required bool extend,
    int maxRow = 999999,
    int maxColumn = 999999,
  }) {
    if (_focus == null) return;

    var newRow = (_focus!.row + rowDelta).clamp(0, maxRow - 1);
    var newCol = (_focus!.column + columnDelta).clamp(0, maxColumn - 1);

    // When not extending and merged cells exist, skip over merge children
    if (!extend && mergedCells != null) {
      // If current focus is in a merge, step out from the merge boundary
      final currentRegion = mergedCells!.getRegion(_focus!);
      if (currentRegion != null) {
        if (rowDelta > 0) {
          newRow = (currentRegion.range.endRow + rowDelta)
              .clamp(0, maxRow - 1);
        } else if (rowDelta < 0) {
          newRow = (currentRegion.range.startRow + rowDelta)
              .clamp(0, maxRow - 1);
        }
        if (columnDelta > 0) {
          newCol = (currentRegion.range.endColumn + columnDelta)
              .clamp(0, maxColumn - 1);
        } else if (columnDelta < 0) {
          newCol = (currentRegion.range.startColumn + columnDelta)
              .clamp(0, maxColumn - 1);
        }
      }

      // Resolve through merge anchor at destination
      final destCoord = CellCoordinate(newRow, newCol);
      final resolved = mergedCells!.resolveAnchor(destCoord);
      newRow = resolved.row;
      newCol = resolved.column;
    }

    final newFocus = CellCoordinate(newRow, newCol);

    if (extend) {
      _focus = newFocus;
      _mode = SelectionMode.range;
    } else {
      _anchor = newFocus;
      _focus = newFocus;
      _mode = SelectionMode.single;
    }

    notifyListeners();
  }

  /// Returns true if the given cell is within the current selection.
  bool containsCell(CellCoordinate cell) {
    final range = selectedRange;
    if (range == null) return false;
    return range.contains(cell);
  }
}
