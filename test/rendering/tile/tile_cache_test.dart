import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/tile/tile.dart';
import 'package:worksheet/src/rendering/tile/tile_cache.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';

ui.Picture _createTestPicture() {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 256, 256),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording();
}

Tile _createTestTile(int row, int col, {ZoomBucket zoomBucket = ZoomBucket.full}) {
  return Tile(
    coordinate: TileCoordinate(row, col),
    zoomBucket: zoomBucket,
    picture: _createTestPicture(),
    cellRange: CellRange(row * 10, col * 10, row * 10 + 9, col * 10 + 9),
  );
}

void main() {
  group('TileCache', () {
    late TileCache cache;

    setUp(() {
      cache = TileCache(maxTiles: 5);
    });

    tearDown(() {
      cache.dispose();
    });

    group('construction', () {
      test('creates with max tiles limit', () {
        final cache = TileCache(maxTiles: 100);
        expect(cache.maxTiles, 100);
        cache.dispose();
      });

      test('throws for non-positive max tiles', () {
        expect(() => TileCache(maxTiles: 0), throwsAssertionError);
        expect(() => TileCache(maxTiles: -1), throwsAssertionError);
      });

      test('starts empty', () {
        expect(cache.size, 0);
        expect(cache.isEmpty, isTrue);
      });
    });

    group('put/get', () {
      test('stores and retrieves tile', () {
        final tile = _createTestTile(0, 0);
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);

        cache.put(key, tile);
        expect(cache.get(key), tile);
      });

      test('returns null for missing tile', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        expect(cache.get(key), isNull);
      });

      test('updates size on put', () {
        cache.put(
          TileKey(TileCoordinate(0, 0), ZoomBucket.full),
          _createTestTile(0, 0),
        );
        expect(cache.size, 1);

        cache.put(
          TileKey(TileCoordinate(0, 1), ZoomBucket.full),
          _createTestTile(0, 1),
        );
        expect(cache.size, 2);
      });

      test('replaces existing tile with same key', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        final tile1 = _createTestTile(0, 0);
        final tile2 = _createTestTile(0, 0);

        cache.put(key, tile1);
        cache.put(key, tile2);

        expect(cache.size, 1);
        expect(cache.get(key), tile2);
      });
    });

    group('LRU eviction', () {
      test('evicts least recently used when full', () {
        // Fill cache to capacity
        for (var i = 0; i < 5; i++) {
          cache.put(
            TileKey(TileCoordinate(0, i), ZoomBucket.full),
            _createTestTile(0, i),
          );
        }
        expect(cache.size, 5);

        // Add one more, should evict oldest
        cache.put(
          TileKey(TileCoordinate(0, 5), ZoomBucket.full),
          _createTestTile(0, 5),
        );
        expect(cache.size, 5);

        // First tile should be evicted
        expect(
          cache.get(TileKey(TileCoordinate(0, 0), ZoomBucket.full)),
          isNull,
        );

        // New tile should be present
        expect(
          cache.get(TileKey(TileCoordinate(0, 5), ZoomBucket.full)),
          isNotNull,
        );
      });

      test('get updates recency', () {
        // Add tiles
        for (var i = 0; i < 5; i++) {
          cache.put(
            TileKey(TileCoordinate(0, i), ZoomBucket.full),
            _createTestTile(0, i),
          );
        }

        // Access first tile to make it recently used
        cache.get(TileKey(TileCoordinate(0, 0), ZoomBucket.full));

        // Add new tile, should evict second tile (now oldest)
        cache.put(
          TileKey(TileCoordinate(0, 5), ZoomBucket.full),
          _createTestTile(0, 5),
        );

        // First tile should still be present (was accessed)
        expect(
          cache.get(TileKey(TileCoordinate(0, 0), ZoomBucket.full)),
          isNotNull,
        );

        // Second tile should be evicted
        expect(
          cache.get(TileKey(TileCoordinate(0, 1), ZoomBucket.full)),
          isNull,
        );
      });
    });

    group('containsKey', () {
      test('returns true for existing key', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        cache.put(key, _createTestTile(0, 0));

        expect(cache.containsKey(key), isTrue);
      });

      test('returns false for missing key', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        expect(cache.containsKey(key), isFalse);
      });
    });

    group('remove', () {
      test('removes tile from cache', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        cache.put(key, _createTestTile(0, 0));

        final removed = cache.remove(key);
        expect(removed, isNotNull);
        expect(cache.containsKey(key), isFalse);
        expect(cache.size, 0);
      });

      test('returns null for missing key', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);
        expect(cache.remove(key), isNull);
      });
    });

    group('clear', () {
      test('removes all tiles', () {
        for (var i = 0; i < 3; i++) {
          cache.put(
            TileKey(TileCoordinate(0, i), ZoomBucket.full),
            _createTestTile(0, i),
          );
        }

        cache.clear();
        expect(cache.size, 0);
        expect(cache.isEmpty, isTrue);
      });

      test('disposes cleared tiles', () {
        final tile = _createTestTile(0, 0);
        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile);

        cache.clear();
        expect(tile.isDisposed, isTrue);
      });
    });

    group('invalidateRange', () {
      test('invalidates tiles intersecting range', () {
        // Create tiles at different positions
        final tile00 = _createTestTile(0, 0); // cells 0-9, 0-9
        final tile01 = _createTestTile(0, 1); // cells 0-9, 10-19
        final tile10 = _createTestTile(1, 0); // cells 10-19, 0-9

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile00);
        cache.put(TileKey(TileCoordinate(0, 1), ZoomBucket.full), tile01);
        cache.put(TileKey(TileCoordinate(1, 0), ZoomBucket.full), tile10);

        // Invalidate range that only hits tile00
        cache.invalidateRange(CellRange(0, 0, 5, 5));

        expect(tile00.isValid, isFalse);
        expect(tile01.isValid, isTrue);
        expect(tile10.isValid, isTrue);
      });

      test('invalidates multiple intersecting tiles', () {
        final tile00 = _createTestTile(0, 0);
        final tile01 = _createTestTile(0, 1);

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile00);
        cache.put(TileKey(TileCoordinate(0, 1), ZoomBucket.full), tile01);

        // Range spans both tiles
        cache.invalidateRange(CellRange(0, 5, 5, 15));

        expect(tile00.isValid, isFalse);
        expect(tile01.isValid, isFalse);
      });
    });

    group('invalidateZoomBucket', () {
      test('invalidates tiles in specific zoom bucket', () {
        final tileA = _createTestTile(0, 0, zoomBucket: ZoomBucket.full);
        final tileB = _createTestTile(0, 0, zoomBucket: ZoomBucket.half);

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tileA);
        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.half), tileB);

        cache.invalidateZoomBucket(ZoomBucket.full);

        expect(tileA.isValid, isFalse);
        expect(tileB.isValid, isTrue);
      });
    });

    group('invalidateAll', () {
      test('invalidates all tiles', () {
        final tile1 = _createTestTile(0, 0);
        final tile2 = _createTestTile(0, 1);

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile1);
        cache.put(TileKey(TileCoordinate(0, 1), ZoomBucket.full), tile2);

        cache.invalidateAll();

        expect(tile1.isValid, isFalse);
        expect(tile2.isValid, isFalse);
      });
    });

    group('getValidTilesForZoom', () {
      test('returns only valid tiles for zoom bucket', () {
        final tile1 = _createTestTile(0, 0, zoomBucket: ZoomBucket.full);
        final tile2 = _createTestTile(0, 1, zoomBucket: ZoomBucket.full);
        final tile3 = _createTestTile(0, 0, zoomBucket: ZoomBucket.half);

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile1);
        cache.put(TileKey(TileCoordinate(0, 1), ZoomBucket.full), tile2);
        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.half), tile3);

        tile1.invalidate();

        final validTiles = cache.getValidTilesForZoom(ZoomBucket.full);
        expect(validTiles.length, 1);
        expect(validTiles.first, tile2);
      });
    });

    group('dispose', () {
      test('disposes all tiles', () {
        final tile1 = _createTestTile(0, 0);
        final tile2 = _createTestTile(0, 1);

        cache.put(TileKey(TileCoordinate(0, 0), ZoomBucket.full), tile1);
        cache.put(TileKey(TileCoordinate(0, 1), ZoomBucket.full), tile2);

        cache.dispose();

        expect(tile1.isDisposed, isTrue);
        expect(tile2.isDisposed, isTrue);
      });
    });
  });
}
