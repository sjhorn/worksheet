import 'package:flutter/widgets.dart';

/// Controls when scrollbars are visible.
enum ScrollbarVisibility {
  /// Always show scrollbars (Windows/Linux default).
  always,

  /// Show only while scrolling, then fade out (macOS/mobile default).
  onScroll,

  /// Never show scrollbars.
  never,
}

/// Configuration for worksheet scrollbar appearance and behavior.
///
/// Controls scrollbar visibility for both axes independently.
/// Use the static presets for common configurations:
/// - [WorksheetScrollbarConfig.desktop] — both scrollbars always visible (Windows/Linux)
/// - [WorksheetScrollbarConfig.mobile] — scrollbars shown on scroll, then fade (macOS/mobile)
/// - [WorksheetScrollbarConfig.none] — no scrollbars
@immutable
class WorksheetScrollbarConfig {
  /// When the vertical scrollbar should be visible.
  final ScrollbarVisibility verticalVisibility;

  /// When the horizontal scrollbar should be visible.
  final ScrollbarVisibility horizontalVisibility;

  /// Whether the scrollbar thumb can be dragged interactively.
  final bool interactive;

  /// Thickness of the scrollbar in logical pixels.
  ///
  /// If null, uses the platform default from [ScrollbarTheme].
  final double? thickness;

  /// Radius of the scrollbar thumb corners.
  ///
  /// If null, uses the platform default from [ScrollbarTheme].
  final Radius? radius;

  const WorksheetScrollbarConfig({
    this.verticalVisibility = ScrollbarVisibility.always,
    this.horizontalVisibility = ScrollbarVisibility.always,
    this.interactive = true,
    this.thickness,
    this.radius,
  });

  /// Desktop default (Windows/Linux): both scrollbars always visible.
  static const desktop = WorksheetScrollbarConfig();

  /// Mobile default: scrollbars shown on scroll, then fade out.
  static const mobile = WorksheetScrollbarConfig(
    verticalVisibility: ScrollbarVisibility.onScroll,
    horizontalVisibility: ScrollbarVisibility.onScroll,
  );

  /// No scrollbars.
  static const none = WorksheetScrollbarConfig(
    verticalVisibility: ScrollbarVisibility.never,
    horizontalVisibility: ScrollbarVisibility.never,
  );
}
