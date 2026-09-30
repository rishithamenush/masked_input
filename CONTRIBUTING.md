# Contributing

Use the declared minimum SDK or newer. Resolve dependencies, then run `dart format
lib test example/lib example/test`, `flutter analyze`, and `flutter test --coverage`.
In `example`, run `flutter pub get` and `flutter test`. CI checks the minimum and
current stable SDKs, with package-quality analysis as a separate job.

Every behavior change needs a regression test specifying the mask, old/new
TextEditingValue, exact text, selection, and composing range. Add public API
dartdoc and a CHANGELOG entry. Preserve the rule that runtime dependencies come
only from the Flutter SDK; discuss any proposed addition before implementation.
Do not add validation, numeric parsing, native channels, I/O, or widgets to the
library. The example app is separate.

Use the bug template for input-method problems: include OS, device, keyboard,
Flutter version, mask/filter, exact edit sequence, expected output and actual
output. Prefer a reproducible formatter test to screenshots alone. Do not include
real customer phone numbers, card details, or identifiers in fixtures.

Editing behavior is part of the public contract. Stable releases use semantic
versioning; changes to established edit behavior require a major release. For
pre-1.0 breaking changes, increase the minor version and describe migration.
See `doc/RELEASE_CHECKLIST.md` before tagging or publishing. No response/fix SLA
is promised by generated repository documentation.
