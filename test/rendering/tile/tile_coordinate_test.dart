import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';

void main() {
  group('TileCoordinate', () {
    group('construction', () {
      test('creates with row and column', () {
        final coord = TileCoordinate(2, 3);
        expect(coord.row, 2);
        expect(coord.column, 3);
      });

      test('allows zero indices', () {
        final coord = TileCoordinate(0, 0);
        expect(coord.row, 0);
        expect(coord.column, 0);
      });

      test('throws for negative row', () {
        expect(() => TileCoordinate(-1, 0), throwsAssertionError);
      });

      test('throws for negative column', () {
        expect(() => TileCoordinate(0, -1), throwsAssertionError);
      });
    });

    group('fromPixelPosition', () {
      test('calculates tile at origin', () {
        final coord = TileCoordinate.fromPixelPosition(
          x: 0,
          y: 0,
          tileWidth: 256,
          tileHeight: 256,
        );
        expect(coord.row, 0);
        expect(coord.column, 0);
      });

      test('calculates tile for position within first tile', () {
        final coord = TileCoordinate.fromPixelPosition(
          x: 100,
          y: 150,
          tileWidth: 256,
          tileHeight: 256,
        );
        expect(coord.row, 0);
        expect(coord.column, 0);
      });

      test('calculates tile at tile boundary', () {
        final coord = TileCoordinate.fromPixelPosition(
          x: 256,
          y: 256,
          tileWidth: 256,
          tileHeight: 256,
        );
        expect(coord.row, 1);
        expect(coord.column, 1);
      });

      test('calculates tile for arbitrary position', () {
        final coord = TileCoordinate.fromPixelPosition(
          x: 600,
          y: 800,
          tileWidth: 256,
          tileHeight: 256,
        );
        // 600 / 256 = 2.34 -> column 2
        // 800 / 256 = 3.125 -> row 3
        expect(coord.column, 2);
        expect(coord.row, 3);
      });

      test('handles custom tile sizes', () {
        final coord = TileCoordinate.fromPixelPosition(
          x: 500,
          y: 300,
          tileWidth: 100,
          tileHeight: 50,
        );
        expect(coord.column, 5); // 500 / 100
        expect(coord.row, 6); // 300 / 50
      });
    });

    group('pixelBounds', () {
      test('returns bounds for tile at origin', () {
        final coord = TileCoordinate(0, 0);
        final bounds = coord.pixelBounds(tileWidth: 256, tileHeight: 256);

        expect(bounds.left, 0);
        expect(bounds.top, 0);
        expect(bounds.width, 256);
        expect(bounds.height, 256);
      });

      test('returns bounds for offset tile', () {
        final coord = TileCoordinate(2, 3);
        final bounds = coord.pixelBounds(tileWidth: 256, tileHeight: 256);

        expect(bounds.left, 768); // 3 * 256
        expect(bounds.top, 512); // 2 * 256
        expect(bounds.width, 256);
        expect(bounds.height, 256);
      });

      test('handles custom tile sizes', () {
        final coord = TileCoordinate(1, 2);
        final bounds = coord.pixelBounds(tileWidth: 100, tileHeight: 50);

        expect(bounds.left, 200); // 2 * 100
        expect(bounds.top, 50); // 1 * 50
        expect(bounds.width, 100);
        expect(bounds.height, 50);
      });
    });

    group('offset', () {
      test('returns offset tile coordinate', () {
        final coord = TileCoordinate(5, 5);
        final offset = coord.offset(2, 3);

        expect(offset.row, 7);
        expect(offset.column, 8);
      });

      test('clamps negative results to zero', () {
        final coord = TileCoordinate(2, 3);
        final offset = coord.offset(-10, -10);

        expect(offset.row, 0);
        expect(offset.column, 0);
      });
    });

    group('equality', () {
      test('equal coordinates are equal', () {
        final a = TileCoordinate(2, 3);
        final b = TileCoordinate(2, 3);
        expect(a, b);
        expect(a == b, isTrue);
      });

      test('different coordinates are not equal', () {
        final a = TileCoordinate(2, 3);
        final b = TileCoordinate(2, 4);
        expect(a == b, isFalse);
      });
    });

    group('hashCode', () {
      test('equal coordinates have same hashCode', () {
        final a = TileCoordinate(2, 3);
        final b = TileCoordinate(2, 3);
        expect(a.hashCode, b.hashCode);
      });

      test('can be used as map key', () {
        final map = <TileCoordinate, String>{};
        map[TileCoordinate(2, 3)] = 'test';
        expect(map[TileCoordinate(2, 3)], 'test');
      });

      test('can be used in set', () {
        final set = <TileCoordinate>{};
        set.add(TileCoordinate(2, 3));
        set.add(TileCoordinate(2, 3));
        expect(set.length, 1);
      });
    });

    group('toString', () {
      test('returns readable string', () {
        expect(TileCoordinate(2, 3).toString(), 'TileCoordinate(row: 2, col: 3)');
      });
    });

    group('getTilesInRange', () {
      test('returns tiles covering pixel range', () {
        final tiles = TileCoordinate.getTilesInRange(
          startX: 0,
          startY: 0,
          endX: 512,
          endY: 512,
          tileWidth: 256,
          tileHeight: 256,
        );

        expect(tiles.length, 4); // 2x2 grid
        expect(tiles, contains(TileCoordinate(0, 0)));
        expect(tiles, contains(TileCoordinate(0, 1)));
        expect(tiles, contains(TileCoordinate(1, 0)));
        expect(tiles, contains(TileCoordinate(1, 1)));
      });

      test('returns tiles for partial coverage', () {
        final tiles = TileCoordinate.getTilesInRange(
          startX: 100,
          startY: 100,
          endX: 300,
          endY: 300,
          tileWidth: 256,
          tileHeight: 256,
        );

        // Covers parts of tiles (0,0) and (1,1)
        expect(tiles.length, 4);
      });

      test('returns single tile for small range', () {
        final tiles = TileCoordinate.getTilesInRange(
          startX: 10,
          startY: 10,
          endX: 50,
          endY: 50,
          tileWidth: 256,
          tileHeight: 256,
        );

        expect(tiles.length, 1);
        expect(tiles.first, TileCoordinate(0, 0));
      });
    });
  });
}
