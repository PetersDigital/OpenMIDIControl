# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

## [Unreleased]

[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.3.0...HEAD)

## [0.3.0] - 2026-05-02

[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.3...v0.3.0)

### Added

- **OMC Ecosystem Unification**: Standardized all preset and layout management under the `.omc` format.
  - Consolidated all file management into a unified "OMC ECOSYSTEM" section in settings.
  - Implemented full-preset export/import (pages + control state) with smart content detection to differentiate between full presets and single-page mappings.
  - Migrated internal snapshot storage to `.omc` with legacy `.json` migration support.
- **Dynamic Connection Island**: Introduced an animated, adaptive status indicator (using `SizeTransition` to eliminate layout jank) with double-tap-hold gesture guards.
- **Utility Grid Clear/Reset UX**: Disambiguated "Clear" (hard unbind) from "Reset" (factory restore). Controls visually reflect "UNASSIGNED" states with 0.3 opacity and interaction guards.
- **Device Offline Overlay**: Added a comprehensive offline overlay to gracefully handle MIDI disconnects during active sessions.
- **UI State Tracking**: Implemented button state tracking in `UiStateSinkNode` for better bidirectional feedback.
- **Typography Height Support**: Added explicit line height support to the `AppText` design system.
- **Side Panel Docking**: Implemented side-agnostic flyout system for settings and diagnostics in landscape orientations, supporting Left/Right docking.
- **Native Android Resilience**: Hardened `MidiSystemManager` with callback tracking per transport and physical disconnect handling.
- **Unified Control SSoT**: Consolidated all performance widgets to read from a single `LayoutState` source of truth.
- **Android Native UMP SDK Enforcement:** explicitly hardcoded `minSdk = 33`, `targetSdk = 36`, and `compileSdk = 36` directly in `app/android/app/build.gradle.kts` to strictly support native UMP.
- **Tactile Encoder Grips**: Added 24-spoke rotational grips to `EndlessEncoderWidget` for physical tactile feedback.
- **Audio dB Color Scheme**: Implemented dynamic LED ring coloring based on MIDI value thresholds (Green/Amber/Red).
- **Interactive Developer CLI**: Enhanced `run_app.py` with an interactive mode supporting device selection, release builds, and APK signing workflows.
- **Thermal Hardening**: Implemented visibility-aware resource management across all performance widgets. Background widgets now suspend MIDI listeners and tickers to eliminate CPU churn in `IndexedStack`.

### Changed

- **Consolidated Layout State**: Refactored Utility Grid controls (`Trigger`, `Toggle`) to read MIDI identifiers and channels directly from the central `LayoutState` source of truth.
- **Settings Screen Refactor**: Reorganized the Settings UI to prioritize Preset Management and the "OMC Ecosystem" workflow.
- **Native Android MIDI Resilience**: Hardened `MidiSystemManager` with `serviceScope` lifecycle management and Main-thread dispatching for hardware notifications.
- **Typography & Layout Hardening**:
  - Migrated orientation-driven transport visibility updates to `didChangeMetrics` to eradicate build-phase layout flickers.
  - Hardened the render tree with `const` constructors for static leaf nodes and `_GridButton`.
- **Three-Zone Header Layout**: Unified top bar layout into three zones (Left, Center, Right) across orientations, horizontally centering the connection status badge.
- **Control Config UX**: Standardized the action button row in `ControlConfigModal` by moving 'Cancel' to a top-right 'X' icon, grouping utility buttons (Clear, Reset) on the left, and positioning the primary 'Save' button on the right to eliminate overflow and improve ergonomics.
- **Batch Grid Management**: Added "Reset to Default" and "Clear Assignments" options to Utility and Drum grid settings menus, backed by new O(1) page-level state methods.
- **Transport Bar Normalization**: Removed redundant transport controls, normalized grid layout, and set transport to default visible in landscape to resolve overflow issues.
- **Performance Lock Relocation**: Moved the performance lock icon to the performance zone pagination bar for improved accessibility and proximity to the performance zone.
- **Docs Consolidation**: Updated architectural and design documentation to formally reflect `MidiRouter` (DAG), thermal hardening optimizations, and the UMP shift.
- **Flush & Flat UI System**: Migrated Drum and Utility grids to a zero-gap layout with unified 1.0px border widths.
- **High-Density Utility Grid**: Restored the 12-control high-density grid for standard Utility page layout.

### Fixed

- **Ticker Stability Guard**: Implemented `safeStartTicker` in `PerformanceTickerMixin` to prevent "already active" or "disposed" assertion crashes during rapid UI updates.
- **Grid Aspect Ratio Hardening**: Added division-by-zero guards and safe clamping to grid aspect ratio calculations.
- **Async Context Safety**: Hardened asynchronous operations (e.g., preset saves) with `context.mounted` guards and pre-captured `Navigator` instances.
- **Monotonic Timing Guards**: Replaced `DateTime.now()` with `Stopwatch` for all gesture, rate-limiting, and throttling logic to prevent NTP sync jumps.
- **64-bit Sign Extension**: Resolved bitwise corruption in the Android native layer with explicit 32-bit masking (`0xFFFFFFFFL`).
- **Bitwise & Math Safety**: Hardened UMP assembly with precedence grouping and added math guards for zero-width/inverted ranges in `RemapNode`.
- **Config Gesture Reliability**: Refactored `ConfigGestureWrapper` to use monotonic `Stopwatch` timing for reliable double-tap detection.
- **MidiRouter Stability**: Implemented strictly bounded object pools (`_MAX_POOL_SIZE = 256`) to prevent memory inflation during high-frequency routing bursts.
- **Timer Leak Fix**: Replaced runaway `Timer.periodic` with a self-canceling one-off timer in the worker isolate fallback to prevent idle CPU leaks.
- **Orientation Memory Leak**: Tracked orientation changes via `didChangeDependencies` to prevent redundant `addPostFrameCallback` registration during build cycles.
- **Riverpod-Based Lifecycle Observation**: Replaced `WidgetsBindingObserver` in `PerformanceTickerMixin` with `appLifecycleStateProvider` to reduce high-frequency notification overhead.
- **Zero-Copy Isolate Transport**: Implemented `TransferableTypedData` for background transport isolate to eliminate memory copying between the main thread and MIDI worker.
- **Native Object Pooling**: Introduced reusable `LongArray` buffer pools for native-to-Dart transport to eliminate GC pressure at 120Hz.
- **Native Event Suppression**: Added intelligent deduplication for USB state broadcasts and MIDI device discovery events in `MainActivity.kt`.

### Optimized

- **O(1) Grid Rendering**: Optimized rebuilds via index-based leaf subscriptions and decoupled render pulls to eliminate O(N) rebuilds during automation.
- **Blur Shadow GPU Optimization**: Replaced `_GridButton` `BlurStyle.inner` with `BlurStyle.normal` to avoid hardware-accelerated rendering bottlenecks and improve frame performance.
- **Zero-Allocation Processing**: Refactored `UiStateSinkNode` and `CcNotifier` to use primitive-indexed collections and pre-allocated address keys, eliminating GC churn.
- **120Hz Outgoing MIDI**: Increased outgoing MIDI transmission rate to 8ms (120Hz) for expressive widgets.
- **State Equality**: Implemented value equality on models using the `collection` package to prevent unnecessary widget rebuilds.
- **Fader Locking**: Faders now lock immediately on touch to prevent host fighting during local interaction and DAW automation collision.
- **Render Pull Decoupling**: Decoupled the UI Render Pull from the Data Pump for improved overall layout performance.
- **UMP Bitwise Parsing**: Hardened UMP bitwise parsing logic for improved cross-platform stability.
- **Diagnostics Buffer Versioning**: Replaced expensive `List.of()` array copies in `DiagnosticsLoggerNotifier` with a mutation counter and `ValueKey` rebuilding. Reduced memory churn from 20KB/sec to <1KB/sec.
- **Orientation-Aware Lifecycle**: Replaced `WidgetsBindingObserver` with `MediaQuery` listeners for orientation-driven transport visibility. Eliminated observer overhead and simplified lifecycle management.
- **Virtual MIDI Receiver Caching**: Promoted anonymous `MidiReceiver` in `VirtualMidiService` to a class-level property, eliminating per-call allocations.
- **Main Thread Dispatch Optimization**: Standardized on `Dispatchers.Main.immediate` in `MainActivity` to avoid redundant context switches when already on the main thread.
- **Lock-Free Flow Collection**: Replaced `@Synchronized` parser locks with a `Channel<ByteArray>` decoupling pattern in the native ingress pipeline. Reduced JNI contention and latency spikes.
- **Headless Compositor Guard**: Implemented `isPaused` lifecycle guard in `UiStateSinkNode` to prevent the Flutter compositor from waking up when the application is backgrounded.
- **Zero-Copy Performance Models**: Added `ControlState.raw` constructor to bypass defensive map copying during high-frequency MIDI automation.
- **Atomic Ring Buffer (Native)**: Replaced standard synchronized buffers in `MidiParser` with an `AtomicLong`-based SPSC (Single Producer Single Consumer) ring buffer for lock-free 32-bit event reconstruction.
- **Transport Isolate Decoupling**: Migrated native MIDI transport logic to a dedicated background isolate, reducing JNI overhead and preventing UI thread stuttering during high-density bursts.
- **Stream Throttling**: Implemented per-CC stream throttling in `ControlStateNotifier` to deduplicate redundant updates before they reach the UI bridge.
- **Zero-Copy Optimization**: Removed defensive `UnmodifiableMapView` wrapping in `ControlState.copyWith` to eliminate redundant object allocations in the hot-path.
- **Native Map Pre-allocation**: Standardized on pre-allocated object maps for Android USB events to avoid heap churn during device hot-plugging.

### Hardening & Resilience
- **Ticker Lifecycle Optimization**: Restriced ticker usage to active spring simulations in `HybridTouchFader`. Removed redundant tickers from `XYPad` and `EndlessEncoder`.
- **Render Object Caching**: Cached `Paint` objects and `Path` patterns in custom painters to eliminate per-frame allocations during high-frequency interaction.
- **Resource Cleanup**: Hardened `onDispose` lifecycle in all performance widgets to clear `StreamController` maps and prune stale `deadReceivers`.
- **Buffer Safety**: Implemented capacity-respecting bounds and wrap-around validation for lock-free native MIDI buffers.
- **Scheduling Guardrails**: Reset frame callback guards strictly inside scheduler callbacks to prevent frame drop spirals during thermal throttling.
- **Pre-allocated JNI Buffers**: Pre-allocated `Int64List` transit buffers in `MidiRouter` to eliminate per-event array allocations.
- **Debounced Interaction**: Standardized on 8ms (120Hz) batching for `setState` in the touch hot-path, preventing UI thread saturation.
- **Gesture System Decoupling**: Hardened `ConfigGestureWrapper` by decoupling interaction state from performance widgets. Implemented internal pan interception to prevent configuration timeouts from being triggered by performance gestures.
- **Render Isolation**: Strategic implementation of `RepaintBoundary` on high-complexity leaf nodes (e.g., `_GridButton`) to minimize GPU repaint costs during header updates.

## [0.2.3] - 2026-04-24

[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.2...v0.2.3)

### Added

- **MidiRouter Graph (Core Routing Engine)**: Implemented a centralized Directed Acyclic Graph (DAG) for deterministic N-to-N MIDI message routing and transformation.
  - **Cycle Detection**: `addEdge()` triggers `_canReach()` / `_dfsReach()` to perform depth-first search for reachability validation, preventing routing loops at add-time.
  - Queue-based work dispatch avoids deep recursion and ensures reproducible processing order.
  - Object pooling for work items reduces garbage collection pressure during high-frequency routing.
  - Batch processing of `List<MidiEvent>` amortizes routing overhead across multiple events.
- **Thermal & Performance Hardening**:
  - **Memory Churn Elimination**: Replaced `Pair<Long, Long>` boxing with packed `Long` primitives (32-bit UMP + 32-bit millisecond timestamp) in the native ingress pipeline, reducing 2MB/sec allocation churn.
  - **Buffer Reuse**: Reimplemented `MidiParser` and JNI bridge to reuse message buffers and dispatch coroutines, eliminating per-batch allocations.
  - **32-bit Millisecond Packing**: Formalized the native-to-Dart transport to use millisecond precision, extending 32-bit wrap-around to ~49 days while maintaining low-latency jitter correction.
- **Reliability & Bug Fixes**:
  - **UMP Word Alignment**: Fixed a critical bug in `MidiParser` where multi-word packets (MT 3, 4, 5) caused stream desynchronization during skipping.
  - **Primitive Backing**: Migrated `CcNotifier` and native CC limiters to primitive arrays and `Int64List`, reducing object overhead in the hot path.
  - **Packed Transport**: Implemented `Int64List` packed transport for MIDI CC batches over platform channels.
  - **Native Loop Prevention**: Implemented explicit `UsbMode` tracking in `MainActivity.kt` to disable virtual port dispatch in Peripheral mode, eliminating redundant routing and feedback loops.
  - **Service Decoupling**: Refactored the native layer into a persistent `MidiSystemManager` and decoupled `PeripheralMidiService` from `MainActivity` focus, ensuring MIDI transport remains active even when the app is in the background or loses focus.
  - **Thermal Priority Alignment**: Synchronized `AndroidManifest.xml` with `android:appCategory="audio"` and `android:isGame="false"` to signal to the OS scheduler that the application requires high-priority processing threads, effectively exempting MIDI transport from aggressive background throttling.
  - **O(N) Batch Deduplication**: Optimized UI-to-Native CC batching from $O(N^2)$ to $O(N)$ using backward iteration and `BitSet` tracking, reducing processing latency.
  - **Buffer Pool Hardening**: Implemented failure handling for native buffer reuse to prevent resource leaks and pipeline stalls during high-load scenarios.
  - **Optimization Pass**: Removed diagnostic heartbeats and increased internal event throttles to further reduce idle CPU load.
- **Connectivity & UI Refinement**:
  - **Two-Stage USB Status**: Added discrete "READY" (peripheral active) and "HOST-CONNECTED" (DAW traffic detected) status indicators.
  - **Unique Status Identity**: Refactored the status banner with unique labels and color tokens for all 7 MIDI states (e.g., "USB HOST DETECTED" vs "USB HOST ACTIVE").
  - **Manufacturer-Agnostic Detection**: Broadened peripheral fingerprinting to reliably identify the Android USB host port across Pixel, Samsung, and generic OEM devices.
  - **Unified Discovery**: Merged UMP and byte-stream MIDI discovery logic for consistent device enumeration across all Android versions.
  - **Edge-Triggered USB Handling**: Implemented debouncing and edge-triggering for USB state broadcasts to prevent thermal spikes during hotplugging.
  - **Stateless UI Colors**: Replaced expensive status glow animations with a unified, high-contrast color palette across the main console and settings screens.
- **TransformerNode Abstraction**: Introduced abstract base class for custom MIDI transformation logic.
  - Supports filtering (velocity/channel-based), remapping (CC value scaling, message type conversion), and stream splitting (multi-path routing).
  - Clean interface enables future protocol adapters and device-specific routers.
- **Routing Engine Tests**: Comprehensive test suite covering DAG construction, cycle detection, batch routing, and error recovery.

## [0.2.2] - 2026-04-15

[Full Changelog](https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.1...v0.2.2)

### Added

- **MidiParser Extraction**: Extracted UMP reconstruction logic from `MainActivity.kt` into isolated, testable `MidiParser.kt` static object for comprehensive unit testing without Android Service mocks.
- **UMP Group Preservation**: Multi-cable UMP group data is now preserved during reconstruction (not discarded), enabling future MIDI 2.0 multi-group support.
- **Enhanced isUmp Detection**: Improved heuristic detection using MT (Message Type) validation — checks for MT=0x1 (System) or MT=0x2 (MIDI 1.0 Channel Voice) to prevent false positives from legacy byte streams.
- **Automated Test Suite** (10+ test files):
  - Kotlin native tests: `MidiParserTest.kt` (6 test scenarios: UMP heuristic, legacy fallback, 32-bit reconstruction, spam filtering, echo suppression, batching bounds)
  - Dart unit tests: `midi_event_test.dart`, `midi_models_test.dart`, `control_state_test.dart`, `diagnostics_test.dart`, `midi_settings_state_test.dart`
  - Dart widget tests: `settings_screen_test.dart`, `midi_settings_screen_test.dart`, `open_midi_screen_test.dart`
  - Integration tests: `midi_pipeline_integration_test.dart` (EventChannel multiplexing, 10K event stress test)
- **Comprehensive Test Documentation**: Added [TESTING.md](TESTING.md) with complete test suite architecture, execution instructions, and conceptual fuzzing test design.
- Enforce minSdkVersion 33 and decouple from Flutter SDK
- **Device Refresh Debouncing**: Added `Timer`-based debouncing (300ms) to `ConnectedMidiDeviceNotifier` to prevent redundant `midiDevicesProvider` invalidations during rapid USB state changes.
- **Iterative Fast-Reject Spam Filtering**: `MidiParser` now iteratively fast-rejects real-time spam arrays (0xF8, 0xFE) before expensive 32-bit reconstruction, reducing CPU overhead during clock saturation.
- **Symmetric Callback Unregistration**: Fixed `teardownMidiDeviceCallback` to ensure symmetric callback unregistration, preventing callback leaks and potential double-unregister crashes.

### Changed

- **Branding**: Updated internal references from "PetersDigital" to "Peters Digital" for corporate consistency.
- **Standardize package identifiers**: Renamed Android/iOS package to lowercase (`com.PetersDigital.OpenMIDIControl` → `com.petersdigital.openmidicontrol`) to follow Android conventions.
- **Update technical identifiers**: Updated AGENTS.md and README.md to reference the new lowercase package name.
- **Hardware Monitoring**: Updated documentation in `AGENTS.md` with enhanced logging tags and platform-specific commands (PowerShell).
- **Build Configuration**: Added a version sync tracking warning comment to `pubspec.yaml` to ensure `.version` and `pubspec.yaml` remain synchronized.
- **Centralized Event Parsing:** The `MidiService` handles `EventChannel` decoding exactly once per native polling cycle, distributing a typed `List<MidiEvent>` (unpacked from packed primitives) to all observers to ensure atomic state transitions and 0% redundant parsing.
- **Primitive Packing & Buffer Reuse**: Native-to-Dart transport packs 32-bit UMP and 32-bit millisecond timestamps into single `Long` primitives and reuses pre-allocated `ByteArray` buffers to eliminate object allocation churn (2MB/sec reduction). Millisecond precision is used to extend the 32-bit timestamp wrap-around to ~49 days.
- **Lazy-Init & Snapshotting:** `UiStateSinkNode` and `CcNotifier` use lazy-init `Map` allocation and reusable snapshots for batch updates, minimizing garbage collection during automation bursts.
- **Broadcast Stream Simplification**: Removed redundant `.asBroadcastStream()` calls from `_rawStream`, `midiEventsStream`, and `systemEventsStream` — `receiveBroadcastStream()` already provides broadcast semantics, eliminating duplicate subscription overhead.
- **Logging Overhead Removal**: Stripped `isDebug` parameter from hot-path MIDI parsing, removing conditional branch overhead from the critical processing pipeline.
- **Unused State Cleanup**: Removed unused `currentUsbMode` variable from `setUsbMode` handler.

### Security

- **Dual-Licensing Model**: Established GPL-3.0-or-later / LicenseRef-Commercial dual-licensing with comprehensive documentation (LICENSE, LICENSE-COMMERCIAL, COPYRIGHT, NOTICE, docs/LICENSING.md, docs/security/).
- **License Headers**: Added copyright and SPDX license identifiers to all Kotlin (6 files) and Dart (13 files) source files.

### CI/CD Infrastructure

- **Version Tracking**: Added a standalone `.version` file in the root directory to permanently decouple GitHub Actions beta/RC prerelease sequence generation from the `pubspec.yaml` version.
- **Automated Dependency Updates**: Dependabot configuration now runs on a weekly cadence for GitHub Actions (`/`), npm (`/`), and Flutter pub dependencies (`/app`), targets the `dev` branch, uses dedicated `security-updates` groups (`applies-to: security-updates`), and enforces a pub open-PR limit of 5.
- **YAML Linting & Validation Scope**: Integrated yamllint with custom rules (document-start, line-length 150, trailing-spaces, unix newlines) and actionlint for schema validation with Dependabot PR exemptions. Validation scope enforces `.github/**`-only checks for `validate_auto_yaml.yml` (excluding markdown/preview-only changes), with push runs on `dev` and PR gates on `dev`, `release/**`, and `hotfix/**`.
- **License Header Enforcement**: Automated CI check (`validate_auto_license.yml`) validating SPDX license headers across all source files (Dart, Kotlin, PowerShell, YAML, Python, Shell), with push runs on `dev` and PR gates on `dev`, `release/**`, and `hotfix/**`.
- **Main Promotion Guard**: Added a `pre-main-sync` gate in `ci_auto_main.yml` to ensure `beta`/`rc` release branch heads are already present in `dev` before merging into `main`.
- **Commit Message Validation**: Added commitlint workflow (`validate_pr_commitlint.yml`) and Husky pre-commit hook enforcing Conventional Commits format, with PR gates on `dev`, `release/**`, and `hotfix/**` plus cancel-in-progress PR concurrency.
- **Promotion Branch De-dup Pass**: Removed redundant validation/CI runs on promotion branches (`beta`, `rc`, `main`) where quality gates already pass upstream on `dev`, while retaining required release pipelines and the `pre-main-sync` integrity gate.
- **CI/CD Optimization**: Removed `check-build-markers` and `check-release-markers` runner jobs from `cd_auto_dev.yml` and `cd_auto_beta.yml`. Marker detection now uses native GitHub `if:` conditions at zero runner cost. `analyze-and-test` always runs on push for code quality visibility. APK/release builds trigger automatically on their respective branch pushes without manual markers.
- **Stale Issue Management**: Automated weekly cleanup of inactive issues/PRs (60-day threshold, 14-day grace, bug/security exemptions) via `ops_schedule_stale.yml`.
- **Supply Chain Security**: Implemented Cosign keyless signing with GitHub OIDC, SLSA provenance attestation, and GPG tag verification for production releases.
- **Telegram Notifications**: Centralized notification system for CI failures, dev builds, beta releases, and production deployments via the reusable `notify-telegram` composite action.
  - Templates use a standardized enterprise message vocabulary and emoji map with linked Repository, Branch/Tag, Commit, and Workflow URLs, canonical section labels (`🧭 Actions`, `🛠 Diagnostics`, `📊 Signals`, `🛡 Trust Signals`), and consistent status/environment/security markers across both runtime output and HTML/CSS preview artifacts.
  - Replaced embedded Python JSON parsing with a lightweight pure-bash parser (`sed`-based extraction), removing the `python3` runtime dependency for minimal runners.
  - Added dedicated HTML/CSS preview scenario for the truncation notice path (`telegram-11-truncated-message.html`) to document limit-safe rendering behavior.
- **Git Configuration**: Added `.gitattributes` to enforce LF line endings across platforms with CRLF exemption for PowerShell scripts.
- **YAML Cleanup**: Added copyright and SPDX headers to all YAML configuration files (`.gemini/config.yaml`, `analysis_options.yaml`, `pubspec.yaml`) with document start markers.
- **Modular Workflow Architecture**: Replaced monolithic workflows (`dev.yml`, `release.yml`) with 11 reusable composite actions:

    | Composite Action | Purpose |
    | ------------------ | -------- |
    | `flutter-ci-core` | Shared Flutter setup, analysis, testing |
    | `cosign-sign-verify` | Keyless artifact signing with OIDC |
    | `provenance-attestation` | SLSA provenance generation |
    | `flutter-build-android` | Android APK builds with keystore |
    | `flutter-build-windows` | Windows desktop builds |
    | `download-and-prepare-artifacts` | Artifact collection and merging |
    | `generate-prerelease-tag` | Deterministic beta/RC tag generation from `pubspec.yaml` + `.version` |
    | `generate-release-notes` | CHANGELOG parsing for releases |
    | `notify-telegram` | Telegram build/release notifications with standardized enterprise templates |
    | `prepare-release-assets` | Shared asset collection for releases |
    | `release-tag-validation` | Release gate validation |

- **Workflow Naming Convention**: Renamed all 13 workflow files to `type_trigger_tier.yml` pattern:

    | Workflow | Trigger | Purpose |
    | ---------- | --------- | --------- |
    | `cd_auto_dev.yml` | Push to `dev` | Automated dev builds |
    | `cd_auto_beta.yml` | Push to `beta` | Automated beta prerelease builds (public prerelease) |
    | `cd_auto_rc.yml` | Push to `rc` | Automated release candidate builds (public prerelease) |
    | `cd_auto_prod.yml` | Push to SemVer tag | Automated production releases |
    | `cd_man_prod.yml` | Manual dispatch | Manual production rebuilds |
    | `cd_man_hotfix.yml` | Push to `v*-patch.*` tag | Emergency hotfix deployments |
    | `cd_man_retro.yml` | Manual dispatch | Historical release rebuilds |
    | `ci_auto_main.yml` | PR to `main` | Main promotion sync guard (`pre-main-sync`) |
    | `ci_auto_feature.yml` | Push to feature branches | Feature branch CI validation |
    | `validate_auto_yaml.yml` | `.github/**` changes | YAML/workflow syntax validation |
    | `validate_auto_license.yml` | Push to `dev`, PR to `dev`/`release/**`/`hotfix/**` | License header enforcement |
    | `validate_pr_commitlint.yml` | Pull requests | Conventional commits validation |
    | `ops_schedule_stale.yml` | Weekly cron | Stale issue/PR management |

- **RC Release Visibility**: `cd_auto_rc.yml` no longer creates draft releases — RCs are immediately visible as public prereleases on GitHub Releases page.
- **Hotfix Windows Build Fix**: `cd_man_hotfix.yml` now runs Windows builds in a separate `build-hotfix-windows` job on `windows-latest` instead of inlining them in the Ubuntu-based `build-hotfix` job, which previously failed because `flutter build windows` cannot cross-compile on Linux.
- **CI Main Workflow Simplification**: `ci_auto_main.yml` was reduced to a lightweight promotion guard workflow (`pre-main-sync`) to avoid duplicate post-promotion CI runs on `main`.
- **Feature Branch RC Exclusion**: `ci_auto_feature.yml` now excludes the `rc` branch to prevent double-triggering alongside `cd_auto_rc.yml`.
- **Provenance-Aware Notifications**: `notify-telegram` in `cd_auto_beta.yml` and `cd_auto_rc.yml` now waits for `provenance` job completion before firing.
- **Beta/RC Terminology Consistency**: Beta release notes now correctly say "pre-release build for testing" (not "release candidate"). Release name in `cd_auto_beta.yml` corrected to "Beta Release".

### Development Tools

- Add interactive conventional commit helper (`commit.py`) to enforce valid commit structures prior to push
- Add cross-platform Python Flutter launcher
- Remove legacy PowerShell launcher scripts (`run_debug.ps1`, `run_release.ps1`) in favor of Python equivalents
- Add automated license header management tools
- Add workflow validator script with auto-fix
- Add automated CHANGELOG.md generator from git history
- Add unit tests for release notes generation
- Add GitHub Actions cleanup utilities

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

[Unreleased]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.5...v0.2.0
[0.1.5]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.1.0...v0.1.5
[0.1.0]: https://github.com/PetersDigital/OpenMIDIControl/compare/v0.0.0...v0.1.0
