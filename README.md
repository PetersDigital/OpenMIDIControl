# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![CI Build](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/ci.yml?branch=main&style=for-the-badge&label=CI%20Build)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

- **App Namespace**: Unified Android (package) and iOS bundle identifiers directly to `com.petersdigital.openmidicontrol` (Standardized v0.2.2).

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Release Status

- **v0.2.2** (Current) Hybrid UMP implementation with manual 32-bit reconstruction, primitive EventChannel batching, and automated test suite.
- **v0.2.1** Canonical 32-bit `MidiEvent` model, `ControlState` immutability, `MidiPortBackend` abstraction, and high-precision native Diagnostics Logger.
- **v0.2.0** Advanced USB MIDI Peripheral Mode with native OS routing and performance batching.
- **v0.1.5** ships the original Flutter UI baseline plus MIDI bridge, auto reconnect, and metadata + mobile orientation improvements.
- Design + state guidance (see DESIGN.md and IMPLEMENTATION.md) now reflect the v0.2.2 implementation.

## Current UI & Controls

- **Responsive command center:** Layout switches between a portrait-focused command center (status row, 3×3 control pad, navigation icons) on phones and a desktop landscape layout with flexible panel ordering plus a dedicated track card.
- **HybridTouchFader controls:** Each fader uses `DSEG7Modern` readouts, per-control color cues, and a long-press CC picker so the UI can stay expressive while remaining MIDI-agnostic.
- **Settings & MIDI Configuration:** A settings drawer exposes fader-behavior modes (`jump`, `hybrid`, `catch-up`) and a hand-orientation toggle. The MIDI settings view allows discrete port selection with active-port highlighting (Blue/Green) and automatic persistence.
- **Material 3 theming:** M3 dark theme with `GoogleFonts.spaceGrotesk` / `Inter` text plus the obsidian surface palette keeps the interface consistent with the [DESIGN.md](DESIGN.md) system.

## Getting Started

1. Install Flutter 3.x and target Android 10+ or desktop/Windows devices.
2. Run `flutter pub get` inside the `app/` folder to fetch Riverpod, `google_fonts`, and other dependencies.
3. Use `flutter run -d <device>` to start the UI; the command center and fader layout automatically adapt to the screen width.
4. Launch the settings or MIDI settings screens from the top-right icons or the connection status text (e.g. "AVAILABLE", "DISCONNECTED") to configure your MIDI ports.


## Project Direction

- Android-first touch control for expressive MIDI performance
- DAW-agnostic baseline using standard MIDI messages
- Optional host-specific integrations only after the baseline is stable
- Deterministic behavior and defensive feedback-loop prevention

## Platform & Stack (baseline)

- Android 10+ (API 29+), scaling to tablets (iPadOS/Android) and Windows touch displays
- Flutter UI (Dart) for high-performance, cross-platform Material 3 rendering
- Core app is isolated in a subdirectory (e.g., `app/`) to maintain modularity for future host adapters and desktop bridges
- Target transport: wired USB-MIDI (v0.1.0 to v0.3.0); WebSockets/OSC (v0.4.0+) for advanced macro integration
- Build variants: debug (verbose logging, test harness) and release (reduced logging)

## Project Goals

1. Ship a clean baseline with low-latency fader control and reliable feedback.
2. Keep architecture modular so host integrations and advanced routing can be added safely.
3. Preserve protocol and reliability learnings in clear documentation.

## Technical Baseline

- Multi-touch pointer capture per control
- "Absolute/Relative" hybrid touch behavior: touch anywhere to capture, slide to change relatively (prevents jarring value jumps)
- Responsive LayoutBuilder UI:
  - **Phones (Portrait):** Top 30% dummy display/controls, Bottom 70% extra-long CC1/CC11 faders.
  - **Tablets/Windows (Landscape):** Grid layout (Faders on left, Display top-center, Macro space on right).
- State Management (Riverpod/Bloc) emitting "Intent" events to strictly decouple UI from transport layers
- Normalized internal value domain (`0.0..1.0`)
- MIDI input-driven UI feedback with touch override behavior
- Value-based deduplication and short time-window suppression to avoid echo loops
- **Virtual MIDI Port**: Exposes the app as a native MIDI source/sink for other mobile DAWs.
- **Metadata Persistence**: Uses device name and manufacturer fingerprints to maintain connections across USB hot-plugs.
- Rate limiting/coalescing to protect battery and thermal stability

## Version Roadmap (v0.1.0 to v1.0.0)

This roadmap tracks feature progress using Semantic Versioning. Progress is measured by functional milestones rather than specific dates.

### ✅ Completed

#### ✅ v0.1.0: Baseline
* Established core wired control and UI baseline.
* Implemented two expressive faders with high-precision tracking.
* Integrated internal MIDI test harness.

#### ✅ v0.1.5: MIDI Reliability & Logic Polish
* **Virtual MIDI Port**: Implemented a native Android MIDI device ("OpenMIDIControl") for local data routing.
* **Metadata Reconnection**: Added "fingerprint" matching (Name/Manufacturer) to handle transient Android IDs during USB hot-plugging.
* **Bi-directional Logic**: Applied Jump, Hybrid, and Catch-up behaviors to incoming hardware MIDI data.
* **UI Feedback**: Added translucent row highlighting for active input/output ports in MIDI settings.
* **Responsive UI**: Dedicated ultra-wide phone landscape layout (optimized for S24 Ultra).
* **Gesture Fixes**: Moved fader initialization to `onVerticalDragStart` to prevent accidental value jumps.
* **Haptic Stability**: Resolved JVM crashes by standardizing number-to-long casting for vibration durations.

#### ✅ v0.2.0: Advanced USB MIDI & Dual-Path Routing
* **True Peripheral Mode**: Native Android `MidiDeviceService` for class compliance on Windows 11.
* **Dual-Path Routing**: High-speed native Kotlin transport for peripheral mode.
* **Performance Batching**: 8ms Coroutine-based buffering for smooth UI fader rendering.
* **Binder Stability**: Port collision hiding and Dead Receiver Quarantine logic.

#### ✅ v0.2.1: Canonical Data & State Model
* **MidiPortBackend**: Unified abstraction for all future inputs (Native vs. USB Fallback).
* **Universal Payload**: Introduction of the internal **32-bit UMP-ready** MIDI format as the system source of truth.
* **Event vs. State Separation**: Decoupling raw transport data (`MidiEvent`) from UI-facing Riverpod logic (`ControlState`) with strict immutability.
* **Service Centralization**: Simplified event processing into a single-pass `MidiService` stream.
* **Diagnostic Tools**: Real-time MIDI event logger with native high-precision timestamps.

#### ✅ API 33+ Baseline (Post-v0.2.1)
- **SDK Exclusivity**: Enforced `minSdkVersion = 33` to provide native support for MIDI 2.0 and UMP (SHA `97e002e`).

### ✅ v0.2.2 – Hybrid UMP Implementation (Complete)

**Strategic Decision**: Retained `MidiDeviceService` over `MidiUmpDeviceService` due to Android's incomplete UMP implementation:
- `MidiUmpDeviceService` virtual UMP requires Android 15+ (API 35) and feature flag `FLAG_VIRTUAL_UMP`
- Hybrid approach provides 90% device coverage (Android 13-15) vs. 20% for native UMP

**Key Features**:
- **Manual 32-bit UMP Reconstruction**: `MidiParser.kt` processes `byte[]` in 4-byte chunks with big-endian reconstruction
- **UMP Transport Flag**: All ports opened with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` for MIDI 2.0 compatibility
- **Primitive EventChannel Batching**: Optimized JNI bridge using `LongArray` instead of `List<MidiEvent>` to reduce GC pressure
- **Automated Test Suite**: UMP transport tests with known payloads, validation of bitwise extraction logic
- **Defensive Bounds Checking**: Prevents DoS via malformed MIDI packets in native layer
- **Package Standardization**: Migrated to lowercase `com.petersdigital.openmidicontrol` namespace

**Performance**:
- 8ms batching interval (120Hz) with primitive `LongArray` for zero-allocation dispatch
- UMP reconstruction overhead: ~0.1-0.5ms (negligible vs. USB transport latency)
- Real-time message filtering (0xF8 Timing Clock, 0xFE Active Sensing) at native entry point

### ⏳ v0.2.3 – Core Routing Engine (UMP DAG)
- **MidiRouter Graph**: Centralized routing Directed Acyclic Graph (DAG) operating exclusively on 32-bit UMP payloads
- **Transformer Nodes**: Logic modules for filtering, remapping, and splitting UMP streams
- **Routing Presets**: Save/load routing configurations as JSON
- **Latency Monitoring**: Real-time UMP pipeline latency measurement (p50, p95, p99)

### ⏳ v0.3.0 – Performance Optimization & Control Expansion
**Performance**:
- **Kotlin SIMD UMP Reconstruction**: RenderScript-based batch processing targeting <0.1ms latency (4x speedup)
- **Zero-Copy Ring Buffer**: Replace Channel with shared memory ring buffer for JNI dispatch
- **GC Elimination**: Preallocate all UMP buffers, eliminate per-event allocations

**Controls**:
- **3x3 Pad Grid**: Velocity-sensitive pads with aftertouch support
- **Per-Note Polyphonic Aftertouch**: UMP-native per-note pressure control (MIDI 2.0)
- **32-bit High-Resolution CC**: Native 32-bit CC values instead of 7-bit (0-127)
- **Multi-Channel Assignment**: Per-control MIDI channel assignment (1-16)

**State**:
- **Raw Snapshots**: Save/load complete control state as JSON
- **Preset Management**: Quick-swap between routing/CC configurations

### ⏳ v0.4.0 – NDK Fast Path & DAW Integration
**NDK Fast Path** (MOVED UP from v0.5.0):
- **C++ AMidi Implementation**: Direct UMP handling via Android NDK
- **Dart FFI Bridge**: Zero-copy shared memory between NDK and Flutter
- **Sub-0.1ms Latency**: Target end-to-end UMP latency <100µs
- **No GC Jitter**: Complete elimination of Kotlin JVM garbage collection

**DAW Integration**:
- **DAW Profile Presets**: Pre-configured mappings for Cubase, Ableton, FL Studio
- **High-Res Pitch Bend**: 32-bit pitch bend resolution via UMP
- **MCU/HUI Protocol Core**: Basic Mackie Control and HUI transport mapping
- **MIDI-CI Handshake**: Capability Inquiry for MIDI 2.0 device discovery (see AGENTS.md TDR-004)

**Removed**:
- ~~Native UMP Backend Migration~~ (Hybrid approach is permanent)

### ⏳ v0.5.0 – Cross-Platform UMP Abstraction
**Platform Abstraction**:
- **ump_reconstructor.dart**: Platform-agnostic UMP bitwise extraction (shared)
- **ump_router.dart**: Cross-platform DAG routing engine (shared)

**iOS/iPadOS** (NEW):
- **Swift UMP Reconstruction**: Native iOS implementation using CoreMIDI
- **iPad Layout Optimization**: Tablet-first UI with expanded control surface

**Windows Desktop** (NEW):
- **WinRT MIDI Services**: Native Windows 11 MIDI 2.0 support
- **Desktop UI Layout**: Mouse/keyboard-optimized control surface

### ⏳ v0.6.0 – Plugin Architecture & Advanced Features
- **Custom Transformers**: User-authored UMP processing plugins (Dart API)
- **Network MIDI**: RTP-MIDI (Wi-Fi) and Bluetooth MIDI transport
- **OSC Bridge**: Open Sound Control protocol integration
- **Visual Feedback**: OLED display integration for parameter values

### ⏳ v0.7.0 – Layout Editor & Community Features
- **Visual Designer**: Drag-and-drop control surface builder
- **Preset Marketplace**: User-submitted routing/CC configurations
- **Plugin Repository**: Third-party transformer/plugin hosting

### ⏳ v1.0.0 – Stable Release & Contributor-Ready
- **API Stability**: Frozen public API for third-party developers
- **Test Coverage**: >90% unit test coverage, automated fuzzing
- **Performance**: All targets met (<0.1ms latency, 0% idle CPU)
- **Accessibility**: Full screen reader support, high-contrast themes

## Repository Status

- Documentation and implementation are evolving together.
- Decisions are tracked in [ARCHITECTURE.md](ARCHITECTURE.md), [USERGUIDE.md](USERGUIDE.md), and [CHANGELOG.md](CHANGELOG.md).
- Cubase-specific reference mappings live under [references/cubase](references/cubase) and inform optional host adapters

## Development Workflow

This repository follows:

- Semantic Versioning (SemVer)
- Conventional Commits
- Small, reviewable pull requests

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for contributor and agent guardrails.

## Credits

- Project: Peters Digital
- Contributors: maintainers and community contributors (see Git history)

Full attributions: [CREDITS.md](CREDITS.md)

## License

- Open source: GPL-3.0 ([LICENSE](LICENSE))
- Commercial licensing: available separately from Peters Digital
