import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input/masked_input.dart';
import 'helpers.dart';

void main() {
  test('digit literal is not consumed after the caret has passed it', () {
    final f = MaskFormatter(mask: '#1#', initialText: '213');
    expect(type(f, editing('213', 2), '1'), editing('211', 3));
    expect(f.unmaskedText, '21');
    final prefix = MaskFormatter(mask: '1##', initialText: '123');
    expect(type(prefix, editing('123', 1), '1'), editing('113', 2));
  });
  test('currency invalid typing preserves deliberately placed literal cursor',
      () {
    final f = CurrencyFormatter(initialText: '123456');
    final old = editing(f.maskedText, 0);
    expect(type(f, old, 'x'), old);
  });

  test('forward delete among repeated digits deletes the slot on the right',
      () {
    final f = MaskFormatter(mask: '####', initialText: '1111');
    expect(delete(f, editing('1111', 2)), editing('111', 2));
    expect(type(f, f.value, '9').text, '1191');
  });
  test('typing one literal inside a multi-character literal run', () {
    final f = MaskFormatter(mask: '## / ##', initialText: '12 / 34');
    expect(type(f, editing(f.maskedText, 2), ' '), editing('12 / 34', 3));
    expect(type(f, editing(f.maskedText, 3), '/'), editing('12 / 34', 4));
  });
  test(
      '10,000 deterministic edits preserve deletion count, bounds, and filters',
      () {
    final random = Random(210930);
    for (final mode in MaskAutoCompletionType.values) {
      final f = MaskFormatter(mask: '+1 (###) ##-####', type: mode);
      var value = editing('');
      for (var i = 0; i < 5000; i++) {
        final cursor = random.nextInt(value.text.length + 1);
        value = editing(value.text, cursor);
        final before = f.unmaskedText;
        final operation = random.nextInt(5);
        if (operation == 0 && cursor > 0) {
          // Display positions with ASCII digits include a fixed prefix digit;
          // exclude that prefix when counting available user characters.
          final userBefore = value.text
              .substring(0, cursor)
              .replaceFirst(RegExp(r'^\+1 ?\(?'), '')
              .replaceAll(RegExp('[^0-9]'), '');
          value = backspace(f, value);
          expect(f.unmaskedText.length,
              before.length - (userBefore.isEmpty ? 0 : 1),
              reason: 'backspace $i');
        } else if (operation == 1 && cursor < value.text.length) {
          final userAfter = value.text
              .substring(cursor < 4 ? 4.clamp(0, value.text.length) : cursor)
              .replaceAll(RegExp('[^0-9]'), '');
          value = delete(f, value);
          expect(f.unmaskedText.length,
              before.length - (userAfter.isEmpty ? 0 : 1),
              reason: 'forward delete $i');
        } else if (operation == 2) {
          final old = value;
          value = type(f, value, 'x');
          expect(value, old);
          expect(f.unmaskedText, before);
        } else if (operation == 3 && i % 7 == 0) {
          value = value.copyWith(
              selection: TextSelection(
                  baseOffset: 0, extentOffset: value.text.length));
          value = type(f, value, '12345');
          expect(f.unmaskedText, '12345');
        } else {
          value = type(f, value, '${random.nextInt(10)}');
        }
        expect(value.selection.extentOffset,
            inInclusiveRange(0, value.text.length));
        expect(value.composing, TextRange.empty);
        expect(f.maskedText, value.text);
        expect(f.unmaskedText, matches(RegExp(r'^[0-9]{0,9}$')));
      }
    }
  });
}
