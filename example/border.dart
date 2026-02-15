import 'package:flutter/material.dart' hide BorderStyle;
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: BorderDemo()));

class BorderDemo extends StatefulWidget {
  const BorderDemo({super.key});

  @override
  State<BorderDemo> createState() => _BorderDemoState();
}

class _BorderDemoState extends State<BorderDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;
  late final WorksheetController _controller;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        // Title row — will be merged across A1:D1
        (0, 0): Cell.text(
          'Border & Merge Demo',
          style: const CellStyle(
            textAlignment: CellTextAlignment.center,
          ),
          richText: const [
            TextSpan(
              text: 'Border & Merge Demo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        // Headers
        (2, 0): Cell.text('Region', style: _headerStyle, richText: const [
          TextSpan(
              text: 'Region', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (2, 1): Cell.text('Q1', style: _headerStyle, richText: const [
          TextSpan(text: 'Q1', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (2, 2): Cell.text('Q2', style: _headerStyle, richText: const [
          TextSpan(text: 'Q2', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (2, 3): Cell.text('Q3', style: _headerStyle, richText: const [
          TextSpan(text: 'Q3', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        // Data — regions will be merged vertically
        (3, 0): Cell.text('North', richText: const [
          TextSpan(text: 'North', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (3, 1): 12500.cell,
        (3, 2): 14200.cell,
        (3, 3): 13800.cell,
        (4, 1): 11800.cell,
        (4, 2): 13500.cell,
        (4, 3): 12900.cell,
        (5, 0): Cell.text('South', richText: const [
          TextSpan(text: 'South', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (5, 1): 9800.cell,
        (5, 2): 10500.cell,
        (5, 3): 11200.cell,
        (6, 1): 10200.cell,
        (6, 2): 11000.cell,
        (6, 3): 10800.cell,
      },
    );

    // Pre-merge the title row and region cells
    _data.mergeCells(const CellRange(0, 0, 0, 3)); // Title A1:D1
    _data.mergeCells(const CellRange(3, 0, 4, 0)); // "North" A4:A5
    _data.mergeCells(const CellRange(5, 0, 6, 0)); // "South" A6:A7

    _editController = EditController();
    _controller = WorksheetController();
    _controller.selectionController.addListener(() => setState(() {}));
  }

  static const _headerStyle = CellStyle(
    backgroundColor: Color(0xFFE0E0E0),
    textAlignment: CellTextAlignment.center,
  );

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  bool get _hasAnySelection =>
      _controller.selectionController.selectedRange != null;

  bool get _hasSelection {
    final range = _controller.selectionController.selectedRange;
    return range != null && range.cellCount >= 2;
  }

  bool get _selectionHasMerge {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return false;
    return _data.mergedCells.regionsInRange(range).isNotEmpty;
  }

  // -- Border application helpers --

  /// Applies a style to every cell in the selection, skipping borders on
  /// non-anchor cells of merged regions (same logic as SetCellStyleAction).
  void _applyStyle(CellStyle style) {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;

    final hasBorders = style.borders != null;
    final noBordersStyle = hasBorders
        ? CellStyle(
            backgroundColor: style.backgroundColor,
            textAlignment: style.textAlignment,
            verticalAlignment: style.verticalAlignment,
            wrapText: style.wrapText,
          )
        : null;

    _data.batchUpdate((batch) {
      for (int row = range.startRow; row <= range.endRow; row++) {
        for (int col = range.startColumn; col <= range.endColumn; col++) {
          final coord = CellCoordinate(row, col);

          var styleToApply = style;
          if (hasBorders) {
            final region = _data.mergedCells.getRegion(coord);
            if (region != null && !region.isAnchor(coord)) {
              styleToApply = noBordersStyle!;
            }
          }

          final current = _data.getStyle(coord);
          final merged =
              current != null ? current.merge(styleToApply) : styleToApply;
          batch.setStyle(coord, merged);
        }
      }
    });
    setState(() {});
  }

  void _allBorders() {
    _applyStyle(
        const CellStyle(borders: CellBorders.all(BorderStyle())));
  }

  void _outerBorder() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;

    _data.batchUpdate((batch) {
      for (int row = range.startRow; row <= range.endRow; row++) {
        for (int col = range.startColumn; col <= range.endColumn; col++) {
          final coord = CellCoordinate(row, col);

          // Skip borders on non-anchor merged cells
          final region = _data.mergedCells.getRegion(coord);
          if (region != null && !region.isAnchor(coord)) continue;

          // For merged anchors, use the merge region's extent to determine
          // which edges touch the selection perimeter.
          final int effectiveEndRow =
              region != null ? region.range.endRow : row;
          final int effectiveEndCol =
              region != null ? region.range.endColumn : col;

          final top = row == range.startRow
              ? const BorderStyle()
              : BorderStyle.none;
          final bottom = effectiveEndRow == range.endRow
              ? const BorderStyle()
              : BorderStyle.none;
          final left = col == range.startColumn
              ? const BorderStyle()
              : BorderStyle.none;
          final right = effectiveEndCol == range.endColumn
              ? const BorderStyle()
              : BorderStyle.none;

          final borders = CellBorders(
              top: top, right: right, bottom: bottom, left: left);
          final style = CellStyle(borders: borders);
          final current = _data.getStyle(coord);
          final merged = current != null ? current.merge(style) : style;
          batch.setStyle(coord, merged);
        }
      }
    });
    setState(() {});
  }

  void _thickBorders() {
    _applyStyle(const CellStyle(
      borders: CellBorders.all(BorderStyle(width: 2.0)),
    ));
  }

  void _noBorder() {
    _applyStyle(const CellStyle(borders: CellBorders.none));
  }

  void _dashedBorders() {
    _applyStyle(const CellStyle(
      borders:
          CellBorders.all(BorderStyle(lineStyle: BorderLineStyle.dashed)),
    ));
  }

  void _doubleBorders() {
    _applyStyle(const CellStyle(
      borders: CellBorders.all(
          BorderStyle(lineStyle: BorderLineStyle.double)),
    ));
  }

  // -- Merge / Clear helpers --

  void _merge() {
    final range = _controller.selectionController.selectedRange;
    if (range == null || range.cellCount < 2) return;
    _data.mergeCells(range);

    // Clear borders on non-anchor cells to avoid rendering artifacts
    final anchor = range.topLeft;
    _data.batchUpdate((batch) {
      for (final coord in range.cells) {
        if (coord == anchor) continue;
        final style = _data.getStyle(coord);
        if (style != null &&
            style.borders != null &&
            !style.borders!.isNone) {
          batch.setStyle(
            coord,
            CellStyle(
              backgroundColor: style.backgroundColor,
              textAlignment: style.textAlignment,
              verticalAlignment: style.verticalAlignment,
              wrapText: style.wrapText,
            ),
          );
        }
      }
    });
    setState(() {});
  }

  void _unmerge() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;
    final anchors = _data.mergedCells
        .regionsInRange(range)
        .map((r) => r.anchor)
        .toList();
    for (final anchor in anchors) {
      _data.unmergeCells(anchor);
    }
    setState(() {});
  }

  void _clearAll() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;
    _data.clearRange(range);
    _data.unmergeCellsInRange(range);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final range = _controller.selectionController.selectedRange;
    final mergeCount = range != null
        ? _data.mergedCells.regionsInRange(range).length
        : 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Border & Merge Demo'),
        actions: [
          // Border group
          _ToolbarButton(
            icon: Icons.border_all,
            label: 'All Borders',
            onPressed: _hasAnySelection ? _allBorders : null,
            tooltip: 'Apply thin borders on all sides of every cell',
          ),
          _ToolbarButton(
            icon: Icons.border_outer,
            label: 'Outer',
            onPressed: _hasAnySelection ? _outerBorder : null,
            tooltip: 'Apply border only on the perimeter of selection',
          ),
          _ToolbarButton(
            icon: Icons.line_weight,
            label: 'Thick',
            onPressed: _hasAnySelection ? _thickBorders : null,
            tooltip: 'Apply thick (2px) borders on all sides',
          ),
          _ToolbarButton(
            icon: Icons.border_clear,
            label: 'No Border',
            onPressed: _hasAnySelection ? _noBorder : null,
            tooltip: 'Remove all borders from selected cells',
          ),
          const VerticalDivider(color: Colors.white38, width: 24),
          // Style group
          _ToolbarButton(
            icon: Icons.line_style,
            label: 'Dashed',
            onPressed: _hasAnySelection ? _dashedBorders : null,
            tooltip: 'Apply dashed borders on all sides',
          ),
          _ToolbarButton(
            icon: Icons.vertical_align_center,
            label: 'Double',
            onPressed: _hasAnySelection ? _doubleBorders : null,
            tooltip: 'Apply double-line borders on all sides',
          ),
          const VerticalDivider(color: Colors.white38, width: 24),
          // Merge group
          _ToolbarButton(
            icon: Icons.table_chart,
            label: 'Merge',
            onPressed: _hasSelection ? _merge : null,
            tooltip: 'Merge selected cells',
          ),
          _ToolbarButton(
            icon: Icons.grid_on,
            label: 'Unmerge',
            onPressed: _selectionHasMerge ? _unmerge : null,
            tooltip: 'Unmerge selected cells',
          ),
          const VerticalDivider(color: Colors.white38, width: 24),
          // Clear
          _ToolbarButton(
            icon: Icons.delete_sweep,
            label: 'Clear All',
            onPressed: _hasAnySelection ? _clearAll : null,
            tooltip: 'Clear values, styles, formats & unmerge',
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                range != null
                    ? 'Selection: ${range.topLeft.toNotation()}'
                        ':${range.bottomRight.toNotation()}'
                        '  (${range.rowCount}x${range.columnCount})'
                        '${mergeCount > 0 ? '  — $mergeCount merge(s) in selection' : ''}'
                    : 'Click a cell to select, drag to select a range',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          editController: _editController,
          controller: _controller,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
      ),
    );
  }
}
