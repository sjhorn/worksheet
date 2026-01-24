import 'dart:ui';

/// The painting context for render layers.
///
/// Provides the necessary information for a layer to paint itself,
/// including the canvas, viewport information, and zoom level.
class LayerPaintContext {
  /// The canvas to paint on.
  final Canvas canvas;

  /// The size of the viewport.
  final Size viewportSize;

  /// The scroll offset in worksheet coordinates.
  final Offset scrollOffset;

  /// The current zoom level.
  final double zoom;

  const LayerPaintContext({
    required this.canvas,
    required this.viewportSize,
    required this.scrollOffset,
    required this.zoom,
  });
}

/// Abstract base class for render layers.
///
/// Layers are painted in order from back to front:
/// 1. Content layer (tiles)
/// 2. Selection layer
/// 3. Header layer (row/column headers)
/// 4. Frozen layer (frozen panes)
///
/// Each layer can be enabled/disabled independently.
abstract class RenderLayer {
  /// Whether this layer is enabled (should be painted).
  bool enabled;

  /// The paint order of this layer (lower numbers paint first/below).
  int get order;

  /// Creates a render layer.
  RenderLayer({this.enabled = true});

  /// Paints this layer.
  ///
  /// [context] provides the canvas and viewport information.
  void paint(LayerPaintContext context);

  /// Marks this layer as needing repaint.
  ///
  /// Subclasses may override to trigger repaint notifications.
  void markNeedsPaint() {}

  /// Releases any resources held by this layer.
  ///
  /// Called when the layer is no longer needed.
  void dispose() {}
}
