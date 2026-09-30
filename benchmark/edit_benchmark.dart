import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input/masked_input.dart';

void main() {
  test('10,000 overtype edits on a 19-slot card mask', () {
    final formatter = MaskFormatter(
      mask: '#### #### #### #### ###',
      initialText: '1234567890123456789',
    );
    final samples = <int>[];
    var value = formatter.value;
    for (var i = 0; i < 11000; i++) {
      final cursor = i % value.text.length;
      final old =
          value.copyWith(selection: TextSelection.collapsed(offset: cursor));
      final incoming = old.copyWith(
        text: old.text.replaceRange(cursor, cursor, '${i % 10}'),
        selection: TextSelection.collapsed(offset: cursor + 1),
      );
      final watch = Stopwatch()..start();
      value = formatter.formatEditUpdate(old, incoming);
      watch.stop();
      if (i >= 1000) samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    debugPrint('Host Flutter test/JIT microseconds: n=${samples.length}, '
        'p50=${samples[5000]}, p95=${samples[9500]}, p99=${samples[9900]}, '
        'max=${samples.last}. This is not a physical-device benchmark.');
    expect(formatter.unmaskedText.length, 19);
  });
}
