import '../models/cell.dart';
import '../models/cell_value.dart';

/// The type of fill pattern detected from a sequence of cells.
enum FillPatternType {
  /// Single cell or all identical values - repeat the same value.
  constant,

  /// All numbers with a constant step (e.g. 1, 2, 3 or 10, 20, 30).
  linearNumeric,

  /// All dates with a constant interval (e.g. daily, weekly).
  dateSequence,

  /// Same text prefix with a linear numeric suffix (e.g. Item1, Item2, Item3).
  textWithNumericSuffix,

  /// Treat the entire source as a repeating cycle.
  repeatingCycle,
}

/// A detected fill pattern that can generate values at arbitrary indices.
class FillPattern {
  /// The type of pattern detected.
  final FillPatternType type;

  final Cell? Function(int index) _generator;

  FillPattern._(this.type, this._generator);

  /// Generates the cell value at the given 0-based [index] from the start
  /// of the source sequence.
  Cell? generate(int index) => _generator(index);
}

/// Epsilon tolerance for floating-point step comparison.
const double _epsilon = 1e-10;

/// Detects fill patterns from a list of source cells.
class FillPatternDetector {
  /// Analyzes [sourceCells] and returns the best-matching [FillPattern].
  ///
  /// Detection priority:
  /// 1. Constant (single cell, all identical, or empty)
  /// 2. Linear numeric (all numbers with constant step)
  /// 3. Date sequence (all dates with constant interval)
  /// 4. Text with numeric suffix (same prefix, linear suffix numbers)
  /// 5. Repeating cycle (fallback)
  static FillPattern detect(List<Cell?> sourceCells) {
    if (sourceCells.isEmpty) {
      return FillPattern._(FillPatternType.constant, (_) => null);
    }

    if (sourceCells.length == 1) {
      final cell = sourceCells[0];
      return FillPattern._(FillPatternType.constant, (_) => cell);
    }

    // Check if all cells are identical (including all-null)
    if (_allIdentical(sourceCells)) {
      final cell = sourceCells[0];
      return FillPattern._(FillPatternType.constant, (_) => cell);
    }

    // Try linear numeric
    final linearResult = _tryLinearNumeric(sourceCells);
    if (linearResult != null) return linearResult;

    // Try date sequence
    final dateResult = _tryDateSequence(sourceCells);
    if (dateResult != null) return dateResult;

    // Try text with numeric suffix
    final textSuffixResult = _tryTextWithNumericSuffix(sourceCells);
    if (textSuffixResult != null) return textSuffixResult;

    // Fallback: repeating cycle
    return _repeatingCycle(sourceCells);
  }

  static bool _allIdentical(List<Cell?> cells) {
    final first = cells[0];
    for (int i = 1; i < cells.length; i++) {
      if (cells[i] != first) return false;
    }
    return true;
  }

  static FillPattern? _tryLinearNumeric(List<Cell?> cells) {
    // All cells must have numeric values
    final numbers = <double>[];
    for (final cell in cells) {
      if (cell == null || cell.value == null || !cell.value!.isNumber) {
        return null;
      }
      numbers.add(cell.value!.asDouble);
    }

    // Check constant step
    final step = numbers[1] - numbers[0];
    for (int i = 2; i < numbers.length; i++) {
      if ((numbers[i] - numbers[i - 1] - step).abs() > _epsilon) {
        return null;
      }
    }

    final startValue = numbers[0];
    // Use the first cell's style, format, and richText as template
    final templateStyle = cells[0]?.style;
    final templateFormat = cells[0]?.format;
    final templateRichText = cells[0]?.richText;

    return FillPattern._(FillPatternType.linearNumeric, (index) {
      final value = startValue + step * index;
      return Cell(
        value: CellValue.number(value),
        style: templateStyle,
        format: templateFormat,
        richText: templateRichText,
      );
    });
  }

  static FillPattern? _tryDateSequence(List<Cell?> cells) {
    // All cells must have date values
    final dates = <DateTime>[];
    for (final cell in cells) {
      if (cell == null || cell.value == null || !cell.value!.isDate) {
        return null;
      }
      dates.add(cell.value!.asDateTime);
    }

    // Check constant day interval
    final stepDays = dates[1].difference(dates[0]).inDays;
    if (stepDays == 0) return null;

    for (int i = 2; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays != stepDays) {
        return null;
      }
    }

    final startDate = dates[0];
    final templateStyle = cells[0]?.style;
    final templateFormat = cells[0]?.format;
    final templateRichText = cells[0]?.richText;

    return FillPattern._(FillPatternType.dateSequence, (index) {
      final date = startDate.add(Duration(days: stepDays * index));
      return Cell(
        value: CellValue.date(date),
        style: templateStyle,
        format: templateFormat,
        richText: templateRichText,
      );
    });
  }

  static final _suffixRegex = RegExp(r'^(.*?)(\d+)$');

  static FillPattern? _tryTextWithNumericSuffix(List<Cell?> cells) {
    // All cells must be text with the same prefix and numeric suffix
    final prefixes = <String>[];
    final suffixNumbers = <int>[];

    for (final cell in cells) {
      if (cell == null || cell.value == null || !cell.value!.isText) {
        return null;
      }
      final text = cell.value!.rawValue as String;
      final match = _suffixRegex.firstMatch(text);
      if (match == null) return null;

      prefixes.add(match.group(1)!);
      suffixNumbers.add(int.parse(match.group(2)!));
    }

    // All prefixes must be the same
    final prefix = prefixes[0];
    for (int i = 1; i < prefixes.length; i++) {
      if (prefixes[i] != prefix) return null;
    }

    // Suffix numbers must form a linear sequence
    final step = suffixNumbers[1] - suffixNumbers[0];
    for (int i = 2; i < suffixNumbers.length; i++) {
      if (suffixNumbers[i] - suffixNumbers[i - 1] != step) return null;
    }

    final startSuffix = suffixNumbers[0];
    final templateStyle = cells[0]?.style;
    final templateFormat = cells[0]?.format;
    final templateRichText = cells[0]?.richText;

    return FillPattern._(FillPatternType.textWithNumericSuffix, (index) {
      final suffix = startSuffix + step * index;
      return Cell(
        value: CellValue.text('$prefix$suffix'),
        style: templateStyle,
        format: templateFormat,
        richText: templateRichText,
      );
    });
  }

  static FillPattern _repeatingCycle(List<Cell?> cells) {
    final length = cells.length;
    return FillPattern._(FillPatternType.repeatingCycle, (index) {
      return cells[index % length];
    });
  }
}
