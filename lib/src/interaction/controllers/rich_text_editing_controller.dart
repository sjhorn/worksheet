import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A [TextEditingController] subclass that tracks per-character styles
/// for rich text editing within a worksheet cell.
///
/// Internally maintains a list of [TextStyle?] per character. `null` entries
/// inherit the base cell style. This per-character model makes insert, delete,
/// and selection-based formatting trivial for the small text sizes typical of
/// worksheet cells (tens of characters).
///
/// Conversion to/from `List<TextSpan>` is provided by [initFromSpans] and
/// [toSpans] for integration with the data layer.
class RichTextEditingController extends TextEditingController {
  /// Per-character style. `null` means inherit the base cell style.
  List<TextStyle?> _charStyles = [];

  /// Guard flag: skip style adjustment during [initFromSpans].
  bool _skipAdjust = false;

  /// Style to apply to the next typed character when the selection is collapsed.
  ///
  /// Set by toggling formatting (e.g. Ctrl+B) with no selection. Consumed and
  /// cleared on the next character insert.
  TextStyle? _pendingStyle;

  /// Creates a controller with optional initial text and spans.
  RichTextEditingController({super.text});

  /// The per-character styles (read-only view for testing).
  List<TextStyle?> get charStyles => List.unmodifiable(_charStyles);

  /// The pending style that will be applied to the next typed character.
  ///
  /// Non-null when the user has toggled formatting with a collapsed selection.
  TextStyle? get pendingStyle => _pendingStyle;

  /// Clears the pending style without applying it.
  void clearPendingStyle() {
    _pendingStyle = null;
  }

  /// Initializes from a list of [TextSpan]s, expanding into per-character styles.
  ///
  /// [baseStyle] is the cell-level style that spans inherit from when they
  /// have no explicit style.
  void initFromSpans(List<TextSpan> spans, {TextStyle? baseStyle}) {
    final buffer = StringBuffer();
    final styles = <TextStyle?>[];

    for (final span in spans) {
      final spanText = span.text ?? '';
      buffer.write(spanText);
      for (int i = 0; i < spanText.length; i++) {
        styles.add(span.style);
      }
    }

    _charStyles = styles;
    _skipAdjust = true;
    text = buffer.toString();
    _skipAdjust = false;
  }

  /// Groups consecutive characters with the same style into [TextSpan]s.
  ///
  /// Returns an empty list if the text is empty. Spans with `null` style
  /// are emitted as-is (they inherit from the parent).
  List<TextSpan> toSpans() {
    final currentText = text;
    if (currentText.isEmpty) return [];

    // Ensure charStyles matches text length
    _syncLength();

    final result = <TextSpan>[];
    TextStyle? currentStyle = _charStyles[0];
    int start = 0;

    for (int i = 1; i <= currentText.length; i++) {
      final style = i < currentText.length ? _charStyles[i] : null;
      if (i == currentText.length || style != currentStyle) {
        result.add(TextSpan(
          text: currentText.substring(start, i),
          style: currentStyle,
        ));
        if (i < currentText.length) {
          currentStyle = style;
          start = i;
        }
      }
    }

    return result;
  }

  /// Whether the controller has any non-null per-character styles.
  bool get hasRichStyles => _charStyles.any((s) => s != null);

  /// Toggles bold on the current selection.
  ///
  /// If all characters in the selection are bold, removes bold.
  /// Otherwise, applies bold to all characters in the selection.
  void toggleBold() {
    _toggleProperty(
      getter: (s) => s?.fontWeight == FontWeight.bold,
      apply: (s) =>
          (s ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold),
      remove: (s) =>
          (s ?? const TextStyle()).copyWith(fontWeight: FontWeight.normal),
    );
  }

  /// Toggles italic on the current selection.
  void toggleItalic() {
    _toggleProperty(
      getter: (s) => s?.fontStyle == FontStyle.italic,
      apply: (s) =>
          (s ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic),
      remove: (s) =>
          (s ?? const TextStyle()).copyWith(fontStyle: FontStyle.normal),
    );
  }

  /// Toggles underline on the current selection.
  void toggleUnderline() {
    _toggleProperty(
      getter: (s) =>
          s?.decoration == TextDecoration.underline ||
          (s?.decoration != null &&
              s!.decoration!.contains(TextDecoration.underline)),
      apply: (s) {
        final existing = s ?? const TextStyle();
        final currentDec = existing.decoration;
        if (currentDec == null ||
            currentDec == TextDecoration.none) {
          return existing.copyWith(decoration: TextDecoration.underline);
        }
        return existing.copyWith(
          decoration: TextDecoration.combine([currentDec, TextDecoration.underline]),
        );
      },
      remove: (s) {
        final existing = s ?? const TextStyle();
        final currentDec = existing.decoration;
        if (currentDec == TextDecoration.underline) {
          return existing.copyWith(decoration: TextDecoration.none);
        }
        // Remove underline but keep other decorations
        if (currentDec != null) {
          final decorations = <TextDecoration>[];
          if (currentDec.contains(TextDecoration.lineThrough)) {
            decorations.add(TextDecoration.lineThrough);
          }
          if (currentDec.contains(TextDecoration.overline)) {
            decorations.add(TextDecoration.overline);
          }
          return existing.copyWith(
            decoration: decorations.isEmpty
                ? TextDecoration.none
                : TextDecoration.combine(decorations),
          );
        }
        return existing.copyWith(decoration: TextDecoration.none);
      },
    );
  }

  /// Toggles strikethrough on the current selection.
  void toggleStrikethrough() {
    _toggleProperty(
      getter: (s) =>
          s?.decoration == TextDecoration.lineThrough ||
          (s?.decoration != null &&
              s!.decoration!.contains(TextDecoration.lineThrough)),
      apply: (s) {
        final existing = s ?? const TextStyle();
        final currentDec = existing.decoration;
        if (currentDec == null ||
            currentDec == TextDecoration.none) {
          return existing.copyWith(decoration: TextDecoration.lineThrough);
        }
        return existing.copyWith(
          decoration: TextDecoration.combine([currentDec, TextDecoration.lineThrough]),
        );
      },
      remove: (s) {
        final existing = s ?? const TextStyle();
        final currentDec = existing.decoration;
        if (currentDec == TextDecoration.lineThrough) {
          return existing.copyWith(decoration: TextDecoration.none);
        }
        if (currentDec != null) {
          final decorations = <TextDecoration>[];
          if (currentDec.contains(TextDecoration.underline)) {
            decorations.add(TextDecoration.underline);
          }
          if (currentDec.contains(TextDecoration.overline)) {
            decorations.add(TextDecoration.overline);
          }
          return existing.copyWith(
            decoration: decorations.isEmpty
                ? TextDecoration.none
                : TextDecoration.combine(decorations),
          );
        }
        return existing.copyWith(decoration: TextDecoration.none);
      },
    );
  }

  /// Sets the text color on the current selection.
  void setColor(Color color) {
    _applyToSelection((s) => (s ?? const TextStyle()).copyWith(color: color));
  }

  /// Sets the font size on the current selection.
  void setFontSize(double size) {
    _applyToSelection((s) => (s ?? const TextStyle()).copyWith(fontSize: size));
  }

  /// Sets the font family on the current selection.
  void setFontFamily(String family) {
    _applyToSelection(
        (s) => (s ?? const TextStyle()).copyWith(fontFamily: family));
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    if (!_skipAdjust && oldText != newText) {
      _adjustCharStylesForEdit(oldText, newText);
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(text: currentText, style: style);
    }

    _syncLength();

    // If no rich styles, return a simple text span
    if (!_charStyles.any((s) => s != null)) {
      return TextSpan(text: currentText, style: style);
    }

    // Build spans grouped by consecutive same style
    final children = <TextSpan>[];
    TextStyle? currentCharStyle = _charStyles[0];
    int start = 0;

    for (int i = 1; i <= currentText.length; i++) {
      final charStyle = i < currentText.length ? _charStyles[i] : null;
      if (i == currentText.length || charStyle != currentCharStyle) {
        children.add(TextSpan(
          text: currentText.substring(start, i),
          style: currentCharStyle,
        ));
        if (i < currentText.length) {
          currentCharStyle = charStyle;
          start = i;
        }
      }
    }

    // Handle composing region for IME
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      // Just return with children — composing decoration is handled by the
      // framework's EditableText which wraps composing text with underline.
    }

    return TextSpan(style: style, children: children);
  }

  /// Adjusts [_charStyles] when the text changes due to user typing/deletion.
  ///
  /// Finds the minimal diff between old and new text and splices styles accordingly.
  void _adjustCharStylesForEdit(String oldText, String newText) {
    if (newText.isEmpty) {
      _charStyles = [];
      return;
    }

    if (oldText.isEmpty) {
      _charStyles = List.filled(newText.length, null);
      return;
    }

    // Find common prefix length
    final minLen = math.min(oldText.length, newText.length);
    int commonPrefix = 0;
    while (commonPrefix < minLen &&
        oldText[commonPrefix] == newText[commonPrefix]) {
      commonPrefix++;
    }

    // Find common suffix length
    int commonSuffix = 0;
    while (commonSuffix < (minLen - commonPrefix) &&
        oldText[oldText.length - 1 - commonSuffix] ==
            newText[newText.length - 1 - commonSuffix]) {
      commonSuffix++;
    }

    final oldMiddleLen = oldText.length - commonPrefix - commonSuffix;
    final newMiddleLen = newText.length - commonPrefix - commonSuffix;

    // Ensure _charStyles matches old text length before splicing
    while (_charStyles.length < oldText.length) {
      _charStyles.add(null);
    }
    if (_charStyles.length > oldText.length) {
      _charStyles = _charStyles.sublist(0, oldText.length);
    }

    // Determine the style to use for new inserted characters:
    // Use pending style if set (from collapsed-selection toggle), otherwise
    // inherit the style of the character just before the insertion point.
    final TextStyle? insertStyle;
    if (_pendingStyle != null) {
      insertStyle = _pendingStyle;
      _pendingStyle = null;
    } else {
      insertStyle = commonPrefix > 0 ? _charStyles[commonPrefix - 1] : null;
    }

    // Splice: remove old middle, insert new middle with inherited style
    _charStyles.replaceRange(
      commonPrefix,
      commonPrefix + oldMiddleLen,
      List.filled(newMiddleLen, insertStyle),
    );
  }

  /// Ensures [_charStyles] length matches the current text length.
  void _syncLength() {
    final len = text.length;
    if (_charStyles.length < len) {
      _charStyles.addAll(List.filled(len - _charStyles.length, null));
    } else if (_charStyles.length > len) {
      _charStyles = _charStyles.sublist(0, len);
    }
  }

  /// Toggles a boolean property on the selection.
  ///
  /// When the selection is collapsed (no text selected), toggles the property
  /// on [_pendingStyle] so the next typed character inherits the formatting.
  void _toggleProperty({
    required bool Function(TextStyle?) getter,
    required TextStyle Function(TextStyle?) apply,
    required TextStyle Function(TextStyle?) remove,
  }) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      // Toggle on pending style for future typing.
      _syncLength();
      final current = _pendingStyle ??
          (sel.start > 0 && sel.start <= _charStyles.length
              ? _charStyles[sel.start - 1]
              : null);
      if (getter(current)) {
        _pendingStyle = remove(current);
      } else {
        _pendingStyle = apply(current);
      }
      notifyListeners();
      return;
    }

    _syncLength();

    final start = sel.start;
    final end = sel.end;

    // Check if all chars in selection have the property
    bool allHave = true;
    for (int i = start; i < end; i++) {
      if (!getter(_charStyles[i])) {
        allHave = false;
        break;
      }
    }

    for (int i = start; i < end; i++) {
      _charStyles[i] = allHave ? remove(_charStyles[i]) : apply(_charStyles[i]);
    }

    notifyListeners();
  }

  /// Applies a style transformation to all characters in the current selection.
  void _applyToSelection(TextStyle Function(TextStyle?) transform) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    _syncLength();

    for (int i = sel.start; i < sel.end; i++) {
      _charStyles[i] = transform(_charStyles[i]);
    }

    notifyListeners();
  }
}
