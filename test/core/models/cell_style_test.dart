import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_style.dart';

void main() {
  group('BorderStyle', () {
    test('creates with default values', () {
      const style = BorderStyle();
      expect(style.color, const Color(0xFF000000));
      expect(style.width, 1.0);
    });

    test('creates with custom values', () {
      const style = BorderStyle(color: Color(0xFFFF0000), width: 2.0);
      expect(style.color, const Color(0xFFFF0000));
      expect(style.width, 2.0);
    });

    test('none has zero width', () {
      expect(BorderStyle.none.width, 0);
      expect(BorderStyle.none.isNone, isTrue);
    });

    test('isNone returns false for non-zero width', () {
      const style = BorderStyle(width: 1.0);
      expect(style.isNone, isFalse);
    });

    test('equality', () {
      const a = BorderStyle(color: Color(0xFF000000), width: 1.0);
      const b = BorderStyle(color: Color(0xFF000000), width: 1.0);
      const c = BorderStyle(color: Color(0xFFFF0000), width: 1.0);

      expect(a, b);
      expect(a == c, isFalse);
    });

    test('hashCode', () {
      const a = BorderStyle(color: Color(0xFF000000), width: 1.0);
      const b = BorderStyle(color: Color(0xFF000000), width: 1.0);

      expect(a.hashCode, b.hashCode);
    });
  });

  group('CellBorders', () {
    test('creates with default none borders', () {
      const borders = CellBorders();
      expect(borders.top, BorderStyle.none);
      expect(borders.right, BorderStyle.none);
      expect(borders.bottom, BorderStyle.none);
      expect(borders.left, BorderStyle.none);
    });

    test('creates with custom borders', () {
      const style = BorderStyle(width: 2.0);
      const borders = CellBorders(top: style, bottom: style);

      expect(borders.top, style);
      expect(borders.bottom, style);
      expect(borders.right, BorderStyle.none);
      expect(borders.left, BorderStyle.none);
    });

    test('all constructor sets all sides', () {
      const style = BorderStyle(width: 2.0, color: Color(0xFFFF0000));
      const borders = CellBorders.all(style);

      expect(borders.top, style);
      expect(borders.right, style);
      expect(borders.bottom, style);
      expect(borders.left, style);
    });

    test('none is all none borders', () {
      expect(CellBorders.none.isNone, isTrue);
    });

    test('isNone returns false when any border is set', () {
      const style = BorderStyle(width: 1.0);
      const borders = CellBorders(top: style);

      expect(borders.isNone, isFalse);
    });

    test('equality', () {
      const style = BorderStyle(width: 2.0);
      const a = CellBorders(top: style);
      const b = CellBorders(top: style);
      const c = CellBorders(bottom: style);

      expect(a, b);
      expect(a == c, isFalse);
    });

    test('hashCode', () {
      const style = BorderStyle(width: 2.0);
      const a = CellBorders(top: style);
      const b = CellBorders(top: style);

      expect(a.hashCode, b.hashCode);
    });
  });

  group('CellStyle', () {
    test('creates with all null values', () {
      const style = CellStyle();
      expect(style.backgroundColor, isNull);
      expect(style.fontFamily, isNull);
      expect(style.fontSize, isNull);
      expect(style.fontWeight, isNull);
      expect(style.fontStyle, isNull);
      expect(style.textColor, isNull);
      expect(style.textAlignment, isNull);
      expect(style.verticalAlignment, isNull);
      expect(style.borders, isNull);
      expect(style.wrapText, isNull);
      expect(style.numberFormat, isNull);
    });

    test('creates with custom values', () {
      const style = CellStyle(
        backgroundColor: Color(0xFFFFFF00),
        fontFamily: 'Arial',
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        textColor: Color(0xFF000000),
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.top,
        borders: CellBorders.none,
        wrapText: true,
        numberFormat: '#,##0.00',
      );

      expect(style.backgroundColor, const Color(0xFFFFFF00));
      expect(style.fontFamily, 'Arial');
      expect(style.fontSize, 16.0);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.textColor, const Color(0xFF000000));
      expect(style.textAlignment, CellTextAlignment.center);
      expect(style.verticalAlignment, CellVerticalAlignment.top);
      expect(style.borders, CellBorders.none);
      expect(style.wrapText, isTrue);
      expect(style.numberFormat, '#,##0.00');
    });

    test('defaultStyle has expected values', () {
      expect(CellStyle.defaultStyle.fontFamily, 'Roboto');
      expect(CellStyle.defaultStyle.fontSize, 14.0);
      expect(CellStyle.defaultStyle.fontWeight, FontWeight.normal);
      expect(CellStyle.defaultStyle.fontStyle, FontStyle.normal);
      expect(CellStyle.defaultStyle.textColor, const Color(0xFF000000));
      expect(CellStyle.defaultStyle.textAlignment, CellTextAlignment.left);
      expect(CellStyle.defaultStyle.verticalAlignment, CellVerticalAlignment.middle);
      expect(CellStyle.defaultStyle.borders, CellBorders.none);
      expect(CellStyle.defaultStyle.wrapText, isFalse);
    });

    group('merge', () {
      test('returns this when other is null', () {
        const style = CellStyle(fontSize: 16.0);
        expect(style.merge(null), style);
      });

      test('other values take precedence', () {
        const base = CellStyle(
          fontSize: 14.0,
          fontFamily: 'Arial',
          textColor: Color(0xFF000000),
        );
        const overlay = CellStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        );

        final merged = base.merge(overlay);

        expect(merged.fontSize, 18.0); // from overlay
        expect(merged.fontFamily, 'Arial'); // from base
        expect(merged.textColor, const Color(0xFF000000)); // from base
        expect(merged.fontWeight, FontWeight.bold); // from overlay
      });

      test('preserves base values when other has nulls', () {
        const base = CellStyle(
          fontSize: 14.0,
          fontFamily: 'Arial',
        );
        const overlay = CellStyle();

        final merged = base.merge(overlay);

        expect(merged.fontSize, 14.0);
        expect(merged.fontFamily, 'Arial');
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const original = CellStyle(
          fontSize: 14.0,
          fontFamily: 'Arial',
        );

        final copy = original.copyWith(fontSize: 18.0);

        expect(copy.fontSize, 18.0);
        expect(copy.fontFamily, 'Arial');
      });

      test('returns equivalent when nothing specified', () {
        const original = CellStyle(fontSize: 14.0);
        final copy = original.copyWith();

        expect(copy, original);
      });

      test('can update all fields', () {
        const original = CellStyle();
        final copy = original.copyWith(
          backgroundColor: const Color(0xFFFFFFFF),
          fontFamily: 'Courier',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          textColor: const Color(0xFF333333),
          textAlignment: CellTextAlignment.right,
          verticalAlignment: CellVerticalAlignment.bottom,
          borders: CellBorders.none,
          wrapText: true,
          numberFormat: '0%',
        );

        expect(copy.backgroundColor, const Color(0xFFFFFFFF));
        expect(copy.fontFamily, 'Courier');
        expect(copy.fontSize, 12.0);
        expect(copy.fontWeight, FontWeight.w500);
        expect(copy.fontStyle, FontStyle.italic);
        expect(copy.textColor, const Color(0xFF333333));
        expect(copy.textAlignment, CellTextAlignment.right);
        expect(copy.verticalAlignment, CellVerticalAlignment.bottom);
        expect(copy.borders, CellBorders.none);
        expect(copy.wrapText, isTrue);
        expect(copy.numberFormat, '0%');
      });
    });

    group('equality', () {
      test('equal styles are equal', () {
        const a = CellStyle(fontSize: 14.0, fontFamily: 'Arial');
        const b = CellStyle(fontSize: 14.0, fontFamily: 'Arial');

        expect(a, b);
      });

      test('different styles are not equal', () {
        const a = CellStyle(fontSize: 14.0);
        const b = CellStyle(fontSize: 16.0);

        expect(a == b, isFalse);
      });

      test('identical returns true for same instance', () {
        const a = CellStyle(fontSize: 14.0);
        expect(a == a, isTrue);
      });
    });

    group('hashCode', () {
      test('equal styles have same hashCode', () {
        const a = CellStyle(fontSize: 14.0, fontFamily: 'Arial');
        const b = CellStyle(fontSize: 14.0, fontFamily: 'Arial');

        expect(a.hashCode, b.hashCode);
      });

      test('can be used in set', () {
        final set = <CellStyle>{};
        set.add(const CellStyle(fontSize: 14.0));
        set.add(const CellStyle(fontSize: 14.0));

        expect(set.length, 1);
      });
    });
  });

  group('CellTextAlignment enum', () {
    test('has expected values', () {
      expect(CellTextAlignment.values.length, 3);
      expect(CellTextAlignment.left.index, 0);
      expect(CellTextAlignment.center.index, 1);
      expect(CellTextAlignment.right.index, 2);
    });
  });

  group('CellVerticalAlignment enum', () {
    test('has expected values', () {
      expect(CellVerticalAlignment.values.length, 3);
      expect(CellVerticalAlignment.top.index, 0);
      expect(CellVerticalAlignment.middle.index, 1);
      expect(CellVerticalAlignment.bottom.index, 2);
    });
  });
}
