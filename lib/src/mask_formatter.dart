import 'package:flutter/services.dart';

import 'edit_delta.dart';
import 'mask_definition.dart';
import 'mask_engine.dart';

/// A stateful, positional input mask for one Flutter text field.
///
/// Typing over a filled slot replaces it. Deletion leaves a hole rather than
/// shifting subsequent slots. Active IME composition passes through unchanged;
/// accessors keep the last committed value until the composition commits.
class MaskFormatter extends TextInputFormatter {
  /// Creates a formatter. [initialText] is interpreted as formatted or raw text.
  MaskFormatter(
      {required String mask,
      Map<String, RegExp>? filter,
      MaskAutoCompletionType type = MaskAutoCompletionType.lazy,
      this.textDirection = TextDirection.ltr,
      String? initialText})
      : _definition = MaskDefinition(mask, filter: filter),
        _type = type {
    _result = MaskEngine.parse(initialText, _definition, type: _type);
    _lastValue = TextEditingValue(
        text: _result.text,
        selection: TextSelection.collapsed(offset: _result.text.length));
  }

  MaskDefinition _definition;
  MaskAutoCompletionType _type;
  late MaskResult _result;
  late TextEditingValue _lastValue;
  TextEditingValue? _compositionBase;

  /// Logical direction metadata. Set the field's textDirection to the same value.
  /// Text and slot order remain logical in both directions; Flutter handles bidi.
  final TextDirection textDirection;

  /// Current parsed mask.
  MaskDefinition get definition => _definition;

  /// Current literal completion mode.
  MaskAutoCompletionType get type => _type;

  /// Last committed formatted text.
  String get maskedText => _result.text;

  /// Last committed characters occupying placeholders, excluding every literal.
  String get unmaskedText => _result.rawText;

  /// Whether every placeholder is filled, without semantic validation.
  bool get isComplete => _result.isComplete;

  /// Last committed value, suitable for assigning to a controller.
  TextEditingValue get value => _lastValue;

  /// Resets internal state and returns the empty value to assign to a controller.
  ///
  /// A formatter does not own a controller: use `controller.value = mask.clear()`.
  TextEditingValue clear() {
    _compositionBase = null;
    _result = MaskEngine.apply('', _definition, type: _type);
    return _save(0);
  }

  /// Atomically updates the definition and re-applies current raw characters.
  ///
  /// Omitted filters/mode retain their current values; pass an empty filter map
  /// to restore defaults. Syntax failure leaves all state intact. Assign the
  /// returned value to the field controller. During composition, wait for commit
  /// before invoking this method. Cursor maps to the same slot or truncation end.
  TextEditingValue updateMask(
      {String? mask,
      Map<String, RegExp>? filter,
      MaskAutoCompletionType? type}) {
    final next = MaskDefinition(mask ?? _definition.mask,
        filter: filter ?? _definition.filter);
    final cursor = _result.slotAt(_lastValue.selection.extentOffset);
    final raw = _result.rawText;
    _definition = next;
    _type = type ?? _type;
    _compositionBase = null;
    _result = MaskEngine.apply(raw, next, type: _type);
    return _save(cursor < _result.starts.length
        ? _result.starts[cursor]
        : _result.text.length);
  }

  TextEditingValue _save(int offset) {
    _lastValue = TextEditingValue(
        text: _result.text,
        selection: TextSelection.collapsed(
            offset: scalarBoundary(_result.text, offset)));
    return _lastValue;
  }

  TextEditingValue _preserveSelection(TextEditingValue input) {
    _lastValue = TextEditingValue(
        text: _result.text,
        selection: TextSelection(
          baseOffset: scalarBoundary(_result.text, input.selection.baseOffset),
          extentOffset:
              scalarBoundary(_result.text, input.selection.extentOffset),
          affinity: input.selection.affinity,
          isDirectional: input.selection.isDirectional,
        ));
    return _lastValue;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      _compositionBase ??= oldValue;
      return newValue;
    }
    final baseline = _compositionBase ?? oldValue;
    _compositionBase = null;
    if (baseline.text != _result.text) {
      _result = MaskEngine.parse(baseline.text, _definition, type: _type);
    }
    // External controller assignments may have unformatted text. Infer intent
    // using that text, then map its positions through a parsed prefix.
    final delta = EditDelta.between(baseline.text, newValue.text,
        baseline.selection.baseOffset, baseline.selection.extentOffset,
        newExtent: newValue.selection.extentOffset);
    int mapOffset(int offset) {
      if (baseline.text == _result.text) return offset;
      final prefix = MaskEngine.parse(
          baseline.text.substring(0, scalarBoundary(baseline.text, offset)),
          _definition,
          type: _type);
      final count = prefix.values.whereType<String>().length;
      return count < _result.starts.length
          ? _result.starts[count]
          : _result.text.length;
    }

    if (baseline.text == newValue.text) {
      return _preserveSelection(newValue.copyWith(
          selection: TextSelection(
              baseOffset: mapOffset(newValue.selection.baseOffset),
              extentOffset: mapOffset(newValue.selection.extentOffset),
              affinity: newValue.selection.affinity,
              isDirectional: newValue.selection.isDirectional)));
    }
    final start = mapOffset(delta.start);
    final end = mapOffset(delta.end);
    final edit = MaskEngine.edit(_result, _definition,
        start: start,
        end: end,
        inserted: delta.inserted,
        selected: !baseline.selection.isCollapsed,
        deleting: delta.inserted.isEmpty && delta.end > delta.start,
        backward: delta.start < baseline.selection.extentOffset,
        caret: mapOffset(baseline.selection.extentOffset),
        type: _type);
    _result = edit.result;
    return edit.cursor == null
        ? _preserveSelection(baseline)
        : _save(edit.cursor!);
  }
}
