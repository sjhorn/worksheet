import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/scrolling/viewport_delegate.dart';

void main() {
  group('ViewportDelegate', () {
    group('construction', () {
      test('creates with content size', () {
        final delegate = ViewportDelegate(
          contentWidth: 10000,
          contentHeight: 25000,
        );

        expect(delegate.contentWidth, 10000);
        expect(delegate.contentHeight, 25000);
      });

      test('content size must be positive', () {
        expect(
          () => ViewportDelegate(contentWidth: 0, contentHeight: 100),
          throwsAssertionError,
        );
        expect(
          () => ViewportDelegate(contentWidth: 100, contentHeight: 0),
          throwsAssertionError,
        );
      });
    });

    group('contentSize', () {
      test('returns content size as Size', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        expect(delegate.contentSize, const Size(5000, 3000));
      });
    });

    group('updateContentSize', () {
      test('updates content dimensions', () {
        final delegate = ViewportDelegate(
          contentWidth: 1000,
          contentHeight: 500,
        );

        delegate.updateContentSize(width: 2000, height: 1000);

        expect(delegate.contentWidth, 2000);
        expect(delegate.contentHeight, 1000);
      });

      test('notifies listeners on change', () {
        final delegate = ViewportDelegate(
          contentWidth: 1000,
          contentHeight: 500,
        );

        var notified = false;
        delegate.addListener(() => notified = true);

        delegate.updateContentSize(width: 2000, height: 1000);

        expect(notified, isTrue);
      });

      test('does not notify when size unchanged', () {
        final delegate = ViewportDelegate(
          contentWidth: 1000,
          contentHeight: 500,
        );

        var notifyCount = 0;
        delegate.addListener(() => notifyCount++);

        delegate.updateContentSize(width: 1000, height: 500);

        expect(notifyCount, 0);
      });
    });

    group('getMaxScrollExtent', () {
      test('calculates max horizontal scroll', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final maxX = delegate.getMaxScrollExtentX(
          viewportWidth: 800,
          zoom: 1.0,
        );

        // content * zoom - viewport = 5000 - 800 = 4200
        expect(maxX, 4200);
      });

      test('calculates max vertical scroll', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final maxY = delegate.getMaxScrollExtentY(
          viewportHeight: 600,
          zoom: 1.0,
        );

        expect(maxY, 2400);
      });

      test('accounts for zoom', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final maxX = delegate.getMaxScrollExtentX(
          viewportWidth: 800,
          zoom: 2.0,
        );

        // content * zoom - viewport = 10000 - 800 = 9200
        expect(maxX, 9200);
      });

      test('returns zero when viewport larger than content', () {
        final delegate = ViewportDelegate(
          contentWidth: 500,
          contentHeight: 300,
        );

        final maxX = delegate.getMaxScrollExtentX(
          viewportWidth: 800,
          zoom: 1.0,
        );

        expect(maxX, 0);
      });
    });

    group('getVisibleRect', () {
      test('calculates visible rect at zoom 1.0', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final rect = delegate.getVisibleRect(
          scrollX: 100,
          scrollY: 200,
          viewportWidth: 800,
          viewportHeight: 600,
          zoom: 1.0,
        );

        expect(rect, const Rect.fromLTWH(100, 200, 800, 600));
      });

      test('calculates visible rect with zoom', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final rect = delegate.getVisibleRect(
          scrollX: 200,
          scrollY: 100,
          viewportWidth: 800,
          viewportHeight: 600,
          zoom: 2.0,
        );

        // At 2x zoom, viewport shows half the area in worksheet coords
        // scroll is in screen coords, convert to worksheet: scroll/zoom
        // visible area in worksheet = viewport/zoom
        expect(rect.left, 100); // 200/2
        expect(rect.top, 50); // 100/2
        expect(rect.width, 400); // 800/2
        expect(rect.height, 300); // 600/2
      });

      test('calculates visible rect at zoom out', () {
        final delegate = ViewportDelegate(
          contentWidth: 5000,
          contentHeight: 3000,
        );

        final rect = delegate.getVisibleRect(
          scrollX: 100,
          scrollY: 50,
          viewportWidth: 800,
          viewportHeight: 600,
          zoom: 0.5,
        );

        // At 0.5x zoom, viewport shows double the area in worksheet coords
        expect(rect.left, 200); // 100/0.5
        expect(rect.top, 100); // 50/0.5
        expect(rect.width, 1600); // 800/0.5
        expect(rect.height, 1200); // 600/0.5
      });
    });

    group('dispose', () {
      test('disposes cleanly', () {
        final delegate = ViewportDelegate(
          contentWidth: 1000,
          contentHeight: 500,
        );

        delegate.dispose();
        // Should not throw
      });
    });
  });
}
