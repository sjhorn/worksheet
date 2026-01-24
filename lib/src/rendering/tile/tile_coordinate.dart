import 'dart:math' as math;
import 'dart:ui';

/// Immutable position in the tile grid.
///
/// Tiles are arranged in a grid where (0, 0) is the top-left tile.
/// Each tile covers a fixed pixel region of the worksheet.
class TileCoordinate {
  /// The row index in the tile grid (0-based).
  final int row;

  /// The column index in the tile grid (0-based).
  final int column;

  /// Creates a tile coordinate at the given [row] and [column].
  TileCoordinate(this.row, this.column)
      : assert(row >= 0, 'Row must be non-negative'),
        assert(column >= 0, 'Column must be non-negative');

  /// Creates a tile coordinate from a pixel position.
  ///
  /// Returns the tile that contains the given (x, y) position.
  factory TileCoordinate.fromPixelPosition({
    required double x,
    required double y,
    required double tileWidth,
    required double tileHeight,
  }) {
    final column = (x / tileWidth).floor();
    final row = (y / tileHeight).floor();
    return TileCoordinate(
      math.max(0, row),
      math.max(0, column),
    );
  }

  /// Returns the pixel bounds of this tile.
  Rect pixelBounds({
    required double tileWidth,
    required double tileHeight,
  }) {
    return Rect.fromLTWH(
      column * tileWidth,
      row * tileHeight,
      tileWidth,
      tileHeight,
    );
  }

  /// Returns a new coordinate offset by the given deltas.
  ///
  /// Results are clamped to non-negative values.
  TileCoordinate offset(int rowDelta, int columnDelta) {
    return TileCoordinate(
      math.max(0, row + rowDelta),
      math.max(0, column + columnDelta),
    );
  }

  /// Returns all tiles that cover the given pixel range.
  static List<TileCoordinate> getTilesInRange({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required double tileWidth,
    required double tileHeight,
  }) {
    final startTile = TileCoordinate.fromPixelPosition(
      x: startX,
      y: startY,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
    );

    final endTile = TileCoordinate.fromPixelPosition(
      x: endX - 0.001, // Subtract epsilon to handle exact boundaries
      y: endY - 0.001,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
    );

    final tiles = <TileCoordinate>[];
    for (var row = startTile.row; row <= endTile.row; row++) {
      for (var col = startTile.column; col <= endTile.column; col++) {
        tiles.add(TileCoordinate(row, col));
      }
    }

    return tiles;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TileCoordinate && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'TileCoordinate(row: $row, col: $column)';
}
