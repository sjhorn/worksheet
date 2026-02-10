# Getting Started with Worksheet Widget

A high-performance Flutter worksheet widget with Excel-like functionality, supporting 10%-400% zoom with GPU-optimized tile-based rendering.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  worksheet: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Minimal Working Example

```dart
import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: WorksheetExample(),
      ),
    );
  }
}

class WorksheetExample extends StatefulWidget {
  @override
  State<WorksheetExample> createState() => _WorksheetExampleState();
}

class _WorksheetExampleState extends State<WorksheetExample> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 1000,
      columnCount: 26,
      cells: {
        (0, 0): 'Hello'.cell,
        (0, 1): 42.cell,
      },
    );
    _controller = WorksheetController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorksheetTheme(
      data: const WorksheetThemeData(),
      child: Worksheet(
        data: _data,
        controller: _controller,
        rowCount: 1000,
        columnCount: 26,
      ),
    );
  }
}
```

## Understanding WorksheetData

The `WorksheetData` abstract class defines the data interface. Use `SparseWorksheetData` for efficient storage of sparse data (most cells empty):

```dart
// Create with map literal and record coordinates (row, col)
final data = SparseWorksheetData(
  rowCount: 100000,    // Up to 1,048,576 rows (Excel limit)
  columnCount: 16384,  // Up to 16,384 columns (A to XFD)
  cells: {
    (0, 0): 'Product Name'.cell,  // .cell extension for quick creation
    (1, 0): 99.99.cell,           // Works on num too
  },
);

// Bracket access with (row, col) records
data[(2, 0)] = Cell.text('Another Product');
data[(2, 1)] = Cell.number(49.99);

// Read cells
final cell = data[(0, 0)];  // Cell(value: 'Product Name', style: null)

// Clear a cell
data[(2, 0)] = null;

// Low-level access (CellValue/CellStyle separately) is also available:
data.setCell(const CellCoordinate(0, 0), CellValue.text('Product Name'));
final value = data.getCell(const CellCoordinate(0, 0));
```

### CellValue Types

```dart
// Text values
CellValue.text('Hello World')

// Numeric values
CellValue.number(42)
CellValue.number(3.14159)

// Boolean values
CellValue.boolean(true)   // Displays as "TRUE"
CellValue.boolean(false)  // Displays as "FALSE"

// Date values
CellValue.date(DateTime.now())  // Displays as "YYYY-MM-DD"

// Formula (stored but not evaluated)
CellValue.formula('=SUM(A1:A10)')

// Error values
CellValue.error('#DIV/0!')

// Parse text into the appropriate type automatically
CellValue.parse('42')           // → CellValue.number(42)
CellValue.parse('TRUE')         // → CellValue.boolean(true)
CellValue.parse('2025-01-15')   // → CellValue.date(DateTime(2025, 1, 15))
CellValue.parse('hello')        // → CellValue.text('hello')
CellValue.parse('=SUM(A1:A5)')  // → CellValue.formula('=SUM(A1:A5)')
```

`CellValue.parse()` is used internally when editing cells and pasting from
the clipboard. It detects types in this order: formula → boolean → number →
date → text.

### Cell Formatting

Control how values are displayed using `CellFormat` with Excel-style format codes:

```dart
// Built-in presets
Cell.number(1234.56, format: CellFormat.currency)       // "$1,234.56"
Cell.number(0.42, format: CellFormat.percentage)         // "42%"
Cell.date(DateTime(2024, 1, 15), format: CellFormat.dateIso)  // "2024-01-15"
Cell.number(12345, format: CellFormat.scientific)        // "1.23E+04"

// Custom format codes
const custom = CellFormat(type: CellFormatType.number, formatCode: '#,##0.000');
Cell.number(3.14159, format: custom)                     // "3.142"
```

See [COOKBOOK.md](COOKBOOK.md) for the full list of presets and more examples.

## Using WorksheetController

The controller provides programmatic access to selection, zoom, and scrolling:

```dart
final controller = WorksheetController();

// Selection
controller.selectCell(const CellCoordinate(5, 3));  // Select D6
controller.selectRange(CellRange(0, 0, 10, 5));     // Select A1:F11
controller.selectRow(5, columnCount: 26);           // Select entire row 6
controller.selectColumn(2, rowCount: 1000);         // Select column C
controller.clearSelection();

// Access selection state
final range = controller.selectedRange;
final focus = controller.focusCell;
final hasSelection = controller.hasSelection;

// Zoom (10% to 400%)
controller.setZoom(1.5);   // 150%
controller.zoomIn();       // Increase by step
controller.zoomOut();      // Decrease by step
controller.resetZoom();    // Back to 100%
final currentZoom = controller.zoom;

// Scrolling
controller.scrollTo(x: 500, y: 1000, animate: true);

// Keyboard navigation
controller.moveFocus(
  rowDelta: 1,
  columnDelta: 0,
  extend: false,  // true to extend selection
  maxRow: 999,
  maxColumn: 25,
);

// Listen for changes
controller.addListener(() {
  print('Selection: ${controller.selectedRange}');
  print('Zoom: ${controller.zoom}');
});
```

## Handling Cell Selection

```dart
Worksheet(
  data: _data,
  controller: _controller,
  onCellTap: (CellCoordinate cell) {
    print('Tapped: ${cell.toNotation()}');  // e.g., "A1", "B5"

    // Access the cell value
    final value = _data.getCell(cell);
    print('Value: ${value?.displayValue}');
  },
)
```

## Enabling Cell Editing

Cell editing requires an `EditController` and `CellEditorOverlay`. The `WorksheetController` provides `getCellScreenBounds()` to position the editor overlay — no need to create your own `LayoutSolver`:

```dart
class _MyWidgetState extends State<MyWidget> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;
  Rect? _editingCellBounds;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: 1000, columnCount: 26);
    _controller = WorksheetController();
    _editController = EditController();
  }

  void _onEditCell(CellCoordinate cell) {
    // getCellScreenBounds accounts for zoom, scroll, and headers
    final bounds = _controller.getCellScreenBounds(cell);
    if (bounds == null) return;

    setState(() => _editingCellBounds = bounds);

    _editController.startEdit(
      cell: cell,
      currentValue: _data.getCell(cell),
      trigger: EditTrigger.doubleTap,
    );
  }

  void _onCommit(CellCoordinate cell, CellValue? value,
      {CellFormat? detectedFormat}) {
    setState(() {
      _data.setCell(cell, value);
      if (detectedFormat != null && _data.getFormat(cell) == null) {
        _data.setFormat(cell, detectedFormat);
      }
      _editingCellBounds = null;
    });
  }

  void _onCancel() {
    setState(() {
      _editingCellBounds = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: _data,
            controller: _controller,
            onEditCell: _onEditCell,  // Called on double-tap
          ),
        ),

        // Editor overlay
        if (_editController.isEditing && _editingCellBounds != null)
          CellEditorOverlay(
            editController: _editController,
            cellBounds: _editingCellBounds!,
            onCommit: _onCommit,
            onCancel: _onCancel,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }
}
```

## Basic Theming

Wrap your `Worksheet` with `WorksheetTheme` to customize appearance:

```dart
WorksheetTheme(
  data: WorksheetThemeData(
    // Cell appearance
    cellBackgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 14.0,
    fontFamily: 'Roboto',
    cellPadding: 4.0,

    // Gridlines
    showGridlines: true,
    gridlineColor: const Color(0xFFE0E0E0),
    gridlineWidth: 1.0,

    // Headers
    showHeaders: true,
    rowHeaderWidth: 50.0,
    columnHeaderHeight: 24.0,

    // Default sizes
    defaultRowHeight: 24.0,
    defaultColumnWidth: 100.0,

    // Selection style
    selectionStyle: const SelectionStyle(
      fillColor: Color(0x220078D4),
      borderColor: Color(0xFF0078D4),
      borderWidth: 1.0,
    ),

    // Header style
    headerStyle: const HeaderStyle(
      backgroundColor: Color(0xFFF5F5F5),
      textColor: Color(0xFF616161),
      fontSize: 12.0,
    ),
  ),
  child: Worksheet(...),
)
```

## Read-Only Mode

For a view-only spreadsheet, set `readOnly: true`:

```dart
Worksheet(
  data: _data,
  controller: _controller,
  readOnly: true,  // Disables selection and editing
)
```

## Custom Row and Column Sizes

```dart
Worksheet(
  data: _data,
  controller: _controller,
  customRowHeights: {
    0: 40.0,   // Row 1 is 40px tall
    5: 60.0,   // Row 6 is 60px tall
  },
  customColumnWidths: {
    0: 150.0,  // Column A is 150px wide
    2: 200.0,  // Column C is 200px wide
  },
)
```

## Handling Row/Column Resize

```dart
Worksheet(
  data: _data,
  controller: _controller,
  onResizeRow: (int row, double newHeight) {
    print('Row $row resized to $newHeight');
    // Persist the new height if needed
  },
  onResizeColumn: (int column, double newWidth) {
    print('Column $column resized to $newWidth');
    // Persist the new width if needed
  },
)
```

## Next Steps

- See [COOKBOOK.md](COOKBOOK.md) for practical recipes
- See [THEMING.md](THEMING.md) for detailed customization
- See [PERFORMANCE.md](PERFORMANCE.md) for optimization tips
- See [API.md](API.md) for complete API reference
