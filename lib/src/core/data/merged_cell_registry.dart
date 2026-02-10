import 'package:flutter/foundation.dart';

import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';

/// An immutable merged cell region in a worksheet.
///
/// Wraps a [CellRange] and provides convenience accessors for the anchor
/// cell (top-left) and containment checks.
@immutable
class MergeRegion {
  /// The cell range covered by this merge.
  final CellRange range;

  /// Creates a merge region from a [CellRange].
  ///
  /// The range must contain at least 2 cells.
  const MergeRegion(this.range);

  /// The anchor (top-left) cell of the merge region.
  CellCoordinate get anchor => range.topLeft;

  /// Returns true if [cell] is within this merge region.
  bool contains(CellCoordinate cell) => range.contains(cell);

  /// Returns true if [cell] is the anchor of this merge region.
  bool isAnchor(CellCoordinate cell) => cell == anchor;

  /// The number of rows spanned by this merge.
  int get rowCount => range.rowCount;

  /// The number of columns spanned by this merge.
  int get columnCount => range.columnCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MergeRegion && other.range == range;
  }

  @override
  int get hashCode => range.hashCode;

  @override
  String toString() => 'MergeRegion($range)';
}

/// Registry managing merged cell regions in a worksheet.
///
/// Provides O(1) lookup from any cell coordinate to its merge region
/// via a reverse index. Validates that merges don't overlap and contain
/// at least 2 cells.
class MergedCellRegistry {
  /// Reverse index: every cell in a merge → its MergeRegion.
  final Map<CellCoordinate, MergeRegion> _cellToRegion = {};

  /// All registered merge regions (keyed by anchor for uniqueness).
  final Map<CellCoordinate, MergeRegion> _anchorToRegion = {};

  /// Returns the merge region containing [cell], or null if not merged.
  MergeRegion? getRegion(CellCoordinate cell) => _cellToRegion[cell];

  /// Returns true if [cell] is part of any merge region.
  bool isMerged(CellCoordinate cell) => _cellToRegion.containsKey(cell);

  /// Returns true if [cell] is the anchor of a merge region.
  bool isAnchor(CellCoordinate cell) {
    final region = _cellToRegion[cell];
    return region != null && region.isAnchor(cell);
  }

  /// Returns the anchor cell for [cell]'s merge region,
  /// or [cell] itself if not merged.
  CellCoordinate resolveAnchor(CellCoordinate cell) {
    final region = _cellToRegion[cell];
    return region?.anchor ?? cell;
  }

  /// All registered merge regions.
  Iterable<MergeRegion> get regions => _anchorToRegion.values;

  /// The number of registered merge regions.
  int get regionCount => _anchorToRegion.length;

  /// Whether the registry has no merge regions.
  bool get isEmpty => _anchorToRegion.isEmpty;

  /// Registers a new merge for [range].
  ///
  /// Throws [ArgumentError] if:
  /// - The range contains fewer than 2 cells
  /// - The range overlaps with an existing merge region
  void merge(CellRange range) {
    if (range.cellCount < 2) {
      throw ArgumentError('Merge range must contain at least 2 cells: $range');
    }

    // Check for overlaps
    for (final cell in range.cells) {
      if (_cellToRegion.containsKey(cell)) {
        throw ArgumentError(
          'Cannot merge $range: cell $cell is already in merge region '
          '${_cellToRegion[cell]}',
        );
      }
    }

    final region = MergeRegion(range);

    // Register in reverse index
    for (final cell in range.cells) {
      _cellToRegion[cell] = region;
    }

    _anchorToRegion[region.anchor] = region;
  }

  /// Removes the merge region containing [cell].
  ///
  /// If [cell] is not part of any merge, this is a no-op.
  void unmerge(CellCoordinate cell) {
    final region = _cellToRegion[cell];
    if (region == null) return;

    // Remove all cells from reverse index
    for (final c in region.range.cells) {
      _cellToRegion.remove(c);
    }

    _anchorToRegion.remove(region.anchor);
  }

  /// Returns all merge regions that intersect with [range].
  Iterable<MergeRegion> regionsInRange(CellRange range) {
    final found = <MergeRegion>{};
    for (final region in _anchorToRegion.values) {
      if (region.range.intersects(range)) {
        found.add(region);
      }
    }
    return found;
  }

  /// Removes all merge regions.
  void clear() {
    _cellToRegion.clear();
    _anchorToRegion.clear();
  }
}
