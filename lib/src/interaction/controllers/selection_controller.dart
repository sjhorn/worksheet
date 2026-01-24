import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
  CellRange? get selectedRange {
    if (_anchor == null || _focus == null) return null;

    return CellRange(
      math.min(_anchor!.row, _focus!.row),
      math.min(_anchor!.column, _focus!.column),
      math.max(_anchor!.row, _focus!.row),
      math.max(_anchor!.column, _focus!.column),
    );
  }

  /// Selects a single cell.
  ///
  /// Sets both anchor and focus to the given cell.
  void selectCell(CellCoordinate cell) {
    _anchor = cell;
    _focus = cell;
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
  void moveFocus({
    required int rowDelta,
    required int columnDelta,
    required bool extend,
    int maxRow = 999999,
    int maxColumn = 999999,
  }) {
    if (_focus == null) return;

    final newRow = (_focus!.row + rowDelta).clamp(0, maxRow - 1);
    final newCol = (_focus!.column + columnDelta).clamp(0, maxColumn - 1);
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
