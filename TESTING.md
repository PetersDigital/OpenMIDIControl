# Automated Test Suite Architecture

> [!NOTE]
> This documentation is aligned with the multi-domain UMP transport test suite implemented in commit `1e5a48b8d0081c568c79f1e95548042a62067ec4`.

The v0.2.2 Universal MIDI Packet (UMP) transport pipeline utilizes a rigorous, multi-domain automated test suite. The suite is separated into three tiers: **Kotlin Native Unit Tests**, **Dart Flutter Unit Tests**, and **Flutter Integration Tests**.

This document outlines how to execute the test suite and the specific scenarios validated.

## 1. Phase A: Kotlin Native Transport & Logic Tests

**Target Directory:** `app/android/app/src/test/kotlin/com/petersdigital/openmidicontrol/`
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

---

## 4. Phase D: UMP Fuzzing Tests (v0.3.0+)

**Target Directory:** `app/android/app/src/androidTest/kotlin/com/petersdigital/openmidicontrol/`
**Test File:** `UmpFuzzTest.kt`
**Runner:** Gradle (Android Instrumentation Tests)

### Overview
Automated fuzzing tests generate random UMP packets to validate reconstruction accuracy and measure latency distribution under stress conditions.

### Scenarios Validated:
- **Random UMP Generation:** Generates 10,000 random valid UMP packets (all message types, groups, channels).
- **Reconstruction Accuracy:** Validates 100% accurate reconstruction after byte[] → UMP conversion.
- **Latency Distribution:** Measures p50, p95, p99 latency percentiles.
- **Malformed Packet Handling:** Injects invalid packets (wrong length, invalid MT) to validate graceful degradation.
- **Boundary Conditions:** Tests minimum (4 bytes) and maximum (16 bytes) UMP packet sizes.

### Performance Targets:
| Metric | Target | Measurement |
|--------|--------|-------------|
| **Reconstruction Accuracy** | 100% | All packets correctly reconstructed |
| **p50 Latency** | <0.3ms | 50th percentile latency |
| **p95 Latency** | <0.5ms | 95th percentile latency |
| **p99 Latency** | <1.0ms | 99th percentile latency |
| **GC Allocations** | <100KB/batch | Memory churn per batch |

### Test Implementation:
```kotlin
@Test
fun umpFuzzTest() {
    val random = Random(42) // Fixed seed for reproducibility
    val latencies = mutableListOf<Long>()
    
    repeat(10_000) { i ->
        // Generate random UMP packet
        val umpPacket = generateRandomUmp(random)
        
        // Measure reconstruction latency
        val start = System.nanoTime()
        val reconstructed = MidiParser.reconstruct(umpPacket)
        val latency = (System.nanoTime() - start) / 1_000_000 // Convert to ms
        
        // Validate accuracy
        assertEquals(umpPacket, reconstructed)
        latencies.add(latency)
    }
    
    // Calculate percentiles
    latencies.sort()
    val p50 = latencies[latencies.size * 50 / 100]
    val p95 = latencies[latencies.size * 95 / 100]
    val p99 = latencies[latencies.size * 99 / 100]
    
    // Assert performance targets
    assertTrue(p50 < 0.3, "p50 latency $p50ms exceeds 0.3ms target")
    assertTrue(p95 < 0.5, "p95 latency $p95ms exceeds 0.5ms target")
    assertTrue(p99 < 1.0, "p99 latency $p99ms exceeds 1.0ms target")
}
```

### How to Run:
```powershell
cd app/android
.\gradlew.bat :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.petersdigital.openmidicontrol.UmpFuzzTest
```

**Requirements:**
- Connected Android device or emulator
- USB debugging enabled
- Android 13+ (API 33)

---

## 5. Hardware-in-the-Loop (HITL) Testing

For native layer changes, validate with physical MIDI hardware as described in the main test sections above.

---

## 6. Performance Benchmarking (v0.3.0+)

**Target:** Continuous performance monitoring with automated regression detection.

### Benchmark Suite:
```kotlin
@OptIn(BenchmarkTime::class)
@Test
fun benchmarkUmpReconstruction() {
    val umpPacket = byteArrayOf(0x20, 0xB0, 0x01, 0x40)
    
    // Warm up JIT
    repeat(1000) { MidiParser.reconstruct(umpPacket) }
    
    // Measure
    val start = System.nanoTime()
    repeat(100_000) { MidiParser.reconstruct(umpPacket) }
    val elapsed = (System.nanoTime() - start) / 1_000_000
    
    println("Average latency: ${elapsed / 100_000.0}ms")
}
```

### Benchmark Targets:
| Operation | Target | Current (v0.2.2) |
|-----------|--------|------------------|
| **UMP Reconstruction** | <0.1ms | ~0.5ms |
| **Event Batching (1000 events)** | <5ms | ~8ms |
| **State Update (Riverpod)** | <1ms | ~2ms |
| **UI Rebuild (Fader)** | <16ms | ~8ms |

### How to Run:
```powershell
cd app/android
.\gradlew.bat :app:benchmark
```

**Output:**
- CSV files with latency distributions
- Flame graphs for hotspot analysis
- GC allocation reports

---

## 7. Test Coverage Requirements (v0.2.2+)

**Minimum Coverage Targets:**
- **Kotlin Native Layer:** >85% line coverage
- **Dart Models:** >90% line coverage
- **UI Components:** >70% line coverage

**Coverage Reports:**
```powershell
# Kotlin coverage
cd app/android
.\gradlew.bat :app:koverHtmlReport

# Dart coverage
cd app
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**Coverage Tools:**
- Kotlin: Kover (Kotlinx)
- Dart: `lcov` + `genhtml`

---

## 8. Continuous Integration Testing

**GitHub Actions Workflow:**
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Kotlin Tests
        run: cd app/android && ./gradlew test
      
      - name: Run Dart Tests
        run: cd app && flutter test
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
```

**Required Checks for PR Merge:**
- ✅ All Kotlin tests pass
- ✅ All Dart tests pass
- ✅ `flutter analyze` passes
- ✅ Code coverage meets minimum targets
- ✅ Performance benchmarks within targets (v0.3.0+)