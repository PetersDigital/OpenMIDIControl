## Implementation Roadmap

Following the [Version Roadmap](README.md#version-roadmap-v0.1.0-to-v1.0.0), the implementation is structured as follows:

### ✅ v0.1.0: Baseline
- **Responsive UI Shell:** Building the "Console" using `LayoutBuilder` (Portrait Phone / Landscape Tablet).
- **Core Fader Logic:** Multi-touch pointer capture and normalized `0.0..1.0` value domain.
- **State Management:** Riverpod `Notifier` providers for transport-agnostic logic.

### ✅ v0.1.5: MIDI Reliability & Logic Polish
- **Metadata Reconnection:** Switched from transient IDs to Name/Manufacturer fingerprints for robust USB hot-plugging.
- **Virtual MIDI Bridge:** Native `VirtualMidiService.kt` to expose "OpenMIDIControl" as a device for other mobile apps.
- **Bi-directional Logic Engine:** Behavior logic (Catch-up/Hybrid) applied to both UI drag events and incoming MIDI `CC` streams.
- **Orientation Fix:** Dedicated `_MobileLandscapeLayout` to handle ultra-wide aspect ratios (19.5:9+).
- **Active Port UI:** Translucent row highlighting in MIDI settings to visualize active "data pipes."

### ✅ v0.2.0: Advanced USB MIDI & Dual-Path Routing
- **True Peripheral Mode:** Native Android `MidiDeviceService` for class compliance on Windows 11.
- **Dual-Path Routing:** High-speed native Kotlin transport for peripheral mode bypassing Flutter event loop.
- **Performance Batching:** 8ms Coroutine-based buffering for smooth UI fader rendering.
- **Binder Stability:** Port collision hiding and "Dead Receiver Quarantine" logic to prevent Binder crashes during hotplugging.
- **Thread Safety:** Migrated state maps to `ConcurrentHashMap` for cross-thread reliability.
- **Manual Port Selection:** Added a toggle in Settings to optionally show internal ports in the device list.
- **MIDI Real-Time Filtering:** Broad-spectrum discard of `0xF8`/`0xFE` in `MidiReceiver.onSend` to prioritize control data over clock saturation.
- **Riverpod .select() Optimization:** High-frequency UI rebuild prevention via targeted state subscriptions in `HybridTouchFader`.
- **Silent Dispatch Idle:** Replaced busy-wait polling with event-driven suspension in the native MIDI bridge.
- **Thermal Stabilization:** Implemented Riverpod batching and direct animation-value assignment to reduce Dart VM and rendering overhead during heavy automation.

### ✅ v0.2.1: Canonical Data & State Model
- **MidiPortBackend Abstraction**: Unified interface for OS-native vs. raw USB driver fallback (MIDI 1.0 logic).
- **Universal Payload Structure**: Introduction of the internal 32-bit UMP-ready MIDI format (32-bit `MidiEvent`).
- **Event vs. State Separation**: Formalized `MidiEvent` (transport) vs. `ControlState` (UI-facing logic), enforced via strict immutability.
- **Diagnostic Tools**: Real-time DiagnosticsConsole UI with `autoDispose` logic and high-precision native timestamps.
- **Service Centralization**: Migrated stream parsing into `MidiService` for single-decode event distribution.
- **Native Stability Hardening**: Centralized all native port operations in a shared `safeExecute` utility.

### ✅ API 33+ Baseline (Post-v0.2.1)
- **SDK Exclusivity**: Enforced `minSdkVersion = 33` to provide native foundation for MIDI 2.0 and UMP.

### ⏳ Current Focus: v0.2.2 – Native UMP Backend Migration

**Core UMP Transport Implementation:**
- **MidiParser Extraction**: Extracted UMP reconstruction logic from `MainActivity.kt` into isolated, testable `MidiParser.kt` static object for comprehensive unit testing without Android Service mocks.
- **MidiDeviceService with UMP Transport**: `VirtualMidiService` and `PeripheralMidiService` extend Android's `MidiDeviceService` (API 33+) with UMP transport enforced via the `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag for system-level virtual routing.
- **SDK Constraint Handling**: Client ports use legacy `MidiDevice` and `MidiPort` classes to satisfy compiler visibility, while guaranteeing UMP traffic via the `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag.
- **Manual 32-bit Reconstruction**: `MidiReceiver.onSend()` iterates through `byte[]` in 4-byte chunks, reconstructing 32-bit integers via bitwise shifts with strict defensive bounds checks (`offset >= 0`, `count % 4 == 0`, `offset + count <= msg.size`).
- **UMP Group Preservation**: Multi-cable UMP group data is preserved during reconstruction (not discarded), enabling future MIDI 2.0 multi-group support.
- **Enhanced isUmp Detection**: Improved heuristic detection using MT (Message Type) validation — checks for MT=0x1 (System) or MT=0x2 (MIDI 1.0 Channel Voice) to prevent false positives from legacy byte streams.

**Dart Layer UMP Integration:**
- **Simplified MidiEvent Model**: Replaced multi-field constructor with single 32-bit `ump` integer + bitwise extraction getters (`messageType`, `group`, `status`, `channel`, `data1`, `data2`, `legacyStatusByte`).
- **Primitive Batching JNI Bridge**: EventChannel now sends `Int64List` (pairs of UMP integer + timestamp) instead of Map objects, eliminating serialization overhead and improving throughput.
- **Stream Leak Prevention**: Refactored `MidiService` to use `late final` streams, preventing platform stream subscription leaks and infinite UI update loops.
- **Defensive Bounds Checking**: Added validation for malformed JNI payloads (odd-length `Int64List` structures) with safe orphan value skipping.

**Thermal & Performance Stabilization:**
- **Stream Subscription Leak Fix**: Fixed platform stream subscription leak in `MidiService` by refactoring to `late final` streams.
- **Infinite Update Loop Prevention**: Eliminated with `changed == true` guards in `CcNotifier` — early return if values haven't changed.
- **Root Cause Removal**: Removed global `ref.watch` from app root to prevent full-tree rebuilds on every MIDI event.
- **MIDI Flood Throttling**: Added 8ms throttle (~120Hz) in `HybridTouchFader` to prevent MIDI flooding during rapid touch events.
- **Batched Diagnostics**: Updates use `SchedulerBinding.scheduleFrameCallback` (~60Hz) to prevent CPU drain from excessive logging.
- **Monotonic Clock Throttling**: Replaced `DateTime.now()` with `Stopwatch.elapsedMilliseconds` in `HybridTouchFader` MIDI throttling. `DateTime.now()` is non-monotonic and can jump on NTP sync, breaking throttle logic. `Stopwatch` provides reliable monotonic clock for ~120Hz MIDI rate limiting.
- **Lazy-Init Map Allocation**: Optimized `CcNotifier.updateMultipleCCs()` with single-pass iteration and lazy `Map` initialization — only allocates new state when actual changes are detected, avoiding double-pass and full-map copy overhead during MIDI bursts.
- **Diagnostics Disposal Guard**: Added `_disposed` flag to `DiagnosticsLoggerNotifier.scheduleFrameCallback` to prevent state-write errors when the frame callback fires after auto-dispose. Also resets `_pendingUpdate` in `onDispose` to prevent stale state on re-mount.

**Thermal Spiking Mitigation & Performance Refinements:**
- **Iterative Fast-Reject Spam Filtering**: `MidiParser` now iteratively fast-rejects real-time spam arrays (0xF8, 0xFE) before expensive 32-bit reconstruction, reducing CPU overhead during clock saturation. Spam detection happens early in the hot path, avoiding unnecessary bitwise operations.
- **Fire-and-Forget sendCC**: `MidiService.sendCC()` uses `.catchError()` instead of `await`, eliminating platform channel result-wait overhead and improving outbound MIDI latency. Returns the Future directly for callers that need it, but doesn't block the caller.
- **Device Refresh Debouncing**: `ConnectedMidiDeviceNotifier` uses 300ms `Timer` debounce for device refresh operations, preventing redundant `midiDevicesProvider` invalidations during rapid USB state changes. Timer is properly canceled in `onDispose` to prevent memory leaks.
- **Broadcast Stream Cleanup**: Removed redundant `.asBroadcastStream()` calls from `_rawStream`, `midiEventsStream`, and `systemEventsStream`. `receiveBroadcastStream()` already provides broadcast semantics, eliminating duplicate subscription overhead.
- **Logging Overhead Removal**: Stripped `isDebug` parameter from `MidiParser.processMidiPayload()` hot-path parsing, removing conditional branch overhead from the critical MIDI processing pipeline. Debug logging moved to conditional compilation for zero-cost in release builds.
- **Symmetric Unregister Fix**: Ensured symmetric callback unregistration in `teardownMidiDeviceCallback`, preventing callback leaks and potential double-unregister crashes. Both virtual and peripheral callbacks are now properly unregistered with matching parameter structures.
- **Unused State Removal**: Removed unused `currentUsbMode` variable from `setUsbMode` handler, reducing state management overhead.
- **Clarified Spam Filter Comments**: Updated MIDI service comments to clarify that spam filtering is handled by `MidiParser.processMidiPayload()`, not moved elsewhere.

**Automated Test Suite:**
- **Kotlin Native Tests** (`MidiParserTest.kt`): 6 test scenarios covering UMP heuristic validation, legacy fallback, 32-bit reconstruction, spam filtering, echo suppression, and batching loop bounds.
- **Dart Unit Tests** (8 test files): Comprehensive coverage of MidiEvent bitwise extraction, ControlState immutability, CcNotifier batch updates, and malformed payload handling.
- **Widget Tests** (4 test files): Settings screens, MIDI settings, diagnostics console, main screen layout, and fader behaviors.
- **Integration Tests** (`midi_pipeline_integration_test.dart`): EventChannel multiplexing with interleaved `Int64List`/`Map` payloads, and 10,000-event high-frequency stress test.

**Bug Fixes:**
- **Array Bounds Crash**: Fixed crash in native batch dispatch loop with strict bounds checking (`count + 1 < batch.size`).
- **MIDI Channel Loss**: Fixed `forwardCcEvent()` UMP reconstruction to preserve MIDI channel in status byte.
- **Missing Import**: Added missing `Int64List` import in `midi_service.dart`.
- **Redundant Import**: Removed redundant `typed_data` import in `hybrid_touch_fader.dart`.
- **UMP Comment Clarity**: Clarified UMP MT 0x1 bit layout in code comments for maintainability.
- **MidiParser Comment Fix**: Fixed legacy filtering comments in `VirtualMidiService.kt` and `PeripheralMidiService.kt` to correctly reference `MidiParser.processMidiPayload()` instead of incorrectly stating filtering moved to `MainActivity`.

### ⏳ v0.2.3 – Core Routing Engine (DAG)
- **MidiRouter Graph**: Centralized routing graph using canonical payloads.
- **Transformer Nodes**: Logic modules for filtering, remapping, and splitting streams.

### ⏳ v0.3.0 – Control Expansion & Basic State
- **Grid & Tactile Inputs**: 3x3 pads, buttons, and switches with low-latency velocity simulation.
- **Multi-Channel Support**: Assignable UI controls for independent MIDI channels.
- **Raw Snapshots**: Basic save/load functionality via the `ControlState` model.

### ⏳ v0.4.x – The MCU / HUI Protocol Series
- **v0.4.0 (Core Logic)**: Basic MCU protocol mapping and native UMP high-resolution control.
- **v0.4.1 (Handshake)**: DAW device detection and bidirectional negotiation.
- **v0.4.2 (Feedback)**: LCD track naming logic and bank switching feedback.

### ⏳ v0.5.0 – Native DAW Scripts & Architecture Review
- **Remote Scripts**: Python/JS integrations for Ableton, Cubase, and Logic.
- **Performance Audit**: Benchmark Kotlin pipeline against native DAW integrations.
- **NDK Fast Path (Conditional)**: C++ AMidi and Dart FFI shared memory migration.

### ⏳ experimental/v0.5.x – MIDI 2.0 Native Path
- **MIDI-CI Handshake**: Capability Inquiry negotiation.
- **OS UMP Integration**: Direct UMP payload transfer for supported platforms.

### ⏳ v0.6.0+: Customization & Plugins
- **Full Preset Engine**: Snapshot management and schema saving.
- **Layout Editor**: Visual drag-and-drop customization and serializable UI schema.
- **Plugin Layer**: Extensibility hooks for custom transformers and protocol adapters.
