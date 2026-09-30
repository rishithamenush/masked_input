/// Controls when literals following filled slots become visible.
enum MaskAutoCompletionType {
  /// Render literals only when a later filled slot needs them.
  lazy,

  /// Also render literals immediately following the last filled slot.
  eager,
}

/// Invalid mask syntax, including an empty mask or dangling escape.
class MaskSyntaxError extends FormatException {
  /// Creates an error pointing to a UTF-16 offset in [source].
  const MaskSyntaxError(super.message, String super.source, int super.offset);
}

/// One immutable placeholder or literal in a parsed mask.
class MaskToken {
  const MaskToken._(this.character, this.filter, this.slot);

  /// The literal or placeholder scalar value.
  final String character;

  /// The placeholder filter, or null for a literal.
  final RegExp? filter;

  /// Zero-based placeholder index, or null for a literal.
  final int? slot;

  /// Whether this token accepts user input.
  bool get isSlot => slot != null;

  /// Whether a single Unicode scalar matches the entire filter.
  bool accepts(String value) {
    if (value.runes.length != 1) return false;
    final match = filter?.matchAsPrefix(value);
    return match != null && match.end == value.length;
  }
}

/// An immutable mask compiled once into literals and filtered slots.
class MaskDefinition {
  /// Parses [mask], merging [filter] over the built-in placeholder filters.
  ///
  /// Filter keys must be one Unicode scalar and cannot be the escape character.
  /// An unused valid key is permitted. Invalid syntax throws [MaskSyntaxError].
  factory MaskDefinition(String mask, {Map<String, RegExp>? filter}) {
    if (mask.isEmpty) throw const MaskSyntaxError('Mask is empty', '', 0);
    final filters = <String, RegExp>{
      '#': RegExp(r'[0-9]'),
      'A': RegExp(r'\p{L}', unicode: true),
      'N': RegExp(r'[\p{L}0-9]', unicode: true),
      '*': RegExp(r'[^\r\n\u2028\u2029]', unicode: true),
    };
    for (final entry in (filter ?? <String, RegExp>{}).entries) {
      if (entry.key.runes.length != 1 || entry.key == r'\') {
        throw ArgumentError.value(
            entry.key, 'filter', 'Expected one non-escape scalar');
      }
      filters[entry.key] = entry.value;
    }
    final tokens = <MaskToken>[];
    final slots = <MaskToken>[];
    var escaped = false;
    for (final rune in mask.runes) {
      final character = String.fromCharCode(rune);
      if (!escaped && character == r'\') {
        escaped = true;
        continue;
      }
      final matcher = escaped ? null : filters[character];
      final token = MaskToken._(
          character, matcher, matcher == null ? null : slots.length);
      tokens.add(token);
      if (token.isSlot) slots.add(token);
      escaped = false;
    }
    if (escaped) {
      throw MaskSyntaxError('Dangling escape', mask, mask.length - 1);
    }
    return MaskDefinition._(mask, tokens, slots, filter ?? {});
  }

  MaskDefinition._(this.mask, List<MaskToken> tokens, List<MaskToken> slots,
      Map<String, RegExp> filters)
      : tokens = List.unmodifiable(tokens),
        slots = List.unmodifiable(slots),
        filter = Map.unmodifiable(filters);

  /// Original mask source.
  final String mask;

  /// Ordered literals and placeholders.
  final List<MaskToken> tokens;

  /// Placeholders in logical order.
  final List<MaskToken> slots;

  /// Explicit custom filters, excluding built-in defaults.
  final Map<String, RegExp> filter;

  /// Number of fillable positions.
  int get slotCount => slots.length;
}
