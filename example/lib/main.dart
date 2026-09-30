import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masked_input/masked_input.dart';

/// Starts the interactive package example.
void main() => runApp(const MaskedInputExample());

/// Four independent fields demonstrating the package's input modes.
class MaskedInputExample extends StatelessWidget {
  /// Creates the example app.
  const MaskedInputExample({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Masked input',
        theme: ThemeData(
            colorSchemeSeed: const Color(0xff246b59), useMaterial3: true),
        home: const _Examples(),
      );
}

class _Examples extends StatefulWidget {
  const _Examples();
  @override
  State<_Examples> createState() => _ExamplesState();
}

class _ExamplesState extends State<_Examples> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Masked input')),
        body: IndexedStack(index: _index, children: const [
          _FieldDemo(kind: 0),
          _FieldDemo(kind: 1),
          _FieldDemo(kind: 2),
          _FieldDemo(kind: 3),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.phone_outlined), label: 'Phone'),
            NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined), label: 'Date'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined), label: 'Currency'),
            NavigationDestination(
                icon: Icon(Icons.format_textdirection_r_to_l), label: 'RTL'),
          ],
        ),
      );
}

class _FieldDemo extends StatefulWidget {
  const _FieldDemo({required this.kind});
  final int kind;
  @override
  State<_FieldDemo> createState() => _FieldDemoState();
}

class _FieldDemoState extends State<_FieldDemo> {
  final _controller = TextEditingController();
  late final TextInputFormatter _formatter;
  bool _eager = false;
  bool _longPhone = false;
  @override
  void initState() {
    super.initState();
    _formatter = switch (widget.kind) {
      0 => MaskFormatter(mask: '+1 (###) ###-####'),
      1 => MaskFormatter(mask: '##/##/####'),
      2 => CurrencyFormatter(),
      _ =>
        MaskFormatter(mask: '###-###-####', textDirection: TextDirection.rtl),
    };
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mask = _formatter is MaskFormatter ? _formatter : null;
    final currency = _formatter is CurrencyFormatter ? _formatter : null;
    final titles = [
      'Phone number',
      'Date',
      'Currency amount',
      'Right-to-left ID'
    ];
    final hints = [
      '+1 (555) 123-4567',
      '25/09/2026',
      r'$1,250.00',
      '123-456-7890'
    ];
    final descriptions = [
      'Edit any digit in place. Backspace across punctuation removes one digit. The fixed +1 prefix is not part of the raw value.',
      'The mask formats the shape of a date. A separate validator must check whether the date exists.',
      'Enter minor units: 125000 becomes \$1,250.00. Each backspace removes one entered digit.',
      'Digits stay in logical order. Flutter controls their visual order in this right-to-left field.',
    ];
    final composing = _controller.value.composing.isValid &&
        !_controller.value.composing.isCollapsed;
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(titles[widget.kind],
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(descriptions[widget.kind]),
            const SizedBox(height: 28),
            TextFormField(
              key: ValueKey('input-${widget.kind}'),
              controller: _controller,
              inputFormatters: [_formatter],
              textDirection:
                  widget.kind == 3 ? TextDirection.rtl : TextDirection.ltr,
              keyboardType:
                  widget.kind == 0 ? TextInputType.phone : TextInputType.number,
              decoration: InputDecoration(
                  labelText: titles[widget.kind],
                  hintText: hints[widget.kind],
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Committed raw value'),
                        const SizedBox(height: 8),
                        SelectableText(
                            (mask?.unmaskedText ?? currency!.unmaskedText)
                                    .isEmpty
                                ? '(empty)'
                                : mask?.unmaskedText ?? currency!.unmaskedText),
                        const SizedBox(height: 12),
                        Text(mask == null
                            ? 'Minor-unit digits; no floating-point conversion.'
                            : 'All slots filled: ${mask.isComplete ? "yes" : "no"}'),
                        if (composing)
                          const Text(
                              'Composition in progress; formatting waits for commit.'),
                      ],
                    ))),
            if (widget.kind == 1)
              SwitchListTile(
                title: const Text('Show separators eagerly'),
                value: _eager,
                onChanged: composing
                    ? null
                    : (enabled) => setState(() {
                          _eager = enabled;
                          _controller.value = mask!.updateMask(
                              type: enabled
                                  ? MaskAutoCompletionType.eager
                                  : MaskAutoCompletionType.lazy);
                        }),
              ),
            if (widget.kind == 0)
              SwitchListTile(
                title: const Text('Include a three-digit extension'),
                value: _longPhone,
                onChanged: composing
                    ? null
                    : (enabled) => setState(() {
                          _longPhone = enabled;
                          _controller.value = mask!.updateMask(
                              mask: enabled
                                  ? '+1 (###) ###-#### ext. ###'
                                  : '+1 (###) ###-####');
                        }),
              ),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller.value = mask?.clear() ?? currency!.clear();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear field'),
                )),
          ]),
        ));
  }
}
