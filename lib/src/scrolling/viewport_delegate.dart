import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Delegate that provides content dimensions and viewport calculations.
///
/// This delegate manages the relationship between content size, viewport size,
/// and zoom level to calculate scroll extents and visible regions.
class ViewportDelegate extends ChangeNotifier {
  /// The total content width in worksheet coordinates.
  double _contentWidth;

  /// The total content height in worksheet coordinates.
  double _contentHeight;

  /// Creates a viewport delegate with the given content dimensions.
  ViewportDelegate({
    required double contentWidth,
    required double contentHeight,
  })  : assert(contentWidth > 0, 'Content width must be positive'),
        assert(contentHeight > 0, 'Content height must be positive'),
        _contentWidth = contentWidth,
        _contentHeight = contentHeight;

  /// The total content width.
  double get contentWidth => _contentWidth;

  /// The total content height.
  double get contentHeight => _contentHeight;

  /// The content size as a Size object.
  Size get contentSize => Size(_contentWidth, _contentHeight);

  /// Updates the content dimensions.
  ///
  /// Notifies listeners if the size changed.
  void updateContentSize({required double width, required double height}) {
    if (_contentWidth == width && _contentHeight == height) {
      return;
    }
    _contentWidth = width;
    _contentHeight = height;
    notifyListeners();
  }

  /// Calculates the maximum horizontal scroll extent.
  ///
  /// Returns the maximum scroll position that keeps content visible.
  double getMaxScrollExtentX({
    required double viewportWidth,
    required double zoom,
  }) {
    final scaledWidth = _contentWidth * zoom;
    return math.max(0.0, scaledWidth - viewportWidth);
  }

  /// Calculates the maximum vertical scroll extent.
  ///
  /// Returns the maximum scroll position that keeps content visible.
  double getMaxScrollExtentY({
    required double viewportHeight,
    required double zoom,
  }) {
    final scaledHeight = _contentHeight * zoom;
    return math.max(0.0, scaledHeight - viewportHeight);
  }

  /// Calculates the visible rectangle in worksheet coordinates.
  ///
  /// Takes screen-space scroll position and viewport size, and returns
  /// the corresponding region in worksheet (unzoomed) coordinates.
  Rect getVisibleRect({
    required double scrollX,
    required double scrollY,
    required double viewportWidth,
    required double viewportHeight,
    required double zoom,
  }) {
    // Convert scroll position to worksheet coordinates
    final worksheetX = scrollX / zoom;
    final worksheetY = scrollY / zoom;

    // Convert viewport size to worksheet coordinates
    final worksheetWidth = viewportWidth / zoom;
    final worksheetHeight = viewportHeight / zoom;

    return Rect.fromLTWH(
      worksheetX,
      worksheetY,
      worksheetWidth,
      worksheetHeight,
    );
  }
}
