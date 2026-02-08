import 'dart:ui' as ui;

import 'package:flutter/painting.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/rendering/painters/border_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BorderPainter', () {
    late ui.PictureRecorder recorder;
    late Canvas canvas;
    late Paint paint;

    setUp(() {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 256, 256));
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF000000)
        ..strokeWidth = 1.0;
    });

    tearDown(() {
      recorder.endRecording().dispose();
    });

    test('draws solid line without error', () {
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(0, 10.5),
        const Offset(100, 10.5),
        paint,
        BorderLineStyle.solid,
        1.0,
      );
    });

    test('draws dotted line without error', () {
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(0, 10.5),
        const Offset(100, 10.5),
        paint,
        BorderLineStyle.dotted,
        1.0,
      );
    });

    test('draws dashed line without error', () {
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(0, 10.5),
        const Offset(100, 10.5),
        paint,
        BorderLineStyle.dashed,
        1.0,
      );
    });

    test('draws double line without error', () {
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(0, 10.5),
        const Offset(100, 10.5),
        paint,
        BorderLineStyle.double,
        1.0,
      );
    });

    test('none lineStyle draws nothing', () {
      // Should not throw
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(0, 10.5),
        const Offset(100, 10.5),
        paint,
        BorderLineStyle.none,
        1.0,
      );
    });

    test('draws vertical lines without error', () {
      for (final style in BorderLineStyle.values) {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(10.5, 0),
          const Offset(10.5, 100),
          paint,
          style,
          1.0,
        );
      }
    });

    test('handles zero-length line', () {
      // Should not throw or loop infinitely
      BorderPainter.drawBorderEdge(
        canvas,
        const Offset(50, 50),
        const Offset(50, 50),
        paint,
        BorderLineStyle.dashed,
        1.0,
      );
    });

    test('handles various widths', () {
      for (final width in [0.5, 1.0, 2.0, 3.0]) {
        paint.strokeWidth = width;
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(200, 10.5),
          paint,
          BorderLineStyle.solid,
          width,
        );
      }
    });
  });
}
