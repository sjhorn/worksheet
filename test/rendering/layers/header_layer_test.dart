import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/rendering/layers/header_layer.dart';
import 'package:worksheet/src/rendering/layers/render_layer.dart';
import 'package:worksheet/src/rendering/painters/header_renderer.dart';

void main() {
  late LayoutSolver layoutSolver;
  late HeaderRenderer headerRenderer;
  late SelectionController selectionController;

  SpanRange getVisibleColumns(double scrollX, double viewportWidth, double zoom) {
    final startX = scrollX / zoom;
    final endX = startX + viewportWidth / zoom;
    return layoutSolver.getVisibleColumns(startX, endX - startX);
  }

  SpanRange getVisibleRows(double scrollY, double viewportHeight, double zoom) {
    final startY = scrollY / zoom;
    final endY = startY + viewportHeight / zoom;
    return layoutSolver.getVisibleRows(startY, endY - startY);
  }

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
    headerRenderer = HeaderRenderer(layoutSolver: layoutSolver);
    selectionController = SelectionController();
  });

  tearDown(() {
    selectionController.dispose();
  });

  group('HeaderLayer', () {
    test('creates with required parameters', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
      );

      expect(layer.enabled, isTrue);
      expect(layer.order, 200);

      layer.dispose();
    });

    test('can be created disabled', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        enabled: false,
      );

      expect(layer.enabled, isFalse);

      layer.dispose();
    });

    test('calls onNeedsPaint when selection changes', () {
      var paintCount = 0;

      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        selectionController: selectionController,
        onNeedsPaint: () => paintCount++,
      );

      expect(paintCount, 0);

      selectionController.selectCell(const CellCoordinate(0, 0));
      expect(paintCount, 1);

      selectionController.selectRow(5, columnCount: 26);
      expect(paintCount, 2);

      layer.dispose();
    });

    test('paints headers without selection', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      expect(() => layer.paint(context), returnsNormally);

      recorder.endRecording();
      layer.dispose();
    });

    test('paints headers with selection', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        selectionController: selectionController,
      );

      selectionController.selectCell(const CellCoordinate(5, 3));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      expect(() => layer.paint(context), returnsNormally);

      recorder.endRecording();
      layer.dispose();
    });

    test('skips painting when disabled', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        enabled: false,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      expect(() => layer.paint(context), returnsNormally);

      recorder.endRecording();
      layer.dispose();
    });

    test('paints with viewport offset and zoom', () {
      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        selectionController: selectionController,
      );

      selectionController.selectCell(const CellCoordinate(10, 5));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: const Offset(200, 100),
        zoom: 1.5,
      );

      expect(() => layer.paint(context), returnsNormally);

      recorder.endRecording();
      layer.dispose();
    });

    test('stops listening on dispose', () {
      var paintCount = 0;

      final layer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
        selectionController: selectionController,
        onNeedsPaint: () => paintCount++,
      );

      selectionController.selectCell(const CellCoordinate(0, 0));
      expect(paintCount, 1);

      layer.dispose();

      // After dispose, selection changes should not trigger onNeedsPaint
      selectionController.selectCell(const CellCoordinate(1, 1));
      expect(paintCount, 1); // Still 1, not 2
    });

    test('order is above selection layer', () {
      final selectionLayer = _TestSelectionLayer();
      final headerLayer = HeaderLayer(
        renderer: headerRenderer,
        getVisibleColumns: getVisibleColumns,
        getVisibleRows: getVisibleRows,
      );

      expect(headerLayer.order, greaterThan(selectionLayer.order));

      headerLayer.dispose();
    });
  });
}

// Simple mock selection layer for order comparison
class _TestSelectionLayer extends RenderLayer {
  @override
  int get order => 100; // Same as SelectionLayer

  @override
  void paint(LayerPaintContext context) {}
}
