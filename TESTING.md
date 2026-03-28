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
**Test File:** `midi_event_test.dart`
**Runner:** Flutter Test

Validates the Phase 3 UMP integration within the core Dart models and Riverpod state architecture.

### Scenarios Validated:
- **MidiEvent Bitwise Extraction:** Instantiates `MidiEvent` with a raw 32-bit UMP integer. Validates that the bitwise shift getters (`messageType`, `group`, `status`, `channel`, `data1`, `data2`, `legacyStatusByte`) extract the correct values.
- **Riverpod Equality Overrides:** Instantiates multiple `MidiEvent` objects with identical integers and timestamps. Validates `operator ==` and `hashCode` functionality to ensure Riverpod correctly identifies redundant state updates.
- **CcNotifier State Mutation:** Dispatches a batch of identical CC values into the `CcNotifier`. Asserts that the internal state map reference is strictly maintained (`identical(firstState, secondState) == true`), guaranteeing no unnecessary widget rebuilds occur.
- **Malformed JNI Payloads:** Pipes odd-length primitive `Int64List` structures (simulating an EventChannel truncation or drop). Asserts the decoder loop uses defensive bounds checking (`i + 1 < data.length`) to safely ignore the trailing orphan value without throwing a `RangeError`.

### How to Run:
Navigate to the root flutter app directory and run:
```bash
cd app
flutter test test/midi_event_test.dart
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