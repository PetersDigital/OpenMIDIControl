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
- **API 33+ Baseline (Post-v0.2.1):** Enforced `minSdkVersion = 33` to provide a native foundation for MIDI 2.0 and Universal MIDI Packets (UMP).
- **Native UMP Backend Migration (v0.2.2):** Implementing the core UMP transport layer. The native code inherits from `MidiDeviceService` (API 33+) with UMP transport enforced via the `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag. It uses legacy `MidiDevice` and `MidiPort` classes for client connections to satisfy Android SDK visibility constraints, with manual 32-bit packet reconstruction from `byte[]` buffers.
- **MidiRouter Graph (v0.2.3):** Implementing a software Directed Acyclic Graph (DAG) for N-to-N message distribution and logic-based remapping.
- **Performance & Thermal Hardening (v0.2.3):** Eliminating object allocation churn in the MIDI hot-path through primitive packing, buffer reuse, and coalesced state updates.
- **Native Loop Prevention (v0.2.3):** Implemented explicit `UsbMode` tracking in the native layer to disable `VirtualMidiService` dispatch when in Peripheral mode, eliminating internal feedback loops.
- **Service Decoupling (v0.2.3):** Refactored native logic into a persistent `MidiSystemManager` singleton to decouple MIDI lifecycle from `MainActivity`. This ensures that `PeripheralMidiService` remains active during background transitions and focus changes.
- **Unique Status Identity (v0.2.3):** Refactored the connection status system to use distinct labels (READY, DETECTED, ACTIVE) and unique color tokens for all 7 MIDI states, improving user feedback clarity.
- **Thermal Priority Flags (v0.2.3):** Integrated `appCategory="game"` and `isGame="true"` flags in `AndroidManifest.xml` to grant the application higher priority in the Android OS scheduler and thermal management system.
- **Protocol & Scripting (v0.4.x - v0.5.0):** Native MCU/HUI support followed by official DAW remote scripts (Ableton/Cubase/Logic).
- **NDK Fast Path (v0.5.0 Conditional):** High-performance C++ migration will only occur if benchmarks identify Kotlin/JVM as the absolute latency bottleneck.

Connection lifecycle (text diagram):
```
INIT -> READY_PROBE -> ACTIVE_STREAM -> RECOVERY (on disconnect) -> INIT
```

## 3.2 Native Android Layer / JNI Bridge

The Native Kotlin layer guarantees UMP traffic by opening ports with the `MidiManager.TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag. Although it interacts with legacy `MidiDevice` and `MidiPort` classes (due to SDK limitations), it enforces a **Manual 32-bit Reconstruction** strategy:

1.  **OS Delivery:** The Android OS delivers UMP packets as 4-byte blocks within a standard `ByteArray`.
2.  **Reconstruction:** Inside `onSend()`, the Kotlin layer iterates through the buffer in 4-byte chunks, reconstructing 32-bit integers via bitwise shifts (Big-Endian).
3.  **Validation:** Strict defensive bounds checking ensuring `count % 4 == 0` and payload alignment.
4.  **Dispatch:** Reconstructed 32-bit integers are passed directly across the `EventChannel`, mapping to the Dart `MidiEvent` model.

### 3.2.1 MidiParser Extraction (v0.2.2+)

To enable comprehensive unit testing without requiring Android Service lifecycle mocks, the UMP reconstruction logic was extracted from `MainActivity.kt` into a dedicated, testable static object `MidiParser.kt`.

**Architecture:**
```
MidiReceiver.onSend() 
  → MidiParser.processMidiPayload()
    → UMP heuristic detection (MT=0x1 or MT=0x2)
    → 32-bit bitwise reconstruction (Big-Endian)
    → Real-time spam filtering (0xF8, 0xFE)
    → Echo suppression (virtual DAW loopback prevention)
    → Channel<Pair<Long, Long>> queue
  → EventChannel dispatch to Dart layer
```

**Benefits:**
- **Testability:** `MidiParser` is a pure Kotlin object with no Android dependencies, enabling fast unit tests via JUnit + Coroutines Test
- **Isolation:** MIDI parsing logic is decoupled from `MidiDeviceService` lifecycle complexity
- **Coverage:** All UMP reconstruction paths, edge cases, and boundary conditions are automatically validated (see `MidiParserTest.kt`)
- **Maintainability:** Single responsibility principle - parsing logic is isolated from JNI bridge code

**Key Functions:**
```kotlin
object MidiParser {
    fun processMidiPayload(
        msg: ByteArray,
        offset: Int,
        count: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsChannel: Channel<Pair<Long, Long>>,
        suppressionWindowNs: Long,
        lastSentTime: Map<Int, Long>,
        isDebug: Boolean = false
    )
}
```

The function handles both UMP (32-bit) and legacy (8-bit) MIDI streams, with automatic heuristic detection and graceful fallback.

## 4. Event Semantics

- Internal values are normalized to `0.0..1.0`.
- Outgoing CC values are encoded to `0..127` natively, with 32-bit UMP values used where high-resolution is supported.
- Local touch owns control state while active.
- External MIDI owns control state when touch is inactive.
- On touch release, control returns to external-follow mode immediately.

## 4.1 MIDI 2.0 & UMP Core Architecture

To future-proof the system, OpenMIDIControl adopts a **UMP Core Architecture**:
- **Source of Truth:** Internally, all MIDI data is treated as a **Universal MIDI Packet (UMP)** using 32-bit integer blocks rather than traditional 8-bit byte streams.
- **Native Android Layer:** Enforces UMP mode at the query/open level using the `TRANSPORT_UNIVERSAL_MIDI_PACKETS` transport flag. Virtual routing extends `MidiDeviceService`, while client connections utilize legacy port classes with manual packet reconstruction to maintain SDK compliance.
- **MidiRouter Graph:** The routing engine only handles UMP payloads, ensuring it can process high-resolution (32-bit) data natively without architectural changes.
- **Output Negotiation:** The app uses MIDI-CI (Capability Inquiry) to negotiate with the DAW. If MIDI 2.0 is supported, UMP is sent directly; otherwise, the packet is down-translated to legacy MIDI 1.0 bytes.

## 4.2 MidiRouter Graph (v0.2.3)

The MidiRouter is a centralized **Directed Acyclic Graph (DAG)** for deterministic N-to-N message routing and transformation:

**Core Components:**
- **Nodes:** `TransformerNode` implementations that process batches of `MidiEvent` payloads. Each node applies a specific transformation (filtering, remapping, splitting streams).
- **Edges:** Directed connections between nodes, validated to prevent cycles (enforced at add-time in `addEdge` via `_canReach()`/`_dfsReach()`).
- **Queue-Based Traversal:** Uses a pre-allocated work queue to avoid deep recursion and maintain consistent processing order.
- **Object Pooling:** Work items are recycled from a pool to reduce garbage collection pressure during high-frequency routing cycles.

**Processing Model:**
```
process(sourceNodeId, eventBatch)
  → Queue.add(WorkItem(sourceNodeId, eventBatch))
  → while Queue.isNotEmpty:
      → node.process(batch) → processedBatch
      → for each child in edges[node]:
           Queue.add(WorkItem(child, processedBatch))
```

**Key Features:**
- **Cycle Detection:** `_canReach()` / `_dfsReach()` uses depth-first search to check reachability at add-time, preventing infinite routing loops.
- **Batch Processing:** All nodes operate on `List<MidiEvent>` to amortize routing overhead across multiple events.
- **Error Isolation:** Exceptions during processing clear the queue to prevent stale work items from lingering.
- **Deterministic Order:** Queue-based dispatch ensures reproducible routing order regardless of node count.

**TransformerNode Interface:**
```dart
abstract class TransformerNode {
  List<MidiEvent> process(List<MidiEvent> events);
}
```

Implementers can:
- **Filter:** Remove events matching criteria (e.g., velocity < 64).
- **Remap:** Transform CC values, channels, or message types.
- **Split:** Send different events to different child nodes via multiple routing paths.
- **Drop:** Return empty list to suppress downstream processing.

**Example Use Cases (Future):**
- Channel mapper: Remaps all CC messages to a target MIDI channel.
- Velocity transformer: Applies dynamics curves or scaling.
- Protocol adapter: Converts MIDI 1.0 to MIDI 2.0 format (or vice versa).
- Device router: Routes specific CCs to hardware USB ports vs. virtual DAW ports.

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
- **Centralized Event Parsing:** The `MidiService` handles `EventChannel` decoding exactly once per native polling cycle, distributing a typed `List<MidiEvent>` (unpacked from packed primitives) to all observers to ensure atomic state transitions and 0% redundant parsing.
- **Primitive Packing & Buffer Reuse**: Native-to-Dart transport packs 32-bit UMP and 32-bit millisecond timestamps into single `Long` primitives and reuses pre-allocated `ByteArray` buffers to eliminate object allocation churn (2MB/sec reduction). Millisecond precision is used to extend the 32-bit timestamp wrap-around to ~49 days.
- **Lazy-Init & Snapshotting:** `UiStateSinkNode` and `CcNotifier` use lazy-init `Map` allocation and reusable snapshots for batch updates, minimizing garbage collection during automation bursts.
- **High-Precision Diagnostics:** The diagnostics console uses native platform timestamps (nanoseconds) provided by the Android MIDI stack, ensuring the event log order is independent of Dart VM scheduling jitter.
- **Monotonic Clock Throttling:** `HybridTouchFader` uses `Stopwatch.elapsedMilliseconds` (not `DateTime.now()`) for MIDI rate limiting. `DateTime.now()` is non-monotonic and can jump on NTP sync, breaking throttle logic. `Stopwatch` provides reliable monotonic clock for ~120Hz MIDI rate limiting.
- **Lifecycle Flow Collection:** Native MIDI events are collected into a `StateFlow` within the persistent `MidiSystemManager`, allowing the transport to survive `Activity` destruction during rotation or low-memory pressure.
- **Thermal Priority Scheduling:** By flagging the app as a `game` category, we minimize OS-level background task interference and prevent the Android thermal manager from aggressively down-clocking the CPU during high-frequency MIDI bursts.
- **Lazy-Init Map Allocation:** `CcNotifier.updateMultipleCCs()` uses single-pass iteration with lazy `Map` initialization — only allocates new state when actual changes are detected, avoiding double-pass and full-map copy overhead during MIDI bursts.
- **Diagnostics Disposal Guard:** `DiagnosticsLoggerNotifier` uses `_disposed` flag to prevent state-write errors when `scheduleFrameCallback` fires after auto-dispose. Also resets `_pendingUpdate` in `onDispose` to prevent stale state on re-mount.
- **Performance Evaluation (Planned v0.5.0):** Strict benchmarking of the Kotlin Coroutine pipeline against native DAW integrations.
- **C++ Audio Layer (Conditional v0.5.0+):** If Kotlin limits are hit, migrate the hot data path to Android's native `AMidi` C API and Dart FFI shared memory. The internal data model is already **32-bit UMP-aligned** (v0.2.1) to support this transition.

## 9. Error Handling & Stability

- **Native Layer Hardened**: Centralized all unsafe Android MIDI operations (connect, disconnect, send) into a global `safeExecute` wrapper in `Utils.kt`. This ensures that `IOException` or `IllegalStateException` during rapid hot-plugging are logged via the diagnostics system rather than crashing the application.
- **Dead Receiver Quarantine:** Catch `IOException` on hardware writes and isolate disconnected receivers in a quarantine set to prevent infinite Binder crash loops during rapid hotplugging.
- **Invalid MIDI frames:** ignore and continue.
- **Unknown SysEx commands:** log and ignore.
- **Port loss:** preserve UI state, signal disconnected mode, retry connection.

## 10. Version Roadmap

The complete implementation history, current focus, and future version roadmap (v0.1.0 through v1.0.0) is maintained exclusively in [IMPLEMENTATION.md](IMPLEMENTATION.md).

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