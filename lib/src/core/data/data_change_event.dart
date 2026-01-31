import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';

/// The type of data change that occurred.
enum DataChangeType {
  /// A single cell value changed.
  cellValue,

  /// A single cell style changed.
  cellStyle,

  /// A single cell format changed.
  cellFormat,

  /// Multiple cells changed (batch update).
  range,

  /// Row inserted.
  rowInserted,

  /// Row deleted.
  rowDeleted,

  /// Column inserted.
  columnInserted,

  /// Column deleted.
  columnDeleted,

  /// Full data reset/reload.
  reset,
}

/// Event describing a change to worksheet data.
class DataChangeEvent {
  /// The type of change.
  final DataChangeType type;

  /// The affected cell (for single cell changes).
  final CellCoordinate? cell;

  /// The affected range (for range changes).
  final CellRange? range;

  /// The row index (for row insert/delete).
  final int? rowIndex;

  /// The column index (for column insert/delete).
  final int? columnIndex;

  const DataChangeEvent._({
    required this.type,
    this.cell,
    this.range,
    this.rowIndex,
    this.columnIndex,
  });

  /// Creates an event for a cell value change.
  factory DataChangeEvent.cellValue(CellCoordinate coord) {
    return DataChangeEvent._(
      type: DataChangeType.cellValue,
      cell: coord,
    );
  }

  /// Creates an event for a cell style change.
  factory DataChangeEvent.cellStyle(CellCoordinate coord) {
    return DataChangeEvent._(
      type: DataChangeType.cellStyle,
      cell: coord,
    );
  }

  /// Creates an event for a cell format change.
  factory DataChangeEvent.cellFormat(CellCoordinate coord) {
    return DataChangeEvent._(
      type: DataChangeType.cellFormat,
      cell: coord,
    );
  }

  /// Creates an event for a range change.
  factory DataChangeEvent.range(CellRange range) {
    return DataChangeEvent._(
      type: DataChangeType.range,
      range: range,
    );
  }

  /// Creates an event for a row insertion.
  factory DataChangeEvent.rowInserted(int index) {
    return DataChangeEvent._(
      type: DataChangeType.rowInserted,
      rowIndex: index,
    );
  }

  /// Creates an event for a row deletion.
  factory DataChangeEvent.rowDeleted(int index) {
    return DataChangeEvent._(
      type: DataChangeType.rowDeleted,
      rowIndex: index,
    );
  }

  /// Creates an event for a column insertion.
  factory DataChangeEvent.columnInserted(int index) {
    return DataChangeEvent._(
      type: DataChangeType.columnInserted,
      columnIndex: index,
    );
  }

  /// Creates an event for a column deletion.
  factory DataChangeEvent.columnDeleted(int index) {
    return DataChangeEvent._(
      type: DataChangeType.columnDeleted,
      columnIndex: index,
    );
  }

  /// Creates an event for a full data reset.
  factory DataChangeEvent.reset() {
    return const DataChangeEvent._(type: DataChangeType.reset);
  }

  @override
  String toString() {
    switch (type) {
      case DataChangeType.cellValue:
        return 'DataChangeEvent.cellValue($cell)';
      case DataChangeType.cellStyle:
        return 'DataChangeEvent.cellStyle($cell)';
      case DataChangeType.cellFormat:
        return 'DataChangeEvent.cellFormat($cell)';
      case DataChangeType.range:
        return 'DataChangeEvent.range($range)';
      case DataChangeType.rowInserted:
        return 'DataChangeEvent.rowInserted($rowIndex)';
      case DataChangeType.rowDeleted:
        return 'DataChangeEvent.rowDeleted($rowIndex)';
      case DataChangeType.columnInserted:
        return 'DataChangeEvent.columnInserted($columnIndex)';
      case DataChangeType.columnDeleted:
        return 'DataChangeEvent.columnDeleted($columnIndex)';
      case DataChangeType.reset:
        return 'DataChangeEvent.reset()';
    }
  }
}
