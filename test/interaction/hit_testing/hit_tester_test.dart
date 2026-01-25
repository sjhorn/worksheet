import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_test_result.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_tester.dart';

void main() {
  group('WorksheetHitTester', () {
    late LayoutSolver layoutSolver;
    late WorksheetHitTester hitTester;

    setUp(() {
      // 1000 rows x 100 columns
      // Rows: 25px each, Columns: 100px each
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );

      hitTester = WorksheetHitTester(
        layoutSolver: layoutSolver,
        headerWidth: 50.0,
        headerHeight: 30.0,
      );
    });

    group('construction', () {
      test('creates with layout solver and header dimensions', () {
        expect(hitTester.headerWidth, 50.0);
        expect(hitTester.headerHeight, 30.0);
      });

      test('creates with zero header dimensions', () {
        final tester = WorksheetHitTester(
          layoutSolver: layoutSolver,
          headerWidth: 0,
          headerHeight: 0,
        );
        expect(tester.headerWidth, 0);
        expect(tester.headerHeight, 0);
      });
    });

    group('hitTest - cells', () {
      test('returns cell at position', () {
        // Position in cell area: (100, 50) with headers (50, 30)
        // Effective position: (50, 20) at zoom 1.0
        // Row 0 (0-25px), Col 0 (0-100px)
        final result = hitTester.hitTest(
          position: const Offset(100, 50),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.cell);
        expect(result.cell, CellCoordinate(0, 0));
      });

      test('accounts for scroll offset', () {
        // Scroll 200px right, 100px down
        // Position (150, 80) - headers (50, 30) = (100, 50) in viewport
        // Plus scroll = (300, 150) in worksheet
        // Row: 150/25 = 6, Col: 300/100 = 3
        final result = hitTester.hitTest(
          position: const Offset(150, 80),
          scrollOffset: const Offset(200, 100),
          zoom: 1.0,
        );

        expect(result.type, HitTestType.cell);
        expect(result.cell, CellCoordinate(6, 3));
      });

      test('accounts for zoom', () {
        // At zoom 2.0, headers are scaled: (50*2, 30*2) = (100, 60)
        // Position (150, 80) - scaled headers (100, 60) = (50, 20) in viewport
        // Worksheet position = (50, 20) / 2.0 = (25, 10)
        // Row: 10/25 = 0, Col: 25/100 = 0
        final result = hitTester.hitTest(
          position: const Offset(150, 80),
          scrollOffset: Offset.zero,
          zoom: 2.0,
        );

        expect(result.type, HitTestType.cell);
        expect(result.cell, CellCoordinate(0, 0));
      });

      test('accounts for zoom and scroll together', () {
        // Zoom 0.5, scroll (100, 50)
        // Headers scaled: (50*0.5, 30*0.5) = (25, 15)
        // Position (150, 80) - scaled headers (25, 15) = (125, 65) in viewport
        // Scroll in worksheet coords = (100, 50) / 0.5 = (200, 100)
        // Viewport in worksheet = (125, 65) / 0.5 = (250, 130)
        // Total worksheet position = (250+200, 130+100) = (450, 230)
        // Row: 230/25 = 9, Col: 450/100 = 4
        final result = hitTester.hitTest(
          position: const Offset(150, 80),
          scrollOffset: const Offset(100, 50),
          zoom: 0.5,
        );

        expect(result.type, HitTestType.cell);
        expect(result.cell, CellCoordinate(9, 4));
      });
    });

    group('hitTest - row header', () {
      test('returns row header when in header column', () {
        // x < headerWidth (50), y > headerHeight (30)
        final result = hitTester.hitTest(
          position: const Offset(25, 50),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.rowHeader);
        expect(result.headerIndex, 0); // First row
      });

      test('row header accounts for scroll', () {
        // Scroll down 75px (3 rows)
        final result = hitTester.hitTest(
          position: const Offset(25, 50),
          scrollOffset: const Offset(0, 75),
          zoom: 1.0,
        );

        expect(result.type, HitTestType.rowHeader);
        expect(result.headerIndex, 3);
      });
    });

    group('hitTest - column header', () {
      test('returns column header when in header row', () {
        // y < headerHeight (30), x > headerWidth (50)
        final result = hitTester.hitTest(
          position: const Offset(100, 15),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.columnHeader);
        expect(result.headerIndex, 0); // First column
      });

      test('column header accounts for scroll', () {
        // Scroll right 150px
        // Position (100, 15) - headers (50, 30) = (50, -15) in viewport
        // Worksheet X = 50 + 150 = 200 -> column 2
        final result = hitTester.hitTest(
          position: const Offset(100, 15),
          scrollOffset: const Offset(150, 0),
          zoom: 1.0,
        );

        expect(result.type, HitTestType.columnHeader);
        expect(result.headerIndex, 2);
      });
    });

    group('hitTest - corner', () {
      test('returns none for corner area', () {
        // x < headerWidth, y < headerHeight
        final result = hitTester.hitTest(
          position: const Offset(25, 15),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.none);
      });
    });

    group('hitTest - out of bounds', () {
      test('returns none for negative position', () {
        final result = hitTester.hitTest(
          position: const Offset(-10, -10),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.none);
      });
    });

    group('hitTest - resize handles', () {
      test('returns row resize handle near row edge', () {
        // Near bottom of row 0 (25px) with tolerance
        // Row header area, y position close to 30 + 25 = 55
        final result = hitTester.hitTest(
          position: const Offset(25, 54), // Just before row boundary
          scrollOffset: Offset.zero,
          zoom: 1.0,
          resizeHandleTolerance: 5.0,
        );

        expect(result.type, HitTestType.rowResizeHandle);
        expect(result.headerIndex, 0);
      });

      test('returns column resize handle near column edge', () {
        // Near right edge of column 0 (100px) with tolerance
        // Column header area, x position close to 50 + 100 = 150
        final result = hitTester.hitTest(
          position: const Offset(149, 15), // Just before column boundary
          scrollOffset: Offset.zero,
          zoom: 1.0,
          resizeHandleTolerance: 5.0,
        );

        expect(result.type, HitTestType.columnResizeHandle);
        expect(result.headerIndex, 0);
      });
    });

    group('hitTestCell', () {
      test('returns cell coordinate for position', () {
        final cell = hitTester.hitTestCell(
          position: const Offset(150, 80),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // (150-50, 80-30) = (100, 50) -> row 2, col 1
        expect(cell, CellCoordinate(2, 1));
      });

      test('returns null when outside cell area', () {
        final cell = hitTester.hitTestCell(
          position: const Offset(25, 80), // In row header
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(cell, isNull);
      });
    });

    group('screenToWorksheet', () {
      test('converts screen position to worksheet coordinates', () {
        final worksheet = hitTester.screenToWorksheet(
          screenPosition: const Offset(150, 80),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // (150-50, 80-30) = (100, 50)
        expect(worksheet, const Offset(100, 50));
      });

      test('accounts for zoom', () {
        final worksheet = hitTester.screenToWorksheet(
          screenPosition: const Offset(150, 80),
          scrollOffset: Offset.zero,
          zoom: 2.0,
        );

        // Headers scaled at zoom 2.0: (50*2, 30*2) = (100, 60)
        // (150-100, 80-60) / 2.0 = (50, 20) / 2.0 = (25, 10)
        expect(worksheet, const Offset(25, 10));
      });

      test('accounts for scroll', () {
        final worksheet = hitTester.screenToWorksheet(
          screenPosition: const Offset(150, 80),
          scrollOffset: const Offset(100, 50),
          zoom: 1.0,
        );

        // (150-50+100, 80-30+50) = (200, 100)
        expect(worksheet, const Offset(200, 100));
      });
    });

    group('worksheetToScreen', () {
      test('converts worksheet position to screen coordinates', () {
        final screen = hitTester.worksheetToScreen(
          worksheetPosition: const Offset(100, 50),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // (100+50, 50+30) = (150, 80)
        expect(screen, const Offset(150, 80));
      });

      test('accounts for zoom', () {
        final screen = hitTester.worksheetToScreen(
          worksheetPosition: const Offset(100, 50),
          scrollOffset: Offset.zero,
          zoom: 2.0,
        );

        // Headers scaled at zoom 2.0: (50*2, 30*2) = (100, 60)
        // (100*2+100, 50*2+60) = (300, 160)
        expect(screen, const Offset(300, 160));
      });

      test('accounts for scroll', () {
        final screen = hitTester.worksheetToScreen(
          worksheetPosition: const Offset(100, 50),
          scrollOffset: const Offset(50, 25),
          zoom: 1.0,
        );

        // (100-50+50, 50-25+30) = (100, 55)
        expect(screen, const Offset(100, 55));
      });
    });
  });
}
