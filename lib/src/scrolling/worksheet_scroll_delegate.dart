import 'package:flutter/widgets.dart';

import '../core/geometry/layout_solver.dart';
import '../core/geometry/zoom_transformer.dart';
import 'scroll_anchor.dart';
import 'scroll_physics.dart';
import 'viewport_delegate.dart';

/// Delegate that manages scroll controllers for a worksheet.
///
/// This delegate creates and manages horizontal and vertical scroll controllers,
/// automatically updating their extents when zoom or viewport size changes.
/// It also provides methods for scroll position persistence and zoom anchoring.
class WorksheetScrollDelegate {
  /// The layout solver for content dimensions.
  final LayoutSolver layoutSolver;

  /// The zoom transformer for coordinate conversion.
  final ZoomTransformer zoomTransformer;

  /// The viewport delegate.
  late final ViewportDelegate viewportDelegate;

  /// The horizontal scroll controller.
  late final ScrollController horizontalController;

  /// The vertical scroll controller.
  late final ScrollController verticalController;

  /// The current viewport size.
  Size _viewportSize = Size.zero;

  /// Creates a worksheet scroll delegate.
  WorksheetScrollDelegate({
    required this.layoutSolver,
    required this.zoomTransformer,
    double initialScrollX = 0.0,
    double initialScrollY = 0.0,
  }) {
    viewportDelegate = ViewportDelegate(
      contentWidth: layoutSolver.totalWidth,
      contentHeight: layoutSolver.totalHeight,
    );

    horizontalController = ScrollController(initialScrollOffset: initialScrollX);
    verticalController = ScrollController(initialScrollOffset: initialScrollY);
  }

  /// The current horizontal scroll offset.
  double get scrollX => horizontalController.hasClients
      ? horizontalController.offset
      : horizontalController.initialScrollOffset;

  /// The current vertical scroll offset.
  double get scrollY => verticalController.hasClients
      ? verticalController.offset
      : verticalController.initialScrollOffset;

  /// The current scroll offset as an Offset.
  Offset get scrollOffset => Offset(scrollX, scrollY);

  /// The current zoom level.
  double get zoom => zoomTransformer.scale;

  /// The current viewport size.
  Size get viewportSize => _viewportSize;

  /// The scroll physics to use for both controllers.
  ScrollPhysics get physics => const WorksheetScrollPhysics();

  /// Updates the viewport size and recalculates scroll extents.
  void updateViewportSize(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    _updateScrollExtents();
  }

  /// Updates scroll extents after zoom change.
  ///
  /// Call this after changing zoom to ensure scroll bounds are correct.
  void onZoomChanged() {
    _updateScrollExtents();
  }

  /// Creates an anchor from the current scroll state.
  ///
  /// Use this before a zoom operation to preserve the visual position
  /// of a specific point.
  ScrollAnchor createAnchorFromCenter() {
    return ScrollAnchor.fromCenter(
      viewportSize: _viewportSize,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
  }

  /// Creates an anchor from a focal point.
  ///
  /// Use this for pinch-to-zoom gestures where the focal point should
  /// remain stable.
  ScrollAnchor createAnchorFromFocalPoint(Offset focalPoint) {
    return ScrollAnchor.fromFocalPoint(
      focalPoint: focalPoint,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
  }

  /// Applies an anchor after a zoom change.
  ///
  /// This scrolls to maintain the visual position of the anchor point
  /// at its original viewport location.
  void applyAnchor(ScrollAnchor anchor) {
    final newOffset = anchor.calculateScrollOffset(zoom: zoom);
    final clampedOffset = ScrollAnchor.clampScrollOffset(
      offset: newOffset,
      contentSize: viewportDelegate.contentSize,
      viewportSize: _viewportSize,
      zoom: zoom,
    );

    _jumpTo(clampedOffset.dx, clampedOffset.dy);
  }

  /// Scrolls to a specific cell coordinate.
  void scrollToCell({
    required int row,
    required int column,
    bool animate = false,
  }) {
    final cellBounds = layoutSolver.getCellBounds(
      layoutSolver.getCellAt(Offset(
        layoutSolver.getColumnLeft(column),
        layoutSolver.getRowTop(row),
      ))!,
    );

    final targetX = cellBounds.left * zoom;
    final targetY = cellBounds.top * zoom;

    final maxScrollX = _getMaxScrollExtentX();
    final maxScrollY = _getMaxScrollExtentY();

    final clampedX = targetX.clamp(0.0, maxScrollX);
    final clampedY = targetY.clamp(0.0, maxScrollY);

    if (animate) {
      _animateTo(clampedX, clampedY);
    } else {
      _jumpTo(clampedX, clampedY);
    }
  }

  /// Scrolls to ensure a cell is visible.
  void ensureCellVisible({
    required int row,
    required int column,
    bool animate = false,
  }) {
    final cellBounds = layoutSolver.getCellBounds(
      layoutSolver.getCellAt(Offset(
        layoutSolver.getColumnLeft(column),
        layoutSolver.getRowTop(row),
      ))!,
    );

    // Convert to screen coordinates
    final cellLeft = cellBounds.left * zoom;
    final cellTop = cellBounds.top * zoom;
    final cellRight = cellBounds.right * zoom;
    final cellBottom = cellBounds.bottom * zoom;

    var targetX = scrollX;
    var targetY = scrollY;

    // Check if cell is fully visible horizontally
    if (cellLeft < scrollX) {
      targetX = cellLeft;
    } else if (cellRight > scrollX + _viewportSize.width) {
      targetX = cellRight - _viewportSize.width;
    }

    // Check if cell is fully visible vertically
    if (cellTop < scrollY) {
      targetY = cellTop;
    } else if (cellBottom > scrollY + _viewportSize.height) {
      targetY = cellBottom - _viewportSize.height;
    }

    if (targetX != scrollX || targetY != scrollY) {
      final maxScrollX = _getMaxScrollExtentX();
      final maxScrollY = _getMaxScrollExtentY();

      targetX = targetX.clamp(0.0, maxScrollX);
      targetY = targetY.clamp(0.0, maxScrollY);

      if (animate) {
        _animateTo(targetX, targetY);
      } else {
        _jumpTo(targetX, targetY);
      }
    }
  }

  /// Disposes the scroll delegate and its controllers.
  void dispose() {
    horizontalController.dispose();
    verticalController.dispose();
  }

  void _updateScrollExtents() {
    // The scroll controllers will automatically update their extents
    // when attached to a Scrollable. This method is here for explicit
    // extent calculation if needed.
  }

  double _getMaxScrollExtentX() {
    return viewportDelegate.getMaxScrollExtentX(
      viewportWidth: _viewportSize.width,
      zoom: zoom,
    );
  }

  double _getMaxScrollExtentY() {
    return viewportDelegate.getMaxScrollExtentY(
      viewportHeight: _viewportSize.height,
      zoom: zoom,
    );
  }

  void _jumpTo(double x, double y) {
    if (horizontalController.hasClients) {
      horizontalController.jumpTo(x);
    }
    if (verticalController.hasClients) {
      verticalController.jumpTo(y);
    }
  }

  void _animateTo(double x, double y) {
    if (horizontalController.hasClients) {
      horizontalController.animateTo(
        x,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (verticalController.hasClients) {
      verticalController.animateTo(
        y,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }
}
