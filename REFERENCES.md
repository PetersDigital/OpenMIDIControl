### 1.0 Standards & References

**MIDI 1.0 Standards:**
- [MIDI.org Specifications (Official)](https://midi.org/developing-midi-applications-on-android) — Reference for RPN/NRPN, Control Changes, SysEx
- [MIDI 1.0 Complete Specification](https://www.midi.org/specifications-old/item/the-midi-1-0-specification) — Historical reference (archived)

**MIDI 2.0 (Emerging Standard for Cubase 15+):**
- [Microsoft MIDI 2.0 Documentation](https://microsoft.github.io/MIDI/) — Windows 11 2026 rollout, UMP protocol
- [Microsoft MIDI SDK & API Reference](https://microsoft.github.io/MIDI/sdk-reference/) — Native Windows MIDI 2.0 implementation
- [Microsoft MIDI GitHub](https://github.com/microsoft/MIDI) — Open-source MIDI 2.0 SDK for Windows
- [Cubase 15 New Features: RPN/NRPN Support](https://www.steinberg.help/r/cubase-pro/15.0/en/cubase_nuendo/topics/new_features/new_features.html) — Cubase MIDI 2.0 RPN/NRPN extensions overview

**Cubase MIDI Remote API v1 (Official):**
- [Steinberg MIDI Remote API Documentation](https://steinbergmedia.github.io/midiremote_api_doc/) — Official GitHub Pages reference
- [API Getting Started](https://steinbergmedia.github.io/midiremote_api_doc/getting-started) — Quick introduction
- [Code Examples & Samples](https://steinbergmedia.github.io/midiremote_api_doc/code-examples) — Reference implementations
- [Complete API Reference](https://steinbergmedia.github.io/midiremote_api_doc/codedoc_api_reference) — Full class/method documentation (TrackSelection, Transport, callbacks)
- [API Version History](https://steinbergmedia.github.io/midiremote_api_doc/versions) — MIDI Remote v1.0 → v1.1+ evolution
- [User Scripts Repository](https://github.com/steinbergmedia/midiremote-userscripts) — Community scripts (Behringer BCR2000, PreSonus FaderPort8, Alesis VI49)
- [API Documentation Source](https://github.com/steinbergmedia/midiremote_api_doc) — GitHub markdown source (reference)

**Flutter/Dart MIDI Integration:**
- [Flutter Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels) — MethodChannel/EventChannel architecture
- [Dart async/await](https://dart.dev/guides/language/language-tour#async-await) — Concurrency & Future handling

**Android Native MIDI:**
- [Android MIDI API Reference (Official)](https://developer.android.com/reference/android/media/midi/package-summary) — MidiManager, MidiDevice, MidiPort
- [Android NDK MIDI Guide](https://developer.android.com/ndk/guides/audio/midi) — Native C/C++ MIDI integration
- [Android MIDI on Source](https://source.android.com/docs/core/audio/midi) — Kernel & HAL level documentation
- [MIDI 2.0 Android Samples](https://github.com/android/midi-samples) — Google reference implementations for Android

**Open Source References:**
- [Arduino MIDI Library](https://github.com/FortySevenEffects/arduino_midi_library) — For future hardware integration (DIY MIDI controllers)

**Performance & Optimization:**
- [MIDI Latency Reduction Guide](https://www.sweetwater.com/insync/daw-latency/) — Sweetwater practical optimization strategies
- [USB Polling & Bandwidth](https://en.wikipedia.org/wiki/USB#Bandwidth_and_protocols) — USB 1.1 full-speed polling (1kHz interrupt intervals)