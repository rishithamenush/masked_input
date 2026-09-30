# Migration from mask_text_input_formatter

This is a behavioral migration, not a binary-compatible replacement. Use a new
formatter per field and test real keyboard sequences in your app.

| Old API | masked_input |
| --- | --- |
| `MaskTextInputFormatter(mask: ..., filter: ...)` | `MaskFormatter(mask: ..., filter: ...)` |
| `getMaskedText()` | `maskedText` |
| `getUnmaskedText()` | `unmaskedText` |
| `isFill()` | `isComplete` |
| `clear()` | `controller.value = formatter.clear()` |
| `updateMask(...)` | `controller.value = formatter.updateMask(...)` |
| Instance `maskText` / `unmaskText` | Top-level `maskText(text, mask: ...)` / `unmaskText(text, mask: ...)` |

Keep the `MaskAutoCompletionType` name, importing it from `masked_input`. Built-in
`A`, `N`, and `*` now have specified meanings; escape them when you intend literals.
`#` is ASCII-only unless explicitly overridden. Custom filters match whole scalars.

Verify these five behaviors in your application:

1. Editing a filled slot in the middle replaces it and keeps the caret at the next
   slot, rather than moving to the field end.
2. Backspace adjacent to punctuation removes one user character and retains all
   other characters in their original slots. Forward-delete mirrors this.
3. Clearing both field and formatter, then retyping, starts from empty state.
4. Invalid typed characters preserve text/caret; invalid pasted characters are
   skipped. Invalid selection replacement still clears selected slots.
5. Non-ASCII digits are rejected by default. Literal prefixes never appear in raw
   text, even if a prefix contains numeric characters.

Additional boundaries: empty masks throw; IME values remain untouched until commit;
Unicode atomic units are scalars; holes require retained formatter state; direction
must also be set on the field. This package does not promise equivalent behavior
for every legacy edge case. Currency uses raw minor-unit digits and has no legacy
formatter compatibility claim.
