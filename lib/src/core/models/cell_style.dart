// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'cell_value.dart';

/// Line style for cell borders, ordered by priority for conflict resolution.
///
/// When adjacent cells share an edge, the border with the higher-priority
/// line style wins (e.g., `double` beats `solid`).
enum BorderLineStyle {
  none,
  dotted,
  dashed,
  solid,
  double,
}

/// Text alignment options for cell content.
enum CellTextAlignment {
  left,
  center,
  right,
}

/// Vertical alignment options for cell content.
enum CellVerticalAlignment {
  top,
  middle,
  bottom,
}

/// Border style for cell edges.
@immutable
class BorderStyle {
  /// The color of the border.
  final Color color;

  /// The width of the border.
  final double width;

  /// The line style (solid, dashed, dotted, double).
  final BorderLineStyle lineStyle;

  const BorderStyle({
    this.color = const Color(0xFF000000),
    this.width = 1.0,
    this.lineStyle = BorderLineStyle.solid,
  });

  static const BorderStyle none =
      BorderStyle(width: 0, lineStyle: BorderLineStyle.none);

  bool get isNone => lineStyle == BorderLineStyle.none || width == 0;

  /// Creates a copy with optionally modified fields.
  BorderStyle copyWith({
    Color? color,
    double? width,
    BorderLineStyle? lineStyle,
  }) {
    return BorderStyle(
      color: color ?? this.color,
      width: width ?? this.width,
      lineStyle: lineStyle ?? this.lineStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorderStyle &&
        other.color == color &&
        other.width == width &&
        other.lineStyle == lineStyle;
  }

  @override
  int get hashCode => Object.hash(color, width, lineStyle);
}

/// Border configuration for all four sides of a cell.
@immutable
class CellBorders {
  final BorderStyle top;
  final BorderStyle right;
  final BorderStyle bottom;
  final BorderStyle left;

  const CellBorders({
    this.top = BorderStyle.none,
    this.right = BorderStyle.none,
    this.bottom = BorderStyle.none,
    this.left = BorderStyle.none,
  });

  const CellBorders.all(BorderStyle style)
      : top = style,
        right = style,
        bottom = style,
        left = style;

  static const CellBorders none = CellBorders();

  bool get isNone => top.isNone && right.isNone && bottom.isNone && left.isNone;

  /// Creates a copy with optionally modified fields.
  CellBorders copyWith({
    BorderStyle? top,
    BorderStyle? right,
    BorderStyle? bottom,
    BorderStyle? left,
  }) {
    return CellBorders(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellBorders &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.left == left;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Style configuration for a worksheet cell.
///
/// Contains cell-level concerns only: background color, text alignment,
/// vertical alignment, borders, and text wrapping. Text appearance
/// (font weight, style, size, family, color, underline, strikethrough)
/// is expressed via rich text [TextSpan] styles on the data layer.
@immutable
class CellStyle {
  /// The default font family bundled with the worksheet package.
  static const String defaultFontFamily = 'Roboto';

  /// Background color of the cell.
  final Color? backgroundColor;

  /// Horizontal text alignment.
  final CellTextAlignment? textAlignment;

  /// Vertical text alignment.
  final CellVerticalAlignment? verticalAlignment;

  /// Border configuration.
  final CellBorders? borders;

  /// Whether text should wrap within the cell.
  final bool? wrapText;

  /// Number format pattern (e.g., "#,##0.00", "0%").
  @Deprecated('Use CellFormat on Cell instead. See cell_format.dart.')
  final String? numberFormat;

  const CellStyle({
    this.backgroundColor,
    this.textAlignment,
    this.verticalAlignment,
    this.borders,
    this.wrapText,
    this.numberFormat,
  });

  /// Default style with standard worksheet appearance.
  ///
  /// Note: [textAlignment] is intentionally `null` so that implicit
  /// value-type alignment (numbers right, text left) takes effect
  /// unless the user sets an explicit alignment.
  static const CellStyle defaultStyle = CellStyle(
    verticalAlignment: CellVerticalAlignment.middle,
    borders: CellBorders.none,
    wrapText: false,
  );

  /// Returns the implicit horizontal alignment for a given [CellValueType].
  ///
  /// Numbers, booleans, dates, and durations align right (like Excel/Sheets).
  /// Text, formulas, and errors align left.
  static CellTextAlignment implicitAlignment(CellValueType type) {
    switch (type) {
      case CellValueType.number:
      case CellValueType.boolean:
      case CellValueType.date:
      case CellValueType.duration:
        return CellTextAlignment.right;
      case CellValueType.text:
      case CellValueType.formula:
      case CellValueType.error:
        return CellTextAlignment.left;
    }
  }

  /// Merges this style with [other], with [other] taking precedence.
  CellStyle merge(CellStyle? other) {
    if (other == null) return this;

    return CellStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      textAlignment: other.textAlignment ?? textAlignment,
      verticalAlignment: other.verticalAlignment ?? verticalAlignment,
      borders: other.borders ?? borders,
      wrapText: other.wrapText ?? wrapText,
      numberFormat: other.numberFormat ?? numberFormat,
    );
  }

  /// Creates a copy with optionally modified fields.
  CellStyle copyWith({
    Color? backgroundColor,
    CellTextAlignment? textAlignment,
    CellVerticalAlignment? verticalAlignment,
    CellBorders? borders,
    bool? wrapText,
    String? numberFormat,
  }) {
    return CellStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textAlignment: textAlignment ?? this.textAlignment,
      verticalAlignment: verticalAlignment ?? this.verticalAlignment,
      borders: borders ?? this.borders,
      wrapText: wrapText ?? this.wrapText,
      numberFormat: numberFormat ?? this.numberFormat,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellStyle &&
        other.backgroundColor == backgroundColor &&
        other.textAlignment == textAlignment &&
        other.verticalAlignment == verticalAlignment &&
        other.borders == borders &&
        other.wrapText == wrapText &&
        other.numberFormat == numberFormat;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        textAlignment,
        verticalAlignment,
        borders,
        wrapText,
        numberFormat,
      );
}
