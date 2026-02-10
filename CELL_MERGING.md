# Google Sheets: Cell Merging — Complete Behavior Reference

A guide to how cell merging works in Google Sheets, covering merge types, data loss rules, formula interactions, operational restrictions, and the critical distinction between merging cells (formatting) and merging data (formulas).

---

## 1. The Fundamental Concept

Cell merging in Google Sheets is a **formatting operation, not a data operation**. It combines multiple adjacent cells into a single larger cell for visual presentation purposes. Think of it as knocking down walls between rooms — the rooms become one, but you can only keep one room's contents.

**The cardinal rule:** Only the value in the **top-left cell** of the selected range survives a merge. All other cell contents are **permanently deleted**.

This distinction is critical:

| Goal | Correct Tool |
|------|-------------|
| Make a title span across columns | Merge Cells (formatting) |
| Combine text from multiple cells into one value | Formula: `&`, `CONCATENATE`, `TEXTJOIN`, `JOIN` |
| Group visual sections of a report | Merge Cells (formatting) |
| Create a single data value from multiple inputs | Formula (never merge) |

---

## 2. Merge Types

Google Sheets offers three merge operations and one undo operation, accessible via **Format → Merge cells** or the toolbar merge icon.

### 2.1 Merge All

Combines every selected cell into **one single cell**, regardless of how many rows and columns are selected.

```
Before (selected A1:C3):          After Merge All:
┌───┬───┬───┐                     ┌───────────────┐
│ A1│ B1│ C1│                     │               │
├───┼───┼───┤                     │      A1       │
│ A2│ B2│ C2│         →           │   (one cell)  │
├───┼───┼───┤                     │               │
│ A3│ B3│ C3│                     └───────────────┘
└───┴───┴───┘
```

Only A1's value is kept. B1, C1, A2, B2, C2, A3, B3, C3 are all deleted.

### 2.2 Merge Horizontally

Merges cells **across columns within each row separately**. Each row becomes its own merged cell.

```
Before (selected A1:C3):          After Merge Horizontally:
┌───┬───┬───┐                     ┌───────────────┐
│ A1│ B1│ C1│                     │      A1       │
├───┼───┼───┤                     ├───────────────┤
│ A2│ B2│ C2│         →           │      A2       │
├───┼───┼───┤                     ├───────────────┤
│ A3│ B3│ C3│                     │      A3       │
└───┴───┴───┘                     └───────────────┘
```

Three merged cells result. Within each row, only the leftmost cell's value is kept (A1, A2, A3). B and C column values in each row are deleted.

### 2.3 Merge Vertically

Merges cells **down rows within each column separately**. Each column becomes its own merged cell.

```
Before (selected A1:C3):          After Merge Vertically:
┌───┬───┬───┐                     ┌───┬───┬───┐
│ A1│ B1│ C1│                     │   │   │   │
├───┼───┼───┤                     │A1 │B1 │C1 │
│ A2│ B2│ C2│         →           │   │   │   │
├───┼───┼───┤                     │   │   │   │
│ A3│ B3│ C3│                     └───┴───┴───┘
└───┴───┴───┘
```

Three merged cells result. Within each column, only the topmost cell's value is kept (A1, B1, C1). Row 2 and 3 values in each column are deleted.

### 2.4 Unmerge

Splits a merged cell back into its original individual cells. The merged cell's value goes to the **top-left cell**; all other cells become **empty**. Unmerging does **not** restore previously deleted data.

### 2.5 Equivalence Rules

When the selection is a single row, **Merge All** and **Merge Horizontally** produce the same result.
When the selection is a single column, **Merge All** and **Merge Vertically** produce the same result.

---

## 3. Accessing Merge

### 3.1 Menu

**Format → Merge cells →** choose Merge All / Merge Horizontally / Merge Vertically / Unmerge

The available options change based on your selection:
- Single row selected → Merge Vertically is unavailable (or equivalent to Merge All)
- Single column selected → Merge Horizontally is unavailable (or equivalent to Merge All)
- Multi-row, multi-column block → all three options appear

### 3.2 Toolbar

The **Merge cells icon** (two squares merging into one) is in the toolbar next to the Borders icon.
- Clicking the icon directly performs **Merge All**
- Clicking the **dropdown arrow** next to it reveals all merge/unmerge options

### 3.3 Keyboard Shortcuts

There is no single-key shortcut. Instead, use a menu-key sequence:

| Platform | Sequence |
|----------|----------|
| **Windows / ChromeOS** | `Alt` → `O` → `M` → then `A` (All), `H` (Horizontally), `V` (Vertically), or `U` (Unmerge) |
| **Mac** | `Ctrl + Option + O` → `M` → then `A`, `H`, `V`, or `U` |

Alternatively, use the **menu search** shortcut (`Alt + /` on Windows, `Option + /` on Mac), type "Merge", and select the desired option.

### 3.4 Mobile App (iOS / Android)

- Select cells → tap the **formatting icon** (A with lines) → **Cell** tab → toggle **Merge** on/off
- Or use the **merge icon** in the bottom toolbar
- **Only "Merge All" is available** on mobile — no Merge Horizontally or Vertically options

---

## 4. Data Loss Rules

This is the most important section. Merging destroys data.

### 4.1 The Warning Dialog

If **any cell other than the top-left cell** in the selection contains data, Google Sheets shows a warning:

> "Merging cells only keeps the top-left value and discards the rest."

You must click **OK** to proceed. There is no "merge and keep all data" option in the built-in tool.

### 4.2 What Counts as "Data"

| Content Type | Counts as data? | Triggers warning? |
|-------------|----------------|-------------------|
| Text | Yes | Yes |
| Numbers | Yes | Yes |
| Formulas (any result) | Yes | Yes |
| Empty string (`""`) | Yes | Yes |
| Formatting only (no value) | No | No |
| Data validation rules | Silently removed | No |
| Comments/Notes | Preserved only on top-left cell | No |
| Conditional formatting rules | May behave unexpectedly | No |

### 4.3 What Survives

After merging, the resulting cell has:
- The **value** of the top-left cell
- The **formatting** (font, color, borders, alignment) of the top-left cell
- The **comment/note** of the top-left cell (if any)
- A new, larger **cell boundary** spanning the merged area

### 4.4 What Is Destroyed

- All values in every cell except the top-left
- All formulas in every cell except the top-left
- All comments/notes on non-top-left cells
- All data validation rules on non-top-left cells
- The individual cell identity of every non-top-left cell (they become part of the merged block)

### 4.5 Unmerge Does Not Restore

Unmerging places the value in the top-left cell and leaves all other cells **blank**. The data deleted during the original merge is gone permanently (unless you Undo immediately with `Ctrl+Z`).

---

## 5. How Formulas Interact with Merged Cells

### 5.1 Referencing a Merged Cell

A merged cell spanning A2:A5 (four rows) has its value stored **only in A2**. Cells A3, A4, and A5 are treated as **empty** by the formula engine, even though they visually appear to contain the value.

| Formula | Result |
|---------|--------|
| `=A2` | Returns the merged cell's value ✓ |
| `=A3` | Returns **empty / 0** ✗ |
| `=A4` | Returns **empty / 0** ✗ |
| `=A5` | Returns **empty / 0** ✗ |

**Rule:** Always reference the **top-left cell address** of a merged range to get its value.

### 5.2 Range Functions

| Function | Behavior with merged cells in range |
|----------|-------------------------------------|
| `SUM(A1:A10)` | Only counts the top-left cell's value; "empty" cells in the merged block contribute 0. **Can give silently wrong results.** |
| `AVERAGE(A1:A10)` | Counts the empty cells in the merged block as non-existent (not as zeros), which may skew the average unpredictably. |
| `COUNT(A1:A10)` | Only counts the top-left cell. The rest of the merged block's cells are not counted. |
| `COUNTA(A1:A10)` | Only counts the top-left cell as non-empty. |
| `VLOOKUP` | Only matches the top-left cell. Rows covered by the merged block but below the top-left are treated as having empty lookup values — the lookup will **miss** them. |
| `QUERY` | Same problem — merged cells below the top-left are invisible to QUERY. |
| `FILTER` | Same problem — only the top-left row matches criteria. |

### 5.3 The SUM Trap (Illustrated)

```
Column A      Column B
┌─────────┐   ┌───┐
│         │   │ 1 │  ← B1
│  "4"    │   ├───┤
│ (merged │   │ 2 │  ← B2
│  A1:A3) │   ├───┤
│         │   │ 3 │  ← B3
└─────────┘   └───┘

=SUM(B1:B3) → 6  ✓ (correct, B column is normal)
=SUM(A1:A3) → 4  (only A1 has a value; A2, A3 are empty)
```

If you expected the "4" to be in B-column alongside other values, a merged cell in A silently changes what formulas see.

### 5.4 Formulas Inside Merged Cells

A formula can exist in a merged cell (it lives in the top-left cell). The formula works normally — the merge only affects the cell's visual size, not the formula engine's behavior. However, if you later unmerge, the formula stays only in the top-left cell.

---

## 6. Operational Restrictions

Merged cells break many standard spreadsheet operations. Here is a complete catalog of what is restricted.

### 6.1 Sorting

**Cannot sort a range containing vertically merged cells.**

Error message: *"These cells can't be sorted because they contain merged cells. Unmerge the cells first."* (or similar wording)

Google Sheets cannot rearrange rows when a single cell spans multiple rows — it doesn't know which row the merged cell "belongs to." You must **unmerge first**, then sort.

### 6.2 Filtering

**Cannot create a filter over a range containing vertical merges.**

Error message: *"You can't create a filter over a range containing vertical merges."*

The filter dropdown cannot appear on a column where cells span multiple rows. Even if the merged cells are in a different column, if the filter range includes them, filtering is blocked.

Additionally, if a filter is active and you try to merge cells vertically within the filtered range, the merge will fail or clear values.

### 6.3 Inserting Rows/Columns

**Cannot insert a row or column between cells that are part of a merged block.**

If cells A2:A5 are merged, you cannot insert a row between rows 3 and 4 — the merged cell spans that boundary. You must **unmerge first**, insert the row, then re-merge if desired.

### 6.4 Copy and Paste

| Operation | Behavior |
|-----------|----------|
| Copy a merged cell → Paste | Pastes the **merged cell with its formatting** — the destination gets merged cells too |
| Copy a merged cell → Paste Special → Values only | Pastes **only the value** into the top-left destination cell, no merge formatting |
| Copy normal cells → Paste into a merged cell area | May fail or produce unexpected results if the source dimensions don't match the merged area |
| Copy a multi-cell range that spans a merged block | Only copies the formula/value from the top-left cell of the merged block; other positions in the merged block are treated as empty |

### 6.5 Drag-to-Fill (AutoFill)

Fill handle behavior is disrupted by merged cells. Dragging through or across merged cells may skip them, fail, or produce errors. AutoFill patterns (series, formulas) cannot reliably extend through merged regions.

### 6.6 Data Validation

Data validation rules applied to cells that are subsequently merged may be silently removed from the non-top-left cells. The top-left cell retains its validation. Applying data validation to a merged cell applies it only to the top-left cell address.

### 6.7 Pivot Tables

Merged cells in source data will cause pivot tables to misread the data. Rows spanned by a vertical merge will appear to have blank values in the merged column, leading to incorrect grouping and aggregation.

### 6.8 Apps Script / API

The Google Sheets API and Apps Script treat merged cells as a range property. Reading a merged range returns the value only at the top-left cell; all other cells in the range return empty. The `merge()` and `breakApart()` methods on Range objects control merging programmatically.

---

## 7. Merge Interactions Summary Table

| Operation | Works with Merged Cells? | Details |
|-----------|-------------------------|---------|
| Sort | ❌ No | Error: "contains merged cells" |
| Filter / Create filter | ❌ No | Error: "range containing vertical merges" |
| Insert row between merged rows | ❌ No | Must unmerge first |
| Insert column between merged columns | ❌ No | Must unmerge first |
| Copy → Paste | ⚠️ Partial | Copies merge formatting too |
| Copy → Paste Values Only | ✅ Yes | Only pastes the value |
| AutoFill / Fill handle | ⚠️ Unreliable | Skips or errors on merged regions |
| VLOOKUP across merged cells | ⚠️ Partial | Only matches top-left cell |
| SUM across merged cells | ⚠️ Silently wrong | Empty cells in merge contribute 0 |
| Conditional formatting | ⚠️ Partial | Applies to the merged block as one unit |
| Data validation | ⚠️ Partial | Only top-left cell retains validation |
| Charts | ⚠️ Partial | May misread data ranges |
| Pivot tables | ⚠️ Unreliable | Blank rows in merged column |
| Find & Replace | ✅ Yes | Finds value in top-left cell |
| Protect range | ✅ Yes | Protection applies to the merged block |
| Conditional formatting | ✅ Yes | Treats merged block as one cell |

---

## 8. When to Use (and Never Use) Merge

### ✅ Appropriate Uses

- **Report titles** spanning multiple columns above a data table
- **Section headers** in a presentation-style sheet (not a data sheet)
- **Category labels** along the side of a formatted report
- **Print/PDF layouts** where visual grouping matters and data will not be processed
- **Dashboard labels** in a separate "presentation" tab (keep raw data in a separate, unmerged tab)

### ❌ Never Use Merge In

- Any column or row that will be **sorted**
- Any range that will have **filters** applied
- Any range used as **source data** for formulas, VLOOKUP, QUERY, FILTER, or pivot tables
- Any range where you need to **insert or delete rows/columns** within the merged area
- Any **data entry** area where values need to be independently edited per cell
- Any sheet that will be **imported into another tool** (merged cells often cause parsing issues)

### Best Practice: Two-Tab Approach

1. **Raw Data tab** — clean, unmerged, one-value-per-cell data suitable for formulas and analysis
2. **Report/Dashboard tab** — uses merged cells freely for presentation, pulling values from the raw data tab via formulas

---

## 9. Merging Data with Formulas (The Right Way)

When the goal is to **combine text from multiple cells** into one value, never use the merge tool — use formulas instead.

### 9.1 Ampersand (`&`)

```
=A1 & " " & B1
```

Simple, readable. Good for joining 2–3 cells with a known separator.

### 9.2 CONCATENATE

```
=CONCATENATE(A1, " ", B1, " ", C1)
```

Functionally identical to `&` but can accept multiple arguments. Does not skip blanks.

### 9.3 TEXTJOIN (Recommended)

```
=TEXTJOIN(", ", TRUE, A1:D1)
```

- First argument: delimiter (", " in this case)
- Second argument: `TRUE` = skip empty cells; `FALSE` = include them
- Third argument: range or multiple values

This is the most flexible option. It handles ranges, skips blanks, and accepts custom delimiters.

### 9.4 JOIN

```
=JOIN(" - ", A1:D1)
```

Similar to TEXTJOIN but cannot skip blanks. Simpler syntax for basic cases.

### 9.5 Line Breaks Within a Cell

To combine values on **separate lines within one cell**, use `CHAR(10)`:

```
=A1 & CHAR(10) & B1 & CHAR(10) & C1
```

Then enable **Format → Wrapping → Wrap** on the cell to make the line breaks visible.

### 9.6 ARRAYFORMULA for Entire Columns

```
=ARRAYFORMULA(A2:A & " " & B2:B)
```

Combines every row at once without dragging formulas down.

---

## 10. Finding Merged Cells in a Sheet

There is no built-in "Find all merged cells" tool. Methods to locate them:

### 10.1 Visual Inspection

Merged cells are visually obvious — they span multiple rows or columns. Zoom out and scan for irregularly sized cells.

### 10.2 Menu Search

Use the menu search shortcut (`Alt + /` or `Option + /`), type "Merge" — if a merged cell is selected, you'll see "Unmerge" as an option, confirming it's merged.

### 10.3 Apps Script

```javascript
function findMergedCells() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var mergedRanges = sheet.getRange(1, 1, sheet.getMaxRows(), sheet.getMaxColumns())
                         .getMergedRanges();
  mergedRanges.forEach(function(range) {
    Logger.log(range.getA1Notation());
  });
}
```

This logs every merged range in the active sheet.

### 10.4 Trigger: Sort or Filter

Attempting to sort or filter a range will immediately produce an error if merged cells exist within it — this is an indirect but effective detection method.

---

## 11. Google Sheets vs. Excel: Merge Behavior Differences

| Behavior | Google Sheets | Excel (Desktop) |
|----------|--------------|-----------------|
| **Data loss on merge** | Only top-left value kept | Only top-left value kept (same) |
| **Warning before merge** | Yes — dialog with OK/Cancel | Yes — similar dialog |
| **Merge types** | Merge All, Horizontally, Vertically | Merge & Center, Merge Across, Merge Cells |
| **"Merge & Center"** | No dedicated option (merge then center manually) | Built-in single-click option |
| **Sort with merged cells** | Blocked with error | Blocked with error (same) |
| **Filter with merged cells** | Blocked with error | Allowed but unpredictable behavior |
| **VLOOKUP on merged range** | Top-left only; rest empty | Same behavior |
| **Unmerge restores data** | No | No (same) |
| **Center Across Selection** (no merge) | Not available | Available — a superior alternative that visually centers without merging |
| **Find merged cells** | No built-in tool | Find & Select → Merged Cells |
| **Mobile merge** | Merge All only | Not available on mobile |
| **Cross-app compatibility** | Merged cells may display differently when opened in Excel and vice versa; text alignment and row/column sizing can shift |

### Excel's "Center Across Selection" Advantage

Excel offers **Format Cells → Alignment → Horizontal: Center Across Selection**, which visually centers text across multiple columns **without actually merging them**. This avoids all the operational restrictions of merging while achieving the same visual effect. Google Sheets has no equivalent feature.

---

## 12. Workarounds for Merged-Cell Problems

### 12.1 Problem: Need to sort/filter data with category labels

**Workaround:** Don't merge. Instead, repeat the category value in every row (fill down). Use conditional formatting or a helper column to visually group them if needed.

### 12.2 Problem: VLOOKUP can't find rows in a merged range

**Workaround:** Create a helper column that fills the merged value down using:
```
=ARRAYFORMULA(LOOKUP(ROW(A2:A), ROW(A2:A)/(A2:A<>""), A2:A))
```
This propagates the top-left value of each merged block into every row, making the data formula-friendly.

### 12.3 Problem: Need to visually center a title across columns

**Workaround (if avoiding merge):** Place the title in the leftmost cell. Select the range. Apply **Center** alignment. The text won't visually span, but it avoids merge complications. Alternatively, accept the merge if the title row is above the data range and not included in sort/filter ranges.

### 12.4 Problem: Pasting data into a sheet with merged cells

**Workaround:** Unmerge all cells first (`Format → Merge cells → Unmerge`), paste your data, then re-merge decorative cells if needed.

---

## 13. Apps Script Reference

Common programmatic operations for merged cells:

```javascript
// Merge a range
SpreadsheetApp.getActiveSheet().getRange("A1:C1").merge();

// Merge vertically
SpreadsheetApp.getActiveSheet().getRange("A1:A5").mergeVertically();

// Merge across (horizontally, per row)
SpreadsheetApp.getActiveSheet().getRange("A1:C3").mergeAcross();

// Unmerge
SpreadsheetApp.getActiveSheet().getRange("A1:C1").breakApart();

// Check if a range is merged
var mergedRanges = SpreadsheetApp.getActiveSheet()
    .getRange("A1:Z100").getMergedRanges();
// Returns an array of Range objects that are merged

// Get value from merged cell (always use top-left)
var value = SpreadsheetApp.getActiveSheet().getRange("A1").getValue();
```

---

## 14. Quick Decision Flowchart

```
Do you need to COMBINE VISUAL SPACE (formatting)?
│
├── YES → Will this range ever be sorted, filtered, or used in formulas?
│          │
│          ├── YES → ❌ DO NOT MERGE. Use fill-down, helper columns,
│          │          or a separate presentation tab.
│          │
│          └── NO → ✅ MERGE IS FINE (titles, headers, print layouts)
│
└── NO → Do you need to COMBINE DATA VALUES from multiple cells?
          │
          └── YES → ❌ DO NOT MERGE. Use formulas:
                     TEXTJOIN, &, CONCATENATE, JOIN
```

---

## 15. Keyboard Shortcut Reference

| Action | Windows / ChromeOS | Mac |
|--------|-------------------|-----|
| Open Merge menu | `Alt` → `O` → `M` | `Ctrl + Option + O` → `M` |
| Merge All | `Alt, O, M, A` | `Ctrl+Option+O, M, A` |
| Merge Horizontally | `Alt, O, M, H` | `Ctrl+Option+O, M, H` |
| Merge Vertically | `Alt, O, M, V` | `Ctrl+Option+O, M, V` |
| Unmerge | `Alt, O, M, U` | `Ctrl+Option+O, M, U` |
| Menu search → type "Merge" | `Alt + /` | `Option + /` |
| Undo (rescue data after accidental merge) | `Ctrl + Z` | `Cmd + Z` |
| Paste Values Only (avoid pasting merge format) | `Ctrl + Shift + V` | `Cmd + Shift + V` |

---

*This document covers Google Sheets (web, desktop via browser) and the Google Sheets mobile app (iOS/Android). Behaviors may vary slightly with app updates. Last updated: February 2026.*