### 1.0 Standards & References

**MIDI 1.0 Standards:**
- [MIDI.org Specifications (Official)](https://midi.org/developing-midi-applications-on-android) — Reference for RPN/NRPN, Control Changes, SysEx
- [General MIDI Level 1 Developer Guidelines](https://midi.org/general-midi-level-1-developer-guidelines) — Legacy compatibility baseline
- [MIDI 1.0 Complete Specification](https://www.midi.org/specifications-old/item/the-midi-1-0-specification) — Historical reference (archived)

**MIDI 2.0 (Emerging Standard for Cubase 15+):**
- [Microsoft MIDI 2.0 Documentation](https://microsoft.github.io/MIDI/) — Windows 11 2026 rollout, UMP protocol
- [Microsoft MIDI SDK & API Reference](https://microsoft.github.io/MIDI/sdk-reference/) — Native Windows MIDI 2.0 implementation
- [Microsoft MIDI GitHub](https://github.com/microsoft/MIDI) — Open-source MIDI 2.0 SDK for Windows
- [Windows MIDI Services (WinRT) Multi-Client](https://midi.org/midi-2-0-coming-to-windows-11) — Confirmation of native multi-client support in MIDI 2.0
- [Windows 11 MIDI Boost (Feb 2026)](https://blogs.windows.com/windowsexperience/2026/02/17/making-music-with-midi-just-got-a-real-boost-in-windows-11/) — Latest performance updates for WinRT MIDI
- [Cubase 15 New Features: RPN/NRPN Support](https://www.steinberg.help/r/cubase-pro/15.0/en/cubase_nuendo/topics/new_features/new_features.html) — Cubase MIDI 2.0 RPN/NRPN extensions overview
- [MIDI Association: New SysEx ID Policies (Oct 2025)](https://midi.org/new-midi-association-sysex-id-policies-as-of-oct-15-2025) — Rules for **0x7C** Non-Commercial ID usage
- [Curated MIDI 2.0 Resources for Developers](https://midi.org/curated-midi-2-0-resources-for-developers) — Official MIDI Association resource hub

**Cubase MIDI Remote API v1 (Official):**
- [Steinberg MIDI Remote API Documentation](https://steinbergmedia.github.io/midiremote_api_doc/) — Official GitHub Pages reference
- [API Version History](https://steinbergmedia.github.io/midiremote_api_doc/versions) — v1.1+ introduces Direct Access (`getParameterTitle`, `getParameterDisplayValue`)
- [AI Integration & Scripting Gap](https://forums.steinberg.net/t/full-scripting-api-for-cubase-the-ai-integration-gap-is-now-a-competitive-threat/1026258/62) — Discussion on Cubase 15 technical limits and performance
- [SysEx Logging Workaround](https://forums.steinberg.net/t/sending-logs-as-a-sysex-to-an-html-based-utility/1006723) — Pattern for streaming Cubase script metadata to external consoles
- [High Resolution MIDI 2.0 (Win 11)](https://forums.steinberg.net/t/high-resolution-midi-2-0-windows-11-which-version-of-cubase/1025711) — Technical requirements for Cubase 14/15 UMP transport

**Flutter/Dart MIDI Integration:**
- [Flutter Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels) — MethodChannel/EventChannel architecture
- [Dart async/await](https://dart.dev/guides/language/language-tour#async-await) — Concurrency & Future handling
- [Web MIDI API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API) — Browser-based MIDI access details
- [Web MIDI API Specification](https://webaudio.github.io/web-midi-api/) — W3C/WebAudio draft for low-level byte access

**Android Native MIDI:**
- [Android MIDI Architecture](https://source.android.com/docs/core/audio/midi_arch) — Kernel, HAL, and platform service routing
- [android.media.midi Package Documentation](https://android.googlesource.com/platform/frameworks/base/+/master/media/java/android/media/midi/package.html) — Inner workings of the Android MIDI stack
- [Android MIDI API Reference (Official)](https://developer.android.com/reference/android/media/midi/package-summary) — MidiManager, MidiDevice, MidiPort
- [Android NDK MIDI Guide](https://developer.android.com/ndk/guides/audio/midi) — Native C/C++ MIDI integration
- [AMidi NDK Reference](https://developer.android.com/ndk/reference/group/midi) — C API for MIDI I/O (v0.4.0 Fast Path)
- [MIDI 2.0 Android Samples](https://github.com/android/midi-samples) — Google reference implementations
- [MidiUmpDeviceService Reference](https://developer.android.com/reference/android/media/midi/MidiUmpDeviceService) — **API 35+ for virtual UMP, feature-flagged with FLAG_VIRTUAL_UMP**
- [Android 15 Developer Preview](https://android-developers.googleblog.com/2024/02/first-developer-preview-android15.html) — Virtual UMP support added in Android 15
- [RenderScript Intrinsics](https://developer.android.com/guide/topics/renderscript/compute) — SIMD optimization guide (v0.3.0)

**Android UMP Implementation Limitations (v0.2.2):**
- `MidiUmpDeviceService` virtual UMP requires **Android 15+ (API 35)**, not API 33
- Feature-flagged with `@FlaggedApi(Flags.FLAG_VIRTUAL_UMP)` — unreliable across OEMs
- Restrictive port constraints: input/output count must be equal and non-zero
- Only ~20% device coverage vs. 90% for hybrid approach (Android 13-15)
- OpenMIDIControl uses **hybrid UMP**: `MidiDeviceService` + manual 32-bit reconstruction in `MidiParser.kt`
- See ARCHITECTURE.md Section 3.2 for detailed hybrid implementation rationale

**NDK Fast Path (v0.4.0):**
- **Decision**: Migrate hot path to C++ NDK with Dart FFI (TDR-003)
- **Target**: Sub-0.1ms latency, zero GC jitter
- **API**: Android `AMidi` (NDK) with direct UMP support since API 33
- **Implementation**: Zero-copy shared memory ring buffer
- **See**: ARCHITECTURE.md Section 13.2 for architecture diagram

**Windows MIDI 2.0 (CRITICAL - Feb 2026 Update):**
- **Status**: Release Candidate 3 (RC3) - February 2026
- **Expected Stable**: March-April 2026 (1-2 months from RC3)
- **Expected Cubase 15 MIDI 2.0**: Q3 2026 (3-4 months after Windows stable)
- **MIDI-CI**: ✅ Included in Windows MIDI Services stack
- **Cubase 15**: ✅ Will add MIDI 2.0 support 3-4 months after Windows stable
- **NI Hardware**: ✅ Kontrol S49 Mk3 ships with MIDI 2.0 + MIDI-CI
- **macOS**: ✅ Cubase already supports MIDI 2.0 high-res (CoreMIDI)
- **Implementation**: v0.4.0 – MIDI-CI Handshake + Windows UMP Native
- **Deadline**: Q3 2026 (to align with Cubase 15 MIDI 2.0 release)
- **See**: ARCHITECTURE.md Section 13.4 for revised MIDI 2.0 strategy

**iOS / macOS Core MIDI:**
- [Apple Core MIDI Documentation](https://developer.apple.com/documentation/coremidi/) — Official reference for `MIDIProtocolID` and UMP abstractions
- [MIDI 2.0 on Apple Platforms](https://developer.apple.com/documentation/coremidi/midi_services/supporting_midi_2_0) — Implementation guide for native UMP endpoints and function blocks

**Open Source References:**
- [Arduino MIDI Library](https://github.com/FortySevenEffects/arduino_midi_library) — For future hardware integration (DIY MIDI controllers)
- [ni-midi2 GitHub](https://github.com/NativeInstruments/ni-midi2) — Reference model for UMP 1.1 / MIDI-CI 1.2 by Native Instruments

**Performance & Optimization:**
- [MIDI Latency Reduction Guide](https://www.sweetwater.com/insync/daw-latency/) — Sweetwater practical optimization strategies
**Platform & Protocol Specifics:**
- **Windows MIDI Services (WinRT)**: Multi-client by default. Multiple applications (e.g., Cubase 15 + OpenMIDIControl Logger) can share the same hardware port simultaneously.
- **Microsecond Precision**: The WinRT stack (as of **Feb 17, 2026 GA**) provides sub-millisecond timestamps accurate to **under a microsecond** (<1µs jitter), significantly boosting MIDI 2.0 / UMP reliability.
- **Android UMP Stack (API 33+)**: Hybrid implementation due to `MidiUmpDeviceService` limitations. Uses `MidiDeviceService` with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag and manual 32-bit reconstruction in `MidiParser.kt`. UMP packets reconstructed from `byte[]` buffers (4-byte chunks).
- **Apple UMP Protocol**: Uses `MIDIProtocolID.protocol_2_0` and specific `MIDIInputPortCreateWithProtocol` methods to enable 32-bit packet handling.
- **SysEx ID 0x7C**: Used for non-commercial UMP Endpoint Discovery. Allows native MIDI 2.0 recognition without unique commercial licensing.
- [USB Polling & Bandwidth](https://en.wikipedia.org/wiki/USB#Bandwidth_and_protocols) — USB 1.1 full-speed polling (1kHz interrupt intervals)