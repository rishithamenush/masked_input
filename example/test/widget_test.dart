import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masked_input_example/main.dart';

String fieldText(WidgetTester tester, int index) => tester
    .widget<EditableText>(find.descendant(
        of: find.byKey(ValueKey('input-$index')),
        matching: find.byType(EditableText)))
    .controller
    .text;

void main() {
  testWidgets('four screens format, retain separate state, and clear',
      (tester) async {
    await tester.pumpWidget(const MaskedInputExample());
    await tester.enterText(find.byKey(const ValueKey('input-0')), '5551234567');
    await tester.pump();
    expect(fieldText(tester, 0), '+1 (555) 123-4567');
    expect(find.text('5551234567'), findsOneWidget);
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-1')), '25092026');
    await tester.pump();
    expect(fieldText(tester, 1), '25/09/2026');
    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-2')), '125000');
    await tester.pump();
    expect(fieldText(tester, 2), r'$1,250.00');
    await tester.tap(find.text('RTL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-3')), '1234567890');
    await tester.pump();
    expect(fieldText(tester, 3), '123-456-7890');
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: find.byKey(const ValueKey('input-3')),
                matching: find.byType(EditableText)))
            .textDirection,
        TextDirection.rtl);
    await tester.tap(find.text('Clear field'));
    await tester.pump();
    expect(find.text('(empty)'), findsOneWidget);
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 0), '+1 (555) 123-4567');
  });
  testWidgets('large text scaling has no layout exceptions', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaskedInputExample());
    for (final label in ['Phone', 'Date', 'Currency', 'RTL']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
