# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-02-03

### Added
- `CellValue.parse()` — unified static factory that detects type from text input (formula, boolean, number, date, text) with consistent behavior across editing and clipboard paste
- `Worksheet.dateParser` parameter — configures date format detection via `AnyDate` from the [`any_date`](https://pub.dev/packages/any_date) package; supports locale-based parsing (e.g., `AnyDate.fromLocale('en-US')` for month/day/year)
- Date detection during editing and clipboard paste — typing `2025-01-15` or `Jan 15, 2025` now commits as `CellValue.date()` instead of text
- Re-exported `AnyDate` and `DateParserInfo` from `worksheet.dart` so consumers don't need a direct `any_date` dependency

### Changed
- `EditController._parseText` now delegates to `CellValue.parse()` for consistent type detection
- `TsvClipboardSerializer._parseValue` now delegates to `CellValue.parse(allowFormulas: false)` — clipboard paste no longer interprets `=` prefix as a formula, trims whitespace, and uses case-insensitive boolean detection
- `TsvClipboardSerializer` constructor accepts optional `dateParser` parameter
- `Worksheet.clipboardSerializer` is now nullable (defaults to `TsvClipboardSerializer` with the widget's `dateParser`)

### Fixed
- Clipboard paste boolean detection was case-sensitive (`true` worked but `TRUE` did not) — now case-insensitive
- Clipboard paste did not trim whitespace — now trims consistently
- Clipboard paste used `num.tryParse` while editing used `double.tryParse` — both now use `double.tryParse`

## [1.4.0] - 2025-02-02

### Added
- Flutter `Shortcuts` / `Actions` pattern for keyboard handling — enables consumers to override, extend, or remap any keyboard shortcut
- `Worksheet.shortcuts` parameter — custom shortcut bindings merged on top of defaults
- `Worksheet.actions` parameter — custom action overrides merged on top of defaults
- `DefaultWorksheetShortcuts` — static map of ~44 default shortcut bindings (both `control:` and `meta:` variants for cross-platform)
- 13 Intent classes (`MoveSelectionIntent`, `GoToCellIntent`, `ClearCellsIntent`, etc.)
- 13 Action classes with `WorksheetActionContext` interface for dependency injection
- `WorksheetActionContext` — abstract interface implemented by the widget state, avoiding 6+ constructor params per Action
- New shortcuts: Ctrl+C/X/V (copy/cut/paste), Ctrl+D (fill down), Ctrl+R (fill right), Delete/Backspace (clear cells)
- `Worksheet.editController` parameter for integrated cell editing — renders `CellEditorOverlay` internally, handles type-to-edit, commit-and-navigate, and F2/double-tap editing
- Type-to-edit: printable characters start editing the focused cell with that character as initial content
- Commit-and-navigate: Enter (down), Shift+Enter (up), Tab (right), Shift+Tab (left) commit the edit and move selection
- `CellEditorOverlay.onCommitAndNavigate` callback for directional commit with row/column delta
- Arrow keys commit the edit and navigate when editing (via `CellEditorOverlay`)
- Tap outside the editing cell commits the current edit
- `EditCommitResult` value class on `EditController`
- Backspace/Delete tests for editing vs navigation mode

### Deprecated
- `KeyboardHandler` class — use the `Shortcuts` / `Actions` pattern instead (see `worksheet_intents.dart`)

### Changed
- `Worksheet` widget now uses `Shortcuts` -> `Actions` -> `Focus` widget tree instead of `Focus(onKeyEvent:)` with `KeyboardHandler`
- Destructive actions (`ClearCells`, `Cut`, `Paste`, `FillDown`, `FillRight`) check `readOnly` in `isEnabled()` as defense-in-depth
- Cell-level actions (copy, cut, paste, clear, select-all) are disabled while the `editController` is editing, so Ctrl+C/X/V/A and Backspace/Delete reach the text field for in-cell editing
- `CellEditorOverlay` uses `TextField` with `InputDecoration.collapsed` for proper cursor rendering, text selection, and double-click word selection
- Parent double-tap handler suppressed while editing so the TextField's word-select gesture wins the gesture arena
- Pointer-down within the editing cell is passed through to the TextField for cursor repositioning instead of committing the edit
- `TilePainter.editingCell` field hides tile-rendered text for the cell being edited (avoids double rendering)

## [1.3.0] - 2025-02-02

### Added
- `WorksheetController.getCellScreenBounds()` — returns screen-space `Rect` for a cell, accounting for zoom, scroll offset, and headers
- `WorksheetController.ensureCellVisible()` — simplified scroll-to-cell that uses the attached layout
- `WorksheetController.hasLayout` / `layoutSolver` / `headerWidth` / `headerHeight` — public read access to the widget's internal layout state
- `WorksheetController.attachLayout()` / `detachLayout()` — called by the `Worksheet` widget to share its internal `LayoutSolver`

### Fixed
- Cell text disappearing on alternating rows after column resize — cell backgrounds straddling a tile boundary overflowed into adjacent tiles because `PictureRecorder` `cullRect` is only a hint; added hard `clipRect` to tile canvas
- Deferred `TextPainter` disposal until after `PictureRecorder.endRecording()` to prevent premature native `Paragraph` resource release

### Changed
- `Worksheet` widget now attaches its `LayoutSolver` and header dimensions to the controller after initialization
- Simplified `_ensureSelectionVisible` in `Worksheet` to use `ensureCellVisible`
- Example app no longer creates a duplicate `LayoutSolver`; uses `controller.getCellScreenBounds()` instead
- Updated GETTING_STARTED.md, COOKBOOK.md, API.md, and ARCHITECTURE.md to reflect the new API

## [1.2.0] - 2025-01-30

### Added
- `CellFormat` class with Excel-style format codes for cell display formatting
- 16 built-in format presets (currency, percentage, date, scientific, fraction, etc.)
- `CellFormatType` enum with 12 format categories
- `Cell.format` field for per-cell formatting
- `Cell.displayValue` getter — uses format when present
- `Cell.copyWithFormat()` method
- `WorksheetData.getFormat()`/`setFormat()` with backward-compatible defaults
- `SparseWorksheetData` format storage with change events and batch support
- `DataChangeType.cellFormat` event type

### Changed
- `TilePainter` and `FrozenLayer` use `CellFormat` when rendering cell content
- `Cell.isEmpty` considers format field

### Deprecated
- `CellStyle.numberFormat` — use `CellFormat` on `Cell` instead

## [1.1.0] - 2025-01-27

### Added
- Built-in keyboard navigation in Worksheet widget (arrow keys, Tab, Enter, Home/End, PageUp/Down, F2, Escape, Ctrl+A)
- 18 widget-level keyboard navigation tests
- Release process checklist in CLAUDE.md

### Fixed
- Selection and header layers now repaint on selection change (CustomPainter repaint listenable)

### Changed
- Simplified example/main.dart by removing manual keyboard handling code
- Updated COOKBOOK.md keyboard navigation section to reflect built-in support

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
