# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.1] - 2026-02-13

### Fixed
- Cell editor overlay now uses full merged cell width for text alignment

## [2.5.0] - 2026-02-13

### Added
- Trackpad pinch-to-zoom support for desktop and web

### Fixed
- Drag-to-move to same location no longer deletes cell data
- Drag-to-move preview now tracks cursor grab point instead of snapping selection top-left to cursor
- Selection border no longer detectable in header-adjacent zone, preventing accidental move-drag near row/column headers

## [2.4.0] - 2026-02-13

### Added
- Rich text formatting via Intents/Actions — `ToggleBoldIntent`, `ToggleItalicIntent`, `ToggleUnderlineIntent`, `ToggleStrikethroughIntent` with corresponding Action classes, enabled only during editing
- `EditController.richTextController` — exposes the active `RichTextEditingController` to toolbar buttons and external code during editing
- `EditController` convenience methods: `toggleBold()`, `toggleItalic()`, `toggleUnderline()`, `toggleStrikethrough()` for toolbar use outside the widget tree
- `EditController` query getters: `isSelectionBold`, `isSelectionItalic`, `isSelectionUnderline`, `isSelectionStrikethrough`, `getSelectionStyle()` for toolbar active-state display
- `RichTextEditingController` query methods: `isSelectionBold`, `isSelectionItalic`, `isSelectionUnderline`, `isSelectionStrikethrough`, `getSelectionStyle()`, `_queryProperty()` helper
- Ctrl+B/I/U and Ctrl+Shift+S shortcut bindings in `DefaultWorksheetShortcuts` (both control and meta variants) mapped to the new formatting intents

## [2.3.0] - 2026-02-12

### Added
- Excel-like mouse cursors — crosshair for cells, pointer for headers, resize arrows for column/row borders, move arrow for selection border, crosshair for fill handle
- Auto-fit column/row on double-click resize handle — measures cell content to set optimal width/height; respects `wrapText` style for row height calculation
- Drag-to-move selection — drag the selection border to relocate cells with a dashed preview border; source cells are cleared after move
- Border double-click jump navigation — double-clicking a selection border edge jumps to the data edge in that direction (Ctrl+Arrow behavior)

### Fixed
- Cell editor stuck at first character on double-click entry
- Double-click auto-fit no longer fires spurious resize-end or selects adjacent column after layout change

## [2.2.1] - 2026-02-11

### Fixed
- Rich text type-to-edit clearing, pending format state, and cell editor alignment
- Wrap-text cell editor expansion lag for right/bottom-aligned cells
- Cell editor edge conditions for bottom overflow and right clipping
- Text selection in cell editor overlay (click-drag, double-click word select)
- Rich text formatting (bold, italic, etc.) lost when committing edit by clicking away from cell

## [2.2.0] - 2026-02-10

### Added
- `HeaderStyle.darkStyle` — dark mode header colors derived from Excel dark mode
- `WorksheetThemeData.darkTheme` — dark mode theme preset (dark headers, white cells)
- `HeaderStyle.copyWith()`, `operator ==`, `hashCode`
- `SelectionStyle.copyWith()`, `operator ==`, `hashCode`
- Runtime theme switching — `WorksheetTheme` data changes now rebuild renderers and layers automatically
- `example/darklight.dart` — toggle between light and dark mode with a button

### Fixed
- Header background rects used non-finite dimensions (`double.infinity`) which some renderers silently skip — now uses viewport-sized rects
- `_HeaderPainter` and `_SelectionPainter` `shouldRepaint` did not detect new layers after theme change

## [2.1.0] - 2026-02-10

### Added
- `DurationParser` class — parses `H:mm:ss` and `H:mm` strings into `Duration` values
- Duration parsing in `CellValue.parse()` — detection order is now: empty → formula → boolean → number → duration → date → text
- `NumberFormatDetector` — auto-detects currency (`$1,234.56`), percentage (`42%`), and thousands-separated (`1,234`) formats on edit commit, returning both parsed value and format
- `DurationFormatDetector` — auto-detects duration formats (`[h]:mm:ss`, `[h]:mm`, `[m]:ss`) on edit commit via round-trip matching
- `EditController.commitEdit()` now detects formats for numbers and durations in addition to dates

## [2.0.0] - 2026-02-10

### Added
- **Cell merging** — `WorksheetData.mergeCells(CellRange)` / `unmergeCells(CellCoordinate)` with `MergedCellRegistry` for merge-aware rendering. Anchor cell keeps its value; non-anchor cells are cleared. Gridlines suppressed across merge interiors. Rendering spans the full merged bounds.
- **Rich text spans** — `Cell.text('...', richText: [TextSpan(...)])` for inline bold, italic, underline, color, and strikethrough within a single cell. `WorksheetData.getRichText()` / `setRichText()` API. Inline editing with Ctrl+B/I/U/Shift+S formatting shortcuts.
- **Multi-line cell text** — `CellStyle.wrapText` now fully supported end-to-end: TilePainter, FrozenLayer, and cell editor all respect `wrapText`. Alt+Enter inserts a newline during editing when `wrapText` is true. Editor grows vertically to fit content.
- Auto-detect date format from user input — when a date like `1/15/2024` or `15-Jan-24` is typed, the display format is preserved via round-trip matching against candidate `CellFormat`s
- `DateFormatDetector` utility class for detecting which `CellFormat` matches a user-typed date string
- `FormatLocale.dayFirst` field — resolves ambiguous numeric dates (e.g., `01/02/2024` → Jan 2 in US, Feb 1 in UK)
- `Worksheet.formatLocale` parameter — passes locale to `EditController` for date format detection
- 7 new date format presets: `dateShortLong` (`d-mmm-yyyy`), `dateLong` (`d mmmm yyyy`), `dateEu` (`d/m/yyyy`), `dateUsDash` (`m-d-yyyy`), `dateEuDash` (`d-m-yyyy`), `dateUsDot` (`m.d.yyyy`), `dateEuDot` (`d.m.yyyy`)
- `CellFormatResult` class — rich formatting result with optional color override from format codes like `[Red]` or `[Color3]`
- `CellFormat.formatRich()` method — returns `CellFormatResult` with text and optional color (vs `format()` which returns plain text)
- `FormatLocale` class with 6 built-in locales (`enUs`, `enGb`, `deDe`, `frFr`, `jaJp`, `zhCn`) — locale-aware decimal/thousands separators, currency symbols, and month/day names
- Comprehensive Excel custom format engine: conditional sections (`[>100]`), color codes (`[Red]`, `[Color3]`), bracket metadata (`[$EUR]` currency override), comma-as-scaler, `*` repeat fill, fractional seconds, fraction denominator constraints

### Fixed
- Zero-padded date formats (e.g., `01/02/2024`) and `yyyy-mmm-dd` patterns now detected correctly by `DateFormatDetector`

### Changed
- `onCommit` callback signature now includes optional `{CellFormat? detectedFormat}` parameter across `EditController`, `CellEditorOverlay`, and `Worksheet`
- `Worksheet` commit handlers auto-apply detected date format via `data.setFormat()` when no explicit format exists
- FrozenLayer now respects `CellStyle.wrapText` (previously hardcoded `maxLines: 1`)

## [1.10.0] - 2026-02-09

### Changed
- Rewrote date/time formatter with token-based pipeline for correct context-sensitive `m`/`mm` disambiguation
- Reworked `CellEditorOverlay` to use `Transform.scale` at base font size (matching tile painter's GPU scaling) with glyph-based cursor height
- Editor overlay now clips behind headers using a positioned Stack

### Added
- `mmmmm` format token — first letter of month name
- `A/P` and `a/p` format tokens — abbreviated AM/PM markers
- `s` format token — unpadded seconds
- `mmmm` and `dddd`/`ddd` format tokens now handled via tokenizer (previously worked but fragile)
- Bundled full Roboto font family (Regular, Bold, Italic, BoldItalic) for bold/italic cell styling
- `CellStyle.defaultFontFamily` constant and `WorksheetThemeData.resolveFontPackage()` for correct package font resolution
- `CellStyle.implicitAlignment()` — Excel-like value-type alignment (numbers/dates right, text left) when no explicit alignment is set

## [1.9.0] - 2026-02-08

### Added
- Selective cell clearing via `ClearCellsIntent` flags (`clearValue`, `clearStyle`, `clearFormat`) — clear values, styles, or formats independently while preserving the rest
- `Ctrl+\` / `Cmd+\` keyboard shortcut for "Clear Formatting" (removes styles and formats, keeps values)

## [1.8.0] - 2026-02-08

### Added
- `CellValueType.duration` and `CellValue.duration()` for storing elapsed time / duration values
- `Cell.duration()` constructor and `WorksheetDuration` extension (`.cell` on `Duration`)
- `CellFormatType.duration` with Excel-style bracket notation format codes (`[h]:mm:ss`, `[h]:mm`, `[m]:ss`, `[s]`)
- 3 duration format presets: `CellFormat.duration`, `CellFormat.durationShort`, `CellFormat.durationMinSec`
- Duration formatting engine supporting bracketed accumulating units and negative durations

## [1.7.0] - 2026-02-08

### Added
- Cell border styling with line styles (`solid`, `dotted`, `dashed`, `double`) and `BorderResolver` for adjacent-cell conflict resolution matching Excel/Sheets rules
- `BorderPainter` utility for rendering all border line styles in tiles and frozen layers
- `keepAnchorVisible` on `WorksheetController` — automatically adjusts scroll when zoom changes so the selected cell stays visible and fully in view
- `copyWith` methods on `BorderStyle` and `CellBorders`

## [1.6.3] - 2026-02-08

### Fixed
- Virtual keyboard now appears immediately on double-tap editing on iOS Safari — moved cell editor overlay outside gesture interceptors and added synchronous focus trigger to satisfy Safari's user-gesture requirement
- Cell editor overlay uses dedicated FocusScope to ensure autofocus fires independently of the worksheet's existing focus tree

## [1.6.2] - 2026-02-06

### Added
- Worksheet automatically scrolls to center the editing cell vertically when virtual keyboard appears, keeping it visible above browser URL bars and other UI elements

## [1.6.1] - 2026-02-06

### Fixed
- Keyboard navigation now works immediately after editing completes on all platforms (web, macOS, mobile)
- Focus restoration uses explicit `FocusNode` and post-frame callback to avoid timing conflicts with tap events
- Software keyboard reliably activates on mobile when cell editing starts

## [1.6.0] - 2026-02-06

### Added
- `CellEditorOverlay` now respects per-cell styles (font size, family, weight, style, color, text alignment) to match the tile-rendered cell appearance
- `autofocus: true` on cell editor TextField to ensure software keyboard activates on mobile

### Fixed
- Gridlines and selection borders snap to half-pixel positions (+0.5) for crisp 1px rendering on Impeller — prevents gray anti-aliased lines
- Removed devicePixelRatio strokeWidth adjustment that caused sub-pixel blending artifacts
- Cell editor overlay text now aligns precisely with cell content using measured TextPainter height
- Cursor height matches font size instead of default line height
- Double-tap to edit places cursor at end instead of selecting all text (F2 still selects all)
- Focus returns to worksheet after editing instead of previous widget (e.g., zoom slider)

### Changed
- Default gridline color changed to `0xFFD4D4D4`

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
