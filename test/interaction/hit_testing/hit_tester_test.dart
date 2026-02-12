import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
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

    group('fill handle hit testing', () {
      test('detects fill handle at bottom-right of selection', () {
        // Selection: rows 0-2, columns 0-2
        // Row 2 ends at 3*25=75, column 2 ends at 3*100=300
        // Screen position of bottom-right corner with headers (50, 30):
        // x = 50 + 300 = 350, y = 30 + 75 = 105
        // Hit near that corner
        final result = hitTester.hitTest(
          position: const Offset(349, 104),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(0, 0, 2, 2),
        );

        expect(result.type, HitTestType.fillHandle);
      });

      test('returns cell when not near fill handle', () {
        // Far from the bottom-right corner of selection
        final result = hitTester.hitTest(
          position: const Offset(60, 40),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(0, 0, 2, 2),
        );

        expect(result.type, HitTestType.cell);
        expect(result.cell, CellCoordinate(0, 0));
      });

      test('no fill handle when selectionRange is null', () {
        final result = hitTester.hitTest(
          position: const Offset(349, 104),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.cell);
      });

      test('detects fill handle with zoom', () {
        // At zoom 2.0: headers scaled to (100, 60)
        // Selection (0,0)-(1,1): row 1 ends at 50, col 1 ends at 200
        // Screen: x = 100 + 200*2 = 500, y = 60 + 50*2 = 160
        final result = hitTester.hitTest(
          position: const Offset(499, 159),
          scrollOffset: Offset.zero,
          zoom: 2.0,
          selectionRange: const CellRange(0, 0, 1, 1),
        );

        expect(result.type, HitTestType.fillHandle);
      });

      test('detects fill handle with scroll offset', () {
        // Selection: rows 2-4, columns 1-3
        // Row 4 ends at 5*25=125, column 3 ends at 4*100=400
        // With scroll (100, 50), screen corner:
        // x = 50 + (400 - 100) = 350, y = 30 + (125 - 50) = 105
        final result = hitTester.hitTest(
          position: const Offset(349, 104),
          scrollOffset: const Offset(100, 50),
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.fillHandle);
      });
    });

    group('selection border hit testing', () {
      test('detects border on top edge', () {
        // Selection: rows 2-4, columns 1-3
        // Row 2 starts at 2*25=50, column 1 starts at 1*100=100
        // Screen top edge: y = 30 + 50 = 80
        // Pointer on top edge (inside tolerance band)
        final result = hitTester.hitTest(
          position: const Offset(200, 80),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('detects border on bottom edge', () {
        // Row 4 ends at 5*25=125, screen bottom: y = 30 + 125 = 155
        final result = hitTester.hitTest(
          position: const Offset(200, 155),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('detects border on left edge', () {
        // Column 1 starts at 1*100=100, screen left: x = 50 + 100 = 150
        final result = hitTester.hitTest(
          position: const Offset(150, 120),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('detects border on right edge', () {
        // Column 3 ends at 4*100=400, screen right: x = 50 + 400 = 450
        final result = hitTester.hitTest(
          position: const Offset(450, 120),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('returns cell when well inside selection', () {
        // Center of selection: far from any border
        final result = hitTester.hitTest(
          position: const Offset(300, 120),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.cell);
      });

      test('returns cell when far outside selection', () {
        // Well outside the selection bounds
        final result = hitTester.hitTest(
          position: const Offset(60, 40),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.cell);
      });

      test('fill handle takes priority over selection border at corner', () {
        // Bottom-right corner of selection: where fill handle and border overlap
        // Row 4 ends at 125, col 3 ends at 400
        // Screen corner: (50+400, 30+125) = (450, 155)
        final result = hitTester.hitTest(
          position: const Offset(449, 154),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.fillHandle);
      });

      test('works with zoom > 1.0', () {
        // At zoom 2.0, headers scaled to (100, 60)
        // Selection (0,0)-(0,0): row 0 starts at 0, ends at 25; col 0 starts at 0, ends at 100
        // Screen top-left: (100 + 0*2, 60 + 0*2) = (100, 60)
        // Screen bottom-right: (100 + 100*2, 60 + 25*2) = (300, 110)
        // Top edge at y=60
        final result = hitTester.hitTest(
          position: const Offset(200, 60),
          scrollOffset: Offset.zero,
          zoom: 2.0,
          selectionRange: const CellRange(0, 0, 0, 0),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('works with scroll offset', () {
        // Selection: rows 2-4, columns 1-3
        // Row 2 starts at 50, col 1 starts at 100
        // With scroll (100, 50):
        // Screen top-left: (50 + (100-100), 30 + (50-50)) = (50, 30)
        // Top edge at y=30, which is in the column header area, so try left edge
        // Screen left: x = 50 + (100 - 100) = 50, which is in row header area
        // Let's use a different scroll that keeps selection visible
        // With scroll (50, 25):
        // Screen top-left: (50 + (100-50), 30 + (50-25)) = (100, 55)
        final result = hitTester.hitTest(
          position: const Offset(100, 55),
          scrollOffset: const Offset(50, 25),
          zoom: 1.0,
          selectionRange: const CellRange(2, 1, 4, 3),
        );

        expect(result.type, HitTestType.selectionBorder);
      });

      test('no selection border when selectionRange is null', () {
        // Position that would be on a border if selection existed
        final result = hitTester.hitTest(
          position: const Offset(200, 80),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(result.type, HitTestType.cell);
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
