import 'package:flutter/painting.dart';

import '../../core/geometry/layout_solver.dart';
import '../../core/geometry/span_list.dart';
import '../../core/models/cell_range.dart';

/// Configuration for header rendering appearance.
class HeaderStyle {
  /// Background color for normal headers.
  final Color backgroundColor;

  /// Background color for selected/highlighted headers.
  final Color selectedBackgroundColor;

  /// Text color for normal headers.
  final Color textColor;

  /// Text color for selected headers.
  final Color selectedTextColor;

  /// Border color for header dividers.
  final Color borderColor;

  /// Border width for header dividers.
  final double borderWidth;

  /// Font size for header text.
  final double fontSize;

  /// Font weight for header text.
  final FontWeight fontWeight;

  /// Font family for header text.
  final String fontFamily;

  const HeaderStyle({
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.selectedBackgroundColor = const Color(0xFFE0E0E0),
    this.textColor = const Color(0xFF616161),
    this.selectedTextColor = const Color(0xFF212121),
    this.borderColor = const Color(0xFFD0D0D0), // Match cell gridlines
    this.borderWidth = 1.0,
    this.fontSize = 12.0,
    this.fontWeight = FontWeight.w500,
    this.fontFamily = 'Roboto',
  });

  /// Default header style.
  static const HeaderStyle defaultStyle = HeaderStyle();
}

/// Renders row and column headers for worksheets.
///
/// Supports:
/// - Row numbers (1, 2, 3, ...)
/// - Column letters (A, B, C, ... AA, AB, ...)
/// - Highlighting headers for selected rows/columns
class HeaderRenderer {
  /// The layout solver for cell positions.
  final LayoutSolver layoutSolver;

  /// The header style configuration.
  final HeaderStyle style;

  /// Width of the row header area.
  final double rowHeaderWidth;

  /// Height of the column header area.
  final double columnHeaderHeight;

  // Pre-allocated paint objects for performance
  late final Paint _backgroundPaint;
  late final Paint _selectedBackgroundPaint;
  late final Paint _borderPaint;

  /// Creates a header renderer.
  HeaderRenderer({
    required this.layoutSolver,
    this.style = HeaderStyle.defaultStyle,
    this.rowHeaderWidth = 50.0,
    this.columnHeaderHeight = 24.0,
  }) {
    _backgroundPaint = Paint()
      ..color = style.backgroundColor
      ..style = PaintingStyle.fill;

    _selectedBackgroundPaint = Paint()
      ..color = style.selectedBackgroundColor
      ..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // Crisp 1px lines
  }

  /// Paints the column headers (A, B, C, ...).
  ///
  /// [canvas] is the canvas to paint on.
  /// [viewportOffset] is the scroll offset (only x is used).
  /// [zoom] is the current zoom level.
  /// [visibleColumns] defines the range of visible columns.
  /// [selectedRange] optionally defines the current selection to highlight.
  void paintColumnHeaders({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required SpanRange visibleColumns,
    CellRange? selectedRange,
  }) {
    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        double.infinity,
        scaledColumnHeaderHeight,
      ),
      _backgroundPaint,
    );

    final selectedStartCol = selectedRange?.startColumn;
    final selectedEndCol = selectedRange?.endColumn;

    for (var col = visibleColumns.startIndex; col <= visibleColumns.endIndex; col++) {
      final left = layoutSolver.getColumnLeft(col);
      final width = layoutSolver.getColumnWidth(col);

      // Convert to screen coordinates (offset by scaled header width)
      final screenLeft = (left - viewportOffset.dx) * zoom + scaledRowHeaderWidth;
      final screenWidth = width * zoom;

      // Check if column is selected
      final isSelected = selectedStartCol != null &&
          selectedEndCol != null &&
          col >= selectedStartCol &&
          col <= selectedEndCol;

      // Draw background
      final cellRect = Rect.fromLTWH(
        screenLeft,
        0,
        screenWidth,
        scaledColumnHeaderHeight,
      );

      if (isSelected) {
        canvas.drawRect(cellRect, _selectedBackgroundPaint);
      }

      // Draw right border
      canvas.drawLine(
        Offset(screenLeft + screenWidth, 0),
        Offset(screenLeft + screenWidth, scaledColumnHeaderHeight),
        _borderPaint,
      );

      // Draw column letter
      final letter = _columnIndexToLetter(col);
      _drawCenteredText(
        canvas,
        letter,
        cellRect,
        isSelected ? style.selectedTextColor : style.textColor,
        zoom: zoom,
      );
    }
  }

  /// Paints the row headers (1, 2, 3, ...).
  ///
  /// [canvas] is the canvas to paint on.
  /// [viewportOffset] is the scroll offset (only y is used).
  /// [zoom] is the current zoom level.
  /// [visibleRows] defines the range of visible rows.
  /// [selectedRange] optionally defines the current selection to highlight.
  void paintRowHeaders({
    required Canvas canvas,
    required Offset viewportOffset,
    required double zoom,
    required SpanRange visibleRows,
    CellRange? selectedRange,
  }) {
    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        scaledRowHeaderWidth,
        double.infinity,
      ),
      _backgroundPaint,
    );

    final selectedStartRow = selectedRange?.startRow;
    final selectedEndRow = selectedRange?.endRow;

    for (var row = visibleRows.startIndex; row <= visibleRows.endIndex; row++) {
      final top = layoutSolver.getRowTop(row);
      final height = layoutSolver.getRowHeight(row);

      // Convert to screen coordinates (offset by scaled header height)
      final screenTop = (top - viewportOffset.dy) * zoom + scaledColumnHeaderHeight;
      final screenHeight = height * zoom;

      // Check if row is selected
      final isSelected = selectedStartRow != null &&
          selectedEndRow != null &&
          row >= selectedStartRow &&
          row <= selectedEndRow;

      // Draw background
      final cellRect = Rect.fromLTWH(
        0,
        screenTop,
        scaledRowHeaderWidth,
        screenHeight,
      );

      if (isSelected) {
        canvas.drawRect(cellRect, _selectedBackgroundPaint);
      }

      // Draw bottom border
      canvas.drawLine(
        Offset(0, screenTop + screenHeight),
        Offset(scaledRowHeaderWidth, screenTop + screenHeight),
        _borderPaint,
      );

      // Draw row number (1-based)
      final rowNumber = (row + 1).toString();
      _drawCenteredText(
        canvas,
        rowNumber,
        cellRect,
        isSelected ? style.selectedTextColor : style.textColor,
        zoom: zoom,
      );
    }
  }

  /// Paints the corner cell (intersection of row and column headers).
  void paintCornerCell(Canvas canvas, {double zoom = 1.0}) {
    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    final rect = Rect.fromLTWH(0, 0, scaledRowHeaderWidth, scaledColumnHeaderHeight);
    canvas.drawRect(rect, _backgroundPaint);
  }

  /// Paints the header border lines.
  ///
  /// This draws the bottom border of the column header and the right border
  /// of the row header. These are drawn separately (unclipped) so they span
  /// the full viewport width/height.
  ///
  /// During elastic overscroll (negative [scrollOffset]), the borders shift
  /// to stay aligned with the first row/column header cells.
  void paintHeaderBorders({
    required Canvas canvas,
    required Size viewportSize,
    required double zoom,
    Offset scrollOffset = Offset.zero,
  }) {
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    // Draw bottom border of column header (spans full width) — fixed
    canvas.drawLine(
      Offset(0, scaledColumnHeaderHeight - style.borderWidth / 2),
      Offset(viewportSize.width, scaledColumnHeaderHeight - style.borderWidth / 2),
      _borderPaint,
    );

    // Draw right border of row header (spans full height) — fixed
    canvas.drawLine(
      Offset(scaledRowHeaderWidth - style.borderWidth / 2, 0),
      Offset(scaledRowHeaderWidth - style.borderWidth / 2, viewportSize.height),
      _borderPaint,
    );

    // During elastic overscroll past the start, draw additional lines
    // only in the header region (the content area already has its own
    // gridlines). This avoids double-drawing which causes thicker lines.
    // Positions match the content gridline convention: line center at
    // the exact coordinate, no borderWidth/2 offset, no rounding — the
    // GPU handles pixel alignment the same way it does for tile gridlines.
    if (scrollOffset.dy < 0) {
      final shiftedY = scaledColumnHeaderHeight - scrollOffset.dy * zoom;
      canvas.drawLine(
        Offset(0, shiftedY),
        Offset(scaledRowHeaderWidth, shiftedY),
        _borderPaint,
      );
    }

    if (scrollOffset.dx < 0) {
      final shiftedX = scaledRowHeaderWidth - scrollOffset.dx * zoom;
      canvas.drawLine(
        Offset(shiftedX, 0),
        Offset(shiftedX, scaledColumnHeaderHeight),
        _borderPaint,
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Rect bounds,
    Color textColor, {
    double zoom = 1.0,
  }) {
    // Scale font size with zoom for readable headers at all zoom levels
    final scaledFontSize = style.fontSize * zoom;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: scaledFontSize,
      fontWeight: style.fontWeight,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center the text
    final dx = bounds.left + (bounds.width - textPainter.width) / 2;
    final dy = bounds.top + (bounds.height - textPainter.height) / 2;

    // Clip to bounds and paint
    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, Offset(dx, dy));
    canvas.restore();

    textPainter.dispose();
  }

  /// Converts a zero-based column index to Excel-style column letters.
  ///
  /// Examples:
  /// - 0 → "A"
  /// - 1 → "B"
  /// - 25 → "Z"
  /// - 26 → "AA"
  /// - 27 → "AB"
  String _columnIndexToLetter(int index) {
    var col = index + 1; // Convert to 1-based
    final letters = StringBuffer();

    while (col > 0) {
      col--;
      letters.write(String.fromCharCode(65 + (col % 26)));
      col ~/= 26;
    }

    return letters.toString().split('').reversed.join();
  }
}
