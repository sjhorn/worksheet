import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';

void main() {
  group('CellCoordinate', () {
    group('construction', () {
      test('creates with valid row and column', () {
        final coord = CellCoordinate(0, 0);
        expect(coord.row, 0);
        expect(coord.column, 0);

        final coord2 = CellCoordinate(100, 50);
        expect(coord2.row, 100);
        expect(coord2.column, 50);
      });

      test('throws assertion error for negative row', () {
        expect(() => CellCoordinate(-1, 0), throwsAssertionError);
      });

      test('throws assertion error for negative column', () {
        expect(() => CellCoordinate(0, -1), throwsAssertionError);
      });
    });

    group('fromNotation', () {
      test('parses single letter column (A1)', () {
        final coord = CellCoordinate.fromNotation('A1');
        expect(coord.row, 0);
        expect(coord.column, 0);
      });

      test('parses single letter column (B5)', () {
        final coord = CellCoordinate.fromNotation('B5');
        expect(coord.row, 4);
        expect(coord.column, 1);
      });

      test('parses Z1', () {
        final coord = CellCoordinate.fromNotation('Z1');
        expect(coord.row, 0);
        expect(coord.column, 25);
      });

      test('parses double letter column (AA1)', () {
        final coord = CellCoordinate.fromNotation('AA1');
        expect(coord.row, 0);
        expect(coord.column, 26);
      });

      test('parses AB10', () {
        final coord = CellCoordinate.fromNotation('AB10');
        expect(coord.row, 9);
        expect(coord.column, 27);
      });

      test('parses AZ1', () {
        final coord = CellCoordinate.fromNotation('AZ1');
        expect(coord.row, 0);
        expect(coord.column, 51); // 26 + 25 = 51
      });

      test('parses triple letter column (AAA1)', () {
        final coord = CellCoordinate.fromNotation('AAA1');
        expect(coord.row, 0);
        expect(coord.column, 702); // 26*26 + 26 + 0 = 702
      });

      test('handles lowercase notation', () {
        final coord = CellCoordinate.fromNotation('a1');
        expect(coord.row, 0);
        expect(coord.column, 0);
      });

      test('throws FormatException for empty string', () {
        expect(() => CellCoordinate.fromNotation(''), throwsFormatException);
      });

      test('throws FormatException for invalid notation', () {
        expect(() => CellCoordinate.fromNotation('1A'), throwsFormatException);
        expect(() => CellCoordinate.fromNotation('A'), throwsFormatException);
        expect(() => CellCoordinate.fromNotation('123'), throwsFormatException);
      });

      test('throws FormatException for row 0', () {
        expect(() => CellCoordinate.fromNotation('A0'), throwsFormatException);
      });
    });

    group('toNotation', () {
      test('converts (0,0) to A1', () {
        expect(CellCoordinate(0, 0).toNotation(), 'A1');
      });

      test('converts (4,1) to B5', () {
        expect(CellCoordinate(4, 1).toNotation(), 'B5');
      });

      test('converts (0,25) to Z1', () {
        expect(CellCoordinate(0, 25).toNotation(), 'Z1');
      });

      test('converts (0,26) to AA1', () {
        expect(CellCoordinate(0, 26).toNotation(), 'AA1');
      });

      test('converts (9,27) to AB10', () {
        expect(CellCoordinate(9, 27).toNotation(), 'AB10');
      });

      test('converts (0,51) to AZ1', () {
        expect(CellCoordinate(0, 51).toNotation(), 'AZ1');
      });

      test('converts (0,702) to AAA1', () {
        expect(CellCoordinate(0, 702).toNotation(), 'AAA1');
      });

      test('round-trips through fromNotation', () {
        for (var row = 0; row < 100; row++) {
          for (var col = 0; col < 100; col++) {
            final coord = CellCoordinate(row, col);
            final notation = coord.toNotation();
            final parsed = CellCoordinate.fromNotation(notation);
            expect(parsed, coord);
          }
        }
      });
    });

    group('offset', () {
      test('applies positive deltas', () {
        final coord = CellCoordinate(5, 5);
        final offset = coord.offset(2, 3);
        expect(offset.row, 7);
        expect(offset.column, 8);
      });

      test('applies negative deltas', () {
        final coord = CellCoordinate(5, 5);
        final offset = coord.offset(-2, -3);
        expect(offset.row, 3);
        expect(offset.column, 2);
      });

      test('clamps to zero when going negative', () {
        final coord = CellCoordinate(2, 3);
        final offset = coord.offset(-10, -10);
        expect(offset.row, 0);
        expect(offset.column, 0);
      });

      test('returns same coordinate for zero offset', () {
        final coord = CellCoordinate(5, 5);
        final offset = coord.offset(0, 0);
        expect(offset, coord);
      });
    });

    group('equality', () {
      test('equal coordinates are equal', () {
        final a = CellCoordinate(5, 10);
        final b = CellCoordinate(5, 10);
        expect(a, b);
        expect(a == b, isTrue);
      });

      test('different rows are not equal', () {
        final a = CellCoordinate(5, 10);
        final b = CellCoordinate(6, 10);
        expect(a == b, isFalse);
      });

      test('different columns are not equal', () {
        final a = CellCoordinate(5, 10);
        final b = CellCoordinate(5, 11);
        expect(a == b, isFalse);
      });
    });

    group('hashCode', () {
      test('equal coordinates have same hashCode', () {
        final a = CellCoordinate(5, 10);
        final b = CellCoordinate(5, 10);
        expect(a.hashCode, b.hashCode);
      });

      test('can be used as map key', () {
        final map = <CellCoordinate, String>{};
        final coord = CellCoordinate(5, 10);
        map[coord] = 'test';
        expect(map[CellCoordinate(5, 10)], 'test');
      });

      test('can be used in set', () {
        final set = <CellCoordinate>{};
        set.add(CellCoordinate(5, 10));
        set.add(CellCoordinate(5, 10));
        expect(set.length, 1);
      });
    });

    group('toString', () {
      test('returns notation string', () {
        expect(CellCoordinate(0, 0).toString(), 'CellCoordinate(A1)');
        expect(CellCoordinate(9, 27).toString(), 'CellCoordinate(AB10)');
      });
    });

    group('copyWith', () {
      test('copies with new row', () {
        final coord = CellCoordinate(5, 10);
        final copy = coord.copyWith(row: 7);
        expect(copy.row, 7);
        expect(copy.column, 10);
      });

      test('copies with new column', () {
        final coord = CellCoordinate(5, 10);
        final copy = coord.copyWith(column: 15);
        expect(copy.row, 5);
        expect(copy.column, 15);
      });

      test('returns same values when nothing specified', () {
        final coord = CellCoordinate(5, 10);
        final copy = coord.copyWith();
        expect(copy, coord);
      });
    });
  });
}
