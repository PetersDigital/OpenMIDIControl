# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

## [Unreleased]
### Added
- Kotlin / host integration work (v0.2.0) will add the native MIDI bridge, port selectors, and defensive correspondence for wired USB transport.

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
- **Riverpod + theming:** Riverpod providers now power layout/behavior state, and the Material 3 dark theme pulls `Space Grotesk` + `Inter` while honoring the Ethereal Console palette.
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