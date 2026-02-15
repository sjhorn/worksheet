import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

/// Reproduces the outer-border logic from example/border.dart so we can
/// unit-test it against merged regions.
///
/// This is a copy of `_outerBorder()` from example/border.dart.  When the
/// example is fixed, this helper should be updated to match.
void applyOuterBorder(SparseWorksheetData data, CellRange range) {
  for (int row = range.startRow; row <= range.endRow; row++) {
    for (int col = range.startColumn; col <= range.endColumn; col++) {
      final coord = CellCoordinate(row, col);

      final region = data.mergedCells.getRegion(coord);
      if (region != null && !region.isAnchor(coord)) continue;

      // For merged anchors, use the merge region's extent to determine
      // which edges touch the selection perimeter.
      final int effectiveEndRow =
          region != null ? region.range.endRow : row;
      final int effectiveEndCol =
          region != null ? region.range.endColumn : col;

      final top = row == range.startRow
          ? const BorderStyle()
          : BorderStyle.none;
      final bottom = effectiveEndRow == range.endRow
          ? const BorderStyle()
          : BorderStyle.none;
      final left = col == range.startColumn
          ? const BorderStyle()
          : BorderStyle.none;
      final right = effectiveEndCol == range.endColumn
          ? const BorderStyle()
          : BorderStyle.none;

      final borders =
          CellBorders(top: top, right: right, bottom: bottom, left: left);
      final style = CellStyle(borders: borders);
      final current = data.getStyle(coord);
      final merged =
          current != null ? current.merge(style) : style;
      data.setStyle(coord, merged);
    }
  }
}

/// Reproduces the merge logic from example/border.dart — merges cells and
/// clears borders on non-anchor cells to avoid rendering artifacts.
void mergeAndClearBorders(SparseWorksheetData data, CellRange range) {
  data.mergeCells(range);

  // Clear borders on non-anchor cells
  final anchor = range.topLeft;
  data.batchUpdate((batch) {
    for (final coord in range.cells) {
      if (coord == anchor) continue;
      final style = data.getStyle(coord);
      if (style != null && style.borders != null && !style.borders!.isNone) {
        batch.setStyle(coord, CellStyle(
          backgroundColor: style.backgroundColor,
          textAlignment: style.textAlignment,
          verticalAlignment: style.verticalAlignment,
          wrapText: style.wrapText,
        ));
      }
    }
  });
}

void main() {
  late SparseWorksheetData data;

  setUp(() {
    data = SparseWorksheetData(rowCount: 10, columnCount: 10);
  });

  tearDown(() => data.dispose());

  group('outer border on merged cells', () {

    test('3x3 merge gets borders on all four sides of the anchor', () {
      // Merge a 3x3 region: rows 0-2, cols 0-2
      const mergeRange = CellRange(0, 0, 2, 2);
      data.mergeCells(mergeRange);

      // Apply outer border to the same 3x3 selection
      applyOuterBorder(data, mergeRange);

      // The anchor (0,0) should have borders on ALL four sides,
      // because the merge region spans the entire selection.
      final anchorBorders =
          data.getStyle(const CellCoordinate(0, 0))?.borders;
      expect(anchorBorders, isNotNull, reason: 'anchor should have borders');
      expect(anchorBorders!.top.isNone, isFalse, reason: 'top border');
      expect(anchorBorders.bottom.isNone, isFalse, reason: 'bottom border');
      expect(anchorBorders.left.isNone, isFalse, reason: 'left border');
      expect(anchorBorders.right.isNone, isFalse, reason: 'right border');
    });

    test('merge on bottom-right of selection gets bottom and right', () {
      // Cells (0,0) normal; (0,1)-(1,2) merged 2x2
      const mergeRange = CellRange(0, 1, 1, 2);
      data.mergeCells(mergeRange);

      const selection = CellRange(0, 0, 1, 2);
      applyOuterBorder(data, selection);

      // Anchor of the merge at (0,1) should get top + right borders
      // (bottom edge of merge is row 1 = selection endRow,
      //  right edge of merge is col 2 = selection endColumn)
      final anchorBorders =
          data.getStyle(const CellCoordinate(0, 1))?.borders;
      expect(anchorBorders, isNotNull);
      expect(anchorBorders!.top.isNone, isFalse, reason: 'top border');
      expect(anchorBorders.right.isNone, isFalse, reason: 'right border');
      expect(anchorBorders.bottom.isNone, isFalse, reason: 'bottom border');
    });

    test('unmerged cells still get correct outer borders', () {
      const selection = CellRange(0, 0, 2, 2);
      applyOuterBorder(data, selection);

      // Top-left corner: top + left
      final tl = data.getStyle(const CellCoordinate(0, 0))?.borders;
      expect(tl!.top.isNone, isFalse);
      expect(tl.left.isNone, isFalse);
      expect(tl.bottom.isNone, isTrue);
      expect(tl.right.isNone, isTrue);

      // Bottom-right corner: bottom + right
      final br = data.getStyle(const CellCoordinate(2, 2))?.borders;
      expect(br!.bottom.isNone, isFalse);
      expect(br.right.isNone, isFalse);
      expect(br.top.isNone, isTrue);
      expect(br.left.isNone, isTrue);
    });
  });

  group('merge clears borders on non-anchor cells', () {
    test('merging cells with existing borders clears non-anchor borders', () {
      // Apply borders to a 3x3 region first
      const range = CellRange(0, 0, 2, 2);
      for (final coord in range.cells) {
        data.setStyle(
          coord,
          const CellStyle(borders: CellBorders.all(BorderStyle())),
        );
      }

      // Verify borders are set before merge
      expect(
        data.getStyle(const CellCoordinate(1, 1))?.borders?.isNone,
        isFalse,
        reason: 'borders should exist before merge',
      );

      // Now merge — non-anchor cells should have borders cleared
      mergeAndClearBorders(data, range);

      // Anchor keeps its borders
      final anchorBorders =
          data.getStyle(const CellCoordinate(0, 0))?.borders;
      expect(anchorBorders?.isNone, isFalse,
          reason: 'anchor should keep borders');

      // Non-anchor cells should have no borders
      for (final coord in range.cells) {
        if (coord == range.topLeft) continue;
        final style = data.getStyle(coord);
        final hasBorders =
            style != null && style.borders != null && !style.borders!.isNone;
        expect(hasBorders, isFalse,
            reason: 'non-anchor $coord should have no borders');
      }
    });

    test('change event range covers full merge extent for invalidation', () {
      // This verifies the data needed by the worksheet widget's
      // _onDataChanged to expand invalidation to the full merge.
      const mergeRange = CellRange(0, 0, 2, 2);
      data.mergeCells(mergeRange);

      // When the anchor's style changes, getRegion should return the
      // full merge so the widget can invalidate all overlapping tiles.
      final region =
          data.mergedCells.getRegion(const CellCoordinate(0, 0));
      expect(region, isNotNull);
      expect(region!.range, mergeRange);

      // For batch updates, regionsInRange should find the merge even
      // when the batch's affected range is just the anchor cell.
      final anchorOnly = const CellRange(0, 0, 0, 0);
      final regions = data.mergedCells.regionsInRange(anchorOnly);
      expect(regions, hasLength(1));

      // Expanding via union gives the full merge extent.
      var expanded = anchorOnly;
      for (final r in regions) {
        expanded = expanded.union(r.range);
      }
      expect(expanded, mergeRange);
    });

    test('non-anchor styles other than borders are preserved', () {
      // Set background color on all cells in range
      const range = CellRange(0, 0, 1, 1);
      for (final coord in range.cells) {
        data.setStyle(
          coord,
          const CellStyle(
            backgroundColor: Color(0xFFAABBCC),
            borders: CellBorders.all(BorderStyle()),
          ),
        );
      }

      mergeAndClearBorders(data, range);

      // Non-anchor at (0,1) should keep backgroundColor but lose borders
      final style = data.getStyle(const CellCoordinate(0, 1));
      expect(style?.backgroundColor, const Color(0xFFAABBCC));
      final hasBorders =
          style != null && style.borders != null && !style.borders!.isNone;
      expect(hasBorders, isFalse);
    });
  });
}
