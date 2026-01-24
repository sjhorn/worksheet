# Theming Guide

Comprehensive guide to customizing the worksheet widget's appearance.

## Table of Contents

1. [WorksheetThemeData Properties](#worksheetthemedata-properties)
2. [Light and Dark Mode Themes](#light-and-dark-mode-themes)
3. [Custom Header Styles](#custom-header-styles)
4. [Selection Appearance](#selection-appearance)
5. [Cell Styling](#cell-styling)
6. [Gridline Customization](#gridline-customization)
7. [Complete Theme Examples](#complete-theme-examples)

---

## WorksheetThemeData Properties

`WorksheetThemeData` controls the global appearance of the worksheet. Wrap your `Worksheet` widget with `WorksheetTheme` to apply:

```dart
WorksheetTheme(
  data: WorksheetThemeData(...),
  child: Worksheet(...),
)
```

### Full Property Reference

```dart
const WorksheetThemeData({
  // Selection
  this.selectionStyle = SelectionStyle.defaultStyle,

  // Headers
  this.headerStyle = HeaderStyle.defaultStyle,

  // Gridlines
  this.gridlineColor = const Color(0xFFE0E0E0),
  this.gridlineWidth = 1.0,
  this.showGridlines = true,

  // Cell defaults
  this.cellBackgroundColor = const Color(0xFFFFFFFF),
  this.textColor = const Color(0xFF000000),
  this.fontSize = 14.0,
  this.fontFamily = 'Roboto',
  this.cellPadding = 4.0,

  // Layout
  this.rowHeaderWidth = 50.0,
  this.columnHeaderHeight = 24.0,
  this.defaultRowHeight = 24.0,
  this.defaultColumnWidth = 100.0,
  this.showHeaders = true,
})
```

### Property Details

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selectionStyle` | `SelectionStyle` | Blue highlight | Selection appearance |
| `headerStyle` | `HeaderStyle` | Gray headers | Row/column header appearance |
| `gridlineColor` | `Color` | `#E0E0E0` | Cell border color |
| `gridlineWidth` | `double` | `1.0` | Cell border width |
| `showGridlines` | `bool` | `true` | Whether to draw gridlines |
| `cellBackgroundColor` | `Color` | White | Default cell background |
| `textColor` | `Color` | Black | Default text color |
| `fontSize` | `double` | `14.0` | Default font size |
| `fontFamily` | `String` | `'Roboto'` | Default font family |
| `cellPadding` | `double` | `4.0` | Padding inside cells |
| `rowHeaderWidth` | `double` | `50.0` | Width of row number column |
| `columnHeaderHeight` | `double` | `24.0` | Height of column letter row |
| `defaultRowHeight` | `double` | `24.0` | Default height of data rows |
| `defaultColumnWidth` | `double` | `100.0` | Default width of data columns |
| `showHeaders` | `bool` | `true` | Whether to show row/column headers |

---

## Light and Dark Mode Themes

### Light Theme (Default)

```dart
const lightTheme = WorksheetThemeData(
  // Cell area
  cellBackgroundColor: Color(0xFFFFFFFF),  // White
  textColor: Color(0xFF000000),             // Black
  gridlineColor: Color(0xFFE0E0E0),         // Light gray

  // Headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFFF5F5F5),
    selectedBackgroundColor: Color(0xFFE0E0E0),
    textColor: Color(0xFF616161),
    selectedTextColor: Color(0xFF212121),
    borderColor: Color(0xFFD0D0D0),
  ),

  // Selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x220078D4),       // Light blue, semi-transparent
    borderColor: Color(0xFF0078D4),     // Blue
    focusBorderColor: Color(0xFF0078D4),
  ),
);
```

### Dark Theme

```dart
const darkTheme = WorksheetThemeData(
  // Cell area
  cellBackgroundColor: Color(0xFF1E1E1E),  // Dark gray
  textColor: Color(0xFFE0E0E0),             // Light gray
  gridlineColor: Color(0xFF3E3E3E),         // Medium gray

  // Headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFF252526),
    selectedBackgroundColor: Color(0xFF3E3E42),
    textColor: Color(0xFFCCCCCC),
    selectedTextColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF3E3E3E),
  ),

  // Selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x330078D4),       // Blue, more visible on dark
    borderColor: Color(0xFF0078D4),
    focusBorderColor: Color(0xFF0078D4),
  ),
);
```

### Adaptive Theme Based on System Setting

```dart
class AdaptiveWorksheet extends StatelessWidget {
  final SparseWorksheetData data;
  final WorksheetController controller;

  const AdaptiveWorksheet({
    required this.data,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    return WorksheetTheme(
      data: isDark ? darkTheme : lightTheme,
      child: Worksheet(
        data: data,
        controller: controller,
      ),
    );
  }
}
```

### Animated Theme Transitions

```dart
class AnimatedThemeWorksheet extends StatefulWidget {
  @override
  State<AnimatedThemeWorksheet> createState() => _AnimatedThemeWorksheetState();
}

class _AnimatedThemeWorksheetState extends State<AnimatedThemeWorksheet> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: _isDark,
          onChanged: (value) => setState(() => _isDark = value),
        ),
        Expanded(
          child: TweenAnimationBuilder<WorksheetThemeData>(
            tween: WorksheetThemeTween(
              begin: _isDark ? lightTheme : darkTheme,
              end: _isDark ? darkTheme : lightTheme,
            ),
            duration: const Duration(milliseconds: 300),
            builder: (context, theme, child) {
              return WorksheetTheme(
                data: theme,
                child: Worksheet(...),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Custom tween for theme interpolation
class WorksheetThemeTween extends Tween<WorksheetThemeData> {
  WorksheetThemeTween({
    required WorksheetThemeData begin,
    required WorksheetThemeData end,
  }) : super(begin: begin, end: end);

  @override
  WorksheetThemeData lerp(double t) {
    return WorksheetThemeData.lerp(begin!, end!, t);
  }
}
```

---

## Custom Header Styles

### HeaderStyle Properties

```dart
const HeaderStyle({
  this.backgroundColor = const Color(0xFFF5F5F5),
  this.selectedBackgroundColor = const Color(0xFFE0E0E0),
  this.textColor = const Color(0xFF616161),
  this.selectedTextColor = const Color(0xFF212121),
  this.borderColor = const Color(0xFFD0D0D0),
  this.borderWidth = 1.0,
  this.fontSize = 12.0,
  this.fontWeight = FontWeight.w500,
  this.fontFamily = 'Roboto',
})
```

### Excel-Like Headers

```dart
WorksheetThemeData(
  headerStyle: const HeaderStyle(
    backgroundColor: Color(0xFFE6E6E6),
    selectedBackgroundColor: Color(0xFFCCCCCC),
    textColor: Color(0xFF333333),
    selectedTextColor: Color(0xFF000000),
    borderColor: Color(0xFFB3B3B3),
    fontSize: 11.0,
    fontWeight: FontWeight.normal,
  ),
  rowHeaderWidth: 40.0,       // Narrower like Excel
  columnHeaderHeight: 20.0,   // Shorter like Excel
)
```

### Google Sheets-Like Headers

```dart
WorksheetThemeData(
  headerStyle: const HeaderStyle(
    backgroundColor: Color(0xFFF8F9FA),
    selectedBackgroundColor: Color(0xFFE8F0FE),
    textColor: Color(0xFF5F6368),
    selectedTextColor: Color(0xFF1A73E8),
    borderColor: Color(0xFFE0E0E0),
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
  ),
)
```

### Colorful Headers

```dart
WorksheetThemeData(
  headerStyle: const HeaderStyle(
    backgroundColor: Color(0xFF4285F4),  // Google Blue
    selectedBackgroundColor: Color(0xFF3367D6),
    textColor: Color(0xFFFFFFFF),
    selectedTextColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF3367D6),
    fontWeight: FontWeight.bold,
  ),
)
```

### Hiding Headers

```dart
WorksheetThemeData(
  showHeaders: false,  // Hide both row and column headers
)
```

---

## Selection Appearance

### SelectionStyle Properties

```dart
const SelectionStyle({
  this.fillColor = const Color(0x220078D4),      // Semi-transparent blue
  this.borderColor = const Color(0xFF0078D4),    // Solid blue
  this.borderWidth = 1.0,
  this.focusFillColor = const Color(0x00000000), // Transparent
  this.focusBorderColor = const Color(0xFF0078D4),
  this.focusBorderWidth = 1.0,
})
```

### Excel-Style Selection

```dart
const excelSelection = SelectionStyle(
  fillColor: Color(0x220078D4),
  borderColor: Color(0xFF0078D4),
  borderWidth: 1.0,
  focusFillColor: Color(0x00000000),
  focusBorderColor: Color(0xFF0078D4),
  focusBorderWidth: 2.0,  // Thicker focus border
);
```

### Google Sheets-Style Selection

```dart
const sheetsSelection = SelectionStyle(
  fillColor: Color(0x221A73E8),
  borderColor: Color(0xFF1A73E8),
  borderWidth: 2.0,
  focusFillColor: Color(0x00000000),
  focusBorderColor: Color(0xFF1A73E8),
  focusBorderWidth: 2.0,
);
```

### High Contrast Selection

```dart
const highContrastSelection = SelectionStyle(
  fillColor: Color(0x44FF6600),      // Orange fill
  borderColor: Color(0xFFFF6600),    // Orange border
  borderWidth: 3.0,
  focusFillColor: Color(0x00000000),
  focusBorderColor: Color(0xFFFF0000),  // Red focus
  focusBorderWidth: 3.0,
);
```

### Subtle Selection (for printing)

```dart
const subtleSelection = SelectionStyle(
  fillColor: Color(0x08000000),      // Very light gray
  borderColor: Color(0xFF888888),    // Medium gray
  borderWidth: 1.0,
  focusFillColor: Color(0x00000000),
  focusBorderColor: Color(0xFF444444),
  focusBorderWidth: 1.0,
);
```

---

## Cell Styling

Per-cell styles override theme defaults using `CellStyle`:

### CellStyle Properties

```dart
const CellStyle({
  this.backgroundColor,      // Cell background color
  this.fontFamily,           // Font family
  this.fontSize,             // Font size in pixels
  this.fontWeight,           // FontWeight (normal, bold, etc.)
  this.fontStyle,            // FontStyle (normal, italic)
  this.textColor,            // Text color
  this.textAlignment,        // CellTextAlignment (left, center, right)
  this.verticalAlignment,    // CellVerticalAlignment (top, middle, bottom)
  this.borders,              // CellBorders (all four sides)
  this.wrapText,             // Whether to wrap text
  this.numberFormat,         // Number format pattern
})
```

### Basic Cell Styles

```dart
// Bold header
const boldHeader = CellStyle(
  fontWeight: FontWeight.bold,
  backgroundColor: Color(0xFF4472C4),
  textColor: Color(0xFFFFFFFF),
  textAlignment: CellTextAlignment.center,
);

// Currency formatting (right-aligned)
const currencyStyle = CellStyle(
  textAlignment: CellTextAlignment.right,
  numberFormat: '\$#,##0.00',
);

// Percentage formatting
const percentStyle = CellStyle(
  textAlignment: CellTextAlignment.right,
  numberFormat: '0.0%',
);

// Italic text
const italicStyle = CellStyle(
  fontStyle: FontStyle.italic,
  textColor: Color(0xFF666666),
);
```

### Colored Backgrounds

```dart
// Traffic light colors
const greenCell = CellStyle(backgroundColor: Color(0xFFD4EDDA));
const yellowCell = CellStyle(backgroundColor: Color(0xFFFFF3CD));
const redCell = CellStyle(backgroundColor: Color(0xFFF8D7DA));

// Apply based on value
void applyTrafficLightStyle(SparseWorksheetData data, CellCoordinate cell) {
  final value = data.getCell(cell);
  if (value != null && value.isNumber) {
    final num = value.asDouble;
    if (num >= 80) {
      data.setStyle(cell, greenCell);
    } else if (num >= 50) {
      data.setStyle(cell, yellowCell);
    } else {
      data.setStyle(cell, redCell);
    }
  }
}
```

### Cell Borders

```dart
// Bottom border (for header separation)
const headerSeparator = CellStyle(
  borders: CellBorders(
    bottom: BorderStyle(
      color: Color(0xFF000000),
      width: 2.0,
    ),
  ),
);

// All borders (boxed cell)
const boxedCell = CellStyle(
  borders: CellBorders.all(
    BorderStyle(
      color: Color(0xFF000000),
      width: 1.0,
    ),
  ),
);

// Mixed borders
const customBorders = CellStyle(
  borders: CellBorders(
    top: BorderStyle(color: Color(0xFF000000), width: 2.0),
    bottom: BorderStyle(color: Color(0xFF000000), width: 2.0),
    left: BorderStyle.none,
    right: BorderStyle.none,
  ),
);
```

### Text Alignment

```dart
// Horizontal alignment
const leftAligned = CellStyle(textAlignment: CellTextAlignment.left);
const centered = CellStyle(textAlignment: CellTextAlignment.center);
const rightAligned = CellStyle(textAlignment: CellTextAlignment.right);

// Vertical alignment
const topAligned = CellStyle(verticalAlignment: CellVerticalAlignment.top);
const middleAligned = CellStyle(verticalAlignment: CellVerticalAlignment.middle);
const bottomAligned = CellStyle(verticalAlignment: CellVerticalAlignment.bottom);

// Combined
const headerStyle = CellStyle(
  textAlignment: CellTextAlignment.center,
  verticalAlignment: CellVerticalAlignment.middle,
  fontWeight: FontWeight.bold,
);
```

### Style Merging

Merge styles to combine properties:

```dart
const baseStyle = CellStyle(
  fontFamily: 'Arial',
  fontSize: 12.0,
);

const highlighted = CellStyle(
  backgroundColor: Color(0xFFFFFF00),
);

// Merge: highlighted takes precedence, but baseStyle fills in gaps
final mergedStyle = baseStyle.merge(highlighted);
// Result: Arial 12pt with yellow background
```

---

## Gridline Customization

### Visible Gridlines (Default)

```dart
WorksheetThemeData(
  showGridlines: true,
  gridlineColor: const Color(0xFFE0E0E0),
  gridlineWidth: 1.0,
)
```

### Hidden Gridlines

```dart
WorksheetThemeData(
  showGridlines: false,
)
```

### Subtle Gridlines

```dart
WorksheetThemeData(
  showGridlines: true,
  gridlineColor: const Color(0xFFF0F0F0),  // Very light
  gridlineWidth: 0.5,
)
```

### Bold Gridlines

```dart
WorksheetThemeData(
  showGridlines: true,
  gridlineColor: const Color(0xFF888888),  // Darker
  gridlineWidth: 2.0,
)
```

### Colored Gridlines

```dart
// Blue gridlines (matches headers)
WorksheetThemeData(
  gridlineColor: const Color(0xFF4285F4),
  gridlineWidth: 1.0,
)

// Matching dark theme
WorksheetThemeData(
  gridlineColor: const Color(0xFF3E3E3E),
  gridlineWidth: 1.0,
)
```

---

## Complete Theme Examples

### Professional Business Theme

```dart
const professionalTheme = WorksheetThemeData(
  // Clean, neutral colors
  cellBackgroundColor: Color(0xFFFFFFFF),
  textColor: Color(0xFF333333),
  gridlineColor: Color(0xFFE5E5E5),
  gridlineWidth: 1.0,

  // Subtle headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFFF7F7F7),
    selectedBackgroundColor: Color(0xFFE8E8E8),
    textColor: Color(0xFF555555),
    selectedTextColor: Color(0xFF333333),
    borderColor: Color(0xFFE5E5E5),
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
  ),

  // Professional blue selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x152979FF),
    borderColor: Color(0xFF2979FF),
    borderWidth: 1.0,
    focusBorderColor: Color(0xFF2979FF),
    focusBorderWidth: 2.0,
  ),

  // Compact layout
  defaultRowHeight: 22.0,
  defaultColumnWidth: 90.0,
  rowHeaderWidth: 45.0,
  columnHeaderHeight: 22.0,
  fontSize: 12.0,
  fontFamily: 'Arial',
);
```

### Modern Dark Theme

```dart
const modernDarkTheme = WorksheetThemeData(
  // Dark background
  cellBackgroundColor: Color(0xFF121212),
  textColor: Color(0xFFE0E0E0),
  gridlineColor: Color(0xFF2D2D2D),
  gridlineWidth: 1.0,

  // Dark headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFF1E1E1E),
    selectedBackgroundColor: Color(0xFF2D2D2D),
    textColor: Color(0xFFBBBBBB),
    selectedTextColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF2D2D2D),
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
  ),

  // Vibrant selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x3300E676),  // Green
    borderColor: Color(0xFF00E676),
    borderWidth: 1.0,
    focusBorderColor: Color(0xFF00E676),
    focusBorderWidth: 2.0,
  ),

  // Standard layout
  defaultRowHeight: 24.0,
  defaultColumnWidth: 100.0,
  fontSize: 13.0,
  fontFamily: 'SF Mono',
);
```

### Colorful Theme

```dart
const colorfulTheme = WorksheetThemeData(
  // Light background with color accents
  cellBackgroundColor: Color(0xFFFFFDF7),
  textColor: Color(0xFF2D3748),
  gridlineColor: Color(0xFFE2E8F0),
  gridlineWidth: 1.0,

  // Colorful headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFF667EEA),
    selectedBackgroundColor: Color(0xFF5A67D8),
    textColor: Color(0xFFFFFFFF),
    selectedTextColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF5A67D8),
    fontSize: 12.0,
    fontWeight: FontWeight.bold,
  ),

  // Purple selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x229F7AEA),
    borderColor: Color(0xFF9F7AEA),
    borderWidth: 2.0,
    focusBorderColor: Color(0xFF805AD5),
    focusBorderWidth: 2.0,
  ),

  fontSize: 14.0,
  fontFamily: 'Inter',
);
```

### Print-Friendly Theme

```dart
const printTheme = WorksheetThemeData(
  // Pure white, black text
  cellBackgroundColor: Color(0xFFFFFFFF),
  textColor: Color(0xFF000000),
  gridlineColor: Color(0xFF000000),
  gridlineWidth: 0.5,

  // Minimal headers
  headerStyle: HeaderStyle(
    backgroundColor: Color(0xFFF0F0F0),
    selectedBackgroundColor: Color(0xFFE0E0E0),
    textColor: Color(0xFF000000),
    selectedTextColor: Color(0xFF000000),
    borderColor: Color(0xFF000000),
    fontSize: 10.0,
    fontWeight: FontWeight.bold,
  ),

  // Subtle selection
  selectionStyle: SelectionStyle(
    fillColor: Color(0x08000000),
    borderColor: Color(0xFF000000),
    borderWidth: 1.0,
  ),

  // Compact for printing
  defaultRowHeight: 18.0,
  defaultColumnWidth: 72.0,
  rowHeaderWidth: 36.0,
  columnHeaderHeight: 18.0,
  fontSize: 10.0,
  fontFamily: 'Times New Roman',
);
```

---

## Accessing Theme in Child Widgets

Use `WorksheetTheme.of(context)` to access the current theme:

```dart
class CustomCellWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = WorksheetTheme.of(context);

    return Container(
      color: theme.cellBackgroundColor,
      padding: EdgeInsets.all(theme.cellPadding),
      child: Text(
        'Cell Content',
        style: TextStyle(
          color: theme.textColor,
          fontSize: theme.fontSize,
          fontFamily: theme.fontFamily,
        ),
      ),
    );
  }
}
```

### maybeOf for Optional Theme

```dart
Widget build(BuildContext context) {
  final theme = WorksheetTheme.maybeOf(context);

  // Use theme if available, otherwise use defaults
  final bgColor = theme?.cellBackgroundColor ?? Colors.white;
  final textColor = theme?.textColor ?? Colors.black;

  return Container(
    color: bgColor,
    child: Text('Content', style: TextStyle(color: textColor)),
  );
}
```
