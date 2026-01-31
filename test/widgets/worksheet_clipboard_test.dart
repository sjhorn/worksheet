import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/scrolling/worksheet_viewport.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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

  void installMockClipboard(String text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': text};
      }
      if (call.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  }

  /// Finds the [RenderWorksheetViewport] in the widget tree.
  RenderWorksheetViewport findViewportRenderObject(WidgetTester tester) {
    final element = tester.element(find.byType(WorksheetViewport));
    return element.renderObject! as RenderWorksheetViewport;
  }

  group('Worksheet clipboard visual update', () {
    testWidgets('paste triggers immediate repaint without needing a click',
        (tester) async {
      installMockClipboard('Pasted');
      await tester.pumpWidget(buildWorksheet());

      controller.selectCell(const CellCoordinate(1, 1));
      await tester.pump();

      // Record the layout version before paste
      final renderObject = findViewportRenderObject(tester);
      final versionBefore = renderObject.layoutVersion;

      // Trigger paste via Cmd/Ctrl+V
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // A single pump should process the async clipboard read and
      // the subsequent setState/layoutVersion bump.
      await tester.pump();

      // Data should be written
      expect(data.getCell(const CellCoordinate(1, 1)),
          const CellValue.text('Pasted'));

      // Layout version should have incremented, proving repaint was triggered
      expect(renderObject.layoutVersion, greaterThan(versionBefore));
    });

    testWidgets('cut triggers immediate repaint without needing a click',
        (tester) async {
      data[(2, 2)] = 'CutMe'.cell;

      // Mock clipboard to capture setData
      String? clipboardContent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardContent = args['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(buildWorksheet());

      controller.selectCell(const CellCoordinate(2, 2));
      await tester.pump();

      final renderObject = findViewportRenderObject(tester);
      final versionBefore = renderObject.layoutVersion;

      // Trigger cut via Cmd/Ctrl+X
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Cell should be cleared
      expect(data.getCell(const CellCoordinate(2, 2)), isNull);

      // Value should be on clipboard
      expect(clipboardContent, 'CutMe');

      // Layout version should have incremented
      expect(renderObject.layoutVersion, greaterThan(versionBefore));
    });

    testWidgets('copy does not change layout version (no data mutation)',
        (tester) async {
      data[(0, 0)] = 'Keep'.cell;

      String? clipboardContent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardContent = args['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(buildWorksheet());

      controller.selectCell(const CellCoordinate(0, 0));
      await tester.pump();

      final renderObject = findViewportRenderObject(tester);
      final versionBefore = renderObject.layoutVersion;

      // Trigger copy via Cmd/Ctrl+C
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Data should be unchanged
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('Keep'));

      // Clipboard should have the value
      expect(clipboardContent, 'Keep');

      // Layout version should NOT have changed (copy is read-only)
      expect(renderObject.layoutVersion, versionBefore);
    });
  });
}
