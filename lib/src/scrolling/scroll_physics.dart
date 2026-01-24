import 'package:flutter/widgets.dart';

/// Custom scroll physics for the worksheet.
///
/// Provides clamping behavior (no overscroll) with configurable
/// friction for momentum scrolling.
class WorksheetScrollPhysics extends ScrollPhysics {
  /// The friction coefficient for momentum scrolling.
  ///
  /// Lower values result in longer scroll distances after a fling.
  /// Default is 0.015 for smooth, responsive scrolling.
  final double friction;

  /// Minimum velocity required to trigger a fling animation.
  ///
  /// Flings below this threshold will not animate.
  final double minFlingVelocity;

  /// Creates worksheet scroll physics.
  const WorksheetScrollPhysics({
    super.parent,
    this.friction = 0.015,
    this.minFlingVelocity = 50.0,
  });

  @override
  WorksheetScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WorksheetScrollPhysics(
      parent: buildParent(ancestor),
      friction: friction,
      minFlingVelocity: minFlingVelocity,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Clamp at boundaries - no overscroll allowed
    if (value < position.minScrollExtent) {
      // Trying to scroll before start
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      // Trying to scroll past end
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // If at boundary, use parent behavior for settling
    if (position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }

    // If velocity is below threshold, no fling
    if (velocity.abs() < minFlingVelocity) {
      return null;
    }

    // Create friction simulation for momentum scroll
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: friction,
    );
  }

  @override
  double get minFlingDistance => 50.0;

  @override
  double carriedMomentum(double existingVelocity) {
    // Preserve momentum when changing scroll direction
    return existingVelocity.sign *
        (existingVelocity.abs() > minFlingVelocity
            ? existingVelocity.abs() * 0.5
            : 0.0);
  }
}
