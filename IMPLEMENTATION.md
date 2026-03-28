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

### ⏳ Current Focus: v0.2.2 – Native UMP Backend Migration
- **API 33+ Exclusivity**: Enforce `minSdkVersion = 33` to natively support MIDI 2.0 Universal MIDI Packets (UMP).
- **MidiUmpDeviceService**: Migrate the Virtual MIDI bridge and native backend to inherit from Android's UMP-specific services.

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
