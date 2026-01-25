# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-01-25

### Added
- Screenshot in README.md via golden test
- GitHub Actions CI workflow for automated testing
- Codecov integration for coverage reporting
- Roboto font bundled for consistent text rendering

### Fixed
- Resolved all dart analyzer warnings in lib/ and test/
- Fixed installation instructions to use pub.dev version
- Golden tests excluded from CI (platform-dependent font rendering)

### Changed
- README badges: pub.dev version, license, CI status, coverage

## [1.0.0] - 2025-01-25

### Added
- Example application with 50,000 rows of sample sales data
- Performance benchmarks for tile rendering (< 8ms target)
- Performance benchmarks for hit testing (< 100μs target)
- Scroll performance benchmarks
- Large dataset integration tests
- Memory leak tests
- Comprehensive documentation suite:
  - ARCHITECTURE.md with rendering pipeline deep dive
  - GETTING_STARTED.md with installation and basic usage
  - COOKBOOK.md with practical recipes
  - PERFORMANCE.md optimization guide
  - THEMING.md customization guide
  - TESTING.md testing patterns
  - API.md quick reference
- Updated PLAN.md to reflect completed implementation

### Changed
- Version bumped to 1.0.0 for production release

## [0.9.0] - 2024-01-24

### Added
- `WorksheetWidget` - Main public StatefulWidget
- `WorksheetController` - Programmatic control aggregating sub-controllers
- `WorksheetThemeData` - Complete theming and styling support
- `WorksheetTheme` - InheritedWidget for theme propagation
- Complete public API exports in `worksheet.dart`
- Gesture handling integration
- Layer composition using Stack

## [0.8.0] - 2024-01-23

### Added
- `RenderLayer` - Abstract interface for render layers
- `SelectionLayer` - Selection highlight painting
- `SelectionRenderer` - Selection visual rendering
- `HeaderLayer` - Row and column header layer
- `HeaderRenderer` - A,B,C column and 1,2,3 row labels
- `FrozenLayer` - Infrastructure for frozen panes (not fully wired)

## [0.7.0] - 2024-01-22

### Added
- `EditController` - Cell editing orchestration with start/commit/cancel flow
- `EditTrigger` enum - Double-tap, keyboard, and typing triggers
- `CellEditorOverlay` - Floating text editor widget for cell editing

## [0.6.0] - 2024-01-21

### Added
- `SelectionController` - Selection state machine with single/range/row/column modes
- `HitTester` - Coordinate resolution from screen to worksheet space
- `HitTestResult` - Types for cell, header, and resize handle hits
- `GestureHandler` - Unified gesture processing
- `KeyboardHandler` - Arrow keys and keyboard shortcuts
- `ScaleHandler` - Pinch-to-zoom gesture handling

## [0.5.0] - 2024-01-20

### Added
- `ZoomController` - Zoom level management extending ValueNotifier
- Support for 10%-400% zoom range (0.1 to 4.0)
- `zoomIn()`, `zoomOut()`, and `reset()` methods
- Zoom clamping and validation

## [0.4.0] - 2024-01-19

### Added
- `ScrollAnchor` - Position preservation during zoom
- `WorksheetScrollPhysics` - Custom scroll momentum physics
- `ViewportDelegate` - Interface for viewport management
- `WorksheetViewport` - TwoDimensionalScrollable integration
- `WorksheetScrollDelegate` - Child management for 2D scrolling

## [0.3.0] - 2024-01-18

### Added
- `TileCoordinate` - Tile grid position representation
- `TileConfig` - Configuration with 256px tiles, LRU cache settings
- `Tile` - Single cached tile with GPU-backed `ui.Picture`
- `TilePainter` - Cell painting with level-of-detail (LOD) rendering
- `TileCache` - LRU eviction cache for tiles
- `TileManager` - Tile lifecycle orchestration

### Performance
- GPU-backed tile caching for smooth scrolling
- Level-of-detail rendering based on zoom level
- LRU cache eviction to manage memory

## [0.2.0] - 2024-01-17

### Added
- `WorksheetData` - Abstract interface for worksheet data access
- `SparseWorksheetData` - Map-based sparse storage implementation
- `DataChangeEvent` - Granular change events for reactive updates
- `SpanList` - Cumulative row/column sizes with O(log n) lookups
- `LayoutSolver` - Position to index conversion
- `VisibleRangeCalculator` - Viewport to CellRange queries
- `ZoomTransformer` - Zoom-aware coordinate math with ZoomBucket enum

### Performance
- O(log n) binary search for position lookups
- Memory-efficient sparse data storage

## [0.1.0] - 2024-01-16

### Added
- Initial project scaffolding
- `CellCoordinate` - Immutable (row, col) address with Excel notation (A1, AA100)
- `CellRange` - Rectangular cell selection with normalization and contains()
- `CellValue` - Union type supporting text, number, boolean, formula, error, date
- `CellStyle` - Font, color, alignment, and border styling
- `FreezeConfig` - Configuration for frozen panes
- Full test coverage for all core models
- CLAUDE.md development guide
- PLAN.md implementation plan

### Technical
- TDD workflow with tests written before implementation
- SOLID principles applied throughout
- Immutable models with proper equality/hashCode
