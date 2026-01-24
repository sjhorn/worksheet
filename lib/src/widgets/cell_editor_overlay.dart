import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_value.dart';
import '../interaction/controllers/edit_controller.dart';

/// Overlay widget that displays a TextField over the cell being edited.
///
/// Positions itself at [cellBounds] and handles commit/cancel via
/// keyboard (Enter/Escape) and callbacks.
class CellEditorOverlay extends StatefulWidget {
  /// The edit controller managing edit state.
  final EditController editController;

  /// The bounds of the cell being edited in screen coordinates.
  final Rect cellBounds;

  /// Called when the edit is committed.
  final void Function(CellCoordinate cell, CellValue? value) onCommit;

  /// Called when the edit is cancelled.
  final VoidCallback onCancel;

  /// Minimum width for the editor.
  static const double minWidth = 60.0;

  /// Creates a cell editor overlay.
  const CellEditorOverlay({
    super.key,
    required this.editController,
    required this.cellBounds,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  State<CellEditorOverlay> createState() => _CellEditorOverlayState();
}

class _CellEditorOverlayState extends State<CellEditorOverlay> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.editController.currentText,
    );
    _focusNode = FocusNode();

    // Listen for changes from edit controller
    widget.editController.addListener(_onEditControllerChanged);

    // Select all text when first focused
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.editController.removeListener(_onEditControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEditControllerChanged() {
    if (!widget.editController.isEditing) {
      setState(() {});
      return;
    }

    // Sync text if it differs (e.g., from external updates)
    if (_textController.text != widget.editController.currentText) {
      _textController.text = widget.editController.currentText;
    }
    setState(() {});
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _textController.text.isNotEmpty) {
      // Select all text when focused
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    }
  }

  void _onTextChanged(String text) {
    widget.editController.updateText(text);
  }

  void _commit() {
    widget.editController.commitEdit(onCommit: widget.onCommit);
  }

  void _cancel() {
    widget.editController.cancelEdit();
    widget.onCancel();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editController.isEditing) {
      return const SizedBox.shrink();
    }

    final width = widget.cellBounds.width < CellEditorOverlay.minWidth
        ? CellEditorOverlay.minWidth
        : widget.cellBounds.width;

    return Positioned(
      left: widget.cellBounds.left,
      top: widget.cellBounds.top,
      child: SizedBox(
        width: width,
        height: widget.cellBounds.height,
        child: Focus(
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _onTextChanged,
            onSubmitted: (_) => _commit(),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
