import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/interaction/gestures/keyboard_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SelectionController selectionController;
  late KeyboardHandler keyboardHandler;

  setUp(() {
    selectionController = SelectionController();
    keyboardHandler = KeyboardHandler(
      selectionController: selectionController,
      maxRow: 100,
      maxColumn: 26,
    );
    // Start with a cell selected
    selectionController.selectCell(const CellCoordinate(5, 5));
  });

  tearDown(() {
    selectionController.dispose();
  });

  KeyDownEvent createKeyEvent(LogicalKeyboardKey key) {
    return KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
  }

  group('KeyboardHandler', () {
    test('creates with required parameters', () {
      expect(keyboardHandler, isNotNull);
    });

    group('arrow keys', () {
      test('arrow up moves selection up', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowUp),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(4, 5));
      });

      test('arrow down moves selection down', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowDown),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(6, 5));
      });

      test('arrow left moves selection left', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowLeft),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(5, 4));
      });

      test('arrow right moves selection right', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowRight),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(5, 6));
      });

      test('does not move past boundaries', () {
        // Select cell at origin
        selectionController.selectCell(const CellCoordinate(0, 0));

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowUp),
        );
        expect(selectionController.focus, const CellCoordinate(0, 0));

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.arrowLeft),
        );
        expect(selectionController.focus, const CellCoordinate(0, 0));
      });
    });

    group('page navigation', () {
      test('page up moves 10 rows up', () {
        selectionController.selectCell(const CellCoordinate(15, 5));

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.pageUp),
        );

        expect(selectionController.focus, const CellCoordinate(5, 5));
      });

      test('page down moves 10 rows down', () {
        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.pageDown),
        );

        expect(selectionController.focus, const CellCoordinate(15, 5));
      });
    });

    group('tab navigation', () {
      test('tab moves right', () {
        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.tab),
        );

        expect(selectionController.focus, const CellCoordinate(5, 6));
      });

      testWidgets('shift+tab moves left', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.tab),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(selectionController.focus, const CellCoordinate(5, 4));
      });
    });

    group('enter key', () {
      test('enter moves down', () {
        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.enter),
        );

        expect(selectionController.focus, const CellCoordinate(6, 5));
      });

      test('numpad enter also moves down', () {
        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.numpadEnter),
        );

        expect(selectionController.focus, const CellCoordinate(6, 5));
      });

      testWidgets('shift+enter moves up', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.enter),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(selectionController.focus, const CellCoordinate(4, 5));
      });
    });

    group('home/end navigation', () {
      test('home moves to start of row', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.home),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(5, 0));
      });

      test('end moves to end of row', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.end),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(5, 25));
      });

      testWidgets('ctrl+home moves to A1', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);

        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.home),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(0, 0));
      });

      testWidgets('ctrl+end moves to last cell', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);

        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.end),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(99, 25));
      });

      testWidgets('shift+home extends selection to start of row', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.home),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(selectionController.mode, SelectionMode.range);
        expect(selectionController.focus, const CellCoordinate(5, 0));
        expect(selectionController.anchor, const CellCoordinate(5, 5));
      });

      testWidgets('shift+end extends selection to end of row', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.end),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(selectionController.mode, SelectionMode.range);
        expect(selectionController.focus, const CellCoordinate(5, 25));
        expect(selectionController.anchor, const CellCoordinate(5, 5));
      });

      test('home with no focus does nothing', () {
        selectionController.clear();

        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.home),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, isNull);
      });

      test('end with no focus does nothing', () {
        selectionController.clear();

        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.end),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, isNull);
      });
    });

    group('select all', () {
      testWidgets('ctrl+a selects all cells', (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);

        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.keyA),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

        expect(handled, isTrue);
        expect(selectionController.mode, SelectionMode.range);
        expect(selectionController.selectedRange?.startRow, 0);
        expect(selectionController.selectedRange?.startColumn, 0);
        expect(selectionController.selectedRange?.endRow, 99);
        expect(selectionController.selectedRange?.endColumn, 25);
      });
    });

    group('key repeat events', () {
      test('handles key repeat events', () {
        final handled = keyboardHandler.handleKeyEvent(
          KeyRepeatEvent(
            physicalKey: PhysicalKeyboardKey.arrowDown,
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        );

        expect(handled, isTrue);
        expect(selectionController.focus, const CellCoordinate(6, 5));
      });
    });

    group('escape key', () {
      test('escape clears selection extension', () {
        // Extend selection (focus moves to the extended point)
        selectionController.extendSelection(const CellCoordinate(8, 8));
        expect(selectionController.mode, SelectionMode.range);
        final focusBeforeEscape = selectionController.focus;

        keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.escape),
        );

        // Should revert to single cell at the focus (which was the extended point)
        expect(selectionController.mode, SelectionMode.single);
        expect(selectionController.focus, focusBeforeEscape);
      });
    });

    group('callbacks', () {
      test('calls onStartEdit for F2', () {
        var editStarted = false;
        final handler = KeyboardHandler(
          selectionController: selectionController,
          maxRow: 100,
          maxColumn: 26,
          onStartEdit: () => editStarted = true,
        );

        handler.handleKeyEvent(createKeyEvent(LogicalKeyboardKey.f2));

        expect(editStarted, isTrue);
      });

      test('calls onEnsureVisible after navigation', () {
        var ensureVisibleCalled = false;
        final handler = KeyboardHandler(
          selectionController: selectionController,
          maxRow: 100,
          maxColumn: 26,
          onEnsureVisible: () => ensureVisibleCalled = true,
        );

        handler.handleKeyEvent(createKeyEvent(LogicalKeyboardKey.arrowDown));

        expect(ensureVisibleCalled, isTrue);
      });
    });

    group('unhandled keys', () {
      test('returns false for unhandled keys', () {
        final handled = keyboardHandler.handleKeyEvent(
          createKeyEvent(LogicalKeyboardKey.keyZ),
        );

        expect(handled, isFalse);
      });

      test('ignores key up events', () {
        final handled = keyboardHandler.handleKeyEvent(
          KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.arrowDown,
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        );

        expect(handled, isFalse);
      });
    });
  });
}
