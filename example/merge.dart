import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: MergeDemo()));

class MergeDemo extends StatefulWidget {
  const MergeDemo({super.key});

  @override
  State<MergeDemo> createState() => _MergeDemoState();
}

class _MergeDemoState extends State<MergeDemo> {
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
          'Quarterly Sales Report',
          style: const CellStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            textAlignment: CellTextAlignment.center,
          ),
        ),
        // Headers
        (2, 0): Cell.text('Region', style: _headerStyle),
        (2, 1): Cell.text('Q1', style: _headerStyle),
        (2, 2): Cell.text('Q2', style: _headerStyle),
        (2, 3): Cell.text('Q3', style: _headerStyle),
        // Data — regions will be merged vertically
        (3, 0): Cell.text('North',
            style: const CellStyle(fontWeight: FontWeight.bold)),
        (3, 1): 12500.cell,
        (3, 2): 14200.cell,
        (3, 3): 13800.cell,
        (4, 1): 11800.cell,
        (4, 2): 13500.cell,
        (4, 3): 12900.cell,
        (5, 0): Cell.text('South',
            style: const CellStyle(fontWeight: FontWeight.bold)),
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
    fontWeight: FontWeight.bold,
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

  void _merge() {
    final range = _controller.selectionController.selectedRange;
    if (range == null || range.cellCount < 2) return;
    _data.mergeCells(range);
    setState(() {});
  }

  void _mergeHorizontally() {
    final range = _controller.selectionController.selectedRange;
    if (range == null || range.columnCount < 2) return;
    for (int row = range.startRow; row <= range.endRow; row++) {
      _data.mergeCells(CellRange(row, range.startColumn, row, range.endColumn));
    }
    setState(() {});
  }

  void _mergeVertically() {
    final range = _controller.selectionController.selectedRange;
    if (range == null || range.rowCount < 2) return;
    for (int col = range.startColumn; col <= range.endColumn; col++) {
      _data.mergeCells(CellRange(range.startRow, col, range.endRow, col));
    }
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

  void _clearValues() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;
    _data.batchUpdate((batch) => batch.clearValues(range));
    setState(() {});
  }

  void _clearFormats() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;
    _data.batchUpdate((batch) {
      batch.clearStyles(range);
      batch.clearFormats(range);
    });
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
        title: const Text('Cell Merging Demo'),
        actions: [
          _ToolbarButton(
            icon: Icons.table_chart,
            label: 'Merge All',
            onPressed: _hasSelection ? _merge : null,
            tooltip: 'Merge selected cells into one',
          ),
          _ToolbarButton(
            icon: Icons.table_rows,
            label: 'Merge Rows',
            onPressed: _hasSelection ? _mergeHorizontally : null,
            tooltip: 'Merge each row separately',
          ),
          _ToolbarButton(
            icon: Icons.view_column,
            label: 'Merge Cols',
            onPressed: _hasSelection ? _mergeVertically : null,
            tooltip: 'Merge each column separately',
          ),
          _ToolbarButton(
            icon: Icons.grid_on,
            label: 'Unmerge',
            onPressed: _selectionHasMerge ? _unmerge : null,
            tooltip: 'Unmerge selected cells',
          ),
          const VerticalDivider(color: Colors.white38, width: 24),
          _ToolbarButton(
            icon: Icons.delete_sweep,
            label: 'Clear All',
            onPressed: _hasAnySelection ? _clearAll : null,
            tooltip: 'Clear values, styles, formats & unmerge',
          ),
          _ToolbarButton(
            icon: Icons.text_fields_outlined,
            label: 'Clear Values',
            onPressed: _hasAnySelection ? _clearValues : null,
            tooltip: 'Clear values only (keeps formatting & merges)',
          ),
          _ToolbarButton(
            icon: Icons.format_color_reset,
            label: 'Clear Formats',
            onPressed: _hasAnySelection ? _clearFormats : null,
            tooltip: 'Clear styles, formats & unmerge (keeps values)',
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
