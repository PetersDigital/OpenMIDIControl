# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![Production](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/cd_auto_prod.yml?style=for-the-badge&label=Production)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

- **App Namespace**: Unified Android (package) and iOS bundle identifiers directly to `com.petersdigital.openmidicontrol` (Standardized v0.2.2).

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Release Status

- **v0.3.0** (Current) Core Routing Engine (DAG-based `MidiRouter`), **OMC Ecosystem Unification** (Standardized `.omc` persistence for presets and layouts), **PerformanceTickerMixin** (with `safeStartTicker` guards), orientation-driven layout hardening, and **Dynamic Connection Island**. Finalized **Extreme Thermal Hardening** (primitive packing, buffer reuse, lock-free native pipeline, headless compositor suppression, ~2MB/sec allocation reduction).
- **v0.2.2** (Previous) Native UMP backend migration with comprehensive automated test suite, MidiParser extraction, thermal stabilization, and Dart layer UMP integration.
- **v0.2.1** Canonical 32-bit `MidiEvent` model, `ControlState` immutability, `MidiPortBackend` abstraction, and high-precision native Diagnostics Logger.
- **v0.2.0** Advanced USB MIDI Peripheral Mode with native OS routing and performance batching.
- **v0.1.5** ships the original Flutter UI baseline plus MIDI bridge, auto reconnect, and metadata + mobile orientation improvements.
- Design + state guidance (see DESIGN.md and IMPLEMENTATION.md) now reflect the v0.3.0 implementation.

## Current UI & Controls

- **Responsive command center:** Layout switches between a portrait-focused command center and a desktop landscape layout. Includes a **Dynamic Connection Island** for real-time MIDI status and a side-agnostic flyout panel for landscape settings.
- **HybridTouchFader controls:** Each fader uses `DSEG7Modern` readouts, per-control color cues, and a long-press CC picker so the UI can stay expressive while remaining MIDI-agnostic.
- **Settings & MIDI Configuration:** A settings drawer exposes fader-behavior modes (`jump`, `hybrid`, `catch-up`) and a **Panel Position** toggle for landscape docking. The MIDI settings view allows discrete port selection with active-port highlighting and automatic persistence.
- **Material 3 theming:** M3 dark theme with `GoogleFonts.spaceGrotesk` / `Inter` text plus the obsidian surface palette keeps the interface consistent with the [DESIGN.md](DESIGN.md) system.
- **Snapshots & Presets:** Save and recall complex UI layouts and control states directly from the settings drawer, backed by the DAG-based routing engine.

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

- Android 13+ (API 33+), scaling to tablets (iPadOS/Android) and Windows touch displays (enforced for UMP support)
- Flutter UI (Dart) for high-performance, cross-platform Material 3 rendering
- Core app is isolated in a subdirectory (e.g., `app/`) to maintain modularity for future host adapters and desktop bridges
- Target transport: Universal MIDI Packets (UMP), wired USB-MIDI (v0.1.0 to v0.3.0); WebSockets/OSC (v0.4.0+) for advanced macro integration
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
- **DAG Routing:** Advanced node-based graph processing (`MidiRouter`) allowing modular splitting, remapping, filtering, and state syncing.
- **Universal MIDI Packets (UMP):** Fully migrated to a 32-bit `MidiEvent` architecture ensuring forward compatibility with MIDI 2.0 standards.

## Version Roadmap

The complete implementation history, current focus, and future version roadmap (v0.1.0 through v1.0.0) is maintained exclusively in [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Repository Status

- Documentation and implementation are evolving together.
- Decisions are tracked in [ARCHITECTURE.md](ARCHITECTURE.md), [USERGUIDE.md](USERGUIDE.md), and [CHANGELOG.md](CHANGELOG.md).
- Cubase-specific reference mappings live under [references/cubase](references/cubase) and inform optional host adapters

## Development Workflow

This repository follows:

- Semantic Versioning (SemVer)
- Conventional Commits
- Small, reviewable pull requests
- Modular CI/CD with 13 workflows and 11 composite actions
- **`.version` file** for beta/RC version tracking (single source of truth for CD workflows)

Branch promotion model:

- Feature/fix branches open PRs into `dev` (default integration branch)
- `dev` is validated continuously and produces dev build notifications/artifacts
- `beta` and `rc` branches produce prereleases from promoted `dev` changes
- `main` receives stable promotions from `beta`/`rc` after sync checks
- Dependabot targets `dev` for all configured ecosystems (actions, npm, pub)

See [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md), and [`.github/CI_CD_README.md`](.github/CI_CD_README.md) for contributor, agent, and CI/CD guardrails.

## Credits

- Project: Peters Digital
- Contributors: maintainers and community contributors (see Git history)

Full attributions: [CREDITS.md](CREDITS.md)

## Licensing

This project is dual-licensed under:

- GNU General Public License v3.0 (GPLv3)
- Commercial License (LicenseRef-Commercial)

All source files include the SPDX identifier:

```text
SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
```

### Open Source Use (GPLv3)

This software is available under the GPLv3. If you use, modify, or distribute
this software, you must comply with the terms of the GPLv3.

### Commercial Use

If you wish to use this software without complying with GPLv3 (for example,
in proprietary or closed-source applications), you must obtain a commercial
license.

Commercial licenses are granted on a case-by-case basis.

For licensing inquiries, contact: [dencelbabu@gmail.com](mailto:dencelbabu@gmail.com)

### License Header Enforcement

License headers are automatically checked by CI.

See [docs/LICENSING.md](docs/LICENSING.md) for details.

## License History

Prior to version 0.2.2, this project used a custom dual-license notice.

As of version 0.2.2, the project has been formally licensed under:

- GNU General Public License v3.0 (GPLv3)
- Commercial License (LicenseRef-Commercial)

This change clarifies and standardizes the licensing terms. Contributors retain full copyright to their contributions and are credited in Git history. By contributing, you grant Peters Digital a broad license to use your work under both the GPLv3 and Commercial License terms, enabling the project's dual-licensing model.
