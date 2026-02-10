import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/painters/selection_renderer.dart';

void main() {
  late LayoutSolver layoutSolver;
  late SelectionRenderer renderer;

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
    renderer = SelectionRenderer(layoutSolver: layoutSolver);
  });

  group('SelectionStyle', () {
    test('has sensible defaults', () {
      const style = SelectionStyle();

      expect(style.fillColor, const Color(0x220078D4));
      expect(style.borderColor, const Color(0xFF0078D4));
      expect(style.borderWidth, 1.0); // Thin like Excel
      expect(style.focusFillColor, const Color(0x00000000));
      expect(style.focusBorderColor, const Color(0xFF0078D4));
      expect(style.focusBorderWidth, 1.0); // Thin like Excel
    });

    test('defaultStyle matches default constructor', () {
      const style = SelectionStyle();
      expect(SelectionStyle.defaultStyle.fillColor, style.fillColor);
      expect(SelectionStyle.defaultStyle.borderColor, style.borderColor);
    });

    test('can be customized', () {
      const style = SelectionStyle(
        fillColor: Color(0x33FF0000),
        borderColor: Color(0xFFFF0000),
        borderWidth: 3.0,
      );

      expect(style.fillColor, const Color(0x33FF0000));
      expect(style.borderColor, const Color(0xFFFF0000));
      expect(style.borderWidth, 3.0);
    });

    test('has fill handle defaults', () {
      const style = SelectionStyle();
      expect(style.fillHandleColor, const Color(0xFF0078D4));
      expect(style.fillHandleSize, 6.0);
    });

    test('has fill preview defaults', () {
      const style = SelectionStyle();
      expect(style.fillPreviewColor, const Color(0x110078D4));
      expect(style.fillPreviewBorderColor, const Color(0x880078D4));
    });

    test('fill preview can be customized', () {
      const style = SelectionStyle(
        fillPreviewColor: Color(0x22FF0000),
        fillPreviewBorderColor: Color(0xAAFF0000),
      );
      expect(style.fillPreviewColor, const Color(0x22FF0000));
      expect(style.fillPreviewBorderColor, const Color(0xAAFF0000));
    });

    test('fill handle can be customized', () {
      const style = SelectionStyle(
        fillHandleColor: Color(0xFFFF0000),
        fillHandleSize: 8.0,
      );
      expect(style.fillHandleColor, const Color(0xFFFF0000));
      expect(style.fillHandleSize, 8.0);
    });

    test('copyWith returns modified copy', () {
      const original = SelectionStyle();
      final modified = original.copyWith(
        fillColor: const Color(0x33FF0000),
        borderWidth: 3.0,
      );

      expect(modified.fillColor, const Color(0x33FF0000));
      expect(modified.borderWidth, 3.0);
      // Unchanged fields
      expect(modified.borderColor, original.borderColor);
      expect(modified.focusBorderColor, original.focusBorderColor);
    });

    test('copyWith with no arguments returns equal copy', () {
      const original = SelectionStyle();
      final copy = original.copyWith();

      expect(copy, original);
    });

    test('equality: equal instances', () {
      const a = SelectionStyle();
      const b = SelectionStyle();

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('equality: different instances', () {
      const a = SelectionStyle();
      const b = SelectionStyle(fillColor: Color(0x33FF0000));

      expect(a, isNot(equals(b)));
    });
  });

  group('SelectionRenderer', () {
    test('creates with default style', () {
      final r = SelectionRenderer(layoutSolver: layoutSolver);
      expect(r.style, SelectionStyle.defaultStyle);
    });

    test('creates with custom style', () {
      const customStyle = SelectionStyle(borderWidth: 4.0);
      final r = SelectionRenderer(
        layoutSolver: layoutSolver,
        style: customStyle,
      );
      expect(r.style.borderWidth, 4.0);
    });

    group('paintSelection', () {
      test('paints without error at zoom 1.0', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSelection(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            range: const CellRange(0, 0, 2, 2),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints with focus cell', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSelection(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            range: const CellRange(0, 0, 2, 2),
            anchorCell: const CellCoordinate(1, 1),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints with viewport offset', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSelection(
            canvas: canvas,
            viewportOffset: const Offset(100, 50),
            zoom: 1.0,
            range: const CellRange(2, 1, 4, 3),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints with zoom', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSelection(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 2.0,
            range: const CellRange(0, 0, 1, 1),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('ignores focus cell outside range', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        // Focus cell (5, 5) is outside range (0,0)-(2,2)
        expect(
          () => renderer.paintSelection(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            range: const CellRange(0, 0, 2, 2),
            anchorCell: const CellCoordinate(5, 5),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });

    group('paintSingleCell', () {
      test('paints single cell at origin', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSingleCell(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            cell: const CellCoordinate(0, 0),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints single cell with offset and zoom', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintSingleCell(
            canvas: canvas,
            viewportOffset: const Offset(200, 100),
            zoom: 0.5,
            cell: const CellCoordinate(10, 5),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });

    group('paintRowHeaderHighlight', () {
      test('paints single row highlight', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintRowHeaderHighlight(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            startRow: 5,
            endRow: 5,
            headerWidth: 50.0,
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints multiple row highlight', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintRowHeaderHighlight(
            canvas: canvas,
            viewportOffset: const Offset(0, 24),
            zoom: 1.5,
            startRow: 2,
            endRow: 6,
            headerWidth: 50.0,
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });

    group('paintFillHandle', () {
      test('paints without error', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintFillHandle(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            range: const CellRange(0, 0, 2, 2),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints with zoom and offset', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintFillHandle(
            canvas: canvas,
            viewportOffset: const Offset(50, 25),
            zoom: 1.5,
            range: const CellRange(1, 1, 5, 5),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });

    group('paintFillPreview', () {
      test('paints without error', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintFillPreview(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            range: const CellRange(3, 0, 6, 2),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints with zoom and offset', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintFillPreview(
            canvas: canvas,
            viewportOffset: const Offset(100, 50),
            zoom: 2.0,
            range: const CellRange(0, 0, 3, 3),
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });

    group('paintColumnHeaderHighlight', () {
      test('paints single column highlight', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintColumnHeaderHighlight(
            canvas: canvas,
            viewportOffset: Offset.zero,
            zoom: 1.0,
            startColumn: 3,
            endColumn: 3,
            headerHeight: 30.0,
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });

      test('paints multiple column highlight', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => renderer.paintColumnHeaderHighlight(
            canvas: canvas,
            viewportOffset: const Offset(100, 0),
            zoom: 0.75,
            startColumn: 1,
            endColumn: 4,
            headerHeight: 30.0,
          ),
          returnsNormally,
        );

        recorder.endRecording();
      });
    });
  });
}
