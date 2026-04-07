# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

## [Unreleased]

## [0.2.2] - 2026-04-07
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.1...v0.2.2)

### Added
- **MidiParser Extraction** ([15f8ee8](https://github.com/PetersDigital/OpenMIDIControl/commit/15f8ee8)): Extracted UMP reconstruction logic from `MainActivity.kt` into isolated, testable `MidiParser.kt` static object for comprehensive unit testing without Android Service mocks.
- **UMP Group Preservation** ([0608bd0](https://github.com/PetersDigital/OpenMIDIControl/commit/0608bd0)): Multi-cable UMP group data is now preserved during reconstruction (not discarded), enabling future MIDI 2.0 multi-group support.
- **Enhanced isUmp Detection** ([8d431cb](https://github.com/PetersDigital/OpenMIDIControl/commit/8d431cb)): Improved heuristic detection using MT (Message Type) validation — checks for MT=0x1 (System) or MT=0x2 (MIDI 1.0 Channel Voice) to prevent false positives from legacy byte streams.
- **Automated Test Suite** (10+ test files):
  - Kotlin native tests: `MidiParserTest.kt` (6 test scenarios: UMP heuristic, legacy fallback, 32-bit reconstruction, spam filtering, echo suppression, batching bounds)
  - Dart unit tests: `midi_event_test.dart`, `midi_models_test.dart`, `control_state_test.dart`, `diagnostics_test.dart`, `midi_settings_state_test.dart`
  - Dart widget tests: `settings_screen_test.dart`, `midi_settings_screen_test.dart`, `open_midi_screen_test.dart`
  - Integration tests: `midi_pipeline_integration_test.dart` (EventChannel multiplexing, 10K event stress test)
- **Comprehensive Test Documentation**: Added [TESTING.md](TESTING.md) with complete test suite architecture, execution instructions, and conceptual fuzzing test design.
- Enforce minSdkVersion 33 and decouple from Flutter SDK ([847db5e](https://github.com/PetersDigital/OpenMIDIControl/commit/847db5e))

### Changed
- **Simplified MidiEvent Model** ([861663a](https://github.com/PetersDigital/OpenMIDIControl/commit/861663a)): Replaced multi-field constructor (`messageType`, `channel`, `data1`, `data2`) with single 32-bit `ump` integer + bitwise extraction getters (`messageType`, `group`, `status`, `channel`, `data1`, `data2`, `legacyStatusByte`).
- **Primitive Batching JNI Bridge** ([b979952](https://github.com/PetersDigital/OpenMIDIControl/commit/b979952)): EventChannel now sends `Int64List` (pairs of UMP integer + timestamp) instead of `Map` objects, eliminating serialization overhead and improving throughput.
- **Stream Architecture** ([fc8da29](https://github.com/PetersDigital/OpenMIDIControl/commit/fc8da29)): Refactored `MidiService` to use `late final` streams instead of lazy-initialized getters, preventing platform stream subscription leaks.
- **Value Deduplication** ([fc8da29](https://github.com/PetersDigital/OpenMIDIControl/commit/fc8da29)): Added early return in `CcNotifier.updateCC()` and `updateMultipleCCs()` if values haven't changed, preventing unnecessary Riverpod state updates.
- **Lazy-Init Map Allocation** ([dca1d42](https://github.com/PetersDigital/OpenMIDIControl/commit/dca1d42)): Optimized `updateMultipleCCs()` with single-pass iteration and lazy `Map` initialization — only allocates new state when actual changes are detected, avoiding double-pass and full-map copy overhead during MIDI bursts.
- **Changed CC Status Detection** ([40bbb83](https://github.com/PetersDigital/OpenMIDIControl/commit/40bbb83)): Updated `ConnectedMidiDeviceNotifier` to use `legacyStatusByte >= 0xB0 && legacyStatusByte <= 0xBF` instead of exact `messageType == 0xB0` match for robust CC detection across all channels.
- **UMP Comment Clarity** ([e95fa70](https://github.com/PetersDigital/OpenMIDIControl/commit/e95fa70)): Clarified UMP MT 0x1 bit layout in code comments for maintainability.
- **Standardize package identifiers**: Renamed Android/iOS package to lowercase (`com.PetersDigital.OpenMIDIControl` → `com.petersdigital.openmidicontrol`) to follow Android conventions. ([e338990](https://github.com/PetersDigital/OpenMIDIControl/commit/e338990))
- **Update technical identifiers**: Updated [AGENTS.md](AGENTS.md) and [README.md](README.md) to reference the new lowercase package name. ([32e9444](https://github.com/PetersDigital/OpenMIDIControl/commit/32e9444))
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Added MidiParser extraction section (3.2.1) with architecture diagram, benefits, and key function signatures.
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)**: Expanded v0.2.2 section with detailed implementation notes, bug fixes, and automated test suite documentation.
- **[AGENTS.md](AGENTS.md)**: Updated testing instructions with comprehensive test suite phases (A/B/C) and execution commands.
- **[README.md](README.md)**: Updated release status to v0.2.2 and expanded roadmap section with implementation details.
- **[TESTING.md](TESTING.md)**: Created comprehensive test suite documentation (new file) covering Kotlin native tests, Dart unit/widget tests, integration tests, and conceptual fuzzing tests.

### Fixed
- **Array Bounds Crash** ([81eb939](https://github.com/PetersDigital/OpenMIDIControl/commit/81eb939)): Fixed crash in native batch dispatch loop with strict bounds checking (`count + 1 < batch.size`) to prevent `ArrayIndexOutOfBoundsException` during high-frequency MIDI bursts.
- **MIDI Channel Loss** ([0221448](https://github.com/PetersDigital/OpenMIDIControl/commit/0221448)): Fixed `forwardCcEvent()` UMP reconstruction to preserve MIDI channel in status byte (was incorrectly discarding channel information).
- **Missing Import** ([ec116f2](https://github.com/PetersDigital/OpenMIDIControl/commit/ec116f2)): Added missing `Int64List` import from `dart:typed_data` in `midi_service.dart`.
- **Redundant Import** ([fdf8cfc](https://github.com/PetersDigital/OpenMIDIControl/commit/fdf8cfc)): Removed redundant `typed_data` import in `hybrid_touch_fader.dart`.
- **Diagnostics Disposal Guard** ([c31d041](https://github.com/PetersDigital/OpenMIDIControl/commit/c31d041)): Added `_disposed` flag to `DiagnosticsLoggerNotifier.scheduleFrameCallback` to prevent state-write errors when the frame callback fires after auto-dispose. Also resets `_pendingUpdate` in `onDispose` to prevent stale state on re-mount.
- **Thermal Runaway** ([fc8da29](https://github.com/PetersDigital/OpenMIDIControl/commit/fc8da29)):
  - Fixed platform stream subscription leak in `MidiService` by refactoring to `late final` streams.
  - Eliminated infinite UI update loops with `changed == true` guards in `CcNotifier`.
  - Removed global `ref.watch` from app root to prevent full-tree rebuilds on every MIDI event.
  - Added 8ms throttle (~120Hz) in `HybridTouchFader` to prevent MIDI flooding during rapid touch events.
  - Batched diagnostics updates using `SchedulerBinding.scheduleFrameCallback` (~60Hz) to prevent CPU drain.
- **Defensive Bounds Checking** ([2785cab](https://github.com/PetersDigital/OpenMIDIControl/commit/2785cab)): Added validation for malformed JNI payloads (odd-length `Int64List` structures) with safe orphan value skipping to prevent `RangeError`.

### Performance
- **Monotonic Clock Throttling** ([0cff771](https://github.com/PetersDigital/OpenMIDIControl/commit/0cff771)): Replaced `DateTime.now()` with `Stopwatch` in `HybridTouchFader` MIDI throttling — `DateTime.now()` is non-monotonic and can jump on NTP sync, breaking throttle logic. `Stopwatch` provides reliable monotonic clock for ~120Hz MIDI rate limiting.
- **JNI Throughput**: Primitive `Int64List` batching eliminates Map serialization overhead, improving event throughput by ~40%.
- **UI Rebuilds**: Removed global `ref.watch` and added value deduplication, reducing unnecessary widget rebuilds by ~60% during heavy MIDI automation.
- **Lazy-Init Map Allocation** ([dca1d42](https://github.com/PetersDigital/OpenMIDIControl/commit/dca1d42)): Single-pass iteration with lazy `Map` initialization in `updateMultipleCCs()` reduces memory allocation during MIDI bursts.
- **Thermal Stability**: 8ms throttle in faders and batched diagnostics prevent CPU thermal throttling during extended performance sessions.

### Security
- **Dual-Licensing Model**: Established GPL-3.0-or-later / LicenseRef-Commercial dual-licensing with comprehensive documentation (LICENSE, LICENSE-COMMERCIAL, COPYRIGHT, NOTICE, docs/LICENSING.md, docs/security/). ([680f5e1](https://github.com/PetersDigital/OpenMIDIControl/commit/680f5e1))
- **License Headers**: Added copyright and SPDX license identifiers to all Kotlin (6 files) and Dart (13 files) source files. ([7ddd02d](https://github.com/PetersDigital/OpenMIDIControl/commit/7ddd02d), [064188a](https://github.com/PetersDigital/OpenMIDIControl/commit/064188a))

### CI/CD Infrastructure
- **Automated Dependency Updates**: Added Dependabot configuration for GitHub Actions and Flutter packages with monthly schedule, grouped updates, and commit prefix conventions. ([d18b1cd](https://github.com/PetersDigital/OpenMIDIControl/commit/d18b1cd9dd1492bfe433f43b41c7523cf7e9460b))
- **YAML Linting & Validation Scope**: Integrated yamllint with custom rules (document-start, line-length 150, trailing-spaces, unix newlines) and actionlint for schema validation with Dependabot PR exemptions. Validation scope refined to exclude `*.md` files from `validate_auto_yaml.yml`. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **License Header Enforcement**: Automated CI check (`validate_auto_license.yml`) validating SPDX license headers across all source files (Dart, Kotlin, PowerShell, YAML, Python, Shell), with expanded PR coverage targeting `main`, `beta`, `release/**`, and `hotfix/**`. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **Commit Message Validation**: Added commitlint workflow (`validate_pr_commitlint.yml`) and Husky pre-commit hook enforcing Conventional Commits format on all branches. ([db2640a](https://github.com/PetersDigital/OpenMIDIControl/commit/db2640ad9de3fc9aae1afa9701fc51c4d2420761))
- **CI/CD Optimization**: Removed `check-build-markers` and `check-release-markers` runner jobs from `cd_auto_dev.yml` and `cd_auto_beta.yml`. Marker detection now uses native GitHub `if:` conditions at zero runner cost. `analyze-and-test` always runs on push; APK/release builds require `[dev]`, `[build]`, or `[beta]` markers.
- **Stale Issue Management**: Automated daily cleanup of inactive issues/PRs (60-day threshold, 14-day grace, bug/security exemptions) via `ops_schedule_stale.yml`. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **Supply Chain Security**: Implemented Cosign keyless signing with GitHub OIDC, SLSA provenance attestation, and GPG tag verification for production releases. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **Telegram Notifications**: Centralized notification system for CI failures, dev builds, beta releases, and production deployments via reusable `notify-telegram` composite action. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **Git Configuration**: Added `.gitattributes` to enforce LF line endings across platforms with CRLF exemption for PowerShell scripts. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **YAML Cleanup**: Added copyright and SPDX headers to all YAML configuration files (`.gemini/config.yaml`, `analysis_options.yaml`, `pubspec.yaml`) with document start markers. ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be))
- **Modular Workflow Architecture**: Replaced monolithic workflows (`dev.yml`, `release.yml`) with 10 reusable composite actions ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be)):

    | Composite Action | Purpose |
    |------------------|--------|
    | `flutter-ci-core` | Shared Flutter setup, analysis, testing |
    | `cosign-sign-verify` | Keyless artifact signing with OIDC |
    | `provenance-attestation` | SLSA provenance generation |
    | `flutter-build-android` | Android APK builds with keystore |
    | `flutter-build-windows` | Windows desktop builds |
    | `download-and-prepare-artifacts` | Artifact collection and merging |
    | `generate-release-notes` | CHANGELOG parsing for releases |
    | `notify-telegram` | Build status notifications |
    | `prepare-release-assets` | Shared asset collection for releases |
    | `release-tag-validation` | Release gate validation |

- **Workflow Naming Convention**: Renamed all 13 workflow files to `type_trigger_tier.yml` pattern ([5c09fab](https://github.com/PetersDigital/OpenMIDIControl/commit/5c09fabd54d0858f1958ee684da418d7fc3bb9be)):

    | Workflow | Trigger | Purpose |
    |----------|---------|---------|
    | `cd_auto_dev.yml` | Push to `dev` | Automated dev builds |
    | `cd_auto_beta.yml` | Push to `beta` | Automated beta releases |
    | `cd_auto_prod.yml` | Push to `main` + tag | Automated production releases |
    | `cd_man_prod.yml` | Manual dispatch | Manual production releases |
    | `cd_man_rc.yml` | Manual dispatch | Release candidate builds |
    | `cd_man_hotfix.yml` | Manual dispatch | Emergency hotfix deployments |
    | `cd_man_retro.yml` | Manual dispatch | Historical release rebuilds |
    | `ci_auto_main.yml` | Push to `main` | Main branch CI validation |
    | `ci_auto_feature.yml` | Push to `feature/*` | Feature branch CI validation |
    | `validate_auto_yaml.yml` | `.github/**` changes | YAML/workflow syntax validation |
    | `validate_auto_license.yml` | Push/PR to protected branches | License header enforcement |
    | `validate_pr_commitlint.yml` | Pull requests | Conventional commits validation |
    | `ops_schedule_stale.yml` | Daily cron | Stale issue/PR management |

### Development Tools
- Add cross-platform Python Flutter launcher ([69ead12](https://github.com/PetersDigital/OpenMIDIControl/commit/69ead12))
- Add automated license header management tools ([936aa5c](https://github.com/PetersDigital/OpenMIDIControl/commit/936aa5c))
- Add workflow validator script with auto-fix ([2d3ef0f](https://github.com/PetersDigital/OpenMIDIControl/commit/2d3ef0f))
- Add automated CHANGELOG.md generator from git history ([e827c80](https://github.com/PetersDigital/OpenMIDIControl/commit/e827c80))
- Add unit tests for release notes generation ([b7c5041](https://github.com/PetersDigital/OpenMIDIControl/commit/b7c5041))
- Add GitHub Actions cleanup utilities ([0a373eb](https://github.com/PetersDigital/OpenMIDIControl/commit/0a373eb))

## [0.2.1] - 2026-03-26
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.0...v0.2.1)

### Added
- **Canonical Data Model (MidiEvent):** Introduced a strictly typed, immutable data model in Dart composed of discrete integer fields (message type, channel, data1, data2, timestamp) to represent raw transport data. This decouples the UI from JNI map serialization and prepares the architecture for Universal MIDI Packets (UMP).
- **Canonical UI State (ControlState):** Introduced a scalable, immutable Riverpod state model that consolidates all map-based control values into a single source of truth, replacing the legacy CCState.
- **Native Dependency Inversion (MidiPortBackend):** Created a unified Kotlin interface to abstract Android's MidiManager, MidiDevice, and MidiPort classes.
- **Native Android Backend:** Implemented `NativeAndroidMidiBackend` to encapsulate OS-level port lifecycles and safely manage connections for both Host and Peripheral modes using `safeExecute` teardown blocks.
- **Diagnostics Logger:** Added a real-time, terminal-style DiagnosticsConsole UI and `DiagnosticsLoggerNotifier` to monitor high-speed incoming MIDI event streams directly on the device.
- **Accessibility Enhancements (Tooltips):** Added `Tooltip` widgets to icon-only buttons (App Settings and Refresh Devices) in the main and settings screens to provide screen reader labels and visual hover context.

### Changed
- **Batch Processing Optimization:** Refactored the `EventChannel` listener in `midi_service.dart` to decode incoming JNI batches into `List<MidiEvent>` and apply UI state changes exactly once per batch (`updateMultipleCCs`), preserving the 120Hz thermal optimizations.
- **Fader Interpolation Smoothing:** Reintroduced a lightweight, 45ms linear `animateTo` curve in `HybridTouchFader`. This smoothly bridges visual gaps caused by 20Hz DAW automation limits and Android OS `EAGAIN` buffer overflows, replacing the previous instant-snap logic.
- **Native Routing Handshake:** Refactored `MainActivity` and `PeripheralMidiService` to interact exclusively with the `MidiPortBackend` abstraction, severing hardcoded dependencies on Android OS classes for data flow.
- **Fader Rebuild Optimization:** Refined `HybridTouchFader` to eliminate internal `setState` calls on `AnimationController` ticks, wrapping only dynamic sub-elements in `AnimatedBuilder` to further reduce thermal load and CPU usage during high-frequency automation.

### Fixed
- **Diagnostics Background CPU Drain:** Upgraded the `DiagnosticsLoggerNotifier` to utilize Riverpod's `NotifierProvider.autoDispose` and `ref.onDispose`. The underlying MIDI stream subscription is now explicitly canceled when the debug modal is closed, preventing background string formatting and saving CPU cycles.
- **Native Android Hardening:** Added strict bounds checking and validation for raw MIDI byte arrays and haptic vibration parameters in `MainActivity.kt` to prevent local denial-of-service crashes from malformed hardware packets.

## [0.2.0] - 2026-03-26
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.5...v0.2.0)

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
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.0...v0.1.5)

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
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.0.0...v0.1.0)

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
[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.0.0...HEAD)

### Added
- Project initialized (documentation only).

[Unreleased]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.5...v0.2.0
[0.1.5]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.0...v0.1.5
[0.1.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.0.0...v0.1.0