import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../core/geometry/zoom_transformer.dart';

/// Controls the zoom level of a worksheet with animation support.
///
/// Provides methods to get/set zoom as a scale factor (1.0 = 100%) or
/// percentage, with automatic clamping to valid range.
class ZoomController extends ValueNotifier<double> {
  /// The minimum allowed zoom level.
  final double minZoom;

  /// The maximum allowed zoom level.
  final double maxZoom;

  /// The initial zoom level (used for reset).
  final double _initialZoom;

  /// Current animation controller, if any.
  AnimationController? _animationController;

  /// Creates a zoom controller.
  ///
  /// [initialZoom] defaults to 1.0 (100%).
  /// [minZoom] defaults to 0.1 (10%).
  /// [maxZoom] defaults to 4.0 (400%).
  ZoomController({
    double initialZoom = 1.0,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
  })  : _initialZoom = initialZoom.clamp(minZoom, maxZoom),
        super(initialZoom.clamp(minZoom, maxZoom));

  @override
  set value(double newValue) {
    super.value = newValue.clamp(minZoom, maxZoom);
  }

  /// The current zoom as a percentage (100 = 100%).
  int get percentage => (value * 100).round();

  /// Sets the zoom from a percentage value.
  void setPercentage(int percent) {
    value = percent / 100.0;
  }

  /// Multiplies the current zoom by [factor].
  void zoomBy(double factor) {
    value = value * factor;
  }

  /// Increases zoom by [step] (default 0.25).
  void zoomIn({double step = 0.25}) {
    value = value + step;
  }

  /// Decreases zoom by [step] (default 0.25).
  void zoomOut({double step = 0.25}) {
    value = value - step;
  }

  /// Whether zoom can be increased.
  bool get canZoomIn => value < maxZoom;

  /// Whether zoom can be decreased.
  bool get canZoomOut => value > minZoom;

  /// Resets zoom to the initial value.
  void reset() {
    value = _initialZoom;
  }

  /// Animates to [target] zoom level.
  ///
  /// [vsync] is required for animation timing.
  /// [duration] defaults to 200ms.
  /// [curve] defaults to [Curves.easeOut].
  ///
  /// Any in-progress animation is cancelled.
  Future<void> animateTo(
    double target, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOut,
  }) async {
    // Cancel any existing animation
    _animationController?.dispose();

    // Clamp target
    target = target.clamp(minZoom, maxZoom);

    // Create new animation
    _animationController = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    final startZoom = value;
    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: curve,
    );

    animation.addListener(() {
      value = lerpDouble(startZoom, target, animation.value)!;
    });

    await _animationController!.forward();
  }

  /// Returns the [ZoomBucket] for the current zoom level.
  ZoomBucket get zoomBucket => ZoomBucket.fromZoom(value);

  @override
  void dispose() {
    _animationController?.dispose();
    _animationController = null;
    super.dispose();
  }
}
