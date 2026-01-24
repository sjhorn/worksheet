import 'dart:ui' as ui;

import '../../core/geometry/zoom_transformer.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import 'tile_coordinate.dart';

/// A rendered tile containing a cached Picture.
///
/// Tiles are pre-rendered sections of the worksheet that can be
/// efficiently composited during scrolling and zooming.
class Tile {
  /// The position of this tile in the tile grid.
  final TileCoordinate coordinate;

  /// The zoom bucket this tile was rendered for.
  final ZoomBucket zoomBucket;

  /// The rendered content of this tile.
  final ui.Picture picture;

  /// The range of cells contained in this tile.
  final CellRange cellRange;

  /// Whether this tile's content is still valid.
  bool _isValid = true;

  /// Whether this tile has been disposed.
  bool _isDisposed = false;

  /// Creates a tile with the given properties.
  Tile({
    required this.coordinate,
    required this.zoomBucket,
    required this.picture,
    required this.cellRange,
  });

  /// Whether this tile's content is still valid.
  ///
  /// A tile becomes invalid when the underlying data changes.
  bool get isValid => _isValid;

  /// Whether this tile has been disposed.
  bool get isDisposed => _isDisposed;

  /// Marks this tile as invalid.
  ///
  /// Invalid tiles should be re-rendered before use.
  void invalidate() {
    _isValid = false;
  }

  /// Disposes this tile's resources.
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      picture.dispose();
    }
  }

  /// Returns true if this tile contains the given cell.
  bool containsCell(int row, int column) {
    return cellRange.contains(CellCoordinate(row, column));
  }

  /// Returns true if this tile's cell range intersects with [range].
  bool intersectsCellRange(CellRange range) {
    return cellRange.intersects(range);
  }
}

/// A unique key for identifying tiles in the cache.
///
/// Combines tile coordinate and zoom bucket to create a unique identifier.
class TileKey {
  /// The tile coordinate.
  final TileCoordinate coordinate;

  /// The zoom bucket.
  final ZoomBucket zoomBucket;

  /// Creates a tile key.
  const TileKey(this.coordinate, this.zoomBucket);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TileKey &&
        other.coordinate == coordinate &&
        other.zoomBucket == zoomBucket;
  }

  @override
  int get hashCode => Object.hash(coordinate, zoomBucket);

  @override
  String toString() => 'TileKey($coordinate, $zoomBucket)';
}
