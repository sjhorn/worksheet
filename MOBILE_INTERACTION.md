# Mobile Interaction: Touch Gesture & Interaction Reference

A guide to touch-based interaction on mobile devices (iOS and Android phones and tablets). Originally based on Excel mobile behavior, each section is annotated with the implementation status of the worksheet widget.

> **Legend:** ✅ Implemented | ⚠️ Partial | ❌ Not implemented | 📖 Reference only

---

## 1. The Fundamental Shift: Cursors → Gestures

On desktop, interaction is driven by **cursor shapes** that change based on mouse position — the selection cross, move pointer, fill handle cross, resize arrows, etc. On mobile, there are no cursor shapes. Instead, interaction is driven by **touch gestures** and **visual selection handles** that appear contextually.

| Desktop Concept | Mobile Equivalent |
|----------------|-------------------|
| Mouse cursor shape changes | Selection handles, circles, and touch targets appear/disappear |
| Hover (no click) | No equivalent — there is no hover state on touch |
| Single click | Tap |
| Double click | Double-tap |
| Right click | Long-press (tap and hold) |
| Click and drag | Tap, hold, and drag |
| Scroll wheel | Swipe / flick |
| Ctrl+scroll to zoom | Pinch to zoom |
| Cursor position determines action | Finger target (handle vs. cell body vs. header) determines action |

**Key difference:** Desktop relies on *continuous positional feedback* (the cursor changes as you move). Mobile relies on *discrete gesture recognition* (tap, hold, drag) with no pre-action visual feedback. You don't see what will happen until you perform the gesture.

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — `mobileMode` property (line 186). When `null` (default), auto-detects via platform. The `_isMobileMode` getter resolves the platform check. All mouse cursors are disabled in mobile mode (`MouseRegion.onHover` set to null). See [MOUSE_CURSOR.md](MOUSE_CURSOR.md) for desktop cursor behavior.

---

## 2. Core Navigation Gestures

### 2.1 Scrolling & Panning

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — touch drags scroll instead of selecting. The `onDragStart` handler is skipped for touch events on cells. `SuppressibleBouncingPhysics` suppresses scroll during handle drags via `ScrollSuppressor`.

| Gesture | Action |
|---------|--------|
| **One-finger swipe** (up/down/left/right) | Scroll the worksheet in that direction |
| **Fast flick** | Momentum scroll (continues after finger lifts) |
| **Drag the scroll handle** | Jump quickly through large worksheets (handles appear on edges during scroll) |

### 2.2 Zooming

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/gestures/scale_handler.dart` — `ScaleHandler` manages pinch-to-zoom gestures. `lib/src/interaction/controllers/zoom_controller.dart` handles clamping (10%–400%).

| Gesture | Action |
|---------|--------|
| **Pinch two fingers together** | Zoom out (see more cells, smaller) |
| **Spread two fingers apart** | Zoom in (see fewer cells, larger) |

There is no "Ctrl + scroll wheel" equivalent — pinch-to-zoom is the only zoom method on mobile. The zoom level persists until changed again.

---

## 3. Cell Selection

### 3.1 Basic Selection

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/widgets/worksheet_widget.dart` — `onTapUp` handler selects cell in mobile mode. Selection handles are painted by `SelectionRenderer.paintSelectionHandles()` in `lib/src/rendering/painters/selection_renderer.dart`.

| Gesture | Action |
|---------|--------|
| **Tap a cell** | Select that cell. A blue border appears with **circular selection handles** at the upper-left and lower-right corners. |
| **Tap another cell** | Deselects the current cell and selects the new one |
| **Tap a selected cell again** (or long-press) | In Excel, opens the context menu. In our widget, long-press initiates drag-to-move. |

### 3.2 Extending a Selection (Range)

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/hit_testing/hit_test_result.dart` — `HitTestType.selectionHandle` identifies handle touches. `lib/src/interaction/gesture_handler.dart` handles selection handle drag to extend the selection range.

| Gesture | Action |
|---------|--------|
| **Drag a selection handle** (circle at corner) | Extends the selection to include more cells — drag in any direction |
| **Flick a selection handle** | (Excel: quickly extends to last cell with content. Not implemented in widget.) |

**Important:** The selection handles are **circles** at opposite corners of the selection, not the small square fill handle from desktop. Dragging these circles *always* extends the selection — it does not fill or move data.

### 3.3 Selecting Entire Columns & Rows

> **Implementation Status:** ✅ Implemented

| Gesture | Action |
|---------|--------|
| **Tap a column header letter** (A, B, C…) | Selects the entire column |
| **Tap a row header number** (1, 2, 3…) | Selects the entire row |
| **Drag across multiple column/row headers** | Selects multiple columns or rows |

### 3.4 Select All

Tap the intersection box at the top-left corner (where row and column headers meet) to select all cells.

---

## 4. Editing Cells

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/controllers/edit_controller.dart` — `startEdit()` method. `lib/src/widgets/worksheet_widget.dart` — `DoubleTapGestureRecognizer` in mobile mode calls the edit callback. iOS Safari virtual keyboard fix: an offstage `EditableText` is kept in the widget tree for synchronous focus (see Memory notes on iOS Safari).

| Gesture | Action |
|---------|--------|
| **Double-tap a cell** | Enters **edit mode** — the on-screen keyboard appears and a cursor is placed in the cell text. Equivalent to pressing F2 on desktop. |
| **Tap the formula bar** | 📖 Reference only — no formula bar in widget |
| **Tap the ✓ (checkmark) button** | 📖 Reference only — confirm via on-screen keyboard Enter |
| **Tap the ✕ (cancel) button** | 📖 Reference only — cancel via Escape key or programmatic cancel |

### Numeric Keyboard

📖 *Reference only.* Excel mobile offers a dedicated numeric keypad. The worksheet widget uses the platform's default keyboard.

---

## 5. Moving Cells (Drag and Drop)

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/interaction/gesture_handler.dart` — `onLongPressStart()` (line 653), `onLongPressMoveUpdate()` (line 682), `onLongPressEnd()`. Move preview rendered via `SelectionLayer.movePreviewRange`.

The desktop "move pointer" (4-headed arrow on the selection border) is replaced by a **tap-hold-and-drag** gesture.

| Step | Action |
|------|--------|
| 1 | **Tap** to select the cell or range |
| 2 | **Tap and hold** (long-press) on the selected area — the selection will visually "lift" or highlight to indicate it's ready to move |
| 3 | **Drag** with your finger to the new location — a ghost outline follows your finger |
| 4 | **Release** your finger to drop the cells in the new location |

### Moving Columns and Rows

📖 *Reference only — column/row reorder via drag not implemented.*

| Step | Action |
|------|--------|
| 1 | **Tap a column or row header** to select the entire column/row |
| 2 | **Tap and hold** on the selected header — it will visually lift |
| 3 | **Drag** to the new position |
| 4 | **Release** to drop |

**Key differences from desktop:**
- There is no visual cursor change before you begin dragging — you simply long-press and drag
- There is no Ctrl-drag to copy (use Copy & Paste instead)
- There is no Shift-drag to insert (cells are overwritten at the destination)
- There is no Alt-drag to move to another sheet tab

---

## 6. Fill Handle (AutoFill) on Touch

> **Implementation Status:** ❌ Not on mobile
>
> The fill handle is hidden in mobile mode (`showFillHandle: !_isMobileMode`). This differs from Excel mobile, which offers fill via context menu or explicit handle tap. On desktop, the fill handle is available and uses `SystemMouseCursors.precise` — see [MOUSE_CURSOR.md](MOUSE_CURSOR.md).

### 📖 Excel Mobile Reference

#### Phone (iOS / Android)

| Step | Action |
|------|--------|
| 1 | **Tap** to select the cell(s) containing the source data |
| 2 | **Tap the fill handle** — the small square at the bottom-right corner of the selection |
| 3 | **Drag** the fill handle through the cells you want to fill |
| 4 | **Release** your finger — the cells fill with the series or copied values |

#### Tablet (iPad / Android Tablet)

On tablets, the fill handle works more similarly to desktop — a mini-toolbar with AutoFill button appears after tapping the selection handle.

#### What's Different from Desktop

| Feature | Desktop | Mobile |
|---------|---------|--------|
| Fill handle activation | Automatic on hover (cursor changes) | Requires explicit tap or menu selection |
| Auto Fill Options tag | Appears after any fill | Not available on phones; limited on tablets |
| Double-click fill handle | Auto-fills down to match adjacent column | Not available — must drag manually |

---

## 7. Context Menu (Replaces Right-Click)

> **Implementation Status:** ❌ Not implemented
>
> No context menu on long-press of unselected cells. Long-press on selected cells initiates drag-to-move instead.

### 📖 Excel Mobile Reference

Since there is no right-click on touch, **long-press** (tap and hold) replaces it.

| Gesture | Result |
|---------|--------|
| **Long-press on a selected cell** | Opens context menu: Cut, Copy, Paste, Paste Special, Fill, Clear, Insert, Delete, etc. |
| **Long-press on an unselected cell** | Selects the cell AND opens the context menu |
| **Tap a selected cell again** | Also opens the context menu (second tap) |

### Context Menu Options (typical)

- **Cut** / **Copy** / **Paste**
- **Paste Special** (tap the right arrow ▶ for options: Values, Formulas, Formatting)
- **Fill** (when available)
- **Insert** (rows/columns/cells)
- **Delete** (rows/columns/cells)
- **Clear** (contents, formats, all)

---

## 8. Resizing Columns & Rows

> **Implementation Status:** ✅ Implemented
>
> Same as desktop, with touch-friendly hit targets. Mobile mode uses 12px tolerance for resize handles (vs 4px desktop).
>
> **Code:** `lib/src/interaction/hit_testing/hit_test_result.dart` — `HitTestType.rowResizeHandle` / `HitTestType.columnResizeHandle`.

| Gesture | Action |
|---------|--------|
| **Tap and drag the column header border** (the line between two column letters) | Resizes the column width — a double-line indicator appears at the edge |
| **Tap and drag the row header border** (the line between two row numbers) | Resizes the row height |
| **Double-tap the column header border** | Auto-fits column width to content (same as desktop) |
| **Double-tap the row header border** | Auto-fits row height to content |

**Note:** The hit target for the border between headers is enlarged in mobile mode (12px vs 4px) to accommodate finger-based interaction.

---

## 9. Charts & Objects

> **Implementation Status:** 📖 Reference only — no chart/object support in widget

| Gesture | Action |
|---------|--------|
| **Tap a chart or object** | Selects it — shows selection handles at corners and edges |
| **Drag the object body** | Moves the chart/object to a new position |
| **Drag a corner handle** | Resizes proportionally |
| **Double-tap a chart** | Enters chart edit mode |

---

## 10. Sheet Navigation

> **Implementation Status:** 📖 Reference only — no multi-sheet support in widget

| Gesture | Action |
|---------|--------|
| **Tap a sheet tab** (bottom of screen) | Switches to that worksheet |
| **Swipe left/right on the sheet tab bar** | Scrolls through sheet tabs |
| **Long-press a sheet tab** | Opens sheet context menu: Rename, Delete, Move/Copy, Hide |

---

## 11. Widget-Specific Features

These features are implemented in the worksheet widget but are not part of the Excel mobile reference.

### 11.1 Escape to Cancel Drag (Desktop Only)

Pressing **Escape** during any active drag operation (selection handle drag, resize drag, move drag) cancels the drag and restores the pre-drag selection state. The cursor resets to `SystemMouseCursors.basic`.

> **Code:** `lib/src/interaction/gesture_handler.dart` — cancel drag logic.

### 11.2 Scroll Suppression During Handle Drag

When dragging a selection handle in mobile mode, scrolling is suppressed to prevent the worksheet from scrolling while the user is extending a selection.

> **Code:** `lib/src/widgets/worksheet_widget.dart` — `ScrollSuppressor` and `SuppressibleBouncingPhysics` classes.

### 11.3 Double-Tap on Header Border

Double-tapping the border between column or row headers triggers auto-fit — the column/row resizes to fit its content. This works in both mobile and desktop modes.

### 11.4 Data Edge Jump (Desktop Only)

Double-tapping on the selection border jumps the selection to the data edge in that direction (equivalent to Ctrl+Arrow). This feature is desktop-mode only.

### 11.5 Larger Hit Targets in Mobile Mode

Mobile mode uses 12px tolerance for all interactive zones (resize handles, selection border, selection handles), compared to 4px on desktop. This makes touch interaction more reliable.

### 11.6 `mobileMode` Property

The `Worksheet` widget accepts a `bool? mobileMode` property:
- `null` (default) — auto-detects based on platform (mobile on iOS/Android, desktop on macOS/Windows/Linux)
- `true` — force mobile mode (useful for testing on desktop)
- `false` — force desktop mode on mobile

```dart
// Auto-detect (default)
Worksheet(data: data, rowCount: 100, columnCount: 26)

// Force mobile mode
Worksheet(data: data, rowCount: 100, columnCount: 26, mobileMode: true)

// Force desktop mode on mobile
Worksheet(data: data, rowCount: 100, columnCount: 26, mobileMode: false)
```

---

## 12. Phone vs. Tablet Differences

> **Implementation Status:** 📖 Reference only — the widget does not distinguish phone vs tablet; `mobileMode` is a single toggle.

| Feature | Phone | Tablet (iPad / Android Tablet) |
|---------|-------|-------------------------------|
| **Ribbon** | Collapsed — access via "…" button | Full ribbon visible at top |
| **Selection handles** | Circles at corners | Circles at corners (larger touch targets) |
| **Fill handle** | May require context menu to activate | More accessible via mini-toolbar |
| **External keyboard** | Supported (Bluetooth) | Supported — enables keyboard shortcuts |
| **Trackpad/Mouse** | Not typically used | iPad supports trackpad/mouse (restores cursor-based interaction) |

---

## 13. Gestures Not Available on Mobile

These desktop interactions have **no direct touch equivalent**:

| Desktop Feature | Mobile Status |
|----------------|---------------|
| **Hover to preview** (cursor shape change) | ❌ No hover state exists on touch screens |
| **Right-click drag** (fill handle context menu) | ❌ Not available |
| **Double-click fill handle** (auto-fill to adjacent data) | ❌ Must drag manually |
| **Ctrl-drag to copy** cells | ❌ Use Copy & Paste instead |
| **Shift-drag to insert** cells | ❌ Use Insert from context menu |
| **F8 Extend Selection mode** | ❌ Use selection handles instead |
| **Border double-click jump** (edge navigation to end of data) | ❌ Desktop only in widget |
| **Format Painter via cursor** | ❌ Not applicable |

---

## 14. Accessibility: VoiceOver & TalkBack

> **Implementation Status:** 📖 Reference only — accessibility features are a future consideration.

| Gesture | Action |
|---------|--------|
| **Swipe right/left** | Move to next/previous cell |
| **Double-tap** | Activate (select) the current element |
| **Double-tap and hold, then drag** | Adjust selection handles |
| **Three-finger swipe** | Scroll the worksheet |

---

## 15. Quick Reference: Gesture-to-Action Map

```
TOUCH INTERACTION MODEL
│
├── TAP (single finger, quick)
│   ├── On cell ────────────────────► Select cell                    ✅
│   ├── On selected cell ───────────► (no context menu)              ❌
│   ├── On column/row header ───────► Select entire column/row       ✅
│   └── On ribbon button ───────────► (no ribbon in widget)          📖
│
├── DOUBLE-TAP
│   ├── On cell ────────────────────► Enter edit mode                ✅
│   ├── On column header border ────► Auto-fit column width          ✅
│   └── On row header border ───────► Auto-fit row height            ✅
│
├── LONG-PRESS (tap and hold ~1 sec)
│   ├── On selected cell/range ─────► Lift for drag-and-drop move    ✅
│   └── On unselected cell ─────────► (no context menu)              ❌
│
├── DRAG (finger down + move)
│   ├── Selection handle (circle) ──► Extend/shrink selection        ✅
│   ├── Fill handle (corner square) ► (hidden on mobile)             ❌
│   ├── Lifted cell/range ──────────► Move cells to new location     ✅
│   └── Column/row header border ───► Resize column/row              ✅
│
├── FLICK (quick swipe)
│   └── On worksheet ───────────────► Momentum scroll                ✅
│
└── PINCH (two fingers)
    ├── Pinch together ─────────────► Zoom out                       ✅
    └── Spread apart ───────────────► Zoom in                        ✅
```

---

## 16. Platform Comparison: Desktop vs. Mobile

| Interaction | Desktop (Mouse) | Mobile (Touch) | Widget Status |
|-------------|----------------|---------------|---------------|
| Select cell | Click | Tap | ✅ Both |
| Edit cell | Double-click or F2 | Double-tap | ✅ Both |
| Extend selection | Click + drag, or Shift+click | Drag selection handle (circle) | ✅ Both |
| Move cells | Hover border → cursor changes → drag | Long-press → drag | ✅ Both |
| Copy cells | Ctrl+drag on border | Copy & Paste (no drag equivalent) | ⚠️ Keyboard only |
| Fill/AutoFill | Hover fill handle → cursor changes → drag | (hidden on mobile) | ❌ Mobile |
| Context menu | Right-click | (not implemented) | ❌ Mobile |
| Resize column/row | Hover header border → drag | Tap and drag header border | ✅ Both |
| Auto-fit column | Double-click header border | Double-tap header border | ✅ Both |
| Zoom | Ctrl + scroll wheel | Pinch gesture | ✅ Both |
| Scroll | Scroll wheel or scroll bars | Swipe / flick | ✅ Both |
| Context sensitivity | Cursor shape provides continuous feedback | No pre-action feedback | ✅ Both |

---

## See Also

- [MOUSE_CURSOR.md](MOUSE_CURSOR.md) — Desktop mouse cursor behavior and hit zones
- [CELL_MERGING.md](CELL_MERGING.md) — Cell merging behavior and restrictions
- [Cookbook](COOKBOOK.md) — Practical recipes including mobile mode configuration
- [API Reference](API.md) — Quick reference for all classes and methods

---

*This document covers the worksheet widget's mobile interaction model for iOS and Android. Originally based on Excel mobile behavior, sections are annotated with implementation status. Last updated: February 2026.*
