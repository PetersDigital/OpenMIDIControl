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
- Wired USB-MIDI only in v0.1.0–v0.3.0 (via Custom SysEx/Standard CC). Future versions (v0.4.0+) may implement WebSockets/OSC strictly for heavy Macro integrations over Wi-Fi, keeping fader data hardwired.

## 3. System Model

Initial target is wired MIDI with three logical layers (see diagram below):

1. Touch/UI layer
2. MIDI service layer
3. Transport/port adapter layer

Each layer can reject duplicate or unsafe events independently.

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

## 10. Version Roadmap

### v0.1.0: Core control path

- Two expressive faders
- Multi-touch pointer capture
- Bidirectional CC feedback
- Dedup and thermal guardrails

### v0.2.0: Configurable behavior

- Mapping/preset storage
- Pickup/jump modes
- Adjustable smoothing/rate limits

### v0.3.0: Expanded messaging

- Optional NRPN/state messages
- Optional metadata SysEx channel
- Integration adapters kept isolated from core touch/MIDI path

### v1.0.0: Host integrations (Cubase first)

- Host adapters live outside the core touch/MIDI path.
- Mapping schema per control: {cc/chan, mode (pickup/jump), resolution (7/14-bit), feedback policy}.
- Reference controller scripts and mappings live under references/cubase/*.

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