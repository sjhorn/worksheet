import 'dart:math' as math;
import 'dart:ui';

/// Represents an anchor point for preserving visual position during zoom.
///
/// When zooming, we want a specific point on the worksheet to remain at the
/// same position on screen. ScrollAnchor captures this relationship and can
/// calculate the new scroll offset needed after a zoom change.
///
/// The anchor stores:
/// - [worksheetPosition]: The point in worksheet coordinates (unzoomed)
/// - [viewportOffset]: Where that point appears in the viewport (screen coords)
class ScrollAnchor {
  /// The position in worksheet (unzoomed) coordinates.
  final Offset worksheetPosition;

  /// The offset within the viewport where this position appears.
  final Offset viewportOffset;

  /// Creates a scroll anchor with explicit positions.
  const ScrollAnchor({
    required this.worksheetPosition,
    required this.viewportOffset,
  });

  /// Creates an anchor from a focal point in the viewport.
  ///
  /// This is typically used when the user performs a pinch-to-zoom gesture,
  /// where [focalPoint] is the center of the pinch.
  ///
  /// The worksheet position is calculated as:
  /// `worksheetPosition = (scrollOffset + focalPoint) / zoom`
  factory ScrollAnchor.fromFocalPoint({
    required Offset focalPoint,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final worksheetPosition = Offset(
      (scrollOffset.dx + focalPoint.dx) / zoom,
      (scrollOffset.dy + focalPoint.dy) / zoom,
    );
    return ScrollAnchor(
      worksheetPosition: worksheetPosition,
      viewportOffset: focalPoint,
    );
  }

  /// Creates an anchor at the center of the viewport.
  ///
  /// This is used for keyboard or button-triggered zoom where there's no
  /// specific focal point.
  factory ScrollAnchor.fromCenter({
    required Size viewportSize,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    return ScrollAnchor.fromFocalPoint(
      focalPoint: center,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
  }

  /// Calculates the scroll offset needed to maintain this anchor at a new zoom.
  ///
  /// The calculation ensures that [worksheetPosition] remains at [viewportOffset]
  /// after applying the new zoom level:
  /// `scrollOffset = worksheetPosition * zoom - viewportOffset`
  Offset calculateScrollOffset({required double zoom}) {
    return Offset(
      worksheetPosition.dx * zoom - viewportOffset.dx,
      worksheetPosition.dy * zoom - viewportOffset.dy,
    );
  }

  /// Clamps a scroll offset to valid bounds for the given content and viewport.
  ///
  /// This prevents scrolling beyond the content boundaries.
  static Offset clampScrollOffset({
    required Offset offset,
    required Size contentSize,
    required Size viewportSize,
    required double zoom,
  }) {
    final scaledContentWidth = contentSize.width * zoom;
    final scaledContentHeight = contentSize.height * zoom;

    final maxScrollX = math.max(0.0, scaledContentWidth - viewportSize.width);
    final maxScrollY = math.max(0.0, scaledContentHeight - viewportSize.height);

    return Offset(
      offset.dx.clamp(0.0, maxScrollX),
      offset.dy.clamp(0.0, maxScrollY),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScrollAnchor &&
        other.worksheetPosition == worksheetPosition &&
        other.viewportOffset == viewportOffset;
  }

  @override
  int get hashCode => Object.hash(worksheetPosition, viewportOffset);

  @override
  String toString() =>
      'ScrollAnchor(worksheet: $worksheetPosition, viewport: $viewportOffset)';
}
