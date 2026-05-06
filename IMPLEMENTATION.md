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

### ✅ v0.2.2 – Native UMP Backend Migration

- **MidiParser Extraction**: Extracted UMP reconstruction logic into isolated, testable `MidiParser.kt` static object for comprehensive unit testing without Android Service mocks.
- **Native UMP Transport**: `VirtualMidiService` and `PeripheralMidiService` enforce UMP via `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag.
- **Manual 32-bit Reconstruction**: Implemented defensive `byte[]` → 32-bit UMP integer pipeline with bounds checking.
- **Simplified MidiEvent Model**: Replaced multi-field constructor with single 32-bit `ump` integer + bitwise extraction getters.
- **Primitive Batching JNI Bridge**: EventChannel sends `Int64List` pairs (UMP integer + timestamp) instead of Map objects.
- **Thermal Stabilization**: Fixed stream leaks, infinite update loops, MIDI flooding, and monotonic clock throttling. Optimized Riverpod batching and diagnostics disposal.
- **Automated Test Suite**: 10+ test files covering native UMP parsing, Dart layer integration, widget tests, and stress testing.

### ✅ v0.2.3 – Core Routing Engine Phase 1 & Hardening

- **MidiRouter Graph**: Centralized DAG for N-to-N routing with reachability-based cycle prevention (`_canReach`), queue-based traversal, and object pooling.
- **Extreme Thermal Optimization**:
  - **Primitive Packing**: Eliminated `Pair` boxing by packing UMP and timestamps into `Long` primitives.
  - **Buffer Re-use**: Reimplemented `MidiParser` and JNI bridge to reuse buffers and coroutines, reducing allocation churn by ~2MB/sec.
- **Architecture & Thermal Reliability**:
  - **Thermal Priority**: `appCategory="game"` for OS-level scheduler prioritization.
  - **State Reliability**: CC state replay, lazy-init map allocations, and fixed UMP word alignment for multi-word packets.

### ✅ v0.3.0: Core Routing Engine, UMP, & Performance Hardening

- **DAG Routing Ecosystem**: Full integration of transformer nodes (`SplitNode`, `RemapNode`, `FilterNode`) allowing modular N-to-N manipulations inside the `MidiRouter`.
- **Universal MIDI Packets (UMP) Migration**: Finalized transition to 32-bit `MidiEvent` architecture internally to secure MIDI 2.0 readiness.
- **Dynamic Connection Island**: Introduced an animated, adaptive status indicator (using `SizeTransition` to eliminate layout jank) that handles all 7 MIDI states and guards configuration via double-tap-hold gestures.
- **PerformanceTickerMixin**: Centralized lifecycle management for interactive widgets with managed disposal and background recovery.
  - Added **safeStartTicker** guards to provide a centralized, guarded way to start tickers, preventing "already active" or "disposed" assertion crashes.
- **Utility Grid Clear/Reset UX**: Disambiguated hard unbind from factory restore. Controls visually reflect "UNASSIGNED" states with interaction guards.
- **Side Panel Docking**: Implemented a side-agnostic flyout system for landscape orientations, supporting Left/Right docking.
- **Layout Hardening**: Eradicated build-phase orientation mutations; migrated to `didChangeMetrics`.
- **O(1) Rendering Engine**: Optimized the UI grid with index-based leaf subscriptions and decoupled render pulls to handle extreme automation density without frame drops.
- **Native Android Resilience**: Hardened `MidiSystemManager` with callback tracking per transport and physical disconnect handling.
- **Zero-Allocation Hot-path**: Primitive-indexed state maps and bounded object pooling (`_MAX_POOL_SIZE = 256`) in the routing engine.
- **Monotonic Timing Guards**: Replaced `DateTime.now()` with `Stopwatch` for all gesture and rate-limiting logic.
- **OMC Ecosystem Unification**: Finalized a robust architecture for full state persistence, integrating `LayoutPage` mappings into `PresetSnapshot` for atomic saving/loading of complex multi-fader layouts and settings.
  - Standardized all preset and layout management under the `.omc` format.
  - Refactored the `SettingsScreen` to include a centralized **"OMC ECOSYSTEM"** section for all file management tools.
- **Unified Control SSoT**: Consolidated all performance widgets to read MIDI configurations from a single `LayoutState` source of truth, eliminating configuration drift.
- **Headless Compositor Guard**: Implemented `isPaused` lifecycle guard in `UiStateSinkNode` to prevent the Flutter compositor from waking up when backgrounded.
- **Lock-Free Native Pipeline**: Replaced `@Synchronized` locks with an `AtomicLong`-based SPSC ring buffer in the native ingress pipeline.
- **Zero-Copy State Logic**: Added `ControlState.raw` constructor to bypass defensive copying in the state hot-path.
- **Memory-Efficient Logging**: Migrated diagnostics log to a version-tracked ring buffer, reducing heap churn during high-frequency monitoring.
- **Thermal Hardening**: Implemented visibility-aware resource management. Performance widgets now suspend MIDI listeners and tickers when backgrounded in `IndexedStack`.
- **Gesture System Hardening**: Decoupled `ConfigGestureWrapper` from widget-level interaction state to eliminate gesture noise and ensure reliable configuration trigger timings.
- **UI UX Normalization**: Refactored `ControlConfigModal` with a top-right 'X' close button and grouped action row to resolve button overflow and improve tactile ergonomics.
- **Developer Experience CLI**: Enhanced `run_app.py` with an interactive mode for device management and release workflows.
- **Riverpod-Based Lifecycle Bridge**: Migrated `PerformanceTickerMixin` to use `appLifecycleStateProvider` via Riverpod `listenManual`, consolidating lifecycle management and eliminating native observer overhead.
- **Background Transport Isolate**: Implemented a dedicated worker isolate for native MIDI transport, utilizing `TransferableTypedData` for zero-copy communication to eliminate UI thread saturation.
- **Native Object Pooling**: Introduced reusable `LongArray` pools for native-to-Dart transit to eliminate garbage collection churn during automation bursts.
- **Orientation Memory Leak Fix**: Tracked orientation changes via `didChangeDependencies` to prevent redundant `addPostFrameCallback` registration.

### ⏳ Current Focus: v0.4.x – Dynamic Modular Layout Engine

- **v0.4.0 (Core Engine)**: Migration from hardcoded panels to a data-driven fixed-ratio grid system.
- **v0.4.1 (Editor Mode)**: Implementation of drag-and-drop, resizing, and the widget palette.
- **v0.4.2 (Persistence & Marketplace)**: JSON schema versioning and manifest metadata for layout sharing.

### ⏳ v0.5.x – The MCU / HUI Protocol Series

- **v0.5.0 (Core Logic)**: Basic MCU protocol mapping and native UMP high-resolution control.
- **v0.5.1 (Handshake)**: DAW device detection and bidirectional negotiation.
- **v0.5.2 (Feedback)**: LCD track naming logic and bank switching feedback.

### ⏳ v0.6.0 – Native DAW Scripts & Architecture Review

- **Remote Scripts**: Python/JS integrations for Ableton, Cubase, and Logic.
- **Performance Audit**: Benchmark Kotlin pipeline against native DAW integrations.
- **NDK Fast Path (Conditional)**: C++ AMidi and Dart FFI shared memory migration.
