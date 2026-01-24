import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/models/cell_coordinate.dart';
import 'package:worksheet2/src/core/models/cell_value.dart';
import 'package:worksheet2/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet2/src/widgets/cell_editor_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditController editController;

  setUp(() {
    editController = EditController();
  });

  tearDown(() {
    editController.dispose();
  });

  Widget buildTestWidget({
    required EditController controller,
    Rect cellBounds = const Rect.fromLTWH(100, 50, 80, 24),
    void Function(CellCoordinate, CellValue?)? onCommit,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            CellEditorOverlay(
              editController: controller,
              cellBounds: cellBounds,
              onCommit: onCommit ?? (_, __) {},
              onCancel: onCancel ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  group('CellEditorOverlay', () {
    testWidgets('shows nothing when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(controller: editController));

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows TextField when editing', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Hello'),
      );

      await tester.pumpWidget(buildTestWidget(controller: editController));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('displays current text in TextField', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Test Value'),
      );

      await tester.pumpWidget(buildTestWidget(controller: editController));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Test Value');
    });

    testWidgets('updates controller when text changes', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));

      await tester.enterText(find.byType(TextField), 'New Text');

      expect(editController.currentText, 'New Text');
    });

    testWidgets('commits on Enter key', (tester) async {
      editController.startEdit(cell: const CellCoordinate(2, 3));

      CellCoordinate? committedCell;
      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (cell, value) {
          committedCell = cell;
          committedValue = value;
        },
      ));

      await tester.enterText(find.byType(TextField), 'Committed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(committedCell, const CellCoordinate(2, 3));
      expect(committedValue, const CellValue.text('Committed'));
    });

    testWidgets('cancels on Escape key', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Original'),
      );

      var cancelCalled = false;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCancel: () => cancelCalled = true,
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('auto-focuses TextField when editing starts', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));
      await tester.pump(); // Allow focus to settle

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('positions at cell bounds', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      const bounds = Rect.fromLTWH(150, 75, 100, 30);
      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        cellBounds: bounds,
      ));

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, bounds.left);
      expect(positioned.top, bounds.top);
    });

    testWidgets('respects minimum width', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      // Very narrow cell
      const narrowBounds = Rect.fromLTWH(100, 50, 20, 24);
      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        cellBounds: narrowBounds,
      ));

      // Find the Positioned widget and check its child SizedBox
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      final sizedBox = positioned.child as SizedBox;

      // Should use minimum width, not the narrow cell width
      expect(sizedBox.width, greaterThanOrEqualTo(CellEditorOverlay.minWidth));
    });

    testWidgets('hides when editing completes', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));
      expect(find.byType(TextField), findsOneWidget);

      editController.commitEdit(onCommit: (_, __) {});
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('commits number value', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (_, value) => committedValue = value,
      ));

      await tester.enterText(find.byType(TextField), '42.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(committedValue?.type, CellValueType.number);
      expect(committedValue?.rawValue, 42.5);
    });

    testWidgets('commits formula value', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (_, value) => committedValue = value,
      ));

      await tester.enterText(find.byType(TextField), '=SUM(A1:A10)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(committedValue?.type, CellValueType.formula);
      expect(committedValue?.rawValue, '=SUM(A1:A10)');
    });

    testWidgets('selects all text on focus', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Select Me'),
      );

      await tester.pumpWidget(buildTestWidget(controller: editController));
      await tester.pump();

      // The text should be selected - verify through controller
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller!;

      // Selection should cover entire text
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'Select Me'.length);
    });
  });
}
