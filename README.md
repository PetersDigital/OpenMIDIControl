# OpenMIDIControl

> **A multi-touch MIDI CC control surface, DAW-agnostic open MIDI standards.**  
> Built for Android first, with an optional PC Bridge for advanced features later.

---

## About

OpenMIDIControl is a performance-focused MIDI controller app designed for composers/producers who want to record notes on a keyboard while riding expression controls on a touch surface—especially **CC11 (Expression)** and **CC1 (Modulation)**.

The project is **Cubase-first by default**, but the baseline feature set uses **open MIDI standards**, so it can work with **any DAW**.

Two modes are supported:

- **Simple mode (no Bridge):** plug-and-play wired MIDI CC control (Android).
- **Advanced mode (Bridge, later):** optional PC Bridge adds Cubase-exclusive macros/commands and advanced routing, while supporting a **Compatibility mode** so users can migrate without breaking existing mappings.

---

## Feature Roadmap

| Version | Milestone |
|---------|-----------|
| **v0.1.0** | Android wired plug-and-play — 2 faders (CC11 + CC1), multi-touch, real-time readout, **MIDI feedback (MIDI IN → UI)** |
| v0.2.0 | Config & stability — mappings/presets, pickup/jump modes, smoothing controls, improved feedback-loop prevention |
| v0.3.0 | More controls (MIDI-only) — buttons/switches, basic transport via MIDI where possible |
| v0.4.0 | Wireless beta — LAN (UDP faders + reliable buttons), hotspot “on the road mode” + reduced update rate |
| v0.5.0 | Bridge introduction (Windows tray) — Compatibility mode (single port) + groundwork for Advanced mode |
| v0.6.0 | Cubase-exclusive actions (Bridge mode) — Cubase setup pack (MIDI Remote + Macros + PLE guidance) |
| v0.7.0 | Windows touch client prototype — native multi-touch client for large touch displays |
| v0.8.0 | Bridge Advanced mode — multi-port option, pair-once discovery |
| v0.9.0 | Polish & templates — Cubase templates/profiles, multi-device layout roles |
| **v1.0.0** | Stable release — stable wired + wireless + Bridge, stable feedback sync behavior, contributor-ready extension points |

> Versions follow **SemVer**. Dates are intentionally not promised (feature-driven milestones).

---

## Tech Stack (planned / evolving)

| Layer | Technology |
|------|------------|
| Android App UI | Flutter |
| Android MIDI I/O | Native Android (Kotlin) as needed + Flutter integration |
| PC Bridge (later) | Windows-first tray app (language/tooling TBD) |
| Windows Touch Client (later) | Native Windows multi-touch client (not web) |
| Protocols (later) | Wired USB, LAN Wi‑Fi (UDP for faders), reliable channel for buttons |

---

## Getting Started

### Prerequisites
- Android device (targeting modern Android; primary test device: Android 16 class)
- A Windows 11 PC running a DAW (Cubase 15/FL Studio 25 or any DAW)
- A wired USB connection (PC USB-A/C → Android USB‑C)

### Setup (once code exists)
```bash
# Clone the repository
git clone https://github.com/PetersDigital/OpenMIDIControl.git
cd OpenMIDIControl

# Install dependencies (when Flutter project exists)
flutter pub get

# Run on your connected device
flutter run
```

---

## Building (once code exists)

```bash
# Android APK (debug)
flutter build apk --debug
```

---

## Release process

Releases are triggered by pushing **signed SemVer tags**:

```bash
git tag -s v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Notes:
- Version numbers must **not** appear in commit subjects (Conventional Commits rule).
- Version bumps are done via tags + changelog entries.

---

## Clean Build

```bash
flutter clean
flutter pub get
```

If build_runner outputs are added later:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Running Tests / Linting (once code exists)

```bash
flutter test
flutter analyze --fatal-infos
```

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed description of the project structure, state management approach, navigation, and coding conventions.

For AI coding agent instructions (setup, testing, PR, and guardrails), see [AGENTS.md](AGENTS.md).

---

## Credits

- **LLM Prompter? Vibe-Coder? Integrator?:** [Dencel K Babu](https://github.com/dencelkbabu)
- **Organization:** [PetersDigital](https://github.com/PetersDigital)

For full tool, AI, and audio attributions, see [CREDITS.md](CREDITS.md).

---

## License

Dual-licensed:
- Open source: **GPL-3.0** (see [LICENSE](LICENSE))
- Commercial license: available separately from PetersDigital