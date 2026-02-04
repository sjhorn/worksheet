import 'package:any_date/any_date.dart';

import '../../core/data/worksheet_data.dart';
import '../../core/models/cell.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../../core/models/cell_value.dart';

/// Abstract interface for clipboard data conversion.
///
/// Override to support custom formats (binary, HTML, etc.).
abstract class ClipboardSerializer {
  /// Convert selected cells to clipboard text.
  String serialize(CellRange range, WorksheetData data);

  /// Parse clipboard text into a grid of [CellValue]s.
  ///
  /// Returns rows x columns of `CellValue?` (null = empty cell).
  List<List<CellValue?>> deserialize(String text);
}

/// Default clipboard serializer using tab-separated values.
///
/// Compatible with Excel and Google Sheets clipboard format:
/// - Columns separated by tab (`\t`)
/// - Rows separated by newline (`\n`)
class TsvClipboardSerializer implements ClipboardSerializer {
  /// Date parser for type detection during clipboard paste.
  final AnyDate? dateParser;

  const TsvClipboardSerializer({this.dateParser});

  @override
  String serialize(CellRange range, WorksheetData data) {
    final buffer = StringBuffer();
    for (int row = range.startRow; row <= range.endRow; row++) {
      if (row > range.startRow) buffer.write('\n');
      for (int col = range.startColumn; col <= range.endColumn; col++) {
        if (col > range.startColumn) buffer.write('\t');
        final coord = CellCoordinate(row, col);
        final value = data.getCell(coord);
        if (value != null) {
          final format = data.getFormat(coord);
          final cell = Cell(value: value, format: format);
          buffer.write(cell.displayValue);
        }
      }
    }
    return buffer.toString();
  }

  @override
  List<List<CellValue?>> deserialize(String text) {
    if (text.isEmpty) return [];

    final rows = text.split('\n');
    return rows.map((row) {
      final columns = row.split('\t');
      return columns.map(_parseValue).toList();
    }).toList();
  }

  CellValue? _parseValue(String text) =>
      CellValue.parse(text, allowFormulas: false, dateParser: dateParser);
}
