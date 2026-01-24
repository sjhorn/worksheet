import 'package:flutter/foundation.dart';

import '../../core/models/cell_coordinate.dart';
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

  /// Creates a selection layer.
  SelectionLayer({
    required this.selectionController,
    required this.renderer,
    this.onNeedsPaint,
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
  }

  @override
  void dispose() {
    selectionController.removeListener(_onSelectionChanged);
  }
}
