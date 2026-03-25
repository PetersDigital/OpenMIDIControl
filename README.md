# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![CI Build](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/ci.yml?branch=main&style=for-the-badge&label=CI%20Build)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Release Status

- **v0.2.0** (Current) Advanced USB MIDI Peripheral Mode with native OS routing, Coroutine-based performance batching, and dual-path transport for ultra-low latency.
- **v0.1.5** ships the original Flutter UI baseline plus MIDI bridge, auto reconnect, and metadata + mobile orientation improvements.
- Design + state guidance (see DESIGN.md and IMPLEMENTATION.md) now reflect the v0.2.0 implementation.

## Current UI & Controls

- **Responsive command center:** Layout switches between a portrait-focused command center (status row, 3×3 control pad, navigation icons) on phones and a desktop landscape layout with flexible panel ordering plus a dedicated track card.
- **HybridTouchFader controls:** Each fader uses `DSEG7Modern` readouts, per-control color cues, and a long-press CC picker so the UI can stay expressive while remaining MIDI-agnostic.
- **Settings & MIDI Configuration:** A settings drawer exposes fader-behavior modes (`jump`, `hybrid`, `catch-up`) and a hand-orientation toggle. The MIDI settings view allows discrete port selection with active-port highlighting (Blue/Green) and automatic persistence.
- **Material 3 theming:** M3 dark theme with `GoogleFonts.spaceGrotesk` / `Inter` text plus the obsidian surface palette keeps the interface consistent with the Ethereal Console system.

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
- MIDI CC output with optional 14-bit precision (MSB/LSB pairs)
- MIDI input-driven UI feedback with touch override behavior
- Value-based deduplication and short time-window suppression to avoid echo loops
- **Virtual MIDI Port**: Exposes the app as a native MIDI source/sink for other mobile DAWs.
- **Metadata Persistence**: Uses device name and manufacturer fingerprints to maintain connections across USB hot-plugs.
- Rate limiting/coalescing to protect battery and thermal stability

## Version Roadmap (v0.1.0 to v1.0.0)

This roadmap tracks feature progress using Semantic Versioning. Progress is measured by functional milestones rather than specific dates.

### ✅ v0.1.0: Baseline
* Established core wired control and UI baseline.
* Implemented two expressive faders with high-precision tracking.
* Integrated internal MIDI test harness.

### ✅ v0.1.5: MIDI Reliability & Logic Polish
* **Virtual MIDI Port**: Implemented a native Android MIDI device ("OpenMIDIControl") for local data routing.
* **Metadata Reconnection**: Added "fingerprint" matching (Name/Manufacturer) to handle transient Android IDs during USB hot-plugging.
* **Bi-directional Logic**: Applied Jump, Hybrid, and Catch-up behaviors to incoming hardware MIDI data.
* **UI Feedback**: Added translucent row highlighting for active input/output ports in MIDI settings.
* **Responsive UI**: Dedicated ultra-wide phone landscape layout (optimized for S24 Ultra).
* **Gesture Fixes**: Moved fader initialization to `onVerticalDragStart` to prevent accidental value jumps.
* **Haptic Stability**: Resolved JVM crashes by standardizing number-to-long casting for vibration durations.

### ✅ v0.2.0: Advanced USB MIDI & Dual-Path Routing
* **True Peripheral Mode**: Native Android `MidiDeviceService` for class compliance on Windows 11.
* **Dual-Path Routing**: High-speed native Kotlin transport for peripheral mode.
* **Performance Batching**: 8ms Coroutine-based buffering for smooth UI fader rendering.
* **Binder Stability**: Port collision hiding and Dead Receiver Quarantine logic.

### ⏳ Current Focus: v0.3.0 (Control Expansion)
* **Grid System**: Addition of a 3×3 performance pad grid.
* **Tactile Inputs**: Implementation of buttons, toggles, and multi-state switches.
* **Multi-Channel Support**: Ability to assign individual controls to different MIDI channels.

### ⏳ v0.4.0: Mackie Control Universal (MCU) & HUI
* **High Resolution**: Support for 14-bit fader resolution via Pitch Bend messages.
* **DAW Handshake**: Native MCU/HUI protocols for instant integration with major DAWs.
* **LCD Logic**: Automatic track naming and bank switching feedback.

### ⏳ v0.5.0: Native DAW Integrations
* **Remote Scripts**: Official integration scripts for Cubase, Ableton Live, and Logic Pro.
* **Cubase Focus**: Deep integration with the Cubase MIDI Remote API.

### ⏳ v0.6.0: Preset Engine & Snapshots
* **Snapshots**: Save and load fader/CC configurations as project-specific presets.
* **Dynamic Mapping**: Quick-flip between layout modes (e.g., Orchestral CC1/11 vs. Synth CC74/71).

### ⏳ v0.7.0: Ethereal Layout Editor
* **Visual Customization**: Drag-and-drop editor to resize and reposition UI elements.
* **Aesthetic Polish**: Implementation of "Ethereal Console" visual effects, including glow trails and friction physics.

### ⏳ v0.8.0+: Desktop Bridge & Wireless Transport
* **Wireless MIDI**: Support for rtpMIDI (Wi-Fi) and Bluetooth MIDI.
* **Advanced Transport**: OSC and WebSocket support for custom desktop bridge applications.

### ⏳ v1.0.0: Contributor-Ready Release
* **Stable Architecture**: Documented API for third-party layout and integration contributors.
* **Performance Optimization**: Final tuning for ultra-low latency and jitter-free performance.

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

- Project: PetersDigital
- Contributors: maintainers and community contributors (see Git history)

Full attributions: [CREDITS.md](CREDITS.md)

## License

- Open source: GPL-3.0 ([LICENSE](LICENSE))
- Commercial licensing: available separately from PetersDigital
