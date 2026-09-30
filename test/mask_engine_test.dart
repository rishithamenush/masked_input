import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input/masked_input.dart';

void main() {
  group('§6 mask syntax', () {
    test('built-ins and raw preservation', () {
      expect(maskText('5551234567', mask: '+1 (###) ###-####'),
          '+1 (555) 123-4567');
      expect(unmaskText('+1 (555) 123-4567', mask: '+1 (###) ###-####'),
          '5551234567');
      expect(maskText('4111111111111111', mask: '#### #### #### ####'),
          '4111 1111 1111 1111');
      expect(maskText('25092026', mask: '##/##/####'), '25/09/2026');
      expect(maskText('xyz12', mask: 'AAA-###'), 'xyz-12');
      expect(maskText('xy', mask: 'AAA-###'), 'xy');
      expect(maskText('a9é', mask: 'NNN'), 'a9é');
    });
    test('escape tokens, slash, and scalar literals', () {
      expect(maskText('1', mask: r'\#\A\N\*\\#'), r'#AN*\1');
      expect(maskText('12', mask: '😀#-#'), '😀1-2');
    });
    test('empty mask and dangling escape throw useful syntax errors', () {
      expect(() => MaskDefinition(''), throwsA(isA<MaskSyntaxError>()));
      expect(() => MaskDefinition('##\\'),
          throwsA(isA<MaskSyntaxError>().having((e) => e.offset, 'offset', 2)));
    });
    test('custom filters merge, override, ignore unused keys and copy map', () {
      final filters = {
        'H': RegExp('[A-F0-9]'),
        '#': RegExp('[a-z]'),
        'X': RegExp('.')
      };
      final definition = MaskDefinition('HH-##', filter: filters);
      filters.clear();
      expect(MaskEngine.apply('AFxy', definition).text, 'AF-xy');
      expect(() => definition.filter.clear(), throwsUnsupportedError);
      expect(() => MaskDefinition('#', filter: {'XX': RegExp('.')}),
          throwsArgumentError);
    });
    test('filter must match entire scalar', () {
      expect(maskText('a', mask: 'H', filter: {'H': RegExp('')}), '');
    });
    test('lazy and eager literals with empty, partial and complete data', () {
      expect(
          maskText('', mask: '+#-#', type: MaskAutoCompletionType.eager), '');
      expect(maskText('1', mask: '+#-#'), '+1');
      expect(maskText('1', mask: '+#-#', type: MaskAutoCompletionType.eager),
          '+1-');
      expect(maskText('12', mask: '##!'), '12');
      expect(maskText('12', mask: '##!', type: MaskAutoCompletionType.eager),
          '12!');
    });
    test('null, invalid input, overflow and structural completion', () {
      final d = MaskDefinition('##/##');
      expect(MaskEngine.apply(null, d).text, '');
      expect(MaskEngine.apply('a9b9c9d9e9', d).text, '99/99');
      expect(MaskEngine.apply('9999', d).isComplete, isTrue);
      expect(MaskEngine.apply('999', d).isComplete, isFalse);
      expect(
          MaskEngine.apply('', MaskDefinition('literal')).isComplete, isTrue);
    });
    test('positional holes do not reflow, immutable result', () {
      final d = MaskDefinition('###-###');
      final r = MaskEngine.render(['1', '2', null, '4', '5', null], d);
      expect(r.text, '12-45');
      expect(r.rawText, '1245');
      expect(r.starts, [0, 1, 2, 3, 4, 5]);
      expect(r.slotAt(2), 2);
      expect(() => r.values[0] = '0', throwsUnsupportedError);
      expect(() => MaskEngine.render([], d), throwsArgumentError);
      expect(() => MaskEngine.render(['a', null, null, null, null, null], d),
          throwsArgumentError);
    });
  });
  group('§8 Unicode boundaries', () {
    test('Unicode letters from multiple scripts, including supplementary plane',
        () {
      expect(maskText('éñü漢Жع𐐀', mask: 'AAAAAAA'), 'éñü漢Жع𐐀');
    });
    test('ASCII digits only, custom filter opts in', () {
      expect(maskText('٠١٢123', mask: '###'), '123');
      expect(
          maskText('٠١٢',
              mask: '###', filter: {'#': RegExp(r'\p{Nd}', unicode: true)}),
          '٠١٢');
    });
    test('single emoji occupies star slot, not letter slot', () {
      expect(maskText('😀', mask: '*'), '😀');
      expect(maskText('😀', mask: 'A'), '');
      expect(MaskEngine.apply('😀a', MaskDefinition('**')).starts, [0, 2]);
    });
    test(
        'line breaks excluded from star; ZWJ and combining marks use separate slots',
        () {
      expect(maskText('\r\n\u2028\u2029a', mask: '*'), 'a');
      expect(maskText('e\u0301', mask: '**'), 'e\u0301');
      expect(MaskEngine.apply('👨‍👩', MaskDefinition('***')).values.length, 3);
    });
  });
}
