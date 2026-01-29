import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(MaterialApp(home: MySpreadsheet()));

class MySpreadsheet extends StatelessWidget {
  const MySpreadsheet({super.key});

  @override
  Widget build(BuildContext context) {
    final data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): 'Name'.text,
        (0, 1): 'Amount'.text,
        (1, 0): 'Apples'.text,
        (1, 1): '42'.number,
        (2, 1): '=2+42'.formula,
        (3, 1): Cell.text('test'),
      },
    );

    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: data,
          rowCount: data.rowCount,
          columnCount: data.columnCount,
        ),
      ),
    );
  }
}
