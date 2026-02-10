import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/widgets/cell_editor_overlay.dart';

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
    void Function(CellCoordinate, CellValue?, {CellFormat? detectedFormat, List<TextSpan>? richText})? onCommit,
    VoidCallback? onCancel,
    FocusNode? parentFocusNode,
    void Function(CellCoordinate, CellValue?, int, int, {CellFormat? detectedFormat, List<TextSpan>? richText})? onCommitAndNavigate,
    bool wrapText = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // Simulates the worksheet's Focus widget
            if (parentFocusNode != null)
              Focus(
                focusNode: parentFocusNode,
                autofocus: true,
                child: const SizedBox.expand(),
              ),
            CellEditorOverlay(
              editController: controller,
              cellBounds: cellBounds,
              onCommit: onCommit ?? (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
              onCancel: onCancel ?? () {},
              onCommitAndNavigate: onCommitAndNavigate,
              wrapText: wrapText,
            ),
          ],
        ),
      ),
    );
  }

  group('CellEditorOverlay', () {
    testWidgets('shows nothing when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(controller: editController));

      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('shows TextField when editing', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Hello'),
      );

      await tester.pumpWidget(buildTestWidget(controller: editController));

      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('displays current text in TextField', (tester) async {
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: const CellValue.text('Test Value'),
      );

      await tester.pumpWidget(buildTestWidget(controller: editController));

      final textField = tester.widget<EditableText>(find.byType(EditableText));
      expect(textField.controller.text, 'Test Value');
    });

    testWidgets('updates controller when text changes', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));

      await tester.enterText(find.byType(EditableText), 'New Text');

      expect(editController.currentText, 'New Text');
    });

    testWidgets('commits on Enter key', (tester) async {
      editController.startEdit(cell: const CellCoordinate(2, 3));

      CellCoordinate? committedCell;
      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (cell, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
          committedCell = cell;
          committedValue = value;
        },
      ));

      await tester.enterText(find.byType(EditableText), 'Committed');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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

    testWidgets('auto-focuses when editing starts', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));
      await tester.pump(); // Allow focus to settle

      final textField = tester.widget<EditableText>(find.byType(EditableText));
      expect(textField.focusNode.hasFocus, isTrue);
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

      // Find the Positioned > Transform > FocusScope > ConstrainedBox
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      final transform = positioned.child as Transform;
      final focusScope = transform.child as FocusScope;
      final constrainedBox = focusScope.child as ConstrainedBox;

      // Should use minimum width, not the narrow cell width
      expect(constrainedBox.constraints.minWidth, greaterThanOrEqualTo(CellEditorOverlay.minWidth));
    });

    testWidgets('hides when editing completes', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      await tester.pumpWidget(buildTestWidget(controller: editController));
      expect(find.byType(EditableText), findsOneWidget);

      editController.commitEdit(onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {});
      await tester.pump();

      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('commits number value', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (_, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) => committedValue = value,
      ));

      await tester.enterText(find.byType(EditableText), '42.5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(committedValue?.type, CellValueType.number);
      expect(committedValue?.rawValue, 42.5);
    });

    testWidgets('commits formula value', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      CellValue? committedValue;

      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        onCommit: (_, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) => committedValue = value,
      ));

      await tester.enterText(find.byType(EditableText), '=SUM(A1:A10)');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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
      final textField = tester.widget<EditableText>(find.byType(EditableText));
      final controller = textField.controller;

      // Selection should cover entire text
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'Select Me'.length);
    });

    group('focus management', () {
      // These tests conditionally render the overlay (matching real app usage)
      // so that initState captures the correct previousFocus.
      Widget buildConditionalOverlay({
        required EditController controller,
        required FocusNode parentFocusNode,
        void Function(CellCoordinate, CellValue?, {CellFormat? detectedFormat, List<TextSpan>? richText})? onCommit,
        VoidCallback? onCancel,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Stack(
                  children: [
                    Focus(
                      focusNode: parentFocusNode,
                      autofocus: true,
                      child: const SizedBox.expand(),
                    ),
                    if (controller.isEditing)
                      CellEditorOverlay(
                        editController: controller,
                        cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                        onCommit: onCommit ?? (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                        onCancel: onCancel ?? () {},
                      ),
                  ],
                );
              },
            ),
          ),
        );
      }

      testWidgets('TextField receives focus when editing starts',
          (tester) async {
        final parentFocus = FocusNode(debugLabel: 'parent');
        addTearDown(parentFocus.dispose);

        await tester.pumpWidget(buildConditionalOverlay(
          controller: editController,
          parentFocusNode: parentFocus,
        ));
        await tester.pump();
        expect(parentFocus.hasFocus, isTrue);

        // Start editing — overlay appears, captures previousFocus, takes focus
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );
        await tester.pump();
        await tester.pump();

        final textField = tester.widget<EditableText>(find.byType(EditableText));
        expect(textField.focusNode.hasFocus, isTrue);
        expect(parentFocus.hasFocus, isFalse);
      });

      testWidgets('focus returns to parent on commit', (tester) async {
        final parentFocus = FocusNode(debugLabel: 'parent');
        addTearDown(parentFocus.dispose);

        await tester.pumpWidget(buildConditionalOverlay(
          controller: editController,
          parentFocusNode: parentFocus,
        ));
        await tester.pump();
        expect(parentFocus.hasFocus, isTrue);

        // Start editing
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );
        await tester.pump();
        await tester.pump();

        // Commit the edit
        await tester.enterText(find.byType(EditableText), 'World');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        // Parent should have focus again
        expect(parentFocus.hasFocus, isTrue);
      });

      testWidgets('focus returns to parent on cancel', (tester) async {
        final parentFocus = FocusNode(debugLabel: 'parent');
        addTearDown(parentFocus.dispose);

        await tester.pumpWidget(buildConditionalOverlay(
          controller: editController,
          parentFocusNode: parentFocus,
        ));
        await tester.pump();
        expect(parentFocus.hasFocus, isTrue);

        // Start editing
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );
        await tester.pump();
        await tester.pump();

        // Cancel with Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Parent should have focus again
        expect(parentFocus.hasFocus, isTrue);
      });
    });

    group('onCommitAndNavigate', () {
      testWidgets('Enter calls onCommitAndNavigate with rowDelta=1',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 4),
          currentValue: const CellValue.text('Hello'),
        );

        CellCoordinate? navCell;
        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navCell = cell;
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(navCell, const CellCoordinate(3, 4));
        expect(navRowDelta, 1);
        expect(navColDelta, 0);
      });

      testWidgets('Shift+Enter calls onCommitAndNavigate with rowDelta=-1',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(5, 2),
        );

        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        expect(navRowDelta, -1);
        expect(navColDelta, 0);
      });

      testWidgets('Tab calls onCommitAndNavigate with columnDelta=1',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(2, 3),
        );

        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(navRowDelta, 0);
        expect(navColDelta, 1);
      });

      testWidgets('Shift+Tab calls onCommitAndNavigate with columnDelta=-1',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(2, 5),
        );

        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        expect(navRowDelta, 0);
        expect(navColDelta, -1);
      });

      testWidgets(
          'Enter falls back to onCommit when onCommitAndNavigate is null',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(1, 1),
        );

        CellCoordinate? committedCell;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommit: (cell, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            committedCell = cell;
          },
          // onCommitAndNavigate is null
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(committedCell, const CellCoordinate(1, 1));
      });

      testWidgets('Tab does not cause focus traversal', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
        );

        var navigateCalled = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navigateCalled = true;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        // Tab should have been handled (commit+navigate), not passed through
        expect(navigateCalled, isTrue);
      });

      testWidgets('numpadEnter commits and navigates down', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(1, 1),
        );

        int? navRowDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        await tester.pump();

        expect(navRowDelta, 1);
      });

      testWidgets('ArrowDown commits and navigates down', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 2),
        );

        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(navRowDelta, 1);
        expect(navColDelta, 0);
      });

      testWidgets('ArrowUp commits and navigates up', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 2),
        );

        int? navRowDelta;
        int? navColDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
            navColDelta = colDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(navRowDelta, -1);
        expect(navColDelta, 0);
      });

      testWidgets('ArrowRight moves text cursor instead of navigating',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 2),
          currentValue: const CellValue.text('abc'),
        );

        bool navigated = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta,
              {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navigated = true;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(navigated, isFalse);
        expect(editController.isEditing, isTrue);
      });

      testWidgets('ArrowLeft moves text cursor instead of navigating',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 2),
          currentValue: const CellValue.text('abc'),
        );

        bool navigated = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta,
              {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navigated = true;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(navigated, isFalse);
        expect(editController.isEditing, isTrue);
      });
    });

    group('multi-line editing (wrapText)', () {
      testWidgets('maxLines is null when wrapText is true', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: true,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, isNull);
      });

      testWidgets('maxLines is 1 when wrapText is false', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: false,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, 1);
      });

      testWidgets('Alt+Enter inserts newline when wrapText is true',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Line1'),
        );

        var committed = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: true,
          onCommit: (_, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            committed = true;
          },
        ));
        await tester.pump();

        // Place cursor at end
        final editableText = find.byType(EditableText);
        await tester.tap(editableText);
        await tester.pump();

        // Alt+Enter should insert newline, not commit
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(committed, isFalse);
        expect(editController.isEditing, isTrue);
        expect(editController.currentText, contains('\n'));
      });

      testWidgets('plain Enter still commits when wrapText is true',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        var committed = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: true,
          onCommit: (_, value, {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            committed = true;
          },
        ));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(committed, isTrue);
      });

      testWidgets('Shift+Enter still commits upward when wrapText is true',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(3, 2),
        );

        int? navRowDelta;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: true,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta,
              {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            navRowDelta = rowDelta;
          },
        ));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        expect(navRowDelta, -1);
      });

      testWidgets('Alt+Enter does not insert newline when wrapText is false',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        var committed = false;

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          wrapText: false,
          onCommitAndNavigate: (cell, value, rowDelta, colDelta,
              {CellFormat? detectedFormat, List<TextSpan>? richText}) {
            committed = true;
          },
        ));
        await tester.pump();

        // Alt+Enter when wrapText is false should commit (Alt is ignored)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(committed, isTrue);
      });

      testWidgets('editor uses ConstrainedBox that can grow when wrapText is true',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          cellBounds: const Rect.fromLTWH(100, 50, 120, 30),
          wrapText: true,
        ));

        // Navigate widget tree: Positioned > Transform > FocusScope > ConstrainedBox
        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        final transform = positioned.child as Transform;
        final focusScope = transform.child as FocusScope;
        final constrainedBox = focusScope.child as ConstrainedBox;
        expect(constrainedBox.constraints.maxHeight, double.infinity);
        expect(constrainedBox.constraints.minHeight, 30.0);
      });
    });

    group('cursor position based on trigger', () {
      testWidgets('typing trigger places cursor at end', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          trigger: EditTrigger.typing,
          initialText: 'x',
        );

        await tester.pumpWidget(buildTestWidget(controller: editController));
        await tester.pump();

        final textField = tester.widget<EditableText>(find.byType(EditableText));
        final tc = textField.controller;

        // For typing trigger, cursor should be at end (collapsed)
        expect(tc.selection.isCollapsed, isTrue);
        expect(tc.selection.baseOffset, 'x'.length);
      });

      testWidgets('F2 trigger selects all text', (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
          trigger: EditTrigger.f2Key,
        );

        await tester.pumpWidget(buildTestWidget(controller: editController));
        await tester.pump();

        final textField = tester.widget<EditableText>(find.byType(EditableText));
        final tc = textField.controller;

        // For F2 trigger, all text should be selected
        expect(tc.selection.start, 0);
        expect(tc.selection.end, 'Hello'.length);
      });
    });
  });
}
