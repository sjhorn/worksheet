import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/rendering/layers/render_layer.dart';
import 'package:worksheet/src/rendering/layers/selection_layer.dart';
import 'package:worksheet/src/rendering/painters/selection_renderer.dart';

void main() {
  late LayoutSolver layoutSolver;
  late SelectionRenderer renderer;
  late SelectionController selectionController;

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
    renderer = SelectionRenderer(layoutSolver: layoutSolver);
    selectionController = SelectionController();
  });

  tearDown(() {
    selectionController.dispose();
  });

  group('SelectionLayer', () {
    test('creates with required parameters', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
      );

      expect(layer.enabled, isTrue);
      expect(layer.order, 100);

      layer.dispose();
    });

    test('can be created disabled', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
        enabled: false,
      );

      expect(layer.enabled, isFalse);

      layer.dispose();
    });

    test('calls onNeedsPaint when selection changes', () {
      var paintCount = 0;

      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
        onNeedsPaint: () => paintCount++,
      );

      expect(paintCount, 0);

      selectionController.selectCell(const CellCoordinate(0, 0));
      expect(paintCount, 1);

      selectionController.extendSelection(const CellCoordinate(2, 2));
      expect(paintCount, 2);

      selectionController.clear();
      expect(paintCount, 3);

      layer.dispose();
    });

    test('paints nothing when no selection', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
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

    test('paints single cell selection', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
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

    test('paints range selection', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
      );

      selectionController.selectCell(const CellCoordinate(2, 2));
      selectionController.extendSelection(const CellCoordinate(5, 5));

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
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
        enabled: false,
      );

      selectionController.selectCell(const CellCoordinate(0, 0));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final context = LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      );

      // Should not throw even when disabled with selection
      expect(() => layer.paint(context), returnsNormally);

      recorder.endRecording();
      layer.dispose();
    });

    test('respects viewport offset and zoom', () {
      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
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

      final layer = SelectionLayer(
        selectionController: selectionController,
        renderer: renderer,
        onNeedsPaint: () => paintCount++,
      );

      selectionController.selectCell(const CellCoordinate(0, 0));
      expect(paintCount, 1);

      layer.dispose();

      // After dispose, selection changes should not trigger onNeedsPaint
      selectionController.selectCell(const CellCoordinate(1, 1));
      expect(paintCount, 1); // Still 1, not 2
    });
  });
}
