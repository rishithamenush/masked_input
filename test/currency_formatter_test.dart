import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input/masked_input.dart';
import 'helpers.dart';

void main() {
  test('Currency grouping (§12.2) and Currency backspace (§12.2)', () {
    final f = CurrencyFormatter();
    var value = type(f, editing(''), '125000');
    expect(value.text, r'$1,250.00');
    expect(f.unmaskedText, '125000');
    value = backspace(f, value);
    expect(value.text, r'$125.00');
    expect(f.unmaskedText, '12500');
  });
  test('minor units pad without polluting raw, clear and leading zeros', () {
    final f = CurrencyFormatter();
    var value = type(f, editing(''), '1');
    expect(value.text, r'$0.01');
    expect(f.unmaskedText, '1');
    expect(backspace(f, value).text, '');
    expect(type(f, f.clear(), '001').text, r'$0.01');
    expect(f.unmaskedText, '001');
    expect(f.clear().text, '');
  });
  test('all ten locale conventions', () {
    final expected = {
      'en_US': r'$1,234.56',
      'en_GB': '£1,234.56',
      'en_CA': r'CA$1,234.56',
      'en_AU': r'A$1,234.56',
      'de_DE': '1.234,56\u00a0€',
      'fr_FR': '1\u202f234,56\u00a0€',
      'pt_BR': 'R\$\u00a01.234,56',
      'ja_JP': '¥123,456',
      'hi_IN': '₹1,234.56',
      'ar_EG': '1\u066c234\u066b56\u00a0ج.م.',
    };
    for (final entry in expected.entries) {
      final f = CurrencyFormatter(locale: entry.key);
      expect(type(f, editing(''), '123456').text, entry.value,
          reason: entry.key);
    }
    expect(
        CurrencyFormatter(locale: 'hi_IN', initialText: '123456789').maskedText,
        '₹12,34,567.89');
  });
  test('format overrides and validation', () {
    final f = CurrencyFormatter(
        locale: 'en-US',
        symbol: '',
        groupSeparator: ' ',
        decimalSeparator: ',',
        decimalDigits: 3);
    expect(type(f, editing(''), '1234567').text, '1 234,567');
    expect(
        CurrencyFormatter(
                symbol: '',
                groupSeparator: '',
                decimalDigits: 0,
                initialText: '123456')
            .maskedText,
        '123456');
    expect(() => CurrencyFormatter(locale: 'unknown'), throwsArgumentError);
    expect(() => CurrencyFormatter(decimalDigits: -1), throwsArgumentError);
    expect(() => CurrencyFormatter(decimalDigits: 21), throwsArgumentError);
    expect(() => CurrencyFormatter(decimalSeparator: ','), throwsArgumentError);
    expect(() => CurrencyFormatter(symbol: '1'), throwsArgumentError);
  });
  test('mid-text insertion, grouping deletion, forward delete', () {
    final f = CurrencyFormatter(initialText: '123456');
    final inserted = type(f, editing(f.maskedText, 4), '9');
    expect(inserted.text, r'$12,934.56');
    expect(inserted.selection.extentOffset, 5);
    f.clear();
    type(f, f.value, '123456');
    expect(backspace(f, editing(f.maskedText, 3)).text, r'$234.56');
    f.clear();
    type(f, f.value, '123456');
    expect(delete(f, editing(f.maskedText, 2)).text, r'$134.56');
  });
  test('select-all replacement, formatted paste, junk and large exact integers',
      () {
    final f = CurrencyFormatter(initialText: '123456');
    final selected = f.value.copyWith(
        selection:
            TextSelection(baseOffset: 0, extentOffset: f.maskedText.length));
    expect(type(f, selected, r'$98.76').text, r'$98.76');
    expect(f.unmaskedText, '9876');
    final big = '9' * 80;
    type(f, f.clear(), big);
    expect(f.unmaskedText, big);
    expect(f.maskedText.replaceAll(RegExp(r'[^0-9]'), ''), big);
  });
  test('composition, cursor-only movement and external controller sync', () {
    final f = CurrencyFormatter();
    final comp =
        editing('a').copyWith(composing: const TextRange(start: 0, end: 1));
    expect(f.formatEditUpdate(editing(''), comp), comp);
    expect(f.unmaskedText, '');
    expect(f.formatEditUpdate(comp, editing('1')).text, r'$0.01');
    final moved = editing(f.maskedText, 2);
    expect(f.formatEditUpdate(f.value, moved), moved);
    expect(type(f, editing('123', 3), '4').text, r'$12.34');
  });
  test('suffix symbol backspace and RTL logical digits', () {
    final f = CurrencyFormatter(
        locale: 'de_DE', textDirection: TextDirection.rtl, initialText: '1234');
    expect(backspace(f, editing(f.maskedText)).text, '1,23\u00a0€');
    expect(f.unmaskedText, '123');
  });
}
