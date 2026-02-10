import 'package:flutter/painting.dart';

import '../../core/geometry/layout_solver.dart';
import '../../core/geometry/span_list.dart';
import '../../core/models/cell_range.dart';
import '../../core/models/cell_style.dart';
import '../../widgets/worksheet_theme.dart';

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
    this.borderColor = const Color(0xFFD0D0D0),
    this.borderWidth = 1.0,
    this.fontSize = 12.0,
    this.fontWeight = FontWeight.w500,
    this.fontFamily = CellStyle.defaultFontFamily,
  });

  /// Default header style.
  static const HeaderStyle defaultStyle = HeaderStyle();

  /// Dark mode header style (derived from Excel dark mode).
  static const HeaderStyle darkStyle = HeaderStyle(
    backgroundColor: Color(0xFF333333),
    selectedBackgroundColor: Color(0xFF565656),
    textColor: Color(0xFFD0D0D0),
    selectedTextColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF4A4A4A),
  );

  /// Creates a copy with optionally modified fields.
  HeaderStyle copyWith({
    Color? backgroundColor,
    Color? selectedBackgroundColor,
    Color? textColor,
    Color? selectedTextColor,
    Color? borderColor,
    double? borderWidth,
    double? fontSize,
    FontWeight? fontWeight,
    String? fontFamily,
  }) {
    return HeaderStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      selectedBackgroundColor:
          selectedBackgroundColor ?? this.selectedBackgroundColor,
      textColor: textColor ?? this.textColor,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HeaderStyle &&
        other.backgroundColor == backgroundColor &&
        other.selectedBackgroundColor == selectedBackgroundColor &&
        other.textColor == textColor &&
        other.selectedTextColor == selectedTextColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.fontFamily == fontFamily;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        selectedBackgroundColor,
        textColor,
        selectedTextColor,
        borderColor,
        borderWidth,
        fontSize,
        fontWeight,
        fontFamily,
      );
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

  /// Device pixel ratio for crisp 1-physical-pixel lines on Retina displays.
  final double? devicePixelRatio;

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
    this.devicePixelRatio,
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
    Size? viewportSize,
  }) {
    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    // Draw background (use viewport width when available for renderer
    // compatibility; some backends skip non-finite rects).
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        viewportSize?.width ?? 100000.0,
        scaledColumnHeaderHeight,
      ),
      _backgroundPaint,
    );

    final selectedStartCol = selectedRange?.startColumn;
    final selectedEndCol = selectedRange?.endColumn;

    // Two-pass rendering: backgrounds + text first, then borders on top.
    // This prevents a selected header's background from painting over
    // the adjacent header's border line.

    // Pass 1: backgrounds and text
    for (var col = visibleColumns.startIndex; col <= visibleColumns.endIndex; col++) {
      final left = layoutSolver.getColumnLeft(col);
      final width = layoutSolver.getColumnWidth(col);

      final screenLeft = (left - viewportOffset.dx) * zoom + scaledRowHeaderWidth;
      final screenWidth = width * zoom;

      final isSelected = selectedStartCol != null &&
          selectedEndCol != null &&
          col >= selectedStartCol &&
          col <= selectedEndCol;

      final cellRect = Rect.fromLTWH(
        screenLeft,
        0,
        screenWidth,
        scaledColumnHeaderHeight,
      );

      if (isSelected) {
        canvas.drawRect(cellRect, _selectedBackgroundPaint);
      }

      final letter = _columnIndexToLetter(col);
      _drawCenteredText(
        canvas,
        letter,
        cellRect,
        isSelected ? style.selectedTextColor : style.textColor,
        zoom: zoom,
      );
    }

    // Pass 2: borders (drawn last so they're never obscured)
    for (var col = visibleColumns.startIndex; col <= visibleColumns.endIndex; col++) {
      final colLeft = layoutSolver.getColumnLeft(col + 1);
      final tileSize = 256.0; // TileConfig default
      final tileBoundsLeft = (colLeft ~/ tileSize) * tileSize;
      final tileLocalX = (colLeft - tileBoundsLeft).roundToDouble() + 0.5;
      final borderX = (tileBoundsLeft - viewportOffset.dx + tileLocalX) * zoom + scaledRowHeaderWidth;
      canvas.drawLine(
        Offset(borderX, 0),
        Offset(borderX, scaledColumnHeaderHeight),
        _borderPaint,
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
    Size? viewportSize,
  }) {
    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = columnHeaderHeight * zoom;

    // Draw background (use viewport height when available for renderer
    // compatibility; some backends skip non-finite rects).
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        scaledRowHeaderWidth,
        viewportSize?.height ?? 100000.0,
      ),
      _backgroundPaint,
    );

    final selectedStartRow = selectedRange?.startRow;
    final selectedEndRow = selectedRange?.endRow;

    // Two-pass rendering: backgrounds + text first, then borders on top.
    // This prevents a selected header's background from painting over
    // the adjacent header's border line.

    // Pass 1: backgrounds and text
    for (var row = visibleRows.startIndex; row <= visibleRows.endIndex; row++) {
      final top = layoutSolver.getRowTop(row);
      final height = layoutSolver.getRowHeight(row);

      final screenTop = (top - viewportOffset.dy) * zoom + scaledColumnHeaderHeight;
      final screenHeight = height * zoom;

      final isSelected = selectedStartRow != null &&
          selectedEndRow != null &&
          row >= selectedStartRow &&
          row <= selectedEndRow;

      final cellRect = Rect.fromLTWH(
        0,
        screenTop,
        scaledRowHeaderWidth,
        screenHeight,
      );

      if (isSelected) {
        canvas.drawRect(cellRect, _selectedBackgroundPaint);
      }

      final rowNumber = (row + 1).toString();
      _drawCenteredText(
        canvas,
        rowNumber,
        cellRect,
        isSelected ? style.selectedTextColor : style.textColor,
        zoom: zoom,
      );
    }

    // Pass 2: borders (drawn last so they're never obscured)
    for (var row = visibleRows.startIndex; row <= visibleRows.endIndex; row++) {
      final rowTop = layoutSolver.getRowTop(row + 1);
      final tileSize = 256.0; // TileConfig default
      final tileBoundsTop = (rowTop ~/ tileSize) * tileSize;
      final tileLocalY = (rowTop - tileBoundsTop).roundToDouble() + 0.5;
      final borderY = (tileBoundsTop - viewportOffset.dy + tileLocalY) * zoom + scaledColumnHeaderHeight;
      canvas.drawLine(
        Offset(0, borderY),
        Offset(scaledRowHeaderWidth, borderY),
        _borderPaint,
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

    // Draw bottom border of column header (spans full width)
    // Position so the stroke's bottom edge aligns with the header/content
    // boundary, keeping the border entirely inside the header area.
    final halfStroke = _borderPaint.strokeWidth / 2;
    final borderY = scaledColumnHeaderHeight - halfStroke;
    canvas.drawLine(
      Offset(0, borderY),
      Offset(viewportSize.width, borderY),
      _borderPaint,
    );

    // Draw right border of row header (spans full height)
    // Position so the stroke's right edge aligns with the header/content
    // boundary, keeping the border entirely inside the header area.
    final borderX = scaledRowHeaderWidth - halfStroke;
    canvas.drawLine(
      Offset(borderX, 0),
      Offset(borderX, viewportSize.height),
      _borderPaint,
    );

    // During elastic overscroll past the start, draw the worksheet outer
    // boundary line across the full viewport (headers + content).
    if (scrollOffset.dy < 0) {
      final shiftedY = (scaledColumnHeaderHeight - scrollOffset.dy * zoom).roundToDouble() + 0.5;
      canvas.drawLine(
        Offset(0, shiftedY),
        Offset(viewportSize.width, shiftedY),
        _borderPaint,
      );
    }

    if (scrollOffset.dx < 0) {
      final shiftedX = (scaledRowHeaderWidth - scrollOffset.dx * zoom).roundToDouble() + 0.5;
      canvas.drawLine(
        Offset(shiftedX, 0),
        Offset(shiftedX, viewportSize.height),
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
      package: WorksheetThemeData.resolveFontPackage(style.fontFamily),
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
