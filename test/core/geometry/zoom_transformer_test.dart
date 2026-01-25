import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';

void main() {
  group('ZoomTransformer', () {
    group('construction', () {
      test('creates with default zoom level', () {
        final transformer = ZoomTransformer();
        expect(transformer.scale, 1.0);
      });

      test('creates with custom zoom level', () {
        final transformer = ZoomTransformer(scale: 2.0);
        expect(transformer.scale, 2.0);
      });

      test('clamps zoom to minimum', () {
        final transformer = ZoomTransformer(scale: 0.05);
        expect(transformer.scale, 0.1); // min is 0.1 (10%)
      });

      test('clamps zoom to maximum', () {
        final transformer = ZoomTransformer(scale: 5.0);
        expect(transformer.scale, 4.0); // max is 4.0 (400%)
      });

      test('allows custom min/max', () {
        final transformer = ZoomTransformer(
          scale: 0.5,
          minScale: 0.25,
          maxScale: 8.0,
        );
        expect(transformer.minScale, 0.25);
        expect(transformer.maxScale, 8.0);
      });
    });

    group('setScale', () {
      test('updates scale', () {
        final transformer = ZoomTransformer();
        transformer.setScale(1.5);
        expect(transformer.scale, 1.5);
      });

      test('clamps to min', () {
        final transformer = ZoomTransformer();
        transformer.setScale(0.01);
        expect(transformer.scale, 0.1);
      });

      test('clamps to max', () {
        final transformer = ZoomTransformer();
        transformer.setScale(10.0);
        expect(transformer.scale, 4.0);
      });
    });

    group('screenToWorksheet', () {
      test('returns same point at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final point = transformer.screenToWorksheet(const Offset(100, 50));
        expect(point.dx, 100.0);
        expect(point.dy, 50.0);
      });

      test('scales up at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        // Screen 100,50 at 2x zoom corresponds to worksheet 50,25
        final point = transformer.screenToWorksheet(const Offset(100, 50));
        expect(point.dx, 50.0);
        expect(point.dy, 25.0);
      });

      test('scales down at scale 0.5', () {
        final transformer = ZoomTransformer(scale: 0.5);
        // Screen 100,50 at 0.5x zoom corresponds to worksheet 200,100
        final point = transformer.screenToWorksheet(const Offset(100, 50));
        expect(point.dx, 200.0);
        expect(point.dy, 100.0);
      });
    });

    group('worksheetToScreen', () {
      test('returns same point at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final point = transformer.worksheetToScreen(const Offset(100, 50));
        expect(point.dx, 100.0);
        expect(point.dy, 50.0);
      });

      test('scales down at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        // Worksheet 100,50 at 2x zoom appears at screen 200,100
        final point = transformer.worksheetToScreen(const Offset(100, 50));
        expect(point.dx, 200.0);
        expect(point.dy, 100.0);
      });

      test('scales up at scale 0.5', () {
        final transformer = ZoomTransformer(scale: 0.5);
        // Worksheet 100,50 at 0.5x zoom appears at screen 50,25
        final point = transformer.worksheetToScreen(const Offset(100, 50));
        expect(point.dx, 50.0);
        expect(point.dy, 25.0);
      });
    });

    group('screenToWorksheetRect', () {
      test('returns same rect at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final rect = transformer.screenToWorksheetRect(
          const Rect.fromLTWH(100, 50, 200, 100),
        );
        expect(rect.left, 100.0);
        expect(rect.top, 50.0);
        expect(rect.width, 200.0);
        expect(rect.height, 100.0);
      });

      test('scales at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        final rect = transformer.screenToWorksheetRect(
          const Rect.fromLTWH(100, 50, 200, 100),
        );
        expect(rect.left, 50.0);
        expect(rect.top, 25.0);
        expect(rect.width, 100.0);
        expect(rect.height, 50.0);
      });
    });

    group('worksheetToScreenRect', () {
      test('returns same rect at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final rect = transformer.worksheetToScreenRect(
          const Rect.fromLTWH(100, 50, 200, 100),
        );
        expect(rect.left, 100.0);
        expect(rect.top, 50.0);
        expect(rect.width, 200.0);
        expect(rect.height, 100.0);
      });

      test('scales at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        final rect = transformer.worksheetToScreenRect(
          const Rect.fromLTWH(100, 50, 200, 100),
        );
        expect(rect.left, 200.0);
        expect(rect.top, 100.0);
        expect(rect.width, 400.0);
        expect(rect.height, 200.0);
      });
    });

    group('screenToWorksheetSize', () {
      test('returns same size at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final size = transformer.screenToWorksheetSize(const Size(200, 100));
        expect(size.width, 200.0);
        expect(size.height, 100.0);
      });

      test('scales at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        final size = transformer.screenToWorksheetSize(const Size(200, 100));
        expect(size.width, 100.0);
        expect(size.height, 50.0);
      });
    });

    group('worksheetToScreenSize', () {
      test('returns same size at scale 1.0', () {
        final transformer = ZoomTransformer(scale: 1.0);
        final size = transformer.worksheetToScreenSize(const Size(200, 100));
        expect(size.width, 200.0);
        expect(size.height, 100.0);
      });

      test('scales at scale 2.0', () {
        final transformer = ZoomTransformer(scale: 2.0);
        final size = transformer.worksheetToScreenSize(const Size(200, 100));
        expect(size.width, 400.0);
        expect(size.height, 200.0);
      });
    });

    group('scaleValue', () {
      test('scales value by zoom level', () {
        final transformer = ZoomTransformer(scale: 2.0);
        expect(transformer.scaleValue(100.0), 200.0);
      });

      test('inverse scales value', () {
        final transformer = ZoomTransformer(scale: 2.0);
        expect(transformer.unscaleValue(200.0), 100.0);
      });
    });

    group('round trip', () {
      test('screen->worksheet->screen returns original', () {
        final transformer = ZoomTransformer(scale: 1.5);
        const original = Offset(150, 75);

        final worksheet = transformer.screenToWorksheet(original);
        final backToScreen = transformer.worksheetToScreen(worksheet);

        expect(backToScreen.dx, closeTo(original.dx, 0.001));
        expect(backToScreen.dy, closeTo(original.dy, 0.001));
      });

      test('worksheet->screen->worksheet returns original', () {
        final transformer = ZoomTransformer(scale: 0.75);
        const original = Offset(200, 100);

        final screen = transformer.worksheetToScreen(original);
        final backToWorksheet = transformer.screenToWorksheet(screen);

        expect(backToWorksheet.dx, closeTo(original.dx, 0.001));
        expect(backToWorksheet.dy, closeTo(original.dy, 0.001));
      });
    });

    group('zoomBucket', () {
      test('returns appropriate bucket for scale', () {
        expect(ZoomTransformer(scale: 0.15).zoomBucket, ZoomBucket.tenth);
        expect(ZoomTransformer(scale: 0.3).zoomBucket, ZoomBucket.quarter);
        expect(ZoomTransformer(scale: 0.6).zoomBucket, ZoomBucket.half);
        expect(ZoomTransformer(scale: 1.0).zoomBucket, ZoomBucket.full);
        expect(ZoomTransformer(scale: 1.5).zoomBucket, ZoomBucket.full);
        expect(ZoomTransformer(scale: 2.5).zoomBucket, ZoomBucket.twoX);
        expect(ZoomTransformer(scale: 3.5).zoomBucket, ZoomBucket.quadruple);
      });
    });

    group('percentage', () {
      test('returns scale as percentage', () {
        expect(ZoomTransformer(scale: 1.0).percentage, 100);
        expect(ZoomTransformer(scale: 0.5).percentage, 50);
        expect(ZoomTransformer(scale: 2.0).percentage, 200);
        expect(ZoomTransformer(scale: 0.25).percentage, 25);
      });

      test('setPercentage updates scale', () {
        final transformer = ZoomTransformer();
        transformer.setPercentage(150);
        expect(transformer.scale, 1.5);
      });
    });

    group('canZoomIn / canZoomOut', () {
      test('canZoomIn is false at max', () {
        final transformer = ZoomTransformer(scale: 4.0);
        expect(transformer.canZoomIn, isFalse);
      });

      test('canZoomIn is true below max', () {
        final transformer = ZoomTransformer(scale: 2.0);
        expect(transformer.canZoomIn, isTrue);
      });

      test('canZoomOut is false at min', () {
        final transformer = ZoomTransformer(scale: 0.1);
        expect(transformer.canZoomOut, isFalse);
      });

      test('canZoomOut is true above min', () {
        final transformer = ZoomTransformer(scale: 0.5);
        expect(transformer.canZoomOut, isTrue);
      });
    });
  });
}
