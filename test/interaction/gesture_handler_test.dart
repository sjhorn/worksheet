import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/interaction/gesture_handler.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_tester.dart';

void main() {
  group('WorksheetGestureHandler', () {
    late LayoutSolver layoutSolver;
    late WorksheetHitTester hitTester;
    late SelectionController selectionController;
    late WorksheetGestureHandler handler;

    CellCoordinate? lastEditCell;
    int? lastResizeRow;
    int? lastResizeColumn;
    double? lastResizeDelta;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      hitTester = WorksheetHitTester(
        layoutSolver: layoutSolver,
        headerWidth: 50.0,
        headerHeight: 30.0,
      );
      selectionController = SelectionController();

      lastEditCell = null;
      lastResizeRow = null;
      lastResizeColumn = null;
      lastResizeDelta = null;

      handler = WorksheetGestureHandler(
        hitTester: hitTester,
        selectionController: selectionController,
        onEditCell: (cell) => lastEditCell = cell,
        onResizeRow: (row, delta) {
          lastResizeRow = row;
          lastResizeDelta = delta;
        },
        onResizeColumn: (column, delta) {
          lastResizeColumn = column;
          lastResizeDelta = delta;
        },
      );
    });

    group('tap gestures', () {
      test('tap on cell selects cell', () {
        // Tap on cell (0, 0) - positioned at (50, 30) plus cell area
        final position = const Offset(60.0, 40.0);

        handler.onTapDown(position: position, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: position, scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.hasSelection, isTrue);
        expect(selectionController.focus, equals(CellCoordinate(0, 0)));
      });

      test('tap on different cell changes selection', () {
        // First select cell (0, 0)
        handler.onTapDown(position: const Offset(60.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(60.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);

        // Then tap on cell (1, 1) - at (150, 54) based on layout
        // Column 1 starts at 100, row 1 starts at 24
        // Screen position = header + worksheet position * zoom
        // = (50, 30) + (100, 24) = (150, 54)
        handler.onTapDown(position: const Offset(155.0, 60.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(155.0, 60.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.focus, equals(CellCoordinate(1, 1)));
      });

      test('tap outside worksheet area does nothing', () {
        // Tap in header corner (should not select)
        handler.onTapDown(position: const Offset(25.0, 15.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(25.0, 15.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.hasSelection, isFalse);
      });
    });

    group('double tap', () {
      test('double tap on cell triggers edit callback', () {
        final position = const Offset(60.0, 40.0);

        handler.onDoubleTap(position: position, scrollOffset: Offset.zero, zoom: 1.0);

        expect(lastEditCell, equals(CellCoordinate(0, 0)));
      });

      test('double tap outside cell area does not trigger edit', () {
        // Double tap in header area
        handler.onDoubleTap(position: const Offset(25.0, 15.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(lastEditCell, isNull);
      });
    });

    group('drag gestures - selection', () {
      test('drag from cell extends selection', () {
        const startPos = Offset(60.0, 40.0);
        const endPos = Offset(155.0, 60.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        expect(selectionController.hasSelection, isTrue);
        expect(selectionController.anchor, equals(CellCoordinate(0, 0)));
        expect(selectionController.focus, equals(CellCoordinate(1, 1)));
      });

      test('drag can select multiple rows and columns', () {
        // Start at (0,0), drag to (2, 2)
        const startPos = Offset(60.0, 40.0);
        // Cell (2, 2) is at worksheet (200, 48), screen = (250, 78)
        const endPos = Offset(255.0, 82.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.startColumn, equals(0));
        expect(range.endRow, equals(2));
        expect(range.endColumn, equals(2));
      });
    });

    group('header selection', () {
      test('tap on row header selects entire row', () {
        // Row header area - x < headerWidth (50), y > headerHeight (30)
        // Row 0 at y = 30 + 0 = 30
        handler.onTapDown(position: const Offset(25.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(25.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.hasSelection, isTrue);
        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(0));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25)); // 26 columns (0-25)
      });

      test('tap on column header selects entire column', () {
        // Column header area - x > headerWidth (50), y < headerHeight (30)
        // Column 0 starts at x = 50
        handler.onTapDown(position: const Offset(60.0, 15.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(60.0, 15.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.hasSelection, isTrue);
        final range = selectionController.selectedRange!;
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(0));
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(99)); // 100 rows (0-99)
      });
    });

    group('resize gestures', () {
      test('provides row resize callback during drag', () {
        // Drag on row resize handle area - near row boundary in row header
        // Row 0 ends at worksheet y=24. With header=30, screen y = 30 + 24 = 54
        // But getRowAt(24) returns row 1, so we need to be just before 24
        // Screen y=53 → worksheet y = (53-30)/1 = 23, which is row 0
        // rowEnd(0) = 24, distance = |23-24| = 1 (within tolerance 4)
        const startPos = Offset(25.0, 53.0);
        const endPos = Offset(25.0, 73.0); // Drag down 20 pixels

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        expect(lastResizeRow, equals(0));
        expect(lastResizeDelta, closeTo(20.0, 0.1));
      });

      test('provides column resize callback during drag', () {
        // Drag on column resize handle area - near column boundary in column header
        // Column 0 ends at worksheet x=100. With header=50, screen x = 50 + 100 = 150
        // But getColumnAt(100) returns column 1, so we need to be just before 100
        // Screen x=149 → worksheet x = (149-50)/1 = 99, which is column 0
        // colEnd(0) = 100, distance = |99-100| = 1 (within tolerance 4)
        const startPos = Offset(149.0, 15.0);
        const endPos = Offset(179.0, 15.0); // Drag right 30 pixels

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        expect(lastResizeColumn, equals(0));
        expect(lastResizeDelta, closeTo(30.0, 0.1));
      });
    });

    group('zoom handling', () {
      test('adjusts hit testing for zoom level', () {
        // At 2x zoom, cell (0,0) appears larger
        // Cell area starts at (50, 30) header offset
        // Cell (0,0) in worksheet is (0-100, 0-24)
        // At 2x zoom, this appears as (0-200, 0-48) in viewport space
        // So position (150, 60) should still hit cell (0, 0)
        final position = const Offset(150.0, 60.0);

        handler.onTapDown(position: position, scrollOffset: Offset.zero, zoom: 2.0);
        handler.onTapUp(position: position, scrollOffset: Offset.zero, zoom: 2.0);

        expect(selectionController.focus, equals(CellCoordinate(0, 0)));
      });

      test('adjusts hit testing with scroll offset', () {
        // With scroll offset (100, 48), cell (0,0) is scrolled off
        // Cell (1, 1) at worksheet (100, 24) should be at viewport origin
        // Screen position (55, 35) with scroll (100, 48) should hit cell (1, 2)
        final scrollOffset = const Offset(100.0, 48.0);
        final position = const Offset(55.0, 35.0);

        handler.onTapDown(position: position, scrollOffset: scrollOffset, zoom: 1.0);
        handler.onTapUp(position: position, scrollOffset: scrollOffset, zoom: 1.0);

        // At scroll (100, 48): viewport origin (50, 30) shows worksheet (100, 48)
        // Position (55, 35) = viewport (5, 5) = worksheet (105, 53)
        // Column: 105 / 100 = column 1
        // Row: 53 / 24 = row 2
        expect(selectionController.focus, equals(CellCoordinate(2, 1)));
      });
    });

    test('state management', () {
      expect(handler.isResizing, isFalse);
      expect(handler.isSelectingRange, isFalse);

      handler.onDragStart(position: const Offset(60.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);
      expect(handler.isSelectingRange, isTrue);

      handler.onDragEnd();
      expect(handler.isSelectingRange, isFalse);
    });

    group('drag update edge cases', () {
      test('drag update without drag start does nothing', () {
        // Call onDragUpdate without onDragStart - should not throw
        handler.onDragUpdate(
          position: const Offset(100.0, 100.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(selectionController.hasSelection, isFalse);
      });

      test('drag end resets state correctly', () {
        handler.onDragStart(position: const Offset(60.0, 40.0), scrollOffset: Offset.zero, zoom: 1.0);
        expect(handler.isSelectingRange, isTrue);

        handler.onDragEnd();
        expect(handler.isResizing, isFalse);
        expect(handler.isSelectingRange, isFalse);

        // Subsequent drag update should do nothing
        handler.onDragUpdate(
          position: const Offset(100.0, 100.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        // Selection should remain from the drag start, not be extended
        expect(selectionController.focus, equals(CellCoordinate(0, 0)));
      });
    });

    group('row header drag selection', () {
      test('drag from row header extends row selection', () {
        // Start drag on row 0 header
        const startPos = Offset(25.0, 40.0); // Row header area, row 0
        // End drag on row 2 header (y = 30 + 2*24 = 78)
        const endPos = Offset(25.0, 82.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(2));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25)); // All columns
      });

      test('drag from row header in reverse extends row selection', () {
        // Start drag on row 2 header (y = 30 + 2*24 = 78)
        const startPos = Offset(25.0, 82.0);
        // End drag on row 0 header
        const endPos = Offset(25.0, 40.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(2));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25));
      });
    });

    group('column header drag selection', () {
      test('drag from column header extends column selection', () {
        // Start drag on column 0 header (x = 50 + 50 = 100 center of column 0)
        const startPos = Offset(60.0, 15.0);
        // End drag on column 2 header (x = 50 + 2*100 + 50 = 300)
        const endPos = Offset(260.0, 15.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(2));
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(99)); // All rows
      });

      test('drag from column header in reverse extends column selection', () {
        // Start drag on column 2 header
        const startPos = Offset(260.0, 15.0);
        // End drag on column 0 header
        const endPos = Offset(60.0, 15.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(2));
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(99));
      });
    });

    group('handler without callbacks', () {
      test('double tap without edit callback does not throw', () {
        final noCallbackHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
        );

        // Should not throw
        noCallbackHandler.onDoubleTap(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
      });

      test('resize without callbacks does not throw', () {
        final noCallbackHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
        );

        // Row resize handle position
        const startPos = Offset(25.0, 53.0);
        const endPos = Offset(25.0, 73.0);

        noCallbackHandler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        noCallbackHandler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        noCallbackHandler.onDragEnd();

        // Should complete without throwing
        expect(noCallbackHandler.isResizing, isFalse);
      });
    });

    group('resize state', () {
      test('isResizing is true during resize drag', () {
        // Row resize handle position
        const startPos = Offset(25.0, 53.0);

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        expect(handler.isResizing, isTrue);
        expect(handler.isSelectingRange, isFalse);

        handler.onDragEnd();
        expect(handler.isResizing, isFalse);
      });

      test('resize with zoom applies correct delta', () {
        // At 2x zoom, headers are scaled: width=100, height=60
        // Row 0 (0-24 in worksheet) appears at screen y=60 to 60+24*2=108
        // Resize handle for row 0 is near screen y=108
        // We need x < 100 (row header) and y close to 108
        const startPos = Offset(25.0, 106.0);
        const endPos = Offset(25.0, 146.0); // 40 pixel drag

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 2.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 2.0);
        handler.onDragEnd();

        expect(lastResizeRow, equals(0));
        // 40 pixels at 2x zoom = 20 worksheet units
        expect(lastResizeDelta, closeTo(20.0, 0.1));
      });
    });

    group('fill handle drag', () {
      test('drag from fill handle sets isFilling', () {
        // First select a range so we have a fill handle
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        final fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) {},
          onFillComplete: (source, dest) {},
          onFillCancel: () {},
        );

        // Drag from fill handle position (bottom-right corner of selection)
        // Row 2 ends at 3*24=72, Col 2 ends at 3*100=300
        // Screen: (50+300, 30+72) = (350, 102)
        const startPos = Offset(349.0, 101.0);
        fillHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(fillHandler.isFilling, isTrue);
        expect(fillHandler.isSelectingRange, isFalse);
      });

      test('drag update calls onFillPreviewUpdate with expanded range', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        CellRange? previewRange;

        final fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => previewRange = range,
          onFillComplete: (source, dest) {},
          onFillCancel: () {},
        );

        // Start at fill handle
        const startPos = Offset(349.0, 101.0);
        fillHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag down to row 4: y = 30 + 4*24 + 12 = 138
        const updatePos = Offset(155.0, 138.0);
        fillHandler.onDragUpdate(
          position: updatePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRange, isNotNull);
        // Preview should be expanded from selection (0,0)-(2,2) to include row 4
        expect(previewRange!.endRow, greaterThanOrEqualTo(3));
      });

      test('drag end calls onFillComplete with source range and destination', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        CellRange? completedSource;
        CellCoordinate? completedDest;

        final fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) {},
          onFillComplete: (source, dest) {
            completedSource = source;
            completedDest = dest;
          },
          onFillCancel: () {},
        );

        // Start at fill handle
        const startPos = Offset(349.0, 101.0);
        fillHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag down
        const updatePos = Offset(155.0, 138.0);
        fillHandler.onDragUpdate(
          position: updatePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        fillHandler.onDragEnd();

        expect(completedSource, const CellRange(0, 0, 2, 2));
        expect(completedDest, isNotNull);
        expect(fillHandler.isFilling, isFalse);
      });

      test('short drag with no update calls onFillCancel', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        bool cancelCalled = false;

        final fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) {},
          onFillComplete: (source, dest) {},
          onFillCancel: () => cancelCalled = true,
        );

        // Start at fill handle
        const startPos = Offset(349.0, 101.0);
        fillHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // End immediately without update
        fillHandler.onDragEnd();

        expect(cancelCalled, isTrue);
        expect(fillHandler.isFilling, isFalse);
      });
    });

    group('mixed drag scenarios', () {
      test('drag from cell to header area extends to cell', () {
        // Start in cell area, drag to row header - should still extend cell selection
        const startPos = Offset(60.0, 40.0); // Cell (0, 0)
        const endPos = Offset(25.0, 60.0); // Row header area

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        // Selection should be from the cells, not row headers
        expect(selectionController.hasSelection, isTrue);
      });

      test('drag from row header to cell area stays as full row selection', () {
        // Start in row header (row 0), drag into cell area (row 1)
        const startPos = Offset(25.0, 40.0); // Row header, row 0
        // Cell area position at row 1: y = 30 + 24 + 12 = 66
        const endPos = Offset(200.0, 66.0); // Deep in cell area, row 1

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        // Should be full row selection (rows 0-1, all columns)
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(1));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25)); // All 26 columns
      });

      test('drag from column header to cell area stays as full column selection', () {
        // Start in column header (column 0), drag into cell area
        const startPos = Offset(60.0, 15.0); // Column header, column 0
        // Cell area position at column 2: x = 50 + 200 + 50 = 300
        const endPos = Offset(300.0, 200.0); // Deep in cell area, column 2

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        // Should be full column selection (columns 0-2, all rows)
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(2));
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(99)); // All 100 rows
      });

      test('drag from row header to column header area stays as row selection', () {
        // Start in row header (row 2), drag to column header area
        const startPos = Offset(25.0, 82.0); // Row header, row 2
        // Column header area: y < 30, x > 50
        const endPos = Offset(200.0, 15.0); // Column header area

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragUpdate(position: endPos, scrollOffset: Offset.zero, zoom: 1.0);
        handler.onDragEnd();

        final range = selectionController.selectedRange!;
        // The y position in column header area maps to a negative worksheet y
        // which returns row -1, so the selection should not update.
        // The initial selection from onDragStart (row 2) should remain.
        expect(range.startRow, equals(2));
        expect(range.endRow, equals(2));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25));
      });

      test('row header drag with multiple updates through cell area', () {
        // Simulate a drag that starts in row header, moves through cell area,
        // then continues further down
        const startPos = Offset(25.0, 40.0); // Row header, row 0

        handler.onDragStart(position: startPos, scrollOffset: Offset.zero, zoom: 1.0);

        // Drag drifts into cell area at row 1
        handler.onDragUpdate(
          position: const Offset(100.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        var range = selectionController.selectedRange!;
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25)); // Still full rows

        // Continue dragging further into cell area at row 3
        handler.onDragUpdate(
          position: const Offset(300.0, 110.0), // row 3: y = 30 + 3*24 + 8
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.endRow, equals(3));
        expect(range.startColumn, equals(0));
        expect(range.endColumn, equals(25)); // Still full rows

        handler.onDragEnd();
      });
    });
  });
}
