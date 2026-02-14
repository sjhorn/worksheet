import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/cell.dart';
import '../models/cell_coordinate.dart';
import '../models/cell_format.dart';
import '../models/cell_range.dart';
import '../models/cell_style.dart';
import '../models/cell_value.dart';
import 'data_change_event.dart';
import 'fill_pattern_detector.dart';
import 'merged_cell_registry.dart';
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

  /// Cell formats indexed by coordinate.
  final Map<CellCoordinate, CellFormat> _formats = {};

  /// Rich text spans indexed by coordinate.
  final Map<CellCoordinate, List<TextSpan>> _richText = {};

  /// Merged cell registry.
  final MergedCellRegistry _mergedCells = MergedCellRegistry();

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
  /// Optionally accepts a [cells] map to populate initial data, using
  /// Dart record tuples `(row, col)` as keys:
  ///
  /// ```dart
  /// final data = SparseWorksheetData(
  ///   rowCount: 100,
  ///   columnCount: 10,
  ///   cells: {
  ///     (0, 0): 'Name'.cell,
  ///     (0, 1): 'Amount'.cell,
  ///     (1, 0): 42.cell,
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
        if (entry.value.format != null) {
          _formats[coord] = entry.value.format!;
        }
        if (entry.value.richText != null) {
          _richText[coord] = entry.value.richText!;
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
  CellFormat? getFormat(CellCoordinate coord) {
    return _formats[coord];
  }

  @override
  bool hasValue(CellCoordinate coord) => _values.containsKey(coord);

  /// Gets the [Cell] at [x, y], or null if the cell has no value, style, format, or rich text.
  Cell? operator [](CellCoordinateRecord record) {
    final coord = CellCoordinate(record.$1, record.$2);
    final value = _values[coord];
    final style = _styles[coord];
    final format = _formats[coord];
    final richText = _richText[coord];
    if (value == null && style == null && format == null && richText == null) {
      return null;
    }
    return Cell(value: value, style: style, format: format, richText: richText);
  }

  /// Sets the [Cell] at [(x, y)], updating value, style, format, and rich text.
  ///
  /// Pass null to clear value, style, format, and rich text.
  void operator []=(CellCoordinateRecord record, Cell? cell) {
    final coord = CellCoordinate(record.$1, record.$2);
    _checkNotDisposed();
    if (cell == null) {
      final hadValue = _values.containsKey(coord);
      final hadStyle = _styles.containsKey(coord);
      final hadFormat = _formats.containsKey(coord);
      final hadRichText = _richText.containsKey(coord);
      if (hadValue) _values.remove(coord);
      if (hadStyle) _styles.remove(coord);
      if (hadFormat) _formats.remove(coord);
      if (hadRichText) _richText.remove(coord);
      if (hadValue) _recalculateBounds();
      if (hadValue || hadStyle || hadFormat || hadRichText) {
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
      if (cell.format != null) {
        _formats[coord] = cell.format!;
      } else if (_formats.containsKey(coord)) {
        _formats.remove(coord);
      }
      if (cell.richText != null) {
        _richText[coord] = cell.richText!;
      } else if (_richText.containsKey(coord)) {
        _richText.remove(coord);
      }
      _changeController.add(DataChangeEvent.cellValue(coord));
    }
  }

  /// Returns a snapshot of all populated cells as a map.
  ///
  /// A cell is included if it has a value, a style, a format, rich text, or any combination.
  Map<CellCoordinate, Cell> get cells {
    final allCoords = {
      ..._values.keys,
      ..._styles.keys,
      ..._formats.keys,
      ..._richText.keys,
    };
    return {
      for (final coord in allCoords)
        coord: Cell(
          value: _values[coord],
          style: _styles[coord],
          format: _formats[coord],
          richText: _richText[coord],
        ),
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
  void setFormat(CellCoordinate coord, CellFormat? format) {
    _checkNotDisposed();

    if (format == null) {
      if (_formats.containsKey(coord)) {
        _formats.remove(coord);
        _changeController.add(DataChangeEvent.cellFormat(coord));
      }
    } else {
      _formats[coord] = format;
      _changeController.add(DataChangeEvent.cellFormat(coord));
    }
  }

  @override
  List<TextSpan>? getRichText(CellCoordinate coord) {
    return _richText[coord];
  }

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {
    _checkNotDisposed();

    if (richText == null) {
      if (_richText.containsKey(coord)) {
        _richText.remove(coord);
        _changeController.add(DataChangeEvent.cellValue(coord));
      }
    } else {
      _richText[coord] = richText;
      _changeController.add(DataChangeEvent.cellValue(coord));
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
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) async {
    _checkNotDisposed();

    final batch = _BatchImpl(this);
    await updates(batch);

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

    // Also clear formats
    final formatsToRemove = <CellCoordinate>[];
    for (final coord in _formats.keys) {
      if (range.contains(coord)) {
        formatsToRemove.add(coord);
      }
    }

    for (final coord in formatsToRemove) {
      _formats.remove(coord);
    }

    // Also clear rich text
    final richTextToRemove = <CellCoordinate>[];
    for (final coord in _richText.keys) {
      if (range.contains(coord)) {
        richTextToRemove.add(coord);
      }
    }

    for (final coord in richTextToRemove) {
      _richText.remove(coord);
    }

    _recalculateBounds();
    _changeController.add(DataChangeEvent.range(range));
  }

  @override
  MergedCellRegistry get mergedCells => _mergedCells;

  @override
  void mergeCells(CellRange range) {
    _checkNotDisposed();

    // Register the merge (validates no overlap, >= 2 cells)
    _mergedCells.merge(range);

    // Clear values from all non-anchor cells
    final anchor = range.topLeft;
    for (final cell in range.cells) {
      if (cell != anchor) {
        _values.remove(cell);
      }
    }

    _recalculateBounds();
    _changeController.add(DataChangeEvent.merge(range));
  }

  @override
  void unmergeCells(CellCoordinate cell) {
    _checkNotDisposed();

    final region = _mergedCells.getRegion(cell);
    if (region == null) return;

    _mergedCells.unmerge(cell);
    _changeController.add(DataChangeEvent.unmerge(region.range));
  }

  @override
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) {
    _checkNotDisposed();

    // 1. Find merges fully contained within source range
    final sourceMerges = <CellRange>[];
    for (final region in _mergedCells.regions) {
      final r = region.range;
      if (r.startRow >= sourceRange.startRow &&
          r.endRow <= sourceRange.endRow &&
          r.startColumn >= sourceRange.startColumn &&
          r.endColumn <= sourceRange.endColumn) {
        sourceMerges.add(r);
      }
    }

    // No merges in source = no-op
    if (sourceMerges.isEmpty) return;

    // 2. Unmerge everything in target range
    final targetRegions =
        _mergedCells.regionsInRange(targetRange).toList();
    for (final region in targetRegions) {
      _mergedCells.unmerge(region.anchor);
    }

    // 3. Tile source merges into target
    if (vertical) {
      final sourceHeight = sourceRange.rowCount;
      final targetHeight = targetRange.rowCount;

      for (int offset = 0; offset < targetHeight; offset += sourceHeight) {
        for (final merge in sourceMerges) {
          final mergeRelStartRow = merge.startRow - sourceRange.startRow;
          final mergeRelEndRow = merge.endRow - sourceRange.startRow;

          final newStartRow = targetRange.startRow + offset + mergeRelStartRow;
          final newEndRow = targetRange.startRow + offset + mergeRelEndRow;

          // Skip incomplete tiles at boundary
          if (newEndRow > targetRange.endRow) continue;

          final newRange = CellRange(
            newStartRow,
            merge.startColumn,
            newEndRow,
            merge.endColumn,
          );

          _mergedCells.merge(newRange);

          // 4. Clear non-anchor cell values
          final anchor = newRange.topLeft;
          for (final cell in newRange.cells) {
            if (cell != anchor) {
              _values.remove(cell);
            }
          }
        }
      }
    } else {
      final sourceWidth = sourceRange.columnCount;
      final targetWidth = targetRange.columnCount;

      for (int offset = 0; offset < targetWidth; offset += sourceWidth) {
        for (final merge in sourceMerges) {
          final mergeRelStartCol =
              merge.startColumn - sourceRange.startColumn;
          final mergeRelEndCol = merge.endColumn - sourceRange.startColumn;

          final newStartCol =
              targetRange.startColumn + offset + mergeRelStartCol;
          final newEndCol =
              targetRange.startColumn + offset + mergeRelEndCol;

          // Skip incomplete tiles at boundary
          if (newEndCol > targetRange.endColumn) continue;

          final newRange = CellRange(
            merge.startRow,
            newStartCol,
            merge.endRow,
            newEndCol,
          );

          _mergedCells.merge(newRange);

          // 4. Clear non-anchor cell values
          final anchor = newRange.topLeft;
          for (final cell in newRange.cells) {
            if (cell != anchor) {
              _values.remove(cell);
            }
          }
        }
      }
    }

    // 5. Fire change event
    _recalculateBounds();
    _changeController.add(DataChangeEvent.range(targetRange));
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _changeController.close();
      _values.clear();
      _styles.clear();
      _formats.clear();
      _richText.clear();
      _mergedCells.clear();
    }
  }

  /// Gets the full [Cell] at the given coordinate, or null if empty.
  Cell? _getCellAt(CellCoordinate coord) {
    final value = _values[coord];
    final style = _styles[coord];
    final format = _formats[coord];
    final richText = _richText[coord];
    if (value == null && style == null && format == null && richText == null) {
      return null;
    }
    return Cell(
      value: value,
      style: style,
      format: format,
      richText: richText,
    );
  }

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    _checkNotDisposed();
    final sourceCell = _getCellAt(source);

    // Empty source with no generator = no-op
    if (sourceCell == null && valueGenerator == null) return;

    batchUpdate((batch) {
      for (int row = range.startRow; row <= range.endRow; row++) {
        for (int col = range.startColumn; col <= range.endColumn; col++) {
          final coord = CellCoordinate(row, col);
          final cell =
              valueGenerator != null ? valueGenerator(coord, sourceCell) : sourceCell;

          if (cell != null) {
            if (cell.value != null) {
              batch.setCell(coord, cell.value);
            }
            if (cell.style != null) {
              batch.setStyle(coord, cell.style);
            }
            if (cell.format != null) {
              batch.setFormat(coord, cell.format);
            }
          }
        }
      }
    });
  }

  @override
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    _checkNotDisposed();

    // Determine fill direction by comparing destination to source range
    final bool fillDown = destination.row > range.endRow;
    final bool fillUp = destination.row < range.startRow;
    final bool fillRight = destination.column > range.endColumn;
    final bool fillLeft = destination.column < range.startColumn;

    final bool vertical = fillDown || fillUp;
    final bool horizontal = fillRight || fillLeft;
    final bool reverse = fillUp || fillLeft;

    // Determine the target region to fill
    CellRange targetRange;
    if (vertical) {
      final startRow = fillDown ? range.endRow + 1 : destination.row;
      final endRow = fillDown ? destination.row : range.startRow - 1;
      targetRange = CellRange(
        startRow,
        range.startColumn,
        endRow,
        range.endColumn,
      );
    } else if (horizontal) {
      final startCol = fillRight ? range.endColumn + 1 : destination.column;
      final endCol = fillRight ? destination.column : range.startColumn - 1;
      targetRange = CellRange(
        range.startRow,
        startCol,
        range.endRow,
        endCol,
      );
    } else {
      return null; // destination is inside the source range, nothing to do
    }

    // Expand target to complete merge tiles if source has merges
    final hasSourceMerges = _mergedCells.regions.any((region) {
      final r = region.range;
      return r.startRow >= range.startRow &&
          r.endRow <= range.endRow &&
          r.startColumn >= range.startColumn &&
          r.endColumn <= range.endColumn;
    });
    if (hasSourceMerges) {
      if (vertical) {
        final sourceHeight = range.rowCount;
        final remainder = targetRange.rowCount % sourceHeight;
        if (remainder > 0) {
          final expansion = sourceHeight - remainder;
          if (fillDown && targetRange.endRow + expansion < rowCount) {
            targetRange = targetRange.copyWith(
              endRow: targetRange.endRow + expansion,
            );
          } else if (fillUp && targetRange.startRow - expansion >= 0) {
            targetRange = targetRange.copyWith(
              startRow: targetRange.startRow - expansion,
            );
          }
        }
      } else {
        final sourceWidth = range.columnCount;
        final remainder = targetRange.columnCount % sourceWidth;
        if (remainder > 0) {
          final expansion = sourceWidth - remainder;
          if (fillRight && targetRange.endColumn + expansion < columnCount) {
            targetRange = targetRange.copyWith(
              endColumn: targetRange.endColumn + expansion,
            );
          } else if (fillLeft && targetRange.startColumn - expansion >= 0) {
            targetRange = targetRange.copyWith(
              startColumn: targetRange.startColumn - expansion,
            );
          }
        }
      }
    }

    batchUpdate((batch) {
      if (valueGenerator != null) {
        // Use generator, skip auto-detection
        for (int row = targetRange.startRow; row <= targetRange.endRow; row++) {
          for (int col = targetRange.startColumn;
              col <= targetRange.endColumn;
              col++) {
            final coord = CellCoordinate(row, col);
            final cell = valueGenerator(coord, null);
            if (cell != null) {
              if (cell.value != null) batch.setCell(coord, cell.value);
              if (cell.style != null) batch.setStyle(coord, cell.style);
              if (cell.format != null) batch.setFormat(coord, cell.format);
            }
          }
        }
        return;
      }

      if (vertical) {
        // Detect pattern per column independently
        for (int col = range.startColumn; col <= range.endColumn; col++) {
          final sourceCells = <Cell?>[];
          if (reverse) {
            // For fill-up, reverse source so pattern detects correctly
            for (int row = range.endRow; row >= range.startRow; row--) {
              sourceCells.add(_getCellAt(CellCoordinate(row, col)));
            }
          } else {
            for (int row = range.startRow; row <= range.endRow; row++) {
              sourceCells.add(_getCellAt(CellCoordinate(row, col)));
            }
          }

          final pattern = FillPatternDetector.detect(sourceCells);
          final sourceLen = sourceCells.length;

          if (fillDown) {
            for (int row = targetRange.startRow;
                row <= targetRange.endRow;
                row++) {
              final index = sourceLen + (row - targetRange.startRow);
              final cell = pattern.generate(index);
              final coord = CellCoordinate(row, col);
              if (cell != null) {
                if (cell.value != null) batch.setCell(coord, cell.value);
                if (cell.style != null) batch.setStyle(coord, cell.style);
                if (cell.format != null) batch.setFormat(coord, cell.format);
              }
            }
          } else {
            // Fill up: generate in reverse order
            for (int row = targetRange.endRow;
                row >= targetRange.startRow;
                row--) {
              final distFromSource = targetRange.endRow - row + 1;
              final index = sourceLen + (distFromSource - 1);
              final cell = pattern.generate(index);
              final coord = CellCoordinate(row, col);
              if (cell != null) {
                if (cell.value != null) batch.setCell(coord, cell.value);
                if (cell.style != null) batch.setStyle(coord, cell.style);
                if (cell.format != null) batch.setFormat(coord, cell.format);
              }
            }
          }
        }
      } else {
        // Horizontal fill: detect pattern per row independently
        for (int row = range.startRow; row <= range.endRow; row++) {
          final sourceCells = <Cell?>[];
          if (reverse) {
            for (int col = range.endColumn; col >= range.startColumn; col--) {
              sourceCells.add(_getCellAt(CellCoordinate(row, col)));
            }
          } else {
            for (int col = range.startColumn; col <= range.endColumn; col++) {
              sourceCells.add(_getCellAt(CellCoordinate(row, col)));
            }
          }

          final pattern = FillPatternDetector.detect(sourceCells);
          final sourceLen = sourceCells.length;

          if (fillRight) {
            for (int col = targetRange.startColumn;
                col <= targetRange.endColumn;
                col++) {
              final index = sourceLen + (col - targetRange.startColumn);
              final cell = pattern.generate(index);
              final coord = CellCoordinate(row, col);
              if (cell != null) {
                if (cell.value != null) batch.setCell(coord, cell.value);
                if (cell.style != null) batch.setStyle(coord, cell.style);
                if (cell.format != null) batch.setFormat(coord, cell.format);
              }
            }
          } else {
            // Fill left: generate in reverse order
            for (int col = targetRange.endColumn;
                col >= targetRange.startColumn;
                col--) {
              final distFromSource = targetRange.endColumn - col + 1;
              final index = sourceLen + (distFromSource - 1);
              final cell = pattern.generate(index);
              final coord = CellCoordinate(row, col);
              if (cell != null) {
                if (cell.value != null) batch.setCell(coord, cell.value);
                if (cell.style != null) batch.setStyle(coord, cell.style);
                if (cell.format != null) batch.setFormat(coord, cell.format);
              }
            }
          }
        }
      }
    });

    replicateMerges(
      sourceRange: range,
      targetRange: targetRange,
      vertical: vertical,
    );

    return range.union(targetRange);
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
  void setFormat(CellCoordinate coord, CellFormat? format) {
    if (format == null) {
      _data._formats.remove(coord);
    } else {
      _data._formats[coord] = format;
    }
    _expandRange(coord);
  }

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {
    if (richText == null) {
      _data._richText.remove(coord);
    } else {
      _data._richText[coord] = richText;
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
    for (final coord in _data._formats.keys.toList()) {
      if (range.contains(coord)) {
        _data._formats.remove(coord);
      }
    }
    for (final coord in _data._richText.keys.toList()) {
      if (range.contains(coord)) {
        _data._richText.remove(coord);
      }
    }
    if (_affectedRange == null) {
      _affectedRange = range;
    } else {
      _affectedRange = _affectedRange!.union(range);
    }
  }

  @override
  void fillRangeWithCell(CellRange range, Cell? value) {
    for (int row = range.startRow; row <= range.endRow; row++) {
      for (int col = range.startColumn; col <= range.endColumn; col++) {
        final coord = CellCoordinate(row, col);
        if (value != null) {
          if (value.value != null) {
            setCell(coord, value.value!);
          }
          if (value.style != null) {
            setStyle(coord, value.style!);
          }
          if (value.format != null) {
            setFormat(coord, value.format!);
          }
        }
      }
    }
  }

  @override
  void clearStyles(CellRange range) {
    for (final coord in _data._styles.keys.toList()) {
      if (range.contains(coord)) {
        setStyle(coord, null);
      }
    }
  }

  @override
  void clearFormats(CellRange range) {
    for (final coord in _data._formats.keys.toList()) {
      if (range.contains(coord)) {
        setFormat(coord, null);
      }
    }
  }

  @override
  void clearValues(CellRange range) {
    for (final coord in _data._values.keys.toList()) {
      if (range.contains(coord)) {
        setCell(coord, null);
      }
    }
    for (final coord in _data._richText.keys.toList()) {
      if (range.contains(coord)) {
        setRichText(coord, null);
      }
    }
  }

  @override
  void copyRange(CellRange source, CellCoordinate destination) {
    int offsetRow = 0;
    for (int row = source.startRow; row <= source.endRow; row++, offsetRow++) {
      int offsetCol = 0;
      for (
        int col = source.startColumn;
        col <= source.endColumn;
        col++, offsetCol++
      ) {
        final sourceCell = CellCoordinate(row, col);
        final destCell = CellCoordinate(
          destination.row + offsetRow,
          destination.column + offsetCol,
        );
        final value = _data.getCell(sourceCell);
        final style = _data.getStyle(sourceCell);
        final format = _data.getFormat(sourceCell);
        final richText = _data.getRichText(sourceCell);

        if (value != null) {
          _data._values[destCell] = value;
          _data._updateBounds(destCell);
        }
        if (style != null) {
          _data._styles[destCell] = style;
        }
        if (format != null) {
          _data._formats[destCell] = format;
        }
        if (richText != null) {
          _data._richText[destCell] = richText;
        }
      }
    }
    final range = CellRange(
      destination.row,
      destination.column,
      destination.row + source.rowCount - 1,
      destination.column + source.columnCount - 1,
    );
    if (_affectedRange == null) {
      _affectedRange = range;
    } else {
      _affectedRange = _affectedRange!.union(range);
    }
  }
}
