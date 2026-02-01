import 'dart:ui';

import '../../core/geometry/layout_solver.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import 'hit_test_result.dart';

/// Resolves screen coordinates to worksheet elements.
///
/// Handles conversion between screen space and worksheet space,
/// accounting for headers, scroll offset, and zoom level.
class WorksheetHitTester {
  /// The layout solver for position calculations.
  final LayoutSolver layoutSolver;

  /// Width of the row header area.
  final double headerWidth;

  /// Height of the column header area.
  final double headerHeight;

  /// Creates a hit tester.
  WorksheetHitTester({
    required this.layoutSolver,
    required this.headerWidth,
    required this.headerHeight,
  });

  /// Performs a hit test at the given screen position.
  ///
  /// [position] is in screen coordinates.
  /// [scrollOffset] is the current scroll position.
  /// [zoom] is the current zoom level.
  /// [resizeHandleTolerance] is the pixel tolerance for resize handle detection.
  WorksheetHitTestResult hitTest({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
    double resizeHandleTolerance = 4.0,
    CellRange? selectionRange,
    double fillHandleSize = 6.0,
  }) {
    // Check for negative positions (outside viewport)
    if (position.dx < 0 || position.dy < 0) {
      return const WorksheetHitTestResult.none();
    }

    // Scale header dimensions by zoom since headers scale with zoom
    final scaledHeaderWidth = headerWidth * zoom;
    final scaledHeaderHeight = headerHeight * zoom;

    final inRowHeader = position.dx < scaledHeaderWidth;
    final inColumnHeader = position.dy < scaledHeaderHeight;

    // Corner area - neither header nor cell
    if (inRowHeader && inColumnHeader) {
      return const WorksheetHitTestResult.none();
    }

    // Convert position to worksheet coordinates
    final worksheetPos = screenToWorksheet(
      screenPosition: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    // Row header area
    if (inRowHeader) {
      final row = layoutSolver.getRowAt(worksheetPos.dy);
      if (row < 0) return const WorksheetHitTestResult.none();

      // Check for resize handle (near row boundary)
      final rowBottom = layoutSolver.getRowEnd(row);
      final distanceToBottom = (worksheetPos.dy - rowBottom).abs() * zoom;
      if (distanceToBottom <= resizeHandleTolerance) {
        return WorksheetHitTestResult.rowResizeHandle(row);
      }

      return WorksheetHitTestResult.rowHeader(row);
    }

    // Column header area
    if (inColumnHeader) {
      final col = layoutSolver.getColumnAt(worksheetPos.dx);
      if (col < 0) return const WorksheetHitTestResult.none();

      // Check for resize handle (near column boundary)
      final colRight = layoutSolver.getColumnEnd(col);
      final distanceToRight = (worksheetPos.dx - colRight).abs() * zoom;
      if (distanceToRight <= resizeHandleTolerance) {
        return WorksheetHitTestResult.columnResizeHandle(col);
      }

      return WorksheetHitTestResult.columnHeader(col);
    }

    // Cell area
    final row = layoutSolver.getRowAt(worksheetPos.dy);
    final col = layoutSolver.getColumnAt(worksheetPos.dx);

    if (row < 0 || col < 0) {
      return const WorksheetHitTestResult.none();
    }

    // Fill handle detection: check proximity to bottom-right corner of selection
    if (selectionRange != null) {
      final selBottom = layoutSolver.getRowEnd(selectionRange.endRow);
      final selRight = layoutSolver.getColumnEnd(selectionRange.endColumn);

      // Convert selection corner to screen coordinates
      final screenCorner = worksheetToScreen(
        worksheetPosition: Offset(selRight, selBottom),
        scrollOffset: scrollOffset,
        zoom: zoom,
      );

      final tolerance = fillHandleSize / 2 + 2;
      if ((position.dx - screenCorner.dx).abs() <= tolerance &&
          (position.dy - screenCorner.dy).abs() <= tolerance) {
        return WorksheetHitTestResult.fillHandle(CellCoordinate(row, col));
      }
    }

    return WorksheetHitTestResult.cell(CellCoordinate(row, col));
  }

  /// Returns the cell at the given screen position, or null if not over a cell.
  CellCoordinate? hitTestCell({
    required Offset position,
    required Offset scrollOffset,
    required double zoom,
  }) {
    final result = hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );
    return result.cell;
  }

  /// Converts a screen position to worksheet coordinates.
  ///
  /// Accounts for headers, scroll offset, and zoom.
  Offset screenToWorksheet({
    required Offset screenPosition,
    required Offset scrollOffset,
    required double zoom,
  }) {
    // Remove header offset (scaled by zoom since headers scale with zoom)
    final scaledHeaderWidth = headerWidth * zoom;
    final scaledHeaderHeight = headerHeight * zoom;
    final viewportX = screenPosition.dx - scaledHeaderWidth;
    final viewportY = screenPosition.dy - scaledHeaderHeight;

    // Convert to worksheet coordinates (accounting for zoom and scroll)
    // Scroll offset is in screen coordinates, convert to worksheet
    final worksheetScrollX = scrollOffset.dx / zoom;
    final worksheetScrollY = scrollOffset.dy / zoom;

    return Offset(
      viewportX / zoom + worksheetScrollX,
      viewportY / zoom + worksheetScrollY,
    );
  }

  /// Converts a worksheet position to screen coordinates.
  ///
  /// Accounts for headers, scroll offset, and zoom.
  Offset worksheetToScreen({
    required Offset worksheetPosition,
    required Offset scrollOffset,
    required double zoom,
  }) {
    // Convert scroll to worksheet coordinates
    final worksheetScrollX = scrollOffset.dx / zoom;
    final worksheetScrollY = scrollOffset.dy / zoom;

    // Convert worksheet to viewport (accounting for zoom and scroll)
    final viewportX = (worksheetPosition.dx - worksheetScrollX) * zoom;
    final viewportY = (worksheetPosition.dy - worksheetScrollY) * zoom;

    // Add header offset (scaled by zoom since headers scale with zoom)
    final scaledHeaderWidth = headerWidth * zoom;
    final scaledHeaderHeight = headerHeight * zoom;
    return Offset(
      viewportX + scaledHeaderWidth,
      viewportY + scaledHeaderHeight,
    );
  }
}
