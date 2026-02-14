import 'package:flutter/painting.dart';

import 'package:worksheet/worksheet.dart';

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

  /// Gets the format of the cell at [coord], or null for General format.
  CellFormat? getFormat(CellCoordinate coord) => null;

  /// Sets the format of the cell at [coord].
  ///
  /// Pass null to use General format.
  void setFormat(CellCoordinate coord, CellFormat? format) {}

  /// Gets the rich text spans for the cell at [coord], or null if none.
  List<TextSpan>? getRichText(CellCoordinate coord) => null;

  /// Sets the rich text spans for the cell at [coord].
  ///
  /// Pass null to clear rich text (cell renders plain text from value).
  /// The concatenation of span texts must equal the cell's plain text value.
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}

  /// Performs batch updates atomically.
  ///
  /// All changes made within [updates] are batched into a single change event.
  void batchUpdate(void Function(WorksheetDataBatch batch) updates);

  /// Async version for batch updates that may need await
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  );

  /// Stream of data change events.
  Stream<DataChangeEvent> get changes;

  /// The number of rows in the worksheet.
  int get rowCount;

  /// The number of columns in the worksheet.
  int get columnCount;

  /// Checks if the cell at [coord] has a value.
  bool hasValue(CellCoordinate coord) => getCell(coord) != null;

  /// Gets all non-empty cells within [range].
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  );

  /// Clears all cells within [range].
  void clearRange(CellRange range);

  /// Pattern fill from range to target cell - either override this or provide a generator
  ///
  /// Returns the full filled range (source + target, possibly expanded to
  /// complete merge tiles), or null when no fill occurred.
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]);

  /// Implement fill Down / fillRight from source to target - either override this or provide a generator
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]);

  /// The merged cell registry for this worksheet.
  ///
  /// Provides access to merged cell regions for layout and rendering.
  MergedCellRegistry get mergedCells;

  /// Merges cells in [range] into a single merged cell.
  ///
  /// The anchor (top-left) cell keeps its value; all other cell values
  /// in the range are cleared. Throws if the range overlaps an existing
  /// merge or contains fewer than 2 cells.
  void mergeCells(CellRange range);

  /// Unmerges the merge region containing [cell].
  ///
  /// The anchor cell's value is preserved. Does nothing if [cell] is
  /// not part of a merged region.
  void unmergeCells(CellCoordinate cell);

  /// Unmerges all merge regions that intersect [range].
  ///
  /// Every merge region touching [range] is removed. Anchor cell values
  /// are preserved. Does nothing if no merges intersect [range].
  void unmergeCellsInRange(CellRange range) {}

  /// Moves merge regions from [source] to [destination].
  ///
  /// Merges fully contained in [source] are unmerged and re-created
  /// at the same relative offset from [destination]. Merges that would
  /// extend beyond worksheet bounds are skipped.
  void moveMerges(CellRange source, CellCoordinate destination) {}

  /// Replicates merge patterns from [sourceRange] into [targetRange].
  ///
  /// Merges fully contained within [sourceRange] are tiled into
  /// [targetRange]. When [vertical] is true, merges tile row-wise
  /// (for fill down/up). When false, merges tile column-wise.
  ///
  /// Existing merges in [targetRange] are removed first.
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) {} // default no-op — test stubs inherit this

  /// Releases resources.
  void dispose();
}

/// Batch interface for atomic updates.
abstract class WorksheetDataBatch {
  /// Sets a cell value within the batch.
  void setCell(CellCoordinate coord, CellValue? value);

  /// Sets a cell style within the batch.
  void setStyle(CellCoordinate coord, CellStyle? style);

  /// Sets a cell format within the batch.
  void setFormat(CellCoordinate coord, CellFormat? format) {}

  /// Sets rich text spans within the batch.
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}

  /// Clears a range within the batch.
  void clearRange(CellRange range);

  /// Fill all cells in range with the same value
  void fillRangeWithCell(CellRange range, Cell? value);

  /// Clear only values, preserve styles
  void clearValues(CellRange range);

  /// Clear only styles, preserve values
  void clearStyles(CellRange range);

  /// Clear only formats, preserve values and styles
  void clearFormats(CellRange range);

  /// Copy cells from source range to destination
  void copyRange(CellRange source, CellCoordinate destination);
}
