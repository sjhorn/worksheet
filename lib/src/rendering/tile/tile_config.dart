import '../../core/geometry/zoom_transformer.dart';

/// Configuration for the tile-based rendering system.
///
/// Controls tile dimensions, cache limits, and prefetch behavior.
class TileConfig {
  /// The size of each tile in pixels (both width and height).
  ///
  /// 256 is optimal for GPU texture sizes.
  final int tileSize;

  /// Maximum number of tiles to keep in the LRU cache.
  final int maxCachedTiles;

  /// Number of tile rings to prefetch beyond the visible area.
  ///
  /// A value of 1 means prefetch tiles that are one tile away from
  /// the visible viewport edge.
  final int prefetchRings;

  /// Creates a tile configuration.
  const TileConfig({
    this.tileSize = 256,
    this.maxCachedTiles = 100,
    this.prefetchRings = 1,
  })  : assert(tileSize > 0, 'Tile size must be positive'),
        assert(maxCachedTiles > 0, 'Max cached tiles must be positive'),
        assert(prefetchRings >= 0, 'Prefetch rings must be non-negative');

  /// The tile width in pixels.
  double get tileWidth => tileSize.toDouble();

  /// The tile height in pixels.
  double get tileHeight => tileSize.toDouble();

  /// Returns the screen tile size for the given zoom level.
  double getTileSizeForZoom(double zoom) {
    return tileSize * zoom;
  }

  /// Returns the worksheet tile coverage size for a zoom bucket.
  ///
  /// At lower zoom levels, each tile covers more worksheet area.
  /// This is used for level-of-detail tile selection.
  int getZoomBucketTileSize(ZoomBucket bucket) {
    switch (bucket) {
      case ZoomBucket.tenth:
        return tileSize * 10;
      case ZoomBucket.quarter:
        return tileSize * 4;
      case ZoomBucket.forty:
        return tileSize * 2; // Same as half since 40% is close to 50%
      case ZoomBucket.half:
        return tileSize * 2;
      case ZoomBucket.full:
        return tileSize;
      case ZoomBucket.twoX:
        return tileSize ~/ 2;
      case ZoomBucket.quadruple:
        return tileSize ~/ 4;
    }
  }

  /// Calculates the number of tiles needed to cover a dimension.
  int getTileCountForDimension(double dimension) {
    return (dimension / tileSize).ceil();
  }

  /// Creates a copy with optionally modified values.
  TileConfig copyWith({
    int? tileSize,
    int? maxCachedTiles,
    int? prefetchRings,
  }) {
    return TileConfig(
      tileSize: tileSize ?? this.tileSize,
      maxCachedTiles: maxCachedTiles ?? this.maxCachedTiles,
      prefetchRings: prefetchRings ?? this.prefetchRings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TileConfig &&
        other.tileSize == tileSize &&
        other.maxCachedTiles == maxCachedTiles &&
        other.prefetchRings == prefetchRings;
  }

  @override
  int get hashCode => Object.hash(tileSize, maxCachedTiles, prefetchRings);
}
