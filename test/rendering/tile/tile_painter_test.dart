import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet/src/rendering/tile/tile_painter.dart';

void main() {
  group('TilePainter', () {
    late SparseWorksheetData data;
    late LayoutSolver layoutSolver;
    late TilePainter painter;

    setUp(() {
      data = SparseWorksheetData(rowCount: 1000, columnCount: 100);
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 24.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      painter = TilePainter(
        data: data,
        layoutSolver: layoutSolver,
      );
    });

    tearDown(() {
      data.dispose();
    });

    test('implements TileRenderer interface', () {
      // TilePainter should implement the TileRenderer interface
      expect(painter, isNotNull);
    });

    test('renderTile returns a valid Picture', () {
      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 10, 2),
        zoomBucket: ZoomBucket.full,
      );

      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    test('renders cells with data', () {
      // Add some cell data
      data.setCell(CellCoordinate(0, 0), CellValue.text('Hello'));
      data.setCell(CellCoordinate(1, 1), CellValue.number(42));

      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 10, 2),
        zoomBucket: ZoomBucket.full,
      );

      // Picture should be created without errors
      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    test('applies cell styles', () {
      data.setCell(CellCoordinate(0, 0), CellValue.text('Styled'));
      data.setStyle(
        CellCoordinate(0, 0),
        const CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textColor: Color(0xFF0000FF),
          fontWeight: FontWeight.bold,
        ),
      );

      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 5, 2),
        zoomBucket: ZoomBucket.full,
      );

      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    group('Level of Detail (LOD)', () {
      test('renders text at full zoom', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Visible'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('skips text at tenth zoom bucket', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Hidden'));

        // At 10% zoom, text should be skipped for performance
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 50, 25),
          zoomBucket: ZoomBucket.tenth,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders simplified at quarter zoom', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Simplified'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 20, 10),
          zoomBucket: ZoomBucket.quarter,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('gridlines', () {
      test('renders gridlines', () {
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('can disable gridlines', () {
        final noGridPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          showGridlines: false,
        );

        final picture = noGridPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('cell value rendering', () {
      test('renders text values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Text'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders number values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(123.45));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders boolean values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.boolean(true));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders error values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.error('#DIV/0!'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('configuration', () {
      test('uses custom gridline color', () {
        final customPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          gridlineColor: const Color(0xFFFF0000),
        );

        final picture = customPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('uses custom background color', () {
        final customPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          backgroundColor: const Color(0xFFF0F0F0),
        );

        final picture = customPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('edge cases', () {
      test('handles empty cell range', () {
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 0, 0),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('handles tile outside data bounds', () {
        // Tile covers cells beyond the data
        final picture = painter.renderTile(
          coordinate: TileCoordinate(100, 100),
          bounds: const ui.Rect.fromLTWH(25600, 2400, 256, 256),
          cellRange: CellRange(100, 256, 110, 258),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });
  });
}
