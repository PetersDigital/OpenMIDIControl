# Automated Test Suite Architecture

> [!NOTE]
> This documentation covers the multi-domain test suite for the v0.2.2 UMP transport pipeline, including Kotlin native unit tests, Dart unit/widget tests, integration tests, and conceptual fuzzing tests.

The v0.2.2 Universal MIDI Packet (UMP) transport pipeline utilizes a rigorous, multi-domain automated test suite. The suite is separated into three tiers: **Kotlin Native Unit Tests**, **Dart Flutter Unit & Widget Tests**, and **Flutter Integration Tests**.

This document outlines how to execute the test suite and the specific scenarios validated.

## 1. Phase A: Kotlin Native Transport & Logic Tests

**Target Directory:** `app/android/app/src/test/kotlin/com/petersdigital/openmidicontrol/`
**Test File:** `MidiParserTest.kt`
**Runner:** Gradle (JUnit 4 + Coroutines Test)

The native Android byte-parsing logic is architecturally isolated in a testable static object `MidiParser.kt` (extracted from `MainActivity.kt` in commit `15f8ee8`). This prevents tests from requiring complex Android Service lifecycles (like `MidiManager` or `MidiDeviceService`).

### Scenarios Validated:

- **UMP Heuristic Validation:** Feeds legacy byte streams mixed with system real-time messages. Verifies that the internal heuristic correctly falls back to legacy parsing when the Message Type (MT) nibble fails to align with UMP definitions (MT=0x1 or MT=0x2).
- **Legacy Byte Stream Parsing:** Simulates standard 3-byte legacy CC arrays. Asserts the parser correctly isolates the status byte and reconstructs it into a fully compliant 32-bit UMP integer using Group 0.
- **UMP 32-bit Reconstruction & Group Preservation:** Feeds 4-byte UMP packets representing multi-channel, multi-group CCs. Asserts the bit-shifting logic perfectly extracts the Message Type, Group, Status, CC Number, and Value.
- **Real-Time Spam Filter:** Floods the parser with Timing Clock (0xF8) and Active Sensing (0xFE) UMP packets. Asserts that these messages are silently dropped natively to prevent bridging them to the high-speed Dart streams.
- **Bidirectional Echo Suppression:** Tests the virtual DAW loopback prevention. Simulates an outgoing CC, then immediately receives an incoming virtual MIDI message on the same CC within the `suppressionWindowNs`. Asserts the incoming message is discarded.
- **Batching Loop Bounds:** Simulates a coroutine channel flood (e.g., pushing 150 events into a bounding pool of 100). Asserts that the `while (count + 1 < batch.size)` logic successfully slices the batch exactly at its capacity limit without throwing an `ArrayIndexOutOfBoundsException`.
- **Array Bounds Crash Prevention:** Validates defensive bounds checking (`offset >= 0`, `count % 4 == 0`, `offset + count <= msg.size`) prevents DoS via malformed MIDI packets.

### How to Run:

Navigate to the nested Android directory and execute the Gradle test task (using the specific debug variant to avoid irrelevant release build issues):

```bash
cd app/android
./gradlew :app:testDebugUnitTest
```

Or on Windows PowerShell:

```powershell
cd app/android
.\gradlew.bat :app:testDebugUnitTest
```

---

## 2. Phase B: Dart Models & State Unit Tests

**Target Directory:** `app/test/`
**Runner:** Flutter Test

Validates the Phase 3 UMP integration within the core Dart models and Riverpod state architecture, plus comprehensive UI component testing.

### 2.1 Core Models (`midi_event_test.dart`)

#### Scenarios Validated:
- **MidiEvent UMP Model:** Validates the new simplified constructor `MidiEvent(ump, timestamp)` replaces the old multi-field constructor.
- **Bitwise Extraction:** Instantiates `MidiEvent` with a raw 32-bit UMP integer. Validates that the bitwise shift getters (`messageType`, `group`, `status`, `channel`, `data1`, `data2`, `legacyStatusByte`) extract the correct values.
- **Riverpod Equality Overrides:** Instantiates multiple `MidiEvent` objects with identical integers and timestamps. Validates `operator ==` and `hashCode` functionality to ensure Riverpod correctly identifies redundant state updates.
- **Legacy Status Byte Extraction:** Tests `legacyStatusByte` getter correctly extracts the combined status+channel byte (e.g., 0xB0 for CC on Channel 1).

#### How to Run:
```bash
cd app
flutter test test/midi_event_test.dart
```

### 2.2 MIDI Models (`midi_models_test.dart`)

#### Scenarios Validated:
- **MidiPort Parsing:** Validates `MidiPort.fromMap()` correctly extracts port number and name from native maps, with defensive defaults for missing fields.
- **MidiStatus Updates:** Tests USB state transition logic (`CONNECTED`, `DISCONNECTED`) with device metadata preservation.

#### How to Run:
```bash
cd app
flutter test test/midi_models_test.dart
```

### 2.3 State Management (`control_state_test.dart`)

#### Scenarios Validated:
- **ControlState Immutability:** Validates `ControlState` constructor creates immutable `ccValues` map, defensively copies input to prevent external mutation, and `copyWith()` returns new immutable instances with updated values.
- **CcNotifier State Mutation:** Dispatches a batch of identical CC values into the `CcNotifier`. Asserts that the internal state map reference is strictly maintained (`identical(firstState, secondState) == true`), guaranteeing no unnecessary widget rebuilds occur.
- **CcNotifier Batch Updates:** Tests `updateMultipleCCs()` applies multiple CC changes in a single state update, preventing redundant rebuilds during heavy automation.
- **Value Deduplication:** Validates state updates only trigger on actual value changes (early return if `state.ccValues[cc] == value`).
- **Lazy-Init Map Allocation:** Validates `updateMultipleCCs()` uses single-pass iteration with lazy `Map` initialization — only allocates new state when first change is detected, avoiding double-pass and full-map copy overhead during MIDI bursts.

#### How to Run:
```bash
cd app
flutter test test/control_state_test.dart
```

### 2.4 Diagnostics Module (`diagnostics_test.dart`)

#### Scenarios Validated:
- **DiagnosticsLoggerNotifier Initialization:** Validates initial state is empty list.
- **Clear Operation:** Tests `clear()` resets state to empty list and is idempotent.
- **Event Logging:** Validates MIDI events are correctly appended to diagnostics log with timestamps.
- **Widget Rendering:** Tests `DiagnosticsConsole` screen renders correctly with log entries table.
- **Auto-Dispose Behavior:** Validates notifier properly disposes on navigation to prevent CPU drain.
- **Disposal Guard:** Validates `_disposed` flag prevents state-write errors when `scheduleFrameCallback` fires after auto-dispose. Also verifies `_pendingUpdate` is reset in `onDispose` to prevent stale state on re-mount.

#### How to Run:
```bash
cd app
flutter test test/diagnostics_test.dart
```

### 2.5 Settings Screens (`settings_screen_test.dart`, `midi_settings_screen_test.dart`, `midi_settings_state_test.dart`)

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

### 2.6 Main Screen & Fader Components (`open_midi_screen_test.dart`)

#### Scenarios Validated:
- **OpenMIDIMainScreen Layout:** Tests responsive layout adaptation between portrait (phone) and landscape (tablet/desktop) modes.
- **HybridTouchFader Widget:** Validates fader rendering with CC labels, DSEG7 readouts, and color cues.
- **Fader Behavior Modes:** Tests Jump, Hybrid, and Catch-up behaviors with drag interactions.
- **Multi-Touch Capture:** Validates pointer capture and relative movement tracking.
- **CC Picker:** Tests long-press CC number selection dialog.
- **Value Deduplication:** Validates state updates only trigger on actual value changes.
- **Monotonic Clock Throttling:** Validates `HybridTouchFader` uses `Stopwatch.elapsedMilliseconds` (not `DateTime.now()`) for MIDI rate limiting, ensuring throttle logic is immune to system clock jumps (NTP sync).

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
- **UMP Payload Processing:** Validates that `Int64List` batches containing 32-bit UMP integers are correctly decoded into `MidiEvent` objects with proper bitwise extraction.

### How to Run:

Navigate to the root flutter app directory and run:

```bash
cd app
flutter test test/midi_pipeline_integration_test.dart
```

---

## 4. Running All Tests

To run the complete test suite:

### Dart Tests Only:

```bash
cd app
flutter test
```

### Kotlin Native Tests Only:

```bash
cd app/android
./gradlew :app:testDebugUnitTest
```

Or on Windows:

```powershell
cd app/android
.\gradlew.bat :app:testDebugUnitTest
```

### Full Suite (Dart + Kotlin):

```bash
# Run Kotlin tests
cd app/android
./gradlew :app:testDebugUnitTest

# Run Dart tests
cd ../../app
flutter test
```

---

## 5. Test Writing Guidelines

### Kotlin Native Tests (`app/android/app/src/test/kotlin/...`):

```kotlin
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
@Test
fun `UMP reconstruction preserves MIDI channel`() = runTest {
    // Arrange
    val umpPacket = byteArrayOf(
        0x20.toByte(), // MT=2 (Channel Voice), Group 0
        0xB0.toByte(), // Status: CC on Channel 1
        0x01.toByte(), // CC Number: 1
        0x40.toByte()  // CC Value: 64
    )
    val channel = Channel<Pair<Long, Long>>(Channel.UNLIMITED)
    val lastSentTime = emptyMap<Int, Long>()

    // Act
    MidiParser.processMidiPayload(
        msg = umpPacket,
        offset = 0,
        count = 4,
        timestamp = System.nanoTime(),
        isVirtual = false,
        incomingEventsChannel = channel,
        suppressionWindowNs = 5_000_000L,
        lastSentTime = lastSentTime,
        isDebug = false
    )
    channel.close()
    val result = channel.receiveCatching()

    // Assert
    assert(result.isSuccess)
    val (reconstructedUmp, _) = result.getOrNull()!!
    assertEquals(0x20B00140L, reconstructedUmp)
}
```

### Dart Unit Tests (`app/test/`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:open_midi_control/core/models/midi_event.dart';

void main() {
  test('MidiEvent extracts fields from 32-bit UMP integer', () {
    // Arrange: CC1, Value 64, Channel 1, Group 0
    final ump = 0x20B00140;

    // Act
    final event = MidiEvent(ump, 12345);

    // Assert
    expect(event.messageType, 2); // Channel Voice
    expect(event.group, 0);
    expect(event.status, 0xB0); // CC status
    expect(event.channel, 0); // Channel 1 (0-indexed)
    expect(event.data1, 0x01); // CC Number 1
    expect(event.data2, 0x40); // CC Value 64
    expect(event.legacyStatusByte, 0xB0);
  });
}
```

### Widget Tests (`app/test/`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_midi_control/ui/hybrid_touch_fader.dart';

void main() {
  testWidgets('HybridTouchFader renders with CC label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HybridTouchFader(
              ccNumber: 1,
              behavior: FaderBehavior.jump,
            ),
          ),
        ),
      ),
    );

    expect(find.text('CC 1'), findsOneWidget);
  });
}
```

---

## 6. Conceptual: UMP Fuzzing Tests (v0.3.0+)

> [!NOTE]
> Fuzzing tests are planned for v0.3.0. The following describes the intended structure.

**Target Directory:** `app/android/app/src/androidTest/kotlin/com/petersdigital/openmidicontrol/`
**Test File:** `UmpFuzzTest.kt`
**Runner:** Gradle (Android Instrumentation Tests)

### Overview

Automated fuzzing tests generate random UMP packets to validate reconstruction accuracy and measure latency distribution under stress conditions.

### Scenarios Validated:

- **Random UMP Generation:** Generates 10,000 random valid UMP packets (all message types, groups, channels).
- **Reconstruction Accuracy:** Validates 100% accurate reconstruction after byte[] → UMP conversion.
- **Latency Distribution:** Measures p50, p95, p99 latency percentiles.
- **Edge Cases:** Tests boundary conditions (min/max values, all groups 0-15, all channels 0-15).

### Performance Targets:

| Metric | Target | Description |
|--------|--------|-------------|
| **p50 Latency** | <0.05ms | Median UMP reconstruction time |
| **p95 Latency** | <0.1ms | 95th percentile latency |
| **p99 Latency** | <0.2ms | Worst-case acceptable latency |
| **GC Allocations** | <100KB/batch | Memory churn per batch |

### Conceptual Implementation:

```kotlin
@Test
fun umpFuzzTest() {
    val random = Random(42) // Fixed seed for reproducibility
    val channel = Channel<Pair<Long, Long>>(capacity = 10000)
    val latencies = mutableListOf<Long>()

    repeat(10000) {
        val ump = generateRandomUmp(random)
        val payload = ump.toUmpByteArray()
        val start = System.nanoTime()

        MidiParser.processMidiPayload(
            msg = payload,
            offset = 0,
            count = 4,
            timestamp = start,
            isVirtual = false,
            incomingEventsChannel = channel,
            suppressionWindowNs = 0L,
            lastSentTime = emptyMap(),
            isDebug = false
        )

        val (reconstructed, _) = channel.receive()
        val latency = System.nanoTime() - start
        latencies.add(latency)

        assertEquals(ump, reconstructed)
    }

    // Validate latencies
    latencies.sort()
    val p50 = latencies[latencies.size * 50 / 100]
    val p95 = latencies[latencies.size * 95 / 100]
    val p99 = latencies[latencies.size * 99 / 100]

    assertTrue("p50 < 0.05ms", p50 < 50_000)
    assertTrue("p95 < 0.1ms", p95 < 100_000)
    assertTrue("p99 < 0.2ms", p99 < 200_000)
}
```

---

## 7. Continuous Integration

All tests run automatically on pull requests via GitHub Actions:

- **Flutter Analysis & Tests:** `flutter analyze --fatal-infos` + `flutter test`
- **Kotlin Tests:** `./gradlew :app:testDebugUnitTest`
- **Integration Tests:** `flutter test test/midi_pipeline_integration_test.dart`

Tests must pass before PRs can be merged.

---

## 8. Hardware-in-the-Loop (HITL) Testing

Automated tests cannot replace real hardware validation. The following manual tests are required:

### USB Peripheral Mode Validation

1. Connect Android device to Windows 11 PC via USB-C.
2. Confirm "USB PERIPHERAL MODE ACTIVE" green banner.
3. Select "OpenMIDIControl" as MIDI Input/Output in DAW.
4. Move faders and verify MIDI data reception.
5. Test bi-directional feedback with DAW automation.

### Diagnostics Console

- Access via the debug modal in Settings.
- Real-time event logging with native timestamps.
- Auto-disposes on close to prevent CPU drain.

### Hardware Monitoring (HITL)

```powershell
# Monitor native logs (look for "UMP Reconstruction" or "32-bit Payload")
adb logcat | Select-String "openmidicontrol|PeripheralMidi|MidiReceiver"

# Send test MIDI messages (Windows MIDI Services)
midi endpoint send-message 0x20B00140  # CC1, Value 64
```

---

## 9. Test Coverage Requirements

All contributions must maintain or improve test coverage:

- **Changes to `MidiParser.kt`:** Require Kotlin native unit tests
- **Changes to `MidiEvent` model:** Require Dart unit tests
- **Changes to `ControlState` or `CcNotifier`:** Require Dart state tests
- **UI component changes:** Require widget tests
- **EventChannel bridge modifications:** Require integration tests

Run these commands before pushing:

```bash
# Flutter analysis and tests
cd app
flutter analyze
flutter test

# Kotlin native tests
cd app/android
./gradlew :app:testDebugUnitTest
```
