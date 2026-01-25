import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/scrolling/scroll_physics.dart';

void main() {
  group('WorksheetScrollPhysics', () {
    group('construction', () {
      test('creates with default parameters', () {
        const physics = WorksheetScrollPhysics();
        expect(physics, isA<WorksheetScrollPhysics>());
      });

      test('creates with custom friction', () {
        const physics = WorksheetScrollPhysics(friction: 0.05);
        expect(physics.friction, 0.05);
      });

      test('creates with custom velocity threshold', () {
        const physics = WorksheetScrollPhysics(minFlingVelocity: 100.0);
        expect(physics.minFlingVelocity, 100.0);
      });
    });

    group('applyTo', () {
      test('creates new instance with ancestor', () {
        const physics = WorksheetScrollPhysics();
        const ancestor = ClampingScrollPhysics();

        final applied = physics.applyTo(ancestor);

        expect(applied, isA<WorksheetScrollPhysics>());
        expect(applied.parent, ancestor);
      });

      test('preserves friction when applying to ancestor', () {
        const physics = WorksheetScrollPhysics(friction: 0.08);
        const ancestor = ClampingScrollPhysics();

        final applied = physics.applyTo(ancestor) as WorksheetScrollPhysics;

        expect(applied.friction, 0.08);
      });
    });

    group('boundary behavior', () {
      test('clamps at min boundary', () {
        const physics = WorksheetScrollPhysics();

        final position = FixedScrollMetrics(
          pixels: 0,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        // Trying to scroll to -20 (below min)
        final boundaryCondition = physics.applyBoundaryConditions(position, -20);
        // Should return -20 (the overflow amount)
        expect(boundaryCondition, -20.0);
      });

      test('clamps at max boundary', () {
        const physics = WorksheetScrollPhysics();

        final position = FixedScrollMetrics(
          pixels: 1000,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        // Trying to scroll to 1020 (above max)
        final boundaryCondition = physics.applyBoundaryConditions(position, 1020);
        expect(boundaryCondition, 20.0);
      });

      test('allows scroll within bounds', () {
        const physics = WorksheetScrollPhysics();

        final position = FixedScrollMetrics(
          pixels: 500,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        final boundaryCondition = physics.applyBoundaryConditions(position, 510);
        expect(boundaryCondition, 0.0);
      });
    });

    group('friction simulation', () {
      test('creates simulation for fling', () {
        const physics = WorksheetScrollPhysics();

        final position = FixedScrollMetrics(
          pixels: 500,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        final simulation = physics.createBallisticSimulation(position, 1000.0);

        expect(simulation, isNotNull);
      });

      test('returns null for zero velocity', () {
        const physics = WorksheetScrollPhysics();

        final position = FixedScrollMetrics(
          pixels: 500,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        final simulation = physics.createBallisticSimulation(position, 0.0);

        expect(simulation, isNull);
      });

      test('respects minimum fling velocity', () {
        const physics = WorksheetScrollPhysics(minFlingVelocity: 500.0);

        final position = FixedScrollMetrics(
          pixels: 500,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );

        // Below threshold
        final slowSimulation = physics.createBallisticSimulation(position, 100.0);
        expect(slowSimulation, isNull);

        // Above threshold
        final fastSimulation = physics.createBallisticSimulation(position, 600.0);
        expect(fastSimulation, isNotNull);
      });
    });

    group('drag behavior', () {
      test('has minimum fling distance', () {
        const physics = WorksheetScrollPhysics();

        expect(physics.minFlingDistance, 50.0);
      });
    });

    group('momentum', () {
      test('carries momentum above threshold', () {
        const physics = WorksheetScrollPhysics(minFlingVelocity: 50.0);

        final momentum = physics.carriedMomentum(200.0);
        expect(momentum, 100.0); // 200 * 0.5
      });

      test('carries negative momentum above threshold', () {
        const physics = WorksheetScrollPhysics(minFlingVelocity: 50.0);

        final momentum = physics.carriedMomentum(-200.0);
        expect(momentum, -100.0); // -200 * 0.5
      });

      test('no momentum below threshold', () {
        const physics = WorksheetScrollPhysics(minFlingVelocity: 50.0);

        final momentum = physics.carriedMomentum(30.0);
        expect(momentum, 0.0);
      });
    });
  });
}
