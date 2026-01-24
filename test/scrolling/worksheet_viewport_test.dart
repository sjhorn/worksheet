import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/geometry/layout_solver.dart';
import 'package:worksheet2/src/core/geometry/span_list.dart';
import 'package:worksheet2/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet2/src/core/models/cell_range.dart';
import 'package:worksheet2/src/rendering/tile/tile_config.dart';
import 'package:worksheet2/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet2/src/rendering/tile/tile_manager.dart';
import 'package:worksheet2/src/scrolling/worksheet_viewport.dart';

/// Test tile renderer that creates simple pictures.
class TestTileRenderer implements TileRenderer {
  int renderCount = 0;

  @override
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  }) {
    renderCount++;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      bounds,
      ui.Paint()..color = const ui.Color(0xFFCCCCCC),
    );
    return recorder.endRecording();
  }
}

/// Test implementation of ViewportOffset for unit testing.
class TestViewportOffset extends ViewportOffset {
  double _pixels = 0.0;

  @override
  bool get hasPixels => true;

  @override
  double get pixels => _pixels;

  set pixels(double value) {
    if (_pixels != value) {
      _pixels = value;
      notifyListeners();
    }
  }

  @override
  bool applyViewportDimension(double viewportDimension) => true;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) =>
      true;

  @override
  void correctBy(double correction) {
    _pixels += correction;
  }

  @override
  void jumpTo(double pixels) {
    _pixels = pixels;
    notifyListeners();
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) async {
    _pixels = to;
    notifyListeners();
  }

  @override
  ScrollDirection get userScrollDirection => ScrollDirection.idle;

  @override
  bool get allowImplicitScrolling => false;
}

void main() {
  group('WorksheetViewport', () {
    late TileManager tileManager;
    late LayoutSolver layoutSolver;
    late TestTileRenderer renderer;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );

      renderer = TestTileRenderer();

      tileManager = TileManager(
        layoutSolver: layoutSolver,
        config: const TileConfig(tileSize: 256, maxCachedTiles: 20),
        renderer: renderer,
      );
    });

    tearDown(() {
      tileManager.dispose();
    });

    testWidgets('renders without error using TwoDimensionalScrollable',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WorksheetViewport), findsOneWidget);
    });

    testWidgets('renders tiles for visible area', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Should have rendered some tiles
      expect(renderer.renderCount, greaterThan(0));
    });

    testWidgets('exposes render object', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      final renderObject = tester.renderObject<RenderWorksheetViewport>(
        find.byType(WorksheetViewport),
      );

      expect(renderObject, isNotNull);
      expect(renderObject.zoom, 1.0);
    });

    testWidgets('updates when zoom changes', (tester) async {
      final horizontalController = ScrollController();
      final verticalController = ScrollController();

      var zoom = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: TwoDimensionalScrollable(
                    horizontalDetails: ScrollableDetails.horizontal(
                      controller: horizontalController,
                    ),
                    verticalDetails: ScrollableDetails.vertical(
                      controller: verticalController,
                    ),
                    viewportBuilder: (context, vertical, horizontal) {
                      return WorksheetViewport(
                        horizontalPosition: horizontal,
                        verticalPosition: vertical,
                        tileManager: tileManager,
                        layoutSolver: layoutSolver,
                        zoom: zoom,
                      );
                    },
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => zoom = 2.0),
                  child: const Icon(Icons.add),
                ),
              );
            },
          ),
        ),
      );

      // Let the scroll system initialize
      await tester.pumpAndSettle();

      final renderObject = tester.renderObject<RenderWorksheetViewport>(
        find.byType(WorksheetViewport),
      );

      expect(renderObject.zoom, 1.0);

      // Change zoom
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(renderObject.zoom, 2.0);

      horizontalController.dispose();
      verticalController.dispose();
    });

    testWidgets('repaints when tile manager invalidates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      final initialRenderCount = renderer.renderCount;

      // Invalidate tiles
      tileManager.invalidateAll();
      await tester.pump();

      // Request a new frame to trigger repaint
      final renderObject = tester.renderObject<RenderWorksheetViewport>(
        find.byType(WorksheetViewport),
      );
      renderObject.markNeedsPaint();
      await tester.pump();

      // Should have re-rendered with new tiles
      expect(renderer.renderCount, greaterThan(initialRenderCount));
    });

    testWidgets('disposes cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Replace with empty widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Should not throw
    });

    testWidgets('responds to scroll controller jumps',
        (tester) async {
      final horizontalController = ScrollController();
      final verticalController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: horizontalController,
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: verticalController,
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Let scroll system initialize
      await tester.pumpAndSettle();

      // Verify viewport renders and can receive scroll commands without error
      expect(find.byType(WorksheetViewport), findsOneWidget);

      // Scroll positions should update (controller drives the position)
      horizontalController.jumpTo(500);
      verticalController.jumpTo(300);
      await tester.pumpAndSettle();

      // After jump, controllers should report the new position
      expect(horizontalController.position.pixels, 500);
      expect(verticalController.position.pixels, 300);

      horizontalController.dispose();
      verticalController.dispose();
    });
  });

  group('RenderWorksheetViewport', () {
    late TileManager tileManager;
    late LayoutSolver layoutSolver;
    late TestViewportOffset horizontalOffset;
    late TestViewportOffset verticalOffset;

    setUp(() {
      horizontalOffset = TestViewportOffset();
      verticalOffset = TestViewportOffset();

      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );

      tileManager = TileManager(
        layoutSolver: layoutSolver,
        config: const TileConfig(tileSize: 256, maxCachedTiles: 20),
        renderer: TestTileRenderer(),
      );
    });

    tearDown(() {
      tileManager.dispose();
    });

    test('has correct intrinsic dimensions', () {
      final renderObject = RenderWorksheetViewport(
        horizontalPosition: horizontalOffset,
        verticalPosition: verticalOffset,
        tileManager: tileManager,
        layoutSolver: layoutSolver,
        zoom: 1.0,
      );

      // Should fill available space
      expect(renderObject.sizedByParent, isTrue);
    });

    test('exposes getters', () {
      final renderObject = RenderWorksheetViewport(
        horizontalPosition: horizontalOffset,
        verticalPosition: verticalOffset,
        tileManager: tileManager,
        layoutSolver: layoutSolver,
        zoom: 1.0,
      );

      expect(renderObject.horizontalPosition, horizontalOffset);
      expect(renderObject.verticalPosition, verticalOffset);
      expect(renderObject.tileManager, tileManager);
      expect(renderObject.layoutSolver, layoutSolver);
      expect(renderObject.zoom, 1.0);
    });

    test('setters update values', () {
      final renderObject = RenderWorksheetViewport(
        horizontalPosition: horizontalOffset,
        verticalPosition: verticalOffset,
        tileManager: tileManager,
        layoutSolver: layoutSolver,
        zoom: 1.0,
      );

      // Create new instances
      final newHorizontal = TestViewportOffset();
      final newVertical = TestViewportOffset();
      final newLayoutSolver = LayoutSolver(
        rows: SpanList(count: 500, defaultSize: 30.0),
        columns: SpanList(count: 50, defaultSize: 120.0),
      );
      final newTileManager = TileManager(
        layoutSolver: newLayoutSolver,
        config: const TileConfig(tileSize: 256, maxCachedTiles: 20),
        renderer: TestTileRenderer(),
      );

      // Update horizontal position
      renderObject.horizontalPosition = newHorizontal;
      expect(renderObject.horizontalPosition, newHorizontal);

      // Update vertical position
      renderObject.verticalPosition = newVertical;
      expect(renderObject.verticalPosition, newVertical);

      // Update tile manager
      renderObject.tileManager = newTileManager;
      expect(renderObject.tileManager, newTileManager);

      // Update layout solver
      renderObject.layoutSolver = newLayoutSolver;
      expect(renderObject.layoutSolver, newLayoutSolver);

      // Clean up
      newTileManager.dispose();
    });

    test('setters skip update when value unchanged', () {
      final renderObject = RenderWorksheetViewport(
        horizontalPosition: horizontalOffset,
        verticalPosition: verticalOffset,
        tileManager: tileManager,
        layoutSolver: layoutSolver,
        zoom: 1.0,
      );

      // Set same values - should not throw or cause issues
      renderObject.horizontalPosition = horizontalOffset;
      renderObject.verticalPosition = verticalOffset;
      renderObject.tileManager = tileManager;
      renderObject.layoutSolver = layoutSolver;
      renderObject.zoom = 1.0;

      // Values should remain the same
      expect(renderObject.horizontalPosition, horizontalOffset);
      expect(renderObject.verticalPosition, verticalOffset);
      expect(renderObject.tileManager, tileManager);
      expect(renderObject.layoutSolver, layoutSolver);
      expect(renderObject.zoom, 1.0);
    });

    test('computeDryLayout returns biggest constraints', () {
      final renderObject = RenderWorksheetViewport(
        horizontalPosition: horizontalOffset,
        verticalPosition: verticalOffset,
        tileManager: tileManager,
        layoutSolver: layoutSolver,
        zoom: 1.0,
      );

      final constraints = BoxConstraints.tight(const Size(800, 600));
      final size = renderObject.computeDryLayout(constraints);

      expect(size, const Size(800, 600));
    });

    testWidgets('hit tests correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: ScrollController(),
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: ScrollController(),
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      final renderObject = tester.renderObject<RenderWorksheetViewport>(
        find.byType(WorksheetViewport),
      );

      // Hit test inside bounds
      final result = BoxHitTestResult();
      final hit = renderObject.hitTest(result, position: const Offset(100, 100));

      expect(hit, isTrue);
    });

    testWidgets('responds to position changes via controllers', (tester) async {
      final horizontalController = ScrollController();
      final verticalController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: horizontalController,
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: verticalController,
                ),
                viewportBuilder: (context, vertical, horizontal) {
                  return WorksheetViewport(
                    horizontalPosition: horizontal,
                    verticalPosition: vertical,
                    tileManager: tileManager,
                    layoutSolver: layoutSolver,
                    zoom: 1.0,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Let scroll system initialize
      await tester.pumpAndSettle();

      // Initial position should be 0 via controller
      expect(horizontalController.position.pixels, 0);
      expect(verticalController.position.pixels, 0);

      // Scroll via controllers
      horizontalController.jumpTo(100);
      verticalController.jumpTo(200);
      await tester.pumpAndSettle();

      // Controllers should reflect new position
      expect(horizontalController.position.pixels, 100);
      expect(verticalController.position.pixels, 200);

      horizontalController.dispose();
      verticalController.dispose();
    });
  });
}
