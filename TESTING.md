# Automated Test Suite Architecture

> [!NOTE]
> This documentation is aligned with the multi-domain UMP transport test suite implemented in commit `1e5a48b8d0081c568c79f1e95548042a62067ec4`.

The v0.2.2 Universal MIDI Packet (UMP) transport pipeline utilizes a rigorous, multi-domain automated test suite. The suite is separated into three tiers: **Kotlin Native Unit Tests**, **Dart Flutter Unit Tests**, and **Flutter Integration Tests**.

This document outlines how to execute the test suite and the specific scenarios validated.

## 1. Phase A: Kotlin Native Transport & Logic Tests

**Target Directory:** `app/android/app/src/test/kotlin/com/PetersDigital/OpenMIDIControl/`
**Test File:** `MidiParserTest.kt`
**Runner:** Gradle (JUnit 4 + Coroutines Test)

The native Android byte-parsing logic is architecturally isolated in a testable static object `MidiParser.kt`. This prevents tests from requiring complex Android Service lifecycles (like `MidiManager` or `MidiDeviceService`).

### Scenarios Validated:
- **UMP Heuristic Validation:** Feeds legacy byte streams mixed with system real-time messages. Verifies that the internal heuristic correctly falls back to legacy parsing when the Message Type (MT) nibble fails to align with UMP definitions.
- **Legacy Byte Stream Parsing:** Simulates standard 3-byte legacy CC arrays. Asserts the parser correctly isolates the status byte and reconstructs it into a fully compliant 32-bit UMP integer using Group 0.
- **UMP 32-bit Reconstruction & Group Preservation:** Feeds 4-byte UMP packets representing multi-channel, multi-group CCs. Asserts the bit-shifting logic perfectly extracts the Message Type, Group, Status, CC Number, and Value.
- **Real-Time Spam Filter:** Floods the parser with Timing Clock (0xF8) and Active Sensing (0xFE) UMP packets. Asserts that these messages are silently dropped natively to prevent bridging them to the high-speed Dart streams.
- **Bidirectional Echo Suppression:** Tests the virtual DAW loopback prevention. Simulates an outgoing CC, then immediately receives an incoming virtual MIDI message on the same CC within the `suppressionWindowNs`. Asserts the incoming message is discarded.
- **Batching Loop Bounds:** Simulates a coroutine channel flood (e.g., pushing 150 events into a bounding pool of 100). Asserts that the `while (count + 1 < batch.size)` logic successfully slices the batch exactly at its capacity limit without throwing an `ArrayIndexOutOfBoundsException`.

### How to Run:
Navigate to the nested Android directory and execute the Gradle test task (using the specific debug variant to avoid irrelevant release build issues):
```powershell
cd app/android
.\gradlew.bat :app:testDebugUnitTest
```

---

## 2. Phase B: Dart Models & State Unit Tests

**Target Directory:** `app/test/`
**Runner:** Flutter Test

Validates the Phase 3 UMP integration within the core Dart models and Riverpod state architecture, plus comprehensive UI component testing.

### 2.1 Core Models & State (`midi_event_test.dart`, `midi_models_test.dart`, `control_state_test.dart`)

#### Scenarios Validated:
- **MidiEvent Bitwise Extraction:** Instantiates `MidiEvent` with a raw 32-bit UMP integer. Validates that the bitwise shift getters (`messageType`, `group`, `status`, `channel`, `data1`, `data2`, `legacyStatusByte`) extract the correct values.
- **Riverpod Equality Overrides:** Instantiates multiple `MidiEvent` objects with identical integers and timestamps. Validates `operator ==` and `hashCode` functionality to ensure Riverpod correctly identifies redundant state updates.
- **CcNotifier State Mutation:** Dispatches a batch of identical CC values into the `CcNotifier`. Asserts that the internal state map reference is strictly maintained (`identical(firstState, secondState) == true`), guaranteeing no unnecessary widget rebuilds occur.
- **Malformed JNI Payloads:** Pipes odd-length primitive `Int64List` structures (simulating an EventChannel truncation or drop). Asserts the decoder loop uses defensive bounds checking (`i + 1 < data.length`) to safely ignore the trailing orphan value without throwing a `RangeError`.
- **MidiPort Parsing:** Validates `MidiPort.fromMap()` correctly extracts port number and name from native maps, with defensive defaults for missing fields.
- **MidiStatus Updates:** Tests USB state transition logic (`CONNECTED`, `DISCONNECTED`) with device metadata preservation.
- **ControlState Immutability:** Validates `ControlState` constructor creates immutable `ccValues` map, defensively copies input to prevent external mutation, and `copyWith()` returns new immutable instances with updated values.
- **CcNotifier Batch Updates:** Tests `updateMultipleCCs()` applies multiple CC changes in a single state update, preventing redundant rebuilds during heavy automation.

#### How to Run:
```bash
cd app
flutter test test/midi_event_test.dart
flutter test test/midi_models_test.dart
flutter test test/control_state_test.dart
```

### 2.2 Diagnostics Module (`diagnostics_test.dart`)

#### Scenarios Validated:
- **DiagnosticsLoggerNotifier Initialization:** Validates initial state is empty list.
- **Clear Operation:** Tests `clear()` resets state to empty list and is idempotent.
- **Event Logging:** Validates MIDI events are correctly appended to diagnostics log with timestamps.
- **Widget Rendering:** Tests `DiagnosticsConsole` screen renders correctly with log entries table.
- **Auto-Dispose Behavior:** Validates notifier properly disposes on navigation to prevent CPU drain.

#### How to Run:
```bash
cd app
flutter test test/diagnostics_test.dart
```

### 2.3 Settings Screens (`settings_screen_test.dart`, `midi_settings_screen_test.dart`, `midi_settings_state_test.dart`)

#### Scenarios Validated:
- **SettingsScreen Rendering:** Tests app settings screen displays correctly with version info, fader behavior options, and orientation toggle.
- **PackageInfo Integration:** Validates version display uses overridden `packageInfoProvider` for testability.
- **MidiSettingsScreen Rendering:** Tests MIDI settings screen shows port lists, search field, and manual override toggle.
- **USB State Display:** Validates USB connection status banners display correctly based on `midiStatusProvider` state.
- **Port Highlighting:** Tests active port selection with visual highlighting (blue/green indicators).
- **MidiSettingsState Immutability:** Validates state model immutability and `copyWith()` operations.
- **Port Selection Logic:** Tests manual port override toggle and search filtering functionality.

#### How to Run:
```bash
cd app
flutter test test/settings_screen_test.dart
flutter test test/midi_settings_screen_test.dart
flutter test test/midi_settings_state_test.dart
```

### 2.4 Main Screen & Fader Components (`open_midi_screen_test.dart`)

#### Scenarios Validated:
- **OpenMIDIMainScreen Layout:** Tests responsive layout adaptation between portrait (phone) and landscape (tablet/desktop) modes.
- **HybridTouchFader Widget:** Validates fader rendering with CC labels, DSEG7 readouts, and color cues.
- **Fader Behavior Modes:** Tests Jump, Hybrid, and Catch-up behaviors with drag interactions.
- **Multi-Touch Capture:** Validates pointer capture and relative movement tracking.
- **CC Picker:** Tests long-press CC number selection dialog.
- **Value Deduplication:** Validates state updates only trigger on actual value changes.

#### How to Run:
```bash
cd app
flutter test test/open_midi_screen_test.dart
```

---

## 3. Phase C: Flutter Pipeline Integration Tests

**Target Directory:** `app/test/`
**Test File:** `midi_pipeline_integration_test.dart`
**Runner:** Flutter Test (Mocked EventChannel via `TestDefaultBinaryMessengerBinding`)

Validates the end-to-end integration between the mocked JNI EventChannel and the actual `MidiService` mapping logics.

### Scenarios Validated:
- **EventChannel Multiplexing (The Hotplug Test):** Simulates a complex environment where high-speed primitive `Int64List` batches are abruptly interrupted by dynamic `Map` payloads (like `usb_state: DISCONNECTED`). Asserts the `MidiService` demultiplexer effectively handles the interleaved types without crashing the main application.
- **High-Frequency Sweep (State Stress Test):** Simulates a 10,000-event CC automation sweep ping-ponging rapidly through the mocked native pipeline. Asserts that the internal Riverpod batch updates accurately process the flood and definitively reflect the final target value in the state tree.

### How to Run:
Navigate to the root flutter app directory and run:
```bash
cd app
flutter test test/midi_pipeline_integration_test.dart
```