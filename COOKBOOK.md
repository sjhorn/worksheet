# Worksheet Widget Cookbook

Practical recipes for common worksheet tasks.

## Table of Contents

1. [Read-Only Spreadsheet Viewer](#read-only-spreadsheet-viewer)
2. [Editable Data Grid with Persistence](#editable-data-grid-with-persistence)
3. [Number Formatting](#number-formatting)
4. [Custom Cell Styling (Conditional Formatting)](#custom-cell-styling-conditional-formatting)
5. [Cell Borders](#cell-borders)
6. [Large Dataset Loading](#large-dataset-loading)
7. [Keyboard Navigation](#keyboard-navigation)
8. [Programmatic Scrolling to Cells](#programmatic-scrolling-to-cells)
9. [Export Data to CSV](#export-data-to-csv)
10. [Custom Column Widths](#custom-column-widths)
11. [Cell Value Validation](#cell-value-validation)
12. [Automatic Date Detection](#automatic-date-detection)
13. [Multi-Select Resize](#multi-select-resize)

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

  void _onCommit(CellCoordinate cell, CellValue? value) {
    setState(() {
      _data.setCell(cell, value);
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
| `CellFormat.dateMonthYear` | `Jan-24` |
| `CellFormat.time24` | `14:30` |
| `CellFormat.time24Seconds` | `14:30:05` |
| `CellFormat.time12` | `2:30 PM` |
| `CellFormat.text` | `hello` |
| `CellFormat.fraction` | `3 1/2` |

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
| Escape | Collapse range to single cell |
| Ctrl+A | Select all |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / Cut / Paste |
| Ctrl+D / Ctrl+R | Fill down / Fill right |
| Delete / Backspace | Clear selected cells |

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
