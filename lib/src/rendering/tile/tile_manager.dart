import 'dart:ui' as ui;

import '../../core/geometry/layout_solver.dart';
import '../../core/geometry/zoom_transformer.dart';
import '../../core/models/cell_range.dart';
import 'tile.dart';
import 'tile_cache.dart';
import 'tile_config.dart';
import 'tile_coordinate.dart';

/// Interface for rendering tile content.
abstract class TileRenderer {
  /// Renders the content for a tile.
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  });
}

/// Manages tile lifecycle, caching, and rendering.
///
/// TileManager coordinates between the layout system, tile cache, and
/// tile renderer to provide efficient tile-based rendering.
class TileManager {
  /// The layout solver for position calculations.
  final LayoutSolver layoutSolver;

  /// Tile configuration.
  final TileConfig config;

  /// The tile renderer.
  final TileRenderer renderer;

  /// The tile cache.
  late final TileCache _cache;

  /// Creates a tile manager.
  TileManager({
    required this.layoutSolver,
    required this.config,
    required this.renderer,
  }) : _cache = TileCache(maxTiles: config.maxCachedTiles);

  /// Returns all tiles needed to cover the viewport.
  ///
  /// Tiles are retrieved from cache if available and valid,
  /// otherwise they are rendered on demand.
  List<Tile> getTilesForViewport({
    required ui.Rect viewport,
    required ZoomBucket zoomBucket,
  }) {
    final coordinates = getTileCoordinatesForViewport(viewport: viewport);
    final tiles = <Tile>[];

    for (final coord in coordinates) {
      final key = TileKey(coord, zoomBucket);
      var tile = _cache.get(key);

      if (tile == null || !tile.isValid) {
        // Need to render this tile
        tile = _renderTile(coord, zoomBucket);
        _cache.put(key, tile);
      }

      tiles.add(tile);
    }

    return tiles;
  }

  /// Returns the tile coordinates that cover the given viewport.
  List<TileCoordinate> getTileCoordinatesForViewport({
    required ui.Rect viewport,
  }) {
    return TileCoordinate.getTilesInRange(
      startX: viewport.left,
      startY: viewport.top,
      endX: viewport.right,
      endY: viewport.bottom,
      tileWidth: config.tileWidth,
      tileHeight: config.tileHeight,
    );
  }

  /// Returns the cell range covered by a tile.
  CellRange getCellRangeForTile(TileCoordinate coord, ZoomBucket zoomBucket) {
    final bounds = coord.pixelBounds(
      tileWidth: config.tileWidth,
      tileHeight: config.tileHeight,
    );

    // Convert pixel bounds to cell range
    var startRow = layoutSolver.getRowAt(bounds.top);
    var startCol = layoutSolver.getColumnAt(bounds.left);
    var endRow = layoutSolver.getRowAt(bounds.bottom - 0.001);
    var endCol = layoutSolver.getColumnAt(bounds.right - 0.001);

    // Clamp to valid range: -1 means beyond content bounds
    // If start is beyond bounds, clamp to last valid index
    final maxRow = layoutSolver.rowCount - 1;
    final maxCol = layoutSolver.columnCount - 1;

    if (startRow < 0) startRow = 0;
    if (startCol < 0) startCol = 0;

    // If end is beyond bounds, clamp to max valid index
    if (endRow < 0) endRow = maxRow;
    if (endCol < 0) endCol = maxCol;

    // Ensure end >= start (tile might be partially or fully beyond content)
    if (endRow < startRow) endRow = startRow;
    if (endCol < startCol) endCol = startCol;

    // Final clamp to valid bounds
    startRow = startRow.clamp(0, maxRow);
    startCol = startCol.clamp(0, maxCol);
    endRow = endRow.clamp(0, maxRow);
    endCol = endCol.clamp(0, maxCol);

    return CellRange(startRow, startCol, endRow, endCol);
  }

  /// Gets a specific tile from the cache.
  Tile? getTile(TileKey key) {
    return _cache.get(key);
  }

  /// Invalidates tiles that intersect with the given cell range.
  void invalidateRange(CellRange range) {
    _cache.invalidateRange(range);
  }

  /// Invalidates all tiles in the given zoom bucket.
  void invalidateZoomBucket(ZoomBucket zoomBucket) {
    _cache.invalidateZoomBucket(zoomBucket);
  }

  /// Invalidates all cached tiles.
  void invalidateAll() {
    _cache.invalidateAll();
  }

  /// Clears all cached tiles.
  void clearCache() {
    _cache.clear();
  }

  /// Cleans up tiles that were evicted during the last getTilesForViewport call.
  /// Call this after painting completes to free GPU resources.
  void cleanup() {
    _cache.cleanup();
  }

  /// Disposes the tile manager and all cached tiles.
  void dispose() {
    _cache.dispose();
  }

  Tile _renderTile(TileCoordinate coord, ZoomBucket zoomBucket) {
    final bounds = coord.pixelBounds(
      tileWidth: config.tileWidth,
      tileHeight: config.tileHeight,
    );

    final cellRange = getCellRangeForTile(coord, zoomBucket);

    final picture = renderer.renderTile(
      coordinate: coord,
      bounds: bounds,
      cellRange: cellRange,
      zoomBucket: zoomBucket,
    );

    return Tile(
      coordinate: coord,
      zoomBucket: zoomBucket,
      picture: picture,
      cellRange: cellRange,
    );
  }
}
