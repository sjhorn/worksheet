import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
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

  Widget buildWorksheet({bool? mobileMode}) {
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
              mobileMode: mobileMode,
            ),
          ),
        ),
      ),
    );
  }

  group('Mobile mode configuration', () {
    testWidgets('mobileMode: true on desktop forces mobile behavior',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      // Verify it builds without error in mobile mode on desktop
      expect(find.byType(Worksheet), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('mobileMode: false on mobile forces desktop behavior',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(buildWorksheet(mobileMode: false));
      await tester.pump();

      // Verify it builds without error in desktop mode on mobile
      expect(find.byType(Worksheet), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('mobileMode: null defaults based on platform (iOS → mobile)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(buildWorksheet(mobileMode: null));
      await tester.pump();

      expect(find.byType(Worksheet), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'mobileMode: null defaults based on platform (macOS → desktop)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(buildWorksheet(mobileMode: null));
      await tester.pump();

      expect(find.byType(Worksheet), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('Mobile mode cell selection', () {
    testWidgets('tap selects cell in mobile mode', (tester) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      // Simulate a mouse tap at cell (0, 0) center.
      // In mobile mode with mouse events, the desktop path fires.
      // Header: width=50, height=24
      // Cell (0,0): screen x=[50,150], y=[24,48], center=(100, 36)
      final gesture = await tester.startGesture(
        const Offset(100.0, 36.0),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      // Wait past the double-tap deadline (300ms) so the
      // TapGestureRecognizer wins the arena and fires onTapUp.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isTrue);
      expect(controller.focusCell, equals(const CellCoordinate(0, 0)));
    });

    testWidgets('tap on cell in desktop mode also selects cell',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: false));
      await tester.pump();

      // Tap at center of cell (0, 0)
      await tester.tapAt(const Offset(100.0, 36.0));
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isTrue);
      expect(controller.focusCell, equals(const CellCoordinate(0, 0)));
    });
  });

  group('Mobile mode data population', () {
    testWidgets('mobileMode: true builds with data', (tester) async {
      data.setCell(
          const CellCoordinate(0, 0), CellValue.text('Hello Mobile'));

      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      expect(find.byType(Worksheet), findsOneWidget);
    });
  });

  group('SuppressibleBouncingPhysics', () {
    test('applyPhysicsToUserOffset returns offset when not suppressed', () {
      final suppressor = ScrollSuppressor();
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      final result = physics.applyPhysicsToUserOffset(metrics, 10.0);
      expect(result, isNonZero);
    });

    test('applyPhysicsToUserOffset returns 0.0 when suppressed', () {
      final suppressor = ScrollSuppressor()..suppress = true;
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      expect(physics.applyPhysicsToUserOffset(metrics, 10.0), 0.0);
      expect(physics.applyPhysicsToUserOffset(metrics, -50.0), 0.0);
    });

    test('createBallisticSimulation returns null when suppressed', () {
      final suppressor = ScrollSuppressor()..suppress = true;
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      expect(physics.createBallisticSimulation(metrics, 500.0), isNull);
    });

    test('createBallisticSimulation delegates when not suppressed', () {
      final suppressor = ScrollSuppressor();
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      // BouncingScrollPhysics at rest with high velocity creates simulation
      final sim = physics.createBallisticSimulation(metrics, 500.0);
      expect(sim, isNotNull);
    });

    test('applyTo preserves suppressor reference', () {
      final suppressor = ScrollSuppressor();
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final chained = physics.applyTo(const ClampingScrollPhysics());
      expect(chained.suppressor, same(suppressor));
    });

    test('suppression is immediate via shared reference', () {
      final suppressor = ScrollSuppressor();
      final physics = SuppressibleBouncingPhysics(suppressor: suppressor);
      final chained = physics.applyTo(null);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );

      // Not suppressed — returns nonzero
      expect(chained.applyPhysicsToUserOffset(metrics, 10.0), isNonZero);

      // Suppress via shared reference — immediately returns 0
      suppressor.suppress = true;
      expect(chained.applyPhysicsToUserOffset(metrics, 10.0), 0.0);

      // Un-suppress — back to nonzero
      suppressor.suppress = false;
      expect(chained.applyPhysicsToUserOffset(metrics, 10.0), isNonZero);
    });
  });

  group('Mobile handle drag scroll suppression', () {
    // Layout constants (WorksheetThemeData defaults, zoom=1.0):
    // Row header width: 50, column header height: 24
    // Cell width: 100, cell height: 24
    //
    // Cell (r, c) screen bounds:
    //   x: [50 + c*100, 50 + (c+1)*100]
    //   y: [24 + r*24, 24 + (r+1)*24]
    //
    // Selection handles are circles (radius ~8) at the top-left and
    // bottom-right corners of the selection range.

    testWidgets(
        'touch drag on selection handle does not scroll in mobile mode',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      // Select range (1,1) to (3,3) programmatically
      controller.selectionController.selectRange(
        const CellRange(1, 1, 3, 3),
      );
      await tester.pump();

      // Record scroll position before drag
      final scrollYBefore = controller.scrollY;
      final scrollXBefore = controller.scrollX;

      // Bottom-right corner of selection (3,3):
      // x = 50 + 4*100 = 450, y = 24 + 4*24 = 120
      const handlePos = Offset(450.0, 120.0);

      // Start touch drag from the bottom-right handle
      final gesture = await tester.startGesture(
        handlePos,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      // Drag downward 100 pixels (would scroll if not suppressed)
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();

      // Scroll position should not have changed
      expect(controller.scrollY, equals(scrollYBefore));
      expect(controller.scrollX, equals(scrollXBefore));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'touch drag on cell body scrolls normally in mobile mode',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      // Record scroll position before drag
      final scrollYBefore = controller.scrollY;

      // Start touch drag in the middle of the cell area (no selection
      // handle), well inside the content grid.
      const startPos = Offset(300.0, 300.0);

      final gesture = await tester.startGesture(
        startPos,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      // Drag upward to scroll down (content scrolls opposite to drag)
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      // Scroll should have moved (content scrolled down since drag was up)
      expect(controller.scrollY, greaterThan(scrollYBefore));
    });

    testWidgets(
        'scroll re-enables after handle drag ends',
        (tester) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: true));
      await tester.pump();

      // Select range (1,1) to (3,3) programmatically
      controller.selectionController.selectRange(
        const CellRange(1, 1, 3, 3),
      );
      await tester.pump();

      // Bottom-right handle position
      const handlePos = Offset(450.0, 120.0);

      // Drag handle and release
      final handleGesture = await tester.startGesture(
        handlePos,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await handleGesture.moveBy(const Offset(0, 50));
      await tester.pump();
      await handleGesture.up();
      await tester.pumpAndSettle();

      // Now do a normal cell drag — scroll should work again
      final scrollYBefore = controller.scrollY;
      const cellPos = Offset(300.0, 300.0);

      final scrollGesture = await tester.startGesture(
        cellPos,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await scrollGesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await scrollGesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await scrollGesture.up();
      await tester.pumpAndSettle();

      expect(controller.scrollY, greaterThan(scrollYBefore));
    });
  });
}
