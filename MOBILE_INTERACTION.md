# Excel Mobile App: Touch Gesture & Interaction Reference

A guide to how Excel's touch-based interaction model replaces mouse cursors on mobile devices (iOS and Android phones and tablets).

---

## 1. The Fundamental Shift: Cursors → Gestures

On desktop Excel, interaction is driven by **cursor shapes** that change based on mouse position — the selection cross, move pointer, fill handle cross, resize arrows, etc. On mobile, there are no cursor shapes. Instead, interaction is driven by **touch gestures** and **visual selection handles** that appear contextually.

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

**Key difference:** Desktop Excel relies on *continuous positional feedback* (the cursor changes as you move). Mobile Excel relies on *discrete gesture recognition* (tap, hold, drag) with no pre-action visual feedback. You don't see what will happen until you perform the gesture.

---

## 2. Core Navigation Gestures

### 2.1 Scrolling & Panning

| Gesture | Action |
|---------|--------|
| **One-finger swipe** (up/down/left/right) | Scroll the worksheet in that direction |
| **Fast flick** | Momentum scroll (continues after finger lifts) |
| **Drag the scroll handle** | Jump quickly through large worksheets (handles appear on edges during scroll) |

### 2.2 Zooming

| Gesture | Action |
|---------|--------|
| **Pinch two fingers together** | Zoom out (see more cells, smaller) |
| **Spread two fingers apart** | Zoom in (see fewer cells, larger) |

There is no "Ctrl + scroll wheel" equivalent — pinch-to-zoom is the only zoom method. The zoom level persists until changed again.

---

## 3. Cell Selection

### 3.1 Basic Selection

| Gesture | Action |
|---------|--------|
| **Tap a cell** | Select that cell. A blue/green border appears with **circular selection handles** at the upper-left and lower-right corners. |
| **Tap another cell** | Deselects the current cell and selects the new one |
| **Tap a selected cell again** (or long-press) | Opens the **context menu** (Cut, Copy, Paste, Fill, etc.) |

### 3.2 Extending a Selection (Range)

| Gesture | Action |
|---------|--------|
| **Drag a selection handle** (circle at corner) | Extends the selection to include more cells — drag in any direction |
| **Flick a selection handle** | Quickly extends the selection to the last cell with content in that direction (equivalent to Ctrl+Shift+Arrow on desktop) |

**Important:** The selection handles are **circles** at opposite corners of the selection, not the small square fill handle from desktop. Dragging these circles *always* extends the selection — it does not fill or move data.

### 3.3 Selecting Entire Columns & Rows

| Gesture | Action |
|---------|--------|
| **Tap a column header letter** (A, B, C…) | Selects the entire column |
| **Tap a row header number** (1, 2, 3…) | Selects the entire row |
| **Drag across multiple column/row headers** | Selects multiple columns or rows |

### 3.4 Select All

Tap the intersection box at the top-left corner (where row and column headers meet) to select all cells.

---

## 4. Editing Cells

| Gesture | Action |
|---------|--------|
| **Double-tap a cell** | Enters **edit mode** — the on-screen keyboard appears and a cursor is placed in the cell text. Equivalent to pressing F2 on desktop. |
| **Tap the formula bar** | Also enters edit mode, placing the cursor in the formula bar |
| **Tap the ✓ (checkmark) button** | Confirms the edit (equivalent to pressing Enter) |
| **Tap the ✕ (cancel) button** | Cancels the edit (equivalent to pressing Esc) |
| **Tap the Back key** (Android) | Hides the on-screen keyboard |

### Numeric Keyboard

Excel mobile offers a dedicated **numeric keypad** (calculator-style layout) accessible via a keyboard toggle icon in the toolbar. This is optimized for data entry with large number keys and quick access to operators (+, -, *, /, parentheses).

---

## 5. Moving Cells (Drag and Drop)

The desktop "move pointer" (4-headed arrow on the selection border) is replaced by a **tap-hold-and-drag** gesture.

| Step | Action |
|------|--------|
| 1 | **Tap** to select the cell or range |
| 2 | **Tap and hold** (long-press) on the selected area — the selection will visually "lift" or highlight to indicate it's ready to move |
| 3 | **Drag** with your finger to the new location — a ghost outline follows your finger |
| 4 | **Release** your finger to drop the cells in the new location |

### Moving Columns and Rows

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

The fill handle works very differently on touch compared to desktop. On desktop, you hover over the small corner square and the cursor changes to a thin black cross. On mobile, the process is more explicit.

### 6.1 Phone (iOS / Android)

| Step | Action |
|------|--------|
| 1 | **Tap** to select the cell(s) containing the source data |
| 2 | **Tap the fill handle** — the small square at the bottom-right corner of the selection. On some versions, you may need to tap and hold the cell first, then tap **"AutoFill"** or **"Fill"** from the mini-toolbar/context menu. |
| 3 | **Drag** the fill handle down, up, left, or right through the cells you want to fill |
| 4 | **Release** your finger — the cells fill with the series or copied values |

### 6.2 Tablet (iPad / Android Tablet)

On tablets, the fill handle works more similarly to desktop:

| Step | Action |
|------|--------|
| 1 | **Tap** to select the cell(s) |
| 2 | The selection shows **circle handles** at corners. Tap the **lower-right selection handle** (circle) |
| 3 | A **mini-toolbar** appears with options including **AutoFill**. Tap AutoFill. |
| 4 | An **AutoFill button** (blue arrow icon) replaces the selection handle at the corner |
| 5 | **Drag** the AutoFill button through the blank cells to fill |
| 6 | **Release** — cells are filled with the series |

### 6.3 What's Different from Desktop

| Feature | Desktop | Mobile |
|---------|---------|--------|
| Fill handle activation | Automatic on hover (cursor changes) | Requires explicit tap or menu selection |
| Auto Fill Options tag | Appears after any fill | Not available on phones; limited on tablets |
| Right-click drag menu | Shows expanded fill options on release | Not available |
| Double-click fill handle | Auto-fills down to match adjacent column | Not available — must drag manually |
| Ctrl-drag to toggle copy/series | Available | Not available |
| Fill direction feedback | Live preview as you drag | Live preview as you drag (same) |

---

## 7. Context Menu (Replaces Right-Click)

Since there is no right-click on touch, **long-press** (tap and hold) replaces it.

| Gesture | Result |
|---------|--------|
| **Long-press on a selected cell** | Opens context menu: Cut, Copy, Paste, Paste Special, Fill, Clear, Insert, Delete, etc. |
| **Long-press on an unselected cell** | Selects the cell AND opens the context menu |
| **Tap a selected cell again** | Also opens the context menu (second tap) |

The context menu appears as a floating **mini-toolbar** (horizontal strip of icons) or a dropdown list, depending on the device and orientation.

### Context Menu Options (typical)

- **Cut** / **Copy** / **Paste**
- **Paste Special** (tap the right arrow ▶ for options: Values, Formulas, Formatting)
- **Fill** (when available)
- **Insert** (rows/columns/cells)
- **Delete** (rows/columns/cells)
- **Clear** (contents, formats, all)
- **Add Comment**
- **Show Context Menu** (▼ button for additional options)

---

## 8. Resizing Columns & Rows

| Gesture | Action |
|---------|--------|
| **Tap and drag the column header border** (the line between two column letters) | Resizes the column width — a double-line indicator appears at the edge |
| **Tap and drag the row header border** (the line between two row numbers) | Resizes the row height |
| **Double-tap the column header border** | Auto-fits column width to content (same as desktop) |
| **Double-tap the row header border** | Auto-fits row height to content |

**Note:** The hit target for the border between headers is small on phones. Zooming in first makes this easier.

---

## 9. Charts & Objects

| Gesture | Action |
|---------|--------|
| **Tap a chart or object** | Selects it — shows selection handles at corners and edges |
| **Drag the object body** | Moves the chart/object to a new position |
| **Drag a corner handle** | Resizes proportionally |
| **Drag an edge handle** | Stretches in one direction |
| **Double-tap a chart** | Enters chart edit mode (edit data, elements, style) |
| **Long-press a chart** | Opens context menu (Cut, Copy, Delete, Format, etc.) |

---

## 10. Sheet Navigation

| Gesture | Action |
|---------|--------|
| **Tap a sheet tab** (bottom of screen) | Switches to that worksheet |
| **Swipe left/right on the sheet tab bar** | Scrolls through sheet tabs when there are many |
| **Long-press a sheet tab** | Opens sheet context menu: Rename, Delete, Move/Copy, Hide, Tab Color |
| **Tap the "+" button** next to sheet tabs | Adds a new worksheet |

**Note:** There is no drag-to-reorder sheets gesture on all versions. Some tablet versions support it; on phones, use the Move/Copy option from the context menu.

---

## 11. Phone vs. Tablet Differences

The Excel mobile experience differs between phones and tablets, primarily due to screen size.

| Feature | Phone | Tablet (iPad / Android Tablet) |
|---------|-------|-------------------------------|
| **Ribbon** | Collapsed — access via "…" (More) button at bottom; single-row ribbon | Full ribbon visible at top (similar to desktop, simplified) |
| **Formula bar** | Appears at bottom of screen | Appears at top (desktop-like position) |
| **Selection handles** | Circles at corners | Circles at corners (larger touch targets) |
| **Fill handle** | May require context menu to activate | More accessible; mini-toolbar with AutoFill button |
| **Context menu** | Compact floating strip | More spacious floating toolbar |
| **Split view / multitasking** | Not supported | Supported (iPad Split View, Android split-screen) |
| **External keyboard** | Supported (Bluetooth) — enables keyboard shortcuts | Supported — enables near-desktop keyboard shortcuts |
| **Trackpad/Mouse** | Not typically used | iPad supports trackpad/mouse (restores cursor-based interaction) |
| **Orientation** | Portrait optimized; landscape for wider data view | Both orientations well-supported |

### iPad with Trackpad/Mouse

When an iPad is connected to a Magic Trackpad or mouse, Excel for iPad **restores cursor-based interaction**:

- A visible circular cursor appears on screen
- Hover states return (cursor changes near borders and handles)
- Click-and-drag works similarly to desktop
- Right-click (two-finger tap on trackpad) opens context menus
- This effectively bridges the gap between the touch and desktop experience

---

## 12. Gestures Not Available on Mobile

These desktop interactions have **no direct touch equivalent**:

| Desktop Feature | Mobile Status |
|----------------|---------------|
| **Hover to preview** (cursor shape change) | ❌ No hover state exists on touch screens |
| **Right-click drag** (fill handle context menu) | ❌ Not available |
| **Double-click fill handle** (auto-fill to adjacent data) | ❌ Must drag manually |
| **Ctrl-drag to copy** cells | ❌ Use Copy & Paste instead |
| **Shift-drag to insert** cells | ❌ Use Insert from context menu |
| **Alt-drag to another sheet** | ❌ Use Cut & Paste across sheets |
| **F8 Extend Selection mode** | ❌ Use selection handles instead |
| **Shift+F8 Add to Selection** (non-contiguous) | ❌ Very limited multi-range selection on mobile |
| **Border double-click jump** (edge navigation to end of data) | ❌ Use flick on selection handle, or Name Box |
| **Scroll Lock toggle** | ❌ Not applicable |
| **Format Painter via cursor** | ⚠️ Available via ribbon, not via cursor drag |
| **Split panes / Freeze panes via drag** | ⚠️ Freeze Panes available in View menu, not via drag |

---

## 13. Accessibility: VoiceOver & TalkBack

Excel mobile supports screen readers (VoiceOver on iOS, TalkBack on Android):

| Gesture | Action |
|---------|--------|
| **Swipe right/left** | Move to next/previous cell |
| **Double-tap** | Activate (select) the current element |
| **Double-tap and hold, then drag** | Adjust selection handles — VoiceOver announces the cell range as you drag |
| **Three-finger swipe** | Scroll the worksheet |
| **Rotor gesture** (iOS) | Navigate by rows, columns, or headings |

---

## 14. Quick Reference: Gesture-to-Action Map

```
TOUCH INTERACTION MODEL
│
├── TAP (single finger, quick)
│   ├── On cell ────────────────────► Select cell
│   ├── On selected cell ───────────► Open context menu (mini-toolbar)
│   ├── On column/row header ───────► Select entire column/row
│   ├── On sheet tab ───────────────► Switch to that sheet
│   ├── On formula bar ─────────────► Enter edit mode (cursor in formula bar)
│   └── On ribbon button ───────────► Activate that command
│
├── DOUBLE-TAP
│   ├── On cell ────────────────────► Enter edit mode (in-cell editing)
│   ├── On column header border ────► Auto-fit column width
│   ├── On row header border ───────► Auto-fit row height
│   └── On chart ───────────────────► Enter chart edit mode
│
├── LONG-PRESS (tap and hold ~1 sec)
│   ├── On cell ────────────────────► Select + open context menu
│   ├── On selected cell/range ─────► Lift for drag-and-drop move
│   ├── On column/row header ───────► Lift column/row for reorder
│   └── On sheet tab ───────────────► Open sheet context menu
│
├── DRAG (finger down + move)
│   ├── Selection handle (circle) ──► Extend/shrink selection
│   ├── Fill handle (corner square) ► AutoFill adjacent cells
│   ├── Lifted cell/range ──────────► Move cells to new location
│   ├── Column/row header border ───► Resize column/row
│   ├── Chart corner handle ────────► Resize chart
│   └── Chart body ─────────────────► Reposition chart
│
├── FLICK (quick swipe)
│   ├── On worksheet ───────────────► Momentum scroll
│   └── On selection handle ────────► Jump to end of data region
│
├── PINCH (two fingers)
│   ├── Pinch together ─────────────► Zoom out
│   └── Spread apart ───────────────► Zoom in
│
└── SWIPE
    ├── One finger on sheet ────────► Scroll
    └── On sheet tab bar ───────────► Scroll through sheet tabs
```

---

## 15. Platform Comparison: Desktop vs. Mobile

| Interaction | Desktop (Mouse) | Mobile (Touch) |
|-------------|----------------|---------------|
| Select cell | Click | Tap |
| Edit cell | Double-click or F2 | Double-tap |
| Extend selection | Click + drag, or Shift+click | Drag selection handle (circle) |
| Move cells | Hover border → cursor changes → drag | Long-press → drag |
| Copy cells | Ctrl+drag on border | Copy & Paste (no drag equivalent) |
| Fill/AutoFill | Hover fill handle → cursor changes → drag | Tap fill handle or use menu → drag |
| Right-click menu | Right-click | Long-press |
| Resize column/row | Hover header border → drag | Tap and drag header border |
| Auto-fit column | Double-click header border | Double-tap header border |
| Zoom | Ctrl + scroll wheel | Pinch gesture |
| Scroll | Scroll wheel or scroll bars | Swipe / flick |
| Context sensitivity | Cursor shape provides continuous feedback | No pre-action feedback; gesture determines action |

---

*This document covers Excel mobile apps for iOS (iPhone/iPad) and Android (phone/tablet). Behaviors may vary slightly between app versions and OS updates. Last updated: February 2026.*