import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(MaterialApp(home: MySpreadsheet()));

class MySpreadsheet extends StatelessWidget {
  const MySpreadsheet({super.key});

  @override
  Widget build(BuildContext context) {
    final data = SparseWorksheetData(rowCount: 100, columnCount: 10);

    // Add some data
    data.setCell(const CellCoordinate(0, 0), CellValue.text('Name'));
    data.setCell(const CellCoordinate(0, 1), CellValue.text('Amount'));
    data.setCell(const CellCoordinate(1, 0), CellValue.text('Apples'));
    data.setCell(const CellCoordinate(1, 1), CellValue.number(42));

    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(data: data, rowCount: 100, columnCount: 10),
      ),
    );
  }
}
