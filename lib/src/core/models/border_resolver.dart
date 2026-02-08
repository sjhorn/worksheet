import 'cell_style.dart';

/// Resolves which border wins when adjacent cells share an edge.
///
/// Rules (matching Excel/Google Sheets):
/// 1. Non-none wins over none
/// 2. Thicker border wins
/// 3. Same width → higher-priority line style wins
///    (`double` > `solid` > `dashed` > `dotted`)
/// 4. All equal → [b] wins (right/bottom neighbor, i.e. the later cell
///    in reading order)
class BorderResolver {
  const BorderResolver._();

  /// Resolves two adjacent borders into the winning border.
  ///
  /// [a] is the border from the earlier cell (left or top neighbor).
  /// [b] is the border from the later cell (right or bottom neighbor).
  static BorderStyle resolve(BorderStyle a, BorderStyle b) {
    final aNone = a.isNone;
    final bNone = b.isNone;

    // Rule 1: non-none wins over none
    if (aNone && bNone) return b;
    if (aNone) return b;
    if (bNone) return a;

    // Rule 2: thicker border wins
    if (a.width > b.width) return a;
    if (b.width > a.width) return b;

    // Rule 3: higher-priority line style wins
    if (a.lineStyle.index > b.lineStyle.index) return a;
    if (b.lineStyle.index > a.lineStyle.index) return b;

    // Rule 4: all equal → b wins (later cell in reading order)
    return b;
  }
}
