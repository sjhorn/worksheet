/// Efficient cumulative size storage for O(log n) position lookups.
///
/// SpanList stores row or column sizes and maintains a cumulative sum array
/// for fast position-to-index and index-to-position conversions.
class SpanList {
  /// The number of spans (rows or columns).
  final int count;

  /// The default size for spans without custom sizes.
  final double defaultSize;

  /// Individual sizes for each span.
  final List<double> _sizes;

  /// Cumulative positions for each span (position where span i starts).
  /// Has length count + 1, where the last element is totalSize.
  late List<double> _cumulative;

  /// Creates a span list with the given [count] and [defaultSize].
  ///
  /// Optionally provide [customSizes] to override sizes at specific indices.
  SpanList({
    required this.count,
    required this.defaultSize,
    Map<int, double>? customSizes,
  })  : assert(count > 0, 'Count must be positive'),
        assert(defaultSize > 0, 'Default size must be positive'),
        _sizes = List<double>.filled(count, defaultSize) {
    // Apply custom sizes
    if (customSizes != null) {
      for (final entry in customSizes.entries) {
        if (entry.key >= 0 && entry.key < count) {
          _sizes[entry.key] = entry.value;
        }
      }
    }

    _rebuildCumulative();
  }

  /// Rebuilds the cumulative position array.
  void _rebuildCumulative() {
    _cumulative = List<double>.filled(count + 1, 0.0);
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      _cumulative[i] = sum;
      sum += _sizes[i];
    }
    _cumulative[count] = sum;
  }

  /// Returns the size of the span at [index].
  ///
  /// Throws [RangeError] if index is out of bounds.
  double sizeAt(int index) {
    RangeError.checkValidIndex(index, _sizes);
    return _sizes[index];
  }

  /// Returns the position (offset from start) where span [index] begins.
  ///
  /// [index] can be from 0 to count inclusive. Index == count returns totalSize.
  /// Throws [RangeError] if index is out of bounds.
  double positionAt(int index) {
    RangeError.checkValueInInterval(index, 0, count, 'index');
    return _cumulative[index];
  }

  /// Returns the index of the span containing [position].
  ///
  /// Uses binary search for O(log n) performance.
  /// Returns -1 if position is negative or >= totalSize.
  int indexAtPosition(double position) {
    if (position < 0 || position >= totalSize) {
      return -1;
    }

    // Binary search for the largest index where cumulative[index] <= position
    var low = 0;
    var high = count - 1;

    while (low < high) {
      final mid = low + ((high - low + 1) >> 1);
      if (_cumulative[mid] <= position) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  /// Sets the size of the span at [index] and rebuilds cumulative sums.
  ///
  /// Throws [RangeError] if index is out of bounds.
  /// Throws [AssertionError] if size is not positive.
  void setSize(int index, double size) {
    RangeError.checkValidIndex(index, _sizes);
    assert(size > 0, 'Size must be positive');

    _sizes[index] = size;
    _rebuildCumulative();
  }

  /// The total size of all spans.
  double get totalSize => _cumulative[count];

  /// Returns the range of indices that intersect with the given position range.
  SpanRange getRange(double startPosition, double endPosition) {
    final startIndex = indexAtPosition(startPosition);
    final endIndex = indexAtPosition(endPosition - 0.001);

    // Clamp to valid range
    final clampedStart = startIndex < 0 ? 0 : startIndex;
    final clampedEnd = endIndex < 0 ? count - 1 : endIndex;

    return SpanRange(clampedStart, clampedEnd);
  }
}

/// A range of span indices.
class SpanRange {
  /// The starting index (inclusive).
  final int startIndex;

  /// The ending index (inclusive).
  final int endIndex;

  const SpanRange(this.startIndex, this.endIndex);

  /// The number of indices in this range.
  int get length => endIndex - startIndex + 1;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpanRange &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex;
  }

  @override
  int get hashCode => Object.hash(startIndex, endIndex);

  @override
  String toString() => 'SpanRange($startIndex, $endIndex)';
}
