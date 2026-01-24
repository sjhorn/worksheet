import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/geometry/layout_solver.dart';
import '../core/geometry/zoom_transformer.dart';
import '../rendering/tile/tile_manager.dart';

/// A viewport widget for displaying worksheet tiles with 2D scrolling.
///
/// This widget integrates with [TwoDimensionalScrollable] to provide
/// efficient tile-based rendering with proper scroll handling.
class WorksheetViewport extends LeafRenderObjectWidget {
  /// The horizontal scroll position.
  final ViewportOffset horizontalPosition;

  /// The vertical scroll position.
  final ViewportOffset verticalPosition;

  /// The tile manager that provides rendered tiles.
  final TileManager tileManager;

  /// The layout solver for cell positions and dimensions.
  final LayoutSolver layoutSolver;

  /// The current zoom level (1.0 = 100%).
  final double zoom;

  /// A version number that changes when the viewport needs to repaint.
  /// Increment this when tiles are invalidated or layout changes.
  final int layoutVersion;

  /// Creates a worksheet viewport.
  const WorksheetViewport({
    super.key,
    required this.horizontalPosition,
    required this.verticalPosition,
    required this.tileManager,
    required this.layoutSolver,
    required this.zoom,
    this.layoutVersion = 0,
  });

  @override
  RenderWorksheetViewport createRenderObject(BuildContext context) {
    return RenderWorksheetViewport(
      horizontalPosition: horizontalPosition,
      verticalPosition: verticalPosition,
      tileManager: tileManager,
      layoutSolver: layoutSolver,
      zoom: zoom,
      layoutVersion: layoutVersion,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderWorksheetViewport renderObject,
  ) {
    renderObject
      ..horizontalPosition = horizontalPosition
      ..verticalPosition = verticalPosition
      ..tileManager = tileManager
      ..layoutSolver = layoutSolver
      ..zoom = zoom
      ..layoutVersion = layoutVersion;
  }
}

/// Render object that paints worksheet tiles with 2D scrolling support.
///
/// This render object works with [TwoDimensionalScrollable] to provide
/// efficient tile-based rendering. It:
/// - Listens to scroll position changes and repaints
/// - Reports content dimensions to the scroll system
/// - Fetches and paints only visible tiles
class RenderWorksheetViewport extends RenderBox {
  ViewportOffset _horizontalPosition;
  ViewportOffset _verticalPosition;
  TileManager _tileManager;
  LayoutSolver _layoutSolver;
  double _zoom;
  int _layoutVersion;

  /// Creates a render worksheet viewport.
  RenderWorksheetViewport({
    required ViewportOffset horizontalPosition,
    required ViewportOffset verticalPosition,
    required TileManager tileManager,
    required LayoutSolver layoutSolver,
    required double zoom,
    int layoutVersion = 0,
  })  : _horizontalPosition = horizontalPosition,
        _verticalPosition = verticalPosition,
        _tileManager = tileManager,
        _layoutSolver = layoutSolver,
        _zoom = zoom,
        _layoutVersion = layoutVersion;

  /// The horizontal scroll position.
  ViewportOffset get horizontalPosition => _horizontalPosition;
  set horizontalPosition(ViewportOffset value) {
    if (_horizontalPosition == value) return;
    if (attached) _horizontalPosition.removeListener(markNeedsPaint);
    _horizontalPosition = value;
    if (attached) _horizontalPosition.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  /// The vertical scroll position.
  ViewportOffset get verticalPosition => _verticalPosition;
  set verticalPosition(ViewportOffset value) {
    if (_verticalPosition == value) return;
    if (attached) _verticalPosition.removeListener(markNeedsPaint);
    _verticalPosition = value;
    if (attached) _verticalPosition.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  /// The tile manager.
  TileManager get tileManager => _tileManager;
  set tileManager(TileManager value) {
    if (_tileManager == value) return;
    _tileManager = value;
    markNeedsPaint();
  }

  /// The layout solver.
  LayoutSolver get layoutSolver => _layoutSolver;
  set layoutSolver(LayoutSolver value) {
    if (_layoutSolver == value) return;
    _layoutSolver = value;
    markNeedsLayout();
  }

  /// A version number that triggers repaint when changed.
  int get layoutVersion => _layoutVersion;
  set layoutVersion(int value) {
    if (_layoutVersion == value) return;
    _layoutVersion = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  /// The current zoom level.
  double get zoom => _zoom;
  set zoom(double value) {
    if (_zoom == value) return;
    _zoom = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _horizontalPosition.addListener(markNeedsPaint);
    _verticalPosition.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _horizontalPosition.removeListener(markNeedsPaint);
    _verticalPosition.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    // Calculate content dimensions based on layout solver and zoom
    final contentWidth = _layoutSolver.totalWidth * _zoom;
    final contentHeight = _layoutSolver.totalHeight * _zoom;

    // First set viewport dimensions (required before applyContentDimensions)
    _horizontalPosition.applyViewportDimension(size.width);
    _verticalPosition.applyViewportDimension(size.height);

    // Report scroll extent to the scroll positions
    // The extent is contentSize - viewportSize (how far you can scroll)
    _horizontalPosition.applyContentDimensions(
      0.0, // min scroll
      (contentWidth - size.width).clamp(0.0, double.infinity), // max scroll
    );
    _verticalPosition.applyContentDimensions(
      0.0,
      (contentHeight - size.height).clamp(0.0, double.infinity),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    // Get current scroll positions (in screen/zoomed coordinates)
    final scrollX = _horizontalPosition.pixels;
    final scrollY = _verticalPosition.pixels;

    // Convert scroll position to worksheet coordinates
    final worksheetScrollX = scrollX / _zoom;
    final worksheetScrollY = scrollY / _zoom;

    // Calculate visible viewport in worksheet coordinates
    final viewportRect = ui.Rect.fromLTWH(
      worksheetScrollX,
      worksheetScrollY,
      size.width / _zoom,
      size.height / _zoom,
    );

    // Get the zoom bucket for tile selection
    final zoomBucket = ZoomBucket.fromZoom(_zoom);

    // Get tiles for the visible area
    final tiles = _tileManager.getTilesForViewport(
      viewport: viewportRect,
      zoomBucket: zoomBucket,
    );

    // Save canvas state
    canvas.save();

    // Translate to widget position and clip to viewport
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);

    // Apply zoom scale, then translate by scroll position
    canvas.scale(_zoom);
    canvas.translate(-worksheetScrollX, -worksheetScrollY);

    // Paint each tile at its worksheet position
    for (final tile in tiles) {
      // Skip disposed tiles (shouldn't happen with deferred cleanup, but check anyway)
      if (tile.isDisposed) continue;

      final tileBounds = tile.coordinate.pixelBounds(
        tileWidth: _tileManager.config.tileWidth,
        tileHeight: _tileManager.config.tileHeight,
      );

      canvas.save();
      canvas.translate(tileBounds.left, tileBounds.top);
      canvas.drawPicture(tile.picture);
      canvas.restore();
    }

    // Restore canvas state
    canvas.restore();

    // Clean up evicted tiles now that painting is complete
    _tileManager.cleanup();
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
