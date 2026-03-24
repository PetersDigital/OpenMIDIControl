# Architecture

This document defines the current architecture for OpenMIDIControl.

## 1. Purpose

OpenMIDIControl is a touch-first MIDI control surface with strict goals:

- low-latency expressive control
- reliable bidirectional feedback
- deterministic behavior under rapid input
- clear layering so future integrations are optional and isolated

## 2. Core Constraints

- Multi-touch must support simultaneous controls without pointer conflicts.
- MIDI output must remain responsive under high event rates.
- Incoming MIDI must update UI when local touch is inactive.
- Feedback loops must be prevented with value-based deduplication.
- Battery and thermal load must remain stable during long sessions.

## 2.1 Platform & Runtime

- Android 10+ (API 29+) (expanding to iOS/iPadOS/Windows touch displays).
- Flutter UI (Dart) relying on `LayoutBuilder` for responsive adaptation.
- "Absolute/Relative" hybrid touch faders to capture interactions without jarring volume changes.
- Internal state management strictly emitting "Intent" events to remain transport-agnostic.
- **Transport Role Pivot:** v0.2.0 shifts the app from a simple "MIDI Host" (controlling hardware) to a **"USB MIDI Peripheral"** (acting as a standard MIDI device for PCs). This pivot requires a native `MidiDeviceService` implementation to ensure driverless Windows 11 compatibility.
- Phone UI is portrait-first for expressive fader controls; tablet landscape remains the preferred mode for grid-style pads and extended control surfaces.

## 3. System Model

Initial target is wired MIDI with three logical layers:

1. Touch/UI layer
2. MIDI service layer
3. Transport/port adapter layer (Host vs. Peripheral roles)

Each layer can reject duplicate or unsafe events independently. In v0.2.0+, the Transport layer is optimized for **USB Class Compliance**, ensuring that the phone appears as a high-precision controller to the desktop OS.

Connection lifecycle (text diagram):
```
INIT -> READY_PROBE -> ACTIVE_STREAM -> RECOVERY (on disconnect) -> INIT
```

## 4. Event Semantics

- Internal values are normalized to `0.0..1.0`.
- Outgoing CC values are encoded to `0..127` or 14-bit pairs where needed.
- Local touch owns control state while active.
- External MIDI owns control state when touch is inactive.
- On touch release, control returns to external-follow mode immediately.

## 5. Feedback Loop Prevention

Use value-first suppression, not timing-only suppression.

Required strategy:

1. Cache the last transmitted value per logical control.
2. Cache the last received value per logical control.
3. If incoming value equals recently sent value in a short window, suppress UI mutation.
4. If outgoing value equals recently applied external value in a short window, suppress retransmit.

Recommended defaults:
- Dedup suppression window: 50–100 ms
- Per-control outbound rate cap: 120 Hz max; typical 60 Hz; always send final value on release

## 6. MIDI Protocol Baseline

### 6.1 Required support

- Channel CC (7-bit)
- Optional 14-bit CC (MSB/LSB pairs)
- Basic SysEx framing for project-specific metadata only

### 6.2 14-bit policy

- Use 14-bit for high-resolution expressive controls.
- Always reconstruct full value before dedup checks.
- Never deduplicate on MSB alone.

### 6.3 SysEx policy

- Keep message schema explicit and versioned.
- Prefer human-readable payload encoding for diagnostics.
- Treat unknown command bytes as non-fatal.

### 6.4 MIDI Device Persistence
In v0.1.5, the app maintains a "Last Known Good" metadata fingerprint. This allows the system to remain robust against Android's dynamic hardware indexing.
- **Reconnection Loop:** `ConnectionLost` -> `DeviceAdded` -> `Metadata Match` -> `Auto-Handshake`.

### 6.5 Global Behavior Engine
The fader behavior logic (Jump/Hybrid/Catch-up) is centralized. It intercepts both local touch deltas and external MIDI CC updates, ensuring that the "Ethereal Console" logic is consistent regardless of the data source.

## 7. Connection Lifecycle

1. Initialize ports and start listeners.
2. Send optional handshake/ready probe.
3. Enter active stream mode after readiness is confirmed or timeout policy passes.
4. On disconnect, transition to recovery state and retry with backoff.

State machine must be explicit and testable.

## 8. Performance Guardrails

- Coalesce rapid touch events using last-value-wins semantics.
- Cap outbound send frequency per control to avoid thermal spikes.
- Always send final control value on touch release.
- Keep parsing and dedup operations O(1) using map-based caches.

## 9. Error Handling

- Invalid MIDI frames: ignore and continue.
- Partial 14-bit pairs: buffer briefly, then drop safely on timeout.
- Unknown SysEx commands: log and ignore.
- Port loss: preserve UI state, signal disconnected mode, retry connection.

## 10. Version Roadmap (v0.1.0 to v1.0.0)

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

### ⏳ v0.2.0: Advanced USB MIDI & Logic (Current Focus)
* **Peripheral Mode**: Pivoting the app to act as a USB Peripheral for Windows 11 and DAW recognition.
* **USB Class Compliance**: Validation of standardized MIDI communication without custom drivers.
* **Logic Refinement**: Finalizing "Catch-up" and "Hybrid" fader physics for professional mixing workflows.

### ⏳ v0.3.0: Control Expansion
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

## 11. Verification Checklist

- Two simultaneous touches produce independent MIDI streams.
- No oscillation when host echoes MIDI values.
- UI remains stable during rapid automation feedback.
- CPU/thermal behavior remains acceptable in long sessions.
- Disconnect/reconnect recovers without restart.

## 12. Host Integration Boundary (Cubase)

- Core app remains DAW-agnostic; Cubase adapters are optional modules.
- Host adapter responsibilities:
  - Translate app control events to host-specific scripts/mappings.
  - Provide feedback normalization back to core in normalized `0.0..1.0`.
- Host adapter must not modify core dedup or coalescing rules.

## 13. References

- [README.md](README.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [USERGUIDE.md](USERGUIDE.md)
- [CHANGELOG.md](CHANGELOG.md)