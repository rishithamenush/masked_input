# masked_input example

Run `flutter pub get`, then `flutter run -d chrome` (or select your connected
mobile/desktop device). No server or account is required.

Four independent screens demonstrate phone, date, currency, and right-to-left
entry. Each displays committed raw input and a clear control. Phone can change
its mask to include an extension; Date can toggle eager separators. Mask changes
are disabled while composing.

Run `flutter test` for widget tests covering each screen and large text scaling.
See the parent package's release checklist for manual keyboard/IME/accessibility
scenarios. Generated platform scaffolds alone do not imply device verification.
