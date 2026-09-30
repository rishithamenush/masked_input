import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input/masked_input.dart';
import 'helpers.dart';

void main() {
  test('Mid-text insert keeps cursor (§12.2)', () {
    final f = MaskFormatter(mask: '##/##/####', initialText: '25/09/2026');
    final value = type(f, editing(f.maskedText, 1), '6');
    expect(value.text, '26/09/2026');
    expect(value.selection.extentOffset, 3);
    expect(f.unmaskedText, '26092026');
  });
  test('Backspace over literal (§12.2) and refill hole', () {
    final f = MaskFormatter(mask: '###-###', initialText: '123-45');
    var value = backspace(f, editing(f.maskedText, 4));
    expect(value.text, '12-45');
    expect(value.selection.extentOffset, 2);
    value = type(f, value, '9');
    expect(value.text, '129-45');
    expect(value.selection.extentOffset, 4);
  });
  test('Clear then retype (§12.2)', () {
    final f = MaskFormatter(mask: '###', initialText: '123');
    final empty = f.clear();
    expect(empty.text, '');
    expect(f.unmaskedText, '');
    expect(f.isComplete, isFalse);
    expect(type(f, empty, '1').text, '1');
  });
  test('Reject invalid char (§12.2) preserves text and selection', () {
    final f = MaskFormatter(mask: '###');
    expect(type(f, editing(''), 'a'), editing(''));
    final old = type(f, editing(''), '12')
        .copyWith(selection: const TextSelection.collapsed(offset: 1));
    expect(type(f, old, 'a'), old);
    expect(f.unmaskedText, '12');
  });
  test('Paste with junk (§12.2), raw and formatted phone', () {
    final f = MaskFormatter(mask: '###');
    expect(type(f, editing(''), 'a1b2c3').text, '123');
    for (final input in ['5551234567', '+1 (555) 123-4567']) {
      final phone = MaskFormatter(mask: '+1 (###) ###-####');
      expect(type(phone, editing(''), input).text, '+1 (555) 123-4567');
      expect(phone.unmaskedText, '5551234567');
    }
  });
  test('Select-all replace (§12.2), reversed selection, cut', () {
    for (final reversed in [false, true]) {
      final f = MaskFormatter(mask: '##/##', initialText: '12/34');
      final old = f.value.copyWith(
          selection: TextSelection(
              baseOffset: reversed ? 5 : 0, extentOffset: reversed ? 0 : 5));
      expect(type(f, old, '56').text, '56');
      expect(f.unmaskedText, '56');
    }
    final f = MaskFormatter(mask: '##/##', initialText: '12/34');
    final old = f.value.copyWith(
        selection: const TextSelection(baseOffset: 1, extentOffset: 4));
    expect(type(f, old, '').text, '1/4');
    expect(type(f, f.value, '9').text, '19/4');
  });
  test('Forward delete (§12.2) removes next filled slot and preserves literal',
      () {
    final f = MaskFormatter(mask: '###-###', initialText: '123-456');
    final value = delete(f, editing(f.maskedText, 3));
    expect(value.text, '123-56');
    expect(value.selection.extentOffset, 4);
    expect(type(f, value, '9').text, '123-956');
  });
  test('Eager literals (§12.2)', () {
    final f = MaskFormatter(mask: '##/##', type: MaskAutoCompletionType.eager);
    expect(type(f, editing(''), '12'), editing('12/'));
  });
  test('Lazy literals (§12.2)', () {
    final f = MaskFormatter(mask: '##/##');
    expect(type(f, editing(''), '12'), editing('12'));
  });
  test('updateMask shrink (§12.2), preserve filters, atomic failure', () {
    final f = MaskFormatter(mask: '####', initialText: '1234');
    expect(f.updateMask(mask: '##'), editing('12'));
    expect(f.isComplete, isTrue);
    expect(() => f.updateMask(mask: ''), throwsA(isA<MaskSyntaxError>()));
    expect(f.definition.mask, '##');
    expect(f.value, editing('12'));
    final custom = MaskFormatter(
        mask: 'HH', filter: {'H': RegExp('[a-f]')}, initialText: 'ab');
    expect(custom.updateMask(mask: 'H-H').text, 'a-b');
    expect(custom.updateMask(filter: {}).text, '');
  });
  test('updateMask maps middle cursor and changes literal mode', () {
    final f = MaskFormatter(mask: '####', initialText: '123');
    f.formatEditUpdate(f.value, editing('123', 1));
    expect(f.updateMask(mask: '#-###').selection.extentOffset, 2);
    final eager = MaskFormatter(mask: '##/##', initialText: '12');
    expect(eager.updateMask(type: MaskAutoCompletionType.eager).text, '12/');
  });
  test('RTL entry (§12.2) logical text and editing stay ordered', () {
    final f = MaskFormatter(mask: '###-###', textDirection: TextDirection.rtl);
    var value = type(f, editing(''), '123456');
    expect(value.text, '123-456');
    value = type(f, editing(value.text, 1), '9');
    expect(value.text, '193-456');
    expect(value.selection.extentOffset, 2);
  });
  test('IME composing preserved (§12.2), commit and cancellation', () {
    final f = MaskFormatter(mask: 'AA-AA');
    final composing =
        editing('汉字').copyWith(composing: const TextRange(start: 0, end: 2));
    expect(f.formatEditUpdate(editing(''), composing), composing);
    expect(f.unmaskedText, '');
    expect(f.formatEditUpdate(composing, editing('汉字')).text, '汉字');
    final next =
        editing('汉字語').copyWith(composing: const TextRange(start: 2, end: 3));
    expect(f.formatEditUpdate(f.value, next), next);
    expect(f.formatEditUpdate(next, editing('汉字')), editing('汉字'));
  });
  test('IME insertion into filled mask preserves positional suffix', () {
    final f = MaskFormatter(mask: 'AA-AA', initialText: 'ab-cd');
    final old = editing('ab-cd', 1);
    final composing = editing('a漢b-cd', 2)
        .copyWith(composing: const TextRange(start: 1, end: 2));
    f.formatEditUpdate(old, composing);
    expect(
        f
            .formatEditUpdate(
                composing, composing.copyWith(composing: TextRange.empty))
            .text,
        'a漢-cd');
  });
  test('Grapheme safety (§12.2): emoji scalar and caret repair', () {
    final f = MaskFormatter(mask: '**');
    final old = type(f, editing(''), '😀a');
    expect(old.text, '😀a');
    expect(f.formatEditUpdate(old, editing(old.text, 1)).selection.extentOffset,
        0);
    final deleted = f.formatEditUpdate(editing(old.text, 2), editing('a', 0));
    expect(deleted.text, 'a');
    expect(type(f, deleted, '😄').text, '😄a');
  });
  test('explicit literal typing skips rendered and unrendered separators', () {
    final f = MaskFormatter(mask: '##/##', initialText: '12/34');
    expect(type(f, editing('12/34', 2), '/'), editing('12/34', 3));
    f.clear();
    var value = type(f, editing(''), '12');
    value = type(f, value, '/');
    expect(value.text, '12');
    expect(type(f, value, '3').text, '12/3');
  });
  test('non-editing selection and literal positions never jump', () {
    final f = MaskFormatter(mask: '## / ##', initialText: '12 / 34');
    final next = f.value.copyWith(
        selection: const TextSelection(baseOffset: 4, extentOffset: 2));
    expect(f.formatEditUpdate(f.value, next), next);
  });
  test('controller assignment best effort remasks on next edit', () {
    final f = MaskFormatter(mask: '##/##');
    expect(type(f, editing('123', 3), '4').text, '12/34');
    expect(type(f, editing('98/7', 4), '6').text, '98/76');
    expect(type(f, editing(''), '1').text, '1');
  });
  test('repeated characters honor caret for insertion and deletion', () {
    final f = MaskFormatter(mask: '####', initialText: '1111');
    expect(type(f, editing('1111', 1), '1'), editing('1111', 2));
    expect(backspace(f, editing('1111', 2)), editing('111', 1));
    expect(type(f, f.value, '9').text, '1911');
  });
  test(
      'overflow rejected, no backspace target, all-selection invalid paste clears',
      () {
    final f = MaskFormatter(mask: '##', initialText: '12');
    expect(type(f, f.value, '3'), editing('12'));
    final selected = f.value.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 2));
    expect(type(f, selected, 'xyz').text, '');
    final prefix = MaskFormatter(mask: '+#', initialText: '1');
    expect(backspace(prefix, editing('+1', 1)), editing('+1', 1));
  });
}
