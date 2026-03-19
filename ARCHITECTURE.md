# Architecture

## Vision
OpenMIDIControl is a control surface system with two user-facing lanes:

1. **Simple lane (no Bridge):** Android device acts as a straightforward MIDI CC controller (wired USB), plug-and-play.
2. **Advanced lane (Bridge):** PC Bridge enables higher-level workflows (Cubase-exclusive macros, multi-port routing, wireless, multi-device sessions) without breaking early user setups.

## Key requirements
- Multi-touch (simultaneous fader movement)
- Low latency, low jitter
- MIDI feedback (DAW MIDI OUT → UI updates)
- Avoid feedback loops (echo suppression / tagging)
- Battery/thermal aware update strategy

## Components (planned)
### Android App
- UI: faders/buttons/pages
- Touch engine:
  - pointer capture per control
  - smoothing and rate limiting
- MIDI engine:
  - send CC/notes
  - receive MIDI for UI feedback
  - loop prevention policies

### Bridge (Windows tray app) — later milestone
- Receives events from Android (USB and/or Wi‑Fi)
- Exposes virtual MIDI endpoint(s) to DAW
- Compatibility mode:
  - single port to preserve legacy mappings
- Advanced mode:
  - multi-port separation
  - Cubase-exclusive features and command catalogs

### Windows Touch Client — later milestone
- Native multi-touch UI for large touch displays
- Uses shared message model and mapping logic when possible

## Event model (conceptual)
- Normalized control value: `0.0..1.0`
- Mappings convert to:
  - MIDI CC 0..127
  - MIDI note on/off
  - (future) higher-level bridge command IDs

## Performance strategy
- UI rendering can run at device refresh rates (60/120 Hz).
- MIDI send rate should be capped:
  - send only while moving
  - coalesce rapid moves (last-value-wins)
  - optional deadband (e.g., 1 step) to reduce spam

## Feedback sync modes (planned)
- **Follow:** UI always follows incoming MIDI
- **Touch overrides:** while touching a control, local interaction takes priority
- **Pickup vs Jump:** configurable per control type
- Echo suppression: ignore immediate identical echoes and/or tag outgoing messages (Bridge lane)