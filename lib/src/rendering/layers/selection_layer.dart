import 'dart:ui';

import '../../core/models/cell_range.dart';
import '../../interaction/controllers/selection_controller.dart';
import '../painters/selection_renderer.dart';
import 'render_layer.dart';

/// Layer for rendering selection overlays.
///
/// Listens to a [SelectionController] and paints the current selection
/// using a [SelectionRenderer].
class SelectionLayer extends RenderLayer {
  /// The selection controller to listen to.
  final SelectionController selectionController;

  /// The renderer for painting selections.
  final SelectionRenderer renderer;

  /// Callback to trigger repaint when selection changes.
  final VoidCallback? onNeedsPaint;

  /// Whether to show the fill handle at the bottom-right of the selection.
  final bool showFillHandle;

  /// The fill preview range to display during a fill drag.
  CellRange? fillPreviewRange;

  /// Creates a selection layer.
  SelectionLayer({
    required this.selectionController,
    required this.renderer,
    this.onNeedsPaint,
    this.showFillHandle = true,
    super.enabled,
  }) {
    selectionController.addListener(_onSelectionChanged);
  }

  @override
  int get order => 100; // Above content tiles, below headers

  void _onSelectionChanged() {
    markNeedsPaint();
  }

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled) return;

    final range = selectionController.selectedRange;
    if (range == null) return;

    final focus = selectionController.focus;

    if (selectionController.mode == SelectionMode.single && focus != null) {
      // Single cell selection
      renderer.paintSingleCell(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        cell: focus,
      );
    } else {
      // Range selection
      renderer.paintSelection(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        range: range,
        focus: focus,
      );
    }

    // Paint fill handle at bottom-right of selection
    if (showFillHandle) {
      renderer.paintFillHandle(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        range: range,
      );
    }

    // Paint fill preview range during drag
    if (fillPreviewRange != null) {
      renderer.paintFillPreview(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        range: fillPreviewRange!,
      );
    }
  }

  @override
  void dispose() {
    selectionController.removeListener(_onSelectionChanged);
  }
}
