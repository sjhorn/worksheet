import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/interaction/controllers/zoom_controller.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';

void main() {
  group('WorksheetController', () {
    late WorksheetController controller;

    setUp(() {
      controller = WorksheetController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('creates with default controllers', () {
      expect(controller.selectionController, isNotNull);
      expect(controller.zoomController, isNotNull);
      expect(controller.horizontalScrollController, isNotNull);
      expect(controller.verticalScrollController, isNotNull);
    });

    test('can be created with custom controllers', () {
      final selectionController = SelectionController();
      final zoomController = ZoomController();
      final hScrollController = ScrollController();
      final vScrollController = ScrollController();

      final customController = WorksheetController(
        selectionController: selectionController,
        zoomController: zoomController,
        horizontalScrollController: hScrollController,
        verticalScrollController: vScrollController,
      );

      expect(customController.selectionController, selectionController);
      expect(customController.zoomController, zoomController);
      expect(customController.horizontalScrollController, hScrollController);
      expect(customController.verticalScrollController, vScrollController);

      customController.dispose();
    });

    group('selection', () {
      test('hasSelection is false initially', () {
        expect(controller.hasSelection, isFalse);
        expect(controller.selectedRange, isNull);
        expect(controller.focusCell, isNull);
      });

      test('selectCell updates selection', () {
        controller.selectCell(const CellCoordinate(5, 3));

        expect(controller.hasSelection, isTrue);
        expect(controller.focusCell, const CellCoordinate(5, 3));
        expect(controller.selectionMode, SelectionMode.single);
      });

      test('selectRange updates selection', () {
        controller.selectRange(const CellRange(2, 2, 5, 5));

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedRange, const CellRange(2, 2, 5, 5));
        expect(controller.selectionMode, SelectionMode.range);
      });

      test('selectRow selects entire row', () {
        controller.selectRow(5, columnCount: 10);

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedRange, const CellRange(5, 0, 5, 9));
      });

      test('selectColumn selects entire column', () {
        controller.selectColumn(3, rowCount: 20);

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedRange, const CellRange(0, 3, 19, 3));
      });

      test('clearSelection clears selection', () {
        controller.selectCell(const CellCoordinate(0, 0));
        expect(controller.hasSelection, isTrue);

        controller.clearSelection();
        expect(controller.hasSelection, isFalse);
      });

      test('moveFocus moves the focus cell', () {
        controller.selectCell(const CellCoordinate(5, 5));

        controller.moveFocus(rowDelta: 1, columnDelta: 0);
        expect(controller.focusCell, const CellCoordinate(6, 5));

        controller.moveFocus(rowDelta: 0, columnDelta: 2);
        expect(controller.focusCell, const CellCoordinate(6, 7));
      });

      test('moveFocus with extend extends selection', () {
        controller.selectCell(const CellCoordinate(5, 5));

        controller.moveFocus(rowDelta: 2, columnDelta: 2, extend: true);
        expect(controller.selectedRange, const CellRange(5, 5, 7, 7));
      });
    });

    group('zoom', () {
      test('zoom is 1.0 initially', () {
        expect(controller.zoom, 1.0);
      });

      test('setZoom changes zoom level', () {
        controller.setZoom(1.5);
        expect(controller.zoom, 1.5);
      });

      test('zoomIn increases zoom', () {
        controller.zoomIn();
        expect(controller.zoom, greaterThan(1.0));
      });

      test('zoomOut decreases zoom', () {
        controller.zoomOut();
        expect(controller.zoom, lessThan(1.0));
      });

      test('resetZoom resets to 1.0', () {
        controller.setZoom(2.0);
        controller.resetZoom();
        expect(controller.zoom, 1.0);
      });
    });

    group('scroll', () {
      test('scrollX and scrollY are 0 when no clients', () {
        expect(controller.scrollX, 0.0);
        expect(controller.scrollY, 0.0);
      });

      test('scrollTo does nothing when no clients', () {
        // Should not throw
        expect(
          () => controller.scrollTo(x: 100, y: 100),
          returnsNormally,
        );
      });

      test('scrollToCell does nothing when no clients', () {
        // Should not throw
        expect(
          () => controller.scrollToCell(
            const CellCoordinate(10, 10),
            getRowTop: (row) => row * 24.0,
            getColumnLeft: (col) => col * 100.0,
            getRowHeight: (_) => 24.0,
            getColumnWidth: (_) => 100.0,
            viewportSize: const Size(800, 600),
            headerWidth: 50.0,
            headerHeight: 24.0,
          ),
          returnsNormally,
        );
      });

      testWidgets('scrollTo with clients jumps to position', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      controller: controller.horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: const SizedBox(width: 2000, height: 100),
                    ),
                    SingleChildScrollView(
                      controller: controller.verticalScrollController,
                      child: const SizedBox(width: 100, height: 2000),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        controller.scrollTo(x: 100, y: 200);
        await tester.pump();

        expect(controller.scrollX, 100);
        expect(controller.scrollY, 200);
      });

      testWidgets('scrollTo with animate uses animateTo', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: controller.horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: const SizedBox(width: 2000, height: 100),
                ),
                SingleChildScrollView(
                  controller: controller.verticalScrollController,
                  child: const SizedBox(width: 100, height: 2000),
                ),
              ],
            ),
          ),
        );

        controller.scrollTo(x: 100, y: 200, animate: true);
        await tester.pumpAndSettle();

        expect(controller.scrollX, 100);
        expect(controller.scrollY, 200);
      });

      testWidgets('scrollToCell scrolls to make cell visible', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  SingleChildScrollView(
                    controller: controller.verticalScrollController,
                    child: const SizedBox(width: 100, height: 10000),
                  ),
                ],
              ),
            ),
          ),
        );

        // Scroll to a cell that's outside the viewport (immediate jump)
        controller.scrollToCell(
          const CellCoordinate(50, 20),
          getRowTop: (row) => row * 24.0,
          getColumnLeft: (col) => col * 100.0,
          getRowHeight: (_) => 24.0,
          getColumnWidth: (_) => 100.0,
          viewportSize: const Size(800, 600),
          headerWidth: 50.0,
          headerHeight: 24.0,
          animate: false,
        );
        await tester.pump();

        // Should have scrolled to show the cell
        expect(controller.scrollX, greaterThan(0));
        expect(controller.scrollY, greaterThan(0));
      });

      testWidgets('scrollToCell with animate uses animateTo', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  SingleChildScrollView(
                    controller: controller.verticalScrollController,
                    child: const SizedBox(width: 100, height: 10000),
                  ),
                ],
              ),
            ),
          ),
        );

        controller.scrollToCell(
          const CellCoordinate(50, 20),
          getRowTop: (row) => row * 24.0,
          getColumnLeft: (col) => col * 100.0,
          getRowHeight: (_) => 24.0,
          getColumnWidth: (_) => 100.0,
          viewportSize: const Size(800, 600),
          headerWidth: 50.0,
          headerHeight: 24.0,
          animate: true,
        );
        await tester.pumpAndSettle();

        expect(controller.scrollX, greaterThan(0));
        expect(controller.scrollY, greaterThan(0));
      });

      testWidgets('scrollToCell handles cell already visible', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  SingleChildScrollView(
                    controller: controller.verticalScrollController,
                    child: const SizedBox(width: 100, height: 10000),
                  ),
                ],
              ),
            ),
          ),
        );

        // Cell (1,1) is already visible at origin
        controller.scrollToCell(
          const CellCoordinate(1, 1),
          getRowTop: (row) => row * 24.0,
          getColumnLeft: (col) => col * 100.0,
          getRowHeight: (_) => 24.0,
          getColumnWidth: (_) => 100.0,
          viewportSize: const Size(800, 600),
          headerWidth: 50.0,
          headerHeight: 24.0,
        );
        await tester.pump();

        // No scrolling needed
        expect(controller.scrollX, 0);
        expect(controller.scrollY, 0);
      });

      testWidgets('scrollToCell scrolls left/up when cell is before viewport', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  SingleChildScrollView(
                    controller: controller.verticalScrollController,
                    child: const SizedBox(width: 100, height: 10000),
                  ),
                ],
              ),
            ),
          ),
        );

        // First scroll far right/down
        controller.scrollTo(x: 5000, y: 5000);
        await tester.pump();

        // Now scroll to cell near origin (immediate jump)
        controller.scrollToCell(
          const CellCoordinate(5, 2),
          getRowTop: (row) => row * 24.0,
          getColumnLeft: (col) => col * 100.0,
          getRowHeight: (_) => 24.0,
          getColumnWidth: (_) => 100.0,
          viewportSize: const Size(800, 600),
          headerWidth: 50.0,
          headerHeight: 24.0,
          animate: false,
        );
        await tester.pump();

        // Should have scrolled back toward origin
        expect(controller.scrollX, lessThan(5000));
        expect(controller.scrollY, lessThan(5000));
      });
    });

    group('layout attachment', () {
      late LayoutSolver solver;

      setUp(() {
        solver = LayoutSolver(
          rows: SpanList(count: 100, defaultSize: 20.0),
          columns: SpanList(count: 26, defaultSize: 80.0),
        );
      });

      test('hasLayout is false before attach', () {
        expect(controller.hasLayout, isFalse);
        expect(controller.layoutSolver, isNull);
      });

      test('hasLayout is true after attach', () {
        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );

        expect(controller.hasLayout, isTrue);
        expect(controller.layoutSolver, same(solver));
        expect(controller.headerWidth, 40.0);
        expect(controller.headerHeight, 20.0);
      });

      test('detachLayout resets hasLayout to false', () {
        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );
        expect(controller.hasLayout, isTrue);

        controller.detachLayout();
        expect(controller.hasLayout, isFalse);
        expect(controller.layoutSolver, isNull);
      });

      test('getCellScreenBounds returns null before attach', () {
        expect(
          controller.getCellScreenBounds(const CellCoordinate(0, 0)),
          isNull,
        );
      });

      test('getCellScreenBounds returns correct Rect at zoom=1 no scroll', () {
        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );

        // Cell (0,0): left=0, top=0, width=80, height=20
        // With headers: left = 0 - 0 + 40 = 40, top = 0 - 0 + 20 = 20
        final bounds = controller.getCellScreenBounds(
          const CellCoordinate(0, 0),
        );
        expect(bounds, isNotNull);
        expect(bounds!.left, 40.0);
        expect(bounds.top, 20.0);
        expect(bounds.width, 80.0);
        expect(bounds.height, 20.0);
      });

      test('getCellScreenBounds for non-origin cell', () {
        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );

        // Cell (2,3): left=3*80=240, top=2*20=40, width=80, height=20
        // With headers: left = 240 + 40 = 280, top = 40 + 20 = 60
        final bounds = controller.getCellScreenBounds(
          const CellCoordinate(2, 3),
        );
        expect(bounds, isNotNull);
        expect(bounds!.left, 280.0);
        expect(bounds.top, 60.0);
        expect(bounds.width, 80.0);
        expect(bounds.height, 20.0);
      });

      test('getCellScreenBounds accounts for zoom', () {
        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );
        controller.setZoom(2.0);

        // Cell (0,0) at zoom 2.0:
        // cellLeft = 0 * 2 = 0, cellTop = 0 * 2 = 0
        // width = 80 * 2 = 160, height = 20 * 2 = 40
        // header offset: 40 * 2 = 80, 20 * 2 = 40
        // left = 0 - 0 + 80 = 80, top = 0 - 0 + 40 = 40
        final bounds = controller.getCellScreenBounds(
          const CellCoordinate(0, 0),
        );
        expect(bounds, isNotNull);
        expect(bounds!.left, 80.0);
        expect(bounds.top, 40.0);
        expect(bounds.width, 160.0);
        expect(bounds.height, 40.0);
      });

      test('getCellScreenBounds accounts for header dimensions', () {
        controller.attachLayout(
          solver,
          headerWidth: 0.0,
          headerHeight: 0.0,
        );

        // Cell (0,0) with no headers:
        // left = 0 - 0 + 0 = 0, top = 0 - 0 + 0 = 0
        final bounds = controller.getCellScreenBounds(
          const CellCoordinate(0, 0),
        );
        expect(bounds, isNotNull);
        expect(bounds!.left, 0.0);
        expect(bounds.top, 0.0);
      });

      testWidgets('getCellScreenBounds accounts for scroll offset',
          (tester) async {
        // Need scroll controllers with clients to have non-zero offsets
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: controller.horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: const SizedBox(width: 10000, height: 100),
                ),
                SingleChildScrollView(
                  controller: controller.verticalScrollController,
                  child: const SizedBox(width: 100, height: 10000),
                ),
              ],
            ),
          ),
        );

        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );

        // Scroll to (100, 50)
        controller.scrollTo(x: 100, y: 50);
        await tester.pump();

        // Cell (0,0) with scroll offset:
        // left = 0 - 100 + 40 = -60, top = 0 - 50 + 20 = -30
        final bounds = controller.getCellScreenBounds(
          const CellCoordinate(0, 0),
        );
        expect(bounds, isNotNull);
        expect(bounds!.left, -60.0);
        expect(bounds.top, -30.0);
      });

      testWidgets('ensureCellVisible works with attached layout',
          (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  SingleChildScrollView(
                    controller: controller.verticalScrollController,
                    child: const SizedBox(width: 100, height: 10000),
                  ),
                ],
              ),
            ),
          ),
        );

        controller.attachLayout(
          solver,
          headerWidth: 40.0,
          headerHeight: 20.0,
        );

        controller.ensureCellVisible(
          const CellCoordinate(50, 20),
          viewportSize: const Size(800, 600),
          animate: false,
        );
        await tester.pump();

        // Should have scrolled to show the cell
        expect(controller.scrollX, greaterThan(0));
        expect(controller.scrollY, greaterThan(0));
      });

      test('ensureCellVisible does nothing without layout', () {
        // Should not throw
        expect(
          () => controller.ensureCellVisible(
            const CellCoordinate(10, 10),
            viewportSize: const Size(800, 600),
          ),
          returnsNormally,
        );
      });
    });

    group('notifications', () {
      test('notifies when selection changes', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.selectCell(const CellCoordinate(0, 0));
        expect(notifyCount, 1);

        controller.selectRange(const CellRange(0, 0, 2, 2));
        expect(notifyCount, 2);

        controller.clearSelection();
        expect(notifyCount, 3);
      });

      test('notifies when zoom changes', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.setZoom(1.5);
        expect(notifyCount, 1);

        controller.zoomIn();
        expect(notifyCount, 2);
      });
    });
  });
}
