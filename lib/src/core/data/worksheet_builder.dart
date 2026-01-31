import 'package:worksheet/worksheet.dart';

/// A builder for creating a map of [CellCoordinate] to [Cell] entries.
///
/// Usage:
/// final cells = (WorksheetBuilder()
///   ..row(['Name'.cell, 'Amount'.cell])
///   ..row(['Apples'.cell, 42.cell])
///   ..row([const Cell(), '=2+42'.formula])
/// ).build();
///

class WorksheetBuilder {
  final _cells = <CellCoordinate, Cell>{};
  int _row = 0;

  WorksheetBuilder row(List<Cell> cells) {
    for (var col = 0; col < cells.length; col++) {
      _cells[CellCoordinate(_row, col)] = cells[col];
    }
    _row++;
    return this;
  }

  Map<CellCoordinate, Cell> build() => _cells;
}
