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

## 3.1 Future Evolution (The Master Plan)

The post-v0.2.0 trajectory prioritizes architectural purity and deterministic routing before further UI expansion:

- **Canonical Data Model (v0.2.1):** Established a unified **32-bit UMP-ready** payload as the internal source of truth. Formalized the separation between `MidiEvent` (transport) and `ControlState` (UI-facing logic), enforced through strict Map immutability and centralized stream parsing.
- **API 33+ Baseline (Post-v0.2.1):** Enforced `minSdkVersion = 33` (SHA `97e002e`) to provide a native foundation for MIDI 2.0 and Universal MIDI Packets (UMP).
- **Hybrid UMP Implementation (v0.2.2):** Implemented manual 32-bit UMP reconstruction from `byte[]` streams due to Android's incomplete `MidiUmpDeviceService` API. Virtual UMP requires Android 15+ (API 35) and is feature-flagged with `FLAG_VIRTUAL_UMP`, providing only ~20% device coverage. The hybrid approach retains `MidiDeviceService` with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag for 90% coverage (Android 13-15).
- **MidiRouter Graph (v0.2.3):** Implementing a software Directed Acyclic Graph (DAG) for N-to-N message distribution and logic-based remapping.
- **Protocol & Scripting (v0.4.x - v0.5.0):** Native MCU/HUI support followed by official DAW remote scripts (Ableton/Cubase/Logic).
- **NDK Fast Path (v0.5.0 Conditional):** High-performance C++ migration will only occur if benchmarks identify Kotlin/JVM as the absolute latency bottleneck.

Connection lifecycle (text diagram):
```
INIT -> READY_PROBE -> ACTIVE_STREAM -> RECOVERY (on disconnect) -> INIT
```

## 3.2 Hybrid UMP Implementation

OpenMIDIControl implements a **hybrid UMP architecture** due to Android's incomplete `MidiUmpDeviceService` implementation:

**Why Hybrid?**
- `MidiUmpDeviceService` virtual UMP requires Android 15+ (API 35)
- Feature-flagged with `FLAG_VIRTUAL_UMP` (unreliable across OEMs)
- Restrictive port constraints (input=output, non-zero)
- Only ~20% device coverage vs. 90% for hybrid approach

**Implementation:**
1. Legacy `MidiDeviceService` inheritance (API 29+)
2. UMP transport flag: `TRANSPORT_UNIVERSAL_MIDI_PACKETS`
3. Manual 32-bit reconstruction in `MidiParser.kt`
4. Future conditional upgrade path (Android 15+ adoption >80%)

**Data Flow:**
1. **OS Delivery:** Android delivers MIDI data as `ByteArray` (legacy byte-stream format)
2. **UMP Detection:** `MidiParser.processMidiPayload()` checks alignment (`count % 4 == 0`) and validates Message Type bits
3. **Reconstruction:** 4-byte chunks → 32-bit integers via big-endian bitwise shifts: `(b1 << 24) | (b2 << 16) | (b3 << 8) | b4`
4. **Validation:** Bounds checking (`offset >= 0`, `count % 4 == 0`, `offset + count <= msg.size`)
5. **Filtering:** Real-time spam (0xF8 Timing Clock, 0xFE Active Sensing) discarded
6. **Dispatch:** Reconstructed UMP integers queued to Kotlin `Channel<Pair<Long, Long>>` for batched EventChannel dispatch

**Trade-offs:**
- ✅ 90% device coverage (Android 13-15)
- ✅ Full implementation control
- ✅ No feature flag dependencies
- ⚠️ Manual UMP maintenance burden
- ⚠️ ~0.5ms reconstruction latency (negligible vs. USB transport)
- ⚠️ Technical debt: future migration when Android 15+ reaches 80% (est. 2027-2028)

## 4. Event Semantics

- Internal values are normalized to `0.0..1.0`.
- Outgoing CC values are encoded to `0..127` natively, with 32-bit UMP values used where high-resolution is supported.
- Local touch owns control state while active.
- External MIDI owns control state when touch is inactive.
- On touch release, control returns to external-follow mode immediately.

## 4.1 MIDI 2.0 & UMP Core Architecture

To future-proof the system, OpenMIDIControl adopts a **UMP Core Architecture** with hybrid implementation:

- **Source of Truth:** Internally, all MIDI data is treated as a **Universal MIDI Packet (UMP)** using 32-bit integer blocks rather than traditional 8-bit byte streams.
- **Native Android Layer:** Enforces UMP mode at the query/open level using the `TRANSPORT_UNIVERSAL_MIDI_PACKETS` transport flag. Due to Android's incomplete `MidiUmpDeviceService` API (requires Android 15+, feature-flagged), the app retains `MidiDeviceService` with manual 32-bit reconstruction in `MidiParser.kt`.
- **MidiRouter Graph:** The routing engine only handles UMP payloads, ensuring it can process high-resolution (32-bit) data natively without architectural changes.
- **Output Negotiation:** The app uses MIDI-CI (Capability Inquiry) to negotiate with the DAW. If MIDI 2.0 is supported, UMP is sent directly; otherwise, the packet is down-translated to legacy MIDI 1.0 bytes.
- **Future Migration Path:** When Android 15+ adoption exceeds 80% (est. 2027-2028), migrate to `MidiUmpDeviceService` for native UMP handling.

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
- Basic SysEx framing for project-specific metadata only

### 6.2 SysEx policy

- Keep message schema explicit and versioned.
- Prefer human-readable payload encoding for diagnostics.
- Treat unknown command bytes as non-fatal.

### 6.4 MIDI Device Persistence
In v0.1.5, the app maintains a "Last Known Good" metadata fingerprint. This allows the system to remain robust against Android's dynamic hardware indexing.
- **Reconnection Loop:** `ConnectionLost` -> `DeviceAdded` -> `Metadata Match` -> `Auto-Handshake`.

### 6.5 Global Behavior Engine
The fader behavior logic (Jump/Hybrid/Catch-up) is centralized. It intercepts both local touch deltas and external MIDI CC updates, ensuring that the console logic is consistent regardless of the data source.

## 7. Connection Lifecycle

1. Initialize ports and start listeners.
2. Send optional handshake/ready probe.
3. Enter active stream mode after readiness is confirmed or timeout policy passes.
4. On disconnect, transition to recovery state and retry with backoff.

State machine must be explicit and testable.

## 8. Performance Guardrails

- **Hybrid UMP Reconstruction (v0.2.2):** Manual 32-bit UMP reconstruction in `MidiParser.kt` with ~0.1-0.5ms overhead (negligible vs. USB transport latency). Big-endian bitwise reconstruction: `(b1 << 24) | (b2 << 16) | (b3 << 8) | b4`.
- **Primitive EventChannel Batching (v0.2.2):** Optimized JNI bridge using `LongArray` instead of `List<MidiEvent>` to reduce GC pressure and allocation churn.
- **Kotlin Coroutine Polling:** High-frequency MIDI events are buffered in a Kotlin `Channel` and batched every 8ms (approx. 120Hz) before dispatching to Flutter.
- **Dual-Path Routing:** Outbound MIDI CC data in Peripheral mode is written directly to physical hardware transport (`MidiInputPort`) via native Kotlin, bypassing the Flutter event loop for minimal latency.
- **Port Collision Hiding:** Physical port 0 is hidden from the Flutter device query to prevent Binder "port already open" crashes, granting exclusive routing access to the native layer.
- **Coalesce rapid touch events:** last-value-wins semantics.
- **Cap outbound send frequency:** per control to avoid thermal spikes.
- **Always send final control value:** on touch release.
- **Keep parsing and dedup operations:** O(1) using `ConcurrentHashMap` caches for thread safety.
- **Strict Coroutine Suspension:** The background MIDI dispatcher strictly suspends on the `incomingEventsChannel` to ensure the thread yields CPU time back to the OS when no data is moving, achieving ~0% idle overhead.
- **Real-Time Message Filtering:** Timing Clock (`0xF8`) and Active Sensing (`0xFE`) messages are discarded at the native entry point (MidiReceiver) to protect the Flutter bridge from high-frequency saturation.
- **Reactive UI Throttling:** UI components (like faders) use Riverpod's `.select()` modifier to filter global state updates, ensuring that only the relevant control rebuilds during multi-channel MIDI traffic.
- **Riverpod Batch Update:** State transitions are batched precisely once per native polling cycle to minimize map churn and UI thread occupancy.
- **Animation Churn Bypass:** External MIDI updates use direct `AnimationController.value` assignment to bypass expensive animation interpolation and cancellation math, relying on the source DAW for temporal smoothing.
- **Centralized Event Parsing:** The `MidiService` handles `EventChannel` decoding exactly once per native polling cycle, distributing a typed `List<MidiEvent>` to all observers to ensure atomic state transitions and 0% redundant parsing.
- **High-Precision Diagnostics:** The diagnostics console uses native platform timestamps (nanoseconds) provided by the Android MIDI stack, ensuring the event log order is independent of Dart VM scheduling jitter.
- **Performance Evaluation (Planned v0.5.0):** Strict benchmarking of the Kotlin Coroutine pipeline against native DAW integrations.
- **C++ Audio Layer (Conditional v0.5.0+):** If Kotlin limits are hit, migrate the hot data path to Android's native `AMidi` C API and Dart FFI shared memory. The internal data model is already **32-bit UMP-aligned** (v0.2.1) to support this transition.

## 9. Error Handling & Stability

- **Native Layer Hardened**: Centralized all unsafe Android MIDI operations (connect, disconnect, send) into a global `safeExecute` wrapper in `Utils.kt`. This ensures that `IOException` or `IllegalStateException` during rapid hot-plugging are logged via the diagnostics system rather than crashing the application.
- **Dead Receiver Quarantine:** Catch `IOException` on hardware writes and isolate disconnected receivers in a quarantine set to prevent infinite Binder crash loops during rapid hotplugging.
- **Invalid MIDI frames:** ignore and continue.
- **Unknown SysEx commands:** log and ignore.
- **Port loss:** preserve UI state, signal disconnected mode, retry connection.

## 10. Version Roadmap (v0.1.0 to v1.0.0)

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
* **MidiPortBackend**: Unified abstraction for OS-native vs. raw USB driver fallback.
* **Universal Payload**: Introduction of the internal **32-bit UMP-ready** MIDI format as the system source of truth.
* **Event vs. State Separation**: Decoupling raw transport data (`MidiEvent`) from UI-facing Riverpod logic (`ControlState`) with strict immutability.
* **Service Centralization**: Simplified event processing into a single-pass `MidiService` stream.
* **Diagnostic Tools**: Real-time MIDI event logger with native high-precision timestamps.

#### ✅ API 33+ Baseline (Post-v0.2.1)
- **SDK Exclusivity**: Enforced `minSdkVersion = 33` to provide native support for MIDI 2.0 and UMP structures.

#### ✅ v0.2.2 – Hybrid UMP Implementation
- **Hybrid Architecture Decision**: Retained `MidiDeviceService` over `MidiUmpDeviceService` due to Android's incomplete UMP implementation (requires Android 15+, feature-flagged, ~20% coverage)
- **Manual 32-bit UMP Reconstruction**: `MidiParser.kt` implements 4-byte chunk reconstruction with big-endian bitwise shifts and strict bounds checking
- **UMP Transport Flag**: All ports opened with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` for MIDI 2.0 compatibility
- **Primitive EventChannel Batching**: Optimized JNI bridge using `LongArray` instead of `List<MidiEvent>` to reduce GC pressure
- **Automated Test Suite**: UMP transport tests with known payloads, validation of bitwise extraction logic
- **Defensive Bounds Checking**: Prevents DoS via malformed MIDI packets in native layer
- **Package Standardization**: Migrated to lowercase `com.petersdigital.openmidicontrol` namespace

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