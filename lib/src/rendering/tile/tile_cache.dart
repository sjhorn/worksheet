import 'dart:collection';

import '../../core/geometry/zoom_transformer.dart';
import '../../core/models/cell_range.dart';
import 'tile.dart';

/// LRU cache for rendered tiles.
///
/// Manages tile storage with automatic eviction of least recently used
/// tiles when the cache exceeds its maximum size.
class TileCache {
  /// Maximum number of tiles to cache.
  final int maxTiles;

  /// LRU-ordered map of cached tiles.
  ///
  /// Uses LinkedHashMap with access order to maintain LRU ordering.
  final LinkedHashMap<TileKey, Tile> _tiles = LinkedHashMap<TileKey, Tile>();

  /// Creates a tile cache with the given maximum size.
  TileCache({required this.maxTiles})
      : assert(maxTiles > 0, 'Max tiles must be positive');

  /// The current number of cached tiles.
  int get size => _tiles.length;

  /// Whether the cache is empty.
  bool get isEmpty => _tiles.isEmpty;

  /// Gets a tile from the cache, updating its recency.
  ///
  /// Returns null if the tile is not cached.
  Tile? get(TileKey key) {
    final tile = _tiles.remove(key);
    if (tile != null) {
      // Re-insert to update recency (move to end)
      _tiles[key] = tile;
    }
    return tile;
  }

  /// Tiles that have been evicted but not yet disposed.
  /// These are kept until cleanup() is called to avoid disposing
  /// tiles that are still being used in the current paint cycle.
  final List<Tile> _pendingDisposal = [];

  /// Puts a tile in the cache.
  ///
  /// If the cache is full, evicts the least recently used tile.
  /// Evicted tiles are not disposed immediately - call cleanup() after
  /// the paint cycle completes to dispose them.
  void put(TileKey key, Tile tile) {
    // Remove existing tile with same key
    final existing = _tiles.remove(key);
    if (existing != null) {
      _pendingDisposal.add(existing);
    }

    // Evict oldest if at capacity (don't dispose yet)
    while (_tiles.length >= maxTiles) {
      _evictOldestWithoutDispose();
    }

    _tiles[key] = tile;
  }

  /// Disposes tiles that were evicted since the last cleanup.
  /// Call this after paint completes to free GPU resources.
  void cleanup() {
    for (final tile in _pendingDisposal) {
      tile.dispose();
    }
    _pendingDisposal.clear();
  }

  /// Returns true if the cache contains a tile with the given key.
  bool containsKey(TileKey key) {
    return _tiles.containsKey(key);
  }

  /// Removes a tile from the cache.
  ///
  /// Returns the removed tile, or null if not found.
  /// The caller is responsible for disposing the returned tile.
  Tile? remove(TileKey key) {
    return _tiles.remove(key);
  }

  /// Clears all tiles from the cache.
  void clear() {
    for (final tile in _tiles.values) {
      tile.dispose();
    }
    _tiles.clear();
  }

  /// Invalidates tiles that intersect with the given cell range.
  void invalidateRange(CellRange range) {
    for (final tile in _tiles.values) {
      if (tile.intersectsCellRange(range)) {
        tile.invalidate();
      }
    }
  }

  /// Invalidates all tiles in the given zoom bucket.
  void invalidateZoomBucket(ZoomBucket zoomBucket) {
    for (final entry in _tiles.entries) {
      if (entry.key.zoomBucket == zoomBucket) {
        entry.value.invalidate();
      }
    }
  }

  /// Invalidates all tiles.
  void invalidateAll() {
    for (final tile in _tiles.values) {
      tile.invalidate();
    }
  }

  /// Returns all valid tiles for the given zoom bucket.
  List<Tile> getValidTilesForZoom(ZoomBucket zoomBucket) {
    return _tiles.entries
        .where((e) => e.key.zoomBucket == zoomBucket && e.value.isValid)
        .map((e) => e.value)
        .toList();
  }

  /// Disposes all tiles and clears the cache.
  void dispose() {
    clear();
  }

  void _evictOldest() {
    if (_tiles.isNotEmpty) {
      final oldestKey = _tiles.keys.first;
      final oldestTile = _tiles.remove(oldestKey);
      oldestTile?.dispose();
    }
  }

  void _evictOldestWithoutDispose() {
    if (_tiles.isNotEmpty) {
      final oldestKey = _tiles.keys.first;
      final oldestTile = _tiles.remove(oldestKey);
      if (oldestTile != null) {
        _pendingDisposal.add(oldestTile);
      }
    }
  }
}
