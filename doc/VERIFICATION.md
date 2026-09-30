# Verification record

Implementation checks were run locally on macOS during this task. Final recorded
commands use Flutter 3.35.0 / Dart 3.9.0 explicitly, avoiding per-directory SDK
selection. Earlier development also used the installed Flutter 3.29.2 toolchain.

| Check | Result |
| --- | --- |
| Static analysis | `flutter analyze`: no issues |
| Dart formatting | 14 files checked; no changes required |
| API documentation | Generated locally with zero warnings and zero errors |
| Publish dry-run | 287 KB archive; one warning for missing homepage/repository, exit 65; nothing published |
| Package regression/invariant tests | 45 passed on the Flutter VM |
| Browser regression/invariant tests | The same 45 passed in headless Chrome |
| Randomized edits | 10,000 deterministic operations per test run, seed 210930 |
| Example widget tests | 2 passed: four screens/state/clear, and 2x text scaling |
| Example web compilation | Release build succeeded; Wasm dry-run succeeded |
| Line coverage | 407 / 413 executable library lines (98.55%) before final lint-only brace edits |
| Host benchmark | 10,000 measured edits after 1,000 warmups; p50 1 us, p95 12 us, p99 45 us, max 1,280 us |

The benchmark uses Flutter test/JIT on the host. It does not establish a mobile
profile/release target. Coverage counts executable lines, not proof of correctness
or branch coverage. Synthetic composing tests are not physical IME verification.

Pana 0.22.22 reports **150/160** with successful dartdoc generation (zero warnings
and zero errors). The only missing 10 points are public homepage/repository
metadata. The package has no real public repository URL yet; it must be configured
before publication rather than filled with a fictitious link. All documentation,
license, static-analysis, and dependency scoring sections otherwise pass.

The test corpus names the §12.2 regression cases and exercises §6-§8: custom and
built-in filters, escapes/errors, raw/formatted input, structural completion,
lazy/eager rendering, dynamic masks, both deletion directions, positional holes,
selection/paste, deliberate cursor placement, programmatic changes, Unicode
letters/scalars, composing commit/cancel, direction, and currency conventions.

Unverified release gates are listed in `RELEASE_CHECKLIST.md`, including minimum
SDK CI execution, real mobile keyboards, accessibility, and physical-device
performance. The GitHub workflow is provided but has not run remotely because no
remote repository has been configured. Nothing has been published.
