import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/data_change_event.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/data/merged_cell_registry.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

/// Minimal implementation that uses the default hasValue from WorksheetData.
class _MinimalWorksheetData extends WorksheetData {
  final Map<CellCoordinate, CellValue> _cells = {};
  final Map<CellCoordinate, CellStyle> _styles = {};
  final _controller = StreamController<DataChangeEvent>.broadcast();

  @override
  int get rowCount => 100;

  @override
  int get columnCount => 100;

  @override
  CellValue? getCell(CellCoordinate coord) => _cells[coord];

  @override
  CellStyle? getStyle(CellCoordinate coord) => _styles[coord];

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    if (value == null) {
      _cells.remove(coord);
    } else {
      _cells[coord] = value;
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    if (style == null) {
      _styles.remove(coord);
    } else {
      _styles[coord] = style;
    }
  }

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    // Minimal implementation
  }

  @override
  Stream<DataChangeEvent> get changes => _controller.stream;

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) {
    return _cells.entries.where((e) => range.contains(e.key));
  }

  @override
  void clearRange(CellRange range) {
    _cells.removeWhere((key, _) => range.contains(key));
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) {
    // TODO: implement batchUpdateAsync
    throw UnimplementedError();
  }

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    // Minimal implementation
  }

  @override
  void smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    // Minimal implementation
  }

  final MergedCellRegistry _mergedCells = MergedCellRegistry();

  @override
  MergedCellRegistry get mergedCells => _mergedCells;

  @override
  void mergeCells(CellRange range) {
    _mergedCells.merge(range);
  }

  @override
  void unmergeCells(CellCoordinate cell) {
    _mergedCells.unmerge(cell);
  }

  // Note: We intentionally do NOT override hasValue to test the default implementation
}

void main() {
  group('WorksheetData', () {
    group('default hasValue implementation', () {
      test('returns true when cell has value', () {
        final data = _MinimalWorksheetData();
        final coord = CellCoordinate(5, 5);

        data.setCell(coord, CellValue.text('Hello'));

        // Uses the default hasValue from abstract class
        expect(data.hasValue(coord), isTrue);

        data.dispose();
      });

      test('returns false when cell is empty', () {
        final data = _MinimalWorksheetData();
        final coord = CellCoordinate(5, 5);

        // Uses the default hasValue from abstract class
        expect(data.hasValue(coord), isFalse);

        data.dispose();
      });

      test('returns false after cell is cleared', () {
        final data = _MinimalWorksheetData();
        final coord = CellCoordinate(5, 5);

        data.setCell(coord, CellValue.number(42));
        expect(data.hasValue(coord), isTrue);

        data.setCell(coord, null);
        expect(data.hasValue(coord), isFalse);

        data.dispose();
      });
    });
  });
}
