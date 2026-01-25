import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/interaction/controllers/zoom_controller.dart';

void main() {
  group('ZoomController', () {
    group('construction', () {
      test('creates with default zoom of 1.0', () {
        final controller = ZoomController();
        expect(controller.value, 1.0);
        controller.dispose();
      });

      test('creates with custom initial zoom', () {
        final controller = ZoomController(initialZoom: 2.0);
        expect(controller.value, 2.0);
        controller.dispose();
      });

      test('creates with custom min/max zoom', () {
        final controller = ZoomController(
          minZoom: 0.5,
          maxZoom: 3.0,
        );
        expect(controller.minZoom, 0.5);
        expect(controller.maxZoom, 3.0);
        controller.dispose();
      });

      test('clamps initial zoom to valid range', () {
        final controller = ZoomController(
          initialZoom: 10.0,
          maxZoom: 4.0,
        );
        expect(controller.value, 4.0);
        controller.dispose();
      });

      test('clamps initial zoom to min', () {
        final controller = ZoomController(
          initialZoom: 0.01,
          minZoom: 0.1,
        );
        expect(controller.value, 0.1);
        controller.dispose();
      });
    });

    group('value setter', () {
      test('sets zoom value', () {
        final controller = ZoomController();
        controller.value = 2.0;
        expect(controller.value, 2.0);
        controller.dispose();
      });

      test('clamps to max', () {
        final controller = ZoomController(maxZoom: 4.0);
        controller.value = 5.0;
        expect(controller.value, 4.0);
        controller.dispose();
      });

      test('clamps to min', () {
        final controller = ZoomController(minZoom: 0.1);
        controller.value = 0.05;
        expect(controller.value, 0.1);
        controller.dispose();
      });

      test('notifies listeners on change', () {
        final controller = ZoomController();
        var notified = false;
        controller.addListener(() => notified = true);

        controller.value = 2.0;

        expect(notified, isTrue);
        controller.dispose();
      });
    });

    group('percentage', () {
      test('returns zoom as percentage', () {
        final controller = ZoomController(initialZoom: 1.5);
        expect(controller.percentage, 150);
        controller.dispose();
      });

      test('rounds percentage', () {
        final controller = ZoomController(initialZoom: 1.555);
        expect(controller.percentage, 156);
        controller.dispose();
      });
    });

    group('setPercentage', () {
      test('sets zoom from percentage', () {
        final controller = ZoomController();
        controller.setPercentage(200);
        expect(controller.value, 2.0);
        controller.dispose();
      });

      test('clamps percentage to valid range', () {
        final controller = ZoomController(maxZoom: 4.0);
        controller.setPercentage(500);
        expect(controller.value, 4.0);
        controller.dispose();
      });
    });

    group('zoomBy', () {
      test('multiplies current zoom by factor', () {
        final controller = ZoomController(initialZoom: 1.0);
        controller.zoomBy(2.0);
        expect(controller.value, 2.0);
        controller.dispose();
      });

      test('clamps result to max', () {
        final controller = ZoomController(initialZoom: 3.0, maxZoom: 4.0);
        controller.zoomBy(2.0);
        expect(controller.value, 4.0);
        controller.dispose();
      });

      test('clamps result to min', () {
        final controller = ZoomController(initialZoom: 0.2, minZoom: 0.1);
        controller.zoomBy(0.25);
        expect(controller.value, 0.1);
        controller.dispose();
      });
    });

    group('zoomIn/zoomOut', () {
      test('zoomIn increases by step', () {
        final controller = ZoomController(initialZoom: 1.0);
        controller.zoomIn();
        expect(controller.value, greaterThan(1.0));
        controller.dispose();
      });

      test('zoomOut decreases by step', () {
        final controller = ZoomController(initialZoom: 1.0);
        controller.zoomOut();
        expect(controller.value, lessThan(1.0));
        controller.dispose();
      });

      test('zoomIn with custom step', () {
        final controller = ZoomController(initialZoom: 1.0);
        controller.zoomIn(step: 0.5);
        expect(controller.value, 1.5);
        controller.dispose();
      });

      test('zoomOut with custom step', () {
        final controller = ZoomController(initialZoom: 1.0);
        controller.zoomOut(step: 0.25);
        expect(controller.value, 0.75);
        controller.dispose();
      });

      test('zoomIn clamps to max', () {
        final controller = ZoomController(initialZoom: 3.9, maxZoom: 4.0);
        controller.zoomIn(step: 0.5);
        expect(controller.value, 4.0);
        controller.dispose();
      });

      test('zoomOut clamps to min', () {
        final controller = ZoomController(initialZoom: 0.15, minZoom: 0.1);
        controller.zoomOut(step: 0.1);
        expect(controller.value, 0.1);
        controller.dispose();
      });
    });

    group('canZoomIn/canZoomOut', () {
      test('canZoomIn returns true when below max', () {
        final controller = ZoomController(initialZoom: 1.0, maxZoom: 4.0);
        expect(controller.canZoomIn, isTrue);
        controller.dispose();
      });

      test('canZoomIn returns false when at max', () {
        final controller = ZoomController(initialZoom: 4.0, maxZoom: 4.0);
        expect(controller.canZoomIn, isFalse);
        controller.dispose();
      });

      test('canZoomOut returns true when above min', () {
        final controller = ZoomController(initialZoom: 1.0, minZoom: 0.1);
        expect(controller.canZoomOut, isTrue);
        controller.dispose();
      });

      test('canZoomOut returns false when at min', () {
        final controller = ZoomController(initialZoom: 0.1, minZoom: 0.1);
        expect(controller.canZoomOut, isFalse);
        controller.dispose();
      });
    });

    group('reset', () {
      test('resets to initial zoom', () {
        final controller = ZoomController(initialZoom: 1.5);
        controller.value = 3.0;
        controller.reset();
        expect(controller.value, 1.5);
        controller.dispose();
      });
    });

    group('animateTo', () {
      testWidgets('animates to target zoom', (tester) async {
        final controller = ZoomController(initialZoom: 1.0);

        await tester.pumpWidget(
          _TestWidget(
            onBuild: (context) {
              controller.animateTo(
                2.0,
                vsync: tester,
                duration: const Duration(milliseconds: 100),
              );
            },
          ),
        );

        expect(controller.value, 1.0);

        // Let animation run
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value, greaterThan(1.0));
        expect(controller.value, lessThan(2.0));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, 2.0);

        controller.dispose();
      });

      testWidgets('clamps animated value to max', (tester) async {
        final controller = ZoomController(initialZoom: 1.0, maxZoom: 1.5);

        await tester.pumpWidget(
          _TestWidget(
            onBuild: (context) {
              controller.animateTo(
                3.0,
                vsync: tester,
                duration: const Duration(milliseconds: 100),
              );
            },
          ),
        );

        await tester.pumpAndSettle();
        expect(controller.value, 1.5);

        controller.dispose();
      });

      testWidgets('cancels previous animation', (tester) async {
        final controller = ZoomController(initialZoom: 1.0);

        await tester.pumpWidget(
          _TestWidget(
            onBuild: (context) {
              controller.animateTo(
                3.0,
                vsync: tester,
                duration: const Duration(milliseconds: 200),
              );
            },
          ),
        );

        await tester.pump(const Duration(milliseconds: 50));

        // Start new animation
        controller.animateTo(
          1.5,
          vsync: tester,
          duration: const Duration(milliseconds: 100),
        );

        await tester.pumpAndSettle();
        expect(controller.value, 1.5);

        controller.dispose();
      });
    });

    group('zoomBucket', () {
      test('returns correct bucket for current zoom', () {
        final controller = ZoomController(initialZoom: 1.0);
        expect(controller.zoomBucket.name, 'full');

        controller.value = 0.2;
        expect(controller.zoomBucket.name, 'tenth');

        controller.value = 2.5;
        expect(controller.zoomBucket.name, 'twoX');

        controller.dispose();
      });
    });

    group('dispose', () {
      test('disposes cleanly', () {
        final controller = ZoomController();
        controller.dispose();
        // Should not throw
      });

      testWidgets('cancels animation on dispose', (tester) async {
        final controller = ZoomController(initialZoom: 1.0);

        await tester.pumpWidget(
          _TestWidget(
            onBuild: (context) {
              controller.animateTo(
                2.0,
                vsync: tester,
                duration: const Duration(milliseconds: 200),
              );
            },
          ),
        );

        await tester.pump(const Duration(milliseconds: 50));
        controller.dispose();

        // Should not throw when pumping after dispose
        await tester.pump(const Duration(milliseconds: 200));
      });
    });
  });
}

class _TestWidget extends StatelessWidget {
  final void Function(BuildContext) onBuild;

  const _TestWidget({required this.onBuild});

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox();
  }
}
