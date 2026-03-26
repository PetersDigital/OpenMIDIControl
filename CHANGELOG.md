# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

## [0.2.1] - 2026-03-26

### Added
- **Canonical Data Model (MidiEvent):** Introduced a strictly typed, immutable data model in Dart composed of discrete integer fields (message type, channel, data1, data2, timestamp) to represent raw transport data. This decouples the UI from JNI map serialization and prepares the architecture for Universal MIDI Packets (UMP).
- **Canonical UI State (ControlState):** Introduced a scalable, immutable Riverpod state model that consolidates all map-based control values into a single source of truth, replacing the legacy CCState.
- **Native Dependency Inversion (MidiPortBackend):** Created a unified Kotlin interface to abstract Android's MidiManager, MidiDevice, and MidiPort classes.
- **Native Android Backend:** Implemented `NativeAndroidMidiBackend` to encapsulate OS-level port lifecycles and safely manage connections for both Host and Peripheral modes using `safeExecute` teardown blocks.
- **Diagnostics Logger:** Added a real-time, terminal-style DiagnosticsConsole UI and `DiagnosticsLoggerNotifier` to monitor high-speed incoming MIDI event streams directly on the device.

### Changed
- **Batch Processing Optimization:** Refactored the `EventChannel` listener in `midi_service.dart` to decode incoming JNI batches into `List<MidiEvent>` and apply UI state changes exactly once per batch (`updateMultipleCCs`), preserving the 120Hz thermal optimizations.
- **Fader Interpolation Smoothing:** Reintroduced a lightweight, 45ms linear `animateTo` curve in `HybridTouchFader`. This smoothly bridges visual gaps caused by 20Hz DAW automation limits and Android OS `EAGAIN` buffer overflows, replacing the previous instant-snap logic.
- **Native Routing Handshake:** Refactored `MainActivity` and `PeripheralMidiService` to interact exclusively with the `MidiPortBackend` abstraction, severing hardcoded dependencies on Android OS classes for data flow.

### Fixed
- **Diagnostics Background CPU Drain:** Upgraded the `DiagnosticsLoggerNotifier` to utilize Riverpod's `NotifierProvider.autoDispose` and `ref.onDispose`. The underlying MIDI stream subscription is now explicitly canceled when the debug modal is closed, preventing background string formatting and saving CPU cycles.

## [0.2.0] - 2026-03-26

### Added
- **True Peripheral Mode:** Native Android `MidiDeviceService` implementation for plug-and-play class compliance on Windows 11.
- **Dual-Path MIDI Routing:** Native Kotlin transport for USB Peripheral mode bypassing the Flutter event loop for ultra-low latency.
- **Kotlin Coroutines Dispatcher:** Non-blocking `Channel` buffering for high-frequency MIDI event handling.
- **Batched Event Dispatching:** 8ms polling (120Hz) logic to batch MIDI payloads to Flutter, drastically reducing UI thread starvation.
- **Manual Port Selection Override:** UI toggle in settings to forcefully reveal internal ports for debugging and advanced routing.
- **USB Peripheral Mode UI:** Dedicated status banners and configuration toggles in `MidiSettingsScreen`.
- **Haptic Feedback:** Bi-directional tactile response for USB connection/disconnection state changes.

### Fixed
- **Binder Collision Crash:** Resolved "port 0 already open" by hiding the physical hardware port from Flutter's device query.
- **USB Outbound Data Dropouts:** Established a direct hardware data pipe by writing CC bytes directly to the `MidiInputPort` transport.
- **Dead Receiver Quarantine:** Added logic to isolate and ignore disconnected hardware receivers to prevent system-wide IO crashes during hotplugging.
- **Thread Safety:** Migrated state maps to `ConcurrentHashMap` to prevent crashes during concurrent MIDI processing and UI updates.
- **Immediate Handshake UX:** Removed legacy startup delays from USB broadcast receivers for instant UI state switching.
- **Memory Leak Prevention:** Rigorous hardware instance teardown sequence on application destruction and physical disconnect.
- **Riverpod State Type Safety:** Fixed Dart-side exceptions when casting native MIDI payloads as `List`.
- **Circular Dependency Resolution:** Decoupled MIDI settings state from the UI layer into a standalone module.
- **CPU Optimization:** Refactored the background MIDI dispatch loop in `MainActivity` from a busy-wait polling pattern to strict coroutine suspension (`for (event in channel)`), reducing idle CPU load from 50%+ to ~0%.
- **MIDI Real-Time Filtering:** Added explicit discard logic for Timing Clock (`0xF8`) and Active Sensing (`0xFE`) in the native layer to prevent `EventChannel` flooding and protect UI responsiveness.
- **Riverpod UI Optimization:** Migrated `HybridTouchFader` listeners to use the `.select()` modifier, ensuring faders only rebuild when their specific CC value changes.
- **Riverpod Batch Churn Fix:** Optimized CC state management to apply multiple updates in a single cycle, preventing $O(N)$ map copies and redundant rebuilds during heavy automation.
- **Animation Engine Bypass:** Refactored `HybridTouchFader` to use direct `AnimationController.value` assignment for external MIDI, avoiding 120Hz animation cancellation churn while following smoothed DAW automation.
- **Release Build Stability:** Enabled `BuildConfig` generation for production APKs and resolved conflicting status byte parsing logic in the native MIDI layer.

## [0.1.5] - 2026-03-24
### Added
- **Virtual MIDI Port:** App now publishes itself as a native Android MIDI device ("OpenMIDIControl").
- **Metadata-Based Reconnection:** Implemented "fingerprint" matching using device name and manufacturer to allow automatic reconnection when Android assigns a new transient ID to hot-plugged hardware.
- **Enhanced Active Indicators:** Updated the MIDI Settings UI to include full-row translucent highlighting for active Input and Output ports, providing a clear "selected" state.

### Fixed
- **Bi-directional Behavior Logic:** Extended Jump, Hybrid, and Catch-up logic to apply to incoming hardware MIDI CC data, ensuring the app fader respects the selected behavior when moved by a physical controller.
- **UI Device Re-sync:** Auto-refresh MIDI device list on `added` events and preserve previous `connectedDevice` metadata for reliable reattach reconnection.
- **Null-safe receiver handling:** Resolved nullable `MidiReceiver` usage for `connect`/`disconnect` in native bridge, preventing compilation/path failure across Kotlin versions.
- **MIDI API compatibility:** Added runtime-safe use of `MidiManager.getDevicesForTransport` on Android T IRAMISU+ and fallback to legacy `getDevices` for older releases.
- **Mobile orientation policy:** Enforced portrait-first fader UX for mobile phones while still allowing tablet landscape mode for future pad designs.
- **Script platform requirement:** Documented PowerShell 7+ requirement for script workflow.
- **Fader Gesture Initialization:** Consolidated gesture state handling within `onVerticalDragStart` to prevent accidental jumps during initial touch.
- **Haptic Type Safety:** Fixed a JVM crash in the native bridge by standardizing number-to-long casting for vibration durations.

### Removed
- **SysEx Support:** Hardware-specific LCD feedback and mode handshaking removed from this milestone due to protocol instability.

## [0.1.0] - 2026-03-22
### Added
- **v0.1.0 Flutter UI:** `OpenMIDIControl` now ships with the responsive command center (status row, 3×3 grid, and top-bar actions) plus the performance area containing two `HybridTouchFader` widgets that adjust for mobile or desktop layouts.
- **Hybrid Touch Fader polish:** Each fader displays `DSEG7Modern` readouts, supports long-press CC selection, and keeps per-control color cues, gutters, and multi-touch capture semantics.
- **Settings & MIDI placeholders:** Added the Settings view (Jump/Hybrid/Catch-Up, layout-hand toggle, version metadata) and the MIDI Settings placeholder (device disconnected banner + search tile) for the future MIDI port manager.
- **Riverpod + theming:** Riverpod providers now power layout/behavior state, and the Material 3 dark theme pulls `Space Grotesk` + `Inter` while honoring the [DESIGN.md](DESIGN.md) palette.
- **Native Build & CI Pipeline:** Added Android release signing via `key.properties` and GitHub secrets.
- **Dynamic Versioning:** The settings screen now dynamically displays the app version directly from `pubspec.yaml` using `package_info_plus`.
- **DSEG7Modern Fonts:** Bundled locally into Flutter assets for offline stability.

### Changed
- Renamed the Flutter package to `OpenMIDIControl`, updated build metadata, and centralized documentation around the new UI (README, DESIGN, IMPLEMENTATION) as part of the v0.1.0 release.
- Cleaned up Flutter analysis warnings, removed deprecated members, and refreshed iconography to keep the CI `flutter analyze` pass green.
- **UI Tweaks:** Aligned top-bar color with design system tokens and adjusted font sizes/padding for global layout consistency.
- **App Namespace:** Unified Android (`MainActivity` directory) and iOS bundle identifiers directly to `com.PetersDigital.OpenMIDIControl`.
- **Fader Behavior:** Bound `HybridTouchFader` internal behavior to `faderBehaviorProvider`.

### Fixed
- **Test State Bleed:** Added setup/teardown logic (`addTearDown` before `pumpWidget`) preventing cross-test pollution in widget specs.
- **Secret Management:** Ensured release properties (`key.properties`) are excluded in `.gitignore`.

## [0.0.0] - 2026-03-19
### Added
- Project initialized (documentation only).

[0.2.1]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.5...v0.2.0
[0.1.5]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.0...v0.1.5
[0.1.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.0.0...v0.1.0