import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/rendering/layers/render_layer.dart';

// Concrete test implementation of RenderLayer
class TestRenderLayer extends RenderLayer {
  int paintCallCount = 0;

  TestRenderLayer({super.enabled});

  @override
  int get order => 0;

  @override
  void paint(LayerPaintContext context) {
    paintCallCount++;
  }
}

void main() {
  group('LayerPaintContext', () {
    test('stores canvas and viewport info', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: const Offset(100, 50),
        zoom: 1.5,
      );

      expect(context.canvas, canvas);
      expect(context.viewportSize, const Size(800, 600));
      expect(context.scrollOffset, const Offset(100, 50));
      expect(context.zoom, 1.5);

      recorder.endRecording();
    });
  });

  group('RenderLayer', () {
    test('creates with enabled=true by default', () {
      final layer = TestRenderLayer();
      expect(layer.enabled, isTrue);
    });

    test('creates with enabled=false when specified', () {
      final layer = TestRenderLayer(enabled: false);
      expect(layer.enabled, isFalse);
    });

    test('markNeedsPaint does nothing by default', () {
      final layer = TestRenderLayer();
      // Should not throw
      expect(() => layer.markNeedsPaint(), returnsNormally);
    });

    test('dispose does nothing by default', () {
      final layer = TestRenderLayer();
      // Should not throw
      expect(() => layer.dispose(), returnsNormally);
    });

    test('enabled can be toggled', () {
      final layer = TestRenderLayer();
      expect(layer.enabled, isTrue);

      layer.enabled = false;
      expect(layer.enabled, isFalse);

      layer.enabled = true;
      expect(layer.enabled, isTrue);
    });
  });
}
