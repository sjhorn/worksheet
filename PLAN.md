# Worksheet Widget - Implementation Plan

## Executive Summary

A high-performance Flutter worksheet widget supporting 10%-400% zoom with Excel-like functionality. Built on `TwoDimensionalScrollable`, `LeafRenderObjectWidget`, and GPU-backed tile caching for jank-free scrolling at extreme zoom levels.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Worksheet Widget                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Headers    │  │ Frozen Panes │  │   Cell Editor        │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                  TwoDimensionalScrollable                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              WorksheetViewport (RenderObject)              │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                   TileManager                        │  │  │
│  │  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │  │  │
│  │  │  │Tile │ │Tile │ │Tile │ │Tile │ │Tile │  ...     │  │  │
│  │  │  │ A1  │ │ B1  │ │ C1  │ │ A2  │ │ B2  │          │  │  │
│  │  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘          │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ ZoomController│  │SelectionCtrl │  │   GestureHandler    │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                       WorksheetData                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  SparseData  │  │   CellCache  │  │   ChangeNotifier     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Complete File Structure

```
worksheet/
├── lib/
│   ├── worksheet.dart                          # Public API barrel
│   │
│   └── src/
│       ├── core/
│       │   ├── models/
│       │   │   ├── cell_coordinate.dart        # Immutable (row, col) address
│       │   │   ├── cell_range.dart             # Rectangular cell selection
│       │   │   ├── cell_value.dart             # Union type: text/number/formula/etc
│       │   │   ├── cell_style.dart             # Font, color, borders, alignment
│       │   │   ├── column_definition.dart      # Width, visibility, freeze state
│       │   │   ├── row_definition.dart         # Height, visibility, freeze state
│       │   │   ├── viewport_metrics.dart       # Scroll offset, visible range, zoom
│       │   │   └── worksheet_config.dart       # Global settings, defaults
│       │   │
│       │   ├── data/
│       │   │   ├── worksheet_data.dart         # Abstract data interface
│       │   │   ├── sparse_worksheet_data.dart  # Map-based sparse storage
│       │   │   ├── cell_cache.dart             # LRU cache for computed values
│       │   │   ├── data_change_event.dart      # Granular change events
│       │   │   └── data_change_notifier.dart   # Pub/sub for data mutations
│       │   │
│       │   └── geometry/
│       │       ├── span_list.dart              # Cumulative row/col sizes
│       │       ├── layout_solver.dart          # Position ↔ index conversion
│       │       ├── visible_range_calculator.dart # Viewport → CellRange
│       │       └── zoom_transformer.dart       # Zoom-aware coordinate math
│       │
│       ├── rendering/
│       │   ├── tile/
│       │   │   ├── tile.dart                   # Single tile: Picture + metadata
│       │   │   ├── tile_coordinate.dart        # Tile grid position
│       │   │   ├── tile_manager.dart           # Tile lifecycle orchestration
│       │   │   ├── tile_cache.dart             # LRU Picture cache (zoom-bucketed)
│       │   │   ├── tile_painter.dart           # Paints cells into Picture
│       │   │   └── tile_config.dart            # Tile size, cache limits
│       │   │
│       │   ├── painters/
│       │   │   ├── cell_renderer.dart          # Abstract cell painting
│       │   │   ├── text_cell_renderer.dart     # Text/number cells
│       │   │   ├── grid_line_renderer.dart     # Batched gridlines
│       │   │   ├── selection_renderer.dart     # Selection highlight overlay
│       │   │   └── header_renderer.dart        # Row/column header painting
│       │   │
│       │   ├── layers/
│       │   │   ├── layer.dart                  # Abstract render layer
│       │   │   ├── cell_layer.dart             # Base cells + gridlines
│       │   │   ├── selection_layer.dart        # Selection overlay
│       │   │   ├── frozen_layer.dart           # Frozen panes
│       │   │   └── layer_compositor.dart       # Combines layers
│       │   │
│       │   ├── worksheet_render_object.dart    # Main LeafRenderObject
│       │   └── paint_resources.dart            # Pre-allocated Paint objects
│       │
│       ├── scrolling/
│       │   ├── worksheet_viewport.dart         # TwoDimensionalViewport subclass
│       │   ├── worksheet_render_viewport.dart  # RenderTwoDimensionalViewport
│       │   ├── worksheet_scroll_delegate.dart  # TwoDimensionalChildDelegate
│       │   ├── scroll_physics.dart             # Custom momentum physics
│       │   └── scroll_anchor.dart              # Position preservation on zoom
│       │
│       ├── interaction/
│       │   ├── controllers/
│       │   │   ├── zoom_controller.dart        # Zoom level + animations
│       │   │   ├── selection_controller.dart   # Selection state machine
│       │   │   └── edit_controller.dart        # Cell editing orchestration
│       │   │
│       │   ├── gestures/
│       │   │   ├── gesture_handler.dart        # Unified gesture processing
│       │   │   ├── tap_handler.dart            # Cell selection
│       │   │   ├── drag_handler.dart           # Range selection, scrolling
│       │   │   ├── scale_handler.dart          # Pinch-to-zoom
│       │   │   └── keyboard_handler.dart       # Arrow keys, shortcuts
│       │   │
│       │   └── hit_testing/
│       │       ├── hit_test_result.dart        # What was hit (cell, header, etc)
│       │       └── hit_tester.dart             # Coordinate → element resolution
│       │
│       ├── widgets/
│       │   ├── worksheet.dart                  # Main public StatefulWidget
│       │   ├── worksheet_controller.dart       # Programmatic control
│       │   ├── worksheet_theme.dart            # Theming/styling
│       │   ├── cell_editor_overlay.dart        # Floating text editor
│       │   ├── context_menu.dart               # Right-click menu
│       │   └── headers/
│       │       ├── column_header_widget.dart   # Column letters/numbers
│       │       └── row_header_widget.dart      # Row numbers
│       │
│       └── utils/
│           ├── extensions/
│           │   ├── rect_extensions.dart
│           │   ├── offset_extensions.dart
│           │   └── canvas_extensions.dart
│           ├── math_utils.dart
│           ├── paint_utils.dart
│           └── platform_utils.dart
│
├── test/
│   ├── core/
│   │   ├── models/
│   │   │   ├── cell_coordinate_test.dart
│   │   │   ├── cell_range_test.dart
│   │   │   └── cell_value_test.dart
│   │   ├── data/
│   │   │   ├── sparse_worksheet_data_test.dart
│   │   │   └── cell_cache_test.dart
│   │   └── geometry/
│   │       ├── span_list_test.dart
│   │       ├── layout_solver_test.dart
│   │       └── visible_range_calculator_test.dart
│   │
│   ├── rendering/
│   │   ├── tile/
│   │   │   ├── tile_manager_test.dart
│   │   │   └── tile_cache_test.dart
│   │   └── painters/
│   │       └── cell_renderer_test.dart
│   │
│   ├── scrolling/
│   │   └── worksheet_viewport_test.dart
│   │
│   ├── interaction/
│   │   ├── zoom_controller_test.dart
│   │   ├── selection_controller_test.dart
│   │   └── hit_tester_test.dart
│   │
│   ├── widgets/
│   │   └── worksheet_test.dart
│   │
│   ├── integration/
│   │   ├── scroll_zoom_integration_test.dart
│   │   ├── large_dataset_test.dart
│   │   └── memory_leak_test.dart
│   │
│   ├── benchmarks/
│   │   ├── tile_render_benchmark.dart
│   │   ├── scroll_performance_benchmark.dart
│   │   └── hit_test_benchmark.dart
│   │
│   └── helpers/
│       ├── test_data_factory.dart
│       ├── mock_worksheet_data.dart
│       └── render_test_helpers.dart
│
├── example/
│   └── lib/
│       └── main.dart
│
├── CLAUDE.md
├── PLAN.md
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## Detailed Component Specifications

### 1. Core Models

#### CellCoordinate
```dart
/// Immutable cell address
@immutable
class CellCoordinate {
  final int row;
  final int column;
  
  const CellCoordinate(this.row, this.column)
      : assert(row >= 0),
        assert(column >= 0);
  
  /// Excel-style notation: A1, B2, AA100
  factory CellCoordinate.fromNotation(String notation);
  
  String toNotation(); // -> "A1"
  
  CellCoordinate offset(int rowDelta, int colDelta);
  
  @override
  bool operator ==(Object other);
  
  @override
  int get hashCode;
}
```

**Tests:**
- Construction with valid/invalid indices
- fromNotation parsing (A1, Z1, AA1, AAA1)
- toNotation conversion
- Equality and hashCode
- offset() behavior at boundaries

#### SpanList
```dart
/// Efficient cumulative size storage for O(log n) lookups
class SpanList {
  final List<double> _sizes;
  late final List<double> _cumulative;
  final double defaultSize;
  
  SpanList({
    required int count,
    required this.defaultSize,
    Map<int, double>? customSizes,
  });
  
  /// O(1) - Get size at index
  double sizeAt(int index);
  
  /// O(1) - Get position of index start
  double positionAt(int index);
  
  /// O(log n) - Find index containing position
  int indexAtPosition(double position);
  
  /// O(n) - Rebuild cumulative after size change
  void setSize(int index, double size);
  
  /// Total content size
  double get totalSize;
}
```

**Tests:**
- Default sizes applied correctly
- Custom sizes override defaults
- positionAt matches cumulative sum
- indexAtPosition binary search accuracy
- Edge cases: position 0, position at boundary, beyond total
- setSize triggers rebuild

### 2. Data Layer

#### WorksheetData Interface
```dart
/// Abstract interface for worksheet data access
abstract class WorksheetData {
  /// Get cell value (null if empty)
  CellValue? getCell(CellCoordinate coord);
  
  /// Get cell style (null for default)
  CellStyle? getStyle(CellCoordinate coord);
  
  /// Set cell value
  void setCell(CellCoordinate coord, CellValue? value);
  
  /// Set cell style
  void setStyle(CellCoordinate coord, CellStyle? style);
  
  /// Batch operations for performance
  void batchUpdate(void Function(WorksheetDataBatch batch) updates);
  
  /// Change stream for reactive updates
  Stream<DataChangeEvent> get changes;
  
  /// Row/column counts
  int get rowCount;
  int get columnCount;
}
```

#### SparseWorksheetData
```dart
/// Memory-efficient sparse storage implementation
class SparseWorksheetData implements WorksheetData {
  final Map<CellCoordinate, CellValue> _values = {};
  final Map<CellCoordinate, CellStyle> _styles = {};
  final _changeController = StreamController<DataChangeEvent>.broadcast();
  
  // Track actual data bounds for optimization
  int _maxPopulatedRow = 0;
  int _maxPopulatedColumn = 0;
  
  @override
  CellValue? getCell(CellCoordinate coord) => _values[coord];
  
  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    if (value == null) {
      _values.remove(coord);
    } else {
      _values[coord] = value;
      _updateBounds(coord);
    }
    _changeController.add(DataChangeEvent.cell(coord));
  }
}
```

**Tests:**
- Get/set operations
- Null handling (empty cells)
- Change event emission
- Batch update atomicity
- Memory efficiency with large sparse data
- Bounds tracking

### 3. Tile Rendering System

#### Tile
```dart
/// Single cached tile with GPU-backed Picture
class Tile {
  final TileCoordinate coordinate;
  final ZoomBucket zoomBucket;
  final CellRange cellRange;  // Cells covered by this tile
  
  ui.Picture? _picture;
  DateTime _createdAt;
  bool _dirty = false;
  
  bool get isValid => _picture != null && !_dirty;
  
  void paint(Canvas canvas, Offset offset) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }
  
  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
```

#### TileManager
```dart
/// Orchestrates tile lifecycle and rendering
class TileManager {
  final TileCache _cache;
  final TilePainter _painter;
  final WorksheetData _data;
  final SpanList _rows;
  final SpanList _columns;
  
  static const int tileSize = 256;
  
  /// Get tiles needed for current viewport
  Iterable<Tile> getTilesForViewport({
    required Rect viewport,
    required double zoom,
    required int prefetchRings,
  }) sync* {
    final bucket = ZoomBucket.fromZoom(zoom);
    final tileRange = _calculateTileRange(viewport, zoom, prefetchRings);
    
    for (var ty = tileRange.startY; ty <= tileRange.endY; ty++) {
      for (var tx = tileRange.startX; tx <= tileRange.endX; tx++) {
        final coord = TileCoordinate(tx, ty);
        var tile = _cache.get(coord, bucket);
        
        if (tile == null || !tile.isValid) {
          tile = _createTile(coord, bucket);
          _cache.put(coord, bucket, tile);
        }
        
        yield tile;
      }
    }
  }
  
  /// Invalidate tiles affected by data change
  void invalidateCells(CellRange range) {
    final affectedTiles = _getTilesIntersecting(range);
    for (final coord in affectedTiles) {
      _cache.invalidate(coord);
    }
  }
  
  Tile _createTile(TileCoordinate coord, ZoomBucket bucket) {
    final cellRange = _cellRangeForTile(coord, bucket);
    final picture = _painter.paint(cellRange, bucket.representativeZoom);
    return Tile(
      coordinate: coord,
      zoomBucket: bucket,
      cellRange: cellRange,
      picture: picture,
    );
  }
}
```

#### ZoomBucket
```dart
/// Groups similar zoom levels to reduce cache thrashing
enum ZoomBucket {
  ultraLow(0.10, 0.25),   // 10-25%
  low(0.25, 0.50),        // 25-50%
  medium(0.50, 1.00),     // 50-100%
  high(1.00, 2.00),       // 100-200%
  ultraHigh(2.00, 4.00);  // 200-400%
  
  final double minZoom;
  final double maxZoom;
  
  const ZoomBucket(this.minZoom, this.maxZoom);
  
  double get representativeZoom => (minZoom + maxZoom) / 2;
  
  static ZoomBucket fromZoom(double zoom) {
    for (final bucket in values) {
      if (zoom >= bucket.minZoom && zoom < bucket.maxZoom) {
        return bucket;
      }
    }
    return ultraHigh;
  }
}
```

#### TilePainter with LOD
```dart
/// Paints cells to Picture with level-of-detail
class TilePainter {
  final WorksheetData _data;
  final CellRenderer _cellRenderer;
  final GridLineRenderer _gridRenderer;
  final PaintResources _paints;
  
  ui.Picture paint(CellRange range, double zoom) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Determine LOD based on zoom
    final lod = _determineLOD(zoom);
    
    // Paint cells
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var col = range.startCol; col <= range.endCol; col++) {
        final coord = CellCoordinate(row, col);
        final bounds = _getCellBounds(coord);
        final value = _data.getCell(coord);
        final style = _data.getStyle(coord);
        
        _cellRenderer.paint(
          canvas: canvas,
          bounds: bounds,
          value: value,
          style: style,
          lod: lod,
        );
      }
    }
    
    // Paint gridlines (batched)
    _gridRenderer.paint(canvas, range);
    
    return recorder.endRecording();
  }
  
  LevelOfDetail _determineLOD(double zoom) {
    if (zoom < 0.25) return LevelOfDetail.minimal;    // Fill only
    if (zoom < 0.50) return LevelOfDetail.low;        // Fill + border
    if (zoom < 1.00) return LevelOfDetail.medium;     // + truncated text
    return LevelOfDetail.full;                         // Full rendering
  }
}

enum LevelOfDetail { minimal, low, medium, full }
```

**Tests:**
- Tile creation and Picture generation
- Cache hit/miss behavior
- Invalidation propagation
- ZoomBucket boundaries
- LOD selection at various zoom levels
- Memory disposal

### 4. Scrolling Integration

#### WorksheetRenderViewport
```dart
/// Custom viewport for tile-based rendering
class WorksheetRenderViewport extends RenderTwoDimensionalViewport {
  WorksheetRenderViewport({
    required super.delegate,
    required super.horizontalOffset,
    required super.verticalOffset,
    required TileManager tileManager,
    required ZoomController zoomController,
  }) : _tileManager = tileManager,
       _zoomController = zoomController;
  
  TileManager _tileManager;
  ZoomController _zoomController;
  
  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final zoom = _zoomController.value;
    
    // Get visible tiles
    final tiles = _tileManager.getTilesForViewport(
      viewport: Rect.fromLTWH(
        horizontalOffset.pixels,
        verticalOffset.pixels,
        size.width,
        size.height,
      ),
      zoom: zoom,
      prefetchRings: 1,
    );
    
    // Paint tiles
    canvas.save();
    canvas.scale(zoom);
    
    for (final tile in tiles) {
      final tileOffset = _tileManager.getScreenOffset(tile.coordinate);
      canvas.save();
      canvas.translate(tileOffset.dx, tileOffset.dy);
      tile.paint(canvas, Offset.zero);
      canvas.restore();
    }
    
    canvas.restore();
  }
  
  @override
  void layoutChildSequence() {
    // No child widgets - we paint directly
  }
}
```

### 5. Zoom System

#### ZoomController
```dart
/// Manages zoom state with animation support
class ZoomController extends ValueNotifier<double> {
  ZoomController({
    double initialZoom = 1.0,
    this.minZoom = 0.10,
    this.maxZoom = 4.00,
  }) : super(initialZoom.clamp(minZoom, maxZoom));
  
  final double minZoom;
  final double maxZoom;
  
  AnimationController? _animationController;
  
  /// Animate to target zoom
  Future<void> animateTo(
    double target, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOut,
    Offset? focalPoint,
  }) async {
    target = target.clamp(minZoom, maxZoom);
    
    _animationController?.dispose();
    _animationController = AnimationController(
      vsync: vsync,
      duration: duration,
    );
    
    final startZoom = value;
    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: curve,
    );
    
    animation.addListener(() {
      value = lerpDouble(startZoom, target, animation.value)!;
    });
    
    await _animationController!.forward();
  }
  
  /// Zoom relative to current level
  void zoomBy(double factor, {Offset? focalPoint}) {
    value = (value * factor).clamp(minZoom, maxZoom);
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
}
```

### 6. Interaction System

#### SelectionController
```dart
/// Manages selection state
class SelectionController extends ChangeNotifier {
  CellCoordinate? _anchor;
  CellCoordinate? _focus;
  SelectionMode _mode = SelectionMode.single;
  
  CellCoordinate? get anchor => _anchor;
  CellCoordinate? get focus => _focus;
  
  /// Current selection as range (handles anchor > focus)
  CellRange? get selectedRange {
    if (_anchor == null || _focus == null) return null;
    return CellRange.fromCoordinates(_anchor!, _focus!);
  }
  
  void selectCell(CellCoordinate coord) {
    _anchor = coord;
    _focus = coord;
    _mode = SelectionMode.single;
    notifyListeners();
  }
  
  void extendSelection(CellCoordinate coord) {
    _focus = coord;
    _mode = SelectionMode.range;
    notifyListeners();
  }
  
  void clear() {
    _anchor = null;
    _focus = null;
    notifyListeners();
  }
}

enum SelectionMode { single, range, discontinuous }
```

#### HitTester
```dart
/// Resolves screen coordinates to worksheet elements
class HitTester {
  final SpanList _rows;
  final SpanList _columns;
  final ZoomController _zoomController;
  final ViewportMetrics _viewport;
  
  HitTestResult hitTest(Offset screenPosition) {
    final zoom = _zoomController.value;
    
    // Convert screen to worksheet coordinates
    final worksheetPosition = Offset(
      (_viewport.scrollOffsetX + screenPosition.dx) / zoom,
      (_viewport.scrollOffsetY + screenPosition.dy) / zoom,
    );
    
    // Find cell at position
    final row = _rows.indexAtPosition(worksheetPosition.dy);
    final col = _columns.indexAtPosition(worksheetPosition.dx);
    
    if (row < 0 || col < 0) {
      return HitTestResult.none();
    }
    
    return HitTestResult.cell(CellCoordinate(row, col));
  }
}

class HitTestResult {
  final HitTestType type;
  final CellCoordinate? cell;
  final int? headerIndex;
  
  const HitTestResult.cell(this.cell)
      : type = HitTestType.cell,
        headerIndex = null;
  
  const HitTestResult.none()
      : type = HitTestType.none,
        cell = null,
        headerIndex = null;
}

enum HitTestType { none, cell, rowHeader, columnHeader, resizeHandle }
```

---

## Performance Specifications

### Target Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Scroll FPS | 60 fps | DevTools frame chart |
| Zoom FPS | 30 fps (during animation) | DevTools frame chart |
| Tile render time | < 8ms | Stopwatch in paint() |
| Hit test latency | < 100μs | Benchmark |
| Memory per 1M cells | < 100MB (sparse) | Observatory |
| Time to first paint | < 200ms | Timeline |

### Optimization Strategies

#### 1. Paint Optimization
```dart
/// Pre-allocate all Paint objects
class PaintResources {
  static final gridLinePaint = Paint()
    ..color = const Color(0xFFE0E0E0)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  
  static final selectionFillPaint = Paint()
    ..color = const Color(0x333D8BFF)
    ..style = PaintingStyle.fill;
  
  // ... more pre-allocated paints
}
```

#### 2. Batched Grid Drawing
```dart
class GridLineRenderer {
  void paint(Canvas canvas, CellRange range, SpanList rows, SpanList cols) {
    final horizontalPath = Path();
    final verticalPath = Path();
    
    // Batch all horizontal lines
    for (var row = range.startRow; row <= range.endRow + 1; row++) {
      final y = rows.positionAt(row);
      horizontalPath.moveTo(cols.positionAt(range.startCol), y);
      horizontalPath.lineTo(cols.positionAt(range.endCol + 1), y);
    }
    
    // Batch all vertical lines
    for (var col = range.startCol; col <= range.endCol + 1; col++) {
      final x = cols.positionAt(col);
      verticalPath.moveTo(x, rows.positionAt(range.startRow));
      verticalPath.lineTo(x, rows.positionAt(range.endRow + 1));
    }
    
    // Two draw calls total
    canvas.drawPath(horizontalPath, PaintResources.gridLinePaint);
    canvas.drawPath(verticalPath, PaintResources.gridLinePaint);
  }
}
```

#### 3. Level of Detail Rendering
```dart
class CellRenderer {
  void paint({
    required Canvas canvas,
    required Rect bounds,
    required CellValue? value,
    required CellStyle? style,
    required LevelOfDetail lod,
  }) {
    final effectiveStyle = style ?? CellStyle.defaultStyle;
    
    // Always draw background if not default
    if (effectiveStyle.backgroundColor != null) {
      canvas.drawRect(bounds, _getFillPaint(effectiveStyle));
    }
    
    // Skip text at low zoom
    if (lod == LevelOfDetail.minimal) return;
    
    // Draw border at medium zoom
    if (lod.index >= LevelOfDetail.low.index) {
      canvas.drawRect(bounds, _getBorderPaint(effectiveStyle));
    }
    
    // Draw text only at higher zoom
    if (lod.index >= LevelOfDetail.medium.index && value != null) {
      _paintText(canvas, bounds, value, effectiveStyle, lod);
    }
  }
}
```

---

## Testing Strategy

### Unit Test Coverage Requirements

| Component | Min Coverage | Critical Paths |
|-----------|--------------|----------------|
| Models | 95% | Equality, hashCode, serialization |
| SpanList | 100% | Binary search, cumulative math |
| WorksheetData | 90% | CRUD, change events |
| TileManager | 85% | Cache hit/miss, invalidation |
| ZoomController | 90% | Clamping, animation |
| HitTester | 100% | Coordinate transforms |

### Test Categories

#### 1. Property-Based Tests (SpanList)
```dart
void main() {
  group('SpanList property tests', () {
    test('positionAt(indexAtPosition(p)) ~= p for any valid position', () {
      final spanList = SpanList(count: 1000, defaultSize: 25.0);
      
      for (var p = 0.0; p < spanList.totalSize; p += 100.0) {
        final index = spanList.indexAtPosition(p);
        final reconstructed = spanList.positionAt(index);
        expect(reconstructed, lessThanOrEqualTo(p));
        expect(reconstructed + spanList.sizeAt(index), greaterThan(p));
      }
    });
  });
}
```

#### 2. Golden Tests (Rendering)
```dart
void main() {
  testWidgets('cell renders correctly at 100% zoom', (tester) async {
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          painter: CellTestPainter(
            value: CellValue.text('Hello'),
            style: CellStyle.defaultStyle,
          ),
        ),
      ),
    );
    
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/cell_text_100.png'),
    );
  });
}
```

#### 3. Integration Tests
```dart
void main() {
  testWidgets('scroll and zoom integration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Worksheet(
          data: MockWorksheetData.generate(rows: 1000, columns: 100),
        ),
      ),
    );
    
    // Scroll to middle
    await tester.fling(find.byType(Worksheet), const Offset(-500, -500), 1000);
    await tester.pumpAndSettle();
    
    // Zoom out
    await tester.sendKeyEvent(LogicalKeyboardKey.minus, 
        character: '-', 
        physicalKey: PhysicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    
    // Verify no jank
    final binding = TestWidgetsFlutterBinding.instance;
    expect(binding.framesBuilt, greaterThan(0));
  });
}
```

#### 4. Performance Benchmarks
```dart
void main() {
  group('Performance benchmarks', () {
    test('tile render under 8ms', () {
      final painter = TilePainter(/* ... */);
      final range = CellRange(0, 0, 20, 10); // ~200 cells
      
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final picture = painter.paint(range, 1.0);
        picture.dispose();
      }
      stopwatch.stop();
      
      final avgMs = stopwatch.elapsedMicroseconds / 100 / 1000;
      expect(avgMs, lessThan(8.0));
    });
    
    test('hit test under 100μs', () {
      final hitTester = HitTester(/* 10000 rows, 1000 cols */);
      
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        hitTester.hitTest(Offset(i % 1000.0, i % 500.0));
      }
      stopwatch.stop();
      
      final avgUs = stopwatch.elapsedMicroseconds / 10000;
      expect(avgUs, lessThan(100.0));
    });
  });
}
```

---

## Implementation Timeline

### Week 1: Core Foundation
- [ ] CellCoordinate, CellRange, CellValue models
- [ ] SpanList with full test coverage
- [ ] WorksheetData interface + SparseWorksheetData

### Week 2: Geometry & Layout
- [ ] LayoutSolver
- [ ] VisibleRangeCalculator
- [ ] ZoomTransformer
- [ ] Unit tests for all geometry

### Week 3: Tile System
- [ ] Tile, TileCoordinate, TileConfig
- [ ] TilePainter with LOD
- [ ] TileCache with LRU eviction

### Week 4: Tile Manager & Basic Rendering
- [ ] TileManager orchestration
- [ ] WorksheetRenderObject basics
- [ ] First visual output

### Week 5: Scroll Integration
- [ ] WorksheetViewport
- [ ] WorksheetScrollDelegate
- [ ] Custom scroll physics

### Week 6: Zoom System
- [ ] ZoomController
- [ ] Zoom-bucketed caching
- [ ] Pinch-to-zoom gesture

### Week 7: Interaction
- [ ] HitTester
- [ ] SelectionController
- [ ] Keyboard navigation

### Week 8: Polish & Editing
- [ ] Cell editing overlay
- [ ] Frozen panes
- [ ] Headers
- [ ] Performance profiling & optimization

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Tile cache memory overflow | Aggressive LRU eviction, memory pressure monitoring |
| Jank at 10% zoom | LOD rendering, tile size tuning, prefetch strategy |
| Hit test inaccuracy | Comprehensive coordinate transform tests |
| Zoom animation stuttering | Fallback to scaled tiles during animation |
| Large dataset slowdown | Sparse data structures, virtual rendering |

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  golden_toolkit: ^0.15.0
  benchmark_harness: ^2.2.0
```

---

## Success Criteria

1. ✅ Smooth 60fps scrolling at all zoom levels (10%-400%)
2. ✅ Sub-8ms tile render time
3. ✅ Memory-efficient for 1M+ cell sparse worksheets
4. ✅ 80%+ code coverage
5. ✅ All SOLID principles applied
6. ✅ Comprehensive documentation