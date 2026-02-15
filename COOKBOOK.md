# Worksheet Widget Cookbook

Practical recipes for common worksheet tasks.

## Table of Contents

1. [Read-Only Spreadsheet Viewer](#read-only-spreadsheet-viewer)
2. [Editable Data Grid with Persistence](#editable-data-grid-with-persistence)
3. [Number Formatting](#number-formatting)
4. [Duration Formatting](#duration-formatting)
5. [Custom Cell Styling (Conditional Formatting)](#custom-cell-styling-conditional-formatting)
6. [Cell Borders](#cell-borders)
7. [Rich Text Spans](#rich-text-spans)
8. [Cell Merging](#cell-merging)
9. [Multi-Line Text (wrapText)](#multi-line-text-wraptext)
10. [Large Dataset Loading](#large-dataset-loading)
11. [Keyboard Navigation](#keyboard-navigation)
12. [Programmatic Scrolling to Cells](#programmatic-scrolling-to-cells)
13. [Export Data to CSV](#export-data-to-csv)
14. [Custom Column Widths](#custom-column-widths)
15. [Cell Value Validation](#cell-value-validation)
16. [Automatic Date Detection](#automatic-date-detection)
17. [Locale-Aware Formatting](#locale-aware-formatting)
18. [Multi-Select Resize](#multi-select-resize)
19. [Mobile Mode](#mobile-mode)

---

## Read-Only Spreadsheet Viewer

Display data without allowing user interaction:

```dart
class ReadOnlyViewer extends StatefulWidget {
  final List<List<String>> data;

  const ReadOnlyViewer({required this.data, super.key});

  @override
  State<ReadOnlyViewer> createState() => _ReadOnlyViewerState();
}

class _ReadOnlyViewerState extends State<ReadOnlyViewer> {
  late final SparseWorksheetData _worksheetData;
  late final WorksheetController _controller;

  @override
  void initState() {
    super.initState();
    _worksheetData = SparseWorksheetData(
      rowCount: widget.data.length,
      columnCount: widget.data.isEmpty ? 0 : widget.data[0].length,
    );
    _controller = WorksheetController();

    // Load data using bracket access with (row, col) records
    for (var row = 0; row < widget.data.length; row++) {
      for (var col = 0; col < widget.data[row].length; col++) {
        final value = widget.data[row][col];
        if (value.isNotEmpty) {
          _worksheetData[(row, col)] = Cell.text(value);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _worksheetData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorksheetTheme(
      data: const WorksheetThemeData(
        showHeaders: true,
        showGridlines: true,
      ),
      child: Worksheet(
        data: _worksheetData,
        controller: _controller,
        rowCount: widget.data.length,
        columnCount: widget.data.isEmpty ? 1 : widget.data[0].length,
        readOnly: true,  // Disables selection and editing
      ),
    );
  }
}
```

---

## Editable Data Grid with Persistence

Full editing with save/load functionality:

```dart
class EditableDataGrid extends StatefulWidget {
  @override
  State<EditableDataGrid> createState() => _EditableDataGridState();
}

class _EditableDataGridState extends State<EditableDataGrid> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;

  Rect? _editingCellBounds;
  bool _hasUnsavedChanges = false;

  static const int _rowCount = 1000;
  static const int _columnCount = 26;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: _rowCount, columnCount: _columnCount);
    _controller = WorksheetController();
    _editController = EditController();

    _loadData();
  }

  Future<void> _loadData() async {
    // Example: Load from SharedPreferences or database
    // final prefs = await SharedPreferences.getInstance();
    // final jsonData = prefs.getString('worksheet_data');
    // if (jsonData != null) {
    //   final Map<String, dynamic> dataMap = jsonDecode(jsonData);
    //   for (final entry in dataMap.entries) {
    //     final coords = entry.key.split(',');
    //     final cell = CellCoordinate(int.parse(coords[0]), int.parse(coords[1]));
    //     _data.setCell(cell, CellValue.text(entry.value));
    //   }
    // }
  }

  Future<void> _saveData() async {
    // Example: Save to SharedPreferences
    // final Map<String, String> dataMap = {};
    // for (var row = 0; row < _rowCount; row++) {
    //   for (var col = 0; col < _columnCount; col++) {
    //     final value = _data.getCell(CellCoordinate(row, col));
    //     if (value != null) {
    //       dataMap['$row,$col'] = value.displayValue;
    //     }
    //   }
    // }
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('worksheet_data', jsonEncode(dataMap));

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  void _onEditCell(CellCoordinate cell) {
    // getCellScreenBounds uses the Worksheet's internal LayoutSolver,
    // so it stays in sync with column/row resizes automatically.
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
      _hasUnsavedChanges = true;
    });
  }

  void _onCancel() {
    setState(() {
      _editingCellBounds = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasUnsavedChanges ? 'Data Grid *' : 'Data Grid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _hasUnsavedChanges ? _saveData : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          WorksheetTheme(
            data: const WorksheetThemeData(),
            child: Worksheet(
              data: _data,
              controller: _controller,
              rowCount: _rowCount,
              columnCount: _columnCount,
              onEditCell: _onEditCell,
            ),
          ),
          if (_editController.isEditing && _editingCellBounds != null)
            CellEditorOverlay(
              editController: _editController,
              cellBounds: _editingCellBounds!,
              onCommit: _onCommit,
              onCancel: _onCancel,
            ),
        ],
      ),
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

---

## Number Formatting

Display values as currency, percentages, dates, and more using `CellFormat`:

### Built-in Presets

```dart
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    (0, 0): 'Item'.cell,
    (0, 1): 'Price'.cell,
    (0, 2): 'Qty'.cell,
    (0, 3): 'Tax'.cell,
    (0, 4): 'Date'.cell,
    // Formatted data rows
    (1, 0): 'Widget'.cell,
    (1, 1): Cell.number(29.99, format: CellFormat.currency),       // "$29.99"
    (1, 2): Cell.number(1500, format: CellFormat.integer),         // "1,500"
    (1, 3): Cell.number(0.085, format: CellFormat.percentage),     // "9%"
    (1, 4): Cell.date(DateTime(2024, 3, 15), format: CellFormat.dateUs), // "3/15/2024"
  },
);
```

### Custom Format Codes

```dart
// Three decimal places with thousands separator
const threeDecimals = CellFormat(
  type: CellFormatType.number,
  formatCode: '#,##0.000',
);

// Percentage with two decimal places
const precisePercent = CellFormat(
  type: CellFormatType.percentage,
  formatCode: '0.00%',
);

// Apply format to existing cells via data layer
data.setFormat(const CellCoordinate(1, 1), CellFormat.currency);
```

### Combining Format and Style

```dart
// Format controls display, style controls appearance
data[(0, 0)] = Cell.number(
  -1234.56,
  format: CellFormat.currency,
  style: const CellStyle(
    textColor: Color(0xFFCC0000),        // Red for negative
    textAlignment: CellTextAlignment.right,
  ),
);
// Displays: "$1,234.56" in red, right-aligned
```

### All Available Presets

| Preset | Example Output |
|--------|---------------|
| `CellFormat.general` | `42` |
| `CellFormat.integer` | `1,234` |
| `CellFormat.decimal` | `42.00` |
| `CellFormat.number` | `1,234.56` |
| `CellFormat.currency` | `$1,234.56` |
| `CellFormat.percentage` | `42%` |
| `CellFormat.percentageDecimal` | `42.56%` |
| `CellFormat.scientific` | `1.23E+04` |
| `CellFormat.dateIso` | `2024-01-15` |
| `CellFormat.dateUs` | `1/15/2024` |
| `CellFormat.dateShort` | `15-Jan-24` |
| `CellFormat.dateShortLong` | `15-Jan-2024` |
| `CellFormat.dateLong` | `15 January 2024` |
| `CellFormat.dateEu` | `15/1/2024` |
| `CellFormat.dateUsDash` | `1-15-2024` |
| `CellFormat.dateEuDash` | `15-1-2024` |
| `CellFormat.dateUsDot` | `1.15.2024` |
| `CellFormat.dateEuDot` | `15.1.2024` |
| `CellFormat.dateMonthYear` | `Jan-24` |
| `CellFormat.time24` | `14:30` |
| `CellFormat.time24Seconds` | `14:30:05` |
| `CellFormat.time12` | `2:30 PM` |
| `CellFormat.text` | `hello` |
| `CellFormat.fraction` | `3 1/2` |
| `CellFormat.duration` | `1:30:05` |
| `CellFormat.durationShort` | `1:30` |
| `CellFormat.durationMinSec` | `90:05` |

---

## Duration Formatting

Display elapsed time and durations using Excel-style bracket notation:

### Built-in Presets

```dart
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    (0, 0): 'Task'.cell,
    (0, 1): 'Duration'.cell,
    // Hours:minutes:seconds — "1:30:05"
    (1, 0): 'Meeting'.cell,
    (1, 1): Cell.duration(
      const Duration(hours: 1, minutes: 30, seconds: 5),
      format: CellFormat.duration,
    ),
    // Hours:minutes only — "2:45"
    (2, 0): 'Travel'.cell,
    (2, 1): Cell.duration(
      const Duration(hours: 2, minutes: 45),
      format: CellFormat.durationShort,
    ),
    // Total minutes:seconds — "90:05"
    (3, 0): 'Sprint'.cell,
    (3, 1): Cell.duration(
      const Duration(hours: 1, minutes: 30, seconds: 5),
      format: CellFormat.durationMinSec,
    ),
  },
);
```

### Duration Extension

```dart
// Quick cell creation via .cell extension on Duration
const Duration(hours: 2, minutes: 30).cell  // Cell.duration(...)
```

### Custom Duration Format Codes

The bracketed unit accumulates beyond its normal range (e.g., `[h]` shows 25 hours, not 1 day + 1 hour):

```dart
// Total seconds only
const totalSeconds = CellFormat(
  type: CellFormatType.duration,
  formatCode: '[s]',
);
// Duration(minutes: 1, seconds: 30) → "90"
```

### Available Format Codes

| Code | Meaning | Example (1h 30m 5s) |
|------|---------|---------------------|
| `[h]:mm:ss` | Total hours : min : sec | `1:30:05` |
| `[h]:mm` | Total hours : min | `1:30` |
| `[m]:ss` | Total minutes : sec | `90:05` |
| `[s]` | Total seconds | `5405` |
| `h:mm:ss` | Same as `[h]:mm:ss` for duration values | `1:30:05` |

### Combining with Style

```dart
data[(0, 0)] = Cell.duration(
  const Duration(hours: 8, minutes: 30),
  format: CellFormat.duration,
  style: const CellStyle(
    textColor: Color(0xFF008000),        // Green
    textAlignment: CellTextAlignment.right,
  ),
);
// Displays: "8:30:00" in green, right-aligned
```

---

## Custom Cell Styling (Conditional Formatting)

Apply styles based on cell values:

```dart
void applyConditionalFormatting(SparseWorksheetData data) {
  // Style for header row
  const headerStyle = CellStyle(
    backgroundColor: Color(0xFF4472C4),
    textColor: Color(0xFFFFFFFF),
    fontWeight: FontWeight.bold,
    textAlignment: CellTextAlignment.center,
  );

  // Style for negative numbers (red)
  const negativeStyle = CellStyle(
    textColor: Color(0xFFCC0000),
  );

  // Style for positive numbers (green)
  const positiveStyle = CellStyle(
    textColor: Color(0xFF008000),
  );

  // Alternating row colors
  const evenRowStyle = CellStyle(
    backgroundColor: Color(0xFFF2F2F2),
  );

  // Apply header style to row 0
  for (var col = 0; col < 10; col++) {
    data.setStyle(CellCoordinate(0, col), headerStyle);
  }

  // Apply conditional formatting to data rows
  for (var row = 1; row < 100; row++) {
    // Alternating row background
    if (row.isEven) {
      for (var col = 0; col < 10; col++) {
        data.setStyle(CellCoordinate(row, col), evenRowStyle);
      }
    }

    // Number formatting for column 5 (amount column)
    final value = data.getCell(CellCoordinate(row, 5));
    if (value != null && value.isNumber) {
      final amount = value.asDouble;
      if (amount < 0) {
        data.setStyle(CellCoordinate(row, 5), negativeStyle);
      } else if (amount > 0) {
        data.setStyle(CellCoordinate(row, 5), positiveStyle);
      }
    }
  }
}
```

### Highlight Cells Above/Below Threshold

```dart
void highlightThreshold(
  SparseWorksheetData data,
  int column,
  double threshold,
) {
  const aboveStyle = CellStyle(
    backgroundColor: Color(0xFFD4EDDA),  // Light green
  );

  const belowStyle = CellStyle(
    backgroundColor: Color(0xFFF8D7DA),  // Light red
  );

  for (var row = 1; row < 1000; row++) {
    final value = data.getCell(CellCoordinate(row, column));
    if (value != null && value.isNumber) {
      final num = value.asDouble;
      data.setStyle(
        CellCoordinate(row, column),
        num >= threshold ? aboveStyle : belowStyle,
      );
    }
  }
}
```

---

## Cell Borders

Add borders to cells with various line styles, colors, and widths.

### Basic Border on All Sides

```dart
data.setStyle(
  CellCoordinate(0, 0),
  const CellStyle(
    borders: CellBorders.all(BorderStyle(
      color: Color(0xFF000000),
      width: 1.0,
    )),
  ),
);
```

### Individual Side Borders

```dart
data.setStyle(
  CellCoordinate(0, 0),
  const CellStyle(
    borders: CellBorders(
      bottom: BorderStyle(width: 2.0, color: Color(0xFF000000)),
    ),
  ),
);
```

### Line Styles

Five line styles are available: `none`, `solid`, `dotted`, `dashed`, and `double`:

```dart
data.setStyle(
  CellCoordinate(0, 0),
  const CellStyle(
    borders: CellBorders(
      top: BorderStyle(lineStyle: BorderLineStyle.solid),
      right: BorderStyle(lineStyle: BorderLineStyle.dashed),
      bottom: BorderStyle(lineStyle: BorderLineStyle.dotted),
      left: BorderStyle(lineStyle: BorderLineStyle.double),
    ),
  ),
);
```

### Header Row with Thick Bottom Border

```dart
const headerBorderStyle = CellStyle(
  fontWeight: FontWeight.bold,
  backgroundColor: Color(0xFF4472C4),
  textColor: Color(0xFFFFFFFF),
  borders: CellBorders(
    bottom: BorderStyle(
      width: 2.0,
      color: Color(0xFF2E5A94),
      lineStyle: BorderLineStyle.solid,
    ),
  ),
);

for (var col = 0; col < 10; col++) {
  data.setStyle(CellCoordinate(0, col), headerBorderStyle);
}
```

### Table Outline

Apply borders to edge cells to create a table outline:

```dart
void addTableOutline(SparseWorksheetData data, CellRange range) {
  const border = BorderStyle(width: 2.0, color: Color(0xFF000000));

  for (var col = range.startColumn; col <= range.endColumn; col++) {
    // Top edge
    data.setStyle(
      CellCoordinate(range.startRow, col),
      CellStyle(borders: CellBorders(top: border)),
    );
    // Bottom edge
    data.setStyle(
      CellCoordinate(range.endRow, col),
      CellStyle(borders: CellBorders(bottom: border)),
    );
  }

  for (var row = range.startRow; row <= range.endRow; row++) {
    // Left edge
    data.setStyle(
      CellCoordinate(row, range.startColumn),
      CellStyle(borders: CellBorders(left: border)),
    );
    // Right edge
    data.setStyle(
      CellCoordinate(row, range.endColumn),
      CellStyle(borders: CellBorders(right: border)),
    );
  }
}
```

### Adjacent Cell Border Behavior

When two adjacent cells both define a border on a shared edge, the thicker/higher-priority border wins. Priority order: thicker width > `double` > `solid` > `dashed` > `dotted`. If all attributes are equal, the right/bottom cell's border takes precedence.

---

## Rich Text Spans

Style individual words within a cell using Flutter's `TextSpan`:

### Inline Bold, Italic, and Color

```dart
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    // Bold + normal text in one cell
    (0, 0): Cell.text('Total Revenue', richText: const [
      TextSpan(text: 'Total ', style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: 'Revenue'),
    ]),
    // Italic + colored
    (1, 0): Cell.text('Status: Active', richText: const [
      TextSpan(text: 'Status: '),
      TextSpan(
        text: 'Active',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Color(0xFF4CAF50),
        ),
      ),
    ]),
    // Underline + strikethrough
    (2, 0): Cell.text('New Old', richText: const [
      TextSpan(
        text: 'New',
        style: TextStyle(decoration: TextDecoration.underline),
      ),
      TextSpan(text: ' '),
      TextSpan(
        text: 'Old',
        style: TextStyle(decoration: TextDecoration.lineThrough),
      ),
    ]),
  },
);
```

### Setting Rich Text via Data Layer

```dart
data.setRichText(const CellCoordinate(0, 0), const [
  TextSpan(text: 'Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
  TextSpan(text: 'world'),
]);

// Read back
final spans = data.getRichText(const CellCoordinate(0, 0));

// Clear rich text (reverts to plain text rendering)
data.setRichText(const CellCoordinate(0, 0), null);
```

### Inline Editing with Formatting Shortcuts

When editing a cell with `editController`, use keyboard shortcuts to apply inline formatting:

| Key | Action |
|-----|--------|
| Ctrl+B | Toggle bold on selection |
| Ctrl+I | Toggle italic on selection |
| Ctrl+U | Toggle underline on selection |
| Ctrl+Shift+S | Toggle strikethrough on selection |

The `onCommit` callback receives `richText: List<TextSpan>?` with the edited spans.

### Formatting Toolbar with EditController

Build a toolbar that toggles bold/italic/underline/strikethrough during editing, with active-state highlighting:

```dart
Widget buildFormattingToolbar(EditController editController) {
  return ListenableBuilder(
    listenable: editController,
    builder: (context, _) {
      final editing = editController.isEditing;
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.format_bold),
            isSelected: editController.isSelectionBold,
            onPressed: editing ? () {
              editController.toggleBold();
              editController.requestEditorFocus();
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.format_italic),
            isSelected: editController.isSelectionItalic,
            onPressed: editing ? () {
              editController.toggleItalic();
              editController.requestEditorFocus();
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.format_underline),
            isSelected: editController.isSelectionUnderline,
            onPressed: editing ? () {
              editController.toggleUnderline();
              editController.requestEditorFocus();
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.format_strikethrough),
            isSelected: editController.isSelectionStrikethrough,
            onPressed: editing ? () {
              editController.toggleStrikethrough();
              editController.requestEditorFocus();
            } : null,
          ),
        ],
      );
    },
  );
}
```

> **Important:** Call `editController.requestEditorFocus()` after every toolbar
> action that runs while editing. Clicking a toolbar button moves focus away
> from the editor (especially on web, where the browser's native focus follows
> the click). `requestEditorFocus()` schedules a post-frame callback that
> restores focus to the editor and preserves the text selection.
>
> This applies to any button that modifies data while editing — formatting
> toggles, background color, alignment, wrap text, etc. Without it the editor
> loses focus and the user must tap back into the cell.

Alternatively, use Flutter's Actions system from within the widget tree:

```dart
// Inside a descendant of the Worksheet's Actions widget:
Actions.invoke(context, const ToggleBoldIntent());
```

See `example/rich_text.dart` for a complete working example.

---

## Cell Merging

Merge ranges of cells into a single logical cell. For a comprehensive reference on merge behavior, data loss rules, and restrictions, see [CELL_MERGING.md](CELL_MERGING.md).

### Basic Merging

```dart
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    (0, 0): Cell.text('Title Row',
        style: const CellStyle(
          fontWeight: FontWeight.bold,
          textAlignment: CellTextAlignment.center,
        )),
    (2, 0): Cell.text('Region A'),
    (4, 0): Cell.text('Region B'),
  },
);

// Horizontal merge: title spans A1:D1
data.mergeCells(CellRange(0, 0, 0, 3));

// Vertical merge: region labels span two rows
data.mergeCells(CellRange(2, 0, 3, 0));  // A3:A4
data.mergeCells(CellRange(4, 0, 5, 0));  // A5:A6
```

### Unmerging

```dart
// Unmerge by passing any cell in the merged region
data.unmergeCells(const CellCoordinate(0, 0));
```

### Querying Merged Regions

```dart
final registry = data.mergedCells;

// Check if a cell is merged
print(registry.isMerged(const CellCoordinate(0, 1)));  // true (part of A1:D1)

// Get the merge region
final region = registry.getRegion(const CellCoordinate(0, 1));
print(region?.anchor);  // CellCoordinate(0, 0)
print(region?.range);   // CellRange(0, 0, 0, 3)

// Find all merges in a range
final merges = registry.regionsInRange(CellRange(0, 0, 10, 10));
```

### Merge Rules

- The anchor (top-left) cell keeps its value; all other cell values are cleared
- Merging a range that overlaps an existing merge throws `ArgumentError`
- The range must contain at least 2 cells
- Rendering spans the full merged bounds with gridlines suppressed across the interior

See `example/merge.dart` for a complete working example with toolbar buttons.

---

## Multi-Line Text (wrapText)

Enable text wrapping so cell content flows across multiple lines:

### Setting Up Wrapped Cells

```dart
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    // Wrap text with explicit newlines
    (0, 0): Cell.text('Line 1\nLine 2\nLine 3',
        style: const CellStyle(wrapText: true)),
    // Long text that wraps at cell width
    (1, 0): Cell.text(
        'This is a long paragraph that will wrap automatically within the cell bounds.',
        style: const CellStyle(wrapText: true)),
  },
);
```

### Vertical Alignment with Wrapped Text

Control where wrapped text sits within the cell:

```dart
// Top-aligned (default for wrapped text)
data.setStyle(const CellCoordinate(0, 0), const CellStyle(
  wrapText: true,
  verticalAlignment: CellVerticalAlignment.top,
));

// Middle-aligned
data.setStyle(const CellCoordinate(1, 0), const CellStyle(
  wrapText: true,
  verticalAlignment: CellVerticalAlignment.middle,
));

// Bottom-aligned
data.setStyle(const CellCoordinate(2, 0), const CellStyle(
  wrapText: true,
  verticalAlignment: CellVerticalAlignment.bottom,
));
```

### Inserting Newlines During Editing

When a cell has `wrapText: true`, press **Alt+Enter** (Option+Enter on macOS) while editing to insert a newline. Plain Enter still commits the edit.

| Key | Action (wrapText cell) |
|-----|----------------------|
| Alt+Enter | Insert newline at cursor |
| Enter | Commit edit and move down |
| Shift+Enter | Commit edit and move up |

### Taller Rows for Wrapped Content

Increase row height to accommodate wrapped text:

```dart
// Set row height via custom sizes
Worksheet(
  data: data,
  rowCount: 100,
  columnCount: 10,
  customRowHeights: {0: 72, 1: 96},  // Taller rows for wrapped content
)
```

See `example/wrap_text.dart` for a complete working example.

---

## Large Dataset Loading

### Async Data Loading

```dart
class AsyncDataLoader extends StatefulWidget {
  @override
  State<AsyncDataLoader> createState() => _AsyncDataLoaderState();
}

class _AsyncDataLoaderState extends State<AsyncDataLoader> {
  SparseWorksheetData? _data;
  WorksheetController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Simulate fetching data from API
      await Future.delayed(const Duration(seconds: 1));

      final data = SparseWorksheetData(rowCount: 100000, columnCount: 50);

      // Load data in batches to avoid UI freeze
      const batchSize = 1000;
      for (var startRow = 0; startRow < 50000; startRow += batchSize) {
        await Future.microtask(() {
          for (var row = startRow; row < startRow + batchSize && row < 50000; row++) {
            for (var col = 0; col < 10; col++) {
              data[(row, col)] = Cell.number((row * 10 + col).toDouble());
            }
          }
        });

        // Optional: Update loading progress
        // setState(() => _progress = (startRow + batchSize) / 50000);
      }

      if (mounted) {
        setState(() {
          _data = data;
          _controller = WorksheetController();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return WorksheetTheme(
      data: const WorksheetThemeData(),
      child: Worksheet(
        data: _data!,
        controller: _controller!,
        rowCount: 100000,
        columnCount: 50,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _data?.dispose();
    super.dispose();
  }
}
```

### Paginated Loading Pattern

```dart
class PaginatedWorksheet extends StatefulWidget {
  @override
  State<PaginatedWorksheet> createState() => _PaginatedWorksheetState();
}

class _PaginatedWorksheetState extends State<PaginatedWorksheet> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;

  final Set<int> _loadedPages = {};
  static const int _pageSize = 100;  // Rows per page
  static const int _totalRows = 100000;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: _totalRows, columnCount: 26);
    _controller = WorksheetController();

    // Load initial page
    _loadPage(0);

    // Listen for scroll to load more pages
    _controller.verticalScrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrollY = _controller.scrollY;
    final rowHeight = 24.0;  // Default row height

    // Calculate visible row range
    final firstVisibleRow = (scrollY / rowHeight).floor();
    final lastVisibleRow = firstVisibleRow + 50;  // Estimate visible rows

    // Load pages that contain visible rows
    final firstPage = firstVisibleRow ~/ _pageSize;
    final lastPage = lastVisibleRow ~/ _pageSize;

    for (var page = firstPage; page <= lastPage; page++) {
      _loadPage(page);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_loadedPages.contains(page)) return;
    _loadedPages.add(page);

    final startRow = page * _pageSize;
    final endRow = (startRow + _pageSize).clamp(0, _totalRows);

    // Simulate API call
    // final pageData = await api.fetchRows(startRow, endRow);

    // Populate data using bracket access
    for (var row = startRow; row < endRow; row++) {
      _data[(row, 0)] = Cell.text('Row ${row + 1}');
      _data[(row, 1)] = Cell.number(row.toDouble());
    }

    // Trigger repaint
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WorksheetTheme(
      data: const WorksheetThemeData(),
      child: Worksheet(
        data: _data,
        controller: _controller,
        rowCount: _totalRows,
        columnCount: 26,
      ),
    );
  }

  @override
  void dispose() {
    _controller.verticalScrollController.removeListener(_onScroll);
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }
}
```

---

## Keyboard Navigation

Keyboard navigation is built into the `Worksheet` widget automatically. No extra setup is needed — arrow keys, Tab, Enter, and other shortcuts work out of the box:

```dart
// Keyboard navigation works with no extra code
WorksheetTheme(
  data: const WorksheetThemeData(),
  child: Worksheet(
    data: data,
    rowCount: 1000,
    columnCount: 26,
    onEditCell: (cell) {
      // F2 and double-tap trigger this callback
      print('Edit ${cell.toNotation()}');
    },
  ),
)
```

### Built-in Shortcuts

| Key | Action |
|-----|--------|
| Arrow keys | Move selection |
| Shift + Arrow | Extend selection |
| Tab / Shift+Tab | Move right/left |
| Enter / Shift+Enter | Move down/up |
| Home / End | Start/end of row |
| Ctrl+Home / Ctrl+End | Go to A1 / last cell |
| Page Up / Page Down | Move up/down by 10 rows |
| F2 | Edit current cell (via `onEditCell`) |
| Escape | Cancel active drag; or collapse range to single cell |
| Ctrl+A | Select all |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / Cut / Paste |
| Ctrl+D / Ctrl+R | Fill down / Fill right |
| Delete / Backspace | Clear selected cells |
| Ctrl+\ | Clear formatting (keep values) |

All Ctrl shortcuts also work with Cmd on macOS.

Keyboard navigation is disabled when `readOnly: true`.

### Customizing Shortcuts

The worksheet uses Flutter's standard `Shortcuts` / `Actions` pattern. You can override any default binding or add new ones:

```dart
Worksheet(
  data: data,
  rowCount: 1000,
  columnCount: 26,
  // Override specific shortcut bindings
  shortcuts: {
    // Disable Enter navigation
    const SingleActivator(LogicalKeyboardKey.enter):
        const DoNothingAndStopPropagationIntent(),
    // Remap Ctrl+G to go to cell A1
    const SingleActivator(LogicalKeyboardKey.keyG, control: true):
        const GoToCellIntent(CellCoordinate(0, 0)),
  },
  // Override specific action implementations
  actions: {
    // Custom delete behavior
    ClearCellsIntent: CallbackAction<ClearCellsIntent>(
      onInvoke: (_) {
        showDialog(/* confirm before clearing */);
        return null;
      },
    ),
  },
)
```

The full list of default bindings is available in `DefaultWorksheetShortcuts.shortcuts`. Available intents include:

| Intent | Description |
|--------|-------------|
| `MoveSelectionIntent` | Arrow keys, Tab, Enter, Page Up/Down |
| `GoToCellIntent` | Navigate to a specific cell (Ctrl+Home) |
| `GoToLastCellIntent` | Navigate to last cell (Ctrl+End) |
| `GoToRowBoundaryIntent` | Home/End navigation |
| `SelectAllCellsIntent` | Ctrl+A |
| `CancelSelectionIntent` | Escape |
| `EditCellIntent` | F2 |
| `CopyCellsIntent` / `CutCellsIntent` / `PasteCellsIntent` | Clipboard |
| `ClearCellsIntent` | Delete/Backspace |
| `FillDownIntent` / `FillRightIntent` | Ctrl+D / Ctrl+R |

### Programmatic Navigation

You can also move the selection programmatically via the controller:

```dart
controller.moveFocus(
  rowDelta: 1,
  columnDelta: 0,
  extend: false,  // true to extend selection
  maxRow: 999,
  maxColumn: 25,
);
```

---

## Programmatic Scrolling to Cells

```dart
class ScrollingExample extends StatefulWidget {
  @override
  State<ScrollingExample> createState() => _ScrollingExampleState();
}

class _ScrollingExampleState extends State<ScrollingExample> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;

  static const int _rowCount = 100000;
  static const int _columnCount = 100;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: _rowCount, columnCount: _columnCount);
    _controller = WorksheetController();
  }

  /// Scrolls to make a cell visible.
  ///
  /// Uses ensureCellVisible which reads layout and header dimensions
  /// from the Worksheet's internal LayoutSolver automatically.
  void scrollToCell(CellCoordinate cell, {bool animate = true}) {
    final size = context.size;
    if (size == null) return;
    _controller.ensureCellVisible(
      cell,
      viewportSize: size,
      animate: animate,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Scrolls to a specific row/column offset.
  void scrollToOffset(double x, double y, {bool animate = true}) {
    _controller.scrollTo(
      x: x,
      y: y,
      animate: animate,
    );
  }

  /// Go to cell dialog
  void _showGoToDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Go To Cell'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter cell (e.g., A1, B100)',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final notation = controller.text.toUpperCase();
                final cell = _parseNotation(notation);
                if (cell != null) {
                  Navigator.pop(context);
                  _controller.selectCell(cell);
                  scrollToCell(cell);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  CellCoordinate? _parseNotation(String notation) {
    // Parse Excel-style notation (e.g., "A1", "AA100")
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(notation);
    if (match == null) return null;

    final letters = match.group(1)!;
    final number = int.tryParse(match.group(2)!);
    if (number == null || number < 1) return null;

    // Convert letters to column index
    var column = 0;
    for (var i = 0; i < letters.length; i++) {
      column = column * 26 + (letters.codeUnitAt(i) - 64);
    }
    column--;  // Convert to 0-based

    final row = number - 1;  // Convert to 0-based

    if (row >= _rowCount || column >= _columnCount) return null;

    return CellCoordinate(row, column);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrolling Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showGoToDialog,
            tooltip: 'Go to cell (Ctrl+G)',
          ),
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => scrollToCell(const CellCoordinate(0, 0)),
            tooltip: 'Go to start',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () => scrollToCell(
              CellCoordinate(_rowCount - 1, _columnCount - 1),
            ),
            tooltip: 'Go to end',
          ),
        ],
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          controller: _controller,
          rowCount: _rowCount,
          columnCount: _columnCount,
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

---

## Export Data to CSV

```dart
import 'dart:io';

class CsvExporter {
  /// Exports worksheet data to CSV format.
  static String exportToCsv(
    SparseWorksheetData data, {
    required int rowCount,
    required int columnCount,
    String delimiter = ',',
    String lineEnding = '\n',
  }) {
    final buffer = StringBuffer();

    for (var row = 0; row < rowCount; row++) {
      final rowValues = <String>[];

      for (var col = 0; col < columnCount; col++) {
        final value = data.getCell(CellCoordinate(row, col));
        final text = value?.displayValue ?? '';

        // Escape quotes and wrap in quotes if needed
        if (text.contains(delimiter) ||
            text.contains('"') ||
            text.contains('\n')) {
          rowValues.add('"${text.replaceAll('"', '""')}"');
        } else {
          rowValues.add(text);
        }
      }

      buffer.write(rowValues.join(delimiter));
      buffer.write(lineEnding);
    }

    return buffer.toString();
  }

  /// Saves worksheet data to a CSV file.
  static Future<void> saveToFile(
    SparseWorksheetData data, {
    required String filePath,
    required int rowCount,
    required int columnCount,
  }) async {
    final csv = exportToCsv(
      data,
      rowCount: rowCount,
      columnCount: columnCount,
    );
    await File(filePath).writeAsString(csv);
  }
}

// Usage in widget:
void _exportData() async {
  final csv = CsvExporter.exportToCsv(
    _data,
    rowCount: 1000,
    columnCount: 26,
  );

  // Copy to clipboard
  await Clipboard.setData(ClipboardData(text: csv));

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Data copied to clipboard')),
  );
}
```

### Export Selected Range Only

```dart
String exportSelection(
  SparseWorksheetData data,
  CellRange selection,
) {
  final buffer = StringBuffer();

  for (var row = selection.startRow; row <= selection.endRow; row++) {
    final rowValues = <String>[];

    for (var col = selection.startColumn; col <= selection.endColumn; col++) {
      final value = data.getCell(CellCoordinate(row, col));
      final text = value?.displayValue ?? '';

      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        rowValues.add('"${text.replaceAll('"', '""')}"');
      } else {
        rowValues.add(text);
      }
    }

    buffer.writeln(rowValues.join(','));
  }

  return buffer.toString();
}
```

---

## Custom Column Widths

### Auto-Fit Column Width

```dart
class ColumnWidthManager {
  final SparseWorksheetData data;
  final LayoutSolver layoutSolver;
  final Map<int, double> columnWidths = {};

  ColumnWidthManager({
    required this.data,
    required this.layoutSolver,
  });

  /// Calculates optimal width for a column based on content.
  double calculateOptimalWidth(
    int column, {
    required int rowCount,
    double minWidth = 50.0,
    double maxWidth = 500.0,
    double padding = 16.0,
    double fontSize = 14.0,
  }) {
    double maxContentWidth = minWidth;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var row = 0; row < rowCount; row++) {
      final value = data.getCell(CellCoordinate(row, column));
      if (value == null) continue;

      final text = value.displayValue;
      final style = data.getStyle(CellCoordinate(row, column));

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: style?.fontSize ?? fontSize,
          fontWeight: style?.fontWeight ?? FontWeight.normal,
        ),
      );
      textPainter.layout();

      final contentWidth = textPainter.width + padding;
      if (contentWidth > maxContentWidth) {
        maxContentWidth = contentWidth;
      }
    }

    textPainter.dispose();

    return maxContentWidth.clamp(minWidth, maxWidth);
  }

  /// Auto-fits all columns.
  Map<int, double> autoFitAllColumns({
    required int columnCount,
    required int rowCount,
  }) {
    final widths = <int, double>{};

    for (var col = 0; col < columnCount; col++) {
      final width = calculateOptimalWidth(col, rowCount: rowCount);
      if (width != layoutSolver.getColumnWidth(col)) {
        widths[col] = width;
      }
    }

    return widths;
  }
}

// Usage (controller.layoutSolver is the Worksheet's internal solver):
void _autoFitColumn(int column) {
  final solver = _controller.layoutSolver;
  if (solver == null) return;

  final manager = ColumnWidthManager(
    data: _data,
    layoutSolver: solver,
  );

  final optimalWidth = manager.calculateOptimalWidth(
    column,
    rowCount: _rowCount,
  );

  setState(() {
    _customColumnWidths[column] = optimalWidth;
  });
}
```

---

## Cell Value Validation

```dart
typedef CellValidator = String? Function(CellCoordinate cell, CellValue? value);

class ValidatingWorksheetData {
  final SparseWorksheetData _data;
  final Map<int, CellValidator> _columnValidators = {};
  final Map<CellCoordinate, String> _validationErrors = {};

  ValidatingWorksheetData(this._data);

  /// Adds a validator for a column.
  void addColumnValidator(int column, CellValidator validator) {
    _columnValidators[column] = validator;
  }

  /// Sets a cell value with validation.
  bool setCell(CellCoordinate cell, CellValue? value) {
    // Check column validator
    final validator = _columnValidators[cell.column];
    if (validator != null) {
      final error = validator(cell, value);
      if (error != null) {
        _validationErrors[cell] = error;
        return false;
      }
    }

    _validationErrors.remove(cell);
    _data.setCell(cell, value);
    return true;
  }

  /// Gets validation error for a cell.
  String? getError(CellCoordinate cell) => _validationErrors[cell];

  /// Returns all cells with validation errors.
  Iterable<CellCoordinate> get cellsWithErrors => _validationErrors.keys;
}

// Example validators:
String? requiredValidator(CellCoordinate cell, CellValue? value) {
  if (value == null || value.displayValue.isEmpty) {
    return 'This field is required';
  }
  return null;
}

String? numberValidator(CellCoordinate cell, CellValue? value) {
  if (value == null) return null;
  if (!value.isNumber) {
    return 'Must be a number';
  }
  return null;
}

String? rangeValidator(double min, double max) {
  return (CellCoordinate cell, CellValue? value) {
    if (value == null) return null;
    if (!value.isNumber) return 'Must be a number';
    final num = value.asDouble;
    if (num < min || num > max) {
      return 'Must be between $min and $max';
    }
    return null;
  };
}

// Usage:
final validatingData = ValidatingWorksheetData(_data);
validatingData.addColumnValidator(0, requiredValidator);
validatingData.addColumnValidator(1, numberValidator);
validatingData.addColumnValidator(2, rangeValidator(0, 100));
```

---

## Automatic Date Detection

When users type dates into cells, the worksheet automatically detects and stores them as `CellValue.date()` rather than plain text. This works during both editing and clipboard paste.

### Default Behavior

With no configuration, the worksheet recognizes common date formats:

```dart
// These all commit as CellValue.date(), not text
// 2025-01-15          → ISO format
// Jan 15, 2025        → Natural language
// 2025-01-15T10:30:00 → ISO with time
```

### Configuring Date Format Preferences

For locale-specific date parsing (e.g., day/month vs month/day for ambiguous dates like `01/02/2025`), pass a `dateParser`:

```dart
// US format: 01/02/2025 → February 1
Worksheet(
  data: data,
  dateParser: AnyDate.fromLocale('en-US'),
)

// Day-first format: 01/02/2025 → January 2
Worksheet(
  data: data,
  dateParser: AnyDate(info: DateParserInfo(dayFirst: true)),
)

// Default (system locale)
Worksheet(
  data: data,
  dateParser: const AnyDate(),
)
```

`AnyDate` and `DateParserInfo` are re-exported from `package:worksheet/worksheet.dart` — no need for a direct dependency on `any_date`.

### Number vs Date Priority

Numbers are detected before dates. This prevents plain numbers like `42` from being interpreted as UNIX timestamps:

```dart
CellValue.parse('42')         // → number, not a date
CellValue.parse('3.14')       // → number
CellValue.parse('20250115')   // → number (bare digits without separators)
CellValue.parse('2025-01-15') // → date (has separators)
```

### Clipboard Paste Behavior

When pasting from the clipboard, formulas are **not** detected — `=SUM(A1)` is stored as text, not a formula. This prevents accidental formula injection. Dates and other types are still detected normally:

```dart
// Paste "=SUM(A1)"     → text (not formula)
// Paste "2025-01-15"   → date
// Paste "42"           → number
// Paste "TRUE"         → boolean
```

### Using CellValue.parse() Directly

You can use the same parsing logic in your own code:

```dart
// Default parsing
final value = CellValue.parse(userInput);

// No formula detection (like clipboard paste)
final safe = CellValue.parse(userInput, allowFormulas: false);

// Custom date parser
final parser = AnyDate(info: DateParserInfo(dayFirst: true));
final parsed = CellValue.parse(userInput, dateParser: parser);
```

---

## Locale-Aware Formatting

Format numbers and dates with locale-specific separators, currency symbols, and month names:

### Number Formatting with Locale

```dart
// German: period for thousands, comma for decimals, euro symbol
final result = CellFormat.currency.formatRich(
  CellValue.number(1234.56),
  locale: FormatLocale.deDe,
);
// result.text == "1.234,56 €"

// French: space for thousands, comma for decimals
final fr = CellFormat.number.formatRich(
  CellValue.number(1234.56),
  locale: FormatLocale.frFr,
);
// fr.text == "1 234,56"
```

### Date Format Auto-Detection

When a user types a date, the format is preserved automatically:

```dart
Worksheet(
  data: data,
  formatLocale: FormatLocale.enUs,  // US: month/day/year
)
// User types "1/15/2024" → displayed as "1/15/2024" (not "2024-01-15")
// User types "15-Jan-24" → displayed as "15-Jan-24"
// User types "2024-01-15" → displayed as "2024-01-15"
```

For UK/European date ordering:

```dart
Worksheet(
  data: data,
  formatLocale: FormatLocale.enGb,  // UK: day/month/year
)
// User types "15/1/2024" → detected as d/m/yyyy, displayed as "15/1/2024"
```

### Conditional Format Codes with Colors

Use Excel-style conditional sections and color codes:

```dart
// Red for negative, blue for positive
const colorFormat = CellFormat(
  type: CellFormatType.custom,
  formatCode: '[Blue]#,##0.00;[Red]-#,##0.00',
);

final positive = colorFormat.formatRich(CellValue.number(42));
// positive.text == "42.00", positive.color == Color(0xFF0000FF)

final negative = colorFormat.formatRich(CellValue.number(-42));
// negative.text == "-42.00", negative.color == Color(0xFFFF0000)

// Conditional thresholds
const threshold = CellFormat(
  type: CellFormatType.custom,
  formatCode: '[Red][<0]#,##0;[Green][>1000]#,##0;#,##0',
);
```

### Available FormatLocale Presets

| Locale | Example Number | Example Currency |
|--------|---------------|-----------------|
| `FormatLocale.enUs` | `1,234.56` | `$1,234.56` |
| `FormatLocale.enGb` | `1,234.56` | `£1,234.56` |
| `FormatLocale.deDe` | `1.234,56` | `1.234,56 €` |
| `FormatLocale.frFr` | `1 234,56` | `1 234,56 €` |
| `FormatLocale.jaJp` | `1,234.56` | `¥1,234.56` |
| `FormatLocale.zhCn` | `1,234.56` | `¥1,234.56` |

---

## Multi-Select Resize

When multiple rows or columns are selected, resizing one applies to all:

```dart
// This is built into the Worksheet widget!
// When you drag-resize a row/column header border,
// and multiple rows/columns are selected,
// the new size is applied to all selected rows/columns.

// The behavior is automatic when using:
Worksheet(
  data: _data,
  controller: _controller,
  onResizeRow: (row, newHeight) {
    // Called during resize with current height
    print('Resizing row $row to $newHeight');
  },
  onResizeColumn: (column, newWidth) {
    // Called during resize with current width
    print('Resizing column $column to $newWidth');
  },
)

// To resize multiple rows/columns programmatically, use the
// controller's layoutSolver (attached by the Worksheet widget):
void resizeSelectedRows(double newHeight) {
  final selection = _controller.selectedRange;
  final solver = _controller.layoutSolver;
  if (selection == null || solver == null) return;

  for (var row = selection.startRow; row <= selection.endRow; row++) {
    solver.setRowHeight(row, newHeight);
  }

  // Rebuild widget to apply changes
  setState(() {});
}

void resizeSelectedColumns(double newWidth) {
  final selection = _controller.selectedRange;
  final solver = _controller.layoutSolver;
  if (selection == null || solver == null) return;

  for (var col = selection.startColumn; col <= selection.endColumn; col++) {
    solver.setColumnWidth(col, newWidth);
  }

  setState(() {});
}
```

---

## Mobile Mode

Configure how the worksheet handles touch input on mobile devices.

### Auto-Detection (Default)

By default, the widget auto-detects the platform and enables mobile mode on iOS/Android:

```dart
// Auto-detect: mobile on iOS/Android, desktop on macOS/Windows/Linux
Worksheet(
  data: data,
  rowCount: 100,
  columnCount: 26,
)
```

### Force Mobile Mode

Force mobile mode on desktop for testing, or force desktop mode on mobile:

```dart
// Force mobile mode (useful for testing touch gestures on desktop)
Worksheet(
  data: data,
  rowCount: 100,
  columnCount: 26,
  mobileMode: true,
)

// Force desktop mode on a mobile device
Worksheet(
  data: data,
  rowCount: 100,
  columnCount: 26,
  mobileMode: false,
)
```

### What Mobile Mode Changes

| Feature | Desktop Mode | Mobile Mode |
|---------|-------------|-------------|
| **Scrolling** | Mouse wheel / scrollbar | One-finger swipe |
| **Zooming** | Ctrl+scroll (if wired) | Pinch-to-zoom |
| **Selection handles** | Hidden | Circles at TL/BR corners |
| **Fill handle** | Visible (corner square) | Hidden |
| **Hit targets** | 4px tolerance | 12px tolerance |
| **Mouse cursors** | Active (cell, grab, resize) | Disabled |
| **Long-press** | N/A | Drag-to-move cells |

For the complete touch interaction reference, see [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md). For desktop cursor behavior, see [MOUSE_CURSOR.md](MOUSE_CURSOR.md).
