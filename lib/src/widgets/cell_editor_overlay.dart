import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_format.dart';
import '../core/models/cell_style.dart';
import '../core/models/cell_value.dart';
import '../interaction/controllers/edit_controller.dart';
import '../interaction/controllers/rich_text_editing_controller.dart';
import 'worksheet_theme.dart';

/// Overlay widget that displays an EditableText over the cell being edited.
///
/// Positions itself at [cellBounds] and handles commit/cancel via
/// keyboard (Enter/Escape) and callbacks.
class CellEditorOverlay extends StatefulWidget {
  /// The edit controller managing edit state.
  final EditController editController;

  /// The bounds of the cell being edited in screen coordinates.
  final Rect cellBounds;

  /// Called when the edit is committed.
  final void Function(
    CellCoordinate cell,
    CellValue? value, {
    CellFormat? detectedFormat,
    List<TextSpan>? richText,
  }) onCommit;

  /// Called when the edit is cancelled.
  final VoidCallback onCancel;

  /// Called when the edit is committed with a navigation direction.
  ///
  /// Receives the cell, committed value, row delta, and column delta.
  /// Used for Enter (down), Shift+Enter (up), Tab (right), Shift+Tab (left).
  /// When null, Enter/Tab fall back to plain commit via [onCommit].
  final void Function(
    CellCoordinate cell,
    CellValue? value,
    int rowDelta,
    int columnDelta, {
    CellFormat? detectedFormat,
    List<TextSpan>? richText,
  })?
  onCommitAndNavigate;

  /// The current zoom level, used to scale font size, padding, and cursor
  /// so the editor text aligns with the tile-rendered cell text.
  final double zoom;

  /// The font size used by the tile painter (in worksheet coordinates).
  final double fontSize;

  /// The font family used by the tile painter.
  final String fontFamily;

  /// The font weight.
  final FontWeight fontWeight;

  /// The font style (normal or italic).
  final FontStyle fontStyle;

  /// The text color.
  final Color textColor;

  /// Horizontal text alignment.
  final TextAlign textAlign;

  /// The cell padding used by the tile painter (in worksheet coordinates).
  final double cellPadding;

  /// Rich text spans for the cell being edited.
  ///
  /// When non-null, the editor displays styled text and supports
  /// inline formatting via Ctrl+B/I/U/Shift+S.
  final List<TextSpan>? richText;

  /// Vertical text alignment matching the tile painter's centering.
  ///
  /// Defaults to [CellVerticalAlignment.middle]. The overlay positions
  /// the EditableText at the same vertical offset the tile painter uses.
  final CellVerticalAlignment verticalAlignment;

  /// Whether the cell wraps text across multiple lines.
  ///
  /// When true, the editor allows multi-line input (Alt+Enter inserts a
  /// newline) and grows vertically. When false (default), the editor is
  /// single-line and Enter commits.
  final bool wrapText;

  /// Expanded bounds in screen coordinates (zoomed), used when text
  /// overflows the original cell and the editor expands into adjacent
  /// columns (non-wrap) or rows (wrap).
  ///
  /// When non-null, the editor's text area width is computed from these
  /// bounds instead of [cellBounds].
  final Rect? expandedBounds;

  /// Focus node to restore when editing completes. If null, attempts to
  /// find the parent focus node automatically.
  final FocusNode? restoreFocusTo;

  /// Width of the content area in screen coordinates (viewport width minus
  /// row header). When non-null and the cell is non-wrap, the editor width
  /// is clamped so it doesn't extend past the viewport right edge.
  final double? contentAreaWidth;

  /// Minimum width for the editor.
  static const double minWidth = 60.0;

  /// Creates a cell editor overlay.
  const CellEditorOverlay({
    super.key,
    required this.editController,
    required this.cellBounds,
    required this.onCommit,
    required this.onCancel,
    this.onCommitAndNavigate,
    this.zoom = 1.0,
    this.fontSize = 14.0,
    this.fontFamily = CellStyle.defaultFontFamily,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.textColor = const Color(0xFF000000),
    this.textAlign = TextAlign.left,
    this.cellPadding = 4.0,
    this.richText,
    this.verticalAlignment = CellVerticalAlignment.middle,
    this.wrapText = false,
    this.expandedBounds,
    this.restoreFocusTo,
    this.contentAreaWidth,
  });

  @override
  State<CellEditorOverlay> createState() => _CellEditorOverlayState();
}

class _CellEditorOverlayState extends State<CellEditorOverlay> {
  late RichTextEditingController _textController;
  late FocusNode _focusNode;
  final GlobalKey<EditableTextState> _editableKey = GlobalKey();

  /// When true, a controller listener guards against select-all that the
  /// platform may apply on focus gain, reversing it to cursor-at-end.
  bool _guardSelectAll = false;

  /// For wrapText cells, the initial vertical offset computed from the
  /// content height at edit start. Fixed for the session so the editor
  /// doesn't jump as the user adds/removes lines.
  double? _initialWrapVerticalOffset;

  @override
  void initState() {
    super.initState();

    _textController = RichTextEditingController(
      text: widget.editController.currentText,
    );

    // Initialize from rich text spans if available,
    // but NOT for type-to-edit (which replaces the old value).
    if (widget.richText != null &&
        widget.richText!.isNotEmpty &&
        widget.editController.trigger != EditTrigger.typing) {
      _textController.initFromSpans(widget.richText!);
    }
    // For wrapText with non-top alignment, compute the initial vertical
    // offset from the wrapped content height so the editor starts at the
    // same position as the tile-rendered text.
    if (widget.wrapText &&
        widget.verticalAlignment != CellVerticalAlignment.top) {
      _initialWrapVerticalOffset = _computeInitialWrapVerticalOffset();
    }

    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    // Listen for changes from edit controller
    widget.editController.addListener(_onEditControllerChanged);

    // Handle initial selection based on trigger
    _focusNode.addListener(_onFocusChanged);

    // For type-to-edit, the platform text input connection may select all
    // text when focus is gained. Guard against this by listening for
    // select-all and reversing it to cursor-at-end.
    if (widget.editController.trigger == EditTrigger.typing) {
      _guardSelectAll = true;
      _textController.addListener(_onSelectionGuard);
    }

    // Request focus after the EditableText is built and attached to the tree.
    // This ensures the text input connection is established on mobile,
    // which is required to show the software keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.editController.removeListener(_onEditControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onSelectionGuard);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Detects if the platform applied a select-all after focus gain and
  /// reverses it to a collapsed cursor at the end. Removes itself after
  /// the first correction or when the selection is already correct.
  void _onSelectionGuard() {
    if (!_guardSelectAll) return;
    final sel = _textController.selection;
    final text = _textController.text;
    if (text.isEmpty) return;

    if (!sel.isCollapsed &&
        sel.baseOffset == 0 &&
        sel.extentOffset == text.length) {
      // Select-all detected — reverse it.
      _guardSelectAll = false;
      _textController.removeListener(_onSelectionGuard);
      _textController.selection = TextSelection.collapsed(offset: text.length);
    } else if (sel.isCollapsed && sel.isValid) {
      // Selection is already fine — stop guarding.
      _guardSelectAll = false;
      _textController.removeListener(_onSelectionGuard);
    }
  }

  void _onEditControllerChanged() {
    if (!widget.editController.isEditing) {
      // Restore focus to the Worksheet's keyboard focus node.
      // Use post-frame callback to ensure the overlay is fully disposed
      // and doesn't interfere with focus (especially on web where timing
      // of tap events can compete with focus restoration).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.restoreFocusTo != null) {
          widget.restoreFocusTo!.requestFocus();
        }
      });
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
      final trigger = widget.editController.trigger;
      if (trigger == EditTrigger.typing || trigger == EditTrigger.doubleTap) {
        // Typing or double-tap: cursor at end
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      } else {
        // F2, programmatic: select all text
        _textController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _textController.text.length,
        );
      }
    }
  }

  /// Measures the wrapped content height and returns the vertical offset
  /// matching the tile painter's vertical alignment.
  double _computeInitialWrapVerticalOffset() {
    final zoom = widget.zoom;
    final unzoomedWidth = widget.cellBounds.width / zoom;
    final unzoomedHeight = widget.cellBounds.height / zoom;
    final effectiveWidth = unzoomedWidth < CellEditorOverlay.minWidth
        ? CellEditorOverlay.minWidth
        : unzoomedWidth;
    final textAreaWidth = effectiveWidth - 2 * widget.cellPadding;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      fontWeight: widget.fontWeight,
      fontStyle: widget.fontStyle,
      color: widget.textColor,
      package: WorksheetThemeData.resolveFontPackage(widget.fontFamily),
    );

    final contentMeasurer = TextPainter(
      text: TextSpan(text: _textController.text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textAreaWidth > 0 ? textAreaWidth : 0);
    final contentHeight = contentMeasurer.height;
    contentMeasurer.dispose();

    switch (widget.verticalAlignment) {
      case CellVerticalAlignment.middle:
        return ((unzoomedHeight - contentHeight) / 2).clamp(
          0.0,
          double.infinity,
        );
      case CellVerticalAlignment.bottom:
        return (unzoomedHeight - widget.cellPadding - contentHeight).clamp(
          0.0,
          double.infinity,
        );
      case CellVerticalAlignment.top:
        return widget.cellPadding;
    }
  }

  void _onTextChanged(String text) {
    widget.editController.updateText(text);
  }

  List<TextSpan>? _extractRichText() {
    if (!_textController.hasRichStyles) return null;
    return _textController.toSpans();
  }

  void _commit() {
    final spans = _extractRichText();
    widget.editController.commitEdit(
      onCommit: (cell, value, {CellFormat? detectedFormat}) {
        widget.onCommit(
          cell,
          value,
          detectedFormat: detectedFormat,
          richText: spans,
        );
      },
    );
  }

  void _commitAndNavigate({required int rowDelta, required int columnDelta}) {
    if (widget.onCommitAndNavigate != null) {
      final cell = widget.editController.editingCell;
      if (cell == null) return;
      final spans = _extractRichText();
      widget.editController.commitEdit(
        onCommit: (commitCell, value, {CellFormat? detectedFormat}) {
          widget.onCommitAndNavigate!(
            commitCell, value, rowDelta, columnDelta,
            detectedFormat: detectedFormat,
            richText: spans,
          );
        },
      );
    } else {
      // Fall back to plain commit when no navigate callback is provided
      _commit();
    }
  }

  void _cancel() {
    widget.editController.cancelEdit();
    widget.onCancel();
  }

  void _insertNewline() {
    final sel = _textController.selection;
    final text = _textController.text;
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final newText = '$before\n$after';
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + 1),
    );
    widget.editController.updateText(newText);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Rich text formatting shortcuts (Ctrl/Cmd + key)
    final isModifier = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isModifier) {
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        _textController.toggleBold();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyI) {
        _textController.toggleItalic();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyU) {
        _textController.toggleUnderline();
        return KeyEventResult.handled;
      }
      if (HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _textController.toggleStrikethrough();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }

    // Alt+Enter inserts a newline when wrapText is enabled
    if (widget.wrapText &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        HardwareKeyboard.instance.isAltPressed) {
      _insertNewline();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      _commitAndNavigate(rowDelta: shift ? -1 : 1, columnDelta: 0);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      _commitAndNavigate(rowDelta: 0, columnDelta: shift ? -1 : 1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _commitAndNavigate(rowDelta: 1, columnDelta: 0);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _commitAndNavigate(rowDelta: -1, columnDelta: 0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editController.isEditing) {
      return const SizedBox.shrink();
    }

    final zoom = widget.zoom;

    // All sizes at BASE (unzoomed) dimensions, matching the tile painter which
    // renders at base font size then GPU-scales with canvas.scale(zoom).
    // We wrap the widget in Transform.scale to achieve the same effect.
    final unzoomedWidth = widget.cellBounds.width / zoom;
    final unzoomedHeight = widget.cellBounds.height / zoom;

    final effectiveWidth = unzoomedWidth < CellEditorOverlay.minWidth
        ? CellEditorOverlay.minWidth
        : unzoomedWidth;

    // Style matches the tile painter's TextStyle exactly — no theme merging.
    // Using EditableText (not TextField) avoids Material theme bleed-through
    // of height, letterSpacing, etc. from bodyLarge.
    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      fontWeight: widget.fontWeight,
      fontStyle: widget.fontStyle,
      color: widget.textColor,
      package: WorksheetThemeData.resolveFontPackage(widget.fontFamily),
    );

    // Measure text height at base size to match tile painter's vertical
    // centering exactly: dy = bounds.top + (bounds.height - textPainter.height) / 2
    final measurer = TextPainter(
      text: TextSpan(text: 'Xg', style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final textHeight = measurer.height;
    // Cursor height uses ascent + descent (glyph bounds) rather than the
    // full line height which includes leading and looks too tall.
    final metrics = measurer.computeLineMetrics();
    final cursorHeight = metrics.isNotEmpty
        ? metrics.first.ascent + metrics.first.descent
        : textHeight;
    measurer.dispose();

    // Compute text offsets matching the tile painter's _calculateTextOffset.
    // Vertical alignment: top/middle/bottom, matching CellVerticalAlignment.
    final double verticalOffset;
    if (widget.wrapText) {
      // Use the initial offset computed in initState (based on the wrapped
      // content height at edit start) so it doesn't jump during editing.
      verticalOffset = _initialWrapVerticalOffset ?? widget.cellPadding;
    } else {
      switch (widget.verticalAlignment) {
        case CellVerticalAlignment.top:
          verticalOffset = widget.cellPadding;
          break;
        case CellVerticalAlignment.middle:
          verticalOffset = ((unzoomedHeight - textHeight) / 2).clamp(
            0.0,
            double.infinity,
          );
          break;
        case CellVerticalAlignment.bottom:
          verticalOffset = (unzoomedHeight - widget.cellPadding - textHeight)
              .clamp(0.0, double.infinity);
          break;
      }
    }

    // Horizontal offset: tile painter uses cellPadding on both sides for
    // text layout width, but positions text per alignment. The EditableText's
    // textAlign property handles alignment within the text area.
    // Match tile painter: availableWidth = bounds.width - 2 * cellPadding.
    final double leftPad;
    switch (widget.textAlign) {
      case TextAlign.right:
      case TextAlign.end:
        // Right-aligned: position at left edge + cellPadding so the text
        // area matches the tile painter's availableWidth. textAlign handles
        // right-alignment within that area.
        leftPad = widget.cellPadding;
        break;
      case TextAlign.center:
        // Center: same — cellPadding on both sides.
        leftPad = widget.cellPadding;
        break;
      default:
        leftPad = widget.cellPadding;
        break;
    }

    // Text area width = cell width - 2 * cellPadding, matching tile painter.
    // When expandedBounds is present (non-wrap overflow), use the expanded
    // width so the editor text area fills the wider area.
    double textAreaWidth;
    if (widget.expandedBounds != null && !widget.wrapText) {
      final expandedUnzoomedWidth = widget.expandedBounds!.width / zoom;
      final expandedEffective = expandedUnzoomedWidth < CellEditorOverlay.minWidth
          ? CellEditorOverlay.minWidth
          : expandedUnzoomedWidth;
      textAreaWidth = expandedEffective - 2 * widget.cellPadding;
    } else {
      textAreaWidth = effectiveWidth - 2 * widget.cellPadding;
    }

    // Cap non-wrap editor width at viewport right edge.
    if (!widget.wrapText && widget.contentAreaWidth != null) {
      final editorLeft = widget.cellBounds.left + leftPad * zoom;
      final maxRenderedWidth = widget.contentAreaWidth! - editorLeft;
      if (maxRenderedWidth > 0) {
        final maxTextAreaWidth = maxRenderedWidth / zoom;
        if (textAreaWidth > maxTextAreaWidth) {
          textAreaWidth = maxTextAreaWidth;
        }
      }
    }

    return Positioned(
      left: widget.cellBounds.left + leftPad * zoom,
      top: widget.cellBounds.top + verticalOffset * zoom,
      child: Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        child: FocusScope(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: textAreaWidth,
              maxWidth: textAreaWidth,
            ),
            child: TextSelectionGestureDetectorBuilder(
              delegate: _EditorSelectionDelegate(_editableKey),
            ).buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: EditableText(
                key: _editableKey,
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                style: textStyle,
                maxLines: widget.wrapText ? null : 1,
                textAlign: widget.textAlign,
                cursorHeight: cursorHeight,
                cursorColor: widget.textColor,
                backgroundCursorColor: const Color(0xFF808080),
                onChanged: _onTextChanged,
                rendererIgnoresPointer: true,
                selectionColor: widget.textColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorSelectionDelegate
    extends TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey;

  _EditorSelectionDelegate(this.editableTextKey);

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => true;
}
