# Mouse Cursor Behavior & State Reference

A guide to the stateful, position-dependent mouse cursor behaviors for the worksheet widget's desktop mode. Originally based on Excel desktop behavior, each section is annotated with the implementation status.

> **Legend:** ✅ Implemented | ⚠️ Partial | ❌ Not implemented | 📖 Reference only

---

## 1. Cursor Types Overview

The worksheet uses distinct cursor shapes, each indicating a different interaction mode. The cursor changes based on *where* the pointer is positioned relative to the selection, headers, and UI elements.

> **Implementation Status:** ⚠️ Partial — 6 of 9 Excel cursor types implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — `_currentCursor` member variable manages cursor state. Cursor is updated inline in gesture handlers and via `onHover` callbacks.

| Cursor | Name | Appearance | Where It Appears | Widget Status |
|--------|------|-----------|-----------------|---------------|
| **Selection Cross** | Standard / Cell Select | Thick white plus sign (+) | Anywhere over the cell grid (default) | ✅ `SystemMouseCursors.cell` |
| **Move Pointer** | Drag / Move | Grab hand / grabbing hand | Edge/border of the current selection | ✅ `SystemMouseCursors.grab` / `.grabbing` |
| **Copy Pointer** | Copy | White arrow + small "+" | Edge of selection while holding Ctrl | ❌ Not implemented |
| **Fill Handle** | AutoFill | Thin crosshair (+) | Bottom-right corner square of the selection | ✅ `SystemMouseCursors.precise` |
| **Column Select** | Select Column | Thick black downward arrow | Over column letter headers (A, B, C…) | ✅ Custom cursor logic |
| **Row Select** | Select Row | Thick black rightward arrow | Over row number headers (1, 2, 3…) | ✅ Custom cursor logic |
| **Resize (Horizontal)** | Column Resize | Double-headed horizontal arrow (↔) | Border between two column headers | ✅ `SystemMouseCursors.resizeColumn` |
| **Resize (Vertical)** | Row Resize | Double-headed vertical arrow (↕) | Border between two row headers | ✅ `SystemMouseCursors.resizeRow` |
| **I-Beam** | Text Edit | Vertical line cursor | Inside the formula bar, or after double-clicking a cell | ❌ Not implemented |

**Note:** Our widget uses `grab` / `grabbing` cursors for the selection border move pointer instead of Excel's 4-headed arrow. This matches Excel for the Web and Excel for Mac behavior. See Section 2 for details.

---

## 2. Selection Border Behavior

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — cursor changes to `SystemMouseCursors.grab` on hover over the selection border, and `SystemMouseCursors.grabbing` during drag. `lib/src/interaction/hit_testing/hit_test_result.dart` — `HitTestType.selectionBorder` identifies the border zone.

This is one of the most nuanced behaviors. The cursor change at the edge of a selection is **position-sensitive with an implicit hit-test zone**.

### What happens:

- **Fast mouse movement across a selected cell**: The pointer passes through the narrow border hit-zone too quickly for the hit test to register it. The cursor stays as the **Selection Cross** the entire time.

- **Slow mouse movement or pausing near the border**: The pointer lingers within the border hit-zone long enough for detection. The cursor changes to the **grab hand** (Move Pointer). If you then move inward away from the border, it reverts to the **Selection Cross**.

### Practical implications:

| Mouse speed | Cursor seen | What happens on click |
|-------------|------------|----------------------|
| Fast pass-through | Selection Cross stays | Clicking selects/activates a new cell |
| Slow hover on border | Grab hand appears | Click-and-drag **moves** the selected range |

### The state transition:

```
                    ┌──────────────────────────────────┐
                    │                                  │
  Mouse enters      │   CELL INTERIOR                  │
  cell grid    ───► │   Cursor: cell (+)               │
                    │                                  │
                    │   ┌─── BORDER ZONE (few px) ───┐ │
                    │   │                             │ │
                    │   │  Cursor: grab (hover)       │ │
                    │   │  Cursor: grabbing (drag)    │ │
                    │   │                             │ │
                    │   └─────────────────────────────┘ │
                    │                                  │
                    │   ┌─ FILL HANDLE (corner sq.) ─┐ │
                    │   │ Cursor: precise (crosshair) │ │
                    │   └─────────────────────────────┘ │
                    └──────────────────────────────────┘
```

**Difference from Excel Windows:** Excel Windows uses a 4-headed move arrow cursor. Our widget uses `grab` / `grabbing` (hand cursors), which matches Excel for the Web and some versions of Excel for Mac.

---

## 3. Fill Handle Behavior (Bottom-Right Corner)

> **Implementation Status:** ✅ Implemented (desktop only)
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — fill handle cursor uses `SystemMouseCursors.precise`. The fill handle is hidden in mobile mode (`showFillHandle: !_isMobileMode`). See [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md) for mobile details.

The small square at the bottom-right corner of the selection has its own cursor and drag behavior.

### 3.1 Cursor Change

When the mouse hovers over the fill handle square, the cursor changes from the Selection Cross to `SystemMouseCursors.precise` — a thin crosshair.

### 3.2 Left-Click Drag

| Source Data | Default Behavior | With Ctrl Held |
|-------------|-----------------|----------------|
| Single number | Copies the same value | 📖 Creates a series (1, 2, 3…) |
| Two+ numbers (pattern) | Extends the series | 📖 Copies values without series |
| Date | Extends by 1 day/month/etc. | 📖 Copies the same date |
| Formula | Copies with relative ref adjustment | 📖 Same (Ctrl has no effect) |
| Text | Copies the same text | 📖 Copies the same text |

### 3.3 Right-Click Drag

📖 *Reference only — right-click drag context menu not implemented.*

### 3.4 Double-Click Fill Handle

📖 *Reference only — double-click auto-fill not implemented.*

### 3.5 Auto Fill Options Smart Tag

📖 *Reference only — post-fill options tag not implemented.*

---

## 4. Double-Click Behaviors on Selection Borders

> **Implementation Status:** ⚠️ Partial
>
> Data edge jump is available on desktop via double-tap on the selection border. The jump logic follows the same pattern as Ctrl+Arrow navigation.

When the **grab hand** cursor is active on a selection border, **double-clicking** performs a "jump" navigation:

| Border Position | Double-Click Action |
|----------------|-------------------|
| Top edge | Jumps to the first non-empty cell upward in that column |
| Bottom edge | Jumps to the last non-empty cell downward in that column |
| Left edge | Jumps to the first non-empty cell leftward in that row |
| Right edge | Jumps to the last non-empty cell rightward in that row |

This is the "flying leap" behavior — it follows the same logic as **Ctrl+Arrow** navigation.

---

## 5. Column & Row Header Behaviors

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/hit_testing/hit_test_result.dart` — `HitTestType.columnHeader`, `HitTestType.rowHeader`, `HitTestType.columnResizeHandle`, `HitTestType.rowResizeHandle`.

### Column Headers (A, B, C…)

| Action | Result | Widget Status |
|--------|--------|---------------|
| Hover | Cursor → column select arrow (↓) | ✅ |
| Click | Selects entire column | ✅ |
| Click + drag horizontally | Selects multiple columns | ✅ |
| Ctrl + click | Adds column to selection (non-contiguous) | 📖 |
| Hover on border between headers | Cursor → `SystemMouseCursors.resizeColumn` (↔) | ✅ |
| Drag on border between headers | Resizes column width | ✅ |
| Double-click border between headers | **Auto-fits** column width to content | ✅ |

### Row Headers (1, 2, 3…)

Identical behavior to columns but in the vertical axis:

| Action | Result | Widget Status |
|--------|--------|---------------|
| Hover | Cursor → row select arrow (→) | ✅ |
| Click | Selects entire row | ✅ |
| Hover on border between row numbers | Cursor → `SystemMouseCursors.resizeRow` (↕) | ✅ |
| Double-click border between rows | **Auto-fits** row height to content | ✅ |

---

## 6. Keyboard Modifier Interactions

> **Implementation Status:** ❌ Not implemented — modifier key combinations during mouse drag are not supported.

📖 *Reference only.* Modifier keys change cursor behavior when combined with mouse actions on a selection in Excel:

| Modifier | Effect on Border Drag | Effect on Fill Handle Drag |
|----------|----------------------|---------------------------|
| *None* | **Move** the selection | Default fill (copy or series, depends on data) |
| **Ctrl** | **Copy** the selection (cursor adds "+" icon) | **Toggle** fill behavior (copy↔series) |
| **Shift** | **Insert** — shifts existing cells to make room | Overrides range — extends/contracts selection |
| **Ctrl+Shift** | **Insert copied** cells, shifting existing cells | — |

---

## 7. Special Modes That Alter Cursor State

### 7.1 Extend Selection Mode (F8)

📖 *Reference only — not implemented in widget.*

### 7.2 Add to Selection Mode (Shift+F8)

📖 *Reference only — not implemented in widget.*

### 7.3 Edit Mode (F2 / Double-Click)

> **Implementation Status:** ⚠️ Partial — F2 and double-click enter edit mode, but the cursor does not change to I-beam inside the cell. The cell editor overlay handles its own cursor.

### 7.4 Design Mode (Developer Tab)

📖 *Reference only — not applicable to widget.*

---

## 8. Mobile Mode Cursor Behavior

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — when `_isMobileMode` is true, all mouse cursor changes are disabled. `MouseRegion.onHover` is set to null, and `_currentCursor` stays as `SystemMouseCursors.basic`.

In mobile mode, all mouse cursors described above are disabled. Touch interaction relies entirely on gestures and visual selection handles rather than cursor feedback. See [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md) for the complete touch interaction model.

### Selection Handles (Touch Only)

In mobile mode, circular selection handles appear at the top-left and bottom-right corners of the selection. These handles are touch-only targets — no cursor change occurs when hovering over them with a mouse (e.g., on iPad with trackpad).

---

## 9. Escape to Cancel Drag

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/gesture_handler.dart` — pressing Escape during any active drag (selection border drag, resize drag, fill handle drag) cancels the operation and restores the pre-drag state.

When Escape is pressed during any drag operation:
1. The drag is cancelled
2. The selection is restored to its pre-drag state
3. The cursor resets to `SystemMouseCursors.basic`

---

## 10. Read-Only Mode

> **Implementation Status:** ✅ Implemented

When `readOnly: true` is set on the `Worksheet` widget:
- Selection cursors still work (cell cursor, header cursors)
- Move/fill cursors are suppressed (no border drag, no fill handle)
- Resize cursors remain active for column/row resizing

---

## 11. Object & Chart Cursors

> **Implementation Status:** 📖 Reference only — no chart/object support in widget

| Location | Cursor | Action |
|----------|--------|--------|
| Interior of object | White arrow / pointer | Click to select object |
| Edge/border of selected object | 4-headed move arrow | Drag to reposition |
| Corner handle (selected) | Diagonal double-headed arrow | Drag to resize proportionally |

---

## 12. Formula Bar Cursors

> **Implementation Status:** 📖 Reference only — no formula bar in widget

| Location | Cursor | Action |
|----------|--------|--------|
| Formula bar text area | I-Beam | Click to position text cursor |
| Border between Name Box and formula bar | Horizontal resize arrow | Drag to resize |

---

## 13. Summary: State Transition Map

```
READY MODE
│
├── Mouse over cell grid ──────────────► cell cursor (thick +)      ✅
│   ├── Click ──────────────────────────► Select cell                ✅
│   ├── Click + Drag ───────────────────► Select range               ✅
│   └── Double-click ───────────────────► Enter edit mode            ✅
│
├── Mouse over selection border ────────► grab cursor (hand)         ✅
│   ├── Click + Drag ───────────────────► Move selection             ✅
│   ├── Ctrl + Click + Drag ────────────► (not implemented)          ❌
│   └── Double-click ───────────────────► Jump to edge of data       ⚠️
│
├── Mouse over fill handle ─────────────► precise cursor (crosshair) ✅
│   ├── Left-click + Drag ──────────────► AutoFill                   ✅
│   └── Double-click ───────────────────► (not implemented)          ❌
│
├── Mouse over column header ───────────► Column Select arrow (↓)    ✅
├── Mouse over row header ──────────────► Row Select arrow (→)       ✅
├── Mouse between col headers ──────────► resizeColumn (↔)           ✅
├── Mouse between row headers ──────────► resizeRow (↕)              ✅
│
├── Escape during drag ─────────────────► Cancel → basic cursor      ✅
└── Mobile mode ────────────────────────► All cursors disabled        ✅
```

---

## 14. Platform Differences: Excel for Mac

> **Implementation Status:** 📖 Reference only

### Modifier Key Mapping

| Action | Windows | Mac |
|--------|---------|-----|
| **Copy cells via drag** (border drag) | Ctrl + drag | Option (⌥) + drag |
| **Insert-shift via drag** | Shift + drag | Shift + drag (same) |
| **Edge jump (keyboard)** | Ctrl + Arrow | Command (⌘) + Arrow |

### Cursor Appearance Differences

- The **Move Pointer** on Mac shows as a white hand/grab cursor in some versions rather than the 4-headed arrow. Our widget's use of `grab`/`grabbing` aligns with this Mac behavior.
- The **Fill Handle** cursor (thin black cross) is the same across platforms.
- Resize cursors (double-headed arrows) are the same.

---

## 15. Platform Differences: Excel for the Web (Online)

> **Implementation Status:** 📖 Reference only

### Cursor Comparison

| Zone | Windows Desktop | Excel for Web | Our Widget |
|------|----------------|--------------|------------|
| Cell grid | Thick white cross (custom) | CSS `cell` / `crosshair` | `SystemMouseCursors.cell` |
| Selection border (move) | 4-headed arrow | Grab hand / move | `SystemMouseCursors.grab` / `.grabbing` |
| Fill handle | Thin black cross (custom) | CSS `crosshair` | `SystemMouseCursors.precise` |
| Column/row header | Thick black arrow | CSS `pointer` | Custom arrow logic |
| Resize between headers | Double-headed arrow | CSS `col-resize` / `row-resize` | `SystemMouseCursors.resizeColumn` / `.resizeRow` |

Our widget's cursor choices most closely match Excel for the Web.

---

## 16. Settings Reference

> **Implementation Status:** 📖 Reference only — the widget does not expose Excel-style settings toggles.

Excel's relevant settings (for reference):

| Setting | Effect |
|---------|--------|
| **Enable fill handle and cell drag-and-drop** | Master toggle for fill/move/copy drag |
| **Alert before overwriting cells** | Shows warning when dragging over non-empty cells |

---

## See Also

- [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md) — Touch gesture equivalents for mobile/tablet
- [CELL_MERGING.md](CELL_MERGING.md) — Cell merging behavior and restrictions
- [Cookbook](COOKBOOK.md) — Practical recipes for common tasks
- [API Reference](API.md) — Quick reference for all classes and methods

---

*This document covers the worksheet widget's desktop mouse cursor behavior. Originally based on Excel desktop, sections are annotated with implementation status. Last updated: February 2026.*
