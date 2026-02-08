# API Reference

Quick reference for the worksheet widget API.

## Table of Contents

1. [WorksheetController](#worksheetcontroller)
2. [Callback Signatures](#callback-signatures)
3. [CellValue Types](#cellvalue-types)
4. [CellFormat](#cellformat)
5. [CellStyle Properties](#cellstyle-properties)
6. [Selection Types](#selection-types)
7. [Theme Classes](#theme-classes)
8. [Event Streams](#event-streams)
9. [Core Models](#core-models)

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
| `hasLayout` | `bool` | Whether layout info is attached (true after widget builds) |
| `layoutSolver` | `LayoutSolver?` | The authoritative layout solver, or null before attach |
| `headerWidth` | `double` | Header width in worksheet coordinates |
| `headerHeight` | `double` | Header height in worksheet coordinates |

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

### Layout Methods

Once the `Worksheet` widget has built, it attaches its internal `LayoutSolver`
to the controller. These methods use that attached layout:

```dart
/// Returns the screen-space bounds of a cell, accounting for
/// zoom, scroll offset, and headers. Returns null if layout
/// is not yet attached.
Rect? getCellScreenBounds(CellCoordinate cell)

/// Scrolls to ensure a cell is visible (simplified version of
/// scrollToCell that uses the attached layout).
/// Does nothing if layout is not attached.
void ensureCellVisible(
  CellCoordinate cell, {
  required Size viewportSize,
  bool animate = true,
  Duration duration = const Duration(milliseconds: 200),
  Curve curve = Curves.easeInOut,
})
```

**Example — positioning a cell editor overlay:**
```dart
void _onEditCell(CellCoordinate cell) {
  final bounds = _controller.getCellScreenBounds(cell);
  if (bounds == null) return;

  setState(() => _editingCellBounds = bounds);

  _editController.startEdit(
    cell: cell,
    currentValue: _data.getCell(cell),
    trigger: EditTrigger.doubleTap,
  );
}
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

### Worksheet Date Parsing

The `Worksheet` widget accepts a `dateParser` parameter that configures date
detection for both cell editing and clipboard paste:

```dart
Worksheet(
  data: data,
  // System defaults — handles ISO 8601 and common formats
  dateParser: const AnyDate(),

  // US format — month/day/year for ambiguous dates
  dateParser: AnyDate.fromLocale('en-US'),

  // Day-first format
  dateParser: AnyDate(info: DateParserInfo(dayFirst: true)),
)
```

`AnyDate` and `DateParserInfo` are re-exported from `worksheet.dart`, so no
direct `any_date` dependency is needed.

When `dateParser` is null (the default), `const AnyDate()` is used. When a
custom `clipboardSerializer` is provided, it is used as-is and `dateParser`
only affects editing.

---

## Keyboard Shortcuts (Intents / Actions)

The worksheet uses Flutter's `Shortcuts` / `Actions` pattern. All keyboard handling is expressed as Intent + Action pairs, making every shortcut overridable.

### Worksheet Shortcut Parameters

```dart
Worksheet(
  // Override or add shortcut bindings (merged on top of defaults)
  shortcuts: Map<ShortcutActivator, Intent>?,

  // Override action implementations (merged on top of defaults)
  actions: Map<Type, Action<Intent>>?,
)
```

### Intent Classes

| Intent | Parameters | Default Binding |
|--------|-----------|-----------------|
| `MoveSelectionIntent` | `rowDelta`, `columnDelta`, `extend` | Arrow keys, Tab, Enter, Page Up/Down |
| `GoToCellIntent` | `coordinate` | Ctrl+Home (→ A1) |
| `GoToLastCellIntent` | — | Ctrl+End |
| `GoToRowBoundaryIntent` | `end`, `extend` | Home, End, Shift+Home, Shift+End |
| `SelectAllCellsIntent` | — | Ctrl+A |
| `CancelSelectionIntent` | — | Escape |
| `EditCellIntent` | — | F2 |
| `CopyCellsIntent` | — | Ctrl+C |
| `CutCellsIntent` | — | Ctrl+X |
| `PasteCellsIntent` | — | Ctrl+V |
| `ClearCellsIntent` | `clearValue`, `clearStyle`, `clearFormat` | Delete, Backspace, Ctrl+\ |
| `FillDownIntent` | — | Ctrl+D |
| `FillRightIntent` | — | Ctrl+R |

### ClearCellsIntent Flags

`ClearCellsIntent` supports selective clearing via three boolean flags (all default to `true`):

```dart
// Clear everything (default — Delete/Backspace)
const ClearCellsIntent()

// Clear formatting only, keep values (Ctrl+\)
const ClearCellsIntent(clearValue: false, clearStyle: true, clearFormat: true)

// Clear values only, keep formatting
const ClearCellsIntent(clearValue: true, clearStyle: false, clearFormat: false)
```

| Flag | What it clears |
|------|---------------|
| `clearValue` | Cell values (text, numbers, dates, etc.) |
| `clearStyle` | Cell styles (background, font, alignment, borders) |
| `clearFormat` | Cell formats (number format, date format, etc.) |

### WorksheetActionContext

Actions receive dependencies through `WorksheetActionContext` (implemented by the widget state):

```dart
abstract class WorksheetActionContext {
  SelectionController get selectionController;
  int get maxRow;
  int get maxColumn;
  WorksheetData get worksheetData;
  ClipboardHandler get clipboardHandler;
  bool get readOnly;
  void Function(CellCoordinate)? get onEditCell;
  void ensureSelectionVisible();
  void invalidateAndRebuild();
}
```

### DefaultWorksheetShortcuts

`DefaultWorksheetShortcuts.shortcuts` provides ~44 default bindings. Both `control:` and `meta:` variants are included for cross-platform support.

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
  text,      // String content
  number,    // Numeric value (double)
  boolean,   // true/false
  formula,   // Formula string (not evaluated)
  error,     // Error message
  date,      // DateTime value
  duration,  // Duration value
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

// Duration value
CellValue.duration(Duration duration)
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
| `isDuration` | `bool` | True if duration type |
| `isInteger` | `bool` | True if number with no decimals |

### Type-Specific Accessors

```dart
int get asInt            // For number types
double get asDouble      // For number types
DateTime get asDateTime  // For date types
Duration get asDuration  // For duration types
```

### Parsing Text into CellValue

`CellValue.parse()` detects the type from a text string. Used internally by
`EditController` and `TsvClipboardSerializer`, but also available for direct use.

```dart
static CellValue? parse(
  String text, {
  bool allowFormulas = true,
  AnyDate? dateParser,
})
```

**Detection order**: empty → formula → boolean → number → date → text.

Numbers are checked before dates because `any_date` interprets plain numbers
as UNIX timestamps (e.g. `"42"` would become 1970-01-01).

| Input | Result |
|-------|--------|
| `''` / `'   '` | `null` |
| `'=SUM(A1:A5)'` | `CellValue.formula('=SUM(A1:A5)')` |
| `'TRUE'` / `'true'` | `CellValue.boolean(true)` |
| `'42'` | `CellValue.number(42)` |
| `'3.14'` | `CellValue.number(3.14)` |
| `'2025-01-15'` | `CellValue.date(DateTime(2025, 1, 15))` |
| `'Jan 15, 2025'` | `CellValue.date(DateTime(2025, 1, 15))` |
| `'hello'` | `CellValue.text('hello')` |

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `allowFormulas` | `true` | Set to `false` for clipboard paste to prevent `=` prefix being treated as a formula |
| `dateParser` | `const AnyDate()` | Configures date format detection. Use `AnyDate.fromLocale('en-US')` for US dates, or `AnyDate(info: DateParserInfo(dayFirst: true))` for day-first formats |

```dart
// Default parsing
CellValue.parse('2025-01-15')  // → date
CellValue.parse('42')          // → number (not a date)
CellValue.parse('TRUE')        // → boolean

// Clipboard mode (no formulas)
CellValue.parse('=SUM(A1)', allowFormulas: false)  // → text

// Custom date format
final parser = AnyDate(info: DateParserInfo(dayFirst: true));
CellValue.parse('15/01/2025', dateParser: parser)  // → date (Jan 15)
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

final duration = CellValue.duration(Duration(hours: 1, minutes: 30, seconds: 5));
print(duration.displayValue);  // "1:30:05"

final error = CellValue.error('#DIV/0!');
print(error.displayValue);  // "#DIV/0!"
```

---

## Cell Class

Combines a `CellValue` and `CellStyle` into a single object for Map-like access on `SparseWorksheetData`.

### Constructors

```dart
// General constructor
const Cell({CellValue? value, CellStyle? style})

// Typed constructors
Cell.text(String text, {CellStyle? style})
Cell.number(num n, {CellStyle? style})
Cell.boolean(bool b, {CellStyle? style})
Cell.formula(String formula, {CellStyle? style})
Cell.date(DateTime date, {CellStyle? style})
Cell.duration(Duration duration, {CellStyle? style})
Cell.withStyle(CellStyle style)  // style only, no value
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `CellValue?` | The cell's value |
| `style` | `CellStyle?` | The cell's style |
| `hasValue` | `bool` | Whether the cell has a value |
| `hasStyle` | `bool` | Whether the cell has a style |
| `isEmpty` | `bool` | True if no value and no style |

### Extensions

Convenience `.cell` getter on core Dart types for quick cell creation:

```dart
// WorksheetString (on String)
'Hello'.cell           // Cell.text('Hello')
'=SUM(A1:A10)'.formula // Cell.formula('=SUM(A1:A10)')

// WorksheetNum (on num)
42.cell                // Cell.number(42)
3.14.cell              // Cell.number(3.14)

// WorksheetBool (on bool)
true.cell              // Cell.boolean(true)

// WorksheetDate (on DateTime)
DateTime.now().cell    // Cell.date(DateTime.now())

// WorksheetDuration (on Duration)
Duration(hours: 1).cell  // Cell.duration(Duration(hours: 1))
```

### SparseWorksheetData Map-like API

```dart
// Construction with (row, col) record keys
final data = SparseWorksheetData(
  rowCount: 100,
  columnCount: 10,
  cells: {
    (0, 0): 'Name'.cell,
    (0, 1): 42.cell,
  },
);

// Bracket read/write using (row, col) records
data[(1, 0)] = Cell.text('Apples');
final cell = data[(0, 0)];  // Cell?
data[(1, 0)] = null;         // clears value and style

// Snapshot of all populated cells
final allCells = data.cells;  // Map<CellCoordinate, Cell>
```

---

## CellFormat

Controls how cell values are displayed using Excel-style format codes. Format lives on `Cell`, not `CellStyle`.

### CellFormatType Enum

```dart
enum CellFormatType {
  general,     // Default display
  number,      // Numeric with decimals/thousands
  currency,    // Monetary values with symbol
  accounting,  // Aligned currency/decimals
  date,        // Date display
  time,        // Time display
  percentage,  // Multiply by 100, append %
  fraction,    // Display as fraction (1/2, 3/4)
  scientific,  // Exponential notation
  text,        // Plain text pass-through
  special,     // Phone numbers, postal codes
  duration,    // Elapsed time ([h]:mm:ss)
  custom,      // User-defined format code
}
```

### CellFormat Class

```dart
const CellFormat({required CellFormatType type, required String formatCode})
```

### Built-in Presets

| Preset | Format Code | Example Input | Example Output |
|--------|-------------|---------------|----------------|
| `CellFormat.general` | `General` | `42` | `42` |
| `CellFormat.integer` | `#,##0` | `1234` | `1,234` |
| `CellFormat.decimal` | `0.00` | `3.1` | `3.10` |
| `CellFormat.number` | `#,##0.00` | `1234.5` | `1,234.50` |
| `CellFormat.currency` | `$#,##0.00` | `1234.5` | `$1,234.50` |
| `CellFormat.percentage` | `0%` | `0.42` | `42%` |
| `CellFormat.percentageDecimal` | `0.00%` | `0.4256` | `42.56%` |
| `CellFormat.scientific` | `0.00E+00` | `12345` | `1.23E+04` |
| `CellFormat.dateIso` | `yyyy-MM-dd` | `2024-01-15` | `2024-01-15` |
| `CellFormat.dateUs` | `m/d/yyyy` | `2024-01-15` | `1/15/2024` |
| `CellFormat.dateShort` | `d-mmm-yy` | `2024-01-15` | `15-Jan-24` |
| `CellFormat.dateMonthYear` | `mmm-yy` | `2024-01-15` | `Jan-24` |
| `CellFormat.time24` | `H:mm` | `14:30` | `14:30` |
| `CellFormat.time24Seconds` | `H:mm:ss` | `14:30:05` | `14:30:05` |
| `CellFormat.time12` | `h:mm AM/PM` | `14:30` | `2:30 PM` |
| `CellFormat.text` | `@` | `hello` | `hello` |
| `CellFormat.fraction` | `# ?/?` | `3.5` | `3 1/2` |
| `CellFormat.duration` | `[h]:mm:ss` | `1h 30m 5s` | `1:30:05` |
| `CellFormat.durationShort` | `[h]:mm` | `2h 45m` | `2:45` |
| `CellFormat.durationMinSec` | `[m]:ss` | `1h 30m 5s` | `90:05` |

### Usage

```dart
// Via Cell constructor
Cell.number(1234.56, format: CellFormat.currency)    // "$1,234.56"
Cell.number(0.42, format: CellFormat.percentage)      // "42%"
Cell.date(DateTime.now(), format: CellFormat.dateIso) // "2024-01-15"
Cell.duration(Duration(hours: 1, minutes: 30), format: CellFormat.duration) // "1:30:00"

// Via data layer
data.setFormat(const CellCoordinate(0, 0), CellFormat.currency);

// Custom format codes
const myFormat = CellFormat(type: CellFormatType.number, formatCode: '#,##0.000');

// Cell.displayValue uses format when present
final cell = Cell.number(42, format: CellFormat.currency);
cell.displayValue  // "$42.00"
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
| `numberFormat` | `String?` | null | **Deprecated** — use `CellFormat` on `Cell` instead |

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

### BorderLineStyle Enum

```dart
enum BorderLineStyle {
  none,     // No border
  dotted,   // Dotted line
  dashed,   // Dashed line
  solid,    // Solid line (default)
  double,   // Double parallel lines
}
```

Ordered by priority for conflict resolution: `double` > `solid` > `dashed` > `dotted` > `none`.

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

// Create modified copy
CellBorders copyWith({BorderStyle? top, BorderStyle? right, BorderStyle? bottom, BorderStyle? left})
```

### BorderStyle Class

```dart
const BorderStyle({
  Color color = const Color(0xFF000000),
  double width = 1.0,
  BorderLineStyle lineStyle = BorderLineStyle.solid,
})

static const BorderStyle none = BorderStyle(width: 0, lineStyle: BorderLineStyle.none)

// Create modified copy
BorderStyle copyWith({Color? color, double? width, BorderLineStyle? lineStyle})
```

### BorderResolver

Resolves which border wins when adjacent cells share an edge:

```dart
// Returns the winning border for a shared edge
static BorderStyle resolve(BorderStyle a, BorderStyle b)
```

Rules (matching Excel/Google Sheets):
1. Non-none wins over none
2. Thicker border wins
3. Same width → higher-priority line style wins
4. All equal → `b` wins (right/bottom neighbor)

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

// Cell with thick dashed bottom border
const bottomBorderStyle = CellStyle(
  borders: CellBorders(
    bottom: BorderStyle(
      color: Color(0xFF000000),
      width: 2.0,
      lineStyle: BorderLineStyle.dashed,
    ),
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

### BorderResolver

Resolves conflicting borders on shared edges between adjacent cells. See [BorderResolver](#borderresolver) in the CellStyle Properties section above.

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
// Map literal construction with (row, col) records
final data = SparseWorksheetData(
  rowCount: 1000,
  columnCount: 26,
  cells: {
    (0, 0): 'Hello'.cell,
    (0, 1): 42.cell,
    (1, 0): Cell.text('World', style: const CellStyle(fontWeight: FontWeight.bold)),
  },
);

// Bracket access
data[(2, 0)] = 'New value'.cell;
final cell = data[(0, 0)];  // Cell(value: 'Hello', style: null)
data[(2, 0)] = null;         // Clear cell

// Low-level access (value and style separately)
data.setCell(const CellCoordinate(0, 0), CellValue.text('Hello'));
final value = data.getCell(const CellCoordinate(0, 0));
data.setStyle(const CellCoordinate(0, 0), const CellStyle(fontWeight: FontWeight.bold));

// Select cell
controller.selectCell(const CellCoordinate(5, 3));

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
