import 'package:worksheet/worksheet.dart';

/// A builder for creating a map of [CellCoordinate] to [Cell] entries.
///
/// Usage:
/// final cells = (WorksheetBuilder()
///   ..row(['Name'.text, 'Amount'.text])
///   ..row(['Apples'.text, 42.number])
///   ..row([Cell.empty, '=2+42'.formula])
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
