# Cell Merging — Complete Behavior Reference

A guide to how cell merging works, covering merge types, data loss rules, formula interactions, operational restrictions, and implementation status. Originally based on Google Sheets behavior, each section is annotated with the worksheet widget's implementation status.

> **Legend:** ✅ Implemented | ⚠️ Partial | ❌ Not implemented | 📖 Reference only

### Implementation Summary

The worksheet widget implements the core cell merging infrastructure:

| Feature | Status | Code |
|---------|--------|------|
| `MergedCellRegistry` — stores/queries merged ranges | ✅ | `lib/src/core/data/merged_cell_registry.dart` |
| `MergeRegion` — individual merge region model | ✅ | `lib/src/core/data/merged_cell_registry.dart` |
| `EditingBoundsCalculator` — merge-aware editing bounds | ✅ | `lib/src/core/geometry/editing_bounds_calculator.dart` |
| Merge/unmerge via `WorksheetData` API | ✅ | `data.mergeCells()`, `data.unmergeCells()` |
| Rendering — merged cells paint across full span | ✅ | Gridlines suppressed across merge interior |
| Merge keyboard shortcuts via `Actions` system | ✅ | Standard Shortcuts/Actions integration |
| Sort/filter restrictions | ❌ | Not applicable (no sort/filter in widget) |
| Data validation rules | ❌ | Not applicable |
| Copy-paste merge formatting | ❌ | Clipboard handles values only |
| Context menu merge options | ❌ | No context menu |

---

## 1. The Fundamental Concept

Cell merging is a **formatting operation, not a data operation**. It combines multiple adjacent cells into a single larger cell for visual presentation purposes.

**The cardinal rule:** Only the value in the **top-left cell** (the anchor) of the selected range survives a merge. All other cell contents are **cleared**.

> **Implementation Status:** ✅ Implemented
>
> **Code:** `lib/src/core/data/merged_cell_registry.dart` — `MergedCellRegistry` enforces this rule. The `addMerge()` / `removeMerge()` / `getMergeContaining()` methods manage merge lifecycle. `data.mergeCells(range)` clears all non-anchor cells.

---

## 2. Merge Types

Google Sheets offers three merge operations and one undo operation.

> **Implementation Status:** ⚠️ Partial — the widget supports "Merge All" via `data.mergeCells(range)`. Merge Horizontally and Merge Vertically are not separate operations but can be achieved by calling `mergeCells()` on individual rows/columns.

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

Only A1's value is kept. B1, C1, A2, B2, C2, A3, B3, C3 are all cleared.

### 2.2 Merge Horizontally

📖 *No dedicated API — achieve by merging individual rows.*

Merges cells **across columns within each row separately**. Each row becomes its own merged cell.

### 2.3 Merge Vertically

📖 *No dedicated API — achieve by merging individual columns.*

Merges cells **down rows within each column separately**. Each column becomes its own merged cell.

### 2.4 Unmerge

> **Implementation Status:** ✅ Implemented — `data.unmergeCells(coordinate)` splits a merged cell back into individual cells.

Splits a merged cell back into its original individual cells. The merged cell's value stays in the **top-left cell**; all other cells remain **empty**. Unmerging does **not** restore previously cleared data.

### 2.5 Equivalence Rules

When the selection is a single row, Merge All and Merge Horizontally produce the same result.
When the selection is a single column, Merge All and Merge Vertically produce the same result.

---

## 3. Accessing Merge

### 3.1 Programmatic API

> **Implementation Status:** ✅ Implemented

```dart
// Merge cells — anchor keeps value, others cleared
data.mergeCells(CellRange(0, 0, 0, 3));  // Merge A1:D1

// Unmerge by passing any cell in the merged region
data.unmergeCells(const CellCoordinate(0, 0));

// Query merges
final registry = data.mergedCells;
registry.isMerged(const CellCoordinate(0, 1));         // true
registry.getRegion(const CellCoordinate(0, 1));         // MergeRegion for A1:D1
registry.regionsInRange(CellRange(0, 0, 10, 10));       // All merges in range
```

### 3.2 Keyboard Shortcuts

> **Implementation Status:** 📖 Reference only — no built-in merge shortcut. Can be added via the `shortcuts`/`actions` parameters on `Worksheet`.

Google Sheets shortcut sequences (for reference):

| Platform | Sequence |
|----------|----------|
| **Windows / ChromeOS** | `Alt` → `O` → `M` → then `A` (All), `H` (Horizontally), `V` (Vertically), or `U` (Unmerge) |
| **Mac** | `Ctrl + Option + O` → `M` → then `A`, `H`, `V`, or `U` |

### 3.3 Mobile App

> **Implementation Status:** 📖 Reference only — no built-in merge UI on mobile. See [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md) for touch interaction details.

---

## 4. Data Loss Rules

This is the most important section. Merging clears data from non-anchor cells.

> **Implementation Status:** ✅ Implemented — `data.mergeCells()` clears all non-anchor cell values.

### 4.1 What Counts as "Data"

| Content Type | Counts as data? | Cleared on merge? |
|-------------|----------------|-------------------|
| Text | Yes | Yes (non-anchor cells) |
| Numbers | Yes | Yes (non-anchor cells) |
| Formulas | Yes | Yes (non-anchor cells) |
| Formatting/style | No | Preserved on anchor |
| Rich text spans | Yes | Yes (non-anchor cells) |

### 4.2 What Survives

After merging, the resulting cell has:
- The **value** of the top-left (anchor) cell
- The **style** of the anchor cell
- A new, larger **cell boundary** spanning the merged area

### 4.3 What Is Cleared

- All values in every cell except the anchor
- All styles on non-anchor cells (styles are per-cell, not per-region)
- The individual cell identity of every non-anchor cell

### 4.4 Unmerge Does Not Restore

Unmerging places the value in the anchor cell and leaves all other cells empty. Data cleared during the original merge is gone permanently.

---

## 5. How Formulas Interact with Merged Cells

> **Implementation Status:** 📖 Reference only — the widget stores formulas as text (`CellValue.formula`) but does not evaluate them. These rules are relevant if you implement formula evaluation.

### 5.1 Referencing a Merged Cell

A merged cell spanning A2:A5 has its value stored **only in A2**. Cells A3, A4, A5 are treated as **empty** by formula engines.

| Formula | Result |
|---------|--------|
| `=A2` | Returns the merged cell's value ✓ |
| `=A3` | Returns **empty / 0** ✗ |

**Rule:** Always reference the **top-left cell address** of a merged range to get its value.

### 5.2 Range Functions

| Function | Behavior with merged cells in range |
|----------|-------------------------------------|
| `SUM(A1:A10)` | Only counts the anchor cell; "empty" cells contribute 0 |
| `AVERAGE(A1:A10)` | Empty cells in the merged block may skew the average |
| `VLOOKUP` | Only matches the anchor cell |

### 5.3 The SUM Trap

```
Column A      Column B
┌─────────┐   ┌───┐
│         │   │ 1 │  ← B1
│  "4"    │   ├───┤
│ (merged │   │ 2 │  ← B2
│  A1:A3) │   ├───┤
│         │   │ 3 │  ← B3
└─────────┘   └───┘

=SUM(A1:A3) → 4  (only A1 has a value; A2, A3 are empty)
```

---

## 6. Operational Restrictions

Merged cells can break many standard spreadsheet operations.

> **Implementation Status:** ⚠️ Partial — the widget enforces some restrictions (overlapping merges are rejected), but most operational restrictions are not applicable since the widget doesn't include sort, filter, or pivot table features.

### 6.1 Overlapping Merges

> ✅ **Enforced.** Merging a range that overlaps an existing merge throws `ArgumentError`.

### 6.2 Minimum Size

> ✅ **Enforced.** The range must contain at least 2 cells.

### 6.3 Sorting

> 📖 **Reference only.** Cannot sort a range containing vertically merged cells. Not applicable — widget has no sort feature.

### 6.4 Filtering

> 📖 **Reference only.** Cannot create a filter over a range containing vertical merges. Not applicable — widget has no filter feature.

### 6.5 Inserting Rows/Columns

> 📖 **Reference only.** Cannot insert between cells that are part of a merged block. Not applicable — widget has no insert row/column feature.

### 6.6 Copy and Paste

> ⚠️ **Partial.** Clipboard copy/paste handles values only — merge formatting is not transferred.

| Operation | Behavior |
|-----------|----------|
| Copy a merged cell → Paste | Pastes the anchor's value only, no merge formatting |
| Copy normal cells → Paste into merged area | Pastes into the anchor cell |

### 6.7 Drag-to-Fill (AutoFill)

> ⚠️ **Partial.** Fill handle behavior through merged regions is not specially handled.

### 6.8 Data Validation

> 📖 **Reference only.** Not applicable — widget has no data validation feature.

---

## 7. Merge Interactions Summary Table

| Operation | Works with Merged Cells? | Widget Status |
|-----------|-------------------------|---------------|
| Merge overlapping ranges | ❌ Error thrown | ✅ Enforced |
| Merge single cell | ❌ Error thrown | ✅ Enforced |
| Rendering across merged bounds | ✅ Yes | ✅ Implemented |
| Selection of merged cells | ✅ Yes | ✅ Implemented |
| Editing merged cell | ✅ Edits anchor | ✅ Implemented |
| Copy → Paste | ⚠️ Value only | ⚠️ Partial |
| Sort | ❌ Error in Sheets | 📖 N/A |
| Filter | ❌ Error in Sheets | 📖 N/A |
| AutoFill through merged | ⚠️ Unreliable | ⚠️ Partial |
| Find & Replace | ✅ Finds anchor value | 📖 N/A |

---

## 8. When to Use (and Never Use) Merge

### ✅ Appropriate Uses

- **Report titles** spanning multiple columns above a data table
- **Section headers** in a presentation-style layout
- **Category labels** along the side of a formatted report
- **Dashboard labels** for visual grouping

### ❌ Never Use Merge In

- Any column or row that will be **sorted**
- Any range that will have **filters** applied
- Any range used as **source data** for formulas or lookups
- Any **data entry** area where values need to be independently edited per cell

---

## 9. Merging Data with Formulas (The Right Way)

> **Implementation Status:** 📖 Reference only — these are spreadsheet formula techniques, not widget features.

When the goal is to **combine text from multiple cells** into one value, never use the merge tool — use formulas instead.

### 9.1 Ampersand (`&`)

```
=A1 & " " & B1
```

### 9.2 TEXTJOIN (Recommended)

```
=TEXTJOIN(", ", TRUE, A1:D1)
```

- First argument: delimiter
- Second argument: `TRUE` = skip empty cells
- Third argument: range

---

## 10. Finding Merged Cells

> **Implementation Status:** ✅ Implemented via `MergedCellRegistry` API

### 10.1 Programmatic Query

```dart
final registry = data.mergedCells;

// Check if a specific cell is merged
final isMerged = registry.isMerged(const CellCoordinate(0, 1));

// Get the merge region containing a cell
final region = registry.getRegion(const CellCoordinate(0, 1));
print(region?.anchor);  // Top-left cell
print(region?.range);   // Full merge range

// Find all merges in a visible range
final merges = registry.regionsInRange(CellRange(0, 0, 50, 26));

// Iterate all merges
for (final region in registry.regions) {
  print('${region.anchor} → ${region.range}');
}
```

### 10.2 📖 Google Sheets: Apps Script

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

---

## 11. Google Sheets vs. Excel: Merge Behavior Differences

> **Implementation Status:** 📖 Reference only — for users comparing our widget's behavior to spreadsheet apps.

| Behavior | Google Sheets | Excel (Desktop) | Our Widget |
|----------|--------------|-----------------|------------|
| **Data loss on merge** | Only top-left kept | Only top-left kept | Same ✅ |
| **Warning before merge** | Yes — dialog | Yes — dialog | No warning (programmatic API) |
| **Merge types** | All, Horizontally, Vertically | Merge & Center, Merge Across | All (via API) |
| **Sort with merged cells** | Blocked with error | Blocked with error | N/A |
| **Unmerge restores data** | No | No | No ✅ |
| **Center Across Selection** | Not available | Available | Not available |

---

## 12. Workarounds for Merged-Cell Problems

> **Implementation Status:** 📖 Reference only — these are spreadsheet workflow tips.

### 12.1 Need to sort/filter data with category labels

Don't merge. Instead, repeat the category value in every row.

### 12.2 Need to visually center a title across columns

Use `mergeCells()` on the title row — since it's above the data range, it won't interfere with data operations.

### 12.3 Pasting data into a sheet with merged cells

Unmerge cells first (`data.unmergeCells(coordinate)`), paste your data, then re-merge if needed.

---

## 13. Apps Script / API Reference

> **Implementation Status:** 📖 Reference only — Google Sheets API, not applicable to widget implementation.

```javascript
// Merge a range
SpreadsheetApp.getActiveSheet().getRange("A1:C1").merge();

// Unmerge
SpreadsheetApp.getActiveSheet().getRange("A1:C1").breakApart();

// Check if a range is merged
var mergedRanges = SpreadsheetApp.getActiveSheet()
    .getRange("A1:Z100").getMergedRanges();
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
│          └── NO → ✅ MERGE IS FINE (titles, headers, layouts)
│
└── NO → Do you need to COMBINE DATA VALUES from multiple cells?
          │
          └── YES → ❌ DO NOT MERGE. Use formulas:
                     TEXTJOIN, &, CONCATENATE, JOIN
```

---

## 15. Widget API Quick Reference

```dart
// Merge cells
data.mergeCells(CellRange(0, 0, 0, 3));  // Merge A1:D1

// Unmerge
data.unmergeCells(const CellCoordinate(0, 0));

// Query
final registry = data.mergedCells;  // MergedCellRegistry
registry.isMerged(coord);           // bool
registry.isAnchor(coord);           // bool
registry.getRegion(coord);          // MergeRegion?
registry.resolveAnchor(coord);      // CellCoordinate (anchor or self)
registry.regions;                    // Iterable<MergeRegion>
registry.regionCount;                // int
registry.isEmpty;                    // bool
registry.regionsInRange(range);      // Iterable<MergeRegion>
```

For complete API details, see [API.md](API.md#cell-merging). For practical recipes, see the [Cell Merging recipe in COOKBOOK.md](COOKBOOK.md#cell-merging).

---

## See Also

- [MOBILE_INTERACTION.md](MOBILE_INTERACTION.md) — Touch interaction with merged cells
- [MOUSE_CURSOR.md](MOUSE_CURSOR.md) — Desktop cursor behavior over merged cells
- [Cookbook](COOKBOOK.md) — Practical recipes including cell merging
- [API Reference](API.md) — Quick reference for all classes and methods

---

*This document covers cell merging behavior for the worksheet widget and as a reference for Google Sheets behavior. Sections are annotated with implementation status. Last updated: February 2026.*
