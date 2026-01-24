import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet2/src/core/models/cell_range.dart';
import 'package:worksheet2/src/rendering/tile/tile.dart';
import 'package:worksheet2/src/rendering/tile/tile_coordinate.dart';

void main() {
  group('Tile', () {
    late ui.Picture testPicture;

    setUp(() {
      // Create a simple test picture
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 256, 256),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      testPicture = recorder.endRecording();
    });

    group('construction', () {
      test('creates tile with required properties', () {
        final tile = Tile(
          coordinate: TileCoordinate(1, 2),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.coordinate, TileCoordinate(1, 2));
        expect(tile.zoomBucket, ZoomBucket.full);
        expect(tile.picture, testPicture);
        expect(tile.cellRange, CellRange(0, 0, 10, 10));
      });

      test('has valid state by default', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 5, 5),
        );

        expect(tile.isValid, isTrue);
        expect(tile.isDisposed, isFalse);
      });
    });

    group('invalidate', () {
      test('marks tile as invalid', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 5, 5),
        );

        expect(tile.isValid, isTrue);
        tile.invalidate();
        expect(tile.isValid, isFalse);
      });
    });

    group('dispose', () {
      test('marks tile as disposed', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 5, 5),
        );

        expect(tile.isDisposed, isFalse);
        tile.dispose();
        expect(tile.isDisposed, isTrue);
      });

      test('disposes picture', () {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          ui.Paint(),
        );
        final picture = recorder.endRecording();

        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: picture,
          cellRange: CellRange(0, 0, 5, 5),
        );

        tile.dispose();
        // After dispose, trying to use the picture should fail
        // but we just verify the tile state here
        expect(tile.isDisposed, isTrue);
      });
    });

    group('containsCell', () {
      test('returns true for cell within range', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.containsCell(5, 5), isTrue);
        expect(tile.containsCell(0, 0), isTrue);
        expect(tile.containsCell(10, 10), isTrue);
      });

      test('returns false for cell outside range', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.containsCell(11, 5), isFalse);
        expect(tile.containsCell(5, 11), isFalse);
      });
    });

    group('intersectsCellRange', () {
      test('returns true for overlapping range', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.intersectsCellRange(CellRange(5, 5, 15, 15)), isTrue);
      });

      test('returns true for contained range', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.intersectsCellRange(CellRange(2, 2, 5, 5)), isTrue);
      });

      test('returns false for non-overlapping range', () {
        final tile = Tile(
          coordinate: TileCoordinate(0, 0),
          zoomBucket: ZoomBucket.full,
          picture: testPicture,
          cellRange: CellRange(0, 0, 10, 10),
        );

        expect(tile.intersectsCellRange(CellRange(20, 20, 30, 30)), isFalse);
      });
    });

    group('TileKey', () {
      test('creates key from coordinate and zoom bucket', () {
        final key = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        expect(key.coordinate, TileCoordinate(1, 2));
        expect(key.zoomBucket, ZoomBucket.full);
      });

      test('equal keys are equal', () {
        final a = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        final b = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        expect(a, b);
      });

      test('different coordinates create different keys', () {
        final a = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        final b = TileKey(TileCoordinate(1, 3), ZoomBucket.full);
        expect(a == b, isFalse);
      });

      test('different zoom buckets create different keys', () {
        final a = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        final b = TileKey(TileCoordinate(1, 2), ZoomBucket.half);
        expect(a == b, isFalse);
      });

      test('can be used as map key', () {
        final map = <TileKey, String>{};
        final key = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        map[key] = 'test';
        expect(map[TileKey(TileCoordinate(1, 2), ZoomBucket.full)], 'test');
      });

      test('toString returns readable format', () {
        final key = TileKey(TileCoordinate(1, 2), ZoomBucket.full);
        expect(key.toString(), contains('TileCoordinate'));
        expect(key.toString(), contains('full'));
      });
    });
  });
}
