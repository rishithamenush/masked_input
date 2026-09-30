# Release checklist

Automated results live in `VERIFICATION.md`. Unchecked items below require real
release context or hardware and are not implied by passing unit tests.

- [ ] Exercise the minimum Flutter 3.27 SDK and current stable in the configured CI.
- [ ] Run analyzer, tests, example widget tests, browser tests, web build, and pana.
- [ ] Android: Gboard and one OEM soft keyboard; keyboard switching, cursor edits,
  select-all, backspace/forward-delete, paste, and composing CJK input.
- [ ] iOS: the same input flows with soft keyboard and autocorrection/capitalization.
- [ ] Physical keyboard on mobile: backspace, forward-delete, selection shortcuts.
- [ ] Web: physical keyboard, select-all, clipboard paste, CJK IME commit/cancel.
- [ ] Windows/macOS/Linux: forward-delete and tab navigation on actual host apps.
- [ ] RTL locale: inspect visual order and caret behavior with Arabic text/digits.
- [ ] TalkBack/VoiceOver: check coherent value announcements and deliberate cursor
  movement on each example screen; verify large text on actual devices.
- [ ] Run the migration five-point checklist in the adopting application's forms.
- [ ] Measure 10,000 edits in profile/release on a mid-range Android device; target
  p99 under 1 ms. Host `flutter test` timings do not establish this target.
- [ ] Confirm owner/license attribution and final package name before publication.
- [ ] Create/configure the actual repository; add real `repository` and
  `issue_tracker` URLs to pubspec (never placeholder or unrelated URLs).
- [ ] Inspect `flutter pub publish --dry-run` and pana; resolve all actual warnings.
- [ ] Set CI's pana threshold to zero after public repository metadata is added.
- [ ] Recheck name availability on pub.dev; choose version and release notes.
- [ ] Publish/tag only when explicitly requested and all required gates are met.

Scoring algorithms change. A 160/160 target in the draft is not evidence of the
score of this package; report the observed score with its analyzer version.
