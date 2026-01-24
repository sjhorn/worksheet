# Worksheet Widget - Development Guide

## Project Overview
High-performance Flutter worksheet widget (Excel-like) supporting 10%-400% zoom with GPU-optimized tile-based rendering. Borrows ideas from ../sheet2/lib/steps/worksheet_widget5.dart and its related files. 

Aim to build a working example in ./example of each part as we go. Its ok to use separate named.dart files as we test with the final product coming together in the main.dart

## Core Technologies
- `TwoDimensionalScrollable` - 2D scroll management
- `LeafRenderObjectWidget` - Direct render object control
- `ui.Picture` / `PictureRecorder` - GPU-backed tile caching
- Sparse data structures - Memory efficiency for large sheets

## Development Principles

### TDD Workflow
1. **Write test first** - Define expected behavior before implementation
2. **Red → Green → Refactor** - Failing test → Pass → Optimize
3. **Test file mirrors source** - `lib/src/core/span_list.dart` → `test/core/span_list_test.dart`
4. **Minimum 80% coverage** - Critical paths require 100%

### SOLID Principles
- **S**: Each class has one responsibility (e.g., `TileCache` only manages cache, not rendering)
- **O**: Extend via interfaces, not modification (e.g., `CellRenderer` abstract class)
- **L**: Subtypes must be substitutable (e.g., `SparseWorksheetData` implements `WorksheetData`)
- **I**: Small, focused interfaces (e.g., separate `Paintable`, `HitTestable`)
- **D**: Depend on abstractions (e.g., `TileManager` takes `TileCache` interface, not concrete)

### Dart Idioms
- Prefer `final` and immutable models
- Use factory constructors for complex initialization
- Extension methods for utility functions
- `typedef` for function signatures
- Named parameters with required keyword

## Package Structure
```
lib/
├── worksheet.dart          # Public API exports
└── src/
    ├── core/               # Models, data, geometry
    ├── rendering/          # Tile system, painters
    ├── scrolling/          # Viewport, delegates
    ├── interaction/        # Gestures, selection, editing
    └── widgets/            # Public widget wrappers
```

## Key Abstractions

### Data Layer
```dart
abstract class WorksheetData {
  CellValue? getCell(CellCoordinate coord);
  CellStyle? getStyle(CellCoordinate coord);
  Stream<DataChangeEvent> get changes;
}
```

### Rendering Layer
```dart
abstract class TileRenderer {
  void render(Canvas canvas, TileRegion region, double zoom);
}

abstract class TileCache {
  Tile? get(TileCoordinate coord, ZoomBucket bucket);
  void put(TileCoordinate coord, ZoomBucket bucket, Tile tile);
  void invalidate(CellRange range);
}
```

## Implementation Order

### Phase 1: Core Models (Week 1)
Files: `cell_coordinate.dart`, `cell_range.dart`, `span_list.dart`
Tests: Property-based tests for coordinate math, edge cases

### Phase 2: Data Layer (Week 1-2)
Files: `worksheet_data.dart`, `sparse_worksheet_data.dart`
Tests: CRUD operations, change notifications, memory bounds

### Phase 3: Geometry (Week 2)
Files: `layout_solver.dart`, `visible_range_calculator.dart`, `zoom_transformer.dart`
Tests: Position lookups, viewport calculations, zoom transforms

### Phase 4: Tile Rendering (Week 3-4)
Files: `tile.dart`, `tile_manager.dart`, `tile_painter.dart`, `tile_cache.dart`
Tests: Tile lifecycle, cache eviction, Picture creation

### Phase 5: Scroll Integration (Week 4-5)
Files: `worksheet_viewport.dart`, `worksheet_scroll_delegate.dart`
Tests: Scroll physics, viewport updates, position persistence

### Phase 6: Zoom System (Week 5-6)
Files: `zoom_controller.dart`, LOD in `cell_renderer.dart`
Tests: Zoom transitions, bucket switching, anchor preservation

### Phase 7: Interaction (Week 6-7)
Files: `gesture_handler.dart`, `selection_controller.dart`, `hit_testing.dart`
Tests: Tap/drag recognition, selection state, coordinate resolution

### Phase 8: Editing & Polish (Week 8)
Files: `edit_controller.dart`, `cell_editor_overlay.dart`, `frozen_panes.dart`
Tests: Edit lifecycle, overlay positioning, freeze behavior

## Testing Strategy

### Unit Tests
- All pure functions and models
- Mock dependencies via interfaces
- Property-based tests for math operations

### Widget Tests
- `RenderObject` behavior via `TestRenderingFlutterBinding`
- Gesture simulation
- Layout verification

### Integration Tests
- Scroll + zoom combinations
- Large dataset performance
- Memory leak detection

### Performance Benchmarks
```dart
// Target metrics
const scrollFps = 60;        // Maintain 60fps while scrolling
const zoomFps = 30;          // Acceptable during zoom animation
const tileRenderMs = 8;      // Max time to render single tile
const hitTestUs = 100;       // Max hit test latency
```

## Critical Performance Rules

1. **Never allocate in paint()** - Pre-allocate paints, paths
2. **Batch draw calls** - Group gridlines into single path
3. **LOD by zoom** - Skip text below 25% zoom
4. **Tile size = 256px** - Optimal GPU texture size
5. **LRU cache tiles** - Max 100 tiles in memory
6. **Prefetch 1 ring** - Tiles beyond viewport edge

## Commands
```bash
# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html

# Run specific test file
flutter test test/core/span_list_test.dart

# Performance profiling
flutter run --profile --trace-skia
```

## Code Review Checklist
- [ ] Tests written before implementation
- [ ] All public APIs documented
- [ ] No magic numbers (use constants)
- [ ] Interfaces for external dependencies
- [ ] Immutable models where possible
- [ ] Memory disposal in `dispose()` methods
- [ ] Performance-critical code benchmarked