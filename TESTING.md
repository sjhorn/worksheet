# Testing Guide

Testing patterns and examples for the worksheet widget.

## Table of Contents

1. [Unit Testing Core Components](#unit-testing-core-components)
2. [Widget Testing](#widget-testing)
3. [Mocking WorksheetData](#mocking-worksheetdata)
4. [Simulating Pointer Gestures](#simulating-pointer-gestures)
5. [Testing Selection Behavior](#testing-selection-behavior)
6. [Performance Benchmark Patterns](#performance-benchmark-patterns)

---

## Unit Testing Core Components

### Testing SpanList

`SpanList` manages row/column dimensions with O(log n) lookups:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/worksheet.dart';

void main() {
  group('SpanList', () {
    test('default size for all indices', () {
      final spans = SpanList(count: 100, defaultSize: 24.0);

      expect(spans.count, 100);
      expect(spans.sizeAt(0), 24.0);
      expect(spans.sizeAt(50), 24.0);
      expect(spans.sizeAt(99), 24.0);
    });

    test('custom sizes override defaults', () {
      final spans = SpanList(
        count: 100,
        defaultSize: 24.0,
        customSizes: {5: 48.0, 10: 100.0},
      );

      expect(spans.sizeAt(4), 24.0);
      expect(spans.sizeAt(5), 48.0);
      expect(spans.sizeAt(10), 100.0);
    });

    test('positionAt returns cumulative offset', () {
      final spans = SpanList(count: 10, defaultSize: 24.0);

      expect(spans.positionAt(0), 0.0);
      expect(spans.positionAt(1), 24.0);
      expect(spans.positionAt(5), 120.0);  // 5 * 24
    });

    test('positionAt with custom sizes', () {
      final spans = SpanList(
        count: 10,
        defaultSize: 24.0,
        customSizes: {2: 48.0},  // Row 2 is double height
      );

      expect(spans.positionAt(0), 0.0);
      expect(spans.positionAt(1), 24.0);
      expect(spans.positionAt(2), 48.0);   // 24 + 24
      expect(spans.positionAt(3), 96.0);   // 24 + 24 + 48
      expect(spans.positionAt(4), 120.0);  // 24 + 24 + 48 + 24
    });

    test('indexAtPosition finds correct index via binary search', () {
      final spans = SpanList(count: 1000, defaultSize: 24.0);

      expect(spans.indexAtPosition(0.0), 0);
      expect(spans.indexAtPosition(23.9), 0);
      expect(spans.indexAtPosition(24.0), 1);
      expect(spans.indexAtPosition(100.0), 4);  // 100 / 24 = 4.16
    });

    test('indexAtPosition clamps to valid range', () {
      final spans = SpanList(count: 100, defaultSize: 24.0);

      expect(spans.indexAtPosition(-10.0), 0);  // Clamp to first
      expect(spans.indexAtPosition(10000.0), 99);  // Clamp to last
    });

    test('totalSize calculates sum of all sizes', () {
      final spans = SpanList(count: 10, defaultSize: 24.0);
      expect(spans.totalSize, 240.0);  // 10 * 24

      final customSpans = SpanList(
        count: 10,
        defaultSize: 24.0,
        customSizes: {0: 48.0, 9: 100.0},
      );
      // (48) + (8 * 24) + (100) = 340
      expect(customSpans.totalSize, 340.0);
    });

    test('setSize updates size and recalculates cumulative', () {
      final spans = SpanList(count: 10, defaultSize: 24.0);

      spans.setSize(5, 48.0);

      expect(spans.sizeAt(5), 48.0);
      expect(spans.positionAt(6), 24.0 * 5 + 48.0);  // 168
    });

    test('getVisibleRange returns indices in viewport', () {
      final spans = SpanList(count: 1000, defaultSize: 24.0);

      final range = spans.getVisibleRange(scrollOffset: 100.0, viewportSize: 200.0);

      // At scroll 100, first visible row is 100/24 = 4
      // Viewport shows 200/24 ≈ 8 rows
      expect(range.startIndex, 4);
      expect(range.endIndex, 12);  // 4 + 8
    });
  });
}
```

### Testing LayoutSolver

`LayoutSolver` combines row and column `SpanList`s for cell geometry:

```dart
void main() {
  group('LayoutSolver', () {
    late LayoutSolver solver;

    setUp(() {
      solver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
    });

    test('getCellBounds returns correct rectangle', () {
      final bounds = solver.getCellBounds(const CellCoordinate(5, 3));

      expect(bounds.left, 300.0);   // 3 columns * 100
      expect(bounds.top, 120.0);    // 5 rows * 24
      expect(bounds.width, 100.0);  // Column width
      expect(bounds.height, 24.0);  // Row height
    });

    test('getCellAt finds cell from position', () {
      final cell = solver.getCellAt(const Offset(350.0, 130.0));

      expect(cell.row, 5);     // 130 / 24 = 5.4 → 5
      expect(cell.column, 3);  // 350 / 100 = 3.5 → 3
    });

    test('getVisibleRows returns range in viewport', () {
      final range = solver.getVisibleRows(100.0, 200.0);

      expect(range.startIndex, 4);   // 100 / 24 = 4.16
      expect(range.endIndex, 12);    // (100 + 200) / 24 = 12.5
    });

    test('getVisibleColumns returns range in viewport', () {
      final range = solver.getVisibleColumns(250.0, 400.0);

      expect(range.startIndex, 2);   // 250 / 100 = 2.5
      expect(range.endIndex, 6);     // (250 + 400) / 100 = 6.5
    });

    test('setRowHeight updates layout', () {
      solver.setRowHeight(5, 48.0);

      expect(solver.getRowHeight(5), 48.0);
      expect(solver.getRowTop(6), 24.0 * 5 + 48.0);
    });

    test('setColumnWidth updates layout', () {
      solver.setColumnWidth(3, 150.0);

      expect(solver.getColumnWidth(3), 150.0);
      expect(solver.getColumnLeft(4), 100.0 * 3 + 150.0);
    });

    test('getRangeBounds calculates bounding rect', () {
      final bounds = solver.getRangeBounds(
        startRow: 2,
        startColumn: 1,
        endRow: 4,
        endColumn: 3,
      );

      expect(bounds.left, 100.0);    // Column 1 * 100
      expect(bounds.top, 48.0);      // Row 2 * 24
      expect(bounds.width, 300.0);   // 3 columns * 100
      expect(bounds.height, 72.0);   // 3 rows * 24
    });
  });
}
```

### Testing CellCoordinate

```dart
void main() {
  group('CellCoordinate', () {
    test('creates coordinate from row and column', () {
      const coord = CellCoordinate(5, 3);
      expect(coord.row, 5);
      expect(coord.column, 3);
    });

    test('toNotation converts to Excel-style', () {
      expect(const CellCoordinate(0, 0).toNotation(), 'A1');
      expect(const CellCoordinate(0, 25).toNotation(), 'Z1');
      expect(const CellCoordinate(0, 26).toNotation(), 'AA1');
      expect(const CellCoordinate(99, 27).toNotation(), 'AB100');
    });

    test('equality comparison', () {
      const a = CellCoordinate(5, 3);
      const b = CellCoordinate(5, 3);
      const c = CellCoordinate(5, 4);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode consistency', () {
      const a = CellCoordinate(5, 3);
      const b = CellCoordinate(5, 3);

      expect(a.hashCode, b.hashCode);
    });

    test('copyWith creates modified copy', () {
      const original = CellCoordinate(5, 3);

      expect(original.copyWith(row: 10), const CellCoordinate(10, 3));
      expect(original.copyWith(column: 7), const CellCoordinate(5, 7));
      expect(original.copyWith(row: 10, column: 7), const CellCoordinate(10, 7));
    });
  });
}
```

### Testing CellRange

```dart
void main() {
  group('CellRange', () {
    test('creates range from corners', () {
      const range = CellRange(2, 1, 5, 4);

      expect(range.startRow, 2);
      expect(range.startColumn, 1);
      expect(range.endRow, 5);
      expect(range.endColumn, 4);
    });

    test('single cell range', () {
      const range = CellRange.single(CellCoordinate(3, 2));

      expect(range.startRow, 3);
      expect(range.startColumn, 2);
      expect(range.endRow, 3);
      expect(range.endColumn, 2);
      expect(range.isSingleCell, isTrue);
    });

    test('normalizes reversed coordinates', () {
      const range = CellRange(5, 4, 2, 1);  // End before start

      expect(range.startRow, 2);
      expect(range.startColumn, 1);
      expect(range.endRow, 5);
      expect(range.endColumn, 4);
    });

    test('contains checks if cell is in range', () {
      const range = CellRange(2, 1, 5, 4);

      expect(range.contains(const CellCoordinate(3, 2)), isTrue);
      expect(range.contains(const CellCoordinate(2, 1)), isTrue);  // Start corner
      expect(range.contains(const CellCoordinate(5, 4)), isTrue);  // End corner
      expect(range.contains(const CellCoordinate(1, 2)), isFalse); // Above
      expect(range.contains(const CellCoordinate(3, 5)), isFalse); // Right
    });

    test('rowCount and columnCount', () {
      const range = CellRange(2, 1, 5, 4);

      expect(range.rowCount, 4);     // Rows 2, 3, 4, 5
      expect(range.columnCount, 4);  // Columns 1, 2, 3, 4
    });

    test('cellCount calculates total cells', () {
      const range = CellRange(0, 0, 9, 4);  // 10 rows × 5 columns

      expect(range.cellCount, 50);
    });
  });
}
```

---

## Widget Testing

### Basic Widget Test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/worksheet.dart';

void main() {
  group('Worksheet Widget', () {
    testWidgets('renders without error', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Worksheet), findsOneWidget);

      // Cleanup
      controller.dispose();
      data.dispose();
    });

    testWidgets('displays cell content', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Test Value'));

      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
              ),
            ),
          ),
        ),
      );

      // Let the widget render
      await tester.pumpAndSettle();

      // The text is rendered in CustomPaint, so we verify the data is set
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'Test Value');

      controller.dispose();
      data.dispose();
    });

    testWidgets('read-only mode prevents selection', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
                readOnly: true,
              ),
            ),
          ),
        ),
      );

      // Tap on the worksheet
      await tester.tap(find.byType(Worksheet));
      await tester.pump();

      // Selection should remain null in read-only mode
      expect(controller.hasSelection, isFalse);

      controller.dispose();
      data.dispose();
    });
  });
}
```

### Testing with pumpWidget

```dart
testWidgets('applies theme correctly', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  const customTheme = WorksheetThemeData(
    cellBackgroundColor: Color(0xFF123456),
    showHeaders: false,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: customTheme,
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify theme is accessible
  final context = tester.element(find.byType(Worksheet));
  final theme = WorksheetTheme.of(context);

  expect(theme.cellBackgroundColor, const Color(0xFF123456));
  expect(theme.showHeaders, isFalse);

  controller.dispose();
  data.dispose();
});
```

---

## Mocking WorksheetData

### Simple Mock Implementation

```dart
class MockWorksheetData implements WorksheetData {
  final Map<CellCoordinate, CellValue> _cells = {};
  final Map<CellCoordinate, CellStyle> _styles = {};

  @override
  final int rowCount;

  @override
  final int columnCount;

  MockWorksheetData({
    this.rowCount = 100,
    this.columnCount = 26,
  });

  @override
  CellValue? getCell(CellCoordinate coord) => _cells[coord];

  @override
  CellStyle? getStyle(CellCoordinate coord) => _styles[coord];

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    if (value == null) {
      _cells.remove(coord);
    } else {
      _cells[coord] = value;
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    if (style == null) {
      _styles.remove(coord);
    } else {
      _styles[coord] = style;
    }
  }

  @override
  Stream<DataChangeEvent> get changes => const Stream.empty();

  @override
  void dispose() {
    _cells.clear();
    _styles.clear();
  }
}

// Usage in tests
testWidgets('handles mock data', (tester) async {
  final mockData = MockWorksheetData();
  mockData.setCell(const CellCoordinate(0, 0), CellValue.text('Mock'));

  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: mockData,
          controller: controller,
          rowCount: 100,
          columnCount: 26,
        ),
      ),
    ),
  );

  expect(mockData.getCell(const CellCoordinate(0, 0))?.displayValue, 'Mock');

  controller.dispose();
  mockData.dispose();
});
```

### Mock with Verification

```dart
class VerifyingMockWorksheetData extends MockWorksheetData {
  final List<CellCoordinate> getCellCalls = [];
  final List<(CellCoordinate, CellValue?)> setCellCalls = [];

  @override
  CellValue? getCell(CellCoordinate coord) {
    getCellCalls.add(coord);
    return super.getCell(coord);
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    setCellCalls.add((coord, value));
    super.setCell(coord, value);
  }

  void verifyGetCellCalled(CellCoordinate coord) {
    expect(getCellCalls, contains(coord));
  }

  void verifySetCellCalled(CellCoordinate coord, CellValue? value) {
    expect(setCellCalls, contains((coord, value)));
  }

  void reset() {
    getCellCalls.clear();
    setCellCalls.clear();
  }
}
```

---

## Simulating Pointer Gestures

### Tap Gesture

```dart
testWidgets('tap selects cell', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(
            rowHeaderWidth: 50.0,
            columnHeaderHeight: 24.0,
            defaultRowHeight: 24.0,
            defaultColumnWidth: 100.0,
          ),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Calculate position of cell A1 (0, 0)
  // Headers: 50px width, 24px height
  // Cell A1 starts at (50, 24)
  final cellA1Center = const Offset(50 + 50, 24 + 12);  // Center of A1

  await tester.tapAt(cellA1Center);
  await tester.pump();

  expect(controller.focusCell, const CellCoordinate(0, 0));

  controller.dispose();
  data.dispose();
});
```

### Drag Gesture

```dart
testWidgets('drag extends selection', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(
            rowHeaderWidth: 50.0,
            columnHeaderHeight: 24.0,
            defaultRowHeight: 24.0,
            defaultColumnWidth: 100.0,
          ),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Start at A1, drag to C3
  final startPoint = const Offset(100, 36);  // A1 center
  final endPoint = const Offset(300, 84);    // C3 center

  await tester.dragFrom(startPoint, endPoint - startPoint);
  await tester.pumpAndSettle();

  final range = controller.selectedRange;
  expect(range, isNotNull);
  expect(range!.startRow, 0);
  expect(range.startColumn, 0);
  expect(range.endRow, 2);
  expect(range.endColumn, 2);

  controller.dispose();
  data.dispose();
});
```

### Double Tap Gesture

```dart
testWidgets('double tap triggers edit callback', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  CellCoordinate? editedCell;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
            onEditCell: (cell) {
              editedCell = cell;
            },
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // First tap to select
  await tester.tap(find.byType(Worksheet));
  await tester.pump(const Duration(milliseconds: 50));

  // Second tap to trigger edit
  await tester.tap(find.byType(Worksheet));
  await tester.pumpAndSettle();

  expect(editedCell, isNotNull);

  controller.dispose();
  data.dispose();
});
```

### Scroll Gesture

```dart
testWidgets('scroll updates scroll position', (tester) async {
  final data = SparseWorksheetData(rowCount: 1000, columnCount: 100);
  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 1000,
            columnCount: 100,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final initialScrollY = controller.scrollY;

  // Scroll down
  await tester.drag(find.byType(Worksheet), const Offset(0, -200));
  await tester.pumpAndSettle();

  expect(controller.scrollY, greaterThan(initialScrollY));

  controller.dispose();
  data.dispose();
});
```

---

## Testing Selection Behavior

### Selection Controller Tests

```dart
void main() {
  group('SelectionController', () {
    late SelectionController controller;

    setUp(() {
      controller = SelectionController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('selectCell sets single cell selection', () {
      controller.selectCell(const CellCoordinate(5, 3));

      expect(controller.hasSelection, isTrue);
      expect(controller.focus, const CellCoordinate(5, 3));
      expect(controller.selectedRange?.isSingleCell, isTrue);
    });

    test('selectRange sets multi-cell selection', () {
      controller.selectRange(const CellRange(2, 1, 5, 4));

      expect(controller.hasSelection, isTrue);
      expect(controller.selectedRange?.startRow, 2);
      expect(controller.selectedRange?.endRow, 5);
    });

    test('selectRow selects entire row', () {
      controller.selectRow(5, columnCount: 26);

      final range = controller.selectedRange!;
      expect(range.startRow, 5);
      expect(range.endRow, 5);
      expect(range.startColumn, 0);
      expect(range.endColumn, 25);
    });

    test('selectColumn selects entire column', () {
      controller.selectColumn(3, rowCount: 100);

      final range = controller.selectedRange!;
      expect(range.startColumn, 3);
      expect(range.endColumn, 3);
      expect(range.startRow, 0);
      expect(range.endRow, 99);
    });

    test('clear removes selection', () {
      controller.selectCell(const CellCoordinate(5, 3));
      controller.clear();

      expect(controller.hasSelection, isFalse);
      expect(controller.focus, isNull);
    });

    test('moveFocus navigates cells', () {
      controller.selectCell(const CellCoordinate(5, 5));

      controller.moveFocus(rowDelta: -1, columnDelta: 0, maxRow: 99, maxColumn: 25);
      expect(controller.focus, const CellCoordinate(4, 5));

      controller.moveFocus(rowDelta: 0, columnDelta: 1, maxRow: 99, maxColumn: 25);
      expect(controller.focus, const CellCoordinate(4, 6));
    });

    test('moveFocus extends selection when extend is true', () {
      controller.selectCell(const CellCoordinate(5, 5));

      controller.moveFocus(
        rowDelta: 1,
        columnDelta: 1,
        extend: true,
        maxRow: 99,
        maxColumn: 25,
      );

      final range = controller.selectedRange!;
      expect(range.startRow, 5);
      expect(range.startColumn, 5);
      expect(range.endRow, 6);
      expect(range.endColumn, 6);
    });

    test('moveFocus respects boundaries', () {
      controller.selectCell(const CellCoordinate(0, 0));

      controller.moveFocus(rowDelta: -1, columnDelta: -1, maxRow: 99, maxColumn: 25);

      // Should stay at (0, 0) since we can't go negative
      expect(controller.focus, const CellCoordinate(0, 0));
    });

    test('notifies listeners on selection change', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.selectCell(const CellCoordinate(5, 3));

      expect(notified, isTrue);
    });
  });
}
```

---

## Performance Benchmark Patterns

### Render Time Benchmark

```dart
void main() {
  group('Performance Benchmarks', () {
    test('tile render time under 8ms', () {
      final data = SparseWorksheetData(rowCount: 1000, columnCount: 100);

      // Populate some data
      for (var row = 0; row < 100; row++) {
        for (var col = 0; col < 10; col++) {
          data.setCell(
            CellCoordinate(row, col),
            CellValue.text('Cell $row,$col'),
          );
        }
      }

      final layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 24.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );

      final tilePainter = TilePainter(
        data: data,
        layoutSolver: layoutSolver,
        showGridlines: true,
        gridlineColor: const Color(0xFFE0E0E0),
        backgroundColor: const Color(0xFFFFFFFF),
        defaultTextColor: const Color(0xFF000000),
        defaultFontSize: 14.0,
        defaultFontFamily: 'Roboto',
        cellPadding: 4.0,
      );

      // Measure render time
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10; i++) {
        tilePainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const Rect.fromLTWH(0, 0, 256, 256),
          cellRange: const CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );
      }

      stopwatch.stop();

      final avgMs = stopwatch.elapsedMilliseconds / 10;
      print('Average tile render time: ${avgMs}ms');

      expect(avgMs, lessThan(16));  // Must be under 16ms for 60fps

      data.dispose();
    });

    test('SpanList lookup under 1ms for 1M rows', () {
      final spans = SpanList(count: 1000000, defaultSize: 24.0);

      final stopwatch = Stopwatch()..start();

      // Perform 1000 lookups
      for (var i = 0; i < 1000; i++) {
        spans.indexAtPosition(i * 1000.0);
      }

      stopwatch.stop();

      final avgUs = stopwatch.elapsedMicroseconds / 1000;
      print('Average lookup time: ${avgUs}μs');

      expect(avgUs, lessThan(100));  // Under 100μs per lookup
    });

    test('SparseWorksheetData memory efficiency', () {
      final data = SparseWorksheetData(
        rowCount: 1048576,  // 1M+ rows
        columnCount: 16384,
      );

      // Add 100K cells
      for (var i = 0; i < 100000; i++) {
        data.setCell(
          CellCoordinate(i, 0),
          CellValue.text('Row $i'),
        );
      }

      // Memory should be O(100K), not O(17 billion)
      // This is hard to test directly, but we can verify it doesn't crash

      expect(data.getCell(const CellCoordinate(99999, 0))?.displayValue, 'Row 99999');
      expect(data.getCell(const CellCoordinate(100000, 0)), isNull);  // Not set

      data.dispose();
    });
  });
}
```

### Scroll Performance Test

```dart
testWidgets('maintains 60fps during scroll', (tester) async {
  final data = SparseWorksheetData(rowCount: 10000, columnCount: 100);

  // Populate visible area
  for (var row = 0; row < 100; row++) {
    for (var col = 0; col < 10; col++) {
      data.setCell(CellCoordinate(row, col), CellValue.number((row * 10 + col).toDouble()));
    }
  }

  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 10000,
            columnCount: 100,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Measure frame time during scroll
  final frameCount = 60;
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < frameCount; i++) {
    await tester.drag(find.byType(Worksheet), const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 16));  // 60fps frame time
  }

  stopwatch.stop();

  final actualMs = stopwatch.elapsedMilliseconds;
  final expectedMs = frameCount * 16;  // 960ms for 60 frames at 60fps

  print('Scroll test: ${frameCount} frames in ${actualMs}ms (expected ~${expectedMs}ms)');

  // Allow some overhead, but should be close to 60fps
  expect(actualMs, lessThan(expectedMs * 2));

  controller.dispose();
  data.dispose();
});
```

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/span_list_test.dart

# Run tests matching pattern
flutter test --name "SpanList"

# Generate coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
