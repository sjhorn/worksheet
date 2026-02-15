# Overflow Behavior

## Horizontal Overflow

**Text overflows into adjacent empty cells (right)**
- Default behavior for left-aligned text in a cell when neighboring cells to the right are empty
- Text visually spills across cell boundaries but remains owned by the original cell
- Overflow stops at the first non-empty adjacent cell — text appears truncated at that boundary

**Right-to-left overflow**
- Right-aligned text can overflow leftward into empty cells to the left
- Center-aligned text overflows in both directions symmetrically

**No overflow (truncation)**
- When adjacent cells contain data, the text is visually clipped at the cell border
- The full content is still there (visible in the formula bar), just not rendered

**Wrap Text mode**
- When "Wrap Text" is enabled, horizontal overflow is suppressed entirely
- Text wraps within the cell width, and the row height grows to accommodate (unless manually fixed)

**Shrink to Fit**
- Font size is reduced until all content fits within the cell width
- No overflow occurs; no wrapping occurs

**Merged cells**
- The "cell width" for overflow purposes becomes the total width of the merged range
- Overflow beyond the merged area follows the same rules as above

## Vertical Overflow

**Row height auto-expand**
- When Wrap Text is on and row height is set to auto, the row grows vertically to fit all wrapped lines
- This is the primary "vertical overflow" mechanism

**Vertical clipping**
- If row height is manually fixed (not auto), wrapped text that exceeds the row height is clipped at the bottom
- Content is hidden, not gone

**No native vertical overflow into cells below**
- Unlike horizontal, Excel never visually spills content into the cell below. Vertical overflow is always either accommodated (row grows) or clipped.

## Summary Table

| Scenario | H-Align | Wrap Text | Adjacent cell empty? | Row height | Result |
|---|---|---|---|---|---|
| Default | Left | Off | Yes | Auto | Overflows right |
| Default | Left | Off | No | Auto | Truncated visually |
| Default | Right | Off | Yes | Auto | Overflows left |
| Default | Center | Off | Yes | Auto | Overflows both directions |
| Wrapped | Any | On | N/A | Auto | Wraps, row expands |
| Wrapped + fixed row | Any | On | N/A | Fixed | Wraps, clipped at bottom |
| Shrink to fit | Any | Off | N/A | Any | Font shrinks, no overflow |

## Implementation Pointers for Claude Code (openpyxl / xlsxwriter)

**Key properties per cell to track:**
- `alignment.wrap_text` (bool)
- `alignment.shrink_to_fit` (bool)
- `alignment.horizontal` (`'left'`, `'right'`, `'center'`, `'justify'`)
- `alignment.vertical` (`'top'`, `'center'`, `'bottom'`)
- Column width (in character units) and row height (in points)
- Whether the cell is part of a merged range

**Rendering algorithm (if you're building a visual preview or layout engine):**

1. **Measure text width** — use font metrics (font name, size, bold/italic) to compute pixel width of the string. Account for number formats (a date or currency may render differently from the raw value).

2. **Check shrink-to-fit first** — if enabled, iteratively reduce font size until text fits cell width. Done.

3. **Check wrap-text** — if enabled, word-wrap the text at cell width boundaries. Compute the number of lines. Multiply by line height to get required row height. If row height is auto, expand it. If fixed, clip.

4. **Horizontal overflow** (wrap text OFF, shrink to fit OFF):
   - Compute how many pixels the text exceeds the cell width.
   - Based on alignment, determine overflow direction (left-align → right, right-align → left, center → both).
   - Walk adjacent cells in the overflow direction. For each empty cell, "consume" its width. Stop when you run out of excess width or hit a non-empty cell.
   - Render the text clipped at whatever boundary you reached.

5. **Gotchas:**
   - Merged cells: use the combined width of all merged columns as the "cell width."
   - Numbers and dates that don't fit show `######` instead of overflowing — this is a special case for numeric/date-formatted cells only.
   - Rich text (mixed formatting within a cell) complicates width measurement significantly.
   - Column widths in Excel are in "character width" units (based on the default font's `0` character), not pixels. The conversion is roughly `pixel_width = (char_width * 7 + 5)` for the default Calibri 11pt, but varies by font.
   - Row heights are in points (1 point = 1/72 inch = ~1.333 pixels at 96 DPI).

6. **Testing tip:** Create a reference Excel file with all overflow scenarios, open it in Excel, screenshot it, and compare against your rendering output pixel-by-pixel.