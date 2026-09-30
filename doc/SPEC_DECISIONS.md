# Interpretation of the v0.1.0 draft

The PDF is the product reference, not authorization to publish, contact upstream
maintainers, or replace this requested implementation with work on another project.
This package was independently written; no competing implementation was copied.
Research claims about competitors are not repeated as package marketing.

| Draft ambiguity/open decision | Implemented decision |
| --- | --- |
| D1 name | `masked_input`, provisional until actual publication checks |
| D2 origin | Independent implementation from the supplied behavior specification |
| D3 empty mask | Throw `MaskSyntaxError` |
| D4 digits | ASCII only by default; filters can opt into Unicode digits |
| D5 graphemes | Runes/scalars; document extended-cluster limitations |
| D6 helpers | Top-level `maskText` and `unmaskText` |
| D7 currency scope | Ten explicit locale conventions, configurable symbols/separators |
| D8 enum | Keep `MaskAutoCompletionType` with lazy/eager |
| D9 minimum | Declare Dart 3.6 / Flutter 3.27; track actual verification separately |
| D10 editing | Positional overtype for masks; currency uses digit-stream insertion |

## Conflicting examples and behavior

- The phone example includes `+1` as a literal, but lists raw input beginning with
  `1`. Raw values contain only placeholder data, so the correct raw example is
  `5551234567`. Use a `#` for an editable country code.
- The regression table pastes emoji into `A`; the letter definition rejects it.
  Emoji safety is tested with `*`, and rejection is tested with `A`.
- The prose says `clear()` resets a controller, while the API gives the formatter
  no controller. Both `clear()` and `updateMask()` return `TextEditingValue` for
  explicit assignment. The example does this correctly.
- The IME prose requests partial formatting while preserving a composing range.
  Flutter's contract says to modify text only once composition is collapsed.
  Therefore the complete composing value is returned untouched; formatting occurs
  on commit. Accessors expose the previous committed state while composing.
- The date regression says cursor "after 6", while §7.1 says skip rendered
  literals to the next placeholder. We follow §7.1: offset 3 in `26/09/2026`,
  not offset 2 or the end of the field.
- Holes render without placeholder markers, as the deletion example requires.
  State retains their slot positions. Re-importing a plain formatted string cannot
  uniquely recover holes; this is documented rather than guessed.
- `updateMask` compacts raw characters and remaps the cursor by slot, as §6.5/§7.6
  specify; ordinary editing does not compact. Filters are merged with built-ins.
- RTL governs Flutter visual direction, not reverse entry or reversed raw data.
- Locale-aware currency means configurable minor-unit formatting, not parsing
  arbitrary localized numbers or accepting negative values. These are explicit
  boundaries since the draft does not define sign/decimal-entry semantics.
- Rendering/editing uses O(mask + inserted input) traversal plus allocations for
  immutable state/maps. The draft's claim of no allocations beyond the string
  is not made; custom RegExp costs are caller-controlled.

## Scope and release status

Implementation is version 0.1.0. It includes the parser, pure editing/rendering
engine, Flutter bindings, currency conventions, examples, automated tests, and
repository guidance. Device testing, TalkBack/VoiceOver checks, registry naming,
remote repository metadata, and actual publication remain release operations.
