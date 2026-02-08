import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/border_resolver.dart';
import 'package:worksheet/src/core/models/cell_style.dart';

void main() {
  group('BorderResolver', () {
    test('both none returns b', () {
      final result = BorderResolver.resolve(BorderStyle.none, BorderStyle.none);
      expect(result.isNone, isTrue);
    });

    test('a none, b non-none returns b', () {
      const b = BorderStyle(width: 1.0);
      final result = BorderResolver.resolve(BorderStyle.none, b);
      expect(result, b);
    });

    test('a non-none, b none returns a', () {
      const a = BorderStyle(width: 1.0);
      final result = BorderResolver.resolve(a, BorderStyle.none);
      expect(result, a);
    });

    test('thicker border wins', () {
      const thin = BorderStyle(width: 1.0);
      const thick = BorderStyle(width: 2.0);

      expect(BorderResolver.resolve(thick, thin), thick);
      expect(BorderResolver.resolve(thin, thick), thick);
    });

    test('same width, higher priority line style wins', () {
      const solid = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);
      const dashed = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.dashed);
      const dotted = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.dotted);
      const double_ = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.double);

      // double > solid
      expect(BorderResolver.resolve(solid, double_), double_);
      expect(BorderResolver.resolve(double_, solid), double_);

      // solid > dashed
      expect(BorderResolver.resolve(dashed, solid), solid);
      expect(BorderResolver.resolve(solid, dashed), solid);

      // dashed > dotted
      expect(BorderResolver.resolve(dotted, dashed), dashed);
      expect(BorderResolver.resolve(dashed, dotted), dashed);
    });

    test('all equal returns b (later cell in reading order)', () {
      const a = BorderStyle(
        width: 1.0,
        color: Color(0xFFFF0000),
        lineStyle: BorderLineStyle.solid,
      );
      const b = BorderStyle(
        width: 1.0,
        color: Color(0xFF0000FF),
        lineStyle: BorderLineStyle.solid,
      );

      expect(BorderResolver.resolve(a, b), b);
    });

    test('width takes priority over line style', () {
      const thickDotted = BorderStyle(
        width: 3.0,
        lineStyle: BorderLineStyle.dotted,
      );
      const thinDouble = BorderStyle(
        width: 1.0,
        lineStyle: BorderLineStyle.double,
      );

      expect(BorderResolver.resolve(thickDotted, thinDouble), thickDotted);
    });

    test('none lineStyle with non-zero width is still none', () {
      const noneStyle = BorderStyle(
        width: 1.0,
        lineStyle: BorderLineStyle.none,
      );
      expect(noneStyle.isNone, isTrue);

      const solid = BorderStyle(width: 1.0);
      expect(BorderResolver.resolve(noneStyle, solid), solid);
    });
  });
}
