import 'dart:ui';

/// Zoom buckets for level-of-detail rendering decisions.
///
/// Different zoom levels may render cells differently (e.g., hiding
/// text at very low zoom levels, hiding gridlines below 40%).
enum ZoomBucket {
  /// 10-24% zoom
  tenth,

  /// 25-39% zoom
  quarter,

  /// 40-49% zoom
  forty,

  /// 50-99% zoom
  half,

  /// 100-199% zoom
  full,

  /// 200-299% zoom
  twoX,

  /// 300-400% zoom
  quadruple;

  /// Returns the zoom bucket for the given zoom scale.
  static ZoomBucket fromZoom(double zoom) {
    if (zoom < 0.25) return ZoomBucket.tenth;
    if (zoom < 0.4) return ZoomBucket.quarter;
    if (zoom < 0.5) return ZoomBucket.forty;
    if (zoom < 1.0) return ZoomBucket.half;
    if (zoom < 2.0) return ZoomBucket.full;
    if (zoom < 3.0) return ZoomBucket.twoX;
    return ZoomBucket.quadruple;
  }
}

/// Transforms coordinates between screen space and worksheet space.
///
/// At zoom level 1.0, screen and worksheet coordinates are identical.
/// At zoom level 2.0, worksheet objects appear twice as large on screen.
class ZoomTransformer {
  /// The minimum allowed zoom scale.
  final double minScale;

  /// The maximum allowed zoom scale.
  final double maxScale;

  double _scale;

  /// Creates a zoom transformer with the given [scale].
  ///
  /// The scale is clamped to [minScale] and [maxScale].
  ZoomTransformer({
    double scale = 1.0,
    this.minScale = 0.1,
    this.maxScale = 4.0,
  }) : _scale = scale.clamp(minScale, maxScale);

  /// The current zoom scale (1.0 = 100%).
  double get scale => _scale;

  /// Sets the zoom scale, clamped to valid range.
  void setScale(double value) {
    _scale = value.clamp(minScale, maxScale);
  }

  /// The current zoom as a percentage (100 = 100%).
  int get percentage => (_scale * 100).round();

  /// Sets the zoom from a percentage value.
  void setPercentage(int percent) {
    setScale(percent / 100.0);
  }

  /// Whether zoom can be increased.
  bool get canZoomIn => _scale < maxScale;

  /// Whether zoom can be decreased.
  bool get canZoomOut => _scale > minScale;

  /// Converts a screen coordinate to worksheet coordinate.
  ///
  /// At 2x zoom, a screen position of (200, 100) corresponds to
  /// worksheet position (100, 50).
  Offset screenToWorksheet(Offset screenPoint) {
    return Offset(
      screenPoint.dx / _scale,
      screenPoint.dy / _scale,
    );
  }

  /// Converts a worksheet coordinate to screen coordinate.
  ///
  /// At 2x zoom, a worksheet position of (100, 50) appears at
  /// screen position (200, 100).
  Offset worksheetToScreen(Offset worksheetPoint) {
    return Offset(
      worksheetPoint.dx * _scale,
      worksheetPoint.dy * _scale,
    );
  }

  /// Converts a screen rect to worksheet coordinates.
  Rect screenToWorksheetRect(Rect screenRect) {
    return Rect.fromLTWH(
      screenRect.left / _scale,
      screenRect.top / _scale,
      screenRect.width / _scale,
      screenRect.height / _scale,
    );
  }

  /// Converts a worksheet rect to screen coordinates.
  Rect worksheetToScreenRect(Rect worksheetRect) {
    return Rect.fromLTWH(
      worksheetRect.left * _scale,
      worksheetRect.top * _scale,
      worksheetRect.width * _scale,
      worksheetRect.height * _scale,
    );
  }

  /// Converts a screen size to worksheet size.
  Size screenToWorksheetSize(Size screenSize) {
    return Size(
      screenSize.width / _scale,
      screenSize.height / _scale,
    );
  }

  /// Converts a worksheet size to screen size.
  Size worksheetToScreenSize(Size worksheetSize) {
    return Size(
      worksheetSize.width * _scale,
      worksheetSize.height * _scale,
    );
  }

  /// Scales a value from worksheet to screen space.
  double scaleValue(double worksheetValue) {
    return worksheetValue * _scale;
  }

  /// Unscales a value from screen to worksheet space.
  double unscaleValue(double screenValue) {
    return screenValue / _scale;
  }

  /// Returns the zoom bucket for the current scale.
  ///
  /// Used for level-of-detail rendering decisions.
  ZoomBucket get zoomBucket => ZoomBucket.fromZoom(_scale);
}
