/// Configuration for frozen (pinned) rows and columns.
///
/// Frozen rows stay fixed at the top of the viewport while scrolling vertically.
/// Frozen columns stay fixed at the left of the viewport while scrolling horizontally.
class FreezeConfig {
  /// Number of rows frozen at the top.
  final int frozenRows;

  /// Number of columns frozen at the left.
  final int frozenColumns;

  /// No frozen panes.
  static const FreezeConfig none = FreezeConfig();

  /// Creates a freeze configuration.
  ///
  /// [frozenRows] defaults to 0 (no frozen rows).
  /// [frozenColumns] defaults to 0 (no frozen columns).
  const FreezeConfig({
    this.frozenRows = 0,
    this.frozenColumns = 0,
  });

  /// Whether any rows are frozen.
  bool get hasFrozenRows => frozenRows > 0;

  /// Whether any columns are frozen.
  bool get hasFrozenColumns => frozenColumns > 0;

  /// Whether any panes are frozen.
  bool get hasFrozenPanes => hasFrozenRows || hasFrozenColumns;

  /// Whether the given row index is frozen.
  bool isFrozenRow(int row) => row < frozenRows;

  /// Whether the given column index is frozen.
  bool isFrozenColumn(int column) => column < frozenColumns;

  /// Whether the cell at the given row and column is frozen.
  ///
  /// A cell is frozen if its row OR column is frozen.
  bool isFrozenCell(int row, int column) =>
      isFrozenRow(row) || isFrozenColumn(column);

  /// Creates a copy with the given fields replaced.
  FreezeConfig copyWith({
    int? frozenRows,
    int? frozenColumns,
  }) {
    return FreezeConfig(
      frozenRows: frozenRows ?? this.frozenRows,
      frozenColumns: frozenColumns ?? this.frozenColumns,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FreezeConfig &&
        other.frozenRows == frozenRows &&
        other.frozenColumns == frozenColumns;
  }

  @override
  int get hashCode => Object.hash(frozenRows, frozenColumns);

  @override
  String toString() =>
      'FreezeConfig(frozenRows: $frozenRows, frozenColumns: $frozenColumns)';
}
