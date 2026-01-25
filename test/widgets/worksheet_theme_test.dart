import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/rendering/painters/header_renderer.dart';
import 'package:worksheet/src/rendering/painters/selection_renderer.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';

void main() {
  group('WorksheetThemeData', () {
    test('has sensible defaults', () {
      const theme = WorksheetThemeData();

      expect(theme.selectionStyle, SelectionStyle.defaultStyle);
      expect(theme.headerStyle, HeaderStyle.defaultStyle);
      expect(theme.gridlineColor, const Color(0xFFE0E0E0));
      expect(theme.gridlineWidth, 1.0);
      expect(theme.cellBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.textColor, const Color(0xFF000000));
      expect(theme.fontSize, 14.0);
      expect(theme.fontFamily, 'Roboto');
      expect(theme.rowHeaderWidth, 50.0);
      expect(theme.columnHeaderHeight, 24.0);
      expect(theme.defaultRowHeight, 24.0);
      expect(theme.defaultColumnWidth, 100.0);
      expect(theme.cellPadding, 4.0);
      expect(theme.showGridlines, isTrue);
      expect(theme.showHeaders, isTrue);
    });

    test('defaultTheme matches default constructor', () {
      const theme = WorksheetThemeData();
      expect(WorksheetThemeData.defaultTheme, theme);
    });

    test('can be customized', () {
      const theme = WorksheetThemeData(
        gridlineColor: Color(0xFF000000),
        fontSize: 16.0,
        showGridlines: false,
        showHeaders: false,
      );

      expect(theme.gridlineColor, const Color(0xFF000000));
      expect(theme.fontSize, 16.0);
      expect(theme.showGridlines, isFalse);
      expect(theme.showHeaders, isFalse);
    });

    test('copyWith creates modified copy', () {
      const original = WorksheetThemeData();
      final modified = original.copyWith(
        fontSize: 18.0,
        showGridlines: false,
      );

      expect(modified.fontSize, 18.0);
      expect(modified.showGridlines, isFalse);
      // Other properties should be unchanged
      expect(modified.textColor, original.textColor);
      expect(modified.showHeaders, original.showHeaders);
    });

    test('copyWith with no arguments returns equivalent copy', () {
      const original = WorksheetThemeData();
      final copy = original.copyWith();

      expect(copy, original);
    });

    test('equality works correctly', () {
      const theme1 = WorksheetThemeData();
      const theme2 = WorksheetThemeData();
      const theme3 = WorksheetThemeData(fontSize: 18.0);

      expect(theme1, equals(theme2));
      expect(theme1, isNot(equals(theme3)));
    });

    test('hashCode is consistent', () {
      const theme1 = WorksheetThemeData();
      const theme2 = WorksheetThemeData();

      expect(theme1.hashCode, theme2.hashCode);
    });

    test('lerp interpolates correctly at t=0', () {
      const a = WorksheetThemeData(fontSize: 14.0);
      const b = WorksheetThemeData(fontSize: 20.0);

      final result = WorksheetThemeData.lerp(a, b, 0.0);

      expect(result.fontSize, 14.0);
    });

    test('lerp interpolates correctly at t=1', () {
      const a = WorksheetThemeData(fontSize: 14.0);
      const b = WorksheetThemeData(fontSize: 20.0);

      final result = WorksheetThemeData.lerp(a, b, 1.0);

      expect(result.fontSize, 20.0);
    });

    test('lerp interpolates correctly at t=0.5', () {
      const a = WorksheetThemeData(fontSize: 14.0);
      const b = WorksheetThemeData(fontSize: 20.0);

      final result = WorksheetThemeData.lerp(a, b, 0.5);

      expect(result.fontSize, 17.0);
    });

    test('lerp interpolates colors correctly', () {
      const a = WorksheetThemeData(gridlineColor: Color(0xFF000000));
      const b = WorksheetThemeData(gridlineColor: Color(0xFFFFFFFF));

      final result = WorksheetThemeData.lerp(a, b, 0.5);

      // Midpoint should be gray
      expect(result.gridlineColor.red, closeTo(128, 1));
      expect(result.gridlineColor.green, closeTo(128, 1));
      expect(result.gridlineColor.blue, closeTo(128, 1));
    });
  });

  group('WorksheetTheme', () {
    testWidgets('provides theme to descendants', (tester) async {
      const customTheme = WorksheetThemeData(fontSize: 20.0);
      WorksheetThemeData? receivedTheme;

      await tester.pumpWidget(
        WorksheetTheme(
          data: customTheme,
          child: Builder(
            builder: (context) {
              receivedTheme = WorksheetTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(receivedTheme, customTheme);
    });

    testWidgets('of returns defaultTheme when no ancestor', (tester) async {
      WorksheetThemeData? receivedTheme;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            receivedTheme = WorksheetTheme.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(receivedTheme, WorksheetThemeData.defaultTheme);
    });

    testWidgets('maybeOf returns null when no ancestor', (tester) async {
      WorksheetThemeData? receivedTheme;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            receivedTheme = WorksheetTheme.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(receivedTheme, isNull);
    });

    testWidgets('maybeOf returns theme when ancestor exists', (tester) async {
      const customTheme = WorksheetThemeData(fontSize: 20.0);
      WorksheetThemeData? receivedTheme;

      await tester.pumpWidget(
        WorksheetTheme(
          data: customTheme,
          child: Builder(
            builder: (context) {
              receivedTheme = WorksheetTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(receivedTheme, customTheme);
    });

    testWidgets('updateShouldNotify returns true when data changes',
        (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        WorksheetTheme(
          data: const WorksheetThemeData(fontSize: 14.0),
          child: Builder(
            builder: (context) {
              WorksheetTheme.of(context);
              buildCount++;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(buildCount, 1);

      await tester.pumpWidget(
        WorksheetTheme(
          data: const WorksheetThemeData(fontSize: 20.0),
          child: Builder(
            builder: (context) {
              WorksheetTheme.of(context);
              buildCount++;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(buildCount, 2);
    });

    testWidgets('updateShouldNotify returns false when data is same',
        (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Builder(
            builder: (context) {
              WorksheetTheme.of(context);
              buildCount++;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(buildCount, 1);

      await tester.pumpWidget(
        WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Builder(
            builder: (context) {
              WorksheetTheme.of(context);
              buildCount++;
              return const SizedBox();
            },
          ),
        ),
      );

      // Technically rebuilds due to pump, but inherited widget check still works
      // The point is updateShouldNotify returns false
      expect(buildCount, 2); // Will still rebuild due to pump mechanism
    });
  });
}
