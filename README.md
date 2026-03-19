# OpenMIDIControl

**OpenMIDIControl** is a Cubase-first, DAW-agnostic MIDI control surface project.

- **Simple users** get a **plug-and-play** Android MIDI CC controller (no Bridge).
- **Advanced users** can later opt into a **Bridge** workflow for higher-level features (Cubase-exclusive control, macros, multi-device, etc.) while preserving existing setups via **Compatibility mode**.

> Primary initial use case: record MIDI notes from a keyboard (e.g., Arturia MiniLab 3) while simultaneously riding **CC1 (Modulation)** and **CC11 (Expression)** on a multi-touch surface.

---

## Goals (high level)

### v0.1.0 (Android-only, no Bridge)
- Wired USB connection to a Windows 11 host
- **2 faders**: CC11 + CC1
- Multi-touch (move both faders simultaneously)
- Real-time value readout
- **Bidirectional MIDI (feedback):** if the DAW sends MIDI back (standard MIDI), the UI updates (“motor fader” style)
- Keep CPU/battery usage low via coalescing/rate limiting

### Post v0.1.0 (Bridge added before v1.0.0)
- Optional PC Bridge app for advanced workflows:
  - **Compatibility mode:** single virtual port to preserve early user mappings
  - **Advanced mode:** multi-port, Cubase-exclusive features (macros/commands/PLE/MIDI Remote integration)
- Wireless support (LAN + hotspot “road mode”)
- Windows native multi-touch client for large touch displays (later milestone)

---

## Roadmap / Timeline (v0.1.0 → v1.0.0)

> Versions follow **SemVer**. Dates are intentionally not promised (feature-driven milestones).

### v0.1.0 — “Wired basics”
- Android app:
  - Two faders (default: CC11 + CC1; optional in-app mapping if time permits)
  - Multi-touch
  - Real-time display
  - Wired USB MIDI, plug-and-play (no Bridge)
  - MIDI IN feedback to update UI (DAW-agnostic)

### v0.2.0 — “Config & stability”
- Presets (save/load CC/channel mappings)
- UI/transport performance tuning (rate limit, smoothing options, pickup/jump modes)
- Improved MIDI feedback loop prevention

### v0.3.0 — “More controls”
- Add buttons/switches (still MIDI-only)
- Basic transport mappings via MIDI where possible (DAW-agnostic)

### v0.4.0 — “Wireless beta”
- Wi‑Fi LAN:
  - UDP stream for faders (low latency, last-value-wins)
  - reliable channel for buttons
- Hotspot mode support (reduced update rate option)

### v0.5.0 — “Bridge introduction (Windows tray)”
- Optional Bridge app (advanced users):
  - Compatibility mode (single-port behavior)
  - Groundwork for Advanced mode (multi-port)
- Cubase-first “setup pack” (MIDI Remote mappings / Macros / PLE guidance)

### v0.6.0 — “Cubase-exclusive actions (Bridge lane)”
- Cubase command/macro triggering via mapped MIDI (user imports/setup pack)
- Device/session management groundwork for multiple controllers

### v0.7.0 — “Windows touch client (prototype)”
- Native Windows multi-touch controller client (for large touch displays)
- Uses same message model as Android app (where feasible)

### v0.8.0 — “Bridge Advanced mode”
- Multi-port option (e.g., separate faders vs commands)
- Pair-once discovery (mDNS) + lightweight pairing

### v0.9.0 — “Polish & templates”
- Cubase templates/profiles
- Multi-device “tetris” layout assignments (left/right/center roles)

### v1.0.0 — “Stable release”
- Stable wired + wireless
- Stable Bridge feature set (Cubase-first)
- Stable feedback sync behaviors
- Contributor-friendly docs and extension points

---

## Non-goals (for now)
- Direct Vienna Ensemble Pro control (no public API integration). VE Pro workflows are supported indirectly through Cubase routing.
- DAW-specific features for non-Cubase DAWs (beyond generic MIDI control).

---

## License
Dual-licensed:
- **GPL-3.0** (open source)
- **Commercial license** available separately (see `LICENSE`)

---

## Contributing
See `CONTRIBUTING.md`.