import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/models/cell_style.dart';
import '../rendering/painters/header_renderer.dart';
import '../rendering/painters/selection_renderer.dart';

/// Theme data for worksheet appearance.
///
/// Contains all configurable visual properties for the worksheet widget.
@immutable
class WorksheetThemeData {
  /// The package name used to resolve bundled font assets.
  static const String packageName = 'worksheet';

  /// Returns `'worksheet'` when [fontFamily] is the bundled default,
  /// `null` otherwise (so consumer-provided fonts resolve from the app).
  static String? resolveFontPackage(String fontFamily) {
    return fontFamily == CellStyle.defaultFontFamily ? packageName : null;
  }

  /// The selection style (highlight color, border, etc.).
  final SelectionStyle selectionStyle;

  /// The header style (background, text, borders).
  final HeaderStyle headerStyle;

  /// The gridline color.
  final Color gridlineColor;

  /// The gridline width.
  final double gridlineWidth;

  /// The default cell background color.
  final Color cellBackgroundColor;

  /// The default text color.
  final Color textColor;

  /// The default font size for cell content.
  final double fontSize;

  /// The default font family for cell content.
  final String fontFamily;

  /// The width of the row header area.
  final double rowHeaderWidth;

  /// The height of the column header area.
  final double columnHeaderHeight;

  /// The default row height.
  final double defaultRowHeight;

  /// The default column width.
  final double defaultColumnWidth;

  /// Cell padding in pixels.
  final double cellPadding;

  /// Whether to show gridlines.
  final bool showGridlines;

  /// Whether to show row/column headers.
  final bool showHeaders;

  const WorksheetThemeData({
    this.selectionStyle = SelectionStyle.defaultStyle,
    this.headerStyle = HeaderStyle.defaultStyle,
    this.gridlineColor = const Color(0xFFD4D4D4),
    this.gridlineWidth = 1.0,
    this.cellBackgroundColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF000000),
    this.fontSize = 14.0,
    this.fontFamily = CellStyle.defaultFontFamily,
    this.rowHeaderWidth = 50.0,
    this.columnHeaderHeight = 24.0,
    this.defaultRowHeight = 24.0,
    this.defaultColumnWidth = 100.0,
    this.cellPadding = 4.0,
    this.showGridlines = true,
    this.showHeaders = true,
  });

  /// Default worksheet theme.
  static const WorksheetThemeData defaultTheme = WorksheetThemeData();

  /// Creates a copy with optionally modified fields.
  WorksheetThemeData copyWith({
    SelectionStyle? selectionStyle,
    HeaderStyle? headerStyle,
    Color? gridlineColor,
    double? gridlineWidth,
    Color? cellBackgroundColor,
    Color? textColor,
    double? fontSize,
    String? fontFamily,
    double? rowHeaderWidth,
    double? columnHeaderHeight,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    double? cellPadding,
    bool? showGridlines,
    bool? showHeaders,
  }) {
    return WorksheetThemeData(
      selectionStyle: selectionStyle ?? this.selectionStyle,
      headerStyle: headerStyle ?? this.headerStyle,
      gridlineColor: gridlineColor ?? this.gridlineColor,
      gridlineWidth: gridlineWidth ?? this.gridlineWidth,
      cellBackgroundColor: cellBackgroundColor ?? this.cellBackgroundColor,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      rowHeaderWidth: rowHeaderWidth ?? this.rowHeaderWidth,
      columnHeaderHeight: columnHeaderHeight ?? this.columnHeaderHeight,
      defaultRowHeight: defaultRowHeight ?? this.defaultRowHeight,
      defaultColumnWidth: defaultColumnWidth ?? this.defaultColumnWidth,
      cellPadding: cellPadding ?? this.cellPadding,
      showGridlines: showGridlines ?? this.showGridlines,
      showHeaders: showHeaders ?? this.showHeaders,
    );
  }

  /// Linearly interpolates between two worksheet themes.
  static WorksheetThemeData lerp(
    WorksheetThemeData a,
    WorksheetThemeData b,
    double t,
  ) {
    // For non-color properties, use the closer value
    return WorksheetThemeData(
      selectionStyle: t < 0.5 ? a.selectionStyle : b.selectionStyle,
      headerStyle: t < 0.5 ? a.headerStyle : b.headerStyle,
      gridlineColor: Color.lerp(a.gridlineColor, b.gridlineColor, t)!,
      gridlineWidth: lerpDouble(a.gridlineWidth, b.gridlineWidth, t)!,
      cellBackgroundColor:
          Color.lerp(a.cellBackgroundColor, b.cellBackgroundColor, t)!,
      textColor: Color.lerp(a.textColor, b.textColor, t)!,
      fontSize: lerpDouble(a.fontSize, b.fontSize, t)!,
      fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
      rowHeaderWidth: lerpDouble(a.rowHeaderWidth, b.rowHeaderWidth, t)!,
      columnHeaderHeight:
          lerpDouble(a.columnHeaderHeight, b.columnHeaderHeight, t)!,
      defaultRowHeight: lerpDouble(a.defaultRowHeight, b.defaultRowHeight, t)!,
      defaultColumnWidth:
          lerpDouble(a.defaultColumnWidth, b.defaultColumnWidth, t)!,
      cellPadding: lerpDouble(a.cellPadding, b.cellPadding, t)!,
      showGridlines: t < 0.5 ? a.showGridlines : b.showGridlines,
      showHeaders: t < 0.5 ? a.showHeaders : b.showHeaders,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorksheetThemeData &&
        other.selectionStyle == selectionStyle &&
        other.headerStyle == headerStyle &&
        other.gridlineColor == gridlineColor &&
        other.gridlineWidth == gridlineWidth &&
        other.cellBackgroundColor == cellBackgroundColor &&
        other.textColor == textColor &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.rowHeaderWidth == rowHeaderWidth &&
        other.columnHeaderHeight == columnHeaderHeight &&
        other.defaultRowHeight == defaultRowHeight &&
        other.defaultColumnWidth == defaultColumnWidth &&
        other.cellPadding == cellPadding &&
        other.showGridlines == showGridlines &&
        other.showHeaders == showHeaders;
  }

  @override
  int get hashCode => Object.hash(
        selectionStyle,
        headerStyle,
        gridlineColor,
        gridlineWidth,
        cellBackgroundColor,
        textColor,
        fontSize,
        fontFamily,
        rowHeaderWidth,
        columnHeaderHeight,
        defaultRowHeight,
        defaultColumnWidth,
        cellPadding,
        showGridlines,
        showHeaders,
      );
}

/// An inherited widget that provides [WorksheetThemeData] to its descendants.
///
/// Use [WorksheetTheme.of] to access the theme data from a descendant widget.
class WorksheetTheme extends InheritedWidget {
  /// The theme data.
  final WorksheetThemeData data;

  const WorksheetTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// Returns the [WorksheetThemeData] from the closest [WorksheetTheme] ancestor.
  ///
  /// If there is no [WorksheetTheme] ancestor, returns [WorksheetThemeData.defaultTheme].
  static WorksheetThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<WorksheetTheme>();
    return theme?.data ?? WorksheetThemeData.defaultTheme;
  }

  /// Returns the [WorksheetThemeData] from the closest [WorksheetTheme] ancestor,
  /// or null if there is no ancestor.
  static WorksheetThemeData? maybeOf(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<WorksheetTheme>();
    return theme?.data;
  }

  @override
  bool updateShouldNotify(WorksheetTheme oldWidget) {
    return data != oldWidget.data;
  }
}
