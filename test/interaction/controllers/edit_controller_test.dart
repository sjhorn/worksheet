import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';

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
          onCommit: (cell, value) {
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
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue?.type, CellValueType.number);
        expect(committedValue?.rawValue, 42.0);
      });

      test('commits decimal number', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('3.14159');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue?.type, CellValueType.number);
        expect(committedValue?.rawValue, 3.14159);
      });

      test('commits boolean TRUE', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('TRUE');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue, const CellValue.boolean(true));
      });

      test('commits boolean FALSE (case insensitive)', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('false');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue, const CellValue.boolean(false));
      });

      test('commits formula', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('=A1+B1');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue, const CellValue.formula('=A1+B1'));
      });

      test('commits null for empty text', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));
        controller.updateText('  ');

        CellValue? committedValue;
        controller.commitEdit(
          onCommit: (cell, value) => committedValue = value,
        );

        expect(committedValue, isNull);
      });

      test('returns to idle state', () {
        controller.startEdit(cell: const CellCoordinate(0, 0));

        controller.commitEdit(onCommit: (_, _) {});

        expect(controller.state, EditState.idle);
        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);
        expect(controller.originalValue, isNull);
        expect(controller.currentText, '');
      });

      test('returns null if not editing', () {
        final result = controller.commitEdit(onCommit: (_, _) {});

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
  });
}
