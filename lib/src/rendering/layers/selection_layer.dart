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
  bool showFillHandle;

  /// Whether to show selection handles (touch drag circles) at the
  /// top-left and bottom-right corners of the selection.
  bool showSelectionHandles;

  /// The fill preview range to display during a fill drag.
  CellRange? fillPreviewRange;

  /// The move preview range to display during a move drag.
  CellRange? movePreviewRange;

  /// Creates a selection layer.
  SelectionLayer({
    required this.selectionController,
    required this.renderer,
    this.onNeedsPaint,
    this.showFillHandle = true,
    this.showSelectionHandles = false,
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

    final anchor = selectionController.anchor;

    if (range.cellCount == 1 && anchor != null) {
      // Single cell selection
      renderer.paintSingleCell(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        cell: anchor,
      );
    } else {
      // Range selection — anchor cell stays transparent
      renderer.paintSelection(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        range: range,
        anchorCell: anchor,
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

    // Paint selection handles (touch drag circles) at corners
    if (showSelectionHandles) {
      renderer.paintSelectionHandles(
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

    // Paint move preview range during drag
    if (movePreviewRange != null) {
      renderer.paintMovePreview(
        canvas: context.canvas,
        viewportOffset: context.scrollOffset,
        zoom: context.zoom,
        range: movePreviewRange!,
      );
    }
  }

  @override
  void dispose() {
    selectionController.removeListener(_onSelectionChanged);
  }
}
