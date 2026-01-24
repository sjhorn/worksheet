import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/geometry/layout_solver.dart';
import 'package:worksheet2/src/core/geometry/span_list.dart';
import 'package:worksheet2/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet2/src/scrolling/worksheet_scroll_delegate.dart';

void main() {
  group('WorksheetScrollDelegate', () {
    late LayoutSolver layoutSolver;
    late ZoomTransformer zoomTransformer;
    late WorksheetScrollDelegate delegate;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 24.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      zoomTransformer = ZoomTransformer();
      delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );
    });

    tearDown(() {
      delegate.dispose();
    });

    test('creates with default values', () {
      expect(delegate.scrollX, equals(0.0));
      expect(delegate.scrollY, equals(0.0));
      expect(delegate.zoom, equals(1.0));
      expect(delegate.viewportSize, equals(Size.zero));
    });

    test('creates with initial scroll position', () {
      final customDelegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
        initialScrollX: 100.0,
        initialScrollY: 200.0,
      );

      expect(customDelegate.scrollX, equals(100.0));
      expect(customDelegate.scrollY, equals(200.0));

      customDelegate.dispose();
    });

    test('exposes horizontal and vertical controllers', () {
      expect(delegate.horizontalController, isNotNull);
      expect(delegate.verticalController, isNotNull);
    });

    test('exposes viewport delegate', () {
      expect(delegate.viewportDelegate, isNotNull);
      expect(delegate.viewportDelegate.contentWidth, equals(layoutSolver.totalWidth));
      expect(delegate.viewportDelegate.contentHeight, equals(layoutSolver.totalHeight));
    });

    test('updates viewport size', () {
      const size = Size(800.0, 600.0);
      delegate.updateViewportSize(size);

      expect(delegate.viewportSize, equals(size));
    });

    test('ignores unchanged viewport size', () {
      const size = Size(800.0, 600.0);
      delegate.updateViewportSize(size);
      delegate.updateViewportSize(size); // Should not throw or cause issues

      expect(delegate.viewportSize, equals(size));
    });

    test('returns scroll offset as Offset', () {
      final offset = delegate.scrollOffset;
      expect(offset, equals(Offset.zero));
    });

    test('provides scroll physics', () {
      expect(delegate.physics, isNotNull);
    });

    group('anchor creation', () {
      setUp(() {
        delegate.updateViewportSize(const Size(800.0, 600.0));
      });

      test('creates anchor from center', () {
        final anchor = delegate.createAnchorFromCenter();

        expect(anchor, isNotNull);
        // At zoom 1.0 with no scroll, center should be at (400, 300)
        expect(anchor.viewportOffset, equals(const Offset(400.0, 300.0)));
        expect(anchor.worksheetPosition, equals(const Offset(400.0, 300.0)));
      });

      test('creates anchor from focal point', () {
        const focalPoint = Offset(200.0, 150.0);
        final anchor = delegate.createAnchorFromFocalPoint(focalPoint);

        expect(anchor, isNotNull);
        expect(anchor.viewportOffset, equals(focalPoint));
        // At zoom 1.0 with no scroll, worksheet position equals viewport position
        expect(anchor.worksheetPosition, equals(focalPoint));
      });

      test('creates anchor with different zoom levels', () {
        zoomTransformer.setScale(2.0);
        delegate.updateViewportSize(const Size(800.0, 600.0));

        const focalPoint = Offset(200.0, 150.0);
        final anchor = delegate.createAnchorFromFocalPoint(focalPoint);

        expect(anchor.viewportOffset, equals(focalPoint));
        // At zoom 2.0 with no scroll: worksheet = focalPoint / zoom
        expect(anchor.worksheetPosition.dx, closeTo(100.0, 0.1));
        expect(anchor.worksheetPosition.dy, closeTo(75.0, 0.1));
      });
    });

    group('zoom anchor application', () {
      setUp(() {
        delegate.updateViewportSize(const Size(800.0, 600.0));
      });

      test('calculates correct anchor offset for zoom change', () {
        final anchor = delegate.createAnchorFromCenter();

        // Change zoom
        zoomTransformer.setScale(2.0);

        // Calculate what the scroll offset should be
        final newOffset = anchor.calculateScrollOffset(zoom: 2.0);

        // At zoom 2.0: scroll = worksheetPosition * zoom - viewportOffset
        // scroll = (400, 300) * 2 - (400, 300) = (400, 300)
        expect(newOffset.dx, closeTo(400.0, 0.1));
        expect(newOffset.dy, closeTo(300.0, 0.1));
      });

      test('applyAnchor without attached controllers does not throw', () {
        final anchor = delegate.createAnchorFromCenter();
        zoomTransformer.setScale(2.0);

        // Should not throw even without attached controllers
        delegate.applyAnchor(anchor);
      });
    });

    group('onZoomChanged', () {
      test('can be called without error', () {
        delegate.updateViewportSize(const Size(800.0, 600.0));
        zoomTransformer.setScale(2.0);

        // Should not throw
        delegate.onZoomChanged();
      });
    });

    group('scrollToCell without attached controllers', () {
      setUp(() {
        delegate.updateViewportSize(const Size(800.0, 600.0));
      });

      test('does not throw when controllers have no clients', () {
        // Should not throw
        delegate.scrollToCell(row: 5, column: 3);
      });

      test('does not throw with animate flag', () {
        // Should not throw
        delegate.scrollToCell(row: 5, column: 3, animate: true);
      });
    });

    group('ensureCellVisible without attached controllers', () {
      setUp(() {
        delegate.updateViewportSize(const Size(800.0, 600.0));
      });

      test('does not throw when controllers have no clients', () {
        // Should not throw
        delegate.ensureCellVisible(row: 5, column: 3);
      });

      test('does not throw with animate flag', () {
        // Should not throw
        delegate.ensureCellVisible(row: 5, column: 3, animate: true);
      });
    });

    test('disposes controllers cleanly', () {
      // Create a separate delegate for this test
      final testDelegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      testDelegate.dispose();

      // Controllers should be disposed - accessing them should throw
      expect(
        () => testDelegate.horizontalController.position,
        throwsA(isA<AssertionError>()),
      );
    });

    group('zoom getter', () {
      test('returns zoom from transformer', () {
        expect(delegate.zoom, equals(1.0));

        zoomTransformer.setScale(1.5);
        expect(delegate.zoom, equals(1.5));

        zoomTransformer.setScale(0.5);
        expect(delegate.zoom, equals(0.5));
      });
    });
  });

  group('WorksheetScrollDelegate with attached controllers', () {
    testWidgets('scrollToCell scrolls to correct position', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Scroll to cell (10, 5)
      delegate.scrollToCell(row: 10, column: 5);
      await tester.pump();

      // Cell (10, 5) is at worksheet position (500, 240)
      // At zoom 1.0, scroll should be (500, 240)
      expect(delegate.horizontalController.offset, closeTo(500.0, 1.0));
      expect(delegate.verticalController.offset, closeTo(240.0, 1.0));

      delegate.dispose();
    });

    testWidgets('scrollToCell with zoom scrolls to correct position', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      zoomTransformer.setScale(2.0);

      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth * 2,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight * 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Scroll to cell (5, 3)
      delegate.scrollToCell(row: 5, column: 3);
      await tester.pump();

      // Cell (5, 3) is at worksheet position (300, 120)
      // At zoom 2.0, scroll should be (600, 240)
      expect(delegate.horizontalController.offset, closeTo(600.0, 1.0));
      expect(delegate.verticalController.offset, closeTo(240.0, 1.0));

      delegate.dispose();
    });

    testWidgets('scrollToCell with animation', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Scroll to cell with animation
      delegate.scrollToCell(row: 10, column: 5, animate: true);

      // Let animation run
      await tester.pumpAndSettle();

      expect(delegate.horizontalController.offset, closeTo(500.0, 1.0));
      expect(delegate.verticalController.offset, closeTo(240.0, 1.0));

      delegate.dispose();
    });

    testWidgets('ensureCellVisible scrolls when cell is off screen', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Ensure cell (50, 20) is visible - it's off screen initially
      delegate.ensureCellVisible(row: 50, column: 20);
      await tester.pump();

      // Should have scrolled to show the cell
      expect(delegate.horizontalController.offset, greaterThan(0));
      expect(delegate.verticalController.offset, greaterThan(0));

      delegate.dispose();
    });

    testWidgets('ensureCellVisible does not scroll when cell is visible', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Cell (1, 1) should be visible at initial scroll position
      delegate.ensureCellVisible(row: 1, column: 1);
      await tester.pump();

      // Should not have scrolled
      expect(delegate.horizontalController.offset, equals(0.0));
      expect(delegate.verticalController.offset, equals(0.0));

      delegate.dispose();
    });

    testWidgets('ensureCellVisible with animation', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth,
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Ensure cell (50, 20) is visible with animation
      delegate.ensureCellVisible(row: 50, column: 20, animate: true);

      // Let animation run
      await tester.pumpAndSettle();

      // Should have scrolled
      expect(delegate.horizontalController.offset, greaterThan(0));
      expect(delegate.verticalController.offset, greaterThan(0));

      delegate.dispose();
    });

    testWidgets('applyAnchor scrolls to maintain position after zoom', (tester) async {
      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      final zoomTransformer = ZoomTransformer();
      final delegate = WorksheetScrollDelegate(
        layoutSolver: layoutSolver,
        zoomTransformer: zoomTransformer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: layoutSolver.totalWidth * 2, // Account for zoom
                      height: 100,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: delegate.verticalController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: 100,
                      height: layoutSolver.totalHeight * 2, // Account for zoom
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      delegate.updateViewportSize(const Size(800.0, 600.0));

      // Create anchor at center
      final anchor = delegate.createAnchorFromCenter();

      // Change zoom
      zoomTransformer.setScale(2.0);

      // Apply anchor
      delegate.applyAnchor(anchor);
      await tester.pump();

      // At zoom 2.0, scroll should be offset to keep center position stable
      expect(delegate.horizontalController.offset, closeTo(400.0, 1.0));
      expect(delegate.verticalController.offset, closeTo(300.0, 1.0));

      delegate.dispose();
    });
  });
}
