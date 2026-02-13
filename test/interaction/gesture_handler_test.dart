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

        // Then tap on cell (1, 1) - center of cell
        // Column 1: x = 100..200 (worksheet), screen x = 150..250
        // Row 1: y = 24..48 (worksheet), screen y = 54..78
        // Center: (200, 66) — well away from any fill handle
        handler.onTapDown(position: const Offset(200.0, 66.0), scrollOffset: Offset.zero, zoom: 1.0);
        handler.onTapUp(position: const Offset(200.0, 66.0), scrollOffset: Offset.zero, zoom: 1.0);

        expect(selectionController.focus, equals(CellCoordinate(1, 1)));
      });

      test('shift+click extends selection from anchor to new cell', () {
        // Simulate full pointer-down sequence: onTapDown then onDragStart
        // First select cell (0, 0)
        handler.onTapDown(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragStart(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragEnd();

        // Shift+click on cell (2, 2)
        // Column 2: x = 200..300 (worksheet), screen x = 250..350
        // Row 2: y = 48..72 (worksheet), screen y = 78..102
        handler.onTapDown(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragStart(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragEnd();

        expect(selectionController.hasSelection, isTrue);
        // Anchor stays at original cell
        expect(selectionController.anchor, equals(CellCoordinate(0, 0)));
        // Focus moves to shift-clicked cell
        expect(selectionController.focus, equals(CellCoordinate(2, 2)));
        // Range covers A1:C3
        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.startColumn, equals(0));
        expect(range.endRow, equals(2));
        expect(range.endColumn, equals(2));
      });

      test('shift+click with no prior selection behaves like normal click', () {
        expect(selectionController.hasSelection, isFalse);

        // Shift+click without any prior selection
        handler.onTapDown(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragStart(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragEnd();

        // Should behave like a normal click — select single cell
        expect(selectionController.hasSelection, isTrue);
        expect(selectionController.anchor, equals(CellCoordinate(2, 2)));
        expect(selectionController.focus, equals(CellCoordinate(2, 2)));
      });

      test('non-shift click after shift-extended selection resets to single cell', () {
        // Select cell (0, 0)
        handler.onTapDown(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragStart(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragEnd();

        // Shift+click to extend to (2, 2)
        handler.onTapDown(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragStart(
          position: const Offset(260.0, 82.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          isShiftPressed: true,
        );
        handler.onDragEnd();

        // Verify extended selection
        expect(selectionController.selectedRange!.endRow, equals(2));
        expect(selectionController.selectedRange!.endColumn, equals(2));

        // Normal click on cell (1, 1) — should reset to single cell
        handler.onTapDown(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        handler.onDragEnd();

        expect(selectionController.anchor, equals(CellCoordinate(1, 1)));
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

      test('onTapDown on fill handle does not collapse selection', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        // Tap at the fill handle position — should NOT collapse the selection
        // Fill handle is at bottom-right of (0,0)-(2,2): screen (350, 102)
        handler.onTapDown(
          position: const Offset(349.0, 101.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Selection should remain as the original range, not collapse to single cell
        final range = selectionController.selectedRange!;
        expect(range, const CellRange(0, 0, 2, 2));
      });

      test('fill source range preserves original multi-cell selection', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        CellRange? completedSource;

        final fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) {},
          onFillComplete: (source, dest) {
            completedSource = source;
          },
          onFillCancel: () {},
        );

        // Simulate full pointer-down flow: onTapDown then onDragStart
        const fillHandlePos = Offset(349.0, 101.0);
        fillHandler.onTapDown(
          position: fillHandlePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        fillHandler.onDragStart(
          position: fillHandlePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag down
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 138.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        fillHandler.onDragEnd();

        // Source should be the original multi-cell range, not a single cell
        expect(completedSource, const CellRange(0, 0, 2, 2));
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

    group('fill axis constraint', () {
      // Layout: headerWidth=50, headerHeight=30, rowHeight=24, colWidth=100
      // Selection (0,0)-(2,2): rows 0-72, cols 0-300
      // Fill handle at screen (350, 102)
      // Cell (r,c) screen position: (50 + c*100 + 50, 30 + r*24 + 12)

      late WorksheetGestureHandler fillHandler;
      late List<CellRange> previewRanges;
      CellRange? completedSource;
      CellCoordinate? completedDest;

      setUp(() {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));
        previewRanges = [];
        completedSource = null;
        completedDest = null;

        fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => previewRanges.add(range),
          onFillComplete: (source, dest) {
            completedSource = source;
            completedDest = dest;
          },
          onFillCancel: () {},
        );
      });

      void startFillDrag() {
        fillHandler.onDragStart(
          position: const Offset(349.0, 101.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
      }

      test('drag down locks to vertical axis', () {
        startFillDrag();

        // Drag to row 4, col 1 (inside source cols) — screen (200, 138)
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 138.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        // Vertical: rows expand, columns stay as source
        expect(preview.startRow, 0);
        expect(preview.endRow, 4);
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 2);
      });

      test('drag right locks to horizontal axis', () {
        startFillDrag();

        // Drag to col 4 (x = 50 + 4*100 + 50 = 500), row 1 (inside source rows)
        // Screen: (500, 60)
        fillHandler.onDragUpdate(
          position: const Offset(500.0, 60.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        // Horizontal: columns expand, rows stay as source
        expect(preview.startRow, 0);
        expect(preview.endRow, 2);
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 4);
      });

      test('drag up locks to vertical axis', () {
        // Select range (3,0)-(5,2) so we can drag up
        selectionController.selectRange(const CellRange(3, 0, 5, 2));
        fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => previewRanges.add(range),
          onFillComplete: (source, dest) {
            completedSource = source;
            completedDest = dest;
          },
          onFillCancel: () {},
        );

        // Fill handle for (3,0)-(5,2): row 5 ends at 144, col 2 ends at 300
        // Screen: (350, 174)
        fillHandler.onDragStart(
          position: const Offset(349.0, 173.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag up to row 1: screen y = 30 + 1*24 + 12 = 66
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        expect(preview.startRow, 1);
        expect(preview.endRow, 5);
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 2);
      });

      test('drag left locks to horizontal axis', () {
        // Select range (0,3)-(2,5)
        selectionController.selectRange(const CellRange(0, 3, 2, 5));
        fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => previewRanges.add(range),
          onFillComplete: (source, dest) {
            completedSource = source;
            completedDest = dest;
          },
          onFillCancel: () {},
        );

        // Fill handle for (0,3)-(2,5): row 2 ends at 72, col 5 ends at 600
        // Screen: (650, 102)
        fillHandler.onDragStart(
          position: const Offset(649.0, 101.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag left to col 1: screen x = 50 + 1*100 + 50 = 200
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 60.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        expect(preview.startRow, 0);
        expect(preview.endRow, 2);
        expect(preview.startColumn, 1);
        expect(preview.endColumn, 5);
      });

      test('diagonal drag locks to axis with greater pixel displacement', () {
        startFillDrag();

        // Drag diagonally: more vertical (dy=80) than horizontal (dx=20)
        // From start (349, 101) to (369, 181) — cell outside both axes
        // Cell at that position: row = (181-30)/24 = ~6, col = (369-50)/100 = ~3
        fillHandler.onDragUpdate(
          position: const Offset(369.0, 181.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        // Vertical wins (dy=80 > dx=20): columns stay as source
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 2);
        expect(preview.endRow, greaterThan(2));
      });

      test('diagonal drag locks horizontal when dx > dy', () {
        startFillDrag();

        // Drag diagonally: more horizontal (dx=200) than vertical (dy=30)
        // From start (349, 101) to (549, 131)
        fillHandler.onDragUpdate(
          position: const Offset(549.0, 131.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        // Horizontal wins: rows stay as source
        expect(preview.startRow, 0);
        expect(preview.endRow, 2);
        expect(preview.endColumn, greaterThan(2));
      });

      test('axis lock persists across subsequent updates', () {
        startFillDrag();

        // First update: drag down (locks vertical)
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 138.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        expect(previewRanges.last.endColumn, 2); // Locked to source cols

        // Second update: drag far to the right — should still be vertical
        fillHandler.onDragUpdate(
          position: const Offset(600.0, 160.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(2));
        final preview = previewRanges.last;
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 2); // Still locked to source cols
      });

      test('cursor inside source range with no lock triggers no preview', () {
        startFillDrag();

        // Drag to cell (1,1) which is inside source range (0,0)-(2,2)
        // Screen: (50 + 100 + 50, 30 + 24 + 12) = (200, 66)
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, isEmpty);
      });

      test('axis resets between drags', () {
        startFillDrag();

        // Lock vertical
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 138.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        expect(previewRanges.last.endColumn, 2);

        fillHandler.onDragEnd();
        previewRanges.clear();

        // New drag — should be able to lock horizontal
        fillHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => previewRanges.add(range),
          onFillComplete: (source, dest) {},
          onFillCancel: () {},
        );

        selectionController.selectRange(const CellRange(0, 0, 2, 2));
        fillHandler.onDragStart(
          position: const Offset(349.0, 101.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag right
        fillHandler.onDragUpdate(
          position: const Offset(500.0, 60.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        expect(preview.endRow, 2); // Locked to source rows
        expect(preview.endColumn, greaterThan(2));
      });

      test('single-cell source allows free expansion without axis constraint', () {
        // Select a single cell
        selectionController.selectRange(const CellRange(2, 2, 2, 2));
        final singleCellPreviewRanges = <CellRange>[];

        final singleHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onFillPreviewUpdate: (range) => singleCellPreviewRanges.add(range),
          onFillComplete: (source, dest) {},
          onFillCancel: () {},
        );

        // Fill handle for single cell (2,2): row 2 ends at 72, col 2 ends at 300
        // Screen: (350, 102)
        singleHandler.onDragStart(
          position: const Offset(349.0, 101.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag diagonally to (5, 4): both row and column outside source
        // Screen: (50 + 4*100 + 50, 30 + 5*24 + 12) = (500, 162)
        singleHandler.onDragUpdate(
          position: const Offset(500.0, 162.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(singleCellPreviewRanges, hasLength(1));
        final preview = singleCellPreviewRanges.last;
        // Should expand freely in both dimensions
        expect(preview.startRow, 2);
        expect(preview.startColumn, 2);
        expect(preview.endRow, 5);
        expect(preview.endColumn, 4);
      });

      test('fill complete reports constrained destination', () {
        startFillDrag();

        // Drag down to row 4
        fillHandler.onDragUpdate(
          position: const Offset(200.0, 138.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        fillHandler.onDragEnd();

        expect(completedSource, const CellRange(0, 0, 2, 2));
        expect(completedDest, isNotNull);
        // Constrained: column pinned to source.endColumn (2)
        expect(completedDest!.column, 2);
        expect(completedDest!.row, greaterThanOrEqualTo(3));
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

    group('auto-fit on double-click', () {
      test('double-click on column resize handle fires onAutoFitColumn', () {
        int? autoFitColumn;
        final autoFitHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onAutoFitColumn: (col) => autoFitColumn = col,
          onAutoFitRow: (row) {},
        );

        // Column 0 resize handle: near column boundary in column header
        // Column 0 ends at worksheet x=100. Screen x = 50 + 100 = 150
        // Screen x=149 → within tolerance of column 0 right edge
        autoFitHandler.onDoubleTap(
          position: const Offset(149.0, 15.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(autoFitColumn, equals(0));
      });

      test('double-click on row resize handle fires onAutoFitRow', () {
        int? autoFitRow;
        final autoFitHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onAutoFitColumn: (col) {},
          onAutoFitRow: (row) => autoFitRow = row,
        );

        // Row 0 resize handle: near row boundary in row header
        // Row 0 ends at worksheet y=24. Screen y = 30 + 24 = 54
        // Screen y=53 → within tolerance of row 0 bottom edge
        autoFitHandler.onDoubleTap(
          position: const Offset(25.0, 53.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(autoFitRow, equals(0));
      });

      test('auto-fit double-click resets drag state so onDragEnd is a no-op',
          () {
        // Simulates the real double-click sequence:
        // 1. Listener.onPointerDown → onDragStart (sets _isResizing)
        // 2. GestureDetector.onDoubleTapDown → onDoubleTap (auto-fit)
        // 3. Listener.onPointerUp → onDragEnd
        // Without the fix, step 3 would fire onResizeColumnEnd.
        int? autoFitColumn;
        bool resizeEndCalled = false;
        final handler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onAutoFitColumn: (col) => autoFitColumn = col,
          onResizeColumnEnd: (col) => resizeEndCalled = true,
        );

        // Column 0 right edge: headerWidth(50) + colWidth(100) = 150
        // Near the right border at y=15 (in column header)
        const pos = Offset(149.0, 15.0);

        // Step 1: onDragStart (from Listener.onPointerDown)
        handler.onDragStart(
          position: pos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        expect(handler.isResizing, isTrue);

        // Step 2: onDoubleTap (from GestureDetector.onDoubleTapDown)
        handler.onDoubleTap(
          position: pos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );
        expect(autoFitColumn, equals(0));
        // Drag state should be reset
        expect(handler.isResizing, isFalse);

        // Step 3: onDragEnd (from Listener.onPointerUp)
        handler.onDragEnd();
        // Must NOT fire onResizeColumnEnd
        expect(resizeEndCalled, isFalse);
      });

      test('double-click on cell does not fire auto-fit', () {
        int? autoFitColumn;
        int? autoFitRow;
        CellCoordinate? editedCell;
        final autoFitHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onAutoFitColumn: (col) => autoFitColumn = col,
          onAutoFitRow: (row) => autoFitRow = row,
          onEditCell: (cell) => editedCell = cell,
        );

        // Double-click on cell (0, 0)
        autoFitHandler.onDoubleTap(
          position: const Offset(60.0, 40.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(autoFitColumn, isNull);
        expect(autoFitRow, isNull);
        expect(editedCell, equals(CellCoordinate(0, 0)));
      });
    });

    group('drag-to-move selection', () {
      test('drag from selection border sets isMoving', () {
        selectionController.selectRange(const CellRange(1, 1, 3, 3));

        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) {},
          onMoveComplete: (source, dest) {},
          onMoveCancel: () {},
        );

        // Selection border: top edge of (1,1)-(3,3)
        // Row 1 starts at y=24, col 1 starts at x=100
        // Screen: (50+100, 30+24) = (150, 54) — top-left of selection
        // Border tolerance is 4 pixels, so just inside the border ring
        const borderPos = Offset(200.0, 53.0);
        moveHandler.onDragStart(
          position: borderPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(moveHandler.isMoving, isTrue);
        expect(moveHandler.isSelectingRange, isFalse);
        expect(moveHandler.isFilling, isFalse);
      });

      test('drag update calls onMovePreviewUpdate with correct range', () {
        selectionController.selectRange(const CellRange(1, 1, 2, 2));

        CellRange? movePreview;
        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) => movePreview = range,
          onMoveComplete: (source, dest) {},
          onMoveCancel: () {},
        );

        // Start at top edge of selection
        // Row 1 at y=24, screen y = 30+24 = 54 → border at 54-2 = 52
        const startPos = Offset(200.0, 53.0);
        moveHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag to cell (5, 5): screen = (50 + 5*100 + 50, 30 + 5*24 + 12) = (600, 162)
        moveHandler.onDragUpdate(
          position: const Offset(600.0, 162.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(movePreview, isNotNull);
        // Source is 2x2 (rows 1-2, cols 1-2), destination cell is (5,5)
        // Preview should be (5,5)-(6,6)
        expect(movePreview!.startRow, 5);
        expect(movePreview!.startColumn, 5);
        expect(movePreview!.endRow, 6);
        expect(movePreview!.endColumn, 6);
      });

      test('drag end calls onMoveComplete with source and destination', () {
        selectionController.selectRange(const CellRange(0, 0, 1, 1));

        CellRange? completedSource;
        CellCoordinate? completedDest;
        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) {},
          onMoveComplete: (source, dest) {
            completedSource = source;
            completedDest = dest;
          },
          onMoveCancel: () {},
        );

        // Start at border of selection (0,0)-(1,1)
        // Bottom edge: row 1 ends at 48, screen y = 30+48 = 78
        const startPos = Offset(100.0, 77.0);
        moveHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Drag to cell (5, 3)
        const updatePos = Offset(400.0, 162.0);
        moveHandler.onDragUpdate(
          position: updatePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        moveHandler.onDragEnd();

        expect(completedSource, const CellRange(0, 0, 1, 1));
        expect(completedDest, isNotNull);
        expect(moveHandler.isMoving, isFalse);
      });

      test('drag end without update calls onMoveCancel', () {
        selectionController.selectRange(const CellRange(0, 0, 1, 1));

        bool cancelCalled = false;
        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) {},
          onMoveComplete: (source, dest) {},
          onMoveCancel: () => cancelCalled = true,
        );

        const startPos = Offset(100.0, 77.0);
        moveHandler.onDragStart(
          position: startPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // End immediately without update
        moveHandler.onDragEnd();

        expect(cancelCalled, isTrue);
        expect(moveHandler.isMoving, isFalse);
      });

      test('move does not trigger on cell drag (not border)', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) {},
          onMoveComplete: (source, dest) {},
          onMoveCancel: () {},
        );

        // Click in center of cell (1,1) — well inside the selection, not border
        // Cell (1,1) center: screen (200, 66)
        const cellCenter = Offset(200.0, 66.0);
        moveHandler.onDragStart(
          position: cellCenter,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(moveHandler.isMoving, isFalse);
        expect(moveHandler.isSelectingRange, isTrue);
      });

      test('move does not trigger on fill handle drag', () {
        selectionController.selectRange(const CellRange(0, 0, 2, 2));

        final moveHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onMovePreviewUpdate: (range) {},
          onMoveComplete: (source, dest) {},
          onMoveCancel: () {},
          onFillPreviewUpdate: (range) {},
          onFillComplete: (source, dest) {},
          onFillCancel: () {},
        );

        // Fill handle at bottom-right of (0,0)-(2,2): screen (350, 102)
        const fillPos = Offset(349.0, 101.0);
        moveHandler.onDragStart(
          position: fillPos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(moveHandler.isMoving, isFalse);
        expect(moveHandler.isFilling, isTrue);
      });
    });

    group('border double-click jump', () {
      test('double-click on top edge fires onJumpToEdge with up direction', () {
        selectionController.selectRange(const CellRange(5, 5, 7, 7));

        CellCoordinate? jumpFrom;
        int? jumpRowDelta;
        int? jumpColDelta;
        final jumpHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onJumpToEdge: (from, rowDelta, colDelta) {
            jumpFrom = from;
            jumpRowDelta = rowDelta;
            jumpColDelta = colDelta;
          },
        );

        // Top edge of selection (5,5)-(7,7):
        // Row 5 starts at y=120, col 5-7 spans x=500-800
        // Screen: top edge y = 30 + 120 = 150
        // Position on top edge: (650, 150) — tolerance check
        const topEdgePos = Offset(700.0, 149.0);
        jumpHandler.onDoubleTap(
          position: topEdgePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(jumpFrom, isNotNull);
        expect(jumpRowDelta, equals(-1));
        expect(jumpColDelta, equals(0));
      });

      test('double-click on right edge fires onJumpToEdge with right direction', () {
        selectionController.selectRange(const CellRange(2, 2, 4, 4));

        CellCoordinate? jumpFrom;
        int? jumpRowDelta;
        int? jumpColDelta;
        final jumpHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onJumpToEdge: (from, rowDelta, colDelta) {
            jumpFrom = from;
            jumpRowDelta = rowDelta;
            jumpColDelta = colDelta;
          },
        );

        // Right edge of selection (2,2)-(4,4):
        // Col 4 ends at x=500, screen x = 50 + 500 = 550
        // Row 3 center y = 30 + 3*24 + 12 = 114
        const rightEdgePos = Offset(549.0, 114.0);
        jumpHandler.onDoubleTap(
          position: rightEdgePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(jumpFrom, isNotNull);
        expect(jumpRowDelta, equals(0));
        expect(jumpColDelta, equals(1));
      });

      test('double-click on bottom edge fires jump down', () {
        selectionController.selectRange(const CellRange(2, 2, 4, 4));

        int? jumpRowDelta;
        int? jumpColDelta;
        final jumpHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onJumpToEdge: (from, rowDelta, colDelta) {
            jumpRowDelta = rowDelta;
            jumpColDelta = colDelta;
          },
        );

        // Bottom edge of selection (2,2)-(4,4):
        // Row 4 ends at y=120, screen y = 30 + 120 = 150
        // Col 3 center x = 50 + 3*100 + 50 = 400
        const bottomEdgePos = Offset(400.0, 149.0);
        jumpHandler.onDoubleTap(
          position: bottomEdgePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(jumpRowDelta, equals(1));
        expect(jumpColDelta, equals(0));
      });

      test('double-click on left edge fires jump left', () {
        selectionController.selectRange(const CellRange(2, 2, 4, 4));

        int? jumpRowDelta;
        int? jumpColDelta;
        final jumpHandler = WorksheetGestureHandler(
          hitTester: hitTester,
          selectionController: selectionController,
          onJumpToEdge: (from, rowDelta, colDelta) {
            jumpRowDelta = rowDelta;
            jumpColDelta = colDelta;
          },
        );

        // Left edge of selection (2,2)-(4,4):
        // Col 2 starts at x=200, screen x = 50 + 200 = 250
        // Row 3 center y = 30 + 3*24 + 12 = 114
        const leftEdgePos = Offset(251.0, 114.0);
        jumpHandler.onDoubleTap(
          position: leftEdgePos,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(jumpRowDelta, equals(0));
        expect(jumpColDelta, equals(-1));
      });
    });

    group('long-press move (mobile)', () {
      late CellRange? lastMoveSource;
      late CellCoordinate? lastMoveDest;
      late CellRange? lastMovePreview;
      late bool moveCancelled;

      setUp(() {
        lastMoveSource = null;
        lastMoveDest = null;
        lastMovePreview = null;
        moveCancelled = false;

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
          onMoveComplete: (source, dest) {
            lastMoveSource = source;
            lastMoveDest = dest;
          },
          onMovePreviewUpdate: (range) {
            lastMovePreview = range;
          },
          onMoveCancel: () {
            moveCancelled = true;
          },
        );
      });

      test('onLongPressStart on selected cell starts move', () {
        // Select cell (1, 1)
        selectionController.selectCell(const CellCoordinate(1, 1));

        // Long-press at cell (1, 1) center
        // Column 1: x = 100..200, screen x = 150..250
        // Row 1: y = 24..48, screen y = 54..78
        handler.onLongPressStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(handler.isMoving, isTrue);
      });

      test('onLongPressStart on unselected cell does NOT start move', () {
        // Select cell (0, 0)
        selectionController.selectCell(const CellCoordinate(0, 0));

        // Long-press at cell (1, 1) which is NOT selected
        handler.onLongPressStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(handler.isMoving, isFalse);
      });

      test('onLongPressMoveUpdate calls onMovePreviewUpdate', () {
        selectionController.selectCell(const CellCoordinate(1, 1));

        handler.onLongPressStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Move to cell (3, 3)
        // Column 3: x = 300..400, screen x = 350..450
        // Row 3: y = 72..96, screen y = 102..126
        handler.onLongPressMoveUpdate(
          position: const Offset(400.0, 110.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        expect(lastMovePreview, isNotNull);
      });

      test('onLongPressEnd calls onMoveComplete with correct args', () {
        selectionController.selectCell(const CellCoordinate(1, 1));

        handler.onLongPressStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Move to cell (3, 3)
        handler.onLongPressMoveUpdate(
          position: const Offset(400.0, 110.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onLongPressEnd();

        expect(lastMoveSource, isNotNull);
        expect(lastMoveDest, isNotNull);
        expect(handler.isMoving, isFalse);
      });

      test('onLongPressEnd without move calls onMoveCancel', () {
        selectionController.selectCell(const CellCoordinate(1, 1));

        handler.onLongPressStart(
          position: const Offset(200.0, 66.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // End without moving
        handler.onLongPressEnd();

        expect(moveCancelled, isTrue);
        expect(handler.isMoving, isFalse);
      });
    });

    group('selection handle drag', () {
      test('selection handle drag extends selection from opposite corner', () {
        // Select range (1,1) to (3,3)
        selectionController.selectRange(const CellRange(1, 1, 3, 3));

        // Drag from bottom-right handle
        // Bottom-right corner of (3,3): row end = 96, col end = 400
        // Screen: (450, 126)
        final bottomRightScreen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnEnd(3),
            layoutSolver.getRowEnd(3),
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Hit test should detect selection handle with size > 0
        final hit = hitTester.hitTest(
          position: bottomRightScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: selectionController.selectedRange,
          selectionHandleSize: 12.0,
        );
        expect(hit.isSelectionHandle, isTrue);

        // Start drag from bottom-right handle
        handler.onDragStart(
          position: bottomRightScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionHandleSize: 12.0,
        );

        expect(handler.isHandleDragging, isTrue);
        expect(handler.isSelectingRange, isTrue);

        // Anchor should now be at top-left (1,1)
        expect(selectionController.anchor,
            equals(const CellCoordinate(1, 1)));
      });

      test('top-left handle anchors at bottom-right corner', () {
        // Select range (1,1) to (3,3)
        selectionController.selectRange(const CellRange(1, 1, 3, 3));

        // Top-left corner of (1,1): row top = 24, col left = 100
        // Screen: (150, 54)
        final topLeftScreen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnLeft(1),
            layoutSolver.getRowTop(1),
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        final hit = hitTester.hitTest(
          position: topLeftScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: selectionController.selectedRange,
          selectionHandleSize: 12.0,
        );
        expect(hit.isSelectionHandle, isTrue);

        handler.onDragStart(
          position: topLeftScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionHandleSize: 12.0,
        );

        // Anchor should now be at bottom-right (3,3)
        expect(selectionController.anchor,
            equals(const CellCoordinate(3, 3)));
      });

      test('dragging handle extends selection to new cell', () {
        // Select range (1,1) to (3,3)
        selectionController.selectRange(const CellRange(1, 1, 3, 3));

        // Drag from bottom-right handle
        final bottomRightScreen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnEnd(3),
            layoutSolver.getRowEnd(3),
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onDragStart(
          position: bottomRightScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionHandleSize: 12.0,
        );

        // Drag to cell (5,5) center
        // Column 5: x = 500..600, screen x = 550..650
        // Row 5: y = 120..144, screen y = 150..174
        handler.onDragUpdate(
          position: const Offset(600.0, 162.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Selection should now extend from (1,1) to (5,5)
        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(1));
        expect(range.startColumn, equals(1));
        expect(range.endRow, equals(5));
        expect(range.endColumn, equals(5));
      });

      test('dragging handle inward contracts selection', () {
        // Select range (1,1) to (5,5)
        selectionController.selectRange(const CellRange(1, 1, 5, 5));

        // Drag from bottom-right handle
        final bottomRightScreen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnEnd(5),
            layoutSolver.getRowEnd(5),
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onDragStart(
          position: bottomRightScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionHandleSize: 12.0,
        );

        // Drag inward to cell (2,2) center — contracts the selection
        final cell22Screen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnLeft(2) + layoutSolver.getColumnWidth(2) / 2,
            layoutSolver.getRowTop(2) + layoutSolver.getRowHeight(2) / 2,
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onDragUpdate(
          position: cell22Screen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Selection should contract from (1,1) to (2,2)
        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(1));
        expect(range.startColumn, equals(1));
        expect(range.endRow, equals(2));
        expect(range.endColumn, equals(2));
      });

      test('dragging handle past opposite corner reverses selection', () {
        // Select range (2,2) to (4,4)
        selectionController.selectRange(const CellRange(2, 2, 4, 4));

        // Drag from bottom-right handle
        final bottomRightScreen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnEnd(4),
            layoutSolver.getRowEnd(4),
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onDragStart(
          position: bottomRightScreen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionHandleSize: 12.0,
        );

        // Drag past opposite corner to cell (0,0)
        final cell00Screen = hitTester.worksheetToScreen(
          worksheetPosition: Offset(
            layoutSolver.getColumnLeft(0) + layoutSolver.getColumnWidth(0) / 2,
            layoutSolver.getRowTop(0) + layoutSolver.getRowHeight(0) / 2,
          ),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        handler.onDragUpdate(
          position: cell00Screen,
          scrollOffset: Offset.zero,
          zoom: 1.0,
        );

        // Selection should reverse — anchor stays at (2,2), focus at (0,0)
        // selectedRange normalizes: (0,0) to (2,2)
        final range = selectionController.selectedRange!;
        expect(range.startRow, equals(0));
        expect(range.startColumn, equals(0));
        expect(range.endRow, equals(2));
        expect(range.endColumn, equals(2));
      });
    });
  });
}
