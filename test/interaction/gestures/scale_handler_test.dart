import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/interaction/controllers/zoom_controller.dart';
import 'package:worksheet2/src/interaction/gestures/scale_handler.dart';

void main() {
  late ZoomController zoomController;
  late ScaleHandler scaleHandler;

  setUp(() {
    zoomController = ZoomController();
    scaleHandler = ScaleHandler(zoomController: zoomController);
  });

  tearDown(() {
    zoomController.dispose();
  });

  group('ScaleHandler', () {
    test('creates with zoom controller', () {
      expect(scaleHandler.isScaling, isFalse);
    });

    group('scale gesture', () {
      test('onScaleStart marks scaling as true', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        expect(scaleHandler.isScaling, isTrue);
        expect(scaleHandler.focalPoint, const Offset(100, 100));
      });

      test('onScaleUpdate updates zoom', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        scaleHandler.onScaleUpdate(
          scale: 2.0,
          focalPoint: const Offset(100, 100),
        );

        expect(zoomController.value, 2.0);
      });

      test('onScaleUpdate with scale 0.5 zooms out', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        scaleHandler.onScaleUpdate(
          scale: 0.5,
          focalPoint: const Offset(100, 100),
        );

        expect(zoomController.value, 0.5);
      });

      test('onScaleEnd marks scaling as false', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        scaleHandler.onScaleEnd();

        expect(scaleHandler.isScaling, isFalse);
      });

      test('update before start does nothing', () {
        scaleHandler.onScaleUpdate(
          scale: 2.0,
          focalPoint: const Offset(100, 100),
        );

        expect(zoomController.value, 1.0); // Unchanged
      });

      test('notifies listeners on state changes', () {
        var notifyCount = 0;
        scaleHandler.addListener(() => notifyCount++);

        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );
        expect(notifyCount, 1);

        scaleHandler.onScaleUpdate(
          scale: 1.5,
          focalPoint: const Offset(100, 100),
        );
        expect(notifyCount, 2);

        scaleHandler.onScaleEnd();
        expect(notifyCount, 3);
      });

      test('respects zoom controller limits', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        // Try to zoom beyond max (4.0)
        scaleHandler.onScaleUpdate(
          scale: 10.0,
          focalPoint: const Offset(100, 100),
        );

        expect(zoomController.value, zoomController.maxZoom);
      });
    });

    group('scrollAdjustment', () {
      test('returns zero when not scaling', () {
        expect(scaleHandler.scrollAdjustment, Offset.zero);
      });

      test('returns zero when zoom has not changed', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        // No update yet, zoom is still 1.0
        expect(scaleHandler.scrollAdjustment, Offset.zero);
      });

      test('calculates adjustment to keep focal point stationary', () {
        scaleHandler.onScaleStart(
          scale: 1.0,
          focalPoint: const Offset(200, 200),
          scrollOffset: const Offset(100, 100),
        );

        scaleHandler.onScaleUpdate(
          scale: 2.0,
          focalPoint: const Offset(200, 200),
        );

        final adjustment = scaleHandler.scrollAdjustment;
        // Adjustment should be non-zero to maintain focal point
        expect(adjustment, isNot(Offset.zero));
      });
    });

    group('zoomBy', () {
      test('zooms by factor', () {
        final adjustment = scaleHandler.zoomBy(
          factor: 2.0,
          anchor: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        expect(zoomController.value, 2.0);
        expect(adjustment, isNotNull);
      });

      test('respects min zoom', () {
        final adjustment = scaleHandler.zoomBy(
          factor: 0.01,
          anchor: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        expect(zoomController.value, zoomController.minZoom);
        expect(adjustment, isNotNull);
      });

      test('respects max zoom', () {
        final adjustment = scaleHandler.zoomBy(
          factor: 100.0,
          anchor: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        expect(zoomController.value, zoomController.maxZoom);
        expect(adjustment, isNotNull);
      });

      test('returns zero adjustment when zoom would not change', () {
        // Set zoom to max first
        zoomController.value = zoomController.maxZoom;

        final adjustment = scaleHandler.zoomBy(
          factor: 2.0, // Would exceed max
          anchor: const Offset(100, 100),
          scrollOffset: Offset.zero,
        );

        expect(adjustment, Offset.zero);
      });
    });

    group('zoomToFit', () {
      test('calculates zoom to fit rectangle in viewport', () {
        final result = scaleHandler.zoomToFit(
          rect: const Rect.fromLTWH(0, 0, 400, 300),
          viewportSize: const Size(800, 600),
          padding: 0,
        );

        // Rectangle should fit within viewport
        expect(result.zoom, 2.0); // 800/400 = 2.0
      });

      test('uses smaller zoom to maintain aspect ratio', () {
        final result = scaleHandler.zoomToFit(
          rect: const Rect.fromLTWH(0, 0, 800, 300),
          viewportSize: const Size(800, 600),
          padding: 0,
        );

        // Height is limiting factor: 600/300 = 2.0, Width: 800/800 = 1.0
        expect(result.zoom, 1.0);
      });

      test('respects padding', () {
        final result = scaleHandler.zoomToFit(
          rect: const Rect.fromLTWH(0, 0, 380, 280),
          viewportSize: const Size(800, 600),
          padding: 20,
        );

        // Available: 760x560, rect: 380x280
        // zoomX = 760/380 = 2.0, zoomY = 560/280 = 2.0
        expect(result.zoom, 2.0);
      });

      test('respects zoom controller limits', () {
        final result = scaleHandler.zoomToFit(
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          viewportSize: const Size(800, 600),
          padding: 0,
        );

        // Would need zoom = 60, but max is 4.0
        expect(result.zoom, zoomController.maxZoom);
      });

      test('returns scroll offset to center rectangle', () {
        final result = scaleHandler.zoomToFit(
          rect: const Rect.fromLTWH(100, 100, 200, 200),
          viewportSize: const Size(800, 600),
          padding: 0,
        );

        expect(result.scroll.dx, greaterThanOrEqualTo(0));
        expect(result.scroll.dy, greaterThanOrEqualTo(0));
      });
    });
  });
}
