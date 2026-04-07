![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)

This folder contains the Flutter application source. See the [root README](../README.md) for project overview, architecture, and getting started.

## Quick Reference

**Dependencies:**
```bash
flutter pub get
```

**Run:**
```bash
flutter run -d <device>
```

**Build:**
```bash
flutter build apk --release        # Android
flutter build windows --release    # Windows
```

**Test:**
```bash
flutter test                        # All tests
flutter test test/midi_event_test.dart          # Core models
flutter test test/control_state_test.dart       # State management
flutter test test/open_midi_screen_test.dart    # Main screen & faders
flutter test test/midi_pipeline_integration_test.dart # Integration (10K stress)
```

See [TESTING.md](../TESTING.md) for complete test suite documentation.

## Project Structure

```
lib/
├── main.dart                          # Entry point, ProviderScope, M3 theme
├── core/
│   └── models/
│       ├── midi_event.dart            # Immutable 32-bit UMP event model
│       └── control_state.dart         # Riverpod state with immutability
└── ui/
    ├── open_midi_screen.dart          # Responsive command center layout
    ├── hybrid_touch_fader.dart        # Fader with Jump/Hybrid/Catch-up
    ├── midi_service.dart              # EventChannel batching & state distribution
    ├── settings_screen.dart           # Behavior toggles, version metadata
    ├── midi_settings_screen.dart      # Port selection, USB status
    └── diagnostics/                   # Real-time MIDI event logger
```

## Key Changes in v0.2.2

- **MidiEvent Model**: Simplified to single 32-bit `ump` integer with bitwise extraction getters
- **EventChannel Batching**: Uses `Int64List` (UMP + timestamp pairs) instead of `Map` objects for ~40% throughput improvement
- **Stream Architecture**: `late final` streams prevent subscription leaks
- **Thermal Stability**: Value deduplication, 8ms fader throttle, batched diagnostics

## References

- Design: [DESIGN.md](../DESIGN.md)
- Architecture: [ARCHITECTURE.md](../ARCHITECTURE.md)
- Roadmap: [IMPLEMENTATION.md](../IMPLEMENTATION.md)
- Changelog: [CHANGELOG.md](../CHANGELOG.md)
- Testing: [TESTING.md](../TESTING.md)
