# Architecture

## 1. Vision

OpenMIDIControl is a MIDI control surface ecosystem with two modess:

1) **Simple mode (no Bridge):** Android device provides plug-and-play MIDI CC control over wired USB.
2) **Advanced mode (Bridge):** optional PC Bridge adds Cubase-exclusive workflows (macros/commands, templates, routing) and optional wireless, without breaking simple-user setups.

**Cubase-first policy**
- Baseline: standard MIDI works with any DAW.
- Advanced: Cubase-exclusive capabilities are delivered via Bridge mode and optional Cubase setup packs.

**VE Pro**
- Supported indirectly through Cubase routing.
- No direct VE Pro API integration.

---

## 2. Requirements (non-negotiable)

- **Multi-touch**: user must be able to ride multiple faders simultaneously while playing a MIDI keyboard.
- **Low latency / low jitter**: “feels immediate” for performance control.
- **Bidirectional MIDI**: incoming MIDI can update UI (“motor fader” behavior) using standard MIDI (DAW-agnostic).
- **Feedback loop prevention**: avoid echo/oscillation when DAW echoes messages back.
- **Battery/thermal awareness**: rate limiting and coalescing must prevent excessive CPU usage.
- **Future Windows touch**: plan for a native Windows multi-touch client for large touch displays.

---

## 3. Components

### 3.1 Android app (v0.1.0)
- Touch engine:
  - pointer capture per control
  - optional smoothing
  - rate limit + coalescing (last value wins)
- MIDI engine:
  - send CC
  - receive CC for UI feedback
  - echo suppression policy

### 3.2 PC Bridge (post v0.1.0, pre v1.0.0)
- **Compatibility mode** (migration-friendly):
  - single virtual MIDI port behavior to preserve existing setups
- **Advanced mode** (opt-in):
  - multi-port separation (e.g., faders vs commands)
  - Cubase command/macro workflows
  - pairing + discovery

### 3.3 Windows touch client (later)
- Native multi-touch client (not web)
- Targets large touch displays (e.g., 21–32" multi-touch)
- Designed for low latency and clean pointer routing

---

## 4. Event model

- Internal values normalized to `0.0..1.0`
- Mapping to MIDI:
  - CC: 0..127
  - Buttons: Note On/Off or CC toggles (later)
- Feedback model:
  - UI follows external MIDI when not touching
  - Touch overrides while active
  - pickup/jump per control (configurable later)

---

# 5. Viability & Implementation Plan (Final)

## 5.1 Viability summary

### Feasible with high confidence
- Multi-touch faders on Android with responsive UI.
- MIDI CC output for CC1/CC11.
- DAW-agnostic MIDI feedback display using incoming MIDI.

### Main risk
**Android wired USB “pure plug-and-play MIDI peripheral” behavior can be device/ROM dependent.**

Mitigation strategy:
- v0.1.0 targets the best practical implementation for modern Android.
- If necessary, Bridge mode becomes the “works everywhere” fallback for wired and wireless later (without forcing Bridge on simple users).

---

## 5.2 v0.1.0 scope (Android-only, no Bridge)

### Goals
A minimal, reliable performance controller:
- Two faders (default CC11 + CC1)
- Multi-touch
- Real-time value readout
- Wired, plug-and-play MIDI
- MIDI IN feedback updates UI (“motor fader” visuals)

### Behavior requirements
- Send updates while moving at a capped rate (avoid heating).
- On release, send final value.
- MIDI feedback:
  - update UI on incoming CC
  - avoid obvious feedback loops (initial heuristics)

### Non-goals
- Wireless
- Bridge
- Cubase macros/PLE packs
- Windows touch client

### Acceptance criteria
- User can record keyboard notes and ride both faders simultaneously.
- Cubase (and other DAWs) can learn CC1/CC11.
- UI stays stable and responsive over long sessions.

---

## 5.3 v0.2.0–v0.4.0 (MIDI-only expansion + wireless groundwork)
- User mappings/presets
- pickup/jump configuration and smoothing controls
- Buttons/switches (MIDI-only)
- Wireless beta:
  - LAN: UDP for faders (loss-tolerant last-value-wins)
  - reliable channel for buttons
  - hotspot road mode + reduced update rate

---

## 5.4 v0.5.0–v0.9.0 (Bridge mode + Cubase-first scaling)
- Bridge tray app:
  - Compatibility mode (single port)
  - Advanced mode (multi-port opt-in)
  - pair-once discovery
- Cubase setup packs:
  - MIDI Remote mappings
  - Macro + PLE guidance
- Multi-device groundwork (“tetris” layouts and roles)

---

## 5.5 v1.0.0 milestone
- Stable wired + wireless
- Stable Bridge compatibility + advanced modes
- Stable feedback sync model (touch override + follow external)
- Stable Windows touch client
- Clear extension points for contributors

---

## 6. References in-repo
- Roadmap: `README.md`
- Contributions: `CONTRIBUTING.md`
- Agent guardrails: `AGENTS.md`
- Versions: `CHANGELOG.md`