import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/tile/tile.dart';
import 'package:worksheet/src/rendering/tile/tile_config.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet/src/rendering/tile/tile_manager.dart';

/// Test tile renderer that creates simple test pictures.
class TestTileRenderer implements TileRenderer {
  int renderCallCount = 0;
  final List<TileCoordinate> renderedCoordinates = [];

  @override
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  }) {
    renderCallCount++;
    renderedCoordinates.add(coordinate);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      bounds,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    return recorder.endRecording();
  }
}

void main() {
  group('TileManager', () {
    late LayoutSolver layoutSolver;
    late TileConfig config;
    late TestTileRenderer renderer;
    late TileManager manager;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      config = const TileConfig(tileSize: 256, maxCachedTiles: 10);
      renderer = TestTileRenderer();
      manager = TileManager(
        layoutSolver: layoutSolver,
        config: config,
        renderer: renderer,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    group('construction', () {
      test('creates with required dependencies', () {
        expect(manager.config, config);
      });
    });

    group('getTilesForViewport', () {
      test('returns tiles covering viewport', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );

        // 512x512 viewport with 256x256 tiles = 2x2 = 4 tiles
        expect(tiles.length, 4);
      });

      test('renders tiles on demand', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        expect(renderer.renderCallCount, 1);
      });

      test('caches rendered tiles', () {
        // First call renders
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);

        // Second call uses cache
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);
      });

      test('re-renders invalid tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);

        // Invalidate
        manager.invalidateAll();

        // Should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 2);
      });

      test('handles viewport larger than single tile', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 1024, 512),
          zoomBucket: ZoomBucket.full,
        );

        // 1024x512 with 256x256 tiles = 4x2 = 8 tiles
        expect(tiles.length, 8);
      });

      test('handles offset viewport', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(128, 128, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        // Viewport spans 4 tiles (partial coverage)
        expect(tiles.length, 4);
      });
    });

    group('getTileCoordinatesForViewport', () {
      test('returns tile coordinates for viewport', () {
        final coords = manager.getTileCoordinatesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
        );

        expect(coords.length, 4);
        expect(coords, contains(TileCoordinate(0, 0)));
        expect(coords, contains(TileCoordinate(0, 1)));
        expect(coords, contains(TileCoordinate(1, 0)));
        expect(coords, contains(TileCoordinate(1, 1)));
      });
    });

    group('invalidateRange', () {
      test('invalidates tiles covering range', () {
        // Pre-render tiles
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );
        final initialCount = renderer.renderCallCount;

        // Invalidate a cell range
        manager.invalidateRange(CellRange(0, 0, 5, 5));

        // Re-fetch - some tiles should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );

        expect(renderer.renderCallCount, greaterThan(initialCount));
      });
    });

    group('invalidateZoomBucket', () {
      test('invalidates tiles for specific zoom bucket', () {
        // Render tiles at full zoom
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        // Invalidate full zoom bucket
        manager.invalidateZoomBucket(ZoomBucket.full);

        // Re-fetch at full zoom should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('invalidateAll', () {
      test('invalidates all cached tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        manager.invalidateAll();

        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('clearCache', () {
      test('removes all cached tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        manager.clearCache();

        // Re-fetch should render new tiles
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('getCellRangeForTile', () {
      test('calculates cell range for tile', () {
        final range = manager.getCellRangeForTile(
          TileCoordinate(0, 0),
          ZoomBucket.full,
        );

        // Tile 0,0 at full zoom covers pixel 0-256, 0-256
        // With 100px columns and 25px rows:
        // Columns: 0-256 = cols 0-2 (3 columns)
        // Rows: 0-256 = rows 0-10 (11 rows)
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
      });

      test('calculates cell range for offset tile', () {
        final range = manager.getCellRangeForTile(
          TileCoordinate(1, 1),
          ZoomBucket.full,
        );

        // Tile 1,1 at full zoom covers pixel 256-512, 256-512
        expect(range.startRow, greaterThan(0));
        expect(range.startColumn, greaterThan(0));
      });
    });

    group('getTile', () {
      test('returns cached tile if valid', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);

        // Render tile
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        final tile = manager.getTile(key);
        expect(tile, isNotNull);
        expect(tile!.isValid, isTrue);
      });

      test('returns null for missing tile', () {
        final key = TileKey(TileCoordinate(100, 100), ZoomBucket.full);
        expect(manager.getTile(key), isNull);
      });
    });

    group('dispose', () {
      test('disposes cache', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        manager.dispose();

        // Accessing after dispose should still work (creates new tiles)
        // but internal state is cleared
      });
    });
  });
}
