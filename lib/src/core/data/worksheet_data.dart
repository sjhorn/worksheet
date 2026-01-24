import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';
import '../models/cell_style.dart';
import '../models/cell_value.dart';
import 'data_change_event.dart';

/// Abstract interface for worksheet data access.
///
/// Implementations handle storage and retrieval of cell values and styles,
/// provide change notifications, and support batch operations.
abstract class WorksheetData {
  /// Gets the value of the cell at [coord], or null if empty.
  CellValue? getCell(CellCoordinate coord);

  /// Gets the style of the cell at [coord], or null for default style.
  CellStyle? getStyle(CellCoordinate coord);

  /// Sets the value of the cell at [coord].
  ///
  /// Pass null to clear the cell.
  void setCell(CellCoordinate coord, CellValue? value);

  /// Sets the style of the cell at [coord].
  ///
  /// Pass null to use the default style.
  void setStyle(CellCoordinate coord, CellStyle? style);

  /// Performs batch updates atomically.
  ///
  /// All changes made within [updates] are batched into a single change event.
  void batchUpdate(void Function(WorksheetDataBatch batch) updates);

  /// Stream of data change events.
  Stream<DataChangeEvent> get changes;

  /// The number of rows in the worksheet.
  int get rowCount;

  /// The number of columns in the worksheet.
  int get columnCount;

  /// Checks if the cell at [coord] has a value.
  bool hasValue(CellCoordinate coord) => getCell(coord) != null;

  /// Gets all non-empty cells within [range].
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(CellRange range);

  /// Clears all cells within [range].
  void clearRange(CellRange range);

  /// Releases resources.
  void dispose();
}

/// Batch interface for atomic updates.
abstract class WorksheetDataBatch {
  /// Sets a cell value within the batch.
  void setCell(CellCoordinate coord, CellValue? value);

  /// Sets a cell style within the batch.
  void setStyle(CellCoordinate coord, CellStyle? style);

  /// Clears a range within the batch.
  void clearRange(CellRange range);
}
