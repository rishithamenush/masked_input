# README demo video

The 36-second silent, captioned MP4 demonstrates the real example widgets and
package formatters. Screenshots are captured deterministically with Flutter's
widget-test renderer, using actual edit events and assertions on each result.
They are not mock field values. This is a product demonstration, not evidence of
physical keyboard, screen-reader, or platform IME certification.

Outputs in `doc/media`:

- `masked-input-demo.mp4`: 1600 × 900, 24 fps, H.264/yuv420p, fast-start playback.
- `demo-preview.gif`: 800 × 450, 8 fps, 3x speed, looping Markdown preview.
- `demo-poster.png`: full-resolution static preview.
- `chapters.json`: precise chapter start times.

The README uses a normal Markdown image linked to the MP4. The GIF animates in
renderers that do not support embedded video; the separate MP4 link also works as
a download fallback. Paths are relative to the package root, with no machine-local
paths or invented hosted URLs. A future pub.dev publication should configure the
real repository metadata so its README media can resolve correctly.

## Reproduce on macOS

Requires Flutter, Python with Pillow, ffmpeg, Arial, and Menlo. These are authoring
tools, not package dependencies. Run from the package directory:

```sh
cd example
flutter pub get
flutter build web
MASKED_INPUT_DEMO_OUTPUT=/tmp/masked-input-demo flutter test tool/capture_demo.dart
cd ..
python3 tool/demo/render.py /tmp/masked-input-demo
```

The capture harness uses the example's current layout and the fonts from the
Flutter SDK / built example. It disables debug banners and restores debug flags
after capture. The renderer adds chapter headings, explanatory code, burned-in
captions, brief crossfades, and a progress bar around the unaltered app frames.

After regenerating, verify the MP4 with `ffprobe`, inspect each chapter, and check
that README media paths exist. Keep raw captures outside the package.
