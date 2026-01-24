# API Reference

Quick reference for the worksheet widget API.

## Table of Contents

1. [WorksheetController](#worksheetcontroller)
2. [Callback Signatures](#callback-signatures)
3. [CellValue Types](#cellvalue-types)
4. [CellStyle Properties](#cellstyle-properties)
5. [Selection Types](#selection-types)
6. [Theme Classes](#theme-classes)
7. [Event Streams](#event-streams)
8. [Core Models](#core-models)

---

## WorksheetController

Central controller for programmatic worksheet interaction.

### Constructor

```dart
WorksheetController({
  SelectionController? selectionController,
  ZoomController? zoomController,
  ScrollController? horizontalScrollController,
  ScrollController? verticalScrollController,
})
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `selectionController` | `SelectionController` | Manages cell selection state |
| `zoomController` | `ZoomController` | Manages zoom level (0.1-4.0) |
| `horizontalScrollController` | `ScrollController` | Horizontal scroll control |
| `verticalScrollController` | `ScrollController` | Vertical scroll control |
| `selectedRange` | `CellRange?` | Current selection range |
| `focusCell` | `CellCoordinate?` | Active cell (focus) |
| `hasSelection` | `bool` | Whether any selection exists |
| `selectionMode` | `SelectionMode` | Current selection mode |
| `zoom` | `double` | Current zoom level (1.0 = 100%) |
| `scrollX` | `double` | Horizontal scroll offset |
| `scrollY` | `double` | Vertical scroll offset |

### Selection Methods

```dart
/// Selects a single cell
void selectCell(CellCoordinate cell)

/// Selects a range of cells
void selectRange(CellRange range)

/// Selects an entire row
void selectRow(int row, {required int columnCount})

/// Selects an entire column
void selectColumn(int column, {required int rowCount})

/// Clears the selection
void clearSelection()

/// Moves the focus cell
void moveFocus({
  required int rowDelta,
  required int columnDelta,
  bool extend = false,
  int maxRow = 999999,
  int maxColumn = 999999,
})
```

### Zoom Methods

```dart
/// Sets the zoom level (0.1 to 4.0)
void setZoom(double value)

/// Zooms in by one step
void zoomIn()

/// Zooms out by one step
void zoomOut()

/// Resets zoom to 100%
void resetZoom()
```

### Scroll Methods

```dart
/// Scrolls to make a cell visible
void scrollToCell(
  CellCoordinate cell, {
  required double Function(int row) getRowTop,
  required double Function(int column) getColumnLeft,
  required double Function(int row) getRowHeight,
  required double Function(int column) getColumnWidth,
  required Size viewportSize,
  required double headerWidth,
  required double headerHeight,
  bool animate = false,
  Duration duration = const Duration(milliseconds: 200),
  Curve curve = Curves.easeInOut,
})

/// Scrolls to a specific offset
void scrollTo({
  double? x,
  double? y,
  bool animate = false,
  Duration duration = const Duration(milliseconds: 200),
  Curve curve = Curves.easeInOut,
})
```

### Lifecycle

```dart
/// Disposes all controllers
void dispose()
```

---

## Callback Signatures

### Worksheet Widget Callbacks

```dart
/// Called when a cell should enter edit mode (double-tap)
typedef OnEditCellCallback = void Function(CellCoordinate cell);

/// Called when a cell is tapped
typedef OnCellTapCallback = void Function(CellCoordinate cell);

/// Called when a row is resized
typedef OnResizeRowCallback = void Function(int row, double newHeight);

/// Called when a column is resized
typedef OnResizeColumnCallback = void Function(int column, double newWidth);
```

### EditController Callbacks

```dart
/// Called when edit is committed
typedef OnCommitCallback = void Function(CellCoordinate cell, CellValue? value);

/// Called when edit is cancelled
typedef OnCancelCallback = void Function();
```

### Usage Example

```dart
Worksheet(
  data: data,
  controller: controller,
  onEditCell: (CellCoordinate cell) {
    // Handle edit start
    print('Editing ${cell.toNotation()}');
  },
  onCellTap: (CellCoordinate cell) {
    // Handle cell tap
    print('Tapped ${cell.toNotation()}');
  },
  onResizeRow: (int row, double newHeight) {
    // Handle row resize
    print('Row $row now ${newHeight}px');
  },
  onResizeColumn: (int column, double newWidth) {
    // Handle column resize
    print('Column $column now ${newWidth}px');
  },
)
```

---

## CellValue Types

### CellValueType Enum

```dart
enum CellValueType {
  text,     // String content
  number,   // Numeric value (double)
  boolean,  // true/false
  formula,  // Formula string (not evaluated)
  error,    // Error message
  date,     // DateTime value
}
```

### Constructors

```dart
// Text value
CellValue.text(String value)

// Numeric value
CellValue.number(num value)

// Boolean value
CellValue.boolean(bool value)

// Formula (stored, not evaluated)
CellValue.formula(String formula)

// Error value
CellValue.error(String error)

// Date value
CellValue.date(DateTime date)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `CellValueType` | The type of value |
| `rawValue` | `Object` | The underlying value |
| `displayValue` | `String` | Formatted string for display |
| `isText` | `bool` | True if text type |
| `isNumber` | `bool` | True if number type |
| `isBoolean` | `bool` | True if boolean type |
| `isFormula` | `bool` | True if formula type |
| `isError` | `bool` | True if error type |
| `isDate` | `bool` | True if date type |
| `isInteger` | `bool` | True if number with no decimals |

### Type-Specific Accessors

```dart
int get asInt        // For number types
double get asDouble  // For number types
DateTime get asDateTime  // For date types
```

### Examples

```dart
final text = CellValue.text('Hello');
print(text.displayValue);  // "Hello"

final number = CellValue.number(42.5);
print(number.displayValue);  // "42.5"
print(number.isNumber);  // true
print(number.asDouble);  // 42.5

final integer = CellValue.number(42);
print(integer.isInteger);  // true
print(integer.asInt);  // 42

final boolean = CellValue.boolean(true);
print(boolean.displayValue);  // "TRUE"

final date = CellValue.date(DateTime(2024, 1, 15));
print(date.displayValue);  // "2024-01-15"

final error = CellValue.error('#DIV/0!');
print(error.displayValue);  // "#DIV/0!"
```

---

## CellStyle Properties

### Full Property List

```dart
const CellStyle({
  Color? backgroundColor,
  String? fontFamily,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  Color? textColor,
  CellTextAlignment? textAlignment,
  CellVerticalAlignment? verticalAlignment,
  CellBorders? borders,
  bool? wrapText,
  String? numberFormat,
})
```

### Property Details

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `backgroundColor` | `Color?` | null (transparent) | Cell background color |
| `fontFamily` | `String?` | null (uses theme) | Font family name |
| `fontSize` | `double?` | null (uses theme) | Font size in pixels |
| `fontWeight` | `FontWeight?` | null (normal) | Font weight |
| `fontStyle` | `FontStyle?` | null (normal) | Normal or italic |
| `textColor` | `Color?` | null (uses theme) | Text color |
| `textAlignment` | `CellTextAlignment?` | null (left) | Horizontal alignment |
| `verticalAlignment` | `CellVerticalAlignment?` | null (middle) | Vertical alignment |
| `borders` | `CellBorders?` | null (no borders) | Cell border configuration |
| `wrapText` | `bool?` | null (false) | Enable text wrapping |
| `numberFormat` | `String?` | null | Number format pattern |

### CellTextAlignment Enum

```dart
enum CellTextAlignment {
  left,
  center,
  right,
}
```

### CellVerticalAlignment Enum

```dart
enum CellVerticalAlignment {
  top,
  middle,
  bottom,
}
```

### CellBorders Class

```dart
const CellBorders({
  BorderStyle top = BorderStyle.none,
  BorderStyle right = BorderStyle.none,
  BorderStyle bottom = BorderStyle.none,
  BorderStyle left = BorderStyle.none,
})

// All sides same style
const CellBorders.all(BorderStyle style)
```

### BorderStyle Class

```dart
const BorderStyle({
  Color color = const Color(0xFF000000),
  double width = 1.0,
})

static const BorderStyle none = BorderStyle(width: 0)
```

### Methods

```dart
// Merge styles (other takes precedence)
CellStyle merge(CellStyle? other)

// Create modified copy
CellStyle copyWith({...})
```

### Examples

```dart
// Bold header with blue background
const headerStyle = CellStyle(
  backgroundColor: Color(0xFF4472C4),
  textColor: Color(0xFFFFFFFF),
  fontWeight: FontWeight.bold,
  textAlignment: CellTextAlignment.center,
);

// Right-aligned currency
const currencyStyle = CellStyle(
  textAlignment: CellTextAlignment.right,
  numberFormat: '\$#,##0.00',
);

// Cell with bottom border
const bottomBorderStyle = CellStyle(
  borders: CellBorders(
    bottom: BorderStyle(color: Color(0xFF000000), width: 2.0),
  ),
);

// Merge styles
final combined = headerStyle.merge(bottomBorderStyle);
```

---

## Selection Types

### SelectionMode Enum

```dart
enum SelectionMode {
  cell,    // Single cell selected
  range,   // Multiple cells selected
  row,     // Entire row(s) selected
  column,  // Entire column(s) selected
  none,    // No selection
}
```

### CellRange Class

```dart
// Constructor (normalizes coordinates)
const CellRange(
  int startRow,
  int startColumn,
  int endRow,
  int endColumn,
)

// Single cell range
factory CellRange.single(CellCoordinate cell)
```

### CellRange Properties

| Property | Type | Description |
|----------|------|-------------|
| `startRow` | `int` | First row (normalized) |
| `startColumn` | `int` | First column (normalized) |
| `endRow` | `int` | Last row (normalized) |
| `endColumn` | `int` | Last column (normalized) |
| `rowCount` | `int` | Number of rows in range |
| `columnCount` | `int` | Number of columns in range |
| `cellCount` | `int` | Total cells in range |
| `isSingleCell` | `bool` | True if only one cell |

### CellRange Methods

```dart
bool contains(CellCoordinate cell)
```

### CellCoordinate Class

```dart
const CellCoordinate(int row, int column)
```

### CellCoordinate Properties

| Property | Type | Description |
|----------|------|-------------|
| `row` | `int` | Zero-based row index |
| `column` | `int` | Zero-based column index |

### CellCoordinate Methods

```dart
// Convert to Excel notation (e.g., "A1", "AA100")
String toNotation()

// Create modified copy
CellCoordinate copyWith({int? row, int? column})
```

---

## Theme Classes

### WorksheetThemeData

```dart
const WorksheetThemeData({
  SelectionStyle selectionStyle,
  HeaderStyle headerStyle,
  Color gridlineColor,
  double gridlineWidth,
  Color cellBackgroundColor,
  Color textColor,
  double fontSize,
  String fontFamily,
  double rowHeaderWidth,
  double columnHeaderHeight,
  double defaultRowHeight,
  double defaultColumnWidth,
  double cellPadding,
  bool showGridlines,
  bool showHeaders,
})
```

### SelectionStyle

```dart
const SelectionStyle({
  Color fillColor,           // Selection fill
  Color borderColor,         // Selection border
  double borderWidth,
  Color focusFillColor,      // Focus cell fill
  Color focusBorderColor,    // Focus cell border
  double focusBorderWidth,
})
```

### HeaderStyle

```dart
const HeaderStyle({
  Color backgroundColor,
  Color selectedBackgroundColor,
  Color textColor,
  Color selectedTextColor,
  Color borderColor,
  double borderWidth,
  double fontSize,
  FontWeight fontWeight,
  String fontFamily,
})
```

### WorksheetTheme (InheritedWidget)

```dart
// Wrap widget tree
WorksheetTheme(
  data: WorksheetThemeData(...),
  child: Worksheet(...),
)

// Access in descendants
static WorksheetThemeData of(BuildContext context)
static WorksheetThemeData? maybeOf(BuildContext context)
```

---

## Event Streams

### DataChangeEvent

Emitted when worksheet data changes:

```dart
abstract class DataChangeEvent {}

class CellChangedEvent extends DataChangeEvent {
  final CellCoordinate cell;
  final CellValue? oldValue;
  final CellValue? newValue;
}

class RangeChangedEvent extends DataChangeEvent {
  final CellRange range;
}

class StyleChangedEvent extends DataChangeEvent {
  final CellCoordinate cell;
  final CellStyle? oldStyle;
  final CellStyle? newStyle;
}
```

### Listening to Changes

```dart
final data = SparseWorksheetData(rowCount: 100, columnCount: 26);

// Listen to data changes
data.changes.listen((event) {
  if (event is CellChangedEvent) {
    print('Cell ${event.cell.toNotation()} changed');
    print('  Old: ${event.oldValue?.displayValue}');
    print('  New: ${event.newValue?.displayValue}');
  }
});
```

---

## Core Models

### SpanList

Manages row/column dimensions with O(log n) lookups:

```dart
SpanList({
  required int count,
  required double defaultSize,
  Map<int, double>? customSizes,
})
```

| Method | Return | Description |
|--------|--------|-------------|
| `sizeAt(int index)` | `double` | Size at index |
| `positionAt(int index)` | `double` | Cumulative position |
| `indexAtPosition(double pos)` | `int` | Index at position |
| `setSize(int index, double size)` | `void` | Update size |
| `getVisibleRange(scrollOffset, viewportSize)` | `SpanRange` | Visible indices |

### SpanRange

```dart
class SpanRange {
  final int startIndex;
  final int endIndex;
}
```

### LayoutSolver

Combines row and column SpanLists:

```dart
LayoutSolver({
  required SpanList rows,
  required SpanList columns,
})
```

| Method | Return | Description |
|--------|--------|-------------|
| `getCellBounds(CellCoordinate)` | `Rect` | Cell rectangle |
| `getCellAt(Offset)` | `CellCoordinate` | Cell at position |
| `getRowTop(int row)` | `double` | Row Y position |
| `getColumnLeft(int column)` | `double` | Column X position |
| `getRowHeight(int row)` | `double` | Row height |
| `getColumnWidth(int column)` | `double` | Column width |
| `setRowHeight(int row, double)` | `void` | Update row height |
| `setColumnWidth(int column, double)` | `void` | Update column width |
| `getVisibleRows(scrollY, height)` | `SpanRange` | Visible row indices |
| `getVisibleColumns(scrollX, width)` | `SpanRange` | Visible column indices |
| `getRangeBounds(startRow, startColumn, endRow, endColumn)` | `Rect` | Range rectangle |

### TileConfig

```dart
const TileConfig({
  int tileSize = 256,
  int maxCachedTiles = 100,
  int prefetchRings = 1,
})
```

### ZoomBucket Enum

```dart
enum ZoomBucket {
  tenth,     // 10-24%
  quarter,   // 25-39%
  forty,     // 40-49%
  half,      // 50-99%
  full,      // 100-199%
  twoX,      // 200-299%
  quadruple, // 300-400%
}
```

---

## Quick Reference Card

### Creating a Worksheet

```dart
// 1. Create data source
final data = SparseWorksheetData(rowCount: 1000, columnCount: 26);

// 2. Create controller
final controller = WorksheetController();

// 3. Build widget
WorksheetTheme(
  data: WorksheetThemeData(...),
  child: Worksheet(
    data: data,
    controller: controller,
    rowCount: 1000,
    columnCount: 26,
    onEditCell: (cell) { /* handle edit */ },
    onCellTap: (cell) { /* handle tap */ },
  ),
)

// 4. Dispose when done
@override
void dispose() {
  controller.dispose();
  data.dispose();
  super.dispose();
}
```

### Common Operations

```dart
// Set cell value
data.setCell(CellCoordinate(0, 0), CellValue.text('Hello'));

// Get cell value
final value = data.getCell(CellCoordinate(0, 0));

// Set cell style
data.setStyle(CellCoordinate(0, 0), CellStyle(fontWeight: FontWeight.bold));

// Select cell
controller.selectCell(CellCoordinate(5, 3));

// Select range
controller.selectRange(CellRange(0, 0, 10, 5));

// Navigate
controller.moveFocus(rowDelta: 1, columnDelta: 0, maxRow: 999, maxColumn: 25);

// Zoom
controller.setZoom(1.5);  // 150%

// Scroll
controller.scrollTo(x: 500, y: 1000, animate: true);

// Clear selection
controller.clearSelection();
```
