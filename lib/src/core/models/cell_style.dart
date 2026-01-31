// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:ui';

import 'package:flutter/foundation.dart';

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

  const BorderStyle({
    this.color = const Color(0xFF000000),
    this.width = 1.0,
  });

  static const BorderStyle none = BorderStyle(width: 0);

  bool get isNone => width == 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorderStyle && other.color == color && other.width == width;
  }

  @override
  int get hashCode => Object.hash(color, width);
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
@immutable
class CellStyle {
  /// Background color of the cell.
  final Color? backgroundColor;

  /// Font family for text rendering.
  final String? fontFamily;

  /// Font size in logical pixels.
  final double? fontSize;

  /// Font weight (normal, bold, etc.).
  final FontWeight? fontWeight;

  /// Font style (normal, italic).
  final FontStyle? fontStyle;

  /// Text color.
  final Color? textColor;

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
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.textColor,
    this.textAlignment,
    this.verticalAlignment,
    this.borders,
    this.wrapText,
    this.numberFormat,
  });

  /// Default style with standard worksheet appearance.
  static const CellStyle defaultStyle = CellStyle(
    fontFamily: 'Roboto',
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    textColor: Color(0xFF000000),
    textAlignment: CellTextAlignment.left,
    verticalAlignment: CellVerticalAlignment.middle,
    borders: CellBorders.none,
    wrapText: false,
  );

  /// Merges this style with [other], with [other] taking precedence.
  CellStyle merge(CellStyle? other) {
    if (other == null) return this;

    return CellStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      fontFamily: other.fontFamily ?? fontFamily,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      textColor: other.textColor ?? textColor,
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
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? textColor,
    CellTextAlignment? textAlignment,
    CellVerticalAlignment? verticalAlignment,
    CellBorders? borders,
    bool? wrapText,
    String? numberFormat,
  }) {
    return CellStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      textColor: textColor ?? this.textColor,
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
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.fontStyle == fontStyle &&
        other.textColor == textColor &&
        other.textAlignment == textAlignment &&
        other.verticalAlignment == verticalAlignment &&
        other.borders == borders &&
        other.wrapText == wrapText &&
        other.numberFormat == numberFormat;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        fontFamily,
        fontSize,
        fontWeight,
        fontStyle,
        textColor,
        textAlignment,
        verticalAlignment,
        borders,
        wrapText,
        numberFormat,
      );
}
