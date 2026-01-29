import 'dart:async';
import 'dart:math' as math;

import '../models/cell.dart';
import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';
import '../models/cell_style.dart';
import '../models/cell_value.dart';
import 'data_change_event.dart';
import 'worksheet_data.dart';

typedef CellCoordinateRecord = (int row, int col);

/// Memory-efficient sparse storage implementation of [WorksheetData].
///
/// Uses maps to store only non-empty cells, making it efficient for
/// worksheets with large dimensions but relatively few populated cells.
class SparseWorksheetData implements WorksheetData {
  /// Cell values indexed by coordinate.
  final Map<CellCoordinate, CellValue> _values = {};

  /// Cell styles indexed by coordinate.
  final Map<CellCoordinate, CellStyle> _styles = {};

  /// Change event stream controller.
  final _changeController = StreamController<DataChangeEvent>.broadcast();

  /// Whether this data object has been disposed.
  bool _disposed = false;

  /// Maximum populated row index (for bounds optimization).
  int _maxPopulatedRow = -1;

  /// Maximum populated column index (for bounds optimization).
  int _maxPopulatedColumn = -1;

  @override
  final int rowCount;

  @override
  final int columnCount;

  /// Creates a sparse worksheet data store with the given dimensions.
  ///
  /// Optionally accepts a [cells] map to populate initial data:
  ///
  /// ```dart
  /// final data = SparseWorksheetData(
  ///   rowCount: 100,
  ///   columnCount: 10,
  ///   cells: {
  ///     CellCoordinate(0, 0): Cell.text('Name'),
  ///     CellCoordinate(1, 0): Cell.number(42),
  ///   },
  /// );
  /// ```
  SparseWorksheetData({
    required this.rowCount,
    required this.columnCount,
    Map<CellCoordinateRecord, Cell>? cells,
  }) {
    if (cells != null) {
      for (final entry in cells.entries) {
        final coord = CellCoordinate(entry.key.$1, entry.key.$2);
        if (entry.value.value != null) {
          _values[coord] = entry.value.value!;
          _updateBounds(coord);
        }
        if (entry.value.style != null) {
          _styles[coord] = entry.value.style!;
        }
      }
    }
  }

  /// The number of populated cells.
  int get populatedCellCount => _values.length;

  /// The highest row index that contains data, or -1 if empty.
  int get maxPopulatedRow => _maxPopulatedRow;

  /// The highest column index that contains data, or -1 if empty.
  int get maxPopulatedColumn => _maxPopulatedColumn;

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('SparseWorksheetData has been disposed');
    }
  }

  void _updateBounds(CellCoordinate coord) {
    _maxPopulatedRow = math.max(_maxPopulatedRow, coord.row);
    _maxPopulatedColumn = math.max(_maxPopulatedColumn, coord.column);
  }

  void _recalculateBounds() {
    _maxPopulatedRow = -1;
    _maxPopulatedColumn = -1;
    for (final coord in _values.keys) {
      _updateBounds(coord);
    }
  }

  @override
  CellValue? getCell(CellCoordinate coord) {
    return _values[coord];
  }

  @override
  CellStyle? getStyle(CellCoordinate coord) {
    return _styles[coord];
  }

  @override
  bool hasValue(CellCoordinate coord) => _values.containsKey(coord);

  /// Gets the [Cell] at [x, y], or null if the cell has no value and no style.
  Cell? operator [](CellCoordinateRecord record) {
    final coord = CellCoordinate(record.$1, record.$2);
    final value = _values[coord];
    final style = _styles[coord];
    if (value == null && style == null) return null;
    return Cell(value: value, style: style);
  }

  /// Sets the [Cell] at [(x, y)], updating both value and style.
  ///
  /// Pass null to clear both value and style.
  void operator []=(CellCoordinateRecord record, Cell? cell) {
    final coord = CellCoordinate(record.$1, record.$2);
    _checkNotDisposed();
    if (cell == null) {
      final hadValue = _values.containsKey(coord);
      final hadStyle = _styles.containsKey(coord);
      if (hadValue) _values.remove(coord);
      if (hadStyle) _styles.remove(coord);
      if (hadValue) _recalculateBounds();
      if (hadValue || hadStyle) {
        _changeController.add(DataChangeEvent.cellValue(coord));
      }
    } else {
      if (cell.value != null) {
        _values[coord] = cell.value!;
        _updateBounds(coord);
      } else if (_values.containsKey(coord)) {
        _values.remove(coord);
        _recalculateBounds();
      }
      if (cell.style != null) {
        _styles[coord] = cell.style!;
      } else if (_styles.containsKey(coord)) {
        _styles.remove(coord);
      }
      _changeController.add(DataChangeEvent.cellValue(coord));
    }
  }

  /// Returns a snapshot of all populated cells as a map.
  ///
  /// A cell is included if it has a value, a style, or both.
  Map<CellCoordinate, Cell> get cells {
    final allCoords = {..._values.keys, ..._styles.keys};
    return {
      for (final coord in allCoords)
        coord: Cell(value: _values[coord], style: _styles[coord]),
    };
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    _checkNotDisposed();

    final hadValue = _values.containsKey(coord);

    if (value == null) {
      if (hadValue) {
        _values.remove(coord);
        _recalculateBounds();
        _changeController.add(DataChangeEvent.cellValue(coord));
      }
    } else {
      _values[coord] = value;
      _updateBounds(coord);
      _changeController.add(DataChangeEvent.cellValue(coord));
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    _checkNotDisposed();

    if (style == null) {
      if (_styles.containsKey(coord)) {
        _styles.remove(coord);
        _changeController.add(DataChangeEvent.cellStyle(coord));
      }
    } else {
      _styles[coord] = style;
      _changeController.add(DataChangeEvent.cellStyle(coord));
    }
  }

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    _checkNotDisposed();

    final batch = _BatchImpl(this);
    updates(batch);

    if (batch._affectedRange != null) {
      _changeController.add(DataChangeEvent.range(batch._affectedRange!));
    }
  }

  @override
  Stream<DataChangeEvent> get changes => _changeController.stream;

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) sync* {
    for (final entry in _values.entries) {
      if (range.contains(entry.key)) {
        yield entry;
      }
    }
  }

  @override
  void clearRange(CellRange range) {
    _checkNotDisposed();

    final toRemove = <CellCoordinate>[];
    for (final coord in _values.keys) {
      if (range.contains(coord)) {
        toRemove.add(coord);
      }
    }

    for (final coord in toRemove) {
      _values.remove(coord);
    }

    // Also clear styles
    final stylesToRemove = <CellCoordinate>[];
    for (final coord in _styles.keys) {
      if (range.contains(coord)) {
        stylesToRemove.add(coord);
      }
    }

    for (final coord in stylesToRemove) {
      _styles.remove(coord);
    }

    _recalculateBounds();
    _changeController.add(DataChangeEvent.range(range));
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _changeController.close();
      _values.clear();
      _styles.clear();
    }
  }
}

/// Internal batch implementation.
class _BatchImpl implements WorksheetDataBatch {
  final SparseWorksheetData _data;
  CellRange? _affectedRange;

  _BatchImpl(this._data);

  void _expandRange(CellCoordinate coord) {
    if (_affectedRange == null) {
      _affectedRange = CellRange.single(coord);
    } else {
      _affectedRange = _affectedRange!.expand(coord);
    }
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    if (value == null) {
      final hadValue = _data._values.containsKey(coord);
      if (hadValue) {
        _data._values.remove(coord);
        _expandRange(coord);
      }
    } else {
      _data._values[coord] = value;
      _data._updateBounds(coord);
      _expandRange(coord);
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    if (style == null) {
      _data._styles.remove(coord);
    } else {
      _data._styles[coord] = style;
    }
    _expandRange(coord);
  }

  @override
  void clearRange(CellRange range) {
    for (final coord in _data._values.keys.toList()) {
      if (range.contains(coord)) {
        _data._values.remove(coord);
      }
    }
    for (final coord in _data._styles.keys.toList()) {
      if (range.contains(coord)) {
        _data._styles.remove(coord);
      }
    }
    if (_affectedRange == null) {
      _affectedRange = range;
    } else {
      _affectedRange = _affectedRange!.union(range);
    }
  }
}
