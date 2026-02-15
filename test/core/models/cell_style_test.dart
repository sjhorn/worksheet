import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

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

  group('BorderLineStyle', () {
    test('has expected values in priority order', () {
      expect(BorderLineStyle.values.length, 5);
      expect(BorderLineStyle.none.index, 0);
      expect(BorderLineStyle.dotted.index, 1);
      expect(BorderLineStyle.dashed.index, 2);
      expect(BorderLineStyle.solid.index, 3);
      expect(BorderLineStyle.double.index, 4);
    });
  });

  group('BorderStyle lineStyle', () {
    test('default lineStyle is solid', () {
      const style = BorderStyle();
      expect(style.lineStyle, BorderLineStyle.solid);
    });

    test('none has none lineStyle', () {
      expect(BorderStyle.none.lineStyle, BorderLineStyle.none);
    });

    test('isNone returns true for none lineStyle with non-zero width', () {
      const style = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.none);
      expect(style.isNone, isTrue);
    });

    test('equality includes lineStyle', () {
      const a = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);
      const b = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);
      const c = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.dashed);

      expect(a, b);
      expect(a == c, isFalse);
    });

    test('hashCode includes lineStyle', () {
      const a = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);
      const b = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);

      expect(a.hashCode, b.hashCode);
    });

    test('copyWith creates modified copy', () {
      const original = BorderStyle(
        color: Color(0xFF000000),
        width: 1.0,
        lineStyle: BorderLineStyle.solid,
      );

      final copy = original.copyWith(
        lineStyle: BorderLineStyle.dashed,
        width: 2.0,
      );

      expect(copy.color, const Color(0xFF000000));
      expect(copy.width, 2.0);
      expect(copy.lineStyle, BorderLineStyle.dashed);
    });

    test('copyWith returns equivalent when nothing specified', () {
      const original = BorderStyle(width: 1.0);
      final copy = original.copyWith();
      expect(copy, original);
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

    test('copyWith creates modified copy', () {
      const original = CellBorders(
        top: BorderStyle(width: 1.0),
        bottom: BorderStyle(width: 2.0),
      );

      final copy = original.copyWith(
        top: const BorderStyle(width: 3.0),
      );

      expect(copy.top.width, 3.0);
      expect(copy.bottom.width, 2.0);
      expect(copy.right, BorderStyle.none);
      expect(copy.left, BorderStyle.none);
    });

    test('copyWith returns equivalent when nothing specified', () {
      const original = CellBorders(top: BorderStyle(width: 1.0));
      final copy = original.copyWith();
      expect(copy, original);
    });
  });

  group('CellStyle', () {
    test('creates with all null values', () {
      const style = CellStyle();
      expect(style.backgroundColor, isNull);
      expect(style.textAlignment, isNull);
      expect(style.verticalAlignment, isNull);
      expect(style.borders, isNull);
      expect(style.wrapText, isNull);
      // ignore: deprecated_member_use_from_same_package
      expect(style.numberFormat, isNull);
    });

    test('creates with custom values', () {
      const style = CellStyle(
        backgroundColor: Color(0xFFFFFF00),
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.top,
        borders: CellBorders.none,
        wrapText: true,
        // ignore: deprecated_member_use_from_same_package
        numberFormat: '#,##0.00',
      );

      expect(style.backgroundColor, const Color(0xFFFFFF00));
      expect(style.textAlignment, CellTextAlignment.center);
      expect(style.verticalAlignment, CellVerticalAlignment.top);
      expect(style.borders, CellBorders.none);
      expect(style.wrapText, isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(style.numberFormat, '#,##0.00');
    });

    test('defaultStyle has expected values', () {
      expect(CellStyle.defaultStyle.textAlignment, isNull);
      expect(CellStyle.defaultStyle.verticalAlignment, CellVerticalAlignment.middle);
      expect(CellStyle.defaultStyle.borders, CellBorders.none);
      expect(CellStyle.defaultStyle.wrapText, isFalse);
    });

    group('merge', () {
      test('returns this when other is null', () {
        const style = CellStyle(backgroundColor: Color(0xFFFFFF00));
        expect(style.merge(null), style);
      });

      test('other values take precedence', () {
        const base = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.left,
          wrapText: false,
        );
        const overlay = CellStyle(
          backgroundColor: Color(0xFF00FF00),
          verticalAlignment: CellVerticalAlignment.top,
        );

        final merged = base.merge(overlay);

        expect(merged.backgroundColor, const Color(0xFF00FF00)); // from overlay
        expect(merged.textAlignment, CellTextAlignment.left); // from base
        expect(merged.wrapText, isFalse); // from base
        expect(merged.verticalAlignment, CellVerticalAlignment.top); // from overlay
      });

      test('preserves base values when other has nulls', () {
        const base = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.center,
        );
        const overlay = CellStyle();

        final merged = base.merge(overlay);

        expect(merged.backgroundColor, const Color(0xFFFFFF00));
        expect(merged.textAlignment, CellTextAlignment.center);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const original = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.left,
        );

        final copy = original.copyWith(
          backgroundColor: const Color(0xFF00FF00),
        );

        expect(copy.backgroundColor, const Color(0xFF00FF00));
        expect(copy.textAlignment, CellTextAlignment.left);
      });

      test('returns equivalent when nothing specified', () {
        const original = CellStyle(backgroundColor: Color(0xFFFFFF00));
        final copy = original.copyWith();

        expect(copy, original);
      });

      test('can update all fields', () {
        const original = CellStyle();
        final copy = original.copyWith(
          backgroundColor: const Color(0xFFFFFFFF),
          textAlignment: CellTextAlignment.right,
          verticalAlignment: CellVerticalAlignment.bottom,
          borders: CellBorders.none,
          wrapText: true,
          // ignore: deprecated_member_use_from_same_package
          numberFormat: '0%',
        );

        expect(copy.backgroundColor, const Color(0xFFFFFFFF));
        expect(copy.textAlignment, CellTextAlignment.right);
        expect(copy.verticalAlignment, CellVerticalAlignment.bottom);
        expect(copy.borders, CellBorders.none);
        expect(copy.wrapText, isTrue);
        // ignore: deprecated_member_use_from_same_package
        expect(copy.numberFormat, '0%');
      });
    });

    group('equality', () {
      test('equal styles are equal', () {
        const a = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.center,
        );
        const b = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.center,
        );

        expect(a, b);
      });

      test('different styles are not equal', () {
        const a = CellStyle(backgroundColor: Color(0xFFFFFF00));
        const b = CellStyle(backgroundColor: Color(0xFF00FF00));

        expect(a == b, isFalse);
      });

      test('identical returns true for same instance', () {
        const a = CellStyle(backgroundColor: Color(0xFFFFFF00));
        expect(a == a, isTrue);
      });
    });

    group('hashCode', () {
      test('equal styles have same hashCode', () {
        const a = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.center,
        );
        const b = CellStyle(
          backgroundColor: Color(0xFFFFFF00),
          textAlignment: CellTextAlignment.center,
        );

        expect(a.hashCode, b.hashCode);
      });

      test('can be used in set', () {
        final set = <CellStyle>{};
        set.add(const CellStyle(backgroundColor: Color(0xFFFFFF00)));
        set.add(const CellStyle(backgroundColor: Color(0xFFFFFF00)));

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

  group('CellStyle.implicitAlignment', () {
    test('numbers align right', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.number),
        CellTextAlignment.right,
      );
    });

    test('booleans align right', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.boolean),
        CellTextAlignment.right,
      );
    });

    test('dates align right', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.date),
        CellTextAlignment.right,
      );
    });

    test('durations align right', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.duration),
        CellTextAlignment.right,
      );
    });

    test('text aligns left', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.text),
        CellTextAlignment.left,
      );
    });

    test('formulas align left', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.formula),
        CellTextAlignment.left,
      );
    });

    test('errors align left', () {
      expect(
        CellStyle.implicitAlignment(CellValueType.error),
        CellTextAlignment.left,
      );
    });

    test('explicit textAlignment overrides implicit', () {
      // When a style has an explicit alignment, it should be used
      // regardless of value type.
      const style = CellStyle(textAlignment: CellTextAlignment.center);
      final merged = CellStyle.defaultStyle.merge(style);
      // The merged style has an explicit alignment, so it wins.
      expect(merged.textAlignment, CellTextAlignment.center);
    });

    test('null textAlignment falls through to implicit', () {
      // When no explicit alignment is set, implicit should be used.
      const style = CellStyle();
      final merged = CellStyle.defaultStyle.merge(style);
      expect(merged.textAlignment, isNull);
      // The caller would then use implicitAlignment based on value type.
    });
  });
}
