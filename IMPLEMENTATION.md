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
- **Hybrid Touch Engine**: Finalized the touch capture model so touch-anywhere, catch-up, and hybrid fader behavior stay consistent across direct UI gestures and MIDI feedback.
- **PerformanceTickerMixin**: Centralized lifecycle management for interactive widgets with managed disposal and background recovery.
  - Added **safeStartTicker** guards to provide a centralized, guarded way to start tickers, preventing "already active" or "disposed" assertion crashes.
- **Utility Grid Clear/Reset UX**: Disambiguated hard unbind from factory restore. Controls visually reflect "UNASSIGNED" states with interaction guards.
- **Side Panel Docking**: Implemented a side-agnostic flyout system for landscape orientations, supporting Left/Right docking.
- **Layout Hardening**: Eradicated build-phase orientation mutations; migrated to `didChangeMetrics`.
- **Unified Layout State**: Consolidated page, control, and persistence state behind `LayoutState` so the performance surface and settings screen consume the same source of truth.
- **Performance Architecture**: Standardized index-based subscriptions, lazy state updates, and visibility-aware disposal so layout rendering remains deterministic under automation load.
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
- **Batch Reset/Clear API**: Implemented `resetPage` and `clearPage` in `LayoutStateNotifier` to provide atomic, high-performance configuration management for entire layout panels.
- **Developer Experience CLI**: Enhanced `run_app.py` with an interactive mode for device management and release workflows.
- **Riverpod-Based Lifecycle Bridge**: Migrated `PerformanceTickerMixin` to use `appLifecycleStateProvider` via Riverpod `listenManual`, consolidating lifecycle management and eliminating native observer overhead.
- **Background Transport Isolate**: Implemented a dedicated worker isolate for native MIDI transport, utilizing `TransferableTypedData` for zero-copy communication to eliminate UI thread saturation.
- **Native Object Pooling**: Introduced reusable `LongArray` pools for native-to-Dart transit to eliminate garbage collection churn during automation bursts.
- **Orientation Memory Leak Fix**: Tracked orientation changes via `didChangeDependencies` to prevent redundant `addPostFrameCallback` registration.

### ✅ v0.4.0 – Dynamic Modular Layout Engine (Foundation)

- **Dynamic Page Management UI**: Interactive add/rename/reorder/delete of layout pages at runtime.
- **PageType Enum**: Formal `PageType` enum on `LayoutPage` for type-safe routing.
- **Dynamic Page Context Routing**: Performance zone and grid panels route state via `pageId`, not index.
- **ID Collision Protection**: Random suffix appended to all auto-generated page and control IDs.
- **Empty Layout Safety**: Full support for zero-page configurations with UI guards.
- **Page Name Validation**: In-dialog validation for empty names.
- **Ticker & Throttle Fixes**: Dedicated per-fader outgoing throttle `Stopwatch`; `safeStartTicker` assertion guard.
- **Min SDK Bump**: Flutter SDK constraint raised to `>=3.41.0`.

### ✅ v0.4.1 – Layout Engine Hardening & Performance

- **Undo Page Deletion**: Added a snackbar undo action for accidental page deletes.
- **Layout Reset**: Interactive reset-to-default-layout button in page management settings.
- **Pagination Scaling**: Support for scrollable tab bar when layouts exceed 4 pages.
- **Extreme UI Performance**: Leaf-level Riverpod optimization, repaint boundaries for faders/buttons/lists, and decoupled settings/compositor rebuild paths.
- **Hardening & Fixes**: Fixed connection lost dismiss reference leaks, reorderable list layout bugs, and GPG/CI pipeline upgrades.

### ✅ v0.4.2 – Editor Mode

- **Drag-and-Drop Placement**: Interactive widget positioning within the layout grid with boundary snapping.
- **Resizing**: Corner drag handle and two-finger pinch-to-resize support.
- **Widget Palette**: Sliding control palette panel for adding new widgets from a catalog.
- **In-Editor Control Config**: Quick access settings handle for configuring controls directly in edit mode.
- **Undo Control Deletion**: Interactive SnackBar undo action to restore accidentally deleted controls.

### ✅ v0.4.3 – Persistence & Marketplace (Local Foundation)

- **JSON Schema Versioning & Migration**: `LayoutDocument` envelope (`schemaVersion: 1`), `LayoutManifest` metadata model, and extensible `LayoutSchemaMigrator` pipeline for v0→v1 upgrades of legacy layouts and `PresetSnapshot` files.
- **Manifest Metadata UI**: `LayoutDocumentNotifier` and `ManifestEditorModal` in `FilesTab` for editing layout name, author, version, description, and comma-separated tags.
- **Local Storage Persistence**: `LayoutStorageManager` saving `.omc` layout documents under `<app_documents>/layouts/{id}.omc`, `SharedPreferences` active document tracking, 1000ms debounced auto-save, lifecycle background flush, startup restoration, and `LayoutLibraryModal` for browsing/switching/deleting saved layouts.
- **Hardened Import / Export**: Envelope-wrapped `.omc` sharing and validated imports with automatic legacy migration and SnackBar feedback.

### ✅ v0.4.4 – Modular Engine Core & MCU Prerequisites

**Goal:** Establish the polymorphic message schema, global header transport mappings, stampable page templates, and per-widget styling so `v0.5.x` (MCU/HUI & MIDI 2.0) builds on a single clean schema without duplicate migrations.

#### Phase 1 – `ActionPayload` Polymorphism & Schema Migration (`v1 → v2`)

- **Models (`app/lib/core/models/action_payload.dart`, `layout_models.dart`):**
  - Introduce an immutable polymorphic `ActionPayload` union/sealed model supporting:
    - `CcPayload` (7-bit CC, channel `0..15`, CC `0..127`, optional 14-bit / high-res flag)
    - `NotePayload` (channel `0..15`, note `0..127`, velocity curve/mode)
    - `PitchBendPayload` (channel `0..15`, 14-bit `0..16383`)
    - `RelativeCcPayload` (channel `0..15`, CC `0..127`, encoding: `signedBit` / `twosComplement` / `binaryOffset`)
    - `McuActionPayload` (placeholder/enum target: fader strip `0..8`, vPot `0..7`, channel button, transport action — wired to protocol engine in `v0.5.0`)
  - Attach optional `ActionPayload? payload` (and secondary payload for XY Y-axis) to `LayoutControl` while retaining backward-compatible getters.
- **Migration (`app/lib/core/models/layout_schema_migrator.dart`, `layout_document.dart`):**
  - Bump `LayoutDocument.currentSchemaVersion` from `1` → `2`.
  - Add deterministic `v1 → v2` migration translating existing `defaultCc` / `secondaryCc` / `channel` / `ControlType` fields into `ActionPayload` instances with zero data loss for existing `.omc` files.
- **Inspector (`app/lib/ui/widgets/control_config_modal.dart`):**
  - Add message-type selector (CC / Note / Pitch Bend / Relative CC) with type-specific inputs.

#### Phase 2 – Header Transport Grid Wiring & Global Assignments

- **Global Persistence (`app/lib/ui/header_transport_state.dart`):**
  - Define 9 fixed `HeaderTransportRole` slots (`rewind`, `up`, `record`, `left`, `stop`, `right`, `fastForward`, `down`, `play`), kept separate from MCU `TransportAction`.
  - Persist `{role.name: ActionPayload.toJson()}` globally in `SharedPreferences` via `headerTransportMappingsProvider`, accepting CC, Note, or Unassigned (all default to Unassigned on fresh installs/upgrades and remain untouched by layout imports).
- **Header 3×3 Grid Interaction (`app/lib/ui/open_midi_screen.dart`):**
  - Wire the 9 roles onto `_GridButton` across both portrait and landscape `MidiTransportGrid` variants while preserving existing glyphs, spacing, sizing, and arrangement.
  - Reuse `MidiGate.transport()` for momentary sends, subscribe assigned cells to `ControlState.buttonStates` for lit host feedback, and release held assignments on pointer up, cancellation, rebinding, grid closure, or app backgrounding.
- **Settings Editor (`app/lib/ui/settings/tabs/performance_tab.dart`):**
  - Add a **Transport Assignments** section under **Settings → Performance** using `MidiActionDraft(allowUnassigned: true, ccAndNoteOnly: true)` and `MidiActionFields`, validating and awaiting persistence on save so performance-mode grid taps only transmit MIDI.
- **Legacy Layout Compatibility (`app/lib/core/models/layout_models.dart`, `layout_schema_migrator.dart`):**
  - Skip legacy `transportButton` entries during `v1`/`v2` page decoding while preserving the rest of the page and leaving global header mappings untouched.

#### Phase 3 – Factory Page Template Gallery ("Stamp Logic")

- **Templates (`app/lib/core/models/page_templates.dart`, `app/lib/ui/editor/widget_palette_panel.dart`):**
  - Define immutable factory page templates (`Factory Fader Bank`, `4x4 Velocity Drum Grid`, `XY + Encoders`, and `8-Track Mixer Stub` / `8-CH MIXER`).
  - Add a **Templates** tab inside `WidgetPalettePanel` and **Add Page** template selection (`PageManagementSection`) to stamp complete pages or template groups using existing grid bounds/collision checks, compact 1-column mixer strip scaling, and post-frame tab strip scrolling.

#### Phase 4 – `WidgetStyle` Visual Sovereignty

- **Model & UI (`app/lib/core/models/widget_style.dart`, `control_config_modal.dart`):**
  - Add immutable `WidgetStyle` to `LayoutControl` (`accentColorHex`, `fontFamily` in `['Inter', 'Space Grotesk', 'DSEG7Modern']`, `showLabel`, `showNumericReadout`), omitting default values from `.omc` JSON.
  - Add a curated 12-color high-contrast palette picker (aligned with `DESIGN.md`), font picker, and visibility toggles in `ControlConfigModal` (`APPEARANCE`).
  - Wire `WidgetStyle` into `HybridTouchFader`, `HybridXYPad`, `VelocityDrumPad`, `EndlessEncoderWidget`, `Trigger`, and `Toggle` (`midi_buttons.dart`) via `ControlWidgetFactory` without introducing extra widget rebuilds.

#### Verification (`v0.4.4`)

- Dart unit & widget tests: `action_payload_test.dart`, `layout_schema_migrator_test.dart` (`v0 → v1 → v2` & `v1 → v2` round-trips), `header_transport_state_test.dart`, `header_transport_grid_test.dart`, `performance_tab_transport_test.dart`, `page_templates_test.dart`, `page_templates_ui_test.dart`, `widget_style_test.dart`, `widget_style_controls_test.dart`, `control_config_modal_style_test.dart`.
- Full gate: `flutter analyze --fatal-infos`, `flutter test`, `.\gradlew.bat :app:testDebugUnitTest`, and on-device `.omc` export/import, header transport, template stamping, and `WidgetStyle` cold-restart persistence verification.

---

### ✅ v0.4.5 – Visual Sovereignty & Expressive Pads

**Goal:** Complete the remaining modular surface controls (`Global UI Scaling`, `AftertouchPad`, `LatchPad`) before starting protocol-layer work.

#### Phase 1 – Global UI Scaling (Zoom & Pan)

- **State & Settings (`app/lib/ui/global_ui_scale_state.dart`, `app/lib/ui/settings/tabs/performance_tab.dart`, `app/lib/ui/widgets/performance_grid_viewport.dart`, `open_midi_screen.dart`):**
  - Persist `globalUiScale` (`0.75..1.35`, default `1.0`) in `SharedPreferences` via `globalUiScaleProvider` (`GlobalUiScaleNotifier`).
  - Wrap the performance grid surface in `PerformanceGridViewport` with a toggleable **Pan grid** button beside the page tabs when scale `> 1.0`, ensuring pointer hit-testing and multi-touch coordinate mapping stay exact (plus scaled Edit Mode drag compensation in `EditorControlWrapper`).

#### Phase 2 – `AftertouchPad` (Expressive Y-Axis Pressure / MPE-Lite)

- **Widget (`app/lib/ui/widgets/aftertouch_pad.dart`, `control_widget_factory.dart`):**
  - Add `ControlType.aftertouchPad`: emits `Note On` on touch-down (velocity from touch position/curve or fixed) and streams a configurable expression CC (default `CC 74`) from vertical `PointerMove` delta while held, emitting `Note Off` on pointer-up/cancel, reassignment, page switch, backgrounding, or disposal.
  - Enforce monotonic `Stopwatch` rate-limiting (`100Hz` / `10ms` window), `RepaintBoundary` + `ValueNotifier` isolation, and 30% unassigned opacity.

#### Phase 3 – `LatchPad` (Timed Smart Trigger)

- **Widget (`app/lib/ui/widgets/latch_pad.dart`, `control_widget_factory.dart`):**
  - Add `ControlType.latchPad`: triggers active state (`127` / `Note On`) for a configurable duration (`0.5 s – 16.0 s`, `latchDurationMs`) with a `CustomPainter` countdown ring overlay (`RepaintBoundary` + `PerformanceTickerMixin` + `ValueNotifier`), tap-to-cancel toggling, and 30% unassigned opacity.
  - **Safety Guarantee:** Cancel active timers and send clean release (`0` / `Note Off`) on page switch, reassignment, widget disposal, or app backgrounding via `appLifecycleStateProvider`.

#### Verification (`v0.4.5`)

- Dart unit & widget tests: `global_ui_scale_state_test.dart`, `performance_grid_scale_test.dart`, `performance_tab_scale_test.dart`, `aftertouch_pad_test.dart`, `latch_pad_test.dart`, `editor_control_wrapper_polish_test.dart`, `layout_document_test.dart`, `page_templates_ui_test.dart`, and `control_config_modal_test.dart`.
- Full gate & HITL (`R5CX14HSQTT` + `midi endpoint monitor`): `dart format`, `flutter analyze --fatal-infos`, `flutter test` (`291/291`), `:app:testDebugUnitTest`, cold-start `globalUiScale` persistence, live `AftertouchPad` (`Note On → CC 74 stream → Note Off`), `LatchPad` auto-expiry & page-swap release, non-overlapping narrow editor handles, and `UNDO` `SnackBar` auto-dismissal.

---

### ⏳ v0.5.x – The MCU / HUI Protocol Series

> **Platform & Standards Context (see `REFERENCES.md` & `references/cubase/README.md`):**
>
> - Android API 33+ enumerates byte-stream and UMP transports separately. The opened port determines framing. Local virtual UMP services use `MidiUmpDeviceService` on API 35+. [Android MIDI API](https://developer.android.com/reference/android/media/midi/package-summary)
> - On the Galaxy S24 Ultra running Android 17 (API 37), the direct USB cable to Cubase currently provides MIDI 1.0. Windows confirmed Cubase 16 had the Samsung byte-stream endpoint open. Test native MIDI 2.0 separately with the Galaxy hosting a compatible USB UMP device or with an Android virtual UMP peer.
> - Windows MIDI Services can translate for legacy hardware. Record the native data format, actual protocol and direction of each test. Measure delivery timing on the test route. [Microsoft translation guide](https://microsoft.github.io/MIDI/kb/data-translation/)
> - v0.5.0 uses Channel Voice for control. Review manufacturer identity and the permitted uses of special IDs when scoping discovery in v0.5.1. [MIDI Association ID policy](https://midi.org/new-midi-association-sysex-id-policies-as-of-oct-15-2025)

---

#### ⏳ Current Focus: v0.5.0 (Core Logic): Basic MCU Protocol Mapping & Native UMP High-Resolution Control

**Goal:** Deliver 14-bit MCU faders, relative V-Pots, strip and transport buttons, host feedback and native high-resolution UMP transport.

Gate 0 passed on Cubase 15.0.40.324 and 16.0.5.174 per bench verification. Begin v0.5.0 Phase 1. Keep handshake work in v0.5.1. MCU ingress must decode MT 2 and MT 4 bend, Note and CC feedback, including channel 16 time digits. Use the [series implementation and verification plan](docs/V0.5.x-V0.6.x_IMPLEMENTATION.md) for the released-code audit, wire vectors, commit boundaries and hardware criteria. The local [reference index](REFERENCES.md) and [bundled Cubase mappings](references/cubase/README.md) provide background. For the November 2026 bench, record the installed Windows service, Preview 14 components, native endpoint format, Cubase build and script revision separately. Cubase 16 adds Windows MIDI Services and independently updatable factory scripts. [Microsoft Preview 14](https://github.com/microsoft/MIDI/releases/tag/inbox-preview-14) · [Steinberg Cubase 16 release notes](https://www.steinberg.net/cubase/release-notes/16/)

##### Phase 1 – Native Kotlin & Core Dart High-Res UMP Foundation

- **Pitch Bend Echo Suppression (`app/android/.../MidiParser.kt`):**
  - *(Baseline channel-keyed `0xE0` normalization shipped in `v0.4.4`; verify 14-bit high-res round-trip coverage here.)* Normalize suppression key to `data1 = 0` whenever `(status and 0xF0) == 0xE0` so changing LSB ticks never bypass bidirectional echo suppression.
- **14-Bit Pitch Bend & 64-Bit `MT=0x4` UMP Pipeline (`MidiParser.kt`, `UmpPacket.kt`, `MainActivity.kt`, `midi_event.dart`):**
  - Add `buildUmpPitchBendPacket(channel, value14Bit, group)` (`0x2<g>E<ch><lsb><msb>`) and `MidiEvent.pitchBendValue14Bit` (`(data2 << 7) | data1`, range `0..16383`).
  - Extend `MidiEvent` (optional `int umpWord2 = 0`) and `MidiParser.kt` / `IncomingEventsBuffer` to preserve **64-bit MIDI 2.0 Channel Voice (`MT=0x4`)** packets (`word0` header + `word1` 32-bit value) instead of dropping word 2, with deterministic down-translation to `MT=0x2` (14-bit Pitch Bend / 7-bit CC) when targeting MIDI 1.0 endpoints.
- **High-Res State (`control_state.dart`, `ui_state_sink_node.dart`, `native_transport_sink_node.dart`):**
  - Retain 14-bit MCU bend and unsigned 32-bit native bend/CC values through immutable state. Scope feedback to the selected port, group and channel.
  - Pre-allocate precision-appropriate typed buffers with dirty masks in `UiStateSinkNode` and support two-word events in both paths of `NativeTransportSinkNode`.

##### Phase 2 – Pure-Dart MCU Core Protocol Module (`app/lib/core/protocol/mcu/`)

- **`mcu_constants.dart` — Standard Mackie Control Universal Map:**
  - **Faders (14-bit Pitch Bend):** Ch `0..7` (`0xE0..0xE7`) = Tracks 1–8. Ch `8` (`0xE8`) = Master. Range `0..16383`. Verify the host's unity-gain position in Cubase.
  - **Fader Touch (Ch 1 Notes):** `0x68..0x6F` (notes `104..111`) = Tracks 1–8; `0x70` (`112`) = Master (`vel 127` on touch-down, `vel 0` on release — required for DAW Touch/Latch automation).
  - **V-Pots (Ch 1 Relative CC):** `CC 16..23` (`0x10..0x17`) using MCU signed-magnitude encoding (`0x01..0x3F` CW steps, `0x41..0x7F` CCW steps).
  - **Channel Strip Buttons (Ch 1 Notes, `vel 127`/`0`):**
    - Rec Arm: `0x00..0x07` (`0..7`)
    - Solo: `0x08..0x0F` (`8..15`)
    - Mute: `0x10..0x17` (`16..23`)
    - Select: `0x18..0x1F` (`24..31`)
    - V-Pot Press: `0x20..0x27` (`32..39`)
  - **Navigation & Transport (Ch 1 Notes):**
    - Bank Left / Right: `0x2E` (`46`) / `0x2F` (`47`)
    - Channel Left / Right: `0x30` (`48`) / `0x31` (`49`)
    - Cycle (`0x56` / `86`), Rewind (`0x5B` / `91`), FF (`0x5C` / `92`), Stop (`0x5D` / `93`), Play (`0x5E` / `94`), Record (`0x5F` / `95`), Cursor Up/Down/Left/Right (`0x60..0x63` / `96..99`).
- **`mcu_codec.dart` & `mcu_protocol_node.dart` (`TransformerNode`):**
  - Pure normalization (`0.0..1.0` ↔ 14-bit `0..16383` & 32-bit UMP), MCU relative V-Pot delta encoding, and DAW feedback decoding (14-bit fader automation + Note LED states `0`=off, `1`=flash, `127`=on).
  - Implement `McuProtocolNode` as a `MidiRouter` `TransformerNode` so UI widgets remain transport-agnostic.

##### Phase 3 – Widget Wiring & Built-In MCU Starter Template

- **`HybridTouchFader`:** Support 14-bit Pitch Bend / 32-bit UMP smooth rendering without 7-bit stair-stepping; emit Fader Touch `Note On` on pointer-down and `Note Off` on pointer-up/cancel in MCU mode; preserve Jump/Hybrid/Catch-up on incoming 14-bit DAW automation.
- **`EndlessEncoderWidget`:** Support MCU `RelativeSignedBit` V-Pot output (`CC 16..23`).
- **Header Transport Grid & Strip Buttons:** Automatically bind the 9 `HeaderTransportRole` cells in MCU mode to MCU Transport (`0x5B–0x5F`) and Cursor (`0x60–0x63`) Ch 1 Notes alongside channel strip MCU Note buttons with live DAW LED feedback, while keeping custom Generic MIDI `SharedPreferences` assignments intact when switching back.
- **Starter Template:** Add **"MCU 8-Track Mixer"** template (8 faders + Master + Rec/Solo/Mute/Select + V-Pots, paired with the global header transport grid) to the v0.4.4 Template Gallery.

##### Verification (`v0.5.0`)

- Kotlin JUnit (`MidiParserTest.kt`, `UmpPacketTest.kt`): 14-bit Pitch Bend parsing, `0xE0` echo-suppression fix, `MT=0x4` 64-bit word preservation + down-translation.
- Dart unit/widget tests: `mcu_codec_test.dart`, `mcu_protocol_node_test.dart`, `hybrid_touch_fader` 14-bit & Fader Touch tests, `endless_encoder` relative V-Pot tests.
- HITL (`R5CX14HSQTT` + `midi.exe`): capture outbound `0x20E0....` (14-bit fader) + `0x2090687F`/`0x20806800` (Fader Touch) + `0x20B01001`/`0x20B01041` (V-Pot) via `midi endpoint monitor`; inject 14-bit automation & LED feedback via `midi endpoint send-message` and verify 0 echo loops.

---

#### ⏱️ v0.5.1 – Surface discovery, SysEx7 and UMP endpoint configuration

**Deliverable:** a reconnect-safe session that identifies MCU or HUI on a selected surface port and reports the opened MIDI transport and protocol. Begin with directional startup captures from Cubase 15 and 16. [Detailed phases, packets and exit tests](docs/V0.5.x-V0.6.x_IMPLEMENTATION.md#v051-discovery-and-handshake)

1. **SysEx7 transport.** Implement MT 3 Complete/Start/Continue/End and legacy F0/F7 assembly in the native parser. Bound buffers and idle time per session/group, preserve ordering with real-time messages and keep completed control messages off the voice ring. Test fragment boundaries, simultaneous groups, overflow and disconnect. Exercise an API 35+ virtual UMP peer independently of the Galaxy USB byte route.
2. **MCU dialogue.** Choose the handshake by device family and observed host behavior. For the challenge variant the surface provides the challenge, verifies the host's reply and returns confirmation or denial. Cover query/ready-only hosts, directed Universal Device Inquiry, repeated probes, timeout and stale replies. Maintain separate manual-mode and auto-detection state. [Ardour's MCU and Logic Control paths](https://github.com/Ardour/ardour/blob/master/libs/surfaces/mackie/surface.cc)
3. **HUI heartbeat and header.** Respond to the host ping on the protocol worker. Protect Generic mode from false detection on note zero. Reuse the nine header roles with surface-to-host CC 0F/2F and host-to-surface LED feedback on CC 0C/2C (hex). Use the transport and cursor zone/port fixtures in the detailed plan. Record Cubase HUI and Pro Tools qualification separately. [HUI measurements](https://htlab.net/computer/protocol/mackie-control/HUI.pdf)
4. **Capability and endpoint discovery.** Implement MIDI-CI v1.2 Discovery/Reply, MUID collision handling and truthful capability/size reporting. Use MT F UMP Stream for endpoint/function-block discovery and Stream Configuration, respecting platform-owned responders. Keep the physical port's known framing on timeout. Validate identity at build time. Allow 7C only for eligible non-commercial discovery fields. A commercial configuration enabling manufacturer identity requires an injected assigned ID. Offer a build with identity-dependent features disabled. [MIDI-CI and UMP changes](https://midi.org/details-about-midi-2-0-midi-ci-profiles-and-property-exchange-updated-june-2023) · [Identity policy](https://midi.org/new-midi-association-sysex-id-policies-as-of-oct-15-2025)

**Exit evidence.** Kotlin framing vectors, deterministic worker/state-machine tests and Cubase cold/warm capture replay. Measure HUI replies against 50 ms under automation load; separately verify raw Stream responses on a capable UMP peer. Show surface mode and effective protocol in the connection indicator and MIDI Settings.

---

#### ⏱️ v0.5.2 – MCU displays, metering and bank feedback

**Deliverable:** responsive host-driven feedback for the eight-strip surface across selection, automation and channel/bank changes. [Decoder contracts and Cubase fixtures](docs/V0.5.x-V0.6.x_IMPLEMENTATION.md#v052-studio-feedback)

1. **LCD.** Decode Mackie command 12 into 112 raw cells (56 × 2). Handle offsets, row crossings, special glyphs and partial writes. Publish dirty strip/row slices with fallback layout labels while waiting for the DAW.
2. **Metering.** Add channel pressure to the selected MCU ingress, decode strip and level, keep overload latched until explicitly cleared. Bound paint cadence to visible frames and stop decay scheduling when idle or backgrounded.
3. **Rings and transport display.** Decode CC 30–37 hex into ring mode, segment position and independent indicator. Decode CC 40–49 and 4A/4B into ten reversed time digits and two assignment cells with a glyph table and dot flags. Test mode-specific zero/extremes and single-digit writes. [Controller implementation observations](https://github.com/NicoG60/TouchMCU/blob/main/doc/mackie_control_protocol.md)
4. **Bank reconciliation.** Send bank/channel navigation on MCU notes 2E/2F and 30/31. Track pending navigation separately from incoming host state. Clear obsolete peaks, preserve partial updates, and publish an absolute offset only with corroborating host evidence.

**Exit evidence.** Capture renames, pan/assignment changes, overload, playback display and rapid bank navigation in a 17-track project on Cubase 15 and 16. Compare 60/120 Hz profile runs, process CPU increase, GC-related missed frames, idle scheduling and touch-release delivery. Record injected-only feedback separately from DAW-emitted feedback.

---

### ⏳ v0.6.0 – DAW adapters, macro engine and Android latency audit

**Deliverable:** editable macro sequences, an installable OpenMIDIControl Cubase MIDI Remote driver, companion mappings and a measured transport decision. The primary qualification hosts are Cubase 15 and 16. [Data contracts, host-specific implementation and benchmark design](docs/V0.5.x-V0.6.x_IMPLEMENTATION.md#v060-macros-daw-adapters-and-android-latency)

1. **Macro engine and Inspector.** Add a versioned macro payload for MIDI, SysEx7, MCU, timed waits and named adapter commands. Plan v2→v3 layout migration, validate complete sequences on import, expose ordered editing and preview, and dispatch through a bounded cancellable per-session runner. Guard terminal releases, overlapping gestures and duplicate host commands with fake-clock and physical capture tests.
2. **Cubase adapter.** Create an original ES5 `PetersDigital_OpenMIDIControl.js` under `scripts/daw/cubase/`. Bind physical ports, eight strips plus master, relative encoders and the existing transport roles to Mixer, Quick Controls, EQ, Sends and Transport mappings. Use host callbacks first and probe available DirectAccess methods. Use a dedicated Channel Voice route for version, page/bank, command acknowledgements, UTF-8 names and colors. Use length-delimited seven-bit data and verify ordering and translation on each backend. Package as `.midiremote`; exercise clean import and deactivate/reactivate in each target host. [Steinberg API versions](https://steinbergmedia.github.io/midiremote_api_doc/versions/) · [Local Cubase mapping references](references/cubase/README.md)
3. **Other DAWs.** Provide separate REAPER CSI MIDI surfaces/zones, a version-pinned Live Python Remote Script, and a Logic control-surface profile with documented assignments. An OSC route for REAPER requires a MIDI↔OSC bridge. Qualify each artifact's installation, input, feedback, restart and removal on its actual host. Record the Mac/Logic qualification separately.
4. **Android latency decision.** Instrument touch, Dart dispatch, bridge, Kotlin write/receive, echo and Flutter paint. Compare repeatable 120 Hz load traces under identical route, refresh rate and thermal conditions. Measure parser microbenchmarks and end-to-end percentiles separately. Prototype AMidi/FFI only when the transport stage causes a measured budget miss. Preserve Kotlin fallback, timing and byte/UMP parity. [Android AMidi guide](https://developer.android.com/ndk/guides/audio/midi) · [Repository performance targets](TESTING.md)

**Exit evidence.** Macro migration and cancellation fixtures, two Cubase install/feedback reports, per-adapter support matrix, trace-backed Kotlin/AMidi decision and the full app/native regression suite. v0.6.0 is the feature milestone currently defined for v0.6.x. Assign subsequent patch work from qualified host/build regressions.
