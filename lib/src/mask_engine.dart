import 'mask_definition.dart';
import 'edit_delta.dart';

/// Immutable slot contents and their rendered UTF-16 boundaries.
class MaskResult {
  MaskResult._(
      List<String?> values, this.text, List<int> starts, List<int> ends)
      : values = List.unmodifiable(values),
        starts = List.unmodifiable(starts),
        ends = List.unmodifiable(ends);

  /// Canonical positional values; null entries are holes and never shift.
  final List<String?> values;

  /// Formatted display text.
  final String text;

  /// Start offset of every slot, including invisible empty slots.
  final List<int> starts;

  /// End offset of every slot; equal to its start when empty.
  final List<int> ends;

  /// Filled characters only, in logical placeholder order.
  String get rawText => values.whereType<String>().join();

  /// True when every placeholder is filled (also true for literal-only masks).
  bool get isComplete => values.every((value) => value != null);

  /// First slot at or after [offset], favoring an empty slot at a shared boundary.
  int slotAt(int offset) {
    for (var i = 0; i < values.length; i++) {
      if (starts[i] >= offset || ends[i] > offset) return i;
    }
    return values.length;
  }
}

/// Result of a pure positional edit.
class MaskEditResult {
  /// Creates a result; a null [cursor] means preserve the original selection.
  const MaskEditResult(this.result, this.cursor);

  /// Updated positional state and rendering.
  final MaskResult result;

  /// Collapsed UTF-16 caret, or null for an ignored edit.
  final int? cursor;
}

/// Pure mask parsing/application/rendering operations, with no Flutter imports.
abstract final class MaskEngine {
  /// Applies an inferred replacement to positional slots without Flutter state.
  ///
  /// [start], [end], and [caret] are UTF-16 offsets into [result]. [selected]
  /// distinguishes selection clearing from single-slot deletion. [deleting]
  /// and [backward] describe a collapsed deletion across slots or literals.
  static MaskEditResult edit(
    MaskResult result,
    MaskDefinition definition, {
    required int start,
    required int end,
    required String inserted,
    required int caret,
    bool selected = false,
    bool deleting = false,
    bool backward = false,
    MaskAutoCompletionType type = MaskAutoCompletionType.lazy,
  }) {
    if (start == end &&
        inserted.runes.length == 1 &&
        result.text.startsWith(inserted, start) &&
        !List.generate(result.values.length, (i) => i)
            .any((i) => result.starts[i] <= start && result.ends[i] > start)) {
      return MaskEditResult(result, start + inserted.length);
    }
    final slots = List<String?>.of(result.values);
    var target = result.slotAt(start);
    if (deleting && !selected) {
      int? victim;
      if (backward) {
        for (var i = slots.length - 1; i >= 0; i--) {
          if (slots[i] != null && result.starts[i] < caret) {
            victim = i;
            break;
          }
        }
      } else {
        for (var i = 0; i < slots.length; i++) {
          if (slots[i] != null && result.ends[i] > caret) {
            victim = i;
            break;
          }
        }
      }
      if (victim != null) {
        slots[victim] = null;
        result = MaskEngine.render(slots, definition, type: type);
        return MaskEditResult(result, result.starts[victim]);
      }
      return MaskEditResult(result, null);
    }
    // Selection/correction replacement clears exactly the intersected slots.
    for (var i = 0; i < slots.length; i++) {
      if (result.starts[i] < end && result.ends[i] > start) slots[i] = null;
    }
    var changed = end > start;
    var literalCursor = start;
    var tokenIndex = 0;
    // Include preceding literal run when starting on or before that run.
    while (tokenIndex < definition.tokens.length) {
      final token = definition.tokens[tokenIndex];
      if (token.isSlot && token.slot! >= target) break;
      tokenIndex++;
    }
    final precedingEnd = target == 0 ? 0 : result.ends[target - 1];
    final targetStart = target < result.starts.length
        ? result.starts[target]
        : result.text.length;
    if (start < targetStart || precedingEnd == targetStart) {
      while (tokenIndex > 0 && !definition.tokens[tokenIndex - 1].isSlot) {
        tokenIndex--;
      }
    }
    var inputOffset = 0;
    while (inputOffset < inserted.length) {
      // Match complete literal runs, avoiding accidental removal of digit input
      // that merely equals one character of a prefix such as '+1 ('.
      if (tokenIndex < definition.tokens.length &&
          !definition.tokens[tokenIndex].isSlot) {
        final literal = StringBuffer();
        while (tokenIndex < definition.tokens.length &&
            !definition.tokens[tokenIndex].isSlot) {
          literal.write(definition.tokens[tokenIndex++].character);
        }
        final run = literal.toString();
        if (inserted.startsWith(run, inputOffset)) {
          inputOffset += run.length;
          literalCursor = target < result.starts.length
              ? result.starts[target]
              : result.text.length;
          changed = true;
          continue;
        }
      }
      if (target >= slots.length) break;
      final character = scalarAt(inserted, inputOffset);
      inputOffset += character.length;
      if (definition.slots[target].accepts(character)) {
        slots[target++] = character;
        changed = true;
        // Advance to the literal run preceding the next slot.
        while (tokenIndex < definition.tokens.length &&
            (!definition.tokens[tokenIndex].isSlot ||
                definition.tokens[tokenIndex].slot! < target)) {
          if (!definition.tokens[tokenIndex].isSlot) break;
          tokenIndex++;
        }
      }
    }
    if (!changed) return MaskEditResult(result, null);
    result = MaskEngine.render(slots, definition, type: type);
    final cursor =
        target < slots.length ? result.starts[target] : result.text.length;
    return MaskEditResult(
        result, cursor > literalCursor ? cursor : literalCursor);
  }

  /// Applies raw scalars left to right, skipping failures at the current slot.
  static MaskResult apply(String? raw, MaskDefinition definition,
      {MaskAutoCompletionType type = MaskAutoCompletionType.lazy}) {
    final values = List<String?>.filled(definition.slotCount, null);
    var slot = 0;
    for (final rune in (raw ?? '').runes) {
      if (slot == values.length) break;
      final character = String.fromCharCode(rune);
      if (definition.slots[slot].accepts(character)) values[slot++] = character;
    }
    return render(values, definition, type: type);
  }

  /// Best-effort import of formatted text, recognizing literals positionally.
  ///
  /// Use [apply] for unambiguously raw input. For example a literal digit in a
  /// prefix is consumed here only when the complete literal run is present.
  static MaskResult parse(String? text, MaskDefinition definition,
      {MaskAutoCompletionType type = MaskAutoCompletionType.lazy}) {
    final input = text ?? '';
    final values = List<String?>.filled(definition.slotCount, null);
    var offset = 0;
    var token = 0;
    while (token < definition.tokens.length && offset < input.length) {
      final current = definition.tokens[token];
      if (!current.isSlot) {
        final literal = StringBuffer();
        while (token < definition.tokens.length &&
            !definition.tokens[token].isSlot) {
          literal.write(definition.tokens[token++].character);
        }
        if (input.startsWith(literal.toString(), offset)) {
          offset += literal.length;
        }
        continue;
      }
      final character = scalarAt(input, offset);
      offset += character.length;
      if (current.accepts(character)) {
        values[current.slot!] = character;
        token++;
      }
    }
    return render(values, definition, type: type);
  }

  /// Renders positional contents without reflowing holes.
  ///
  /// Linear in mask size, allocating a result string and boundary arrays. Caller
  /// supplied filters determine their own matching cost.
  static MaskResult render(List<String?> values, MaskDefinition definition,
      {MaskAutoCompletionType type = MaskAutoCompletionType.lazy}) {
    if (values.length != definition.slotCount) {
      throw ArgumentError('Expected ${definition.slotCount} slot values');
    }
    var lastFilled = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != null) {
        if (!definition.slots[i].accepts(values[i]!)) {
          throw ArgumentError.value(
              values[i], 'values[$i]', 'Invalid slot content');
        }
        lastFilled = i;
      }
    }
    final starts = List<int>.filled(values.length, 0);
    final ends = List<int>.filled(values.length, 0);
    final output = StringBuffer();
    var previousSlot = -1;
    for (final token in definition.tokens) {
      if (token.isSlot) {
        final index = token.slot!;
        starts[index] = output.length;
        output.write(values[index] ?? '');
        ends[index] = output.length;
        previousSlot = index;
      } else if (lastFilled >= 0 &&
          (previousSlot < lastFilled ||
              (type == MaskAutoCompletionType.eager &&
                  previousSlot == lastFilled))) {
        output.write(token.character);
      }
    }
    return MaskResult._(values, output.toString(), starts, ends);
  }
}

/// Formats unambiguously raw input without retaining formatter state.
String maskText(String? text,
        {required String mask,
        Map<String, RegExp>? filter,
        MaskAutoCompletionType type = MaskAutoCompletionType.lazy}) =>
    MaskEngine.apply(text, MaskDefinition(mask, filter: filter), type: type)
        .text;

/// Extracts slot contents from formatted input without retaining state.
///
/// Unrendered holes cannot be reconstructed from text alone. Stateful formatters
/// retain those positions; this helper interprets text from left to right.
String unmaskText(String? text,
        {required String mask, Map<String, RegExp>? filter}) =>
    MaskEngine.parse(text, MaskDefinition(mask, filter: filter)).rawText;
