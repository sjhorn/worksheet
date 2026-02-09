@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  const Size surfaceSize = Size(700, 350);

  setUpAll(() async {
    // Load all Roboto variants under the package-resolved name.
    // When a package declares fonts, Flutter registers them as
    // 'packages/<package>/<family>', so golden tests must match.
    final fontLoader = FontLoader('packages/worksheet/Roboto');
    for (final fileName in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Italic.ttf',
      'Roboto-BoldItalic.ttf',
    ]) {
      final fontData = File('assets/fonts/$fileName').readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    }
    await fontLoader.load();
  });

  testWidgets('worksheet screenshot', (tester) async {
    // Set surface size for consistent golden rendering
    await tester.binding.setSurfaceSize(surfaceSize);
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;

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
          borders: CellBorders(
            bottom: BorderStyle(
              color: Color(0xFF2E5A94),
              width: 2.0,
              lineStyle: BorderLineStyle.solid,
            ),
          ),
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
        data.setCell(
            CellCoordinate(row + 1, q + 1), CellValue.number(value.toDouble()));
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
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: WorksheetTheme(
            data: const WorksheetThemeData(
              fontFamily: 'Roboto',
              defaultColumnWidth: 90,
              defaultRowHeight: 30,
              rowHeaderWidth: 45,
              columnHeaderHeight: 30,
            ),
            child: Worksheet(
              data: data,
              rowCount: 100,
              columnCount: 26,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('worksheet_screenshot.png'),
    );

    // Reset surface size
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
