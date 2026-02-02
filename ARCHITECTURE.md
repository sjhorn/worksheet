# Worksheet Widget Architecture

A high-performance Flutter worksheet widget (Excel-like) supporting 10%-400% zoom with GPU-optimized tile-based rendering.

## Table of Contents

1. [Overview](#overview)
2. [Package Structure](#package-structure)
3. [Core Concepts](#core-concepts)
4. [Rendering Pipeline](#rendering-pipeline)
5. [Data Flow](#data-flow)
6. [Coordinate Systems](#coordinate-systems)
7. [Component Deep Dives](#component-deep-dives)
8. [Performance Optimizations](#performance-optimizations)

---

## Overview

The worksheet widget is built on three foundational Flutter technologies:

| Technology | Purpose |
|------------|---------|
| `TwoDimensionalScrollable` | 2D scroll management with independent horizontal/vertical scroll controllers |
| `LeafRenderObjectWidget` | Direct render object control for custom painting via `WorksheetViewport` |
| `ui.Picture` / `PictureRecorder` | GPU-backed tile caching for efficient rendering |

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Worksheet Widget                          │
│  ┌───────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ MouseRegion   │  │    Listener    │  │  GestureDetector   │  │
│  │ (cursor)      │  │ (pointer events)│  │  (double-tap)      │  │
│  └───────────────┘  └────────────────┘  └────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              TwoDimensionalScrollable                      │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │              WorksheetViewport                       │  │  │
│  │  │  ┌─────────────────────────────────────────────┐    │  │  │
│  │  │  │           TileManager + TileCache            │    │  │  │
│  │  │  │  ┌───────────────────────────────────────┐  │    │  │  │
│  │  │  │  │        TilePainter → ui.Picture        │  │    │  │  │
│  │  │  │  └───────────────────────────────────────┘  │    │  │  │
│  │  │  └─────────────────────────────────────────────┘    │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  SelectionLayer │  │   HeaderLayer   │  │   FrozenLayer   │  │
│  │  (blue overlay) │  │ (A,B,C / 1,2,3) │  │ (frozen panes)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Package Structure

```
lib/
├── worksheet.dart              # Public API exports
└── src/
    ├── core/                   # Models, data, geometry
    │   ├── models/
    │   │   ├── cell_coordinate.dart    # (row, column) position
    │   │   ├── cell_range.dart         # Rectangular cell range
    │   │   ├── cell_style.dart         # Fonts, colors, alignment
    │   │   ├── cell_value.dart         # Text, number, formula, error
    │   │   └── freeze_config.dart      # Frozen rows/columns config
    │   ├── geometry/
    │   │   ├── span_list.dart          # O(log n) row/column sizes
    │   │   ├── layout_solver.dart      # Cell bounds calculator
    │   │   ├── visible_range_calculator.dart
    │   │   └── zoom_transformer.dart   # Screen ↔ worksheet coords
    │   └── data/
    │       ├── worksheet_data.dart     # Abstract data interface
    │       ├── sparse_worksheet_data.dart  # Map-based implementation
    │       └── data_change_event.dart  # Change notifications
    │
    ├── rendering/              # Tile system, painters
    │   ├── tile/
    │   │   ├── tile.dart              # GPU Picture + metadata
    │   │   ├── tile_coordinate.dart   # Tile grid position
    │   │   ├── tile_config.dart       # Size, cache limits
    │   │   ├── tile_cache.dart        # LRU cache with invalidation
    │   │   ├── tile_manager.dart      # Lifecycle orchestrator
    │   │   └── tile_painter.dart      # Cell/gridline rendering
    │   ├── painters/
    │   │   ├── selection_renderer.dart # Selection highlight
    │   │   └── header_renderer.dart    # Row/column headers
    │   └── layers/
    │       ├── render_layer.dart       # Base layer interface
    │       ├── selection_layer.dart    # Selection overlay
    │       ├── header_layer.dart       # Headers overlay
    │       └── frozen_layer.dart       # Frozen panes overlay
    │
    ├── scrolling/              # Viewport, delegates
    │   ├── worksheet_viewport.dart     # RenderBox for tiles
    │   ├── worksheet_scroll_delegate.dart
    │   ├── viewport_delegate.dart
    │   ├── scroll_physics.dart
    │   └── scroll_anchor.dart
    │
    ├── interaction/            # Gestures, selection, editing
    │   ├── gesture_handler.dart        # Tap, drag, resize
    │   ├── controllers/
    │   │   ├── selection_controller.dart  # Selection state
    │   │   ├── zoom_controller.dart       # Zoom level + animation
    │   │   └── edit_controller.dart       # Cell editing state
    │   ├── gestures/
    │   │   ├── keyboard_handler.dart   # Arrow keys, shortcuts
    │   │   └── scale_handler.dart      # Pinch-to-zoom
    │   └── hit_testing/
    │       ├── hit_tester.dart         # Screen → element resolver
    │       └── hit_test_result.dart    # Result types enum
    │
    └── widgets/                # Public widget wrappers
        ├── worksheet_widget.dart       # Main Worksheet widget
        ├── worksheet_controller.dart   # Programmatic control
        ├── worksheet_theme.dart        # Theming (colors, sizes)
        └── cell_editor_overlay.dart    # Text editing overlay
```

---

## Core Concepts

### 1. SpanList - Efficient Row/Column Sizing

`SpanList` provides O(log n) position lookups using cumulative sums:

```dart
SpanList {
  count: 50000,           // Number of rows/columns
  defaultSize: 24.0,      // Default height/width
  _sizes: [24, 24, 48, ...],      // Per-row/column sizes
  _cumulative: [0, 24, 48, 96, ...] // Running totals
}
```

**Key Operations:**
- `sizeAt(index)` → O(1) - Get row/column size
- `positionAt(index)` → O(1) - Get pixel position
- `indexAtPosition(pos)` → O(log n) - Find row/column at position (binary search)
- `setSize(index, size)` → O(n) - Resize (rebuilds cumulative array)

### 2. LayoutSolver - Cell Geometry

Wraps row and column `SpanList`s to provide cell bounds:

```dart
layoutSolver.getCellBounds(CellCoordinate(5, 3))
// → Rect(left: 300, top: 120, width: 100, height: 24)

layoutSolver.getCellAt(Offset(350, 130))
// → CellCoordinate(row: 5, column: 3)

layoutSolver.getVisibleRows(scrollY: 1000, height: 600)
// → SpanRange(startIndex: 41, endIndex: 66)
```

### 3. ZoomBucket - Level of Detail

Zoom levels are bucketed for rendering decisions:

| Bucket | Zoom Range | Gridlines | Text | Tile Coverage |
|--------|------------|-----------|------|---------------|
| `tenth` | 10-24% | Hidden | Hidden | 10× |
| `quarter` | 25-39% | Hidden | Visible | 4× |
| `forty` | 40-49% | Visible | Visible | 2× |
| `half` | 50-99% | Visible | Visible | 2× |
| `full` | 100-199% | Visible | Visible | 1× |
| `twoX` | 200-299% | Visible | Visible | 0.5× |
| `quadruple` | 300-400% | Visible | Visible | 0.25× |

### 4. WorksheetData - Abstract Data Interface

```dart
abstract class WorksheetData {
  CellValue? getCell(CellCoordinate coord);
  CellStyle? getStyle(CellCoordinate coord);
  void setCell(CellCoordinate coord, CellValue? value);
  void setStyle(CellCoordinate coord, CellStyle? style);
  void batchUpdate(void Function(WorksheetDataBatch batch) updates);
  Stream<DataChangeEvent> get changes;
}
```

**Implementation:** `SparseWorksheetData` uses `Map<CellCoordinate, CellValue>` for memory-efficient storage of sparse data.

---

## Rendering Pipeline

### Tile-Based Rendering

The worksheet is divided into 256×256 pixel tiles, each rendered to a GPU-backed `ui.Picture`:

```
┌──────────────────────────────────────────────────────────────┐
│ Viewport (visible area)                                       │
│ ┌────────┬────────┬────────┬────────┐                        │
│ │ Tile   │ Tile   │ Tile   │ Tile   │ ◄── Each tile is       │
│ │ (0,0)  │ (1,0)  │ (2,0)  │ (3,0)  │     256×256 pixels     │
│ ├────────┼────────┼────────┼────────┤                        │
│ │ Tile   │ Tile   │ Tile   │ Tile   │                        │
│ │ (0,1)  │ (1,1)  │ (2,1)  │ (3,1)  │                        │
│ ├────────┼────────┼────────┼────────┤                        │
│ │ Tile   │ Tile   │ Tile   │ Tile   │                        │
│ │ (0,2)  │ (1,2)  │ (2,2)  │ (3,2)  │                        │
│ └────────┴────────┴────────┴────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

### Render Flow

```
1. Scroll/Zoom Event
        │
        ▼
2. WorksheetViewport.paint() called
        │
        ▼
3. Calculate visible viewport in worksheet coordinates
   viewport = Rect(scrollX/zoom, scrollY/zoom, width/zoom, height/zoom)
        │
        ▼
4. TileManager.getTilesForViewport(viewport, zoomBucket)
        │
        ├──► Cache HIT: Return cached ui.Picture
        │
        └──► Cache MISS: TilePainter.renderTile()
                │
                ├── Draw background
                ├── Draw gridlines (if zoom ≥ 40%)
                └── Draw cell contents (if zoom ≥ 25%)
        │
        ▼
5. Paint tiles to canvas with zoom transform
   canvas.scale(zoom)
   canvas.translate(-scrollX, -scrollY)
   for tile in tiles:
       canvas.drawPicture(tile.picture)
        │
        ▼
6. Paint overlay layers (selection, headers)
```

### TileCache LRU Strategy

```dart
TileCache {
  maxTiles: 100,          // LRU eviction threshold
  _cache: LinkedHashMap,  // Access-ordered for LRU
  _pendingDisposal: [],   // Deferred cleanup after paint
}
```

**Invalidation triggers:**
- Cell data change → `invalidateRange(CellRange)`
- Zoom change → `invalidateZoomBucket(ZoomBucket)`
- Row/column resize → `invalidateAll()`

---

## Data Flow

### Selection Flow

```
User tap on cell
        │
        ▼
Listener.onPointerDown
        │
        ▼
WorksheetGestureHandler.onTapDown()
        │
        ▼
WorksheetHitTester.hitTest(position, scroll, zoom)
        │
        ├── HitTestType.cell → SelectionController.selectCell()
        ├── HitTestType.rowHeader → SelectionController.selectRow()
        ├── HitTestType.columnHeader → SelectionController.selectColumn()
        ├── HitTestType.rowResizeHandle → Start resize drag
        └── HitTestType.columnResizeHandle → Start resize drag
        │
        ▼
SelectionController.notifyListeners()
        │
        ▼
SelectionLayer repaints with new selection
```

### Resize Flow

```
User drags column border
        │
        ▼
Listener.onPointerMove
        │
        ▼
WorksheetGestureHandler.onDragUpdate()
        │
        ├── Calculate delta (incremental from last position)
        └── onResizeColumn(column, delta)
                │
                ▼
        LayoutSolver.setColumnWidth(column, newWidth)
                │
                ▼
        TileManager.invalidateAll()
                │
                ▼
        _layoutVersion++ (triggers viewport repaint)
                │
                ▼
        setState() → Widget rebuilds
        │
        ▼
On pointer up: WorksheetGestureHandler.onDragEnd()
        │
        └── Apply size to all selected columns (multi-select resize)
```

### Edit Flow

```
User double-taps cell
        │
        ▼
GestureDetector.onDoubleTap
        │
        ▼
onEditCell callback
        │
        ▼
controller.getCellScreenBounds(cell) → Rect
  (accounts for zoom, scroll, and header offsets)
        │
        ▼
EditController.startEditing(cell, initialValue)
        │
        ▼
CellEditorOverlay appears (TextField positioned at Rect)
        │
        ▼
User types and presses Enter
        │
        ▼
EditController.commitEdit(onCommit: callback)
        │
        ▼
WorksheetData.setCell(coord, newValue)
        │
        ▼
DataChangeEvent emitted
        │
        ▼
TileManager.invalidateRange() for affected cells
```

---

## Coordinate Systems

The widget uses three coordinate systems:

### 1. Screen Coordinates
- Origin: Top-left of widget
- Units: Physical pixels
- Includes: Headers, scroll position

### 2. Viewport Coordinates
- Origin: Top-left of content area (after headers)
- Units: Physical pixels
- Excludes: Headers

### 3. Worksheet Coordinates
- Origin: Cell (0,0) top-left
- Units: Logical pixels at 100% zoom
- Independent of: Scroll, zoom, headers

### Coordinate Conversion

```dart
// Screen → Worksheet
worksheetPos = hitTester.screenToWorksheet(
  screenPosition: Offset(500, 300),
  scrollOffset: Offset(scrollX, scrollY),
  zoom: 1.5,
);

// Worksheet → Screen
screenPos = hitTester.worksheetToScreen(
  worksheetPosition: Offset(200, 100),
  scrollOffset: Offset(scrollX, scrollY),
  zoom: 1.5,
);
```

**Conversion formulas:**

```
Screen → Worksheet:
  worksheetX = (screenX - headerWidth*zoom) / zoom + scrollX/zoom
  worksheetY = (screenY - headerHeight*zoom) / zoom + scrollY/zoom

Worksheet → Screen:
  screenX = (worksheetX - scrollX/zoom) * zoom + headerWidth*zoom
  screenY = (worksheetY - scrollY/zoom) * zoom + headerHeight*zoom
```

---

## Component Deep Dives

### WorksheetController

Central controller aggregating sub-controllers, with access to the widget's
internal layout state:

```dart
WorksheetController {
  SelectionController selectionController;  // Cell selection state
  ZoomController zoomController;            // Zoom level 0.1-4.0
  ScrollController horizontalScrollController;
  ScrollController verticalScrollController;

  // Attached by the Worksheet widget after initialization:
  LayoutSolver? layoutSolver;    // Authoritative cell geometry
  double headerWidth;            // Header width in worksheet coords
  double headerHeight;           // Header height in worksheet coords
}
```

**Usage:**
```dart
controller.selectCell(CellCoordinate(5, 3));
controller.setZoom(1.5);
controller.scrollTo(x: 500, y: 1000, animate: true);

// Get screen-space bounds of a cell (accounts for zoom, scroll, headers)
final bounds = controller.getCellScreenBounds(CellCoordinate(5, 3));

// Scroll to make a cell visible (uses attached layout)
controller.ensureCellVisible(cell, viewportSize: size);

// Access layout for custom calculations
final solver = controller.layoutSolver;
if (solver != null) {
  final width = solver.getColumnWidth(3);
}
```

### WorksheetGestureHandler

Stateful gesture processor:

```dart
WorksheetGestureHandler {
  // State
  _dragStartHit: WorksheetHitTestResult?
  _lastDragPosition: Offset?
  _isResizing: bool
  _isSelectingRange: bool

  // Callbacks
  onEditCell: OnEditCell?
  onResizeRow: OnResizeRow?
  onResizeColumn: OnResizeColumn?
  onResizeRowEnd: OnResizeRowEnd?
  onResizeColumnEnd: OnResizeColumnEnd?
}
```

**Gesture handling:**
- **Single tap:** Select cell/row/column
- **Double tap:** Enter edit mode
- **Drag from cell:** Extend selection
- **Drag resize handle:** Resize row/column
- **Drag end on resize:** Apply to all selected (multi-resize)

### TilePainter

Renders worksheet content to GPU Pictures:

```dart
TilePainter.renderTile(
  coordinate: TileCoordinate(2, 3),
  bounds: Rect(512, 768, 256, 256),
  cellRange: CellRange(32, 5, 42, 8),
  zoomBucket: ZoomBucket.full,
) → ui.Picture
```

**Rendering order:**
1. Fill background (white)
2. Draw gridlines (if zoom ≥ 40%)
3. Draw cell backgrounds (styled cells)
4. Draw cell text (if zoom ≥ 25%)

**LOD optimizations:**
- Skip gridlines below 40% zoom
- Skip text below 25% zoom
- Adjust gridline stroke width per zoom bucket

### HeaderLayer

Renders row (1, 2, 3...) and column (A, B, C...) headers:

```dart
HeaderLayer {
  renderer: HeaderRenderer,
  getVisibleColumns: (scrollX, width, zoom) → SpanRange,
  getVisibleRows: (scrollY, height, zoom) → SpanRange,
}
```

**Header rendering:**
- Background with subtle gradient
- Centered text labels
- Highlight for selected rows/columns
- Resize handle hit areas (4px tolerance)

---

## Performance Optimizations

### 1. Tile Caching
- 256×256 pixel tiles (optimal GPU texture size)
- LRU cache with 100 tile limit
- Zoom-bucketed tiles (reuse across similar zoom levels)

### 2. Deferred Disposal
- Evicted tiles added to `_pendingDisposal`
- Disposed after paint completes (prevents GPU stalls)

### 3. Incremental Invalidation
- `invalidateRange(CellRange)` - Only affected tiles
- `invalidateZoomBucket(ZoomBucket)` - Only that zoom level
- `invalidateAll()` - Full clear (resize, theme change)

### 4. Level of Detail
- No text rendering below 25% zoom
- No gridlines below 40% zoom
- Gridline stroke width adjusted per zoom

### 5. Pre-allocated Resources
- Paint objects created once in constructor
- Path objects reused for gridlines
- TextPainter disposed after each cell

### 6. Binary Search Lookups
- `SpanList.indexAtPosition()` - O(log n)
- Cell lookup in 50,000 row sheet: ~16 comparisons

### 7. Sparse Data Storage
- Only non-empty cells stored in memory
- Map-based lookup for styles

### Performance Targets

| Metric | Target |
|--------|--------|
| Scroll FPS | 60 |
| Zoom animation FPS | 30 |
| Tile render time | < 8ms |
| Hit test latency | < 100μs |
| Memory per 100 tiles | ~50MB |

---

## Widget Tree Structure

```dart
Worksheet
└── MouseRegion (cursor changes for resize handles)
    └── Listener (pointer events: tap, drag)
        └── GestureDetector (double-tap for edit)
            └── Stack
                ├── TwoDimensionalScrollable
                │   └── WorksheetViewport (tiles)
                │       └── RenderWorksheetViewport
                │           └── TileManager.getTilesForViewport()
                ├── Positioned.fill
                │   └── CustomPaint (SelectionLayer)
                ├── Positioned.fill
                │   └── CustomPaint (HeaderLayer)
                └── Positioned.fill
                    └── IgnorePointer
                        └── CustomPaint (FrozenLayer - future)
```

---

## Key Interfaces

### TileRenderer (Abstract)
```dart
abstract class TileRenderer {
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  });
}
```

### WorksheetData (Abstract)
```dart
abstract class WorksheetData {
  CellValue? getCell(CellCoordinate coord);
  CellStyle? getStyle(CellCoordinate coord);
  void setCell(CellCoordinate coord, CellValue? value);
  Stream<DataChangeEvent> get changes;
}
```

### RenderLayer (Abstract)
```dart
abstract class RenderLayer {
  void paint(Canvas canvas, Size size, ...);
  void dispose();
}
```

---

## Future Considerations

1. **Frozen Panes** - `FrozenLayer` infrastructure exists but not fully wired
2. **Cell Merging** - Would require `MergedCellRegistry` in `LayoutSolver`
3. **Formula Engine** - `CellValue.formula` type exists, needs evaluation
4. **Clipboard Operations** - Copy/paste with range serialization
5. **Undo/Redo** - Command pattern with `DataChangeEvent` history
6. **Virtual Scrolling** - For 1M+ row sheets (current: 50K comfortable)
