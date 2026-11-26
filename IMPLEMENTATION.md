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

### ⏳ Current Focus: v0.4.4 – Modular Engine Core & MCU Prerequisites

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
  - Define immutable factory page templates (`Factory Fader Bank`, `4x4 Velocity Drum Grid`, `XY + Encoders`, and `8-Track Mixer Stub`).
  - Add a **Templates** tab inside `WidgetPalettePanel` (or `+ ADD NEW PAGE` flow) to stamp complete pages or template groups using existing grid bounds/collision checks.

#### Phase 4 – `WidgetStyle` Visual Sovereignty

- **Model & UI (`app/lib/core/models/widget_style.dart`, `control_config_modal.dart`):**
  - Add immutable `WidgetStyle` to `LayoutControl` (`accentColorHex`, `fontFamily` in `['Inter', 'Space Grotesk', 'DSEG7Modern']`, `showLabel`, `showNumericReadout`).
  - Add a curated 12-color high-contrast palette picker (aligned with `DESIGN.md`), font picker, and visibility toggles in `ControlConfigModal`.
  - Wire `WidgetStyle` into `HybridTouchFader`, `HybridXYPad`, `VelocityDrumPad`, `EndlessEncoderWidget`, and `MidiButton` without introducing extra widget rebuilds.

#### Verification (`v0.4.4`)

- Dart unit & widget tests: `action_payload_test.dart`, `layout_schema_migrator_test.dart` (`v0 → v1 → v2` & `v1 → v2` round-trips), `header_transport_state_test.dart`, `header_transport_grid_test.dart`, `performance_tab_transport_test.dart`, `widget_style_test.dart`, `page_templates_test.dart`.
- Full gate: `flutter analyze --fatal-infos`, `flutter test`, `.\gradlew.bat :app:testDebugUnitTest`, and on-device `.omc` export/import + cold-restart persistence verification.

---

### ⏳ v0.4.5 – Visual Sovereignty & Expressive Pads

**Goal:** Complete the remaining modular surface controls (`Global UI Scaling`, `AftertouchPad`, `LatchPad`) before starting protocol-layer work.

#### Phase 1 – Global UI Scaling (Zoom & Pan)

- **State & Settings (`app/lib/ui/settings/tabs/performance_tab.dart`, `open_midi_screen.dart`):**
  - Persist `globalUiScale` (`0.75..1.35`, default `1.0`) in `SharedPreferences` via a dedicated Riverpod notifier.
  - Wrap the performance grid surface in a scale-aware layout container with optional pan/scroll fallback when scale `> 1.0`, ensuring pointer hit-testing and multi-touch coordinate mapping stay exact (no offset drift on faders/XY pads).

#### Phase 2 – `AftertouchPad` (Expressive Y-Axis Pressure / MPE-Lite)

- **Widget (`app/lib/ui/widgets/aftertouch_pad.dart`, `control_widget_factory.dart`):**
  - Add `ControlType.aftertouchPad`: emits `Note On` on touch-down (velocity from tap position/pressure) and streams a configurable secondary CC (default `CC 74` Brightness / or Channel Pressure) from vertical `PointerMove` delta while held, emitting `Note Off` on pointer-up/cancel.
  - Enforce monotonic `Stopwatch` rate-limiting (`60–120Hz`) and `RepaintBoundary` isolation for visual fill feedback.

#### Phase 3 – `LatchPad` (Timed Smart Trigger)

- **Widget (`app/lib/ui/widgets/latch_pad.dart`, `control_widget_factory.dart`):**
  - Add `ControlType.latchPad`: triggers active state (`127` / `Note On`) for a configurable duration (e.g., `0.5s – 16.0s`) with a `CustomPainter` countdown ring overlay (`RepaintBoundary` + `PerformanceTickerMixin`).
  - **Safety Guarantee:** Cancel active timers and send clean release (`0` / `Note Off`) on page switch, widget disposal, or app backgrounding via `appLifecycleStateProvider`.

#### Verification (`v0.4.5`)

- Dart widget tests: `aftertouch_pad_test.dart` (pointer move CC cadence + release), `latch_pad_test.dart` (countdown completion, early cancel, background disposal), and global scale hit-test verification.
- HITL test via `midi endpoint monitor` confirming clean `Note On` → CC74 stream → `Note Off` bursts and zero stuck notes on page swap.

---

### ⏳ v0.5.x – The MCU / HUI Protocol Series

> **Platform & Standards Context (see `REFERENCES.md` & `references/cubase/README.md`):**
>
> - **Android UMP (API 33–36):** USB Peripheral continues using `MidiDeviceService` + `TRANSPORT_UNIVERSAL_MIDI_PACKETS` (with manual 4-byte chunk reconstruction in `MidiParser.kt`). Local virtual MIDI 2.0 endpoints can adopt `MidiUmpDeviceService` (API 33+/35+) where supported. UMP packets arrive as 32-bit (`MT=0x0/0x1/0x2`), 64-bit (`MT=0x3` SysEx7, `MT=0x4` MIDI 2.0 Channel Voice), or 128-bit (`MT=0x5` SysEx8/MDS, `MT=0xF` Stream) aligned words.
> - **Windows MIDI Services (Win11 GA Feb 2026 / `midi.exe`):** Multi-client by default (DAW + `midi endpoint monitor` share `KSA` endpoints concurrently) with `<1µs` timestamps, native UMP `MT=0x2`/`MT=0x3`/`MT=0x4` support, and MIDI-CI Function Blocks.
> - **SysEx Manufacturer IDs:** Use Mackie ID `00 00 66` (`14` = MCU, `15` = MCU XT) for MCU emulation, and **non-commercial ID `0x7C`** (MIDI Association Oct 2025 policy) for OpenMIDIControl custom UMP Endpoint Discovery / diagnostics.

---

#### ⏱️ v0.5.0 (Core Logic): Basic MCU Protocol Mapping & Native UMP High-Resolution Control

**Goal:** Deliver deterministic, low-latency 14-bit MCU fader/V-Pot/button/transport control and native high-resolution UMP transport.

##### Phase 1 – Native Kotlin & Core Dart High-Res UMP Foundation

- **Fix Pitch Bend Echo Suppression Bug (`app/android/.../MidiParser.kt`):**
  - In `forwardMidiEvent()`, `lastSentTime` is currently indexed with `data1` (`LSB` for Pitch Bend `0xE0..0xEF`), which changes on every fader tick and breaks bidirectional echo suppression. Normalize suppression key to `data1 = 0` whenever `(status and 0xF0) == 0xE0`.
- **14-Bit Pitch Bend & 64-Bit `MT=0x4` UMP Pipeline (`MidiParser.kt`, `UmpPacket.kt`, `MainActivity.kt`, `midi_event.dart`):**
  - Add `buildUmpPitchBendPacket(channel, value14Bit, group)` (`0x2<g>E<ch><lsb><msb>`) and `MidiEvent.pitchBendValue14Bit` (`(data2 << 7) | data1`, range `0..16383`).
  - Extend `MidiEvent` (optional `int umpWord2 = 0`) and `MidiParser.kt` / `IncomingEventsBuffer` to preserve **64-bit MIDI 2.0 Channel Voice (`MT=0x4`)** packets (`word0` header + `word1` 32-bit value) instead of dropping word 2, with deterministic down-translation to `MT=0x2` (14-bit Pitch Bend / 7-bit CC) when targeting MIDI 1.0 endpoints.
- **High-Res State (`control_state.dart`, `ui_state_sink_node.dart`, `native_transport_sink_node.dart`):**
  - Add immutable `pitchBendValues: Map<int, int>` (`0..15` → `0..16383`) and optional `highResCcValues: Map<String, int>` (32-bit unsigned) to `ControlState`.
  - Pre-allocate `Int32List(16)` pitch-bend buffer + dirty bitmask in `UiStateSinkNode` (zero allocation on hot path) and allow `MT=0x4` alongside `MT=0x2` in `NativeTransportSinkNode`.

##### Phase 2 – Pure-Dart MCU Core Protocol Module (`app/lib/core/protocol/mcu/`)

- **`mcu_constants.dart` — Standard Mackie Control Universal Map:**
  - **Faders (14-bit Pitch Bend):** Ch `0..7` (`0xE0..0xE7`) = Tracks 1–8; Ch `8` (`0xE8`) = Master (`0..16383`, 0 dB ≈ `12580` / `0x3124`).
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

#### ⏱️ v0.5.1 (Handshake): DAW Device Detection, SysEx7 Transport & Bidirectional Negotiation

**Goal:** Enable automatic DAW protocol discovery and keep-alive across MCU, Mackie HUI (Pro Tools), and MIDI 2.0 MIDI-CI / UMP Endpoint Discovery.

##### Phase 1 – Native UMP SysEx7 (`MT=0x3`) Chunking & Reassembly

- **Kotlin Layer (`MidiParser.kt`, `UmpPacket.kt`, `MainActivity.kt`):**
  - Implement 64-bit UMP **SysEx7 (`MT=0x3`)** chunking/reassembly (status nibbles: `0x0` complete in 1 packet, `0x1` start, `0x2` continue, `0x3` end; 0–6 data bytes per 64-bit packet) alongside legacy `F0 ... F7` byte-stream fallback.
  - Add bounded SysEx reassembly buffer (e.g., max `512` bytes, hard timeout/reset on malformed frames) to prevent DoS/memory growth, and expose a dedicated SysEx channel/stream to Dart (`EventChannel` or typed payload) without touching the hot-path `LongArray` CC/Pitch Bend ring buffer.
  - Evaluate migrating `VirtualMidiService` to `MidiUmpDeviceService` (API 33+/35+) for local inter-app MIDI 2.0 virtual routing while keeping `PeripheralMidiService` class-compliant for Windows/macOS USB.

##### Phase 2 – MCU Handshake & Challenge-Response State Machine (`app/lib/core/protocol/handshake/`)

- **Explicit Deterministic State Machine:** `IDLE → PROBING → CHALLENGED → HANDSHAKE_COMPLETE → ACTIVE` (with timeout fallback to generic MIDI mode, per `ARCHITECTURE.md` §7).
- **MCU SysEx Protocol (`F0 00 00 66 14 <cmd> ... F7`):**
  - Respond to Host Device Query (`cmd = 0x00`) with Host Connection Query / Serial (`cmd = 0x01`, 7-byte serial + 4 challenge bytes) and compute the 4-byte challenge response (`r1..r4`, masked `& 0x7F`) within `<300ms` (replying with `cmd = 0x02` / `0x03` confirmation).
  - Support Universal Device Inquiry (`F0 7E 7F 06 01 F7` → Identity Reply `F0 7E <devId> 06 02 00 00 66 ... F7` or `0x7C` non-commercial ID for native OpenMIDIControl mode).

##### Phase 3 – Mackie HUI Heartbeat & Protocol Auto-Detection

- **HUI Keep-Alive Responder (`hui_handshake.dart`):**
  - Detect DAW HUI ping (`0x90 0x00 0x00` sent every ~1–2s by Pro Tools / HUI hosts) and reply immediately on the native/worker path with `0x90 0x00 0x7F` so the DAW never drops the surface.
  - Implement HUI Zone/Port Select (`0xB0 0x0F <zone>` + `0xB0 0x2F <port>`) foundational mapping for HUI mode toggle, automatically mapping the 9 `HeaderTransportRole` cells via HUI Transport & Navigation zones while preserving manual Generic MIDI assignments.

##### Phase 4 – MIDI-CI & UMP Endpoint Discovery (Windows MIDI Services / Cubase 15+)

- **MIDI-CI Protocol Negotiation (`midi_ci_negotiator.dart`):**
  - Handle UMP Stream Discovery (`MT=0xF`) / MIDI-CI Discovery & Protocol Negotiation using non-commercial Manufacturer ID `0x7C` (`REFERENCES.md`) to advertise MIDI 2.0 (`MT=0x4`) capability and Function Block metadata, automatically falling back to MIDI 1.0 (`MT=0x2`) if the host declines or times out.
- **UI Indicator:** Surface negotiated protocol badge (`MIDI 1.0` / `MCU` / `HUI` / `MIDI 2.0 UMP`) inside `DynamicConnectionIsland` and `MidiSettingsScreen`.

##### Verification (`v0.5.1`)

- Kotlin JUnit: SysEx7 (`MT=0x3`) single-packet and multi-packet reassembly, malformed/oversized frame rejection, legacy `F0..F7` fallback.
- Dart tests: MCU challenge-response math vectors, timeout recovery state transitions, HUI `90 00 00 → 90 00 7F` responder, MIDI-CI fallback negotiation.
- HITL (`midi.exe` `sysex` & `endpoint request`): inject MCU Device Query & HUI pings from Windows MIDI Services and verify sub-50ms replies and `DynamicConnectionIsland` protocol badge updates.

---

#### ⏱️ v0.5.2 (Feedback): LCD Track Naming, Peak Metering, V-Pot Rings & Bank Switching

**Goal:** Close the bidirectional studio loop so track names, dB readouts, peak meters, V-Pot LED rings, timecode, and bank offsets reflect live DAW state at 60Hz with zero thermal churn.

##### Phase 1 – MCU 56×2 LCD Scribble Strip Engine (`app/lib/core/protocol/mcu/mcu_lcd_state.dart`)

- **SysEx Decoder (`F0 00 00 66 14 12 <offset> <ascii...> F7`):**
  - Maintain a fixed `112`-byte character buffer (Row 0: offsets `0..55`, Row 1: offsets `56..111` — 8 strips × 7 chars per row).
  - Update only modified strip slices (0–7) via granular Riverpod `.select((s) => s.stripLabel(i))` so updating Strip 3's value readout never rebuilds Strips 0–2 or 4–7.
  - Render dynamic scribble strip headers directly above MCU faders/strips (track name on top line, pan/value/parameter on second line) with graceful fallback to `LayoutControl.displayName` when disconnected.

##### Phase 2 – Peak Level Metering (`0xD0` Channel Pressure)

- **Native & Dart Metering Pipeline (`MidiParser.kt`, `mcu_meter_state.dart`):**
  - Enable Channel Pressure (`0xD0..0xDF`, 2-byte legacy / `MT=0x2` UMP `0x2<g>D0<data1>00`) passthrough in `MidiParser.kt` (currently only `0x80/0x90/0xB0/0xE0` are forwarded!).
  - Decode MCU meter byte: `stripIndex = (data1 >> 4) & 0x07`, `level = data1 & 0x0F` (`0..12` signal levels, `14` = overload/clip set, `15` = overload clear).
  - Drive per-strip peak meter bars via `ValueNotifier` / `CustomPainter` inside a dedicated `RepaintBoundary` with smooth ballistic decay (~300ms/segment per MCU spec) suspended automatically when backgrounded.

##### Phase 3 – V-Pot LED Rings & 7-Segment Timecode Display

- **V-Pot LED Rings (`CC 48..55` / `0x30..0x37`):**
  - Decode all 4 MCU ring modes (`Single Dot` `1..11`, `Boost/Cut` `17..27`, `Wrap` `33..43`, `Spread` `49..54`, plus `+64` center dot flag) and render the 11-segment arc directly in `EndlessEncoderWidget`'s painter.
- **Timecode / Beats 7-Segment Display (`CC 64..73` / `0x40..0x49`):**
  - Decode 10-character rightmost-to-leftmost timecode bytes (bit 6 = decimal point flag, bits `0..5` = ASCII char) plus Assignment display (`CC 74..75`) and render in a toggleable header/widget bar using the bundled `DSEG7Modern` font.

##### Phase 4 – Bank & Channel Switching Feedback

- **Bank State & Sync:**
  - Wire Bank Left/Right (`0x2E`/`0x2F`) and Channel Left/Right (`0x30`/`0x31`) actions, clearing stale transient meter peaks on bank switch and awaiting fresh DAW fader/LCD/LED snapshots without visual flicker.

##### Verification (`v0.5.2`)

- Unit tests: LCD offset wrapping/partial updates, Channel Pressure meter decoding & clip latch/clear, V-Pot LED ring mode decoding, Timecode `CC 64..73` decoding.
- HITL (`midi.exe`): stream `F0 00 00 66 14 12 00 ... F7` track names, `0x20D00A00` meter bursts, `0x20B03016` V-Pot rings, and `CC 64..73` timecode into the S24 Ultra; verify smooth 60–120Hz UI updates, `<5%` extra CPU delta, and zero `System.gc` UI stalls.

---

### ⏳ v0.6.0 – Native DAW Remote Scripts, Macro Engine & NDK Performance Audit

**Goal:** Deliver official host-side DAW scripts (starting with Cubase 14/15), programmable macro execution, and a data-driven Kotlin vs. NDK `AMidi` latency benchmark.

#### Phase 1 – Macro Engine & Inspector Scripting Hook

- **Model & Router (`app/lib/core/models/macro_action.dart`, `macro_dispatcher_node.dart`):**
  - Add a **Macro Script** action payload in `ControlConfigModal` supporting multi-step MIDI/DAW command sequences (ordered MIDI/SysEx/MCU commands with optional ms delays or host command IDs).
  - Implement `MacroDispatcherNode` in `MidiRouter` with non-blocking queue execution and diagnostics console logging.

#### Phase 2 – Official Cubase MIDI Remote Script (`scripts/daw/cubase/` — never modify `references/`)

- **Architecture (following `references/cubase/README.md` & `midiremote_api_v1`):**
  - Create `PetersDigital_OpenMIDIControl.js` using `require('midiremote_api_v1')`:
    - `makeDeviceDriver('PetersDigital', 'OpenMIDIControl', 'Peters Digital')`
    - `makeDetectionUnit().detectPortPair(midiInput, midiOutput)` matching Windows MIDI Services (`MIDI function` / `OpenMIDIControl`) and macOS port names.
    - `mOnActivate` / `mOnDeactivate` SysEx handshake (using `0x7C` non-commercial ID, modeled after `references/cubase/arturia/MiniLab_3/MiniLab_3_Connection.js`).
    - **Surface & SubPages:** Virtual surface mirroring OpenMIDIControl's Mixer, Quick Controls, EQ, Sends, and Transport `SubPages` (referencing `references/cubase/novation/common/sub-pages.js`), with 14-bit Pitch Bend faders, `RelativeSignedBit` encoders, and `setValueTakeOverModePickup()`.
    - **Direct Access Feedback (API v1.1+):** Stream track names, colors, and parameter titles/display values (`getParameterTitle`, `getParameterDisplayValue`) over compact framed SysEx to OpenMIDIControl (referencing `REFERENCES.md` SysEx streaming patterns) so Cubase displays full parameter names beyond MCU's 7-char LCD limit.

#### Phase 3 – Additional DAW Remote Scripts (Reaper / Ableton Live / Logic)

- Provide lightweight companion mappings/scripts under `scripts/daw/` (Reaper CSI / OSC-MIDI preset, Ableton Live MIDI Remote Script `.py`, Logic Pro Control Surface profile) sharing the same DAW-agnostic core protocol.

#### Phase 4 – Latency Benchmark & Conditional Android NDK `AMidi` Fast Path

- **Benchmark Suite:** Measure end-to-end round-trip latency and jitter (`Touch → JNI/Kotlin → USB UMP → Windows MIDI Services <1µs timestamp → Echo → UI`) under 120Hz multi-touch + metering load on Galaxy S24 Ultra.
- **Conditional NDK Migration (`amidi/AMidi.h` + Dart FFI):**
  - Migrate the native transport hot path to C++ `AMidi` + lock-free Dart FFI shared ring buffer **only if** benchmarks prove Kotlin/MethodChannel/EventChannel exceeds the latency/jitter budget (per `ARCHITECTURE.md` §3.1).
  - Preserve full Kotlin unit-test parity and `minSdk = 33` / `targetSdk = 36` compliance.
