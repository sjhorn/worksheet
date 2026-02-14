import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MobileExampleApp());

class MobileExampleApp extends StatelessWidget {
  const MobileExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Worksheet',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const MobileExample(),
    );
  }
}

class MobileExample extends StatefulWidget {
  const MobileExample({super.key});

  @override
  State<MobileExample> createState() => _MobileExampleState();
}

class _MobileExampleState extends State<MobileExample> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;

  /// Toggle to force mobile mode on desktop for testing.
  bool _forceMobile = true;

  @override
  void initState() {
    super.initState();
    _controller = WorksheetController();
    _editController = EditController();
    _data = _buildSampleData();
  }

  SparseWorksheetData _buildSampleData() {
    final data = SparseWorksheetData(rowCount: 500, columnCount: 12);
    final rng = math.Random(42);

    // Header row
    const headers = [
      'ID',
      'Product',
      'Category',
      'Qty',
      'Price',
      'Total',
      'Status',
      'Region',
      'Date',
      'Rep',
      'Discount',
      'Net',
    ];
    const headerStyle = CellStyle(
      backgroundColor: Color(0xFF4472C4),
    );
    const headerTextStyle = TextStyle(
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.bold,
    );
    for (var c = 0; c < headers.length; c++) {
      data.setCell(CellCoordinate(0, c), CellValue.text(headers[c]));
      data.setStyle(CellCoordinate(0, c), headerStyle);
      data.setRichText(CellCoordinate(0, c), [
        TextSpan(text: headers[c], style: headerTextStyle),
      ]);
    }

    // Sample data
    const products = [
      'Widget A',
      'Gadget B',
      'Gizmo C',
      'Doohickey D',
      'Thingamajig E',
    ];
    const categories = ['Electronics', 'Tools', 'Parts', 'Accessories'];
    const statuses = ['Shipped', 'Pending', 'Delivered', 'Cancelled'];
    const regions = ['North', 'South', 'East', 'West'];
    const reps = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'];

    for (var row = 1; row <= 200; row++) {
      final qty = rng.nextInt(100) + 1;
      final price = (rng.nextDouble() * 200).roundToDouble();
      final total = qty * price;
      final discount = rng.nextDouble() * 0.2;
      final net = total * (1 - discount);
      final status = statuses[rng.nextInt(statuses.length)];
      final date = DateTime(2025, rng.nextInt(12) + 1, rng.nextInt(28) + 1);

      data.setCell(CellCoordinate(row, 0), CellValue.number(row.toDouble()));
      data.setCell(
        CellCoordinate(row, 1),
        CellValue.text(products[rng.nextInt(products.length)]),
      );
      data.setCell(
        CellCoordinate(row, 2),
        CellValue.text(categories[rng.nextInt(categories.length)]),
      );
      data.setCell(CellCoordinate(row, 3), CellValue.number(qty.toDouble()));
      data.setCell(CellCoordinate(row, 4), CellValue.number(price));
      data.setCell(CellCoordinate(row, 5), CellValue.number(total));
      data.setCell(CellCoordinate(row, 6), CellValue.text(status));
      data.setCell(
        CellCoordinate(row, 7),
        CellValue.text(regions[rng.nextInt(regions.length)]),
      );
      data.setCell(CellCoordinate(row, 8), CellValue.date(date));
      data.setCell(
        CellCoordinate(row, 9),
        CellValue.text(reps[rng.nextInt(reps.length)]),
      );
      data.setCell(CellCoordinate(row, 10), CellValue.number(discount));
      data.setCell(CellCoordinate(row, 11), CellValue.number(net));

      // Highlight cancelled rows
      if (status == 'Cancelled') {
        for (var c = 0; c < headers.length; c++) {
          data.setStyle(
            CellCoordinate(row, c),
            const CellStyle(backgroundColor: Color(0xFFFFE0E0)),
          );
        }
      }

      // Alternating row background
      if (status != 'Cancelled' && row.isEven) {
        for (var c = 0; c < headers.length; c++) {
          data.setStyle(
            CellCoordinate(row, c),
            const CellStyle(backgroundColor: Color(0xFFF5F5F5)),
          );
        }
      }
    }

    // Formats
    for (var row = 1; row <= 200; row++) {
      data.setFormat(CellCoordinate(row, 4), CellFormat.currency);
      data.setFormat(CellCoordinate(row, 5), CellFormat.currency);
      data.setFormat(CellCoordinate(row, 8), CellFormat.dateIso);
      data.setFormat(CellCoordinate(row, 10), CellFormat.percentage);
      data.setFormat(CellCoordinate(row, 11), CellFormat.currency);
    }

    return data;
  }

  @override
  void dispose() {
    _editController.dispose();
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Worksheet'),
        actions: [
          // Toggle mobile mode
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mobile', style: TextStyle(fontSize: 14)),
              Switch(
                value: _forceMobile,
                onChanged: (v) => setState(() => _forceMobile = v),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Zoom display
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final pct = (_controller.zoom * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text('$pct%', style: const TextStyle(fontSize: 14)),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selection info bar
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final range = _controller.selectedRange;
              final focus = _controller.focusCell;
              final String info;
              if (focus != null) {
                final val = _data.getCell(focus);
                final notation = focus.toNotation();
                info = '$notation: ${val?.displayValue ?? ''}';
              } else if (range != null) {
                info =
                    '${range.topLeft.toNotation()}'
                    ':${range.bottomRight.toNotation()}';
              } else {
                info = 'Tap a cell to select';
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(info, style: const TextStyle(fontSize: 13)),
              );
            },
          ),
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Text(
              _forceMobile
                  ? 'Swipe to scroll  \u2022  Tap to select  \u2022  '
                        'Drag handles to extend  \u2022  '
                        'Long-press to move  \u2022  '
                        'Pinch to zoom  \u2022  Double-tap to edit'
                  : 'Click-drag to select  \u2022  '
                        'Drag fill handle  \u2022  '
                        'Drag border to move  \u2022  '
                        'Double-click to edit',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Worksheet
          Expanded(
            child: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: _data,
                controller: _controller,
                editController: _editController,
                rowCount: _data.rowCount,
                columnCount: _data.columnCount,
                mobileMode: _forceMobile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
