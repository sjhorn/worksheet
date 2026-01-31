import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/core/models/freeze_config.dart';
import 'package:worksheet/src/rendering/layers/frozen_layer.dart';
import 'package:worksheet/src/rendering/layers/render_layer.dart';

void main() {
  late SparseWorksheetData data;
  late LayoutSolver layoutSolver;
  late FrozenLayer frozenLayer;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);

    // Add some test data
    data.setCell(const CellCoordinate(0, 0), const CellValue.text('A1'));
    data.setCell(const CellCoordinate(0, 1), const CellValue.text('B1'));
    data.setCell(const CellCoordinate(1, 0), const CellValue.text('A2'));
    data.setCell(const CellCoordinate(1, 1), const CellValue.text('B2'));
    data.setCell(const CellCoordinate(2, 2), const CellValue.text('C3'));

    final rows = SpanList(defaultSize: 24.0, count: 100);
    final columns = SpanList(defaultSize: 80.0, count: 26);

    layoutSolver = LayoutSolver(
      rows: rows,
      columns: columns,
    );
  });

  tearDown(() {
    frozenLayer.dispose();
  });

  group('FrozenLayer', () {
    test('creates with required parameters', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 1, frozenColumns: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      expect(frozenLayer, isNotNull);
      expect(frozenLayer.order, 4);
    });

    test('is disabled when no frozen panes', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(),
        data: data,
        layoutSolver: layoutSolver,
      );

      expect(frozenLayer.enabled, isFalse);
    });

    test('is enabled when frozen rows exist', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 2),
        data: data,
        layoutSolver: layoutSolver,
      );

      expect(frozenLayer.enabled, isTrue);
    });

    test('is enabled when frozen columns exist', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenColumns: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      expect(frozenLayer.enabled, isTrue);
    });

    test('calculates frozen row height', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 2),
        data: data,
        layoutSolver: layoutSolver,
      );

      // 2 rows * 24.0 default height = 48.0
      expect(frozenLayer.frozenRowsHeight, 48.0);
    });

    test('calculates frozen column width', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenColumns: 2),
        data: data,
        layoutSolver: layoutSolver,
      );

      // 2 columns * 80.0 default width = 160.0
      expect(frozenLayer.frozenColumnsWidth, 160.0);
    });

    test('updates freeze config', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(),
        data: data,
        layoutSolver: layoutSolver,
      );

      expect(frozenLayer.enabled, isFalse);

      frozenLayer.updateFreezeConfig(
        const FreezeConfig(frozenRows: 1, frozenColumns: 1),
      );

      expect(frozenLayer.enabled, isTrue);
      expect(frozenLayer.frozenRowsHeight, 24.0);
      expect(frozenLayer.frozenColumnsWidth, 80.0);
    });

    test('paints without error', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 2, frozenColumns: 2),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: const Offset(100, 50),
        zoom: 1.0,
      );

      // Should not throw
      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });

    test('skips paint when disabled', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      // Should not throw even when disabled
      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });

    test('paints frozen rows only', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: const Offset(0, 100),
        zoom: 1.0,
      );

      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });

    test('paints frozen columns only', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenColumns: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: const Offset(200, 0),
        zoom: 1.0,
      );

      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });

    test('handles zoom', () {
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 1, frozenColumns: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 0.5,
      );

      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });

    test('marks needs paint', () {
      var paintRequested = false;
      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 1),
        data: data,
        layoutSolver: layoutSolver,
        onNeedsPaint: () => paintRequested = true,
      );

      frozenLayer.markNeedsPaint();

      expect(paintRequested, isTrue);
    });

    test('paints formatted cells without error', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(0.42));
      data.setFormat(const CellCoordinate(0, 0), CellFormat.percentage);
      data.setCell(const CellCoordinate(0, 1), CellValue.number(1234.56));
      data.setFormat(const CellCoordinate(0, 1), CellFormat.currency);

      frozenLayer = FrozenLayer(
        freezeConfig: const FreezeConfig(frozenRows: 1, frozenColumns: 1),
        data: data,
        layoutSolver: layoutSolver,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      expect(() => frozenLayer.paint(context), returnsNormally);

      recorder.endRecording();
    });
  });
}
