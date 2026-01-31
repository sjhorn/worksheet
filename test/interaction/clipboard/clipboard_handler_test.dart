import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_serializer.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SparseWorksheetData data;
  late SelectionController selectionController;
  late ClipboardHandler handler;
  String? mockClipboardText;

  void installMockClipboard() {
    mockClipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<dynamic, dynamic>;
        mockClipboardText = args['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        if (mockClipboardText == null) return null;
        return <String, dynamic>{'text': mockClipboardText};
      }
      return null;
    });
  }

  setUp(() {
    data = SparseWorksheetData(rowCount: 10, columnCount: 10);
    selectionController = SelectionController();
    handler = ClipboardHandler(
      data: data,
      selectionController: selectionController,
      serializer: const TsvClipboardSerializer(),
    );
    installMockClipboard();
  });

  tearDown(() {
    selectionController.dispose();
    data.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardHandler.copy', () {
    test('writes TSV to clipboard', () async {
      data[(0, 0)] = 'Hello'.cell;
      data[(0, 1)] = 'World'.cell;
      selectionController.selectRange(const CellRange(0, 0, 0, 1));

      await handler.copy();

      expect(mockClipboardText, 'Hello\tWorld');
    });

    test('does nothing with no selection', () async {
      await handler.copy();
      expect(mockClipboardText, isNull);
    });
  });

  group('ClipboardHandler.cut', () {
    test('writes TSV to clipboard and clears source cells', () async {
      data[(0, 0)] = 'A'.cell;
      data[(0, 1)] = 'B'.cell;
      selectionController.selectRange(const CellRange(0, 0, 0, 1));

      await handler.cut();

      expect(mockClipboardText, 'A\tB');

      // Source cells should be cleared
      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
      expect(data.getCell(const CellCoordinate(0, 1)), isNull);
    });

    test('does nothing with no selection', () async {
      await handler.cut();
      expect(mockClipboardText, isNull);
    });
  });

  group('ClipboardHandler.paste', () {
    test('reads clipboard and writes cells at selection', () async {
      mockClipboardText = 'X\tY\nZ\tW';
      selectionController.selectCell(const CellCoordinate(2, 3));

      await handler.paste();

      expect(data.getCell(const CellCoordinate(2, 3)),
          const CellValue.text('X'));
      expect(data.getCell(const CellCoordinate(2, 4)),
          const CellValue.text('Y'));
      expect(data.getCell(const CellCoordinate(3, 3)),
          const CellValue.text('Z'));
      expect(data.getCell(const CellCoordinate(3, 4)),
          const CellValue.text('W'));
    });

    test('clamps to worksheet bounds', () async {
      mockClipboardText = 'A\tB\tC\tD';
      // Paste near the right edge (column 8 of a 10-column sheet)
      selectionController.selectCell(const CellCoordinate(0, 8));

      await handler.paste();

      // Only columns 8 and 9 should be written
      expect(data.getCell(const CellCoordinate(0, 8)),
          const CellValue.text('A'));
      expect(data.getCell(const CellCoordinate(0, 9)),
          const CellValue.text('B'));
    });

    test('does nothing with empty clipboard', () async {
      mockClipboardText = '';
      selectionController.selectCell(const CellCoordinate(0, 0));

      await handler.paste();

      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
    });

    test('does nothing with no selection', () async {
      mockClipboardText = 'Hello';

      await handler.paste();

      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
    });

    test('pastes numeric values with type detection', () async {
      mockClipboardText = '42\t3.14';
      selectionController.selectCell(const CellCoordinate(0, 0));

      await handler.paste();

      expect(data.getCell(const CellCoordinate(0, 0)),
          CellValue.number(42));
      expect(data.getCell(const CellCoordinate(0, 1)),
          CellValue.number(3.14));
    });

    test('selects the pasted area', () async {
      mockClipboardText = 'A\tB\nC\tD\nE\tF';
      selectionController.selectCell(const CellCoordinate(1, 2));

      await handler.paste();

      expect(selectionController.selectedRange, const CellRange(1, 2, 3, 3));
    });

    test('selects pasted area clamped to worksheet bounds', () async {
      mockClipboardText = 'A\tB\tC\tD';
      selectionController.selectCell(const CellCoordinate(0, 8));

      await handler.paste();

      // 4 columns pasted at col 8, but sheet only has 10 cols (0-9)
      expect(selectionController.selectedRange, const CellRange(0, 8, 0, 9));
    });

    test('selects single cell when pasting single value', () async {
      mockClipboardText = 'X';
      selectionController.selectCell(const CellCoordinate(3, 4));

      await handler.paste();

      expect(selectionController.selectedRange, const CellRange(3, 4, 3, 4));
    });
  });
}
