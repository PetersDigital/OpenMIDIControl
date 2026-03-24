# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![CI Build](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/ci.yml?branch=main&style=for-the-badge&label=CI%20Build)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Release Status

- **v0.1.5** (Current) Refines the MIDI bridge with metadata-based reconnection persistence, virtual MIDI port support (Android), and high-precision discrete port selection.
- **v0.1.5** ships the original Flutter UI baseline plus MIDI bridge, auto reconnect, and metadata + mobile orientation improvements.
- Design + state guidance (see DESIGN.md and IMPLEMENTATION.md) now reflect the v0.1.5 implementation.

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

The project uses SemVer feature tracking instead of date promises.

- ✅ **v0.1.0**: Core wired control (UI baseline), two expressive faders, test harness.
- ✅ **v0.1.5**: **Refinement Phase**: Metadata reconnection, Virtual MIDI, and discrete port selection.
- ⏳ **v0.2.0**: Native MIDI service bridge (Finalizing wired USB/DIN transport baseline).
- ⏳ **v0.3.0**: Expanded controls (buttons/switches) and richer bidirectional state sync.
- ⏳ **v0.4.0+**: Optional desktop bridge and wireless transport (OSC/WebSockets).
- ⏳ **v1.0.0**: Stable contributor-ready architecture and official DAW integrations (Cubase, etc.).

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
