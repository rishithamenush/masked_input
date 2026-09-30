// Record deterministic frames from the actual example widgets and formatters.
// MASKED_INPUT_DEMO_OUTPUT=/tmp/masked-input-demo flutter test tool/capture_demo.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input_example/main.dart';

void main() {
  testWidgets('capture verified package demo', (tester) async {
    final output = Directory(Platform.environment['MASKED_INPUT_DEMO_OUTPUT'] ??
        '/tmp/masked-input-demo')
      ..createSync(recursive: true);
    tester.view.physicalSize = const Size(720, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    for (final entry in {
      'Roboto': '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      'MaterialIcons': 'build/web/assets/fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = File(entry.value).readAsBytesSync();
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    WidgetsApp.debugAllowBannerOverride = false;
    debugDisableShadows = false;
    addTearDown(() {
      WidgetsApp.debugAllowBannerOverride = true;
      debugDisableShadows = true;
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: const MaskedInputExample()));
    await tester.pumpAndSettle();
    final manifest = <Map<String, Object>>[];
    Future<void> shot(String scene, double seconds, String caption) async {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final file = 'frame-${manifest.length.toString().padLeft(3, '0')}.png';
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$file')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      manifest.add({
        'file': file,
        'scene': scene,
        'seconds': seconds,
        'caption': caption
      });
    }

    Finder input(int index) => find.byKey(ValueKey('input-$index'));
    TextEditingController controller(int index) => tester
        .widget<EditableText>(find.descendant(
            of: input(index), matching: find.byType(EditableText)))
        .controller;
    Future<void> focus(int index) async {
      await tester.showKeyboard(input(index));
    }

    Future<void> insert(int index, String text) async {
      final old = controller(index).value;
      final start = old.selection.start.clamp(0, old.text.length);
      final end = old.selection.end.clamp(0, old.text.length);
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: old.text.replaceRange(start, end, text),
          selection: TextSelection.collapsed(offset: start + text.length)));
      await tester.pump();
    }

    Future<void> enter(
        int index, String text, String scene, String caption) async {
      await focus(index);
      for (final char in text.split('')) {
        await insert(index, char);
        await shot(scene, 0.19, caption);
      }
    }

    Future<void> tab(String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    Future<void> clear() async {
      await tester.tap(find.text('Clear field'));
      await tester.pumpAndSettle();
    }

    void verify(int index, String text) => expect(controller(index).text, text);
    await tester.enterText(input(0), '5551234567');
    verify(0, '+1 (555) 123-4567');
    await shot(
        'intro', 3, 'A real Flutter demo. Every edit uses masked_input.');
    await clear();
    await shot('phone', 1,
        'Start with raw digits. The formatter adds the punctuation.');
    await enter(0, '5551234567', 'phone', 'Type 5551234567');
    verify(0, '+1 (555) 123-4567');
    await shot('phone', 2, 'Formatted: +1 (555) 123-4567    Raw: 5551234567');
    await tester.tap(find.text('Include a three-digit extension'));
    await tester.pumpAndSettle();
    await enter(
        0, '123', 'dynamic', 'Switch masks without losing the entered number.');
    verify(0, '+1 (555) 123-4567 ext. 123');
    await shot(
        'dynamic', 2.2, 'updateMask() reapplies the existing raw value.');
    await tab('Date');
    await enter(
        1, '25092026', 'edit', 'Type a date, then edit a digit in the middle.');
    verify(1, '25/09/2026');
    await shot('edit', 1, '25/09/2026');
    tester.testTextInput.updateEditingValue(controller(1)
        .value
        .copyWith(selection: const TextSelection.collapsed(offset: 1)));
    await tester.pump();
    await shot('edit', 0.8, 'Place the caret after the first digit.');
    await insert(1, '6');
    verify(1, '26/09/2026');
    await shot(
        'edit', 2, 'The second slot changes. Later digits stay in place.');
    var old = controller(1).value;
    var caret = old.selection.extentOffset;
    tester.testTextInput.updateEditingValue(TextEditingValue(
        text: old.text.replaceRange(caret - 1, caret, ''),
        selection: TextSelection.collapsed(offset: caret - 1)));
    await tester.pump();
    verify(1, '2/09/2026');
    await shot('delete', 1.8,
        'Backspace across / removes one digit, not the literal.');
    await insert(1, '5');
    verify(1, '25/09/2026');
    await shot('delete', 1.5,
        'Refill the empty slot. The rest of the date stays intact.');
    await clear();
    await enter(1, '12', 'eager',
        'Lazy mode waits before showing a trailing separator.');
    verify(1, '12');
    await shot('eager', 1.2, 'Lazy: 12');
    await tester.tap(find.text('Show separators eagerly'));
    await tester.pumpAndSettle();
    verify(1, '12/');
    await shot('eager', 2, 'Eager: 12/');
    await tab('Currency');
    await enter(2, '125000', 'currency', 'Enter minor-unit digits: 125000');
    verify(2, r'$1,250.00');
    await shot('currency', 2,
        'Grouped display. Raw minor units. No floating-point conversion.');
    old = controller(2).value;
    caret = old.selection.extentOffset;
    tester.testTextInput.updateEditingValue(TextEditingValue(
        text: old.text.replaceRange(caret - 1, caret, ''),
        selection: TextSelection.collapsed(offset: caret - 1)));
    await tester.pump();
    verify(2, r'$125.00');
    await shot('currency', 1.7, r'One backspace: $1,250.00 becomes $125.00');
    await tab('RTL');
    await enter(3, '1234567890', 'rtl',
        'Logical digit order stays unchanged in an RTL field.');
    verify(3, '123-456-7890');
    await shot(
        'rtl', 2.2, 'Set textDirection on both the formatter and the field.');
    await tab('Phone');
    await shot('outro', 3.5,
        'Explore the example app and copy the setup from the README.');
    File('${output.path}/manifest.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
    WidgetsApp.debugAllowBannerOverride = true;
  });
}
