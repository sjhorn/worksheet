import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    controller = WorksheetController();
  });

  tearDown(() {
    controller.dispose();
    data.dispose();
  });

  Widget buildWorksheet({bool readOnly = false}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Worksheet(
              data: data,
              controller: controller,
              rowCount: 100,
              columnCount: 26,
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );
  }

  /// Simulates a trackpad pinch gesture (macOS/Linux) using PointerPanZoom
  /// events, which is what native platforms generate for trackpad pinch.
  Future<void> sendTrackpadPinch(
    WidgetTester tester,
    double scale, {
    Offset position = const Offset(400, 300),
  }) async {
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    tester.binding.handlePointerEvent(pointer.panZoomStart(position));
    await tester.pump();
    tester.binding.handlePointerEvent(
      pointer.panZoomUpdate(position, scale: scale),
    );
    await tester.pump();
    tester.binding.handlePointerEvent(pointer.panZoomEnd());
    await tester.pump();
  }

  /// Simulates a web browser pinch-to-zoom using PointerScaleEvent
  /// (a PointerSignalEvent), which is what web generates.
  Future<void> sendWebScale(
    WidgetTester tester,
    double scale, {
    Offset position = const Offset(400, 300),
  }) async {
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    tester.binding.handlePointerEvent(pointer.hover(position));
    tester.binding.handlePointerEvent(
      PointerScaleEvent(position: position, scale: scale),
    );
    await tester.pump();
  }

  group('Trackpad pinch-to-zoom (native: PointerPanZoom events)', () {
    testWidgets('zoom in: scale > 1.0 increases zoom', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendTrackpadPinch(tester, 1.5);

      expect(controller.zoom, 1.5);
    });

    testWidgets('zoom out: scale < 1.0 decreases zoom', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendTrackpadPinch(tester, 0.8);

      expect(controller.zoom, closeTo(0.8, 0.001));
    });

    testWidgets('at max limit: zoom stays clamped', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      controller.zoomController.value = 4.0;
      await tester.pump();

      await sendTrackpadPinch(tester, 1.1);

      expect(controller.zoom, 4.0);
    });

    testWidgets('at min limit: zoom stays clamped', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      controller.zoomController.value = 0.1;
      await tester.pump();

      await sendTrackpadPinch(tester, 0.9);

      expect(controller.zoom, 0.1);
    });

    testWidgets('scale 1.0 is a no-op', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendTrackpadPinch(tester, 1.0);

      expect(controller.zoom, 1.0);
    });

    testWidgets('works in readOnly mode', (tester) async {
      await tester.pumpWidget(buildWorksheet(readOnly: true));
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendTrackpadPinch(tester, 1.5);

      expect(controller.zoom, 1.5);
    });
  });

  group('Web pinch-to-zoom (PointerScaleEvent)', () {
    testWidgets('zoom in: scale > 1.0 increases zoom', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendWebScale(tester, 1.5);

      expect(controller.zoom, 1.5);
    });

    testWidgets('zoom out: scale < 1.0 decreases zoom', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendWebScale(tester, 0.8);

      expect(controller.zoom, closeTo(0.8, 0.001));
    });

    testWidgets('scale 1.0 is a no-op', (tester) async {
      await tester.pumpWidget(buildWorksheet());
      await tester.pumpAndSettle();

      expect(controller.zoom, 1.0);

      await sendWebScale(tester, 1.0);

      expect(controller.zoom, 1.0);
    });
  });
}
