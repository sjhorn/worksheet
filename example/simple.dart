import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(MaterialApp(home: MySpreadsheet()));

class MySpreadsheet extends StatefulWidget {
  const MySpreadsheet({super.key});

  @override
  State<MySpreadsheet> createState() => _MySpreadsheetState();
}

class _MySpreadsheetState extends State<MySpreadsheet> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): 'Name'.cell,
        (0, 1): 'Amount'.cell,
        (1, 0): 'Apples'.cell,
        (1, 1): 42.cell,
        (2, 1): '=2+42'.formula,
        (3, 1): Cell.text('test'),
        (3, 2): true.cell,
        (4, 0): 'Price'.cell,
        (4, 1): Cell.number(1234.56, format: CellFormat.currency),
        (5, 0): 'Tax'.cell,
        (5, 1): Cell.number(0.085, format: CellFormat.percentage),
        (6, 0): 'Date'.cell,
        (6, 1): Cell.date(DateTime.now(), format: CellFormat.dateIso),
        (7, 1): 1.cell,
        (7, 2): 2.cell,
        (7, 3): 3.cell,
        (8, 1): Cell.date(
          DateTime(2026, 1, 1),
          format: CellFormat(formatCode: 'mmm', type: CellFormatType.date),
        ),
        (9, 1): Cell.date(
          DateTime(2026, 2, 1),
          format: CellFormat(formatCode: 'mmm', type: CellFormatType.date),
        ),
        (10, 1): Cell.date(
          DateTime(2026, 3, 1),
          format: CellFormat(formatCode: 'mmm', type: CellFormatType.date),
        ),
      },
    );
    _editController = EditController();
  }

  @override
  void dispose() {
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}
