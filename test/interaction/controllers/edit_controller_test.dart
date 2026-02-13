import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/rich_text_editing_controller.dart';

void main() {
  group('EditCommitResult', () {
    test('stores cell, value, and deltas', () {
      const result = EditCommitResult(
        cell: CellCoordinate(3, 5),
        value: CellValue.text('Hello'),
        rowDelta: 1,
        columnDelta: 0,
      );

      expect(result.cell, const CellCoordinate(3, 5));
      expect(result.value, const CellValue.text('Hello'));
      expect(result.rowDelta, 1);
      expect(result.columnDelta, 0);
    });

    test('defaults to zero deltas', () {
      const result = EditCommitResult(
        cell: CellCoordinate(0, 0),
        value: null,
      );

      expect(result.rowDelta, 0);
      expect(result.columnDelta, 0);
    });

    test('supports null value', () {
      const result = EditCommitResult(
        cell: CellCoordinate(1, 1),
        value: null,
        rowDelta: -1,
        columnDelta: 0,
      );

      expect(result.value, isNull);
    });
  });

  late EditController controller;

  setUp(() {
    controller = EditController();
  });

  group('EditController', () {
    test('starts in idle state', () {
      expect(controller.state, EditState.idle);
      expect(controller.isEditing, isFalse);
      expect(controller.editingCell, isNull);
    });

    group('startEdit', () {
      test('transitions to editing state', () {
        final result = controller.startEdit(
          cell: const CellCoordinate(5, 3),
          currentValue: const CellValue.text('Hello'),
        );

        expect(result, isTrue);
        expect(controller.state, EditState.editing);
        expect(controller.isEditing, isTrue);
        expect(controller.editingCell, const CellCoordinate(5, 3));
        expect(controller.originalValue, const CellValue.text('Hello'));
        expect(controller.currentText, 'Hello');
      });

      test('starts with empty text for null value', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: null,
        );

        expect(controller.currentText, '');
      });

      test('uses initial text when provided', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Old'),
          initialText: 'New',
        );

        expect(controller.currentText, 'New');
      });

      test('sets trigger', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          trigger: EditTrigger.doubleTap,
        );

        expect(controller.trigger, EditTrigger.doubleTap);
      });

      test('returns false if already editing', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        final result = controller.startEdit(cell: const CellCoordinate(1, 1));

        expect(result, isFalse);
        // Still editing original cell
        expect(controller.editingCell, const CellCoordinate(0, 0));
      });

      test('notifies listeners', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.startEdit(cell: const CellCoordinate(0, 0));

        expect(notifyCount, 1);
      });
    });

    group('updateText', () {
      test('updates current text while editing', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        controller.updateText('New text');

        expect(controller.currentText, 'New text');
      });

      test('does nothing if not editing', () {
        controller.updateText('Text');

        expect(controller.currentText, '');
      });

      test('notifies listeners', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.updateText('Updated');

        expect(notifyCount, 1);
      });
    });

    group('commitEdit', () {
      test('commits text value', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('Hello World');

        CellCoordinate? committedCell;
        CellValue? committedValue;

        final result = controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            committedCell = cell;
            committedValue = value;
          },
        );

        expect(committedCell, const CellCoordinate(0, 0));
        expect(committedValue, const CellValue.text('Hello World'));
        expect(result, const CellValue.text('Hello World'));
      });

      test('commits number value', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('42');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue?.type, CellValueType.number);
        expect(committedValue?.rawValue, 42.0);
      });

      test('commits decimal number', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('3.14159');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue?.type, CellValueType.number);
        expect(committedValue?.rawValue, 3.14159);
      });

      test('commits boolean TRUE', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('TRUE');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue, const CellValue.boolean(true));
      });

      test('commits boolean FALSE (case insensitive)', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('false');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue, const CellValue.boolean(false));
      });

      test('commits formula', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('=A1+B1');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue, const CellValue.formula('=A1+B1'));
      });

      test('commits null for empty text', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('  ');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) => committedValue = value,
        );

        expect(committedValue, isNull);
      });

      test('returns to idle state', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        controller.commitEdit(onCommit: (_, _, {CellFormat? detectedFormat}) {});

        expect(controller.state, EditState.idle);
        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);
        expect(controller.originalValue, isNull);
        expect(controller.currentText, '');
      });

      test('returns null if not editing', () {
        final result = controller.commitEdit(onCommit: (_, _, {CellFormat? detectedFormat}) {});

        expect(result, isNull);
      });
    });

    group('cancelEdit', () {
      test('returns to idle state', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Original'),
        );
        controller.updateText('Changed');

        controller.cancelEdit();

        expect(controller.state, EditState.idle);
        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);
      });

      test('does nothing if not editing', () {
        controller.cancelEdit();

        expect(controller.state, EditState.idle);
      });

      test('notifies listeners', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.cancelEdit();

        expect(notifyCount, 1);
      });
    });

    group('date format detection', () {
      test('detects US date format on commit', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('1/15/2024');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateUs);
      });

      test('detects ISO date format on commit', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('2024-01-15');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateIso);
      });

      test('detects named month format on commit', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('15-Jan-24');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateShort);
      });

      test('no format detected for non-date input', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('Hello World');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, isNull);
      });

      test('no format detected for number input', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('42.5');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, isNull);
      });

      test('uses locale dayFirst for format detection', () {
        controller.locale = FormatLocale.enGb;
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('15/1/2024');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateEu);
      });

      test('no format detected for empty input', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, isNull);
      });

      test('detects format for full month name date', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('15 January 2024');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateLong);
      });

      test('detects zero-padded US date format on commit', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('12/01/1977');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateUsPadded);
      });

      test('detects yyyy-mmm-dd format on commit', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('2026-Jan-01');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, CellFormat.dateYearMonthDay);
      });

      test('null detected for unrecognized date format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        // AnyDate may or may not parse "Jan 15, 2024" — if it does,
        // the round-trip won't match any candidate format
        controller.updateText('January 15th, 2024');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        // Either null (not parsed as date) or null (no format match)
        expect(detected, isNull);
      });
    });

    group('number format detection', () {
      test(r'$1,234.56 → currency format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText(r'$1,234.56');

        CellFormat? detected;
        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
            committedValue = value;
          },
        );

        expect(detected, CellFormat.currency);
        expect(committedValue?.isNumber, isTrue);
        expect(committedValue?.asDouble, 1234.56);
      });

      test('42% → percentage format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('42%');

        CellFormat? detected;
        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
            committedValue = value;
          },
        );

        expect(detected, CellFormat.percentage);
        expect(committedValue?.isNumber, isTrue);
        expect(committedValue?.asDouble, 0.42);
      });

      test('1,234 → integer format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('1,234');

        CellFormat? detected;
        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
            committedValue = value;
          },
        );

        expect(detected, CellFormat.integer);
        expect(committedValue?.isNumber, isTrue);
        expect(committedValue?.asDouble, 1234);
      });

      test('plain 42 → no format detected', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('42');

        CellFormat? detected;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
          },
        );

        expect(detected, isNull);
      });
    });

    group('duration format detection', () {
      test('1:30:05 → duration format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('1:30:05');

        CellFormat? detected;
        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
            committedValue = value;
          },
        );

        expect(detected, CellFormat.duration);
        expect(committedValue?.isDuration, isTrue);
        expect(committedValue?.asDuration,
            const Duration(hours: 1, minutes: 30, seconds: 5));
      });

      test('1:30 → durationShort format', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('1:30');

        CellFormat? detected;
        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {
            detected = detectedFormat;
            committedValue = value;
          },
        );

        expect(detected, CellFormat.durationShort);
        expect(committedValue?.isDuration, isTrue);
        expect(committedValue?.asDuration,
            const Duration(hours: 1, minutes: 30));
      });
    });

    group('hasChanges', () {
      test('returns false when not editing', () {
        expect(controller.hasChanges, isFalse);
      });

      test('returns false when text unchanged', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );

        expect(controller.hasChanges, isFalse);
      });

      test('returns true when text changed', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );
        controller.updateText('World');

        expect(controller.hasChanges, isTrue);
      });

      test('returns true when null changed to value', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('Value');

        expect(controller.hasChanges, isTrue);
      });

      test('returns true when value changed to null', () {
        controller.startEdit(
          cell: const CellCoordinate(0, 0),
          currentValue: const CellValue.text('Hello'),
        );
        controller.updateText('');

        expect(controller.hasChanges, isTrue);
      });
    });

    group('richTextController', () {
      test('is null by default', () {
        expect(controller.richTextController, isNull);
      });

      test('can be set and read', () {
        final rtc = RichTextEditingController();
        addTearDown(rtc.dispose);

        controller.richTextController = rtc;
        expect(controller.richTextController, same(rtc));
      });

      test('can be cleared', () {
        final rtc = RichTextEditingController();
        addTearDown(rtc.dispose);

        controller.richTextController = rtc;
        controller.richTextController = null;
        expect(controller.richTextController, isNull);
      });
    });

    group('rich text convenience methods', () {
      late RichTextEditingController rtc;

      setUp(() {
        rtc = RichTextEditingController();
        rtc.initFromSpans([const TextSpan(text: 'Hello')]);
        rtc.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);
        controller.richTextController = rtc;
      });

      tearDown(() {
        rtc.dispose();
      });

      test('toggleBold delegates to richTextController', () {
        controller.toggleBold();
        expect(rtc.isSelectionBold, isTrue);
      });

      test('toggleItalic delegates to richTextController', () {
        controller.toggleItalic();
        expect(rtc.isSelectionItalic, isTrue);
      });

      test('toggleUnderline delegates to richTextController', () {
        controller.toggleUnderline();
        expect(rtc.isSelectionUnderline, isTrue);
      });

      test('toggleStrikethrough delegates to richTextController', () {
        controller.toggleStrikethrough();
        expect(rtc.isSelectionStrikethrough, isTrue);
      });

      test('toggleBold is no-op when richTextController is null', () {
        controller.richTextController = null;
        controller.toggleBold(); // should not throw
      });

      test('isSelectionBold delegates to richTextController', () {
        expect(controller.isSelectionBold, isFalse);
        controller.toggleBold();
        expect(controller.isSelectionBold, isTrue);
      });

      test('isSelectionItalic returns false when no controller', () {
        controller.richTextController = null;
        expect(controller.isSelectionItalic, isFalse);
      });

      test('isSelectionUnderline delegates to richTextController', () {
        controller.toggleUnderline();
        expect(controller.isSelectionUnderline, isTrue);
      });

      test('isSelectionStrikethrough delegates to richTextController', () {
        controller.toggleStrikethrough();
        expect(controller.isSelectionStrikethrough, isTrue);
      });

      test('getSelectionStyle returns null when no controller', () {
        controller.richTextController = null;
        expect(controller.getSelectionStyle(), isNull);
      });

      test('getSelectionStyle delegates to richTextController', () {
        controller.toggleBold();
        final style = controller.getSelectionStyle();
        expect(style?.fontWeight, FontWeight.bold);
      });
    });
  });
}
