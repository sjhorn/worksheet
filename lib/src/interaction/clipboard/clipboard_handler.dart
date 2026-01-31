import 'package:flutter/services.dart';

import 'dart:math' as math;

import '../../core/data/worksheet_data.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../controllers/selection_controller.dart';
import 'clipboard_serializer.dart';

/// Orchestrates clipboard operations (copy, cut, paste) for a worksheet.
///
/// Uses [ClipboardSerializer] to convert between cell data and clipboard text.
/// Interacts with the system clipboard via [Clipboard].
class ClipboardHandler {
  /// The worksheet data source.
  final WorksheetData data;

  /// The selection controller providing the selected range.
  final SelectionController selectionController;

  /// The serializer for clipboard text conversion.
  final ClipboardSerializer serializer;

  ClipboardHandler({
    required this.data,
    required this.selectionController,
    required this.serializer,
  });

  /// Copies the selected cells to the system clipboard as text.
  ///
  /// Does nothing if no range is selected.
  Future<void> copy() async {
    final range = selectionController.selectedRange;
    if (range == null) return;
    final text = serializer.serialize(range, data);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Cuts the selected cells: copies to clipboard then clears the source cells.
  ///
  /// Does nothing if no range is selected.
  Future<void> cut() async {
    final range = selectionController.selectedRange;
    if (range == null) return;
    final text = serializer.serialize(range, data);
    await Clipboard.setData(ClipboardData(text: text));
    data.clearRange(range);
  }

  /// Pastes from the system clipboard at the selection anchor.
  ///
  /// Parses the clipboard text into cell values and writes them into the
  /// worksheet starting at the top-left of the current selection.
  /// Values are clamped to worksheet bounds.
  ///
  /// Does nothing if no range is selected or clipboard is empty.
  Future<void> paste() async {
    final range = selectionController.selectedRange;
    if (range == null) return;
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipData?.text == null || clipData!.text!.isEmpty) return;
    final grid = serializer.deserialize(clipData.text!);
    if (grid.isEmpty) return;
    final startRow = range.startRow;
    final startCol = range.startColumn;
    final maxPasteRows = grid.length;
    final maxPasteCols = grid.fold(0, (m, row) => math.max(m, row.length));
    final endRow = math.min(startRow + maxPasteRows - 1, data.rowCount - 1);
    final endCol = math.min(startCol + maxPasteCols - 1, data.columnCount - 1);
    data.batchUpdate((batch) {
      for (int r = 0; r < grid.length; r++) {
        for (int c = 0; c < grid[r].length; c++) {
          final coord = CellCoordinate(startRow + r, startCol + c);
          if (coord.row < data.rowCount && coord.column < data.columnCount) {
            batch.setCell(coord, grid[r][c]);
          }
        }
      }
    });
    selectionController.selectRange(
      CellRange(startRow, startCol, endRow, endCol),
    );
  }
}
