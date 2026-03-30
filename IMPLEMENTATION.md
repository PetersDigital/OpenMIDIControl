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
- **SDK Exclusivity**: Enforced `minSdkVersion = 33` to provide native foundation for MIDI 2.0 and UMP (SHA `97e002e`).

### ✅ v0.2.2 – Hybrid UMP Implementation (Complete)

**Strategic Architecture Decision**: Retained `MidiDeviceService` over `MidiUmpDeviceService` due to Android's incomplete UMP implementation:
- `MidiUmpDeviceService` virtual UMP requires Android 15+ (API 35) and feature flag `FLAG_VIRTUAL_UMP`
- Feature-flagged API unreliable across OEMs
- Restrictive port constraints (input=output, non-zero)
- Hybrid approach provides 90% device coverage (Android 13-15) vs. 20% for native UMP

**Key Features**:
- **Manual 32-bit UMP Reconstruction**: `MidiParser.kt` processes `byte[]` in 4-byte chunks with big-endian reconstruction: `(b1 << 24) | (b2 << 16) | (b3 << 8) | b4`
- **UMP Transport Flag**: All ports opened with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` for MIDI 2.0 compatibility
- **Primitive EventChannel Batching**: Optimized JNI bridge using `LongArray` instead of `List<MidiEvent>` to reduce GC pressure
- **Automated Test Suite**: UMP transport tests with known payloads, validation of bitwise extraction logic
- **Defensive Bounds Checking**: Prevents DoS via malformed MIDI packets in native layer
- **Package Standardization**: Migrated to lowercase `com.petersdigital.openmidicontrol` namespace
- **UMP Detection Heuristics**: Enhanced `isUmp` detection with Message Type (MT) validation (MT 0x1, 0x2)
- **Multi-Cable Support**: Preserved UMP group data for future multi-cable expansion

**Performance**:
- 8ms batching interval (120Hz) with primitive `LongArray` for zero-allocation dispatch
- UMP reconstruction overhead: ~0.1-0.5ms (negligible vs. USB transport latency ~1-2ms)
- Real-time message filtering (0xF8 Timing Clock, 0xFE Active Sensing) at native entry point
- Bounds-checked batch dispatch loop prevents array index crashes

**Code Quality**:
- Extracted `MidiParser.processMidiPayload()` for testability (separated from MainActivity)
- Implemented automated UMP transport test suite with known payloads
- Added defensive bounds checking in Dart layer for malformed JNI payloads
- **Comprehensive Test Coverage** (10 test files):
  - **Kotlin Native**: `MidiParserTest.kt` - UMP reconstruction, filtering, echo suppression, batching bounds
  - **Dart Models**: `midi_event_test.dart` - Bitwise extraction, Riverpod equality, malformed payloads
  - **Dart Models**: `midi_models_test.dart` - MidiPort parsing, MidiStatus updates
  - **Dart State**: `control_state_test.dart` - ControlState immutability, CcNotifier batch updates
  - **Dart Diagnostics**: `diagnostics_test.dart` - Logger notifier, console widget, auto-dispose
  - **Dart UI**: `settings_screen_test.dart` - Settings rendering, PackageInfo integration
  - **Dart UI**: `midi_settings_screen_test.dart` - Port selection, USB status, highlighting
  - **Dart State**: `midi_settings_state_test.dart` - Settings state immutability
  - **Dart UI**: `open_midi_screen_test.dart` - Main screen layout, fader behaviors, multi-touch
  - **Dart Integration**: `midi_pipeline_integration_test.dart` - EventChannel multiplexing, 10K event stress test

**Documentation**:
- Updated ARCHITECTURE.md with hybrid UMP rationale
- Documented Android UMP API limitations (requires Android 15+, feature-flagged)
- Added technical decision record for hybrid architecture choice
- Updated TESTING.md with comprehensive test suite documentation

### ⏳ v0.2.3 – Core Routing Engine (DAG)
- **MidiRouter Graph**: Centralized routing graph using canonical 32-bit UMP payloads
- **Transformer Nodes**: Logic modules for filtering, remapping, and splitting streams
- **Routing Presets**: Save/load routing configurations as JSON
- **Latency Monitoring**: Real-time UMP pipeline latency measurement (p50, p95, p99)

### ⏳ v0.3.0 – Performance Optimization & Control Expansion
**Performance Optimizations**:
- **Kotlin SIMD UMP Reconstruction**: RenderScript-based batch processing targeting <0.1ms latency (4x speedup)
- **Zero-Copy Ring Buffer**: Replace Channel with shared memory ring buffer for JNI dispatch
- **GC Elimination**: Preallocate all UMP buffers, eliminate per-event allocations

**Control Expansion**:
- **3x3 Pad Grid**: Velocity-sensitive pads with aftertouch support
- **Per-Note Polyphonic Aftertouch**: UMP-native per-note pressure control (MIDI 2.0 feature)
- **32-bit High-Resolution CC**: Native 32-bit CC values instead of 7-bit (0-127)
- **Multi-Channel Assignment**: Per-control MIDI channel assignment (1-16)

**State Management**:
- **Raw Snapshots**: Save/load complete control state as JSON
- **Preset Management**: Quick-swap between routing/CC configurations
- **Cloud Sync**: Optional preset backup via Google Drive (future)

### ⏳ v0.4.0 – NDK Fast Path & MIDI 2.0 Integration (CRITICAL)
**NDK Fast Path** (MOVED UP from v0.5.0):
- **C++ AMidi Implementation**: Direct UMP handling via Android NDK AMidi API
- **Dart FFI Bridge**: Zero-copy shared memory between NDK and Flutter
- **Sub-0.1ms Latency**: Target end-to-end UMP latency <100µs
- **No GC Jitter**: Complete elimination of Kotlin JVM garbage collection pauses

**MIDI 2.0 Integration** (TIMING: Windows RC3 → Stable in 1-2 months):
- **Windows MIDI 2.0 Status**: Release Candidate 3 (RC3) as of Feb 2026
- **Expected Stable Release**: March-April 2026 (1-2 months from RC3)
- **Expected Cubase 15 MIDI 2.0**: Q3 2026 (3-4 months after Windows stable)
- **MIDI-CI Handshake**: Capability Inquiry for MIDI 2.0 device discovery
- **High-Res CC (32-bit)**: Native UMP 32-bit control (Cubase macOS already supports)
- **Per-Note Pitch/Pressure**: UMP Channel Voice messages
- **Windows UMP Native**: Direct WinRT MIDI 2.0 transport (when SDK stabilizes)

**DAW Profile Presets**:
- Pre-configured mappings for Cubase, Ableton, FL Studio, Logic
- MIDI 2.0 negotiation profiles per DAW
- Fallback to MIDI 1.0 for legacy DAWs

**Why MIDI-CI is CRITICAL** (Feb 2026 Update):
- ✅ Windows 11 MIDI 2.0 **RC3** (stable release in 1-2 months)
- ✅ Cubase 15 will add MIDI 2.0 support **3-4 months after Windows stable**
- ✅ Cubase macOS already supports MIDI 2.0 high-res (CoreMIDI)
- ✅ NI Kontrol S49 Mk3 ships with MIDI 2.0 + MIDI-CI
- ✅ **Timeline**: OpenMIDIControl v0.4.0 must be ready by Q3 2026 for Cubase MIDI 2.0 wave

**Implementation Priority**:
1. ✅ Hybrid UMP (v0.2.2) - DONE
2. ✅ SIMD optimization (v0.3.0) - In progress
3. 🚨 **NDK Fast Path + MIDI-CI (v0.4.0)** - CRITICAL (Q3 2026 Cubase deadline)
4. ⏳ Cross-platform abstraction (v0.5.0) - iOS/Windows ports

### ⏳ v0.5.0 – Cross-Platform UMP Abstraction
**Platform Abstraction Layer**:
- **ump_reconstructor.dart**: Platform-agnostic UMP bitwise extraction (shared)
- **ump_router.dart**: Cross-platform DAG routing engine (shared)
- **ump_profiles.dart**: DAW profile definitions (shared)

**iOS/iPadOS Port** (NEW):
- **Swift UMP Reconstruction**: Native iOS implementation using CoreMIDI
- **iPad Layout Optimization**: Tablet-first UI with expanded control surface
- **Apple Silicon UMP**: Optimized for M-series chips with SIMD acceleration

**Windows Desktop Port** (NEW):
- **WinRT MIDI Services**: Native Windows 11 MIDI 2.0 support
- **Desktop UI Layout**: Mouse/keyboard-optimized control surface
- **VST3 Wrapper**: Host OpenMIDIControl as a VST3 plugin (future exploration)

### ⏳ v0.6.0 – Plugin Architecture & Advanced Features
**Plugin System**:
- **Custom Transformers**: User-authored UMP processing plugins (Dart API)
- **Protocol Adapters**: Third-party MCU/HUI/OSC implementations
- **Layout Plugins**: Custom UI control definitions via JSON schema

**Advanced Features**:
- **Visual Feedback**: OLED display integration for parameter values
- **Haptic Patterns**: Customizable vibration feedback per control
- **Network MIDI**: RTP-MIDI (Wi-Fi) and Bluetooth MIDI transport
- **OSC Bridge**: Open Sound Control protocol integration

### ⏳ v0.7.0 – Layout Editor & Community Features
**Layout Editor**:
- **Visual Designer**: Drag-and-drop control surface builder
- **Serializable Schema**: All controls defined in JSON/YAML
- **Community Sharing**: Preset marketplace for layouts/routing

**Community Features**:
- **Preset Marketplace**: User-submitted routing/CC configurations
- **DAW Profile Contributions**: Community-maintained DAW mappings
- **Plugin Repository**: Third-party transformer/plugin hosting

### ⏳ v1.0.0 – Stable Release & Contributor-Ready
**Release Criteria**:
- **API Stability**: Frozen public API for third-party developers
- **Complete Documentation**: Developer guides, API references, tutorials
- **Test Coverage**: >90% unit test coverage, automated fuzzing
- **Performance Benchmarks**: All targets met (<0.1ms latency, 0% idle CPU)

**Final Polish**:
- **Accessibility Audit**: Full screen reader support, high-contrast themes
- **Security Review**: Third-party security audit for NDK/FFI code
- **Localization**: Multi-language UI support (Chinese, Japanese, German)
