import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: RichTextDemo()));

class RichTextDemo extends StatefulWidget {
  const RichTextDemo({super.key});

  @override
  State<RichTextDemo> createState() => _RichTextDemoState();
}

class _RichTextDemoState extends State<RichTextDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;
  late final WorksheetController _controller;

  @override
  void initState() {
    super.initState();
    _editController = EditController();
    _controller = WorksheetController();
    _controller.selectionController.addListener(() => setState(() {}));
    _editController.addListener(() => setState(() {}));

    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): Cell.text('Rich Text Demo', richText: const [
          TextSpan(
              text: 'Rich Text Demo',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        (2, 0): Cell.text('Plain text'),
        (3, 0): Cell.text('Bold and normal', richText: const [
          TextSpan(
              text: 'Bold',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' and normal'),
        ]),
        (4, 0): Cell.text('Italic and colored', richText: const [
          TextSpan(
              text: 'Italic',
              style: TextStyle(fontStyle: FontStyle.italic)),
          TextSpan(text: ' and '),
          TextSpan(
              text: 'colored',
              style: TextStyle(color: Color(0xFF2196F3))),
        ]),
        (5, 0): Cell.text('Underline and strike', richText: const [
          TextSpan(
              text: 'Underline',
              style: TextStyle(decoration: TextDecoration.underline)),
          TextSpan(text: ' and '),
          TextSpan(
              text: 'strike',
              style: TextStyle(decoration: TextDecoration.lineThrough)),
        ]),
        (6, 0): Cell.text('Mixed formatting', richText: const [
          TextSpan(
            text: 'Mixed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE91E63),
            ),
          ),
          TextSpan(text: ' '),
          TextSpan(
            text: 'formatting',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
            ),
          ),
        ]),
        (8, 0): Cell.text('Cell underline', richText: const [
          TextSpan(
              text: 'Cell underline',
              style: TextStyle(decoration: TextDecoration.underline)),
        ]),
        (9, 0): Cell.text('Cell strikethrough', richText: const [
          TextSpan(
              text: 'Cell strikethrough',
              style: TextStyle(decoration: TextDecoration.lineThrough)),
        ]),
        (11, 0): Cell.text('Double-tap to edit. Use toolbar or Ctrl+B/I/U.'),
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  bool get _hasSelection =>
      _controller.selectionController.selectedRange != null;

  /// Merges [style] into every cell in the current selection.
  void _setStyle(CellStyle style) {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;
    for (int row = range.startRow; row <= range.endRow; row++) {
      for (int col = range.startColumn; col <= range.endColumn; col++) {
        final coord = CellCoordinate(row, col);
        final current = _data.getStyle(coord);
        _data.setStyle(coord, current?.merge(style) ?? style);
      }
    }
  }

  /// Toggles a rich text style property on all selected cells' spans.
  void _toggleSpanStyle({
    required bool Function(TextStyle?) test,
    required TextStyle Function(TextStyle?) apply,
    required TextStyle Function(TextStyle?) remove,
  }) {
    if (_editController.isEditing) return;
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;

    // Check if ALL spans match
    bool allMatch = true;
    for (int r = range.startRow; allMatch && r <= range.endRow; r++) {
      for (int c = range.startColumn; allMatch && c <= range.endColumn; c++) {
        final coord = CellCoordinate(r, c);
        final spans = _ensureSpans(coord);
        if (spans.isEmpty) { allMatch = false; break; }
        if (!spans.every((s) => test(s.style))) allMatch = false;
      }
    }

    for (int r = range.startRow; r <= range.endRow; r++) {
      for (int c = range.startColumn; c <= range.endColumn; c++) {
        final coord = CellCoordinate(r, c);
        final spans = _ensureSpans(coord);
        if (spans.isEmpty) continue;
        final toggled = spans
            .map((s) => TextSpan(
                  text: s.text,
                  style: allMatch ? remove(s.style) : apply(s.style),
                ))
            .toList();
        _data.setRichText(coord, toggled);
      }
    }
    setState(() {});
  }

  List<TextSpan> _ensureSpans(CellCoordinate coord) {
    final existing = _data.getRichText(coord);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = _data.getCell(coord);
    if (value == null) return [];
    return [TextSpan(text: value.displayValue)];
  }

  /// Clears formatting on the selection.
  ///
  /// When editing: clears rich text formatting on the selected text only.
  /// When not editing: clears cell styles, formats, and rich text spans
  /// from the data layer.
  void _clearFormatting() {
    final range = _controller.selectionController.selectedRange;
    if (range == null) return;

    if (_editController.isEditing) {
      _editController.richTextController?.clearSelectionFormatting();
    } else {
      _data.batchUpdate((batch) {
        batch.clearStyles(range);
        batch.clearFormats(range);
      });
      _data.unmergeCellsInRange(range);
      // Clear rich text spans from the data layer.
      for (int r = range.startRow; r <= range.endRow; r++) {
        for (int c = range.startColumn; c <= range.endColumn; c++) {
          _data.setRichText(CellCoordinate(r, c), null);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editController.isEditing;

    return Scaffold(
      appBar: AppBar(title: const Text('Rich Text Spans')),
      body: Column(
        children: [
          _buildToolbar(isEditing),
          const Divider(height: 1),
          Expanded(
            child: WorksheetTheme(
              data: WorksheetThemeData(
                showHeaders: true,
                defaultColumnWidth: 200,
              ),
              child: Worksheet(
                data: _data,
                rowCount: 100,
                columnCount: 10,
                editController: _editController,
                controller: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // --- Background color buttons ---
          const Text('BG:', style: TextStyle(fontSize: 12)),
          _ColorButton(
            color: const Color(0xFFFFEB3B),
            tooltip: 'Yellow background',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(backgroundColor: Color(0xFFFFEB3B)))
                : null,
          ),
          _ColorButton(
            color: const Color(0xFF81D4FA),
            tooltip: 'Blue background',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(backgroundColor: Color(0xFF81D4FA)))
                : null,
          ),
          _ColorButton(
            color: const Color(0xFFA5D6A7),
            tooltip: 'Green background',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(backgroundColor: Color(0xFFA5D6A7)))
                : null,
          ),
          _ColorButton(
            color: const Color(0xFFEF9A9A),
            tooltip: 'Red background',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(backgroundColor: Color(0xFFEF9A9A)))
                : null,
          ),
          const VerticalDivider(width: 16),
          // --- Alignment ---
          _ToolbarIconButton(
            icon: Icons.format_align_left,
            tooltip: 'Align left',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(textAlignment: CellTextAlignment.left))
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.format_align_center,
            tooltip: 'Align center',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(textAlignment: CellTextAlignment.center))
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.format_align_right,
            tooltip: 'Align right',
            onPressed: _hasSelection
                ? () => _setStyle(
                    const CellStyle(textAlignment: CellTextAlignment.right))
                : null,
          ),
          const VerticalDivider(width: 16),
          // --- Bold / Italic / Underline / Strikethrough ---
          _ToolbarIconButton(
            icon: Icons.format_bold,
            tooltip: 'Toggle bold',
            onPressed: _hasSelection
                ? () {
                    if (isEditing) {
                      _editController.toggleBold();
                    } else {
                      _toggleSpanStyle(
                        test: (s) => s?.fontWeight == FontWeight.bold,
                        apply: (s) => (s ?? const TextStyle())
                            .copyWith(fontWeight: FontWeight.bold),
                        remove: (s) => (s ?? const TextStyle())
                            .copyWith(fontWeight: FontWeight.normal),
                      );
                    }
                  }
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.format_italic,
            tooltip: 'Toggle italic',
            onPressed: _hasSelection
                ? () {
                    if (isEditing) {
                      _editController.toggleItalic();
                    } else {
                      _toggleSpanStyle(
                        test: (s) => s?.fontStyle == FontStyle.italic,
                        apply: (s) => (s ?? const TextStyle())
                            .copyWith(fontStyle: FontStyle.italic),
                        remove: (s) => (s ?? const TextStyle())
                            .copyWith(fontStyle: FontStyle.normal),
                      );
                    }
                  }
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.format_underline,
            tooltip: 'Toggle underline',
            onPressed: _hasSelection
                ? () {
                    if (isEditing) {
                      _editController.toggleUnderline();
                    } else {
                      _toggleSpanStyle(
                        test: (s) =>
                            s?.decoration == TextDecoration.underline,
                        apply: (s) => (s ?? const TextStyle())
                            .copyWith(decoration: TextDecoration.underline),
                        remove: (s) => (s ?? const TextStyle())
                            .copyWith(decoration: TextDecoration.none),
                      );
                    }
                  }
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.format_strikethrough,
            tooltip: 'Toggle strikethrough',
            onPressed: _hasSelection
                ? () {
                    if (isEditing) {
                      _editController.toggleStrikethrough();
                    } else {
                      _toggleSpanStyle(
                        test: (s) =>
                            s?.decoration == TextDecoration.lineThrough,
                        apply: (s) => (s ?? const TextStyle()).copyWith(
                            decoration: TextDecoration.lineThrough),
                        remove: (s) => (s ?? const TextStyle())
                            .copyWith(decoration: TextDecoration.none),
                      );
                    }
                  }
                : null,
          ),
          const VerticalDivider(width: 16),
          // --- Clear formatting ---
          _ToolbarIconButton(
            icon: Icons.format_color_reset,
            tooltip: 'Clear formatting (styles + rich text)',
            onPressed: _hasSelection ? _clearFormatting : null,
          ),
          if (isEditing)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Editing',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ColorButton({
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: onPressed != null ? color : color.withAlpha(80),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
