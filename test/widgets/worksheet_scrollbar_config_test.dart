import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/widgets/worksheet_scrollbar_config.dart';

void main() {
  group('ScrollbarVisibility', () {
    test('has all expected values', () {
      expect(ScrollbarVisibility.values, hasLength(3));
      expect(ScrollbarVisibility.values, contains(ScrollbarVisibility.always));
      expect(ScrollbarVisibility.values, contains(ScrollbarVisibility.onScroll));
      expect(ScrollbarVisibility.values, contains(ScrollbarVisibility.never));
    });
  });

  group('WorksheetScrollbarConfig', () {
    test('default constructor has always for both axes', () {
      const config = WorksheetScrollbarConfig();
      expect(config.verticalVisibility, ScrollbarVisibility.always);
      expect(config.horizontalVisibility, ScrollbarVisibility.always);
      expect(config.interactive, isTrue);
      expect(config.thickness, isNull);
      expect(config.radius, isNull);
    });

    test('desktop preset matches default constructor', () {
      const config = WorksheetScrollbarConfig.desktop;
      expect(config.verticalVisibility, ScrollbarVisibility.always);
      expect(config.horizontalVisibility, ScrollbarVisibility.always);
      expect(config.interactive, isTrue);
    });

    test('mobile preset has onScroll for both axes', () {
      const config = WorksheetScrollbarConfig.mobile;
      expect(config.verticalVisibility, ScrollbarVisibility.onScroll);
      expect(config.horizontalVisibility, ScrollbarVisibility.onScroll);
      expect(config.interactive, isTrue);
    });

    test('none preset has never for both axes', () {
      const config = WorksheetScrollbarConfig.none;
      expect(config.verticalVisibility, ScrollbarVisibility.never);
      expect(config.horizontalVisibility, ScrollbarVisibility.never);
    });

    test('custom thickness and radius are preserved', () {
      const config = WorksheetScrollbarConfig(
        thickness: 12.0,
        radius: Radius.circular(4.0),
      );
      expect(config.thickness, 12.0);
      expect(config.radius, const Radius.circular(4.0));
    });

    test('interactive can be disabled', () {
      const config = WorksheetScrollbarConfig(interactive: false);
      expect(config.interactive, isFalse);
    });

    test('axes can be configured independently', () {
      const config = WorksheetScrollbarConfig(
        verticalVisibility: ScrollbarVisibility.always,
        horizontalVisibility: ScrollbarVisibility.never,
      );
      expect(config.verticalVisibility, ScrollbarVisibility.always);
      expect(config.horizontalVisibility, ScrollbarVisibility.never);
    });
  });
}
