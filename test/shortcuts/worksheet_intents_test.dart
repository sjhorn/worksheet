import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/shortcuts/worksheet_intents.dart';

void main() {
  group('MoveSelectionIntent', () {
    test('default values', () {
      const intent = MoveSelectionIntent();
      expect(intent.rowDelta, 0);
      expect(intent.columnDelta, 0);
      expect(intent.extend, false);
    });

    test('custom values', () {
      const intent = MoveSelectionIntent(
        rowDelta: -10,
        columnDelta: 1,
        extend: true,
      );
      expect(intent.rowDelta, -10);
      expect(intent.columnDelta, 1);
      expect(intent.extend, true);
    });
  });

  group('GoToCellIntent', () {
    test('stores coordinate', () {
      const intent = GoToCellIntent(CellCoordinate(5, 10));
      expect(intent.coordinate, const CellCoordinate(5, 10));
    });
  });

  group('GoToLastCellIntent', () {
    test('can be constructed', () {
      const intent = GoToLastCellIntent();
      expect(intent, isA<GoToLastCellIntent>());
    });
  });

  group('GoToRowBoundaryIntent', () {
    test('go to start of row', () {
      const intent = GoToRowBoundaryIntent(end: false);
      expect(intent.end, false);
      expect(intent.extend, false);
    });

    test('go to end of row with extend', () {
      const intent = GoToRowBoundaryIntent(end: true, extend: true);
      expect(intent.end, true);
      expect(intent.extend, true);
    });
  });

  group('SelectAllCellsIntent', () {
    test('can be constructed', () {
      const intent = SelectAllCellsIntent();
      expect(intent, isA<SelectAllCellsIntent>());
    });
  });

  group('CancelSelectionIntent', () {
    test('can be constructed', () {
      const intent = CancelSelectionIntent();
      expect(intent, isA<CancelSelectionIntent>());
    });
  });

  group('EditCellIntent', () {
    test('can be constructed', () {
      const intent = EditCellIntent();
      expect(intent, isA<EditCellIntent>());
    });
  });

  group('CopyCellsIntent', () {
    test('can be constructed', () {
      const intent = CopyCellsIntent();
      expect(intent, isA<CopyCellsIntent>());
    });
  });

  group('CutCellsIntent', () {
    test('can be constructed', () {
      const intent = CutCellsIntent();
      expect(intent, isA<CutCellsIntent>());
    });
  });

  group('PasteCellsIntent', () {
    test('can be constructed', () {
      const intent = PasteCellsIntent();
      expect(intent, isA<PasteCellsIntent>());
    });
  });

  group('ClearCellsIntent', () {
    test('can be constructed', () {
      const intent = ClearCellsIntent();
      expect(intent, isA<ClearCellsIntent>());
    });
  });

  group('FillDownIntent', () {
    test('can be constructed', () {
      const intent = FillDownIntent();
      expect(intent, isA<FillDownIntent>());
    });
  });

  group('FillRightIntent', () {
    test('can be constructed', () {
      const intent = FillRightIntent();
      expect(intent, isA<FillRightIntent>());
    });
  });
}
