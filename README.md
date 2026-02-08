# Worksheet Widget

[![pub package](https://img.shields.io/pub/v/worksheet.svg)](https://pub.dev/packages/worksheet)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/sjhorn/worksheet/actions/workflows/tests.yml/badge.svg)](https://github.com/sjhorn/worksheet/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/sjhorn/worksheet/branch/main/graph/badge.svg)](https://codecov.io/gh/sjhorn/worksheet)

A Flutter widget that brings Excel-like spreadsheet functionality to your app.

![Worksheet Screenshot](doc/images/worksheet_screenshot.png)

Display and edit tabular data with smooth scrolling, pinch-to-zoom, and cell selection - all running at 60fps even with hundreds of thousands of rows.

## Try It In 30 Seconds

```dart
import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(MaterialApp(home: MySpreadsheet()));

class MySpreadsheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = SparseWorksheetData(rowCount: 100, columnCount: 10, cells: {
        (0, 0): 'Name'.cell,
        (0, 1): 'Amount'.cell,
        (1, 0): 'Apples'.cell,
        (1, 1): 42.cell,
        (2, 1): '=2+42'.formula,
        (3, 1): Cell.text('test'),
    });

    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: data,
          rowCount: 100,
          columnCount: 10,
        ),
      ),
    );
  }
}
```

That's it! You now have a scrollable, zoomable spreadsheet with row/column headers.

## Add Selection and Editing

Want users to select and edit cells? Add a controller and callbacks:

```dart
class EditableSpreadsheet extends StatefulWidget {
  @override
  State<EditableSpreadsheet> createState() => _EditableSpreadsheetState();
}

class _EditableSpreadsheetState extends State<EditableSpreadsheet> {
  final _data = SparseWorksheetData(rowCount: 1000, columnCount: 26);
  final _controller = WorksheetController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          controller: _controller,
          rowCount: 1000,
          columnCount: 26,
          onCellTap: (cell) {
            print('Tapped ${cell.toNotation()}');  // "A1", "B5", etc.
          },
          onEditCell: (cell) {
            // Double-tap triggers edit - implement your editor UI
            print('Edit ${cell.toNotation()}');
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }
}
```

Now you can:
- Click cells to select them
- Use arrow keys to navigate
- Track selection via `_controller.selectedRange`
- Zoom with pinch gestures or `_controller.setZoom(1.5)`

## Format Your Numbers

Display values as currency, percentages, dates, and more using Excel-style format codes:

```dart
final data = SparseWorksheetData(rowCount: 100, columnCount: 10, cells: {
    (0, 0): 'Revenue'.cell,
    (0, 1): Cell.number(1234.56, format: CellFormat.currency),     // "$1,234.56"
    (1, 0): 'Growth'.cell,
    (1, 1): Cell.number(0.085, format: CellFormat.percentage),     // "9%"
    (2, 0): 'Date'.cell,
    (2, 1): Cell.date(DateTime(2024, 1, 15), format: CellFormat.dateIso), // "2024-01-15"
    (3, 0): 'Precision'.cell,
    (3, 1): Cell.number(3.14159, format: CellFormat.scientific),   // "3.14E+00"
});
```

16 built-in presets cover common formats. For custom codes, create your own:

```dart
const custom = CellFormat(type: CellFormatType.number, formatCode: '#,##0.000');
```

## Automatic Date Detection

Type a date into a cell and it's stored as a `CellValue.date()`, not plain text:

```dart
// These are detected automatically during editing and paste:
// "2025-01-15"      → CellValue.date(DateTime(2025, 1, 15))
// "Jan 15, 2025"    → CellValue.date(DateTime(2025, 1, 15))
// "42"              → CellValue.number(42)  (numbers are not treated as dates)

// Configure date format preferences for ambiguous dates:
Worksheet(
  data: data,
  dateParser: AnyDate.fromLocale('en-US'),  // month/day/year
)
```

`AnyDate` and `DateParserInfo` are re-exported from `package:worksheet/worksheet.dart`.

## Style Your Data

Add colors, bold text, and conditional formatting:

```dart
// Header row styling
const headerStyle = CellStyle(
  backgroundColor: Color(0xFF4472C4),
  textColor: Color(0xFFFFFFFF),
  fontWeight: FontWeight.bold,
  textAlignment: CellTextAlignment.center,
);

// Apply to cells
_data.setStyle(const CellCoordinate(0, 0), headerStyle);
_data.setStyle(const CellCoordinate(0, 1), headerStyle);

// Add borders with line styles (solid, dashed, dotted, double)
_data.setStyle(
  const CellCoordinate(0, 0),
  const CellStyle(
    borders: CellBorders(
      bottom: BorderStyle(width: 2.0, lineStyle: BorderLineStyle.solid),
    ),
  ),
);

// Highlight negative numbers in red
final value = _data.getCell(CellCoordinate(row, col));
if (value != null && value.isNumber && value.asDouble < 0) {
  _data.setStyle(
    CellCoordinate(row, col),
    const CellStyle(textColor: Color(0xFFCC0000)),
  );
}
```

## Handle Large Datasets

The widget uses sparse storage and tile-based rendering, so this works smoothly:

```dart
// Excel-sized grid: 1 million rows, 16K columns
final data = SparseWorksheetData(
  rowCount: 1048576,
  columnCount: 16384,
);

// Only populated cells use memory
for (var row = 0; row < 50000; row++) {
  data[(row, 0)] = Cell.text('Row ${row + 1}');
}
// Memory usage: ~50K cells, not 17 billion empty cells
```

---

## Why This Widget?

### Built for Performance

- **Tile-based rendering**: Only visible cells are drawn, cached as GPU textures
- **60fps scrolling**: Smooth even with 100K+ populated cells
- **10%-400% zoom**: Pinch to zoom with automatic level-of-detail
- **O(log n) lookups**: Binary search for row/column positions

### Built for Real Apps

- **Sparse storage**: Memory scales with data, not grid size
- **Full selection**: Single cell, ranges, entire rows/columns
- **Keyboard navigation**: Arrow keys, Tab, Enter, Home/End, clipboard, and more — fully customizable via Flutter's Shortcuts/Actions
- **Automatic type detection**: Numbers, booleans, dates, and formulas detected from text input via `CellValue.parse()`
- **Resize support**: Drag column/row borders to resize
- **Theming**: Full control over colors, fonts, headers

### Built with Quality

- **SOLID principles**: Clean separation of concerns
- **Test coverage**: 87%+ with unit, widget, and performance tests
- **TDD workflow**: Tests written before implementation

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](GETTING_STARTED.md) | Installation, basic setup, enabling editing |
| [Cookbook](COOKBOOK.md) | Practical recipes for common tasks |
| [Performance](PERFORMANCE.md) | Tile cache tuning, large dataset strategies |
| [Theming](THEMING.md) | Colors, fonts, headers, selection styles |
| [Testing](TESTING.md) | Unit tests, widget tests, benchmarks |
| [API Reference](API.md) | Quick reference for all classes and methods |
| [Architecture](ARCHITECTURE.md) | Deep dive into the rendering pipeline |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  worksheet: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## Keyboard Shortcuts

All shortcuts work out of the box. You can override or extend them via the `shortcuts` and `actions` parameters.

| Key | Action |
|-----|--------|
| Arrow keys | Move selection |
| Shift + Arrow | Extend selection |
| Tab / Shift+Tab | Move right/left |
| Enter / Shift+Enter | Move down/up |
| Home / End | Start/end of row |
| Ctrl+Home / Ctrl+End | Go to A1 / last cell |
| Page Up / Page Down | Move up/down by 10 rows |
| F2 | Edit current cell |
| Escape | Collapse range to single cell |
| Ctrl+A | Select all |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / Cut / Paste |
| Ctrl+D / Ctrl+R | Fill down / Fill right |
| Delete / Backspace | Clear selected cells |

### Customizing Shortcuts

```dart
Worksheet(
  data: data,
  // Override: make Enter do nothing
  shortcuts: {
    const SingleActivator(LogicalKeyboardKey.enter): const DoNothingAndStopPropagationIntent(),
  },
  // Override: custom action for Delete
  actions: {
    ClearCellsIntent: CallbackAction<ClearCellsIntent>(
      onInvoke: (_) { print('Custom delete!'); return null; },
    ),
  },
)
```

See `DefaultWorksheetShortcuts.shortcuts` for the full list of default bindings.

---

## Quick API Overview

```dart
// Data - map literal construction with record coordinates
final data = SparseWorksheetData(
  rowCount: 1000,
  columnCount: 26,
  cells: {
    (0, 0): 'Hello'.cell,
    (0, 1): 42.cell,
  },
);

// Bracket access with (row, col) records
data[(1, 0)] = 'World'.cell;
data[(1, 1)] = Cell.number(99, style: const CellStyle(fontWeight: FontWeight.bold));
final cell = data[(0, 0)];  // Cell(value: 'Hello', style: null)

// Extensions for quick cell creation
'Hello'.cell            // Cell with text value
42.cell                 // Cell with numeric value
true.cell               // Cell with boolean value
DateTime.now().cell     // Cell with date value
'=SUM(A1:A10)'.formula  // Cell with formula

// Cell constructors for full control (when you need style or format)
Cell.text('Hello', style: headerStyle)
Cell.number(42.5, format: CellFormat.currency)
Cell.boolean(true)
Cell.date(DateTime.now(), format: CellFormat.dateIso)
Cell.withStyle(headerStyle)  // style only, no value

// Controller
final controller = WorksheetController();
controller.selectCell(const CellCoordinate(5, 3));
controller.selectRange(CellRange(0, 0, 10, 5));
controller.setZoom(1.5);  // 150%
controller.scrollTo(x: 500, y: 1000, animate: true);
```

---

## Running the Example

```bash
cd example
flutter run
```

The example app demonstrates:
- 50,000 rows of sample sales data
- Cell editing with double-tap
- Column/row resizing
- Zoom slider (10%-400%)
- Keyboard navigation

---

## Running Tests

```bash
flutter test                    # Run all tests
flutter test --coverage         # With coverage report
flutter test test/core/         # Run specific directory
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.
