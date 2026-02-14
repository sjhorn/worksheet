import '../../core/models/cell_coordinate.dart';

/// The type of element hit during a hit test.
enum HitTestType {
  /// No element was hit (outside worksheet bounds).
  none,

  /// A worksheet cell was hit.
  cell,

  /// A row header was hit.
  rowHeader,

  /// A column header was hit.
  columnHeader,

  /// A row resize handle was hit.
  rowResizeHandle,

  /// A column resize handle was hit.
  columnResizeHandle,

  /// The fill handle (bottom-right corner of selection) was hit.
  fillHandle,

  /// The border of the current selection was hit.
  selectionBorder,

  /// A selection handle (touch drag circle) was hit.
  selectionHandle,

  /// The corner cell (intersection of row and column headers) was hit.
  cornerCell,
}

/// Result of a hit test on the worksheet.
///
/// Contains information about what element was hit at a given position.
class WorksheetHitTestResult {
  /// The type of element that was hit.
  final HitTestType type;

  /// The cell coordinate if a cell was hit, null otherwise.
  final CellCoordinate? cell;

  /// The header index if a header or resize handle was hit, null otherwise.
  final int? headerIndex;

  /// Creates a result indicating nothing was hit.
  const WorksheetHitTestResult.none()
      : type = HitTestType.none,
        cell = null,
        headerIndex = null;

  /// Creates a result indicating the corner cell was hit.
  const WorksheetHitTestResult.cornerCell()
      : type = HitTestType.cornerCell,
        cell = null,
        headerIndex = null;

  /// Creates a result indicating a cell was hit.
  WorksheetHitTestResult.cell(CellCoordinate coordinate)
      : type = HitTestType.cell,
        cell = coordinate,
        headerIndex = null;

  /// Creates a result indicating a row header was hit.
  const WorksheetHitTestResult.rowHeader(int rowIndex)
      : type = HitTestType.rowHeader,
        cell = null,
        headerIndex = rowIndex;

  /// Creates a result indicating a column header was hit.
  const WorksheetHitTestResult.columnHeader(int columnIndex)
      : type = HitTestType.columnHeader,
        cell = null,
        headerIndex = columnIndex;

  /// Creates a result indicating a row resize handle was hit.
  const WorksheetHitTestResult.rowResizeHandle(int rowIndex)
      : type = HitTestType.rowResizeHandle,
        cell = null,
        headerIndex = rowIndex;

  /// Creates a result indicating a column resize handle was hit.
  const WorksheetHitTestResult.columnResizeHandle(int columnIndex)
      : type = HitTestType.columnResizeHandle,
        cell = null,
        headerIndex = columnIndex;

  /// Creates a result indicating the fill handle was hit.
  WorksheetHitTestResult.fillHandle(CellCoordinate coordinate)
      : type = HitTestType.fillHandle,
        cell = coordinate,
        headerIndex = null;

  /// Creates a result indicating the selection border was hit.
  WorksheetHitTestResult.selectionBorder(CellCoordinate coordinate)
      : type = HitTestType.selectionBorder,
        cell = coordinate,
        headerIndex = null;

  /// Creates a result indicating a selection handle was hit.
  WorksheetHitTestResult.selectionHandle(CellCoordinate coordinate)
      : type = HitTestType.selectionHandle,
        cell = coordinate,
        headerIndex = null;

  /// Whether nothing was hit.
  bool get isNone => type == HitTestType.none;

  /// Whether a cell was hit.
  bool get isCell => type == HitTestType.cell;

  /// Whether a row header was hit.
  bool get isRowHeader => type == HitTestType.rowHeader;

  /// Whether a column header was hit.
  bool get isColumnHeader => type == HitTestType.columnHeader;

  /// Whether the corner cell was hit.
  bool get isCornerCell => type == HitTestType.cornerCell;

  /// Whether any header was hit.
  bool get isHeader => isRowHeader || isColumnHeader || isCornerCell;

  /// Whether a resize handle was hit.
  bool get isResizeHandle =>
      type == HitTestType.rowResizeHandle ||
      type == HitTestType.columnResizeHandle;

  /// Whether the fill handle was hit.
  bool get isFillHandle => type == HitTestType.fillHandle;

  /// Whether the selection border was hit.
  bool get isSelectionBorder => type == HitTestType.selectionBorder;

  /// Whether a selection handle was hit.
  bool get isSelectionHandle => type == HitTestType.selectionHandle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorksheetHitTestResult &&
        other.type == type &&
        other.cell == cell &&
        other.headerIndex == headerIndex;
  }

  @override
  int get hashCode => Object.hash(type, cell, headerIndex);

  @override
  String toString() {
    switch (type) {
      case HitTestType.none:
        return 'WorksheetHitTestResult.none';
      case HitTestType.cell:
        return 'WorksheetHitTestResult.cell($cell)';
      case HitTestType.rowHeader:
        return 'WorksheetHitTestResult.rowHeader($headerIndex)';
      case HitTestType.columnHeader:
        return 'WorksheetHitTestResult.columnHeader($headerIndex)';
      case HitTestType.rowResizeHandle:
        return 'WorksheetHitTestResult.rowResizeHandle($headerIndex)';
      case HitTestType.columnResizeHandle:
        return 'WorksheetHitTestResult.columnResizeHandle($headerIndex)';
      case HitTestType.fillHandle:
        return 'WorksheetHitTestResult.fillHandle($cell)';
      case HitTestType.selectionBorder:
        return 'WorksheetHitTestResult.selectionBorder($cell)';
      case HitTestType.selectionHandle:
        return 'WorksheetHitTestResult.selectionHandle($cell)';
      case HitTestType.cornerCell:
        return 'WorksheetHitTestResult.cornerCell';
    }
  }
}
