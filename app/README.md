# app

This folder contains the Flutter-based UI for OpenMIDIControl that ships as the **v0.1.0 release**.

## Overview

- Fully responsive command center + performance layout (portrait mobile and landscape desktop), built on Material 3 with a dark obsidian palette.
- Dual `HybridTouchFader` widgets drive the expressive controls, featuring DSEG7 readouts, long-press CC selection, and multi-touch capture with normalized `0.0..1.0` state values.
- Settings + MIDI Settings helpers expose behavior/layout toggles and the future port configuration UI so the Rust/Kotlin bridge can plug in when the hardware layers arrive.

## Features

1. **Command Center**: Status row (tempo, timecode, track), 3×3 transport grid, and responsive layout ordering that reflows between mobile/desktop and honors the layout-hand toggle.
2. **Performance zone**: Two color-coded faders with hybrid/absolute behaviors, tuned gutters, and glassy, LED-inspired readouts.
3. **Settings screens**: `Settings` controls Jump/Hybrid/Catch-Up modes, layout hand preference, and displays the current version/build metadata; `MIDI Settings` shows the disconnected alert + device search placeholder for the upcoming Kotlin bridge.
4. **State management**: Riverpod-driven providers keep layout and behavior state decoupled from the UI; future platform channels will bind to this intent stream.

## Getting Started

1. Install Flutter 3.11.0 or later and target Android 10+ (API 29) devices or Windows/macOS desktops.
2. From within this directory, run `flutter pub get` to pull `flutter_riverpod`, `google_fonts`, and other dependencies.
3. Use `flutter run -d <device>` (e.g., `flutter run -d emulator-5554` or a Windows target) to start the UI.
4. Interact with the settings (`⋯`) and MIDI settings (USB badge) icons in the top bar to explore the layout/behavior toggles and future MIDI tooling.
5. Long-press a fader label to bring up the CC picker and reassign CC numbers on the fly.

## Building

- `flutter build apk --release` to produce an Android APK.
- `flutter build macos` / `flutter build windows` for desktop prototypes (adjust accordingly for Linux if supported).
- Pass `--dart-define` flags when wiring native MIDI identifiers once the Kotlin bridge is in place.

## Testing

- `flutter test` runs the widget regression suite (the default `widget_test.dart` emulates a 1080×2400 viewport used by CI).

## Project Structure

- `lib/main.dart`: Entry point; wraps the UI in a `ProviderScope` and sets the Material 3 theme.
- `lib/ui/open_midi_screen.dart`: Contains the responsive mobile/desktop command center and imports the `HybridTouchFader` widgets.
- `lib/ui/hybrid_touch_fader.dart`: Custom slider with absolute/relative behaviors, DSEG7 readouts, and the CC picker long-press menu.
- `lib/ui/settings_screen.dart`: Fader behavior + layout toggles plus version metadata.
- `lib/ui/midi_settings_screen.dart`: Placeholder layout for MIDI device listings and connection status.

## References

- Design intent: [DESIGN.md](../DESIGN.md)
- Implementation roadmap: [IMPLEMENTATION.md](../IMPLEMENTATION.md)
- Change history: [CHANGELOG.md](../CHANGELOG.md)