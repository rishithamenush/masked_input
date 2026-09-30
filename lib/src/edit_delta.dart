/// Returns the scalar starting at a known UTF-16 scalar boundary.
String scalarAt(String text, int offset) {
  final unit = text.codeUnitAt(offset);
  final end = unit >= 0xd800 &&
          unit <= 0xdbff &&
          offset + 1 < text.length &&
          text.codeUnitAt(offset + 1) >= 0xdc00 &&
          text.codeUnitAt(offset + 1) <= 0xdfff
      ? offset + 2
      : offset + 1;
  return text.substring(offset, end);
}

/// Snaps a UTF-16 offset to a scalar boundary, clamping out-of-range offsets.
int scalarBoundary(String text, int offset, {bool forward = false}) {
  var result = offset.clamp(0, text.length);
  if (result > 0 && result < text.length) {
    final left = text.codeUnitAt(result - 1);
    final right = text.codeUnitAt(result);
    if (left >= 0xd800 &&
        left <= 0xdbff &&
        right >= 0xdc00 &&
        right <= 0xdfff) {
      result += forward ? 1 : -1;
    }
  }
  return result;
}

/// A contiguous replacement inferred from framework editing values.
class EditDelta {
  /// Creates a replacement of [start] through [end] with [inserted].
  const EditDelta(this.start, this.end, this.inserted);

  /// Inclusive UTF-16 start in the old text.
  final int start;

  /// Exclusive UTF-16 end in the old text.
  final int end;

  /// Replacement text from the new value.
  final String inserted;

  /// Infers intent, preferring the old selection and new caret over a plain diff.
  static EditDelta between(String oldText, String newText, int base, int extent,
      {int? newExtent}) {
    final start = scalarBoundary(oldText, base < extent ? base : extent);
    final end =
        scalarBoundary(oldText, base > extent ? base : extent, forward: true);
    // Prefer the known selection, avoiding ambiguous diffs such as 111 -> 1111.
    final prefix = oldText.substring(0, start);
    final suffix = oldText.substring(end);
    if (base >= 0 &&
        extent >= 0 &&
        newText.length >= prefix.length + suffix.length &&
        newText.startsWith(prefix) &&
        newText.endsWith(suffix)) {
      return EditDelta(start, end,
          newText.substring(prefix.length, newText.length - suffix.length));
    }
    var left = 0;
    while (left < oldText.length &&
        left < newText.length &&
        oldText.codeUnitAt(left) == newText.codeUnitAt(left)) {
      left++;
    }
    left = scalarBoundary(oldText, scalarBoundary(newText, left));
    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > left &&
        newEnd > left &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    oldEnd = scalarBoundary(oldText, oldEnd, forward: true);
    newEnd = scalarBoundary(newText, newEnd, forward: true);
    // Anchor single-direction deletion to the caret when repeated text admits
    // more than one equivalent diff.
    final removed = oldText.length - newText.length;
    if (base == extent && base >= 0 && removed > 0) {
      final caret = scalarBoundary(oldText, base);
      final back = scalarBoundary(oldText, caret - removed);
      if ((newExtent == null || newExtent < caret) &&
          caret >= removed &&
          oldText.replaceRange(back, caret, '') == newText) {
        return EditDelta(back, caret, '');
      }
      final next = scalarBoundary(oldText, caret + removed, forward: true);
      if (oldText.replaceRange(caret, next, '') == newText) {
        return EditDelta(caret, next, '');
      }
    }
    return EditDelta(left, oldEnd, newText.substring(left, newEnd));
  }
}
