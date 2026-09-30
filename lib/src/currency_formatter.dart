import 'package:flutter/services.dart';

import 'edit_delta.dart';

/// Formatting conventions for a minor-unit currency input field.
///
/// This is a small explicit table, not an implementation of CLDR or a currency
/// conversion API. Override separators and symbol for application conventions.
class CurrencyLocale {
  /// Creates a currency display convention.
  const CurrencyLocale(
      {required this.symbol,
      this.groupSeparator = ',',
      this.decimalSeparator = '.',
      this.decimalDigits = 2,
      this.symbolOnLeft = true,
      this.symbolSeparator = '',
      this.primaryGroupSize = 3,
      this.secondaryGroupSize = 3});

  /// Default currency symbol.
  final String symbol;

  /// Thousands/group separator.
  final String groupSeparator;

  /// Fraction separator.
  final String decimalSeparator;

  /// Default number of minor-unit digits.
  final int decimalDigits;

  /// Whether the symbol precedes the number.
  final bool symbolOnLeft;

  /// Space between the symbol and numeric value.
  final String symbolSeparator;

  /// Size of the rightmost integer group.
  final int primaryGroupSize;

  /// Size of subsequent integer groups (2 for Indian grouping).
  final int secondaryGroupSize;

  /// Supported, deterministic conventions. Locale tags also accept hyphens.
  static const Map<String, CurrencyLocale> supported = {
    'en_US': CurrencyLocale(symbol: r'$'),
    'en_GB': CurrencyLocale(symbol: '£'),
    'en_CA': CurrencyLocale(symbol: r'CA$'),
    'en_AU': CurrencyLocale(symbol: r'A$'),
    'de_DE': CurrencyLocale(
        symbol: '€',
        groupSeparator: '.',
        decimalSeparator: ',',
        symbolOnLeft: false,
        symbolSeparator: '\u00a0'),
    'fr_FR': CurrencyLocale(
        symbol: '€',
        groupSeparator: '\u202f',
        decimalSeparator: ',',
        symbolOnLeft: false,
        symbolSeparator: '\u00a0'),
    'pt_BR': CurrencyLocale(
        symbol: r'R$',
        groupSeparator: '.',
        decimalSeparator: ',',
        symbolSeparator: '\u00a0'),
    'ja_JP': CurrencyLocale(symbol: '¥', decimalDigits: 0),
    'hi_IN': CurrencyLocale(symbol: '₹', secondaryGroupSize: 2),
    'ar_EG': CurrencyLocale(
        symbol: 'ج.م.',
        groupSeparator: '\u066c',
        decimalSeparator: '\u066b',
        symbolOnLeft: false,
        symbolSeparator: '\u00a0'),
  };
}

class _CurrencyResult {
  const _CurrencyResult(this.text, this.positions, this.end);
  final String text;
  final List<int> positions;
  final int end;
  int indexAt(int offset) =>
      positions.where((position) => position < offset).length;
  int offsetAt(int index) => index < positions.length ? positions[index] : end;
}

/// Currency input interpreted as a stream of ASCII minor-unit digits.
///
/// With two decimals, typing `125000` displays `$1,250.00`. No floating-point
/// arithmetic is used, and raw leading zeros are retained. Negative amounts and
/// decimal-number parsing are outside this API. Share no instance across fields.
class CurrencyFormatter extends TextInputFormatter {
  /// Creates a formatter using one of [CurrencyLocale.supported]'s conventions.
  /// Unsupported locales and ambiguous/digit-containing separators are rejected.
  CurrencyFormatter(
      {String locale = 'en_US',
      String? symbol,
      int? decimalDigits,
      String? groupSeparator,
      String? decimalSeparator,
      bool? symbolOnLeft,
      String? symbolSeparator,
      this.textDirection = TextDirection.ltr,
      String? initialText})
      : locale = locale.replaceAll('-', '_') {
    final defaults = CurrencyLocale.supported[this.locale];
    if (defaults == null) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
    }
    this.symbol = symbol ?? defaults.symbol;
    this.decimalDigits = decimalDigits ?? defaults.decimalDigits;
    this.groupSeparator = groupSeparator ?? defaults.groupSeparator;
    this.decimalSeparator = decimalSeparator ?? defaults.decimalSeparator;
    this.symbolOnLeft = symbolOnLeft ?? defaults.symbolOnLeft;
    this.symbolSeparator = symbolSeparator ?? defaults.symbolSeparator;
    _primary = defaults.primaryGroupSize;
    _secondary = defaults.secondaryGroupSize;
    if (this.decimalDigits < 0 || this.decimalDigits > 20) {
      throw ArgumentError.value(
          this.decimalDigits, 'decimalDigits', 'Expected 0 through 20');
    }
    if ((this.decimalDigits > 0 && this.decimalSeparator.isEmpty) ||
        (this.groupSeparator.isNotEmpty &&
            this.groupSeparator == this.decimalSeparator) ||
        RegExp(r'[0-9\r\n]').hasMatch(
            '${this.symbol}${this.groupSeparator}${this.decimalSeparator}${this.symbolSeparator}')) {
      throw ArgumentError(
          'Currency decorations must be distinct separators without digits or newlines');
    }
    _raw = _digits(initialText ?? '');
    _rendered = _render(_raw);
    _value = TextEditingValue(
        text: _rendered.text,
        selection: TextSelection.collapsed(offset: _rendered.end));
  }

  /// Normalized locale key.
  final String locale;

  /// Display symbol; pass an empty string for no symbol.
  late final String symbol;

  /// Number of fixed fraction digits.
  late final int decimalDigits;

  /// Integer group separator; empty disables grouping.
  late final String groupSeparator;

  /// Separator before the fractional part.
  late final String decimalSeparator;

  /// Whether the currency symbol precedes the number.
  late final bool symbolOnLeft;

  /// Spacing around the symbol.
  late final String symbolSeparator;

  /// Direction to also set on the Flutter field; logical digits are unchanged.
  final TextDirection textDirection;
  late final int _primary;
  late final int _secondary;
  late String _raw;
  late _CurrencyResult _rendered;
  late TextEditingValue _value;
  TextEditingValue? _compositionBase;

  /// Committed ASCII digits (minor units), without synthetic padding zeros.
  String get unmaskedText => _raw;

  /// Committed formatted display value.
  String get maskedText => _rendered.text;

  /// Last committed value, suitable for assigning to a controller.
  TextEditingValue get value => _value;

  static String _digits(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  _CurrencyResult _render(String raw) {
    if (raw.isEmpty) return const _CurrencyResult('', [], 0);
    final padded = raw.padLeft(decimalDigits + 1, '0');
    final pad = padded.length - raw.length;
    final integerLength = padded.length - decimalDigits;
    final out = StringBuffer();
    final positions = <int>[];
    if (symbolOnLeft && symbol.isNotEmpty) out.write('$symbol$symbolSeparator');
    for (var i = 0; i < padded.length; i++) {
      if (i == integerLength) out.write(decimalSeparator);
      if (i > 0 && i < integerLength) {
        final remaining = integerLength - i;
        if (remaining == _primary ||
            (remaining > _primary &&
                (remaining - _primary) % _secondary == 0)) {
          out.write(groupSeparator);
        }
      }
      if (i >= pad) positions.add(out.length);
      out.write(padded[i]);
    }
    final end = out.length;
    if (!symbolOnLeft && symbol.isNotEmpty) {
      out.write('$symbolSeparator$symbol');
    }
    return _CurrencyResult(out.toString(), positions, end);
  }

  /// Resets state and returns the empty value for assignment to a controller.
  TextEditingValue clear() {
    _raw = '';
    _compositionBase = null;
    _rendered = _render('');
    return _save(0);
  }

  TextEditingValue _save(int index) {
    _value = TextEditingValue(
        text: _rendered.text,
        selection: TextSelection.collapsed(offset: _rendered.offsetAt(index)));
    return _value;
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
    final synchronized = baseline.text == _rendered.text;
    if (!synchronized) {
      _raw = _digits(baseline.text);
      _rendered = _render(_raw);
    }
    int indexAt(int offset) => synchronized
        ? _rendered.indexAt(offset)
        : _digits(baseline.text
                .substring(0, scalarBoundary(baseline.text, offset)))
            .length;
    if (baseline.text == newValue.text) {
      if (!synchronized) return _save(indexAt(newValue.selection.extentOffset));
      _value = newValue.copyWith(
          selection: TextSelection(
              baseOffset:
                  scalarBoundary(newValue.text, newValue.selection.baseOffset),
              extentOffset: scalarBoundary(
                  newValue.text, newValue.selection.extentOffset),
              affinity: newValue.selection.affinity,
              isDirectional: newValue.selection.isDirectional),
          composing: TextRange.empty);
      return _value;
    }
    final delta = EditDelta.between(baseline.text, newValue.text,
        baseline.selection.baseOffset, baseline.selection.extentOffset,
        newExtent: newValue.selection.extentOffset);
    var start = indexAt(delta.start);
    var end = indexAt(delta.end);
    final inserted = _digits(delta.inserted);
    if (delta.inserted.isNotEmpty && inserted.isEmpty && start == end) {
      if (synchronized) {
        _value = baseline.copyWith(composing: TextRange.empty);
        return _value;
      }
      return _save(indexAt(baseline.selection.extentOffset));
    }
    if (delta.inserted.isEmpty &&
        delta.end > delta.start &&
        baseline.selection.isCollapsed) {
      final caret = indexAt(baseline.selection.extentOffset);
      if (delta.start < baseline.selection.extentOffset) {
        start = (caret - 1).clamp(0, _raw.length);
        end = caret;
      } else {
        start = caret;
        end = (caret + 1).clamp(0, _raw.length);
      }
    }
    _raw = _raw.replaceRange(start, end, inserted);
    _rendered = _render(_raw);
    return _save(start + inserted.length);
  }
}
