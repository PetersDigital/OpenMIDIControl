# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![CI Build](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/ci.yml?branch=main&style=for-the-badge&label=CI%20Build)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

- **App Namespace**: Unified Android (package) and iOS bundle identifiers directly to `com.petersdigital.openmidicontrol` (Standardized v0.2.2).

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Release Status

- **v0.2.1** (Current) Canonical 32-bit `MidiEvent` model, `ControlState` immutability, `MidiPortBackend` abstraction, and high-precision native Diagnostics Logger.
- **v0.2.0** Advanced USB MIDI Peripheral Mode with native OS routing and performance batching.
- **v0.1.5** ships the original Flutter UI baseline plus MIDI bridge, auto reconnect, and metadata + mobile orientation improvements.
- Design + state guidance (see DESIGN.md and IMPLEMENTATION.md) now reflect the v0.2.0 implementation.

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

### ⏳ Current Focus: v0.2.2 – Native UMP Backend Migration
- **MidiUmpDeviceService**: Migrate system-wide virtual routing to Android's UMP-specific services.
- **SDK Constraint Handling**: Utilize legacy port classes for public API compatibility while enforcing UMP via transport flags.
- **Manual 32-bit Reconstruction**: Native implementation of 4-byte chunk reconstruction from standard `byte[]` buffers for 32-bit UMP delivery.

### ⏳ v0.2.3 – Core Routing Engine (UMP DAG)
- **MidiRouter Graph**: Centralized routing Directed Acyclic Graph (DAG) operating exclusively on 32-bit UMP payloads.
- **Transformer Nodes**: Logic modules for filtering, remapping, and splitting UMP streams.

### ⏳ v0.3.0 – Control Expansion & High-Res State
- **Grid & Tactile Inputs**: 3x3 pads, buttons, and switches.
- **Native 32-bit Resolution UI**: Upgrade faders to leverage native UMP high-resolution values.
- **Raw Snapshots**: Basic save/load functionality via the `ControlState` model.

### ⏳ v0.4.x – MIDI-CI & The MCU / HUI Protocol Series
- **v0.4.0 (MIDI-CI Handshake)**: Capability Inquiry negotiation to declare the device as a MIDI 2.0 peripheral to the DAW.
- **v0.4.1 (Core Logic)**: MCU protocol mapping translated through the UMP pipeline.
- **v0.4.2 (Feedback)**: LCD track naming logic and bank switching feedback.

### ⏳ v0.5.0 – Native DAW Scripts & Architecture Review
* **Remote Scripts**: Python/JS integrations for Ableton, Cubase, and Logic.
* **Performance Audit**: Benchmarking Kotlin Coroutine jitter and throughput.
* **NDK Fast Path (Conditional)**: Migration to C++ AMidi and Dart FFI if Kotlin limits are reached.

### ⏳ experimental/v0.5.x – MIDI 2.0 Native Path
* **MIDI-CI Handshake**: Formal Capability Inquiry negotiation.
* **OS UMP Integration**: Direct UMP payload transfer to Windows/macOS if supported.

### ⏳ v0.6.0 – Full Preset Engine
* **Dynamic Mapping**: Quick-flip layout modes (e.g., Orchestral vs. Synth mapping).
* **Project Presets**: Advanced snapshot management and schema saving.

### ⏳ v0.7.0 – Layout Editor
* **Serializable Schema**: Requirement for all UI controls to be generated from JSON/config.
* **Visual Editor**: Drag-and-drop resizing and positioning.
* **Aesthetic Polish**: Glow trails and friction physics.

### ⏳ v0.8.0 – Wireless Transport & Desktop Bridge
* **Wireless MIDI**: Support for rtpMIDI (Wi-Fi) and Bluetooth MIDI.
* **Bridge Protocols**: OSC and WebSocket support for custom bridges.

### ⏳ v0.9.0 – Plugin & API Layer
* **Extension Hooks**: Public API for custom transformers and layouts.
* **Extensibility Stabilization**: Locking the API surface for v1.0.

### ⏳ v1.0.0 – Contributor-Ready Release
* **Stable Architecture**: Fully documented API and third-party developer resources.
* **Final Polish**: Global bug squashing and UX refinement.

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
