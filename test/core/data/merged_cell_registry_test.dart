import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  group('MergeRegion', () {
    test('anchor is top-left of range', () {
      final region = MergeRegion(CellRange(1, 2, 3, 4));
      expect(region.anchor, const CellCoordinate(1, 2));
    });

    test('contains returns true for cells inside range', () {
      final region = MergeRegion(CellRange(0, 0, 1, 1));
      expect(region.contains(const CellCoordinate(0, 0)), isTrue);
      expect(region.contains(const CellCoordinate(1, 1)), isTrue);
      expect(region.contains(const CellCoordinate(0, 1)), isTrue);
      expect(region.contains(const CellCoordinate(2, 0)), isFalse);
    });

    test('isAnchor returns true only for top-left cell', () {
      final region = MergeRegion(CellRange(1, 1, 2, 2));
      expect(region.isAnchor(const CellCoordinate(1, 1)), isTrue);
      expect(region.isAnchor(const CellCoordinate(1, 2)), isFalse);
      expect(region.isAnchor(const CellCoordinate(2, 1)), isFalse);
    });

    test('rowCount and columnCount', () {
      final region = MergeRegion(CellRange(0, 0, 2, 3));
      expect(region.rowCount, 3);
      expect(region.columnCount, 4);
    });

    test('equality', () {
      final a = MergeRegion(CellRange(0, 0, 1, 1));
      final b = MergeRegion(CellRange(0, 0, 1, 1));
      final c = MergeRegion(CellRange(0, 0, 1, 2));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      final region = MergeRegion(CellRange(0, 0, 1, 1));
      expect(region.toString(), contains('MergeRegion'));
    });
  });

  group('MergedCellRegistry', () {
    late MergedCellRegistry registry;

    setUp(() {
      registry = MergedCellRegistry();
    });

    test('starts empty', () {
      expect(registry.isEmpty, isTrue);
      expect(registry.regionCount, 0);
      expect(registry.regions, isEmpty);
    });

    test('merge registers a region', () {
      registry.merge(CellRange(0, 0, 1, 1));
      expect(registry.regionCount, 1);
      expect(registry.isEmpty, isFalse);
    });

    test('isMerged returns true for all cells in region', () {
      registry.merge(CellRange(0, 0, 1, 1));
      expect(registry.isMerged(const CellCoordinate(0, 0)), isTrue);
      expect(registry.isMerged(const CellCoordinate(0, 1)), isTrue);
      expect(registry.isMerged(const CellCoordinate(1, 0)), isTrue);
      expect(registry.isMerged(const CellCoordinate(1, 1)), isTrue);
      expect(registry.isMerged(const CellCoordinate(2, 0)), isFalse);
    });

    test('isAnchor returns true only for anchor cell', () {
      registry.merge(CellRange(1, 1, 2, 2));
      expect(registry.isAnchor(const CellCoordinate(1, 1)), isTrue);
      expect(registry.isAnchor(const CellCoordinate(1, 2)), isFalse);
      expect(registry.isAnchor(const CellCoordinate(2, 1)), isFalse);
      expect(registry.isAnchor(const CellCoordinate(0, 0)), isFalse);
    });

    test('getRegion returns the region for any cell in it', () {
      registry.merge(CellRange(0, 0, 1, 1));
      final region = registry.getRegion(const CellCoordinate(1, 0));
      expect(region, isNotNull);
      expect(region!.range, CellRange(0, 0, 1, 1));
    });

    test('getRegion returns null for unmerged cell', () {
      expect(registry.getRegion(const CellCoordinate(0, 0)), isNull);
    });

    test('resolveAnchor returns anchor for merged cell', () {
      registry.merge(CellRange(2, 3, 4, 5));
      expect(
        registry.resolveAnchor(const CellCoordinate(3, 4)),
        const CellCoordinate(2, 3),
      );
    });

    test('resolveAnchor returns cell itself for unmerged cell', () {
      expect(
        registry.resolveAnchor(const CellCoordinate(5, 5)),
        const CellCoordinate(5, 5),
      );
    });

    test('merge rejects range with fewer than 2 cells', () {
      expect(
        () => registry.merge(CellRange(0, 0, 0, 0)),
        throwsArgumentError,
      );
    });

    test('merge rejects overlapping regions', () {
      registry.merge(CellRange(0, 0, 1, 1));
      expect(
        () => registry.merge(CellRange(1, 1, 2, 2)),
        throwsArgumentError,
      );
    });

    test('multiple non-overlapping merges', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.merge(CellRange(0, 2, 1, 3));
      registry.merge(CellRange(3, 0, 4, 4));
      expect(registry.regionCount, 3);
    });

    test('unmerge removes region', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.unmerge(const CellCoordinate(0, 0));
      expect(registry.isEmpty, isTrue);
      expect(registry.isMerged(const CellCoordinate(0, 0)), isFalse);
      expect(registry.isMerged(const CellCoordinate(1, 1)), isFalse);
    });

    test('unmerge works with non-anchor cell', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.unmerge(const CellCoordinate(1, 1)); // not anchor
      expect(registry.isEmpty, isTrue);
    });

    test('unmerge is no-op for unmerged cell', () {
      registry.unmerge(const CellCoordinate(0, 0)); // should not throw
      expect(registry.isEmpty, isTrue);
    });

    test('unmerge allows re-merge of same area', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.unmerge(const CellCoordinate(0, 0));
      registry.merge(CellRange(0, 0, 1, 1));
      expect(registry.regionCount, 1);
    });

    test('regionsInRange returns intersecting regions', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.merge(CellRange(3, 3, 4, 4));
      registry.merge(CellRange(0, 5, 1, 6));

      final result = registry.regionsInRange(CellRange(0, 0, 2, 2)).toList();
      expect(result.length, 1);
      expect(result.first.range, CellRange(0, 0, 1, 1));
    });

    test('regionsInRange returns empty for no intersections', () {
      registry.merge(CellRange(0, 0, 1, 1));
      final result = registry.regionsInRange(CellRange(5, 5, 6, 6));
      expect(result, isEmpty);
    });

    test('regionsInRange returns multiple regions', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.merge(CellRange(0, 2, 1, 3));
      final result = registry.regionsInRange(CellRange(0, 0, 1, 3)).toList();
      expect(result.length, 2);
    });

    test('regionsInRange finds partially overlapping region', () {
      registry.merge(CellRange(0, 0, 3, 3));
      final result = registry.regionsInRange(CellRange(2, 2, 5, 5)).toList();
      expect(result.length, 1);
      expect(result.first.range, CellRange(0, 0, 3, 3));
    });

    test('single-row merge (horizontal)', () {
      registry.merge(CellRange(0, 0, 0, 3));
      expect(registry.regionCount, 1);
      expect(registry.isMerged(const CellCoordinate(0, 2)), isTrue);
    });

    test('single-column merge (vertical)', () {
      registry.merge(CellRange(0, 0, 3, 0));
      expect(registry.regionCount, 1);
      expect(registry.isMerged(const CellCoordinate(2, 0)), isTrue);
    });

    test('clear removes all regions', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.merge(CellRange(3, 3, 4, 4));
      registry.clear();
      expect(registry.isEmpty, isTrue);
      expect(registry.isMerged(const CellCoordinate(0, 0)), isFalse);
    });

    test('regions returns all registered regions', () {
      registry.merge(CellRange(0, 0, 1, 1));
      registry.merge(CellRange(3, 3, 4, 4));
      final regions = registry.regions.toList();
      expect(regions.length, 2);
    });

    test('adjacent merges do not overlap', () {
      registry.merge(CellRange(0, 0, 0, 1));
      registry.merge(CellRange(0, 2, 0, 3));
      expect(registry.regionCount, 2);
      expect(
        registry.getRegion(const CellCoordinate(0, 1))!.range,
        CellRange(0, 0, 0, 1),
      );
      expect(
        registry.getRegion(const CellCoordinate(0, 2))!.range,
        CellRange(0, 2, 0, 3),
      );
    });
  });
}
