import 'package:flutter/services.dart';

TextEditingValue editing(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

TextEditingValue type(
    TextInputFormatter formatter, TextEditingValue old, String input) {
  final start = old.selection.start;
  final end = old.selection.end;
  return formatter.formatEditUpdate(old,
      editing(old.text.replaceRange(start, end, input), start + input.length));
}

TextEditingValue backspace(TextInputFormatter formatter, TextEditingValue old) {
  final cursor = old.selection.extentOffset;
  final start = old.selection.isCollapsed ? cursor - 1 : old.selection.start;
  return formatter.formatEditUpdate(
      old, editing(old.text.replaceRange(start, old.selection.end, ''), start));
}

TextEditingValue delete(TextInputFormatter formatter, TextEditingValue old) {
  final start = old.selection.start;
  final end = old.selection.isCollapsed ? start + 1 : old.selection.end;
  return formatter.formatEditUpdate(
      old, editing(old.text.replaceRange(start, end, ''), start));
}
