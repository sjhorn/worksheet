import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: RichTextDemo()));

class RichTextDemo extends StatefulWidget {
  const RichTextDemo({super.key});

  @override
  State<RichTextDemo> createState() => _RichTextDemoState();
}

class _RichTextDemoState extends State<RichTextDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _editController = EditController();

    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        // Header row with bold style
        (0, 0): Cell.text('Rich Text Demo',
            style: const CellStyle(fontWeight: FontWeight.bold)),
        // Plain text
        (2, 0): Cell.text('Plain text'),
        // Rich text: bold + normal
        (3, 0): Cell.text('Bold and normal', richText: const [
          TextSpan(
              text: 'Bold',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' and normal'),
        ]),
        // Rich text: italic + colored
        (4, 0): Cell.text('Italic and colored', richText: const [
          TextSpan(
              text: 'Italic',
              style: TextStyle(fontStyle: FontStyle.italic)),
          TextSpan(text: ' and '),
          TextSpan(
              text: 'colored',
              style: TextStyle(color: Color(0xFF2196F3))),
        ]),
        // Rich text: underline + strikethrough
        (5, 0): Cell.text('Underline and strike', richText: const [
          TextSpan(
              text: 'Underline',
              style: TextStyle(decoration: TextDecoration.underline)),
          TextSpan(text: ' and '),
          TextSpan(
              text: 'strike',
              style: TextStyle(decoration: TextDecoration.lineThrough)),
        ]),
        // Rich text: mixed styles
        (6, 0): Cell.text('Mixed formatting', richText: const [
          TextSpan(
            text: 'Mixed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE91E63),
            ),
          ),
          TextSpan(text: ' '),
          TextSpan(
            text: 'formatting',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
            ),
          ),
        ]),
        // Cell-level underline via CellStyle
        (8, 0): Cell.text('Cell underline',
            style: const CellStyle(underline: true)),
        // Cell-level strikethrough via CellStyle
        (9, 0): Cell.text('Cell strikethrough',
            style: const CellStyle(strikethrough: true)),
        // Instructions
        (11, 0): Cell.text('Double-tap to edit. Use Ctrl+B/I/U to format.'),
      },
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rich Text Spans')),
      body: WorksheetTheme(
        data: WorksheetThemeData(
          showHeaders: true,
          defaultColumnWidth: 200,
        ),
        child: Worksheet(
          data: _data,
          rowCount: 100,
          columnCount: 10,
          editController: _editController,
        ),
      ),
    );
  }
}
