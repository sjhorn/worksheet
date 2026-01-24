import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet2/src/rendering/tile/tile_config.dart';

void main() {
  group('TileConfig', () {
    group('construction', () {
      test('creates with default values', () {
        final config = TileConfig();
        expect(config.tileSize, 256);
        expect(config.maxCachedTiles, 100);
        expect(config.prefetchRings, 1);
      });

      test('creates with custom values', () {
        final config = TileConfig(
          tileSize: 512,
          maxCachedTiles: 200,
          prefetchRings: 2,
        );
        expect(config.tileSize, 512);
        expect(config.maxCachedTiles, 200);
        expect(config.prefetchRings, 2);
      });

      test('throws for non-positive tile size', () {
        expect(() => TileConfig(tileSize: 0), throwsAssertionError);
        expect(() => TileConfig(tileSize: -1), throwsAssertionError);
      });

      test('throws for non-positive max cached tiles', () {
        expect(() => TileConfig(maxCachedTiles: 0), throwsAssertionError);
      });

      test('throws for negative prefetch rings', () {
        expect(() => TileConfig(prefetchRings: -1), throwsAssertionError);
      });
    });

    group('tileWidth and tileHeight', () {
      test('returns tile size', () {
        final config = TileConfig(tileSize: 256);
        expect(config.tileWidth, 256);
        expect(config.tileHeight, 256);
      });
    });

    group('getTileSizeForZoom', () {
      test('returns same size at zoom 1.0', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileSizeForZoom(1.0), 256);
      });

      test('returns scaled size at zoom 2.0', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileSizeForZoom(2.0), 512);
      });

      test('returns scaled size at zoom 0.5', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileSizeForZoom(0.5), 128);
      });
    });

    group('getZoomBucketTileSize', () {
      test('returns appropriate tile size for zoom bucket', () {
        final config = TileConfig(tileSize: 256);

        // At full zoom (100%), tile covers 256 worksheet pixels
        expect(config.getZoomBucketTileSize(ZoomBucket.full), 256);

        // At half zoom (50%), tile covers 512 worksheet pixels
        expect(config.getZoomBucketTileSize(ZoomBucket.half), 512);

        // At quarter zoom (25%), tile covers 1024 worksheet pixels
        expect(config.getZoomBucketTileSize(ZoomBucket.quarter), 1024);

        // At double zoom (200%), tile covers 128 worksheet pixels
        expect(config.getZoomBucketTileSize(ZoomBucket.twoX), 128);
      });
    });

    group('getTileCountForDimension', () {
      test('calculates tile count for exact fit', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileCountForDimension(1024), 4);
      });

      test('rounds up for partial tiles', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileCountForDimension(1000), 4); // ceil(1000/256)
        expect(config.getTileCountForDimension(1025), 5);
      });

      test('returns 1 for dimension smaller than tile', () {
        final config = TileConfig(tileSize: 256);
        expect(config.getTileCountForDimension(100), 1);
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        final a = TileConfig(tileSize: 256, maxCachedTiles: 100);
        final b = TileConfig(tileSize: 256, maxCachedTiles: 100);
        expect(a, b);
      });

      test('different configs are not equal', () {
        final a = TileConfig(tileSize: 256);
        final b = TileConfig(tileSize: 512);
        expect(a == b, isFalse);
      });
    });

    group('hashCode', () {
      test('equal configs have same hashCode', () {
        final a = TileConfig(tileSize: 256, maxCachedTiles: 100);
        final b = TileConfig(tileSize: 256, maxCachedTiles: 100);
        expect(a.hashCode, b.hashCode);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final config = TileConfig(tileSize: 256, maxCachedTiles: 100);
        final copy = config.copyWith(tileSize: 512);

        expect(copy.tileSize, 512);
        expect(copy.maxCachedTiles, 100);
      });

      test('returns equivalent when nothing specified', () {
        final config = TileConfig(tileSize: 256);
        final copy = config.copyWith();
        expect(copy, config);
      });
    });
  });
}
