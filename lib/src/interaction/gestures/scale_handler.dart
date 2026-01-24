import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../controllers/zoom_controller.dart';

/// Handles pinch-to-zoom gestures for the worksheet.
///
/// Manages:
/// - Scale detection from pinch gestures
/// - Focal point preservation during zoom
/// - Smooth zoom transitions
class ScaleHandler extends ChangeNotifier {
  /// The zoom controller to update.
  final ZoomController zoomController;

  /// Whether a scale gesture is in progress.
  bool _isScaling = false;

  /// The scale when the gesture started.
  double _startScale = 1.0;

  /// The zoom level when the gesture started.
  double _startZoom = 1.0;

  /// The focal point of the gesture in screen coordinates.
  Offset _focalPoint = Offset.zero;

  /// The current scroll offset (needed for anchor calculation).
  Offset _scrollOffset = Offset.zero;

  /// Creates a scale handler.
  ScaleHandler({required this.zoomController});

  /// Whether a scale gesture is currently in progress.
  bool get isScaling => _isScaling;

  /// The current focal point in screen coordinates.
  Offset get focalPoint => _focalPoint;

  /// The scroll adjustment needed to maintain the focal point.
  ///
  /// Apply this offset to the scroll controllers after zoom changes.
  Offset get scrollAdjustment {
    if (!_isScaling) return Offset.zero;

    final oldZoom = _startZoom;
    final newZoom = zoomController.value;
    final zoomDelta = newZoom - oldZoom;

    if (zoomDelta.abs() < 0.001) return Offset.zero;

    // Calculate the worksheet position of the focal point before zoom
    final worksheetFocal = Offset(
      (_focalPoint.dx + _scrollOffset.dx) / oldZoom,
      (_focalPoint.dy + _scrollOffset.dy) / oldZoom,
    );

    // Calculate the new scroll offset to keep the focal point stationary
    final newScrollX = worksheetFocal.dx * newZoom - _focalPoint.dx;
    final newScrollY = worksheetFocal.dy * newZoom - _focalPoint.dy;

    return Offset(
      newScrollX - _scrollOffset.dx,
      newScrollY - _scrollOffset.dy,
    );
  }

  /// Called when a scale gesture starts.
  ///
  /// [scale] is the initial scale (usually 1.0).
  /// [focalPoint] is the center of the pinch in screen coordinates.
  /// [scrollOffset] is the current scroll offset.
  void onScaleStart({
    required double scale,
    required Offset focalPoint,
    required Offset scrollOffset,
  }) {
    _isScaling = true;
    _startScale = scale;
    _startZoom = zoomController.value;
    _focalPoint = focalPoint;
    _scrollOffset = scrollOffset;
    notifyListeners();
  }

  /// Called when the scale gesture is updated.
  ///
  /// [scale] is the current scale relative to the start.
  /// [focalPoint] is the current center of the pinch.
  void onScaleUpdate({
    required double scale,
    required Offset focalPoint,
  }) {
    if (!_isScaling) return;

    // Calculate the new zoom level
    final zoomDelta = scale / _startScale;
    final newZoom = _startZoom * zoomDelta;

    // Update focal point (may drift during gesture)
    _focalPoint = focalPoint;

    // Update zoom controller
    zoomController.value = newZoom;
    notifyListeners();
  }

  /// Called when the scale gesture ends.
  void onScaleEnd() {
    _isScaling = false;
    notifyListeners();
  }

  /// Zooms in/out by a factor, anchored at a point.
  ///
  /// [factor] is the zoom multiplier (>1 to zoom in, <1 to zoom out).
  /// [anchor] is the point in screen coordinates that should remain fixed.
  /// [scrollOffset] is the current scroll offset.
  ///
  /// Returns the scroll adjustment needed to maintain the anchor.
  Offset zoomBy({
    required double factor,
    required Offset anchor,
    required Offset scrollOffset,
  }) {
    final oldZoom = zoomController.value;
    final newZoom = (oldZoom * factor).clamp(
      zoomController.minZoom,
      zoomController.maxZoom,
    );

    if (newZoom == oldZoom) return Offset.zero;

    // Calculate the worksheet position of the anchor before zoom
    final worksheetAnchor = Offset(
      (anchor.dx + scrollOffset.dx) / oldZoom,
      (anchor.dy + scrollOffset.dy) / oldZoom,
    );

    // Update zoom
    zoomController.value = newZoom;

    // Calculate the scroll adjustment to keep anchor stationary
    final newScrollX = worksheetAnchor.dx * newZoom - anchor.dx;
    final newScrollY = worksheetAnchor.dy * newZoom - anchor.dy;

    return Offset(
      newScrollX - scrollOffset.dx,
      newScrollY - scrollOffset.dy,
    );
  }

  /// Zooms to fit the given rectangle in the viewport.
  ///
  /// [rect] is the rectangle in worksheet coordinates to fit.
  /// [viewportSize] is the size of the viewport.
  /// [padding] is the padding around the rectangle.
  ///
  /// Returns the zoom level and scroll offset to fit the rectangle.
  ({double zoom, Offset scroll}) zoomToFit({
    required Rect rect,
    required Size viewportSize,
    double padding = 20.0,
  }) {
    // Calculate the zoom needed to fit the rectangle
    final availableWidth = viewportSize.width - padding * 2;
    final availableHeight = viewportSize.height - padding * 2;

    final zoomX = availableWidth / rect.width;
    final zoomY = availableHeight / rect.height;
    final zoom = (zoomX < zoomY ? zoomX : zoomY).clamp(
      zoomController.minZoom,
      zoomController.maxZoom,
    );

    // Calculate the scroll offset to center the rectangle
    final scaledRectWidth = rect.width * zoom;
    final scaledRectHeight = rect.height * zoom;

    final scrollX = rect.left * zoom - (viewportSize.width - scaledRectWidth) / 2;
    final scrollY = rect.top * zoom - (viewportSize.height - scaledRectHeight) / 2;

    return (
      zoom: zoom,
      scroll: Offset(scrollX.clamp(0, double.infinity), scrollY.clamp(0, double.infinity)),
    );
  }
}
