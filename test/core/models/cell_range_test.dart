import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  group('CellRange', () {
    group('construction', () {
      test('creates with valid indices', () {
        final range = CellRange(0, 0, 10, 5);
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 10);
        expect(range.endColumn, 5);
      });

      test('throws assertion error for negative startRow', () {
        expect(() => CellRange(-1, 0, 10, 5), throwsAssertionError);
      });

      test('throws assertion error for negative startColumn', () {
        expect(() => CellRange(0, -1, 10, 5), throwsAssertionError);
      });

      test('throws assertion error when endRow < startRow', () {
        expect(() => CellRange(10, 0, 5, 5), throwsAssertionError);
      });

      test('throws assertion error when endColumn < startColumn', () {
        expect(() => CellRange(0, 10, 5, 5), throwsAssertionError);
      });

      test('allows single cell range', () {
        final range = CellRange(5, 5, 5, 5);
        expect(range.startRow, 5);
        expect(range.endRow, 5);
      });
    });

    group('fromCoordinates', () {
      test('normalizes when topLeft is before bottomRight', () {
        final topLeft = CellCoordinate(0, 0);
        final bottomRight = CellCoordinate(10, 5);
        final range = CellRange.fromCoordinates(topLeft, bottomRight);
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 10);
        expect(range.endColumn, 5);
      });

      test('normalizes when bottomRight is before topLeft', () {
        final a = CellCoordinate(10, 5);
        final b = CellCoordinate(0, 0);
        final range = CellRange.fromCoordinates(a, b);
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 10);
        expect(range.endColumn, 5);
      });

      test('normalizes when coordinates cross (diagonal)', () {
        final a = CellCoordinate(0, 5);
        final b = CellCoordinate(10, 0);
        final range = CellRange.fromCoordinates(a, b);
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
        expect(range.endRow, 10);
        expect(range.endColumn, 5);
      });

      test('handles same coordinate (single cell)', () {
        final coord = CellCoordinate(5, 5);
        final range = CellRange.fromCoordinates(coord, coord);
        expect(range.startRow, 5);
        expect(range.startColumn, 5);
        expect(range.endRow, 5);
        expect(range.endColumn, 5);
      });
    });

    group('single cell constructor', () {
      test('creates range for single cell', () {
        final coord = CellCoordinate(3, 7);
        final range = CellRange.single(coord);
        expect(range.startRow, 3);
        expect(range.startColumn, 7);
        expect(range.endRow, 3);
        expect(range.endColumn, 7);
      });
    });

    group('dimensions', () {
      test('returns correct row count', () {
        final range = CellRange(0, 0, 10, 5);
        expect(range.rowCount, 11); // 0 through 10 inclusive
      });

      test('returns correct column count', () {
        final range = CellRange(0, 0, 10, 5);
        expect(range.columnCount, 6); // 0 through 5 inclusive
      });

      test('returns correct cell count', () {
        final range = CellRange(0, 0, 10, 5);
        expect(range.cellCount, 66); // 11 * 6
      });

      test('single cell has count of 1', () {
        final range = CellRange(5, 5, 5, 5);
        expect(range.rowCount, 1);
        expect(range.columnCount, 1);
        expect(range.cellCount, 1);
      });
    });

    group('topLeft and bottomRight', () {
      test('returns correct corner coordinates', () {
        final range = CellRange(2, 3, 10, 15);
        expect(range.topLeft, CellCoordinate(2, 3));
        expect(range.bottomRight, CellCoordinate(10, 15));
      });
    });

    group('contains', () {
      test('returns true for coordinate inside range', () {
        final range = CellRange(0, 0, 10, 10);
        expect(range.contains(CellCoordinate(5, 5)), isTrue);
      });

      test('returns true for coordinate at top-left corner', () {
        final range = CellRange(0, 0, 10, 10);
        expect(range.contains(CellCoordinate(0, 0)), isTrue);
      });

      test('returns true for coordinate at bottom-right corner', () {
        final range = CellRange(0, 0, 10, 10);
        expect(range.contains(CellCoordinate(10, 10)), isTrue);
      });

      test('returns true for coordinate on edge', () {
        final range = CellRange(0, 0, 10, 10);
        expect(range.contains(CellCoordinate(5, 0)), isTrue);
        expect(range.contains(CellCoordinate(0, 5)), isTrue);
        expect(range.contains(CellCoordinate(10, 5)), isTrue);
        expect(range.contains(CellCoordinate(5, 10)), isTrue);
      });

      test('returns false for coordinate outside range', () {
        final range = CellRange(5, 5, 10, 10);
        expect(range.contains(CellCoordinate(0, 0)), isFalse);
        expect(range.contains(CellCoordinate(4, 5)), isFalse);
        expect(range.contains(CellCoordinate(5, 4)), isFalse);
        expect(range.contains(CellCoordinate(11, 10)), isFalse);
        expect(range.contains(CellCoordinate(10, 11)), isFalse);
      });
    });

    group('intersects', () {
      test('returns true for overlapping ranges', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(5, 5, 15, 15);
        expect(a.intersects(b), isTrue);
        expect(b.intersects(a), isTrue);
      });

      test('returns true for touching at corner', () {
        final a = CellRange(0, 0, 5, 5);
        final b = CellRange(5, 5, 10, 10);
        expect(a.intersects(b), isTrue);
      });

      test('returns true for touching at edge', () {
        final a = CellRange(0, 0, 5, 10);
        final b = CellRange(5, 0, 10, 10);
        expect(a.intersects(b), isTrue);
      });

      test('returns true for contained range', () {
        final outer = CellRange(0, 0, 10, 10);
        final inner = CellRange(3, 3, 7, 7);
        expect(outer.intersects(inner), isTrue);
        expect(inner.intersects(outer), isTrue);
      });

      test('returns false for non-overlapping ranges', () {
        final a = CellRange(0, 0, 5, 5);
        final b = CellRange(6, 6, 10, 10);
        expect(a.intersects(b), isFalse);
        expect(b.intersects(a), isFalse);
      });

      test('returns true for same range', () {
        final a = CellRange(0, 0, 10, 10);
        expect(a.intersects(a), isTrue);
      });
    });

    group('intersection', () {
      test('returns intersection of overlapping ranges', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(5, 5, 15, 15);
        final intersection = a.intersection(b);
        expect(intersection, isNotNull);
        expect(intersection!.startRow, 5);
        expect(intersection.startColumn, 5);
        expect(intersection.endRow, 10);
        expect(intersection.endColumn, 10);
      });

      test('returns null for non-overlapping ranges', () {
        final a = CellRange(0, 0, 5, 5);
        final b = CellRange(6, 6, 10, 10);
        expect(a.intersection(b), isNull);
      });

      test('returns single cell for corner touch', () {
        final a = CellRange(0, 0, 5, 5);
        final b = CellRange(5, 5, 10, 10);
        final intersection = a.intersection(b);
        expect(intersection, isNotNull);
        expect(intersection!.cellCount, 1);
        expect(intersection.startRow, 5);
        expect(intersection.startColumn, 5);
      });
    });

    group('union', () {
      test('returns union of two ranges', () {
        final a = CellRange(0, 0, 5, 5);
        final b = CellRange(10, 10, 15, 15);
        final union = a.union(b);
        expect(union.startRow, 0);
        expect(union.startColumn, 0);
        expect(union.endRow, 15);
        expect(union.endColumn, 15);
      });

      test('returns same bounds for overlapping ranges', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(5, 5, 15, 15);
        final union = a.union(b);
        expect(union.startRow, 0);
        expect(union.startColumn, 0);
        expect(union.endRow, 15);
        expect(union.endColumn, 15);
      });

      test('returns same range when unioned with itself', () {
        final a = CellRange(5, 5, 10, 10);
        final union = a.union(a);
        expect(union, a);
      });
    });

    group('expand', () {
      test('expands to include coordinate outside range', () {
        final range = CellRange(5, 5, 10, 10);
        final expanded = range.expand(CellCoordinate(15, 15));
        expect(expanded.startRow, 5);
        expect(expanded.startColumn, 5);
        expect(expanded.endRow, 15);
        expect(expanded.endColumn, 15);
      });

      test('expands to include coordinate before range', () {
        final range = CellRange(5, 5, 10, 10);
        final expanded = range.expand(CellCoordinate(0, 0));
        expect(expanded.startRow, 0);
        expect(expanded.startColumn, 0);
        expect(expanded.endRow, 10);
        expect(expanded.endColumn, 10);
      });

      test('returns same range when coordinate already contained', () {
        final range = CellRange(5, 5, 10, 10);
        final expanded = range.expand(CellCoordinate(7, 7));
        expect(expanded, range);
      });
    });

    group('cells iterator', () {
      test('iterates over all cells in range', () {
        final range = CellRange(0, 0, 2, 2);
        final cells = range.cells.toList();
        expect(cells.length, 9);
        expect(cells[0], CellCoordinate(0, 0));
        expect(cells[1], CellCoordinate(0, 1));
        expect(cells[2], CellCoordinate(0, 2));
        expect(cells[3], CellCoordinate(1, 0));
        expect(cells[8], CellCoordinate(2, 2));
      });

      test('iterates over single cell', () {
        final range = CellRange(5, 5, 5, 5);
        final cells = range.cells.toList();
        expect(cells.length, 1);
        expect(cells[0], CellCoordinate(5, 5));
      });
    });

    group('equality', () {
      test('equal ranges are equal', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(0, 0, 10, 10);
        expect(a, b);
        expect(a == b, isTrue);
      });

      test('different ranges are not equal', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(0, 0, 10, 11);
        expect(a == b, isFalse);
      });
    });

    group('hashCode', () {
      test('equal ranges have same hashCode', () {
        final a = CellRange(0, 0, 10, 10);
        final b = CellRange(0, 0, 10, 10);
        expect(a.hashCode, b.hashCode);
      });

      test('can be used in set', () {
        final set = <CellRange>{};
        set.add(CellRange(0, 0, 10, 10));
        set.add(CellRange(0, 0, 10, 10));
        expect(set.length, 1);
      });
    });

    group('toString', () {
      test('returns readable string', () {
        final range = CellRange(0, 0, 10, 5);
        expect(range.toString(), 'CellRange(A1:F11)');
      });

      test('single cell shows single notation', () {
        final range = CellRange(0, 0, 0, 0);
        expect(range.toString(), 'CellRange(A1:A1)');
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final range = CellRange(0, 0, 10, 10);
        final copy = range.copyWith(endRow: 20, endColumn: 20);
        expect(copy.startRow, 0);
        expect(copy.startColumn, 0);
        expect(copy.endRow, 20);
        expect(copy.endColumn, 20);
      });

      test('returns same values when nothing specified', () {
        final range = CellRange(0, 0, 10, 10);
        final copy = range.copyWith();
        expect(copy, range);
      });
    });
  });
}
