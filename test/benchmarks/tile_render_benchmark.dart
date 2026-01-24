import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet2/src/core/geometry/layout_solver.dart';
import 'package:worksheet2/src/core/geometry/span_list.dart';
import 'package:worksheet2/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet2/src/core/models/cell_coordinate.dart';
import 'package:worksheet2/src/core/models/cell_range.dart';
import 'package:worksheet2/src/core/models/cell_value.dart';
import 'package:worksheet2/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet2/src/rendering/tile/tile_painter.dart';

/// Benchmark tests for tile rendering performance.
///
/// Target: Tile render time < 8ms (to maintain 60fps with overhead).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SparseWorksheetData data;
  late LayoutSolver layoutSolver;
  late TilePainter painter;

  setUp(() {
    // Create a worksheet with test data
    data = SparseWorksheetData(rowCount: 1000, columnCount: 100);

    // Populate with various cell types
    for (int row = 0; row < 100; row++) {
      for (int col = 0; col < 20; col++) {
        final value = switch ((row + col) % 4) {
          0 => CellValue.number(row * 100.0 + col),
          1 => CellValue.text('Cell $row,$col'),
          2 => const CellValue.boolean(true),
          _ => CellValue.formula('=A$row+B$col'),
        };
        data.setCell(CellCoordinate(row, col), value);
      }
    }

    final rows = SpanList(defaultSize: 24.0, count: 1000);
    final columns = SpanList(defaultSize: 80.0, count: 100);

    layoutSolver = LayoutSolver(rows: rows, columns: columns);

    painter = TilePainter(
      data: data,
      layoutSolver: layoutSolver,
    );
  });

  group('TileRenderBenchmark', () {
    test('renders tile in under 8ms', () {
      const tileSize = 256.0;
      const iterations = 100;
      final times = <int>[];

      // Warm up
      for (int i = 0; i < 10; i++) {
        _renderTile(painter, tileSize, 0, 0);
      }

      // Benchmark
      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        _renderTile(painter, tileSize, 0, 0);
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicroseconds = times.reduce((a, b) => a + b) / times.length;
      final avgMilliseconds = avgMicroseconds / 1000;
      final maxMicroseconds = times.reduce((a, b) => a > b ? a : b);
      final maxMilliseconds = maxMicroseconds / 1000;

      // ignore: avoid_print
      print('Tile render benchmark:');
      // ignore: avoid_print
      print('  Average: ${avgMilliseconds.toStringAsFixed(3)}ms');
      // ignore: avoid_print
      print('  Max: ${maxMilliseconds.toStringAsFixed(3)}ms');
      // ignore: avoid_print
      print('  Iterations: $iterations');

      // Target: under 8ms average
      expect(
        avgMilliseconds,
        lessThan(8.0),
        reason: 'Average tile render should be under 8ms',
      );
    });

    test('renders empty tile quickly', () {
      // Empty region of the worksheet
      final emptyData = SparseWorksheetData(rowCount: 1000, columnCount: 100);
      final emptyPainter = TilePainter(
        data: emptyData,
        layoutSolver: layoutSolver,
      );

      const iterations = 100;
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        _renderTile(emptyPainter, 256.0, 500, 50);
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicroseconds = times.reduce((a, b) => a + b) / times.length;
      final avgMilliseconds = avgMicroseconds / 1000;

      // ignore: avoid_print
      print('Empty tile render: ${avgMilliseconds.toStringAsFixed(3)}ms avg');

      // Empty tiles should be very fast
      expect(avgMilliseconds, lessThan(2.0));
    });

    test('renders at different zoom levels', () {
      const zooms = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0];
      const iterations = 50;

      for (final zoom in zooms) {
        final times = <int>[];
        final bucket = ZoomBucket.fromZoom(zoom);

        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();
          _renderTileAtZoom(painter, 256.0, 0, 0, bucket);
          stopwatch.stop();
          times.add(stopwatch.elapsedMicroseconds);
        }

        final avgMs = times.reduce((a, b) => a + b) / times.length / 1000;
        // ignore: avoid_print
        print('Zoom $zoom (${bucket.name}): ${avgMs.toStringAsFixed(3)}ms avg');

        // All zoom levels should render under 8ms
        expect(avgMs, lessThan(8.0));
      }
    });

    test('handles large cell range efficiently', () {
      // Render a tile that covers many cells
      final largeRows = SpanList(defaultSize: 16.0, count: 1000);
      final largeCols = SpanList(defaultSize: 40.0, count: 100);
      final largeLayoutSolver = LayoutSolver(rows: largeRows, columns: largeCols);

      final largePainter = TilePainter(
        data: data,
        layoutSolver: largeLayoutSolver,
      );

      const iterations = 50;
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        _renderTile(largePainter, 256.0, 0, 0);
        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMs = times.reduce((a, b) => a + b) / times.length / 1000;
      // ignore: avoid_print
      print('Large cell range: ${avgMs.toStringAsFixed(3)}ms avg');

      // Even with many cells, should stay under 16ms (2 frames budget)
      expect(avgMs, lessThan(16.0));
    });
  });
}

ui.Picture _renderTile(TilePainter painter, double tileSize, int x, int y) {
  return _renderTileAtZoom(painter, tileSize, x, y, ZoomBucket.full);
}

ui.Picture _renderTileAtZoom(
  TilePainter painter,
  double tileSize,
  int x,
  int y,
  ZoomBucket bucket,
) {
  final bounds = ui.Rect.fromLTWH(
    x * tileSize,
    y * tileSize,
    tileSize,
    tileSize,
  );

  // Calculate approximate cell range for the tile
  final startRow = (bounds.top / 24).floor();
  final endRow = (bounds.bottom / 24).ceil();
  final startCol = (bounds.left / 80).floor();
  final endCol = (bounds.right / 80).ceil();

  return painter.renderTile(
    coordinate: TileCoordinate(y, x), // TileCoordinate takes (row, column)
    bounds: bounds,
    cellRange: CellRange(startRow, startCol, endRow, endCol),
    zoomBucket: bucket,
  );
}
