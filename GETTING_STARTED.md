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
    _data = SparseWorksheetData(rowCount: 1000, columnCount: 26);
    _controller = WorksheetController();

    // Add some sample data
    _data.setCell(const CellCoordinate(0, 0), CellValue.text('Hello'));
    _data.setCell(const CellCoordinate(0, 1), CellValue.number(42));
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
// Create a worksheet data source
final data = SparseWorksheetData(
  rowCount: 100000,    // Up to 1,048,576 rows (Excel limit)
  columnCount: 16384,  // Up to 16,384 columns (A to XFD)
);

// Set cell values
data.setCell(
  const CellCoordinate(0, 0),  // row 0, column 0 (A1)
  CellValue.text('Product Name'),
);

data.setCell(
  const CellCoordinate(1, 0),  // row 1, column 0 (A2)
  CellValue.number(99.99),
);

// Get cell values
final value = data.getCell(const CellCoordinate(0, 0));
print(value?.displayValue);  // "Product Name"

// Clear a cell
data.setCell(const CellCoordinate(0, 0), null);
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
```

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

Cell editing requires an `EditController` and `CellEditorOverlay`:

```dart
class _MyWidgetState extends State<MyWidget> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;
  late final LayoutSolver _layoutSolver;
  Rect? _editingCellBounds;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: 1000, columnCount: 26);
    _controller = WorksheetController();
    _editController = EditController();

    // LayoutSolver needed to calculate cell bounds for editor positioning
    _layoutSolver = LayoutSolver(
      rows: SpanList(count: 1000, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
  }

  void _onEditCell(CellCoordinate cell) {
    // Calculate where to position the editor overlay
    final cellLeft = _layoutSolver.getColumnLeft(cell.column) * _controller.zoom;
    final cellTop = _layoutSolver.getRowTop(cell.row) * _controller.zoom;
    final cellWidth = _layoutSolver.getColumnWidth(cell.column) * _controller.zoom;
    final cellHeight = _layoutSolver.getRowHeight(cell.row) * _controller.zoom;

    // Adjust for scroll and headers
    const headerWidth = 50.0;
    const headerHeight = 24.0;
    final adjustedLeft = cellLeft - _controller.scrollX + headerWidth;
    final adjustedTop = cellTop - _controller.scrollY + headerHeight;

    setState(() {
      _editingCellBounds = Rect.fromLTWH(
        adjustedLeft, adjustedTop, cellWidth, cellHeight,
      );
    });

    // Start editing
    _editController.startEdit(
      cell: cell,
      currentValue: _data.getCell(cell),
      trigger: EditTrigger.doubleTap,
    );
  }

  void _onCommit(CellCoordinate cell, CellValue? value) {
    setState(() {
      _data.setCell(cell, value);
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
