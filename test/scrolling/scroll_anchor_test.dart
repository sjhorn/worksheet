import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/scrolling/scroll_anchor.dart';

void main() {
  group('ScrollAnchor', () {
    group('construction', () {
      test('creates with worksheet position and viewport offset', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(500, 300),
          viewportOffset: Offset(100, 50),
        );

        expect(anchor.worksheetPosition, const Offset(500, 300));
        expect(anchor.viewportOffset, const Offset(100, 50));
      });

      test('fromFocalPoint calculates worksheet position from scroll and zoom', () {
        // Viewport focal point at (200, 100) with scroll offset (1000, 500) at zoom 2.0
        // Worksheet position = (scrollOffset + focalPoint) / zoom
        // = (1000 + 200, 500 + 100) / 2.0 = (600, 300)
        final anchor = ScrollAnchor.fromFocalPoint(
          focalPoint: const Offset(200, 100),
          scrollOffset: const Offset(1000, 500),
          zoom: 2.0,
        );

        expect(anchor.worksheetPosition, const Offset(600, 300));
        expect(anchor.viewportOffset, const Offset(200, 100));
      });

      test('fromFocalPoint works at 100% zoom', () {
        final anchor = ScrollAnchor.fromFocalPoint(
          focalPoint: const Offset(150, 75),
          scrollOffset: const Offset(300, 200),
          zoom: 1.0,
        );

        expect(anchor.worksheetPosition, const Offset(450, 275));
        expect(anchor.viewportOffset, const Offset(150, 75));
      });

      test('fromFocalPoint works at zoom < 1', () {
        // At 0.5 zoom, worksheet appears half size
        // focalPoint (100, 50), scroll (200, 100), zoom 0.5
        // worksheet = (200 + 100, 100 + 50) / 0.5 = (600, 300)
        final anchor = ScrollAnchor.fromFocalPoint(
          focalPoint: const Offset(100, 50),
          scrollOffset: const Offset(200, 100),
          zoom: 0.5,
        );

        expect(anchor.worksheetPosition, const Offset(600, 300));
        expect(anchor.viewportOffset, const Offset(100, 50));
      });

      test('fromCenter creates anchor at viewport center', () {
        final anchor = ScrollAnchor.fromCenter(
          viewportSize: const Size(800, 600),
          scrollOffset: const Offset(1000, 500),
          zoom: 1.0,
        );

        expect(anchor.viewportOffset, const Offset(400, 300));
        expect(anchor.worksheetPosition, const Offset(1400, 800));
      });
    });

    group('calculateScrollOffset', () {
      test('returns scroll offset to maintain anchor at new zoom', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(500, 300),
          viewportOffset: Offset(100, 50),
        );

        // At zoom 2.0, worksheet position 500 becomes screen position 1000
        // To keep viewport offset at 100, scroll = 1000 - 100 = 900
        final scrollOffset = anchor.calculateScrollOffset(zoom: 2.0);

        expect(scrollOffset, const Offset(900, 550));
      });

      test('returns zero offset when anchor at origin with zoom 1.0', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(100, 50),
          viewportOffset: Offset(100, 50),
        );

        final scrollOffset = anchor.calculateScrollOffset(zoom: 1.0);

        expect(scrollOffset, Offset.zero);
      });

      test('handles zoom out', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(1000, 500),
          viewportOffset: Offset(200, 100),
        );

        // At zoom 0.5, worksheet position 1000 becomes screen position 500
        // scroll = 500 - 200 = 300
        final scrollOffset = anchor.calculateScrollOffset(zoom: 0.5);

        expect(scrollOffset, const Offset(300, 150));
      });

      test('round trip preserves position', () {
        // Start: scroll (500, 300), zoom 1.5, focal point (200, 100)
        final anchor = ScrollAnchor.fromFocalPoint(
          focalPoint: const Offset(200, 100),
          scrollOffset: const Offset(500, 300),
          zoom: 1.5,
        );

        // Calculate what scroll should be at original zoom
        final newScroll = anchor.calculateScrollOffset(zoom: 1.5);

        // Should get back approximately the same scroll
        expect(newScroll.dx, closeTo(500, 0.001));
        expect(newScroll.dy, closeTo(300, 0.001));
      });
    });

    group('clampScrollOffset', () {
      test('clamps scroll to valid range', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(100, 100),
          viewportOffset: Offset(200, 200),
        );

        // Would result in negative scroll
        final scrollOffset = anchor.calculateScrollOffset(zoom: 1.0);
        expect(scrollOffset.dx, -100); // 100 - 200
        expect(scrollOffset.dy, -100);

        // Clamp to valid bounds
        final clamped = ScrollAnchor.clampScrollOffset(
          offset: scrollOffset,
          contentSize: const Size(2000, 1000),
          viewportSize: const Size(800, 600),
          zoom: 1.0,
        );

        expect(clamped.dx, 0);
        expect(clamped.dy, 0);
      });

      test('clamps to max scroll', () {
        final offset = const Offset(5000, 3000);

        final clamped = ScrollAnchor.clampScrollOffset(
          offset: offset,
          contentSize: const Size(2000, 1000),
          viewportSize: const Size(800, 600),
          zoom: 1.0,
        );

        // Max scroll = content * zoom - viewport = 2000 - 800 = 1200, 1000 - 600 = 400
        expect(clamped.dx, 1200);
        expect(clamped.dy, 400);
      });

      test('accounts for zoom in max calculation', () {
        final offset = const Offset(5000, 3000);

        final clamped = ScrollAnchor.clampScrollOffset(
          offset: offset,
          contentSize: const Size(2000, 1000),
          viewportSize: const Size(800, 600),
          zoom: 2.0,
        );

        // Max scroll = content * zoom - viewport = 4000 - 800 = 3200, 2000 - 600 = 1400
        expect(clamped.dx, 3200);
        expect(clamped.dy, 1400);
      });

      test('returns zero when viewport larger than content', () {
        final offset = const Offset(100, 100);

        final clamped = ScrollAnchor.clampScrollOffset(
          offset: offset,
          contentSize: const Size(500, 400),
          viewportSize: const Size(800, 600),
          zoom: 1.0,
        );

        expect(clamped, Offset.zero);
      });
    });

    group('equality', () {
      test('equal anchors are equal', () {
        const a = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(50, 25),
        );
        const b = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(50, 25),
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different worksheet positions are not equal', () {
        const a = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(50, 25),
        );
        const b = ScrollAnchor(
          worksheetPosition: Offset(101, 200),
          viewportOffset: Offset(50, 25),
        );

        expect(a, isNot(b));
      });

      test('different viewport offsets are not equal', () {
        const a = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(50, 25),
        );
        const b = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(51, 25),
        );

        expect(a, isNot(b));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const anchor = ScrollAnchor(
          worksheetPosition: Offset(100, 200),
          viewportOffset: Offset(50, 25),
        );

        expect(
          anchor.toString(),
          'ScrollAnchor(worksheet: Offset(100.0, 200.0), viewport: Offset(50.0, 25.0))',
        );
      });
    });
  });
}
