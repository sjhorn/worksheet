import 'dart:ui';

import '../../core/geometry/span_list.dart';
import '../../interaction/controllers/selection_controller.dart';
import '../painters/header_renderer.dart';
import 'render_layer.dart';

/// Layer for rendering row and column headers.
///
/// Headers are painted in a fixed position relative to the viewport,
/// with only the relevant axis scrolling (row headers scroll vertically,
/// column headers scroll horizontally).
class HeaderLayer extends RenderLayer {
  /// The renderer for painting headers.
  final HeaderRenderer renderer;

  /// The selection controller for highlighting headers.
  final SelectionController? selectionController;

  /// Function to get visible column range based on viewport.
  final SpanRange Function(double scrollX, double viewportWidth, double zoom)
      getVisibleColumns;

  /// Function to get visible row range based on viewport.
  final SpanRange Function(double scrollY, double viewportHeight, double zoom)
      getVisibleRows;

  /// Callback to trigger repaint when needed.
  final VoidCallback? onNeedsPaint;

  /// Creates a header layer.
  HeaderLayer({
    required this.renderer,
    required this.getVisibleColumns,
    required this.getVisibleRows,
    this.selectionController,
    this.onNeedsPaint,
    super.enabled,
  }) {
    selectionController?.addListener(_onSelectionChanged);
  }

  @override
  int get order => 200; // Above selection layer

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

    final selectedRange = selectionController?.selectedRange;
    final zoom = context.zoom;

    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = renderer.rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = renderer.columnHeaderHeight * zoom;

    // Calculate visible ranges
    final visibleColumns = getVisibleColumns(
      context.scrollOffset.dx,
      context.viewportSize.width - scaledRowHeaderWidth,
      zoom,
    );

    final visibleRows = getVisibleRows(
      context.scrollOffset.dy,
      context.viewportSize.height - scaledColumnHeaderHeight,
      zoom,
    );

    // Save canvas state before painting headers
    context.canvas.save();

    // Paint column headers (at top, scrolls horizontally)
    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTWH(
        scaledRowHeaderWidth,
        0,
        context.viewportSize.width - scaledRowHeaderWidth,
        scaledColumnHeaderHeight,
      ),
    );
    renderer.paintColumnHeaders(
      canvas: context.canvas,
      viewportOffset: context.scrollOffset,
      zoom: zoom,
      visibleColumns: visibleColumns,
      selectedRange: selectedRange,
    );
    context.canvas.restore();

    // Paint row headers (at left, scrolls vertically)
    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTWH(
        0,
        scaledColumnHeaderHeight,
        scaledRowHeaderWidth,
        context.viewportSize.height - scaledColumnHeaderHeight,
      ),
    );
    renderer.paintRowHeaders(
      canvas: context.canvas,
      viewportOffset: context.scrollOffset,
      zoom: zoom,
      visibleRows: visibleRows,
      selectedRange: selectedRange,
    );
    context.canvas.restore();

    // Paint corner cell (intersection of row and column headers)
    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        scaledRowHeaderWidth,
        scaledColumnHeaderHeight,
      ),
    );
    renderer.paintCornerCell(context.canvas, zoom: zoom);
    context.canvas.restore();

    // Draw header border lines (unclipped so they span full width/height)
    renderer.paintHeaderBorders(
      canvas: context.canvas,
      viewportSize: context.viewportSize,
      zoom: zoom,
    );

    // Restore canvas state
    context.canvas.restore();
  }

  @override
  void dispose() {
    selectionController?.removeListener(_onSelectionChanged);
  }
}
