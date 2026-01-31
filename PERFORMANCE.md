# Performance Guide

Optimization strategies for the worksheet widget, including tile caching, large dataset handling, and memory profiling.

## Understanding the Tile Cache

The worksheet uses GPU-backed tile caching for high-performance rendering. Understanding how it works helps optimize your application.

### Tile Basics

- **Tile Size**: 256×256 pixels (optimal for GPU textures)
- **Rendering**: Each tile is rendered to a `ui.Picture` (GPU-backed)
- **Cache Strategy**: LRU (Least Recently Used) eviction
- **Default Limit**: 100 tiles maximum

### How Tiles Work

```
┌──────────────────────────────────────────────────────────┐
│ Viewport (visible screen area)                           │
│ ┌────────┬────────┬────────┬────────┐                   │
│ │ Tile   │ Tile   │ Tile   │ Tile   │ ← Each 256×256   │
│ │ (0,0)  │ (1,0)  │ (2,0)  │ (3,0)  │   pixels         │
│ ├────────┼────────┼────────┼────────┤                   │
│ │ Tile   │ Tile   │ Tile   │ Tile   │                   │
│ │ (0,1)  │ (1,1)  │ (2,1)  │ (3,1)  │                   │
│ └────────┴────────┴────────┴────────┘                   │
│                                                          │
│ + 1 ring of prefetched tiles around the visible area    │
└──────────────────────────────────────────────────────────┘
```

When you scroll, the `TileManager`:
1. Calculates which tiles are now visible
2. Returns cached tiles (cache hit) or renders new ones (cache miss)
3. Prefetches tiles just outside the viewport
4. Evicts oldest unused tiles when cache is full

### Zoom Buckets

Tiles are cached per zoom bucket to avoid re-rendering at similar zoom levels:

| Bucket | Zoom Range | Tile Coverage | Features Rendered |
|--------|------------|---------------|-------------------|
| `tenth` | 10-24% | 10× (2560px) | Background only |
| `quarter` | 25-39% | 4× (1024px) | + Text |
| `forty` | 40-49% | 2× (512px) | + Gridlines |
| `half` | 50-99% | 2× (512px) | All |
| `full` | 100-199% | 1× (256px) | All |
| `twoX` | 200-299% | 0.5× (128px) | All |
| `quadruple` | 300-400% | 0.25× (64px) | All |

At lower zoom levels, tiles cover more worksheet area but contain less detail.

---

## TileConfig Tuning

Customize tile behavior with `TileConfig`:

```dart
TileConfig(
  tileSize: 256,       // Pixel dimensions (256 is optimal)
  maxCachedTiles: 100, // LRU cache limit
  prefetchRings: 1,    // Rings of tiles to prefetch
)
```

### When to Adjust tileSize

**Keep at 256** (default) for most cases. This is the optimal GPU texture size.

Consider 512 for:
- Very high-resolution displays (4K+)
- Fewer tiles to manage (simpler caching)
- Slight reduction in tile boundaries visible during scroll

```dart
// For high-DPI displays
TileConfig(tileSize: 512)
```

### When to Adjust maxCachedTiles

**Default: 100 tiles** (~50MB memory for typical content)

| Cache Size | Memory | Use Case |
|------------|--------|----------|
| 50 | ~25MB | Memory-constrained devices |
| 100 | ~50MB | Standard (default) |
| 200 | ~100MB | Large viewports, zoom-heavy usage |
| 500 | ~250MB | Desktop with abundant RAM |

```dart
// For memory-constrained devices
TileConfig(maxCachedTiles: 50)

// For desktops with large displays
TileConfig(maxCachedTiles: 300)
```

### When to Adjust prefetchRings

**Default: 1 ring** (tiles immediately outside viewport)

| Rings | Prefetch Tiles | Use Case |
|-------|----------------|----------|
| 0 | None | Minimal memory, visible stutter |
| 1 | ~16 tiles | Standard (default) |
| 2 | ~32 tiles | Fast scrolling, smooth experience |
| 3 | ~48 tiles | Very fast scrolling expected |

```dart
// For butter-smooth scrolling on capable devices
TileConfig(prefetchRings: 2)

// For minimal memory usage
TileConfig(prefetchRings: 0)
```

---

## Large Dataset Strategies (50K+ Rows)

### Sparse Data Storage

`SparseWorksheetData` uses `Map<CellCoordinate, CellValue>` internally, so memory usage scales with populated cells, not total grid size:

```dart
// This is memory-efficient even for huge grids
final data = SparseWorksheetData(
  rowCount: 1048576,  // 1M+ rows
  columnCount: 16384, // 16K columns
);

// Only populated cells use memory
for (var i = 0; i < 50000; i++) {
  data[(i, 0)] = Cell.text('Row $i');
}
// Memory usage: ~50K cells, not 17 billion
```

### Memory Usage Estimates

| Cells Populated | Approximate Memory |
|-----------------|-------------------|
| 1,000 | ~200 KB |
| 10,000 | ~2 MB |
| 100,000 | ~20 MB |
| 500,000 | ~100 MB |
| 1,000,000 | ~200 MB |

(Varies based on cell content length and styles)

### Batch Updates for Performance

When loading large amounts of data, use batch updates:

```dart
// Bad: Individual updates trigger change notifications each time
for (var i = 0; i < 100000; i++) {
  data[(i, 0)] = Cell.number(i.toDouble());
}

// Good: Use microtasks to batch UI updates
Future<void> loadLargeDataset() async {
  const batchSize = 1000;

  for (var start = 0; start < 100000; start += batchSize) {
    // Process batch
    await Future.microtask(() {
      for (var i = start; i < start + batchSize; i++) {
        data[(i, 0)] = Cell.number(i.toDouble());
      }
    });

    // Allow UI to breathe
    await Future.delayed(Duration.zero);
  }
}
```

### Virtual Data Patterns

For truly massive datasets, load data on-demand:

```dart
class VirtualWorksheetData implements WorksheetData {
  final Map<CellCoordinate, CellValue> _cache = {};
  final int rowCount;
  final int columnCount;
  final Future<CellValue?> Function(CellCoordinate) _fetcher;

  VirtualWorksheetData({
    required this.rowCount,
    required this.columnCount,
    required Future<CellValue?> Function(CellCoordinate) fetcher,
  }) : _fetcher = fetcher;

  @override
  CellValue? getCell(CellCoordinate coord) {
    // Return cached value or fetch asynchronously
    if (_cache.containsKey(coord)) {
      return _cache[coord];
    }

    // Trigger async fetch (will update on next frame)
    _fetchCell(coord);
    return null;
  }

  Future<void> _fetchCell(CellCoordinate coord) async {
    final value = await _fetcher(coord);
    if (value != null) {
      _cache[coord] = value;
      // Notify listeners to trigger repaint
    }
  }

  // ... implement other methods
}
```

---

## Memory Profiling Techniques

### Using Flutter DevTools

1. Run your app in profile mode:
   ```bash
   flutter run --profile --trace-skia
   ```

2. Open DevTools Memory tab

3. Monitor:
   - **Heap usage**: Should stabilize, not continuously grow
   - **Object count**: Watch for `ui.Picture` count matching tile cache size
   - **GC activity**: Frequent GC indicates memory pressure

### Identifying Memory Leaks

Common leak sources:

```dart
// LEAK: Listeners not removed
@override
void dispose() {
  // Missing: _controller.removeListener(_onChanged);
  super.dispose();
}

// LEAK: Subscriptions not cancelled
StreamSubscription? _subscription;

@override
void dispose() {
  _subscription?.cancel();  // Don't forget!
  super.dispose();
}

// LEAK: Large objects retained in state
class _MyWidgetState extends State<MyWidget> {
  List<LargeObject> _data = [];  // If widget removed, this persists

  @override
  void dispose() {
    _data.clear();  // Help GC
    super.dispose();
  }
}
```

### Monitoring Tile Cache

```dart
// Debug helper to monitor cache
void debugTileCache(TileManager manager) {
  print('Cached tiles: ${manager.cachedTileCount}');
  print('Cache hits: ${manager.cacheHits}');
  print('Cache misses: ${manager.cacheMisses}');
  print('Hit rate: ${(manager.cacheHits / (manager.cacheHits + manager.cacheMisses) * 100).toStringAsFixed(1)}%');
}
```

---

## Zoom Level Considerations

### Level of Detail (LOD) Rendering

The tile painter automatically reduces detail at lower zoom levels:

| Zoom | Gridlines | Text | Notes |
|------|-----------|------|-------|
| <25% | Hidden | Hidden | Only cell backgrounds |
| 25-39% | Hidden | Visible | Text without gridlines |
| 40%+ | Visible | Visible | Full detail |

### Optimizing Zoom Transitions

Zoom changes invalidate tiles in the current zoom bucket. Minimize thrashing by:

1. **Debouncing zoom gestures**:
   ```dart
   Timer? _zoomDebounce;

   void onZoomGesture(double newZoom) {
     _zoomDebounce?.cancel();
     _zoomDebounce = Timer(const Duration(milliseconds: 50), () {
       _controller.setZoom(newZoom);
     });
   }
   ```

2. **Using zoom presets** (avoids bucket boundary crossing):
   ```dart
   const zoomPresets = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0];
   ```

---

## Invalidation Strategies

### invalidateRange vs invalidateAll

```dart
// Use invalidateRange for targeted updates
// Only affected tiles are re-rendered
tileManager.invalidateRange(CellRange(5, 2, 10, 5));

// Use invalidateAll sparingly
// Clears entire cache, forces full re-render
tileManager.invalidateAll();
```

### When to Use Each

| Scenario | Method | Why |
|----------|--------|-----|
| Cell value changed | `invalidateRange` | Only affected tiles |
| Cell style changed | `invalidateRange` | Only affected tiles |
| Multiple scattered edits | Multiple `invalidateRange` | Still targeted |
| Column width changed | `invalidateAll` | Affects all tiles in column |
| Row height changed | `invalidateAll` | Affects all tiles in row |
| Theme changed | `invalidateAll` | Everything needs repaint |
| Font size changed | `invalidateAll` | Text layout changes |

### Efficient Batch Invalidation

```dart
// Bad: Multiple invalidations during batch update
for (var cell in updatedCells) {
  data.setCell(cell, newValue);
  tileManager.invalidateRange(CellRange.single(cell));  // Wasteful!
}

// Good: Calculate bounding range, invalidate once
final cells = updatedCells.toList();
if (cells.isNotEmpty) {
  var minRow = cells.first.row;
  var maxRow = cells.first.row;
  var minCol = cells.first.column;
  var maxCol = cells.first.column;

  for (final cell in cells) {
    minRow = min(minRow, cell.row);
    maxRow = max(maxRow, cell.row);
    minCol = min(minCol, cell.column);
    maxCol = max(maxCol, cell.column);
  }

  // Update all data first
  for (final cell in cells) {
    data.setCell(cell, newValue);
  }

  // Single invalidation
  tileManager.invalidateRange(CellRange(minRow, minCol, maxRow, maxCol));
}
```

---

## Benchmarking Scroll/Zoom Performance

### Performance Targets

| Metric | Target | Acceptable |
|--------|--------|------------|
| Scroll FPS | 60 | 45+ |
| Zoom Animation FPS | 30 | 24+ |
| Tile Render Time | <8ms | <16ms |
| Hit Test Latency | <100μs | <500μs |
| Initial Load (50K rows) | <1s | <3s |

### Measuring Frame Rate

```dart
import 'dart:developer' as developer;

class PerformanceMonitor {
  final List<Duration> _frameTimes = [];
  DateTime? _lastFrameTime;

  void recordFrame() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      _frameTimes.add(now.difference(_lastFrameTime!));
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }
    }
    _lastFrameTime = now;
  }

  double get averageFps {
    if (_frameTimes.isEmpty) return 0;
    final avgMs = _frameTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) / _frameTimes.length / 1000;
    return 1000 / avgMs;
  }

  void logPerformance() {
    developer.log('Average FPS: ${averageFps.toStringAsFixed(1)}');
  }
}
```

### Profiling Paint Performance

```dart
// Wrap paint logic with Timeline events
import 'dart:developer' as developer;

void paint(Canvas canvas, Size size) {
  developer.Timeline.startSync('WorksheetViewport.paint');
  try {
    // ... painting logic
  } finally {
    developer.Timeline.finishSync();
  }
}
```

View in Flutter DevTools → Performance tab.

---

## Platform-Specific Optimizations

### Desktop (macOS, Windows, Linux)

```dart
// Larger cache for bigger screens
TileConfig(
  maxCachedTiles: 300,
  prefetchRings: 2,
)

// Enable hardware acceleration
// (Usually automatic, but verify in flutter run --verbose)
```

### Mobile (iOS, Android)

```dart
// Conservative settings for battery and memory
TileConfig(
  maxCachedTiles: 75,
  prefetchRings: 1,
)

// Reduce data loaded at once
const initialLoadRows = 10000;  // Instead of 100000
```

### Web

```dart
// WebGL has different texture limits
TileConfig(
  tileSize: 256,  // Some browsers struggle with larger
  maxCachedTiles: 50,  // Browser memory is shared
)

// Consider using CanvasKit renderer for better performance
// flutter run -d chrome --web-renderer canvaskit
```

---

## Troubleshooting Performance Issues

### Symptom: Stuttering During Scroll

**Causes & Solutions:**

1. **Tile render time too long**
   - Check cell content complexity
   - Reduce custom painting per cell
   - Increase tile size to reduce tile count

2. **Too many tiles being created**
   - Increase `maxCachedTiles`
   - Check for unnecessary `invalidateAll()` calls

3. **Main thread blocked**
   - Move data processing to isolates
   - Batch updates with microtasks

### Symptom: High Memory Usage

**Causes & Solutions:**

1. **Tile cache too large**
   - Reduce `maxCachedTiles`
   - Monitor with DevTools Memory tab

2. **Too many cell styles**
   - Reuse style objects
   - Use style inheritance instead of per-cell styles

3. **Retaining old data**
   - Dispose unused `WorksheetData` instances
   - Clear data when navigating away

### Symptom: Slow Initial Load

**Causes & Solutions:**

1. **Loading too much data upfront**
   - Implement lazy loading
   - Load visible range first, background load rest

2. **Synchronous data processing**
   - Use `Future.microtask` for batches
   - Show progress indicator

3. **Complex initial styling**
   - Defer conditional formatting
   - Apply styles progressively
