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

    testWidgets('positions at cell bounds with text offset', (tester) async {
      editController.startEdit(cell: const CellCoordinate(0, 0));

      const bounds = Rect.fromLTWH(150, 75, 100, 30);
      await tester.pumpWidget(buildTestWidget(
        controller: editController,
        cellBounds: bounds,
      ));

      // Positioned.fromRect places at cell origin; padding is internal.
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

      // Find the ConstrainedBox wrapping EditableText
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.byType(EditableText),
          matching: find.byType(ConstrainedBox),
        ),
      );

      // Text area width = max(cellWidth, minWidth) - 2 * cellPadding.
      // minWidth (60) kicks in since cell is narrow (20).
      // Text area = 60 - 2 * 4 = 52.
      expect(constrainedBox.constraints.minWidth,
          greaterThanOrEqualTo(CellEditorOverlay.minWidth - 8.0));
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

        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.maxLines, isNull);
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

        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.maxLines, 1);
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

      testWidgets('editor uses ConstrainedBox with unconstrained height when wrapText is true',
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

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );
        // Height is unconstrained — EditableText can grow for multi-line text
        expect(constrainedBox.constraints.maxHeight, double.infinity);
        expect(constrainedBox.constraints.minHeight, 0.0);
      });
    });

    group('text selection', () {
      testWidgets('EditableText has selectionColor and rendererIgnoresPointer',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Select me'),
        );

        await tester.pumpWidget(buildTestWidget(controller: editController));

        final editableText =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.rendererIgnoresPointer, isTrue);
        expect(editableText.selectionColor, isNotNull);
        expect(editableText.selectionColor!.a, closeTo(0.3, 0.01));
      });

      testWidgets('gesture detector wraps EditableText for drag-to-select',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello World'),
        );

        await tester.pumpWidget(buildTestWidget(controller: editController));

        // The TextSelectionGestureDetector should be an ancestor of EditableText
        expect(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(TextSelectionGestureDetector),
          ),
          findsOneWidget,
        );
      });
    });

    group('rich text type-to-edit', () {
      testWidgets('type-to-edit on rich text cell shows typed character, not old value',
          (tester) async {
        // The cell had rich text content "Bold" with bold styling.
        // User starts type-to-edit by pressing 'x' — the editor should show
        // 'x' (the typed character), not 'Bold' (the old rich text).
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          trigger: EditTrigger.typing,
          initialText: 'x',
        );

        final richText = [
          const TextSpan(
            text: 'Bold',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                    richText: richText,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final textField =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(textField.controller.text, 'x');
      });
    });

    group('expandedBounds', () {
      testWidgets('widens editor ConstrainedBox when expandedBounds is set',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        // Original cell is 80px wide, expanded bounds is 200px wide
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    expandedBounds: const Rect.fromLTWH(100, 50, 200, 24),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );

        // The expanded width minus padding should be used
        // 200px / 1.0 zoom - 2 * 4.0 padding = 192.0
        expect(constrainedBox.constraints.maxWidth, 192.0);
      });

      testWidgets('expandedBounds is ignored for wrapText cells',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        // For wrapText, width should stay at the original cell size
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    expandedBounds: const Rect.fromLTWH(100, 50, 80, 100),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                    wrapText: true,
                  ),
                ],
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );

        // Width should be original cell width minus padding, not expanded
        // 80px / 1.0 zoom - 2 * 4.0 padding = 72.0
        expect(constrainedBox.constraints.maxWidth, 72.0);
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

      testWidgets('doubleTap with tapPosition places cursor at tap location',
          (tester) async {
        const cellBounds = Rect.fromLTWH(100, 50, 200, 30);
        const fontSize = 14.0;
        const cellPadding = 4.0;
        const text = 'Hello World';

        // Measure where character index 5 (the space) starts using the same
        // TextStyle the overlay uses.
        final textStyle = TextStyle(fontSize: fontSize);
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        // Get the x offset for the middle of character 5.
        final charBox = painter.getBoxesForSelection(
          const TextSelection(baseOffset: 5, extentOffset: 6),
        );
        // Use the left edge of the character box + a small nudge.
        final charX = charBox.first.left + 1.0;
        painter.dispose();

        // Tap position in the overlay's coordinate space:
        // cellBounds.topLeft + Offset(leftPad + charX, verticalOffset + charY) * zoom
        // At zoom=1.0, vertical middle alignment:
        // verticalOffset = (30 - textHeight) / 2
        // We don't need exact verticalOffset for the test — charY just needs
        // to be within the text line bounds.
        final tapPosition = Offset(
          cellBounds.left + cellPadding + charX,
          cellBounds.top + cellBounds.height / 2, // vertically centered
        );

        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text(text),
          trigger: EditTrigger.doubleTap,
          tapPosition: tapPosition,
        );

        await tester.pumpWidget(buildTestWidget(
          controller: editController,
          cellBounds: cellBounds,
        ));
        await tester.pump();

        final textField =
            tester.widget<EditableText>(find.byType(EditableText));
        final tc = textField.controller;

        // Cursor should be at or near character 5, not at end (11).
        expect(tc.selection.isCollapsed, isTrue);
        expect(tc.selection.baseOffset, 5,
            reason: 'cursor should be at the tapped character position');
      });

      testWidgets('doubleTap without tapPosition falls back to cursor at end',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
          trigger: EditTrigger.doubleTap,
          // No tapPosition provided
        );

        await tester.pumpWidget(buildTestWidget(controller: editController));
        await tester.pump();

        final textField =
            tester.widget<EditableText>(find.byType(EditableText));
        final tc = textField.controller;

        expect(tc.selection.isCollapsed, isTrue);
        expect(tc.selection.baseOffset, 'Hello'.length,
            reason: 'without tapPosition, cursor should fall back to end');
      });
    });

    group('contentAreaWidth', () {
      testWidgets('clamps non-wrap editor width at viewport right edge',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        // Cell at x=100, 80px wide. Expanded bounds 400px wide.
        // contentAreaWidth = 300 (simulating viewport right edge).
        // Editor left = cellBounds.left + cellPadding*zoom = 100 + 4*1 = 104.
        // maxRenderedWidth = 300 - 104 = 196.
        // maxTextAreaWidth = 196 / 1.0 = 196.
        // Unclamped textAreaWidth = 400 - 2*4 = 392 (from expandedBounds).
        // Clamped to 196.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    expandedBounds: const Rect.fromLTWH(100, 50, 400, 24),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                    contentAreaWidth: 300,
                  ),
                ],
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );

        // Clamped to 196.0
        expect(constrainedBox.constraints.maxWidth, 196.0);
      });

      testWidgets('does not clamp wrap-text editor width',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        // For wrapText cells, contentAreaWidth should be ignored.
        // Cell is 80px, effectiveWidth = 80, textAreaWidth = 80 - 8 = 72.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                    wrapText: true,
                    contentAreaWidth: 120,
                  ),
                ],
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );

        // Wrap-text: width should be original cell width minus padding = 72.0
        expect(constrainedBox.constraints.maxWidth, 72.0);
      });

      testWidgets('does not clamp when editor fits within viewport',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        // Expanded to 200px, contentAreaWidth = 500 — plenty of room.
        // textAreaWidth = 200 - 8 = 192 (no clamping needed).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(100, 50, 80, 24),
                    expandedBounds: const Rect.fromLTWH(100, 50, 200, 24),
                    onCommit: (_, _, {CellFormat? detectedFormat, List<TextSpan>? richText}) {},
                    onCancel: () {},
                    contentAreaWidth: 500,
                  ),
                ],
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(EditableText),
            matching: find.byType(ConstrainedBox),
          ),
        );

        // Not clamped — original expanded width used: 200 - 8 = 192
        expect(constrainedBox.constraints.maxWidth, 192.0);
      });
    });

    group('toolbar focus', () {
      testWidgets('tapping external button while editing keeps editor focused',
          (tester) async {
        bool toolbarTapped = false;
        // Simulates the worksheet's keyboard focus node that competes
        // for focus with the editor.
        final worksheetFocusNode = FocusNode(debugLabel: 'worksheet');

        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // Toolbar button outside the overlay — wrapped in
                  // FocusScope(canRequestFocus: false) to prevent
                  // stealing focus from the editor.
                  FocusScope(
                    canRequestFocus: false,
                    child: IconButton(
                      icon: const Icon(Icons.format_bold),
                      onPressed: () => toolbarTapped = true,
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      focusNode: worksheetFocusNode,
                      child: Stack(
                        children: [
                          CellEditorOverlay(
                            editController: editController,
                            cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                            onCommit: (_, _, {CellFormat? detectedFormat,
                                List<TextSpan>? richText}) {},
                            onCancel: () {},
                            restoreFocusTo: worksheetFocusNode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify editor is focused
        final editableText =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'editor should be focused initially');

        // Tap the toolbar button
        await tester.tap(find.byIcon(Icons.format_bold));
        await tester.pumpAndSettle();

        // The toolbar action should have fired
        expect(toolbarTapped, isTrue);

        // Editor should still be editing and focused
        expect(editController.isEditing, isTrue,
            reason: 'editor should still be editing after toolbar tap');
        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'editor should retain focus after toolbar tap');
      });

      testWidgets(
          'calling toggleBold while editing keeps editor focused',
          (tester) async {
        final worksheetFocusNode = FocusNode(debugLabel: 'worksheet');

        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FocusScope(
                    canRequestFocus: false,
                    child: IconButton(
                      icon: const Icon(Icons.format_bold),
                      onPressed: () => editController.toggleBold(),
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      focusNode: worksheetFocusNode,
                      child: Stack(
                        children: [
                          CellEditorOverlay(
                            editController: editController,
                            cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                            onCommit: (_, _, {CellFormat? detectedFormat,
                                List<TextSpan>? richText}) {},
                            onCancel: () {},
                            restoreFocusTo: worksheetFocusNode,
                            richText: const [TextSpan(text: 'Hello')],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final editableText =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'editor should be focused initially');

        // Tap the toolbar button which calls toggleBold
        await tester.tap(find.byIcon(Icons.format_bold));
        await tester.pumpAndSettle();

        // Editor should still be editing and focused
        expect(editController.isEditing, isTrue,
            reason: 'editor should still be editing after toggleBold');
        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'editor should retain focus after toggleBold');
      });

      testWidgets(
          'editor retains focus when overlay rebuilds due to prop change',
          (tester) async {
        // Simulates what happens when a toolbar button changes cell style
        // (BG color, alignment, wrap text) while editing — the overlay
        // rebuilds with different props but should keep focus.
        final worksheetFocusNode = FocusNode(debugLabel: 'worksheet');
        bool wrapText = false;

        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setOuterState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      FocusScope(
                        canRequestFocus: false,
                        child: IconButton(
                          icon: const Icon(Icons.wrap_text),
                          onPressed: () {
                            setOuterState(() {
                              wrapText = !wrapText;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Focus(
                          focusNode: worksheetFocusNode,
                          child: Stack(
                            children: [
                              CellEditorOverlay(
                                editController: editController,
                                cellBounds:
                                    const Rect.fromLTWH(0, 0, 200, 30),
                                onCommit: (_, _, {CellFormat? detectedFormat,
                                    List<TextSpan>? richText}) {},
                                onCancel: () {},
                                restoreFocusTo: worksheetFocusNode,
                                wrapText: wrapText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        await tester.pumpAndSettle();

        final editableText =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'editor should be focused initially');
        expect(editableText.maxLines, 1, reason: 'single-line initially');

        // Tap wrap text — rebuilds overlay with wrapText: true
        await tester.tap(find.byIcon(Icons.wrap_text));
        await tester.pumpAndSettle();

        // Re-find EditableText since it may have been rebuilt
        final editableText2 =
            tester.widget<EditableText>(find.byType(EditableText));

        expect(editController.isEditing, isTrue,
            reason: 'editor should still be editing after wrap toggle');
        expect(editableText2.maxLines, isNull,
            reason: 'wrap text should now be multi-line');
        expect(editableText2.focusNode.hasFocus, isTrue,
            reason: 'editor should retain focus after overlay rebuild');
      });

      testWidgets('registers editorFocusNode on EditController',
          (tester) async {
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        expect(editController.editorFocusNode, isNull,
            reason: 'no focus node before overlay is built');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  CellEditorOverlay(
                    editController: editController,
                    cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                    onCommit: (_, _, {CellFormat? detectedFormat,
                        List<TextSpan>? richText}) {},
                    onCancel: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(editController.editorFocusNode, isNotNull,
            reason: 'overlay should register its focus node');
        expect(editController.editorFocusNode!.hasFocus, isTrue,
            reason: 'editor should have focus');
      });

      testWidgets('requestEditorFocus restores focus and selection',
          (tester) async {
        final stealerFocus = FocusNode(debugLabel: 'stealer');
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: stealerFocus,
                    child: const SizedBox(width: 50, height: 50),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        CellEditorOverlay(
                          editController: editController,
                          cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                          onCommit: (_, _, {CellFormat? detectedFormat,
                              List<TextSpan>? richText}) {},
                          onCancel: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editableText =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.focusNode.hasFocus, isTrue);

        // Place cursor at offset 2 (between "He" and "llo")
        editController.richTextController!.selection =
            const TextSelection.collapsed(offset: 2);
        await tester.pump();

        // Steal focus away from editor (simulates toolbar click)
        stealerFocus.requestFocus();
        await tester.pump();
        expect(editableText.focusNode.hasFocus, isFalse,
            reason: 'focus should be stolen');

        // Request editor focus restoration
        editController.requestEditorFocus();
        await tester.pumpAndSettle();

        expect(editableText.focusNode.hasFocus, isTrue,
            reason: 'requestEditorFocus should restore focus');
        expect(editController.richTextController!.selection,
            const TextSelection.collapsed(offset: 2),
            reason: 'selection should be preserved, not reset to select-all');
      });

      testWidgets(
          'toggleBold at end of text preserves cursor instead of selecting all',
          (tester) async {
        final stealerFocus = FocusNode(debugLabel: 'toolbar');

        // Double-tap trigger → cursor placed at end
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
          trigger: EditTrigger.doubleTap,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: stealerFocus,
                    child: const SizedBox(width: 50, height: 50),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        CellEditorOverlay(
                          editController: editController,
                          cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                          onCommit: (_, _, {CellFormat? detectedFormat,
                              List<TextSpan>? richText}) {},
                          onCancel: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final controller = editController.richTextController!;

        // Verify initial state: cursor at end (doubleTap trigger)
        expect(controller.selection,
            const TextSelection.collapsed(offset: 5),
            reason: 'doubleTap trigger should place cursor at end');

        // Simulate toolbar Bold click: focus stolen → toggleBold → restore
        stealerFocus.requestFocus();
        await tester.pump();
        expect(editController.editorFocusNode!.hasFocus, isFalse);

        editController.toggleBold();
        editController.requestEditorFocus();
        await tester.pumpAndSettle();

        // Focus should be restored
        expect(editController.editorFocusNode!.hasFocus, isTrue,
            reason: 'editor should regain focus');

        // Selection should be collapsed at end, NOT selecting all text
        expect(controller.selection.isCollapsed, isTrue,
            reason: 'selection should be collapsed, not select-all');
        expect(controller.selection,
            const TextSelection.collapsed(offset: 5),
            reason: 'cursor should remain at end of text');
      });

      testWidgets(
          'restoration guard reverses platform select-all after focus regain',
          (tester) async {
        // This simulates the web platform behaviour: after focus is restored,
        // the text input connection re-opens and the platform sends a
        // select-all that overrides our restored selection.
        final stealerFocus = FocusNode(debugLabel: 'toolbar');

        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
          trigger: EditTrigger.doubleTap,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: stealerFocus,
                    child: const SizedBox(width: 50, height: 50),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        CellEditorOverlay(
                          editController: editController,
                          cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                          onCommit: (_, _, {CellFormat? detectedFormat,
                              List<TextSpan>? richText}) {},
                          onCancel: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final controller = editController.richTextController!;
        expect(controller.selection,
            const TextSelection.collapsed(offset: 5));

        // Steal focus
        stealerFocus.requestFocus();
        await tester.pump();

        // Restore focus (arms the guard)
        editController.requestEditorFocus();
        await tester.pumpAndSettle();
        expect(controller.selection,
            const TextSelection.collapsed(offset: 5),
            reason: 'selection restored after focus regain');

        // Simulate platform select-all (what the browser does on web)
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 5,
        );

        // The guard should have caught and reversed it
        expect(controller.selection,
            const TextSelection.collapsed(offset: 5),
            reason: 'guard should reverse platform select-all');
      });

      testWidgets(
          'toggleBold with F2 trigger preserves mid-text cursor position',
          (tester) async {
        final stealerFocus = FocusNode(debugLabel: 'toolbar');

        // F2 trigger → initially selects all
        editController.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
          trigger: EditTrigger.f2Key,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: stealerFocus,
                    child: const SizedBox(width: 50, height: 50),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        CellEditorOverlay(
                          editController: editController,
                          cellBounds: const Rect.fromLTWH(0, 0, 200, 30),
                          onCommit: (_, _, {CellFormat? detectedFormat,
                              List<TextSpan>? richText}) {},
                          onCancel: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final controller = editController.richTextController!;

        // F2 initially selects all text
        expect(controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 5),
            reason: 'F2 should initially select all');

        // User moves cursor to offset 3 (between "Hel" and "lo")
        controller.selection = const TextSelection.collapsed(offset: 3);
        await tester.pump();

        // Simulate toolbar Bold click: steal focus → toggle → restore
        stealerFocus.requestFocus();
        await tester.pump();

        editController.toggleBold();
        editController.requestEditorFocus();
        await tester.pumpAndSettle();

        expect(editController.editorFocusNode!.hasFocus, isTrue);
        expect(controller.selection,
            const TextSelection.collapsed(offset: 3),
            reason: 'cursor at offset 3 should be preserved after Bold');
      });
    });
  });
}
