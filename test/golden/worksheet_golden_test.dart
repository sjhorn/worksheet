import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  testWidgets('worksheet screenshot', (tester) async {
    // Create sample data
    final data = SparseWorksheetData(rowCount: 100, columnCount: 26);

    // Add header row
    final headers = ['Product', 'Q1', 'Q2', 'Q3', 'Q4', 'Total'];
    for (var col = 0; col < headers.length; col++) {
      data.setCell(CellCoordinate(0, col), CellValue.text(headers[col]));
      data.setStyle(
        CellCoordinate(0, col),
        const CellStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFF4472C4),
          textColor: Color(0xFFFFFFFF),
        ),
      );
    }

    // Add sample data rows
    final products = ['Widgets', 'Gadgets', 'Sprockets', 'Gizmos', 'Doodads'];
    for (var row = 0; row < products.length; row++) {
      data.setCell(CellCoordinate(row + 1, 0), CellValue.text(products[row]));

      // Quarterly values
      for (var q = 0; q < 4; q++) {
        final value = (row + 1) * 1000 + (q + 1) * 100 + row * 50;
        data.setCell(CellCoordinate(row + 1, q + 1), CellValue.number(value.toDouble()));
      }

      // Total formula display
      final total = (row + 1) * 1000 * 4 + 1000 + row * 200;
      data.setCell(CellCoordinate(row + 1, 5), CellValue.number(total.toDouble()));
      data.setStyle(
        CellCoordinate(row + 1, 5),
        const CellStyle(fontWeight: FontWeight.bold),
      );
    }

    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 300,
            child: WorksheetTheme(
              data: const WorksheetThemeData(
                defaultColumnWidth: 80,
                defaultRowHeight: 28,
                rowHeaderWidth: 40,
                columnHeaderHeight: 28,
              ),
              child: Worksheet(
                data: data,
                rowCount: 100,
                columnCount: 26,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('worksheet_screenshot.png'),
    );
  });
}
