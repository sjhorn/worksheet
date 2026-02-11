import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/interaction/controllers/rich_text_editing_controller.dart';

void main() {
  group('RichTextEditingController', () {
    late RichTextEditingController controller;

    setUp(() {
      controller = RichTextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('initFromSpans', () {
      test('initializes text from spans', () {
        controller.initFromSpans([
          const TextSpan(text: 'Hello'),
          const TextSpan(text: ' World'),
        ]);

        expect(controller.text, 'Hello World');
      });

      test('initializes per-character styles from spans', () {
        const boldStyle = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'Hi', style: boldStyle),
          const TextSpan(text: '!'),
        ]);

        expect(controller.text, 'Hi!');
        expect(controller.charStyles[0], boldStyle);
        expect(controller.charStyles[1], boldStyle);
        expect(controller.charStyles[2], isNull);
      });

      test('handles empty spans list', () {
        controller.initFromSpans([]);
        expect(controller.text, '');
        expect(controller.charStyles, isEmpty);
      });

      test('handles spans with null text', () {
        controller.initFromSpans([
          const TextSpan(text: null),
          const TextSpan(text: 'hi'),
        ]);
        expect(controller.text, 'hi');
        expect(controller.charStyles.length, 2);
      });
    });

    group('toSpans', () {
      test('returns empty list for empty text', () {
        expect(controller.toSpans(), isEmpty);
      });

      test('groups consecutive same-style characters', () {
        const boldStyle = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'AB', style: boldStyle),
          const TextSpan(text: 'CD'),
        ]);

        final spans = controller.toSpans();
        expect(spans.length, 2);
        expect(spans[0].text, 'AB');
        expect(spans[0].style, boldStyle);
        expect(spans[1].text, 'CD');
        expect(spans[1].style, isNull);
      });

      test('roundtrip: initFromSpans then toSpans preserves structure', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        const italic = TextStyle(fontStyle: FontStyle.italic);
        final original = [
          const TextSpan(text: 'He', style: bold),
          const TextSpan(text: 'll', style: italic),
          const TextSpan(text: 'o'),
        ];

        controller.initFromSpans(original);
        final result = controller.toSpans();

        expect(result.length, 3);
        expect(result[0].text, 'He');
        expect(result[0].style, bold);
        expect(result[1].text, 'll');
        expect(result[1].style, italic);
        expect(result[2].text, 'o');
        expect(result[2].style, isNull);
      });

      test('single-style text produces single span', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'Hello', style: bold),
        ]);

        final spans = controller.toSpans();
        expect(spans.length, 1);
        expect(spans[0].text, 'Hello');
        expect(spans[0].style, bold);
      });
    });

    group('hasRichStyles', () {
      test('returns false for plain text', () {
        controller.text = 'Hello';
        expect(controller.hasRichStyles, isFalse);
      });

      test('returns true when spans have styles', () {
        controller.initFromSpans([
          const TextSpan(
              text: 'Hi', style: TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '!'),
        ]);
        expect(controller.hasRichStyles, isTrue);
      });
    });

    group('toggleBold', () {
      test('applies bold to selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 2);

        controller.toggleBold();

        final spans = controller.toSpans();
        expect(spans.length, 2);
        expect(spans[0].style?.fontWeight, FontWeight.bold);
        expect(spans[0].text, 'He');
        expect(spans[1].text, 'llo');
      });

      test('removes bold when all selected chars are bold', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'Hello', style: bold),
        ]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleBold();

        final spans = controller.toSpans();
        expect(spans.length, 1);
        expect(spans[0].style?.fontWeight, FontWeight.normal);
      });

      test('sets pending style on collapsed selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection = const TextSelection.collapsed(offset: 2);

        controller.toggleBold();
        // Should not modify existing spans
        expect(controller.toSpans().length, 1);
        // Should set pending style with bold
        expect(controller.pendingStyle?.fontWeight, FontWeight.bold);
      });
    });

    group('toggleItalic', () {
      test('applies italic to selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 1, extentOffset: 4);

        controller.toggleItalic();

        final spans = controller.toSpans();
        expect(spans.length, 3);
        expect(spans[1].style?.fontStyle, FontStyle.italic);
        expect(spans[1].text, 'ell');
      });
    });

    group('toggleUnderline', () {
      test('applies underline to selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleUnderline();

        final spans = controller.toSpans();
        expect(spans[0].style?.decoration, TextDecoration.underline);
      });

      test('removes underline when all selected are underlined', () {
        controller.initFromSpans([
          const TextSpan(
            text: 'Hello',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleUnderline();

        final spans = controller.toSpans();
        expect(spans[0].style?.decoration, TextDecoration.none);
      });
    });

    group('toggleStrikethrough', () {
      test('applies strikethrough to selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleStrikethrough();

        final spans = controller.toSpans();
        expect(spans[0].style?.decoration, TextDecoration.lineThrough);
      });
    });

    group('setColor', () {
      test('sets color on selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 3);

        controller.setColor(const Color(0xFFFF0000));

        final spans = controller.toSpans();
        expect(spans[0].style?.color, const Color(0xFFFF0000));
        expect(spans[0].text, 'Hel');
      });
    });

    group('setFontSize', () {
      test('sets font size on selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.setFontSize(24.0);

        final spans = controller.toSpans();
        expect(spans[0].style?.fontSize, 24.0);
      });
    });

    group('setFontFamily', () {
      test('sets font family on selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.setFontFamily('Courier');

        final spans = controller.toSpans();
        expect(spans[0].style?.fontFamily, 'Courier');
      });
    });

    group('text editing (insert/delete)', () {
      test('inserting text adjusts char styles', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'AB', style: bold),
          const TextSpan(text: 'CD'),
        ]);

        // Simulate inserting 'X' at position 2 (between bold A,B and plain C,D)
        controller.value = const TextEditingValue(
          text: 'ABXCD',
          selection: TextSelection.collapsed(offset: 3),
        );

        final spans = controller.toSpans();
        // X should inherit the style of the character before it (bold)
        expect(spans[0].text, 'ABX');
        expect(spans[0].style, bold);
        expect(spans[1].text, 'CD');
      });

      test('deleting text removes corresponding styles', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'AB', style: bold),
          const TextSpan(text: 'CD'),
        ]);

        // Simulate deleting 'B' (position 1)
        controller.value = const TextEditingValue(
          text: 'ACD',
          selection: TextSelection.collapsed(offset: 1),
        );

        final spans = controller.toSpans();
        expect(spans[0].text, 'A');
        expect(spans[0].style, bold);
        expect(spans[1].text, 'CD');
      });

      test('clearing all text results in empty styles', () {
        controller.initFromSpans([
          const TextSpan(text: 'Hello'),
        ]);

        controller.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );

        expect(controller.charStyles, isEmpty);
        expect(controller.toSpans(), isEmpty);
      });

      test('inserting into empty text uses null style', () {
        controller.value = const TextEditingValue(
          text: 'Hi',
          selection: TextSelection.collapsed(offset: 2),
        );

        expect(controller.charStyles.length, 2);
        expect(controller.charStyles[0], isNull);
        expect(controller.charStyles[1], isNull);
      });
    });

    group('buildTextSpan', () {
      testWidgets('builds plain span for text without styles',
          (tester) async {
        controller.text = 'Hello';

        await tester.pumpWidget(Builder(builder: (context) {
          final span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          expect(span.text, 'Hello');
          expect(span.children, isNull);
          return const SizedBox();
        }));
      });

      testWidgets('builds children spans for styled text', (tester) async {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'He', style: bold),
          const TextSpan(text: 'llo'),
        ]);

        await tester.pumpWidget(Builder(builder: (context) {
          final span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          expect(span.children, isNotNull);
          expect(span.children!.length, 2);
          final first = span.children![0] as TextSpan;
          final second = span.children![1] as TextSpan;
          expect(first.text, 'He');
          expect(first.style, bold);
          expect(second.text, 'llo');
          return const SizedBox();
        }));
      });

      testWidgets('builds plain span for empty text', (tester) async {
        await tester.pumpWidget(Builder(builder: (context) {
          final span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          expect(span.text, '');
          return const SizedBox();
        }));
      });
    });

    group('pending style (collapsed selection)', () {
      test('toggleBold sets pending style with bold', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection = const TextSelection.collapsed(offset: 3);

        controller.toggleBold();

        expect(controller.pendingStyle, isNotNull);
        expect(controller.pendingStyle!.fontWeight, FontWeight.bold);
      });

      test('toggling bold twice clears bold from pending', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection = const TextSelection.collapsed(offset: 3);

        controller.toggleBold();
        controller.toggleBold();

        expect(controller.pendingStyle?.fontWeight, FontWeight.normal);
      });

      test('typing after toggleBold gives character bold style', () {
        controller.initFromSpans([const TextSpan(text: 'AB')]);
        controller.selection = const TextSelection.collapsed(offset: 2);

        controller.toggleBold();
        expect(controller.pendingStyle, isNotNull);

        // Simulate typing 'C' at position 2
        controller.value = const TextEditingValue(
          text: 'ABC',
          selection: TextSelection.collapsed(offset: 3),
        );

        // Pending style should be consumed
        expect(controller.pendingStyle, isNull);
        // The inserted character should be bold
        expect(controller.charStyles[2]?.fontWeight, FontWeight.bold);
        // Original chars should remain unstyled
        expect(controller.charStyles[0], isNull);
        expect(controller.charStyles[1], isNull);
      });

      test('toggling bold at bold position removes bold from pending', () {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        controller.initFromSpans([
          const TextSpan(text: 'Hello', style: bold),
        ]);
        controller.selection = const TextSelection.collapsed(offset: 3);

        controller.toggleBold();

        // Cursor is after a bold char — toggling should remove bold
        expect(controller.pendingStyle?.fontWeight, FontWeight.normal);
      });

      test('multiple pending toggles combine into bold+italic', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection = const TextSelection.collapsed(offset: 2);

        controller.toggleBold();
        controller.toggleItalic();

        expect(controller.pendingStyle?.fontWeight, FontWeight.bold);
        expect(controller.pendingStyle?.fontStyle, FontStyle.italic);
      });

      test('clearPendingStyle removes pending', () {
        controller.initFromSpans([const TextSpan(text: 'Hi')]);
        controller.selection = const TextSelection.collapsed(offset: 1);

        controller.toggleBold();
        expect(controller.pendingStyle, isNotNull);

        controller.clearPendingStyle();
        expect(controller.pendingStyle, isNull);
      });
    });

    group('combined formatting', () {
      test('bold + italic on same selection', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleBold();
        controller.toggleItalic();

        final spans = controller.toSpans();
        expect(spans.length, 1);
        expect(spans[0].style?.fontWeight, FontWeight.bold);
        expect(spans[0].style?.fontStyle, FontStyle.italic);
      });

      test('underline + strikethrough', () {
        controller.initFromSpans([const TextSpan(text: 'Hello')]);
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleUnderline();
        controller.toggleStrikethrough();

        final spans = controller.toSpans();
        expect(spans[0].style?.decoration?.contains(TextDecoration.underline),
            isTrue);
        expect(
            spans[0]
                .style
                ?.decoration
                ?.contains(TextDecoration.lineThrough),
            isTrue);
      });
    });
  });
}
