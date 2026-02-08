import 'dart:ui';

import '../../core/models/cell_style.dart';

/// Shared utility for drawing border line styles on a Canvas.
///
/// Used by both [TilePainter] and [FrozenLayer] to avoid duplication.
/// All methods snap to half-pixel positions for crisp rendering.
class BorderPainter {
  const BorderPainter._();

  /// Draws a border edge between [start] and [end] using the given [paint],
  /// [lineStyle], and [width].
  static void drawBorderEdge(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    BorderLineStyle lineStyle,
    double width,
  ) {
    switch (lineStyle) {
      case BorderLineStyle.none:
        return;
      case BorderLineStyle.solid:
        canvas.drawLine(start, end, paint);
      case BorderLineStyle.dotted:
        _drawDashedLine(canvas, start, end, paint, width, width * 2);
      case BorderLineStyle.dashed:
        _drawDashedLine(canvas, start, end, paint, width * 4, width * 2);
      case BorderLineStyle.double:
        _drawDoubleLine(canvas, start, end, paint, width);
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLength = (dx * dx + dy * dy);
    if (totalLength == 0) return;
    final length = totalLength > 0
        ? (dx.abs() > dy.abs() ? dx.abs() : dy.abs())
        : 0.0;
    if (length == 0) return;

    final unitX = dx / length;
    final unitY = dy / length;
    final segmentLength = dashLength + gapLength;

    var distance = 0.0;
    while (distance < length) {
      final dashEnd = (distance + dashLength).clamp(0.0, length);
      canvas.drawLine(
        Offset(start.dx + unitX * distance, start.dy + unitY * distance),
        Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
        paint,
      );
      distance += segmentLength;
    }
  }

  static void _drawDoubleLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double width,
  ) {
    // Two parallel lines offset by width from center
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Perpendicular direction
    double perpX, perpY;
    if (dx.abs() > dy.abs()) {
      // Horizontal line → offset vertically
      perpX = 0;
      perpY = width;
    } else {
      // Vertical line → offset horizontally
      perpX = width;
      perpY = 0;
    }

    canvas.drawLine(
      Offset(start.dx - perpX, start.dy - perpY),
      Offset(end.dx - perpX, end.dy - perpY),
      paint,
    );
    canvas.drawLine(
      Offset(start.dx + perpX, start.dy + perpY),
      Offset(end.dx + perpX, end.dy + perpY),
      paint,
    );
  }
}
