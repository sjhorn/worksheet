import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';

void main() {
  group('LayoutSolver', () {
    late LayoutSolver solver;

    setUp(() {
      solver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
    });

    group('construction', () {
      test('creates with row and column span lists', () {
        expect(solver.rowCount, 1000);
        expect(solver.columnCount, 100);
      });

      test('exposes default sizes', () {
        expect(solver.defaultRowHeight, 25.0);
        expect(solver.defaultColumnWidth, 100.0);
      });

      test('calculates total content size', () {
        expect(solver.totalHeight, 25000.0); // 1000 * 25
        expect(solver.totalWidth, 10000.0); // 100 * 100
        expect(solver.totalSize, const Size(10000.0, 25000.0));
      });
    });

    group('getCellBounds', () {
      test('returns bounds for cell at origin', () {
        final bounds = solver.getCellBounds(CellCoordinate(0, 0));
        expect(bounds.left, 0.0);
        expect(bounds.top, 0.0);
        expect(bounds.width, 100.0);
        expect(bounds.height, 25.0);
      });

      test('returns bounds for cell at offset', () {
        final bounds = solver.getCellBounds(CellCoordinate(5, 3));
        expect(bounds.left, 300.0); // 3 * 100
        expect(bounds.top, 125.0); // 5 * 25
        expect(bounds.width, 100.0);
        expect(bounds.height, 25.0);
      });

      test('returns bounds with custom row height', () {
        solver.setRowHeight(2, 50.0);
        final bounds = solver.getCellBounds(CellCoordinate(3, 0));
        // row 0: 0-25, row 1: 25-50, row 2: 50-100 (custom), row 3: 100-125
        expect(bounds.top, 100.0);
        expect(bounds.height, 25.0);
      });

      test('returns bounds with custom column width', () {
        solver.setColumnWidth(1, 200.0);
        final bounds = solver.getCellBounds(CellCoordinate(0, 2));
        // col 0: 0-100, col 1: 100-300 (custom), col 2: 300-400
        expect(bounds.left, 300.0);
        expect(bounds.width, 100.0);
      });
    });

    group('getCellAt', () {
      test('returns cell at origin', () {
        final coord = solver.getCellAt(const Offset(0, 0));
        expect(coord, CellCoordinate(0, 0));
      });

      test('returns cell at offset', () {
        final coord = solver.getCellAt(const Offset(150, 75));
        // x=150 is in column 1 (100-200), y=75 is in row 3 (75-100)
        expect(coord, CellCoordinate(3, 1));
      });

      test('returns cell at boundary', () {
        final coord = solver.getCellAt(const Offset(100, 25));
        // x=100 is start of column 1, y=25 is start of row 1
        expect(coord, CellCoordinate(1, 1));
      });

      test('returns null for negative position', () {
        expect(solver.getCellAt(const Offset(-1, 0)), isNull);
        expect(solver.getCellAt(const Offset(0, -1)), isNull);
      });

      test('returns null for position beyond content', () {
        expect(solver.getCellAt(const Offset(10000, 0)), isNull);
        expect(solver.getCellAt(const Offset(0, 25000)), isNull);
      });

      test('handles custom sizes', () {
        solver.setRowHeight(0, 50.0);
        solver.setColumnWidth(0, 200.0);

        // Position (100, 30) should be in cell (0, 0) with custom sizes
        final coord = solver.getCellAt(const Offset(100, 30));
        expect(coord, CellCoordinate(0, 0));

        // Position (250, 60) should be in cell (1, 1)
        final coord2 = solver.getCellAt(const Offset(250, 60));
        expect(coord2, CellCoordinate(1, 1));
      });
    });

    group('getRowAt', () {
      test('returns row index for y position', () {
        expect(solver.getRowAt(0), 0);
        expect(solver.getRowAt(24.9), 0);
        expect(solver.getRowAt(25), 1);
        expect(solver.getRowAt(100), 4);
      });

      test('returns -1 for invalid position', () {
        expect(solver.getRowAt(-1), -1);
        expect(solver.getRowAt(25000), -1);
      });
    });

    group('getColumnAt', () {
      test('returns column index for x position', () {
        expect(solver.getColumnAt(0), 0);
        expect(solver.getColumnAt(99.9), 0);
        expect(solver.getColumnAt(100), 1);
        expect(solver.getColumnAt(500), 5);
      });

      test('returns -1 for invalid position', () {
        expect(solver.getColumnAt(-1), -1);
        expect(solver.getColumnAt(10000), -1);
      });
    });

    group('getRowTop', () {
      test('returns top position for row', () {
        expect(solver.getRowTop(0), 0.0);
        expect(solver.getRowTop(1), 25.0);
        expect(solver.getRowTop(10), 250.0);
      });

      test('returns total height for row count', () {
        expect(solver.getRowTop(1000), 25000.0);
      });
    });

    group('getColumnLeft', () {
      test('returns left position for column', () {
        expect(solver.getColumnLeft(0), 0.0);
        expect(solver.getColumnLeft(1), 100.0);
        expect(solver.getColumnLeft(10), 1000.0);
      });

      test('returns total width for column count', () {
        expect(solver.getColumnLeft(100), 10000.0);
      });
    });

    group('getRowHeight', () {
      test('returns default height', () {
        expect(solver.getRowHeight(0), 25.0);
        expect(solver.getRowHeight(50), 25.0);
      });

      test('returns custom height after setting', () {
        solver.setRowHeight(5, 50.0);
        expect(solver.getRowHeight(5), 50.0);
        expect(solver.getRowHeight(4), 25.0);
      });
    });

    group('getColumnWidth', () {
      test('returns default width', () {
        expect(solver.getColumnWidth(0), 100.0);
        expect(solver.getColumnWidth(50), 100.0);
      });

      test('returns custom width after setting', () {
        solver.setColumnWidth(3, 200.0);
        expect(solver.getColumnWidth(3), 200.0);
        expect(solver.getColumnWidth(2), 100.0);
      });
    });

    group('setRowHeight', () {
      test('updates row height and recalculates positions', () {
        solver.setRowHeight(0, 50.0);

        expect(solver.getRowHeight(0), 50.0);
        expect(solver.getRowTop(1), 50.0); // Was 25, now 50
        expect(solver.totalHeight, 25025.0); // Added 25
      });
    });

    group('setColumnWidth', () {
      test('updates column width and recalculates positions', () {
        solver.setColumnWidth(0, 200.0);

        expect(solver.getColumnWidth(0), 200.0);
        expect(solver.getColumnLeft(1), 200.0); // Was 100, now 200
        expect(solver.totalWidth, 10100.0); // Added 100
      });
    });

    group('getVisibleRows', () {
      test('returns row range for viewport', () {
        final range = solver.getVisibleRows(0, 100);
        expect(range.startIndex, 0);
        expect(range.endIndex, 3); // rows 0-3 fit in 100px (4 rows * 25px)
      });

      test('returns row range for offset viewport', () {
        final range = solver.getVisibleRows(50, 100);
        // y=50 is in row 2, y=150 is in row 5
        expect(range.startIndex, 2);
        expect(range.endIndex, 5);
      });

      test('clamps to valid range', () {
        final range = solver.getVisibleRows(24900, 200);
        expect(range.startIndex, 996);
        expect(range.endIndex, 999);
      });
    });

    group('getVisibleColumns', () {
      test('returns column range for viewport', () {
        final range = solver.getVisibleColumns(0, 350);
        expect(range.startIndex, 0);
        expect(range.endIndex, 3); // cols 0-3 fit in 350px
      });

      test('returns column range for offset viewport', () {
        final range = solver.getVisibleColumns(150, 300);
        // x=150 is in col 1, x=450 is in col 4
        expect(range.startIndex, 1);
        expect(range.endIndex, 4);
      });
    });

    group('getRangeBounds', () {
      test('returns bounds for cell range', () {
        final bounds = solver.getRangeBounds(
          startRow: 1,
          startColumn: 2,
          endRow: 3,
          endColumn: 4,
        );

        expect(bounds.left, 200.0); // col 2 starts at 200
        expect(bounds.top, 25.0); // row 1 starts at 25
        expect(bounds.width, 300.0); // cols 2,3,4 = 3 * 100
        expect(bounds.height, 75.0); // rows 1,2,3 = 3 * 25
      });

      test('returns bounds for single cell range', () {
        final bounds = solver.getRangeBounds(
          startRow: 5,
          startColumn: 5,
          endRow: 5,
          endColumn: 5,
        );

        expect(bounds.left, 500.0);
        expect(bounds.top, 125.0);
        expect(bounds.width, 100.0);
        expect(bounds.height, 25.0);
      });
    });
  });
}
