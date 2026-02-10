import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: WrapTextDemo()));

class WrapTextDemo extends StatefulWidget {
  const WrapTextDemo({super.key});

  @override
  State<WrapTextDemo> createState() => _WrapTextDemoState();
}

class _WrapTextDemoState extends State<WrapTextDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  static const _wrapStyle = CellStyle(wrapText: true);
  static const _headerStyle = CellStyle(
    fontWeight: FontWeight.bold,
    backgroundColor: Color(0xFF4472C4),
    textColor: Color(0xFFFFFFFF),
    textAlignment: CellTextAlignment.center,
  );

  @override
  void initState() {
    super.initState();
    _editController = EditController();

    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        // Header
        (0, 0): Cell.text('Feature', style: _headerStyle),
        (0, 1): Cell.text('Description', style: _headerStyle),
        (0, 2): Cell.text('Alignment', style: _headerStyle),

        // Explicit newlines with wrapText
        (1, 0): Cell.text('Newlines'),
        (1, 1): Cell.text(
          'Line 1\nLine 2\nLine 3',
          style: _wrapStyle,
        ),

        // Long text that wraps at cell width
        (2, 0): Cell.text('Auto wrap'),
        (2, 1): Cell.text(
          'This is a longer paragraph that will wrap automatically '
          'within the cell bounds when wrapText is enabled.',
          style: _wrapStyle,
        ),

        // Vertical alignment: top
        (3, 0): Cell.text('Top'),
        (3, 1): Cell.text(
          'Top-aligned\nwrapped text',
          style: const CellStyle(
            wrapText: true,
            verticalAlignment: CellVerticalAlignment.top,
          ),
        ),
        (3, 2): Cell.text('verticalAlignment: top'),

        // Vertical alignment: middle (default)
        (4, 0): Cell.text('Middle'),
        (4, 1): Cell.text(
          'Middle-aligned\nwrapped text',
          style: const CellStyle(
            wrapText: true,
            verticalAlignment: CellVerticalAlignment.middle,
          ),
        ),
        (4, 2): Cell.text('verticalAlignment: middle'),

        // Vertical alignment: bottom
        (5, 0): Cell.text('Bottom'),
        (5, 1): Cell.text(
          'Bottom-aligned\nwrapped text',
          style: const CellStyle(
            wrapText: true,
            verticalAlignment: CellVerticalAlignment.bottom,
          ),
        ),
        (5, 2): Cell.text('verticalAlignment: bottom'),

        // No wrap (single line, truncated)
        (6, 0): Cell.text('No wrap'),
        (6, 1): Cell.text(
          'This text does not wrap and will be truncated with an ellipsis when it overflows the cell width.',
        ),

        // Instructions
        (8, 0): Cell.text('Try editing',
            style: const CellStyle(fontWeight: FontWeight.bold)),
        (8, 1): Cell.text(
          'Double-tap a wrapped cell, then press Alt+Enter to insert a newline.',
          style: _wrapStyle,
        ),
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
      appBar: AppBar(title: const Text('Wrap Text & Vertical Alignment')),
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
          customRowHeights: {0: 28, 1: 60, 2: 72, 3: 60, 4: 60, 5: 60, 8: 48},
        ),
      ),
    );
  }
}
