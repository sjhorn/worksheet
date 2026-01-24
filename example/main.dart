import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet2/worksheet.dart';

/// Converts a slider value (0.0 to 1.0) to a zoom level (0.1 to 4.0).
///
/// Uses a non-linear scale where:
/// - 0.0 → 10% zoom (0.1)
/// - 0.5 → 100% zoom (1.0)
/// - 1.0 → 400% zoom (4.0)
double sliderToZoom(double sliderValue) {
  if (sliderValue <= 0.5) {
    // Left half: exponential from 0.1 to 1.0
    // zoom = 0.1 * 10^(sliderValue * 2)
    return 0.1 * math.pow(10, sliderValue * 2);
  } else {
    // Right half: exponential from 1.0 to 4.0
    // zoom = 4^(2 * sliderValue - 1)
    return math.pow(4, 2 * sliderValue - 1).toDouble();
  }
}

/// Converts a zoom level (0.1 to 4.0) to a slider value (0.0 to 1.0).
///
/// Inverse of [sliderToZoom].
double zoomToSlider(double zoom) {
  if (zoom <= 1.0) {
    // Left half: zoom = 0.1 * 10^(slider * 2)
    // slider = log10(zoom / 0.1) / 2 = log10(zoom * 10) / 2
    return (math.log(zoom * 10) / math.ln10) / 2;
  } else {
    // Right half: zoom = 4^(2 * slider - 1)
    // slider = (log4(zoom) + 1) / 2
    return ((math.log(zoom) / math.log(4)) + 1) / 2;
  }
}

void main() {
  runApp(const WorksheetExampleApp());
}

class WorksheetExampleApp extends StatelessWidget {
  const WorksheetExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worksheet Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WorksheetExample(),
    );
  }
}

class WorksheetExample extends StatefulWidget {
  const WorksheetExample({super.key});

  @override
  State<WorksheetExample> createState() => _WorksheetExampleState();
}

class _WorksheetExampleState extends State<WorksheetExample> {
  // Modern Excel dimensions (Excel 2007+)
  static const int _rowCount = 1048576; // 2^20 rows
  static const int _columnCount = 16384; // 2^14 columns (A to XFD)

  // Excel default sizes (approximately)
  static const double _defaultRowHeight = 20.0; // Excel default ~15 points = ~20 pixels
  static const double _defaultColumnWidth = 64.0; // Excel default 8.43 characters ≈ 64 pixels

  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;
  late final LayoutSolver _layoutSolver;

  // For positioning the editor overlay
  Rect? _editingCellBounds;

  @override
  void initState() {
    super.initState();

    _data = SparseWorksheetData(rowCount: _rowCount, columnCount: _columnCount);
    _populateSampleData();

    _controller = WorksheetController();
    _editController = EditController();

    // Layout solver for cell bounds calculation
    _layoutSolver = LayoutSolver(
      rows: SpanList(count: _rowCount, defaultSize: _defaultRowHeight),
      columns: SpanList(count: _columnCount, defaultSize: _defaultColumnWidth),
    );
  }

  void _populateSampleData() {
    final random = math.Random(42); // Fixed seed for reproducibility

    // === Sheet 1: Sales Data (realistic business spreadsheet) ===

    // Header row with formatting
    final headers = [
      'ID',
      'Date',
      'Customer',
      'Region',
      'Product',
      'Category',
      'Quantity',
      'Unit Price',
      'Total',
      'Discount',
      'Net Total',
      'Status',
      'Sales Rep',
      'Notes',
    ];

    // Header style
    const headerStyle = CellStyle(
      backgroundColor: Color(0xFF4472C4),
      textColor: Color(0xFFFFFFFF),
      fontWeight: FontWeight.bold,
      textAlignment: CellTextAlignment.center,
    );

    for (var col = 0; col < headers.length; col++) {
      _data.setCell(CellCoordinate(0, col), CellValue.text(headers[col]));
      _data.setStyle(const CellCoordinate(0, 0).copyWith(column: col), headerStyle);
    }

    // Sample data arrays
    final customers = [
      'Acme Corp', 'TechStart Inc', 'Global Industries', 'Smith & Co',
      'Johnson LLC', 'Pacific Trading', 'Atlantic Imports', 'Central Services',
      'Northern Supplies', 'Southern Distribution', 'Eastern Partners', 'Western Logistics',
      'Metro Solutions', 'Urban Enterprises', 'Rural Products', 'Coastal Goods',
    ];

    final regions = ['North', 'South', 'East', 'West', 'Central'];

    final products = [
      'Widget A', 'Widget B', 'Gadget X', 'Gadget Y', 'Tool Pro',
      'Tool Basic', 'Device Alpha', 'Device Beta', 'Component 1', 'Component 2',
      'Assembly Kit', 'Repair Kit', 'Starter Pack', 'Premium Pack', 'Enterprise Suite',
    ];

    final categories = ['Electronics', 'Hardware', 'Software', 'Services', 'Accessories'];

    final statuses = ['Completed', 'Pending', 'Shipped', 'Processing', 'Cancelled'];

    final salesReps = [
      'Alice Johnson', 'Bob Smith', 'Carol White', 'David Brown',
      'Emma Davis', 'Frank Wilson', 'Grace Lee', 'Henry Taylor',
    ];

    // Number styles
    const currencyStyle = CellStyle(
      textAlignment: CellTextAlignment.right,
    );

    const numberStyle = CellStyle(
      textAlignment: CellTextAlignment.right,
    );

    // Alternating row colors
    const evenRowStyle = CellStyle(
      backgroundColor: Color(0xFFF2F2F2),
    );

    // Generate 50,000 rows of sales data (simulating a large dataset)
    final baseDate = DateTime(2024, 1, 1);

    for (var row = 1; row <= 50000; row++) {
      final date = baseDate.add(Duration(days: random.nextInt(365)));
      final customer = customers[random.nextInt(customers.length)];
      final region = regions[random.nextInt(regions.length)];
      final product = products[random.nextInt(products.length)];
      final category = categories[random.nextInt(categories.length)];
      final quantity = random.nextInt(100) + 1;
      final unitPrice = (random.nextDouble() * 500 + 10).roundToDouble();
      final total = quantity * unitPrice;
      final discountPercent = random.nextInt(20);
      final discount = total * discountPercent / 100;
      final netTotal = total - discount;
      final status = statuses[random.nextInt(statuses.length)];
      final salesRep = salesReps[random.nextInt(salesReps.length)];

      // Set cell values
      _data.setCell(CellCoordinate(row, 0), CellValue.number(row.toDouble()));
      _data.setCell(CellCoordinate(row, 1), CellValue.text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'));
      _data.setCell(CellCoordinate(row, 2), CellValue.text(customer));
      _data.setCell(CellCoordinate(row, 3), CellValue.text(region));
      _data.setCell(CellCoordinate(row, 4), CellValue.text(product));
      _data.setCell(CellCoordinate(row, 5), CellValue.text(category));
      _data.setCell(CellCoordinate(row, 6), CellValue.number(quantity.toDouble()));
      _data.setCell(CellCoordinate(row, 7), CellValue.number(unitPrice));
      _data.setCell(CellCoordinate(row, 8), CellValue.number(total));
      _data.setCell(CellCoordinate(row, 9), CellValue.text('$discountPercent%'));
      _data.setCell(CellCoordinate(row, 10), CellValue.number(netTotal));
      _data.setCell(CellCoordinate(row, 11), CellValue.text(status));
      _data.setCell(CellCoordinate(row, 12), CellValue.text(salesRep));

      // Add occasional notes
      if (random.nextInt(10) == 0) {
        _data.setCell(CellCoordinate(row, 13), CellValue.text('Follow up required'));
      }

      // Apply alternating row style
      if (row.isEven) {
        for (var col = 0; col < headers.length; col++) {
          _data.setStyle(CellCoordinate(row, col), evenRowStyle);
        }
      }

      // Apply number alignment
      _data.setStyle(CellCoordinate(row, 0), numberStyle);
      _data.setStyle(CellCoordinate(row, 6), numberStyle);
      _data.setStyle(CellCoordinate(row, 7), currencyStyle);
      _data.setStyle(CellCoordinate(row, 8), currencyStyle);
      _data.setStyle(CellCoordinate(row, 10), currencyStyle);

      // Highlight cancelled orders in red
      if (status == 'Cancelled') {
        _data.setStyle(CellCoordinate(row, 11), const CellStyle(
          textColor: Color(0xFFCC0000),
          fontWeight: FontWeight.bold,
        ));
      }
    }

    // === Add summary section ===
    const summaryStartRow = 50002;

    _data.setCell(const CellCoordinate(summaryStartRow, 0), CellValue.text('SUMMARY'));
    _data.setStyle(const CellCoordinate(summaryStartRow, 0), const CellStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
    ));

    _data.setCell(const CellCoordinate(summaryStartRow + 1, 0), CellValue.text('Total Records:'));
    _data.setCell(const CellCoordinate(summaryStartRow + 1, 1), CellValue.number(50000));

    _data.setCell(const CellCoordinate(summaryStartRow + 2, 0), CellValue.text('Report Generated:'));
    _data.setCell(const CellCoordinate(summaryStartRow + 2, 1), CellValue.text(DateTime.now().toString().substring(0, 19)));

    _data.setCell(const CellCoordinate(summaryStartRow + 3, 0), CellValue.text('Grid Size:'));
    _data.setCell(const CellCoordinate(summaryStartRow + 3, 1), CellValue.text('1,048,576 rows × 16,384 columns (XFD)'));

    // === Additional data in columns O onwards (simulating more sheets/data) ===
    // Add a separate "lookup table" starting at column Q (index 16)

    _data.setCell(const CellCoordinate(0, 16), CellValue.text('PRODUCT CATALOG'));
    _data.setStyle(const CellCoordinate(0, 16), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFF70AD47),
      textColor: Color(0xFFFFFFFF),
    ));

    final catalogHeaders = ['Code', 'Name', 'Base Price', 'In Stock'];
    for (var col = 0; col < catalogHeaders.length; col++) {
      _data.setCell(CellCoordinate(1, 16 + col), CellValue.text(catalogHeaders[col]));
      _data.setStyle(CellCoordinate(1, 16 + col), const CellStyle(
        backgroundColor: Color(0xFFE2EFDA),
        fontWeight: FontWeight.bold,
      ));
    }

    for (var i = 0; i < products.length; i++) {
      _data.setCell(CellCoordinate(2 + i, 16), CellValue.text('PRD-${(i + 1).toString().padLeft(3, '0')}'));
      _data.setCell(CellCoordinate(2 + i, 17), CellValue.text(products[i]));
      _data.setCell(CellCoordinate(2 + i, 18), CellValue.number((random.nextDouble() * 400 + 50).roundToDouble()));
      _data.setCell(CellCoordinate(2 + i, 19), CellValue.number((random.nextInt(1000) + 50).toDouble()));
    }

    // === Data at far corners to test large grid navigation ===

    // Data at row 100,000
    _data.setCell(const CellCoordinate(100000, 0), CellValue.text('DATA AT ROW 100,001'));
    _data.setStyle(const CellCoordinate(100000, 0), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFFFFEB9C),
    ));
    for (var col = 1; col < 10; col++) {
      _data.setCell(CellCoordinate(100000, col), CellValue.number((random.nextDouble() * 1000).roundToDouble()));
    }

    // Data at row 500,000
    _data.setCell(const CellCoordinate(500000, 0), CellValue.text('DATA AT ROW 500,001'));
    _data.setStyle(const CellCoordinate(500000, 0), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFFFFEB9C),
    ));
    for (var col = 1; col < 10; col++) {
      _data.setCell(CellCoordinate(500000, col), CellValue.number((random.nextDouble() * 1000).roundToDouble()));
    }

    // Data at the last row (1,048,575)
    _data.setCell(const CellCoordinate(1048575, 0), CellValue.text('LAST ROW (1,048,576)'));
    _data.setStyle(const CellCoordinate(1048575, 0), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFFFF6B6B),
      textColor: Color(0xFFFFFFFF),
    ));

    // Data at column 1000 (ALM)
    _data.setCell(const CellCoordinate(0, 1000), CellValue.text('COLUMN 1001 (ALM)'));
    _data.setStyle(const CellCoordinate(0, 1000), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFF9B59B6),
      textColor: Color(0xFFFFFFFF),
    ));
    for (var row = 1; row <= 100; row++) {
      _data.setCell(CellCoordinate(row, 1000), CellValue.number((random.nextDouble() * 500).roundToDouble()));
    }

    // Data at column 10000 (NTQ)
    _data.setCell(const CellCoordinate(0, 10000), CellValue.text('COLUMN 10001 (NTQ)'));
    _data.setStyle(const CellCoordinate(0, 10000), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFF3498DB),
      textColor: Color(0xFFFFFFFF),
    ));
    for (var row = 1; row <= 50; row++) {
      _data.setCell(CellCoordinate(row, 10000), CellValue.number((random.nextDouble() * 500).roundToDouble()));
    }

    // Data at last column (16383 = XFD)
    _data.setCell(const CellCoordinate(0, 16383), CellValue.text('LAST COL (XFD)'));
    _data.setStyle(const CellCoordinate(0, 16383), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFFFF6B6B),
      textColor: Color(0xFFFFFFFF),
    ));

    // Corner cell - last row, last column
    _data.setCell(const CellCoordinate(1048575, 16383), CellValue.text('XFD1048576'));
    _data.setStyle(const CellCoordinate(1048575, 16383), const CellStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: Color(0xFF2ECC71),
      textColor: Color(0xFFFFFFFF),
    ));
  }

  void _onEditCell(CellCoordinate cell) {
    // Calculate cell bounds for the editor overlay
    const headerWidth = 40.0; // Narrower for Excel-like appearance
    const headerHeight = 20.0;

    final cellLeft = _layoutSolver.getColumnLeft(cell.column) * _controller.zoom;
    final cellTop = _layoutSolver.getRowTop(cell.row) * _controller.zoom;
    final cellWidth = _layoutSolver.getColumnWidth(cell.column) * _controller.zoom;
    final cellHeight = _layoutSolver.getRowHeight(cell.row) * _controller.zoom;

    // Adjust for scroll offset and headers
    final adjustedLeft = cellLeft - _controller.scrollX + headerWidth;
    final adjustedTop = cellTop - _controller.scrollY + headerHeight;

    setState(() {
      _editingCellBounds = Rect.fromLTWH(
        adjustedLeft,
        adjustedTop,
        cellWidth,
        cellHeight,
      );
    });

    // Start editing
    final currentValue = _data.getCell(cell);
    _editController.startEdit(
      cell: cell,
      currentValue: currentValue,
      trigger: EditTrigger.doubleTap,
    );
  }

  void _onCommit(CellCoordinate cell, CellValue? value) {
    setState(() {
      _data.setCell(cell, value);
      _editingCellBounds = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${cell.toNotation()}: ${value?.displayValue ?? "(empty)"}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onCancel() {
    setState(() {
      _editingCellBounds = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Demo - Sales Data'),
        actions: [
          // Zoom slider with non-linear scale
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('10%', style: TextStyle(fontSize: 11)),
                SizedBox(
                  width: 180,
                  child: Slider(
                    value: zoomToSlider(_controller.zoom),
                    onChanged: (value) {
                      final zoom = sliderToZoom(value);
                      _controller.setZoom(zoom);
                      setState(() {});
                    },
                    divisions: 100,
                  ),
                ),
                const Text('400%', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(_controller.zoom * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.resetZoom();
              setState(() {});
            },
            tooltip: 'Reset to 100%',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSelectionInfo(),
          _buildInstructions(),
          Expanded(
            child: Stack(
              children: [
                // The worksheet widget
                Focus(
                  autofocus: true,
                  onKeyEvent: _handleKeyEvent,
                  child: WorksheetTheme(
                    data: WorksheetThemeData(
                      showHeaders: true,
                      showGridlines: true,
                      defaultRowHeight: _defaultRowHeight,
                      defaultColumnWidth: _defaultColumnWidth,
                      rowHeaderWidth: 40.0, // Narrower like Excel
                      columnHeaderHeight: 20.0, // Shorter like Excel
                      fontSize: 11.0, // Smaller font like Excel
                    ),
                    child: Worksheet(
                      data: _data,
                      controller: _controller,
                      rowCount: _rowCount,
                      columnCount: _columnCount,
                      onEditCell: _onEditCell,
                      onCellTap: (cell) {
                        // Close any open editor when tapping a different cell
                        if (_editController.isEditing &&
                            _editController.editingCell != cell) {
                          _editController.commitEdit(onCommit: _onCommit);
                        }
                      },
                    ),
                  ),
                ),

                // Cell editor overlay
                if (_editController.isEditing && _editingCellBounds != null)
                  CellEditorOverlay(
                    editController: _editController,
                    cellBounds: _editingCellBounds!,
                    onCommit: _onCommit,
                    onCancel: _onCancel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // F2 to edit current cell
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      final cell = _controller.focusCell;
      if (cell != null && !_editController.isEditing) {
        _onEditCell(cell);
        return KeyEventResult.handled;
      }
    }

    // Arrow keys to navigate
    if (!_editController.isEditing) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _controller.moveFocus(rowDelta: -1, columnDelta: 0, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _controller.moveFocus(rowDelta: 1, columnDelta: 0, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.moveFocus(rowDelta: 0, columnDelta: -1, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.moveFocus(rowDelta: 0, columnDelta: 1, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _controller.moveFocus(rowDelta: 0, columnDelta: isShift ? -1 : 1, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _controller.moveFocus(rowDelta: isShift ? -1 : 1, columnDelta: 0, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildSelectionInfo() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selection = _controller.selectedRange;
        final focus = _controller.focusCell;
        final cellValue = focus != null ? _data.getCell(focus) : null;

        String text;
        if (selection != null) {
          final start = CellCoordinate(selection.startRow, selection.startColumn);
          final end = CellCoordinate(selection.endRow, selection.endColumn);
          if (start == end) {
            text = 'Selected: ${start.toNotation()}';
          } else {
            text = 'Selected: ${start.toNotation()}:${end.toNotation()}';
          }
          if (cellValue != null) {
            text += ' = ${cellValue.displayValue}';
          }
        } else {
          text = 'No selection - click a cell to select';
        }

        return Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[200],
          width: double.infinity,
          child: Text(text, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.blue[50],
      width: double.infinity,
      child: const Text(
        'Drag column/row header borders to resize | Double-click or F2 to edit | Scroll to column Q for product catalog',
        style: TextStyle(fontSize: 11, color: Colors.blueGrey),
      ),
    );
  }
}
