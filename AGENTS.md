# AGENTS.md

OpenMIDIControl is a performance-first, multi-touch MIDI control surface built with Flutter/Dart (UI) and Kotlin (native Android MIDI layer). Current milestone: **v0.2.2 – Hybrid UMP Implementation**. See [IMPLEMENTATION.md](IMPLEMENTATION.md) for the full roadmap and [ARCHITECTURE.md](ARCHITECTURE.md) for system design.

## Project Structure

```
OpenMIDIControl/
├── app/                          # Flutter application root
│   ├── android/                  # Android native Kotlin layer
│   │   └── app/src/main/kotlin/  # MainActivity.kt, MidiPortBackend, services
│   ├── lib/                      # Dart source code
│   │   ├── core/models/          # MidiEvent, ControlState
│   │   └── ui/                   # Screens, widgets, services
│   ├── test/                     # Widget and unit tests
│   ├── assets/fonts/             # DSEG7Modern, Inter, Space Grotesk
│   └── pubspec.yaml              # Dependencies & version
├── docs/                         # Additional documentation
├── references/                   # Reference materials (read-only)
├── scripts/                      # PowerShell build/deploy scripts
├── AGENTS.md                     # AI agent development guidelines
├── ARCHITECTURE.md               # System architecture & constraints
├── CHANGELOG.md                  # Version history (SemVer)
├── CONTRIBUTING.md               # Contribution guidelines
├── DESIGN.md                     # Design system ("The Console")
├── IMPLEMENTATION.md             # Implementation roadmap
└── README.md                     # Project overview & getting started
```

### Key Components

| File / Directory | Purpose |
|---|---|
| `app/lib/core/models/MidiEvent` | Immutable 32-bit UMP-ready MIDI event model |
| `app/lib/core/models/ControlState` | Scalable Riverpod state for UI controls |
| `app/lib/ui/open_midi_screen.dart` | Main performance screen |
| `app/lib/ui/hybrid_touch_fader.dart` | Expressive fader (Jump/Hybrid/Catch-up) |
| `app/lib/ui/midi_settings_screen.dart` | Port configuration with active highlighting |
| `app/lib/ui/diagnostics/` | Real-time MIDI event logger |
| `app/android/.../MainActivity.kt` | JNI bridge & `MidiPortBackend` implementation |
| `app/android/.../MidiParser.kt` | **v0.2.2** Manual 32-bit UMP reconstruction, real-time filtering, batching |
| `app/android/.../VirtualMidiService.kt` | Virtual MIDI device for local routing (legacy `MidiDeviceService`) |
| `app/android/.../PeripheralMidiService.kt` | USB class compliance service (legacy `MidiDeviceService`) |
| `app/android/.../Utils.kt` | `safeExecute()` wrapper for native error handling |

**Note on UMP Implementation (v0.2.2)**: Due to Android's incomplete `MidiUmpDeviceService` API (requires Android 15+, feature-flagged), the app uses hybrid UMP:
- Retains `MidiDeviceService` for 90% device coverage (Android 13-15)
- Manual 32-bit reconstruction in `MidiParser.kt` from `byte[]` buffers
- UMP enforced via `TRANSPORT_UNIVERSAL_MIDI_PACKETS` transport flag

## Build & Test Commands

### Prerequisites
- Flutter 3.x (SDK ^3.11.0)
- Android Studio / Android SDK
- Android device with USB MIDI support (API 33+ for UMP support)
- PowerShell 7+ (for build scripts)

### Setup

```powershell
cd app
flutter pub get
```

### Run

```bash
flutter devices          # list connected devices
flutter run -d <id>      # run on a specific device
flutter build apk --release
```

### Release keystore

```powershell
Copy-Item -Path scripts/.env.example.ps1 -Destination scripts/.env.ps1
# Fill in keystore Base64 and credentials (provided by maintainer)
```

### Analyze & Test

```bash
flutter analyze
flutter test
```

## Code Style

- **Architecture:** `MidiEvent` (transport) is strictly separated from `ControlState` (UI-facing Riverpod state). All state models are immutable.
- **Native UMP (v0.2.2+):** The native layer enforces 32-bit Universal MIDI Packets (UMP) via hybrid implementation. Due to Android SDK constraints (`MidiUmpDeviceService` requires Android 15+, feature-flagged), the app retains `MidiDeviceService` but implements **manual 32-bit reconstruction** from `byte[]` buffers in `MidiParser.kt`. Ports are opened with `TRANSPORT_UNIVERSAL_MIDI_PACKETS` flag for MIDI 2.0 compatibility.
- **Versioning:** SemVer (`MAJOR.MINOR.PATCH`).
- **Commits:** Conventional Commits — `feat(scope): description`, `fix(scope): description`.
  - Multiple scopes: use forward slashes — `feat(ui/midi): …`. **No hyphens between scopes.**
- **State machines:** Prefer explicit, deterministic state machines for touch capture, MIDI feedback sync, and feedback loop prevention.
- **Concurrency:** Use Kotlin Coroutines with strict suspension (no busy-wait). Do not introduce blocking I/O on MIDI threads.
- **Dependencies:** Avoid heavy new dependencies without justification.
- **References:** Do **not** modify or add code under `references/`. Host-specific adapters live in the core codebase, not there.

## Testing Instructions

### Automated Test Suite (v0.2.2+)

The v0.2.2 release includes a comprehensive test suite with 10 test files covering native layer, models, state, UI components, and integration tests. See [TESTING.md](TESTING.md) for complete documentation.

**Phase A: Kotlin Native Tests**
```powershell
cd app/android
.\gradlew.bat :app:testDebugUnitTest
```
- Tests `MidiParser.kt` UMP reconstruction logic
- Validates real-time spam filtering (0xF8, 0xFE)
- Tests bidirectional echo suppression
- Validates batching loop bounds

**Phase B: Dart Unit Tests**

_Run all Dart tests:_
```bash
cd app
flutter test
```

_Run individual test files:_
```bash
# Core models and state
flutter test test/midi_event_test.dart          # MidiEvent bitwise extraction, Riverpod equality
flutter test test/midi_models_test.dart         # MidiPort parsing, MidiStatus updates
flutter test test/control_state_test.dart       # ControlState immutability, CcNotifier batches

# Diagnostics
flutter test test/diagnostics_test.dart         # DiagnosticsLoggerNotifier, console widget

# Settings screens
flutter test test/settings_screen_test.dart                # Settings rendering, PackageInfo
flutter test test/midi_settings_screen_test.dart           # Port selection, USB status
flutter test test/midi_settings_state_test.dart            # Settings state immutability

# Main screen and faders
flutter test test/open_midi_screen_test.dart    # Main screen layout, fader behaviors
```

**Phase C: Integration Tests**
```bash
cd app
flutter test test/midi_pipeline_integration_test.dart
```
- Tests EventChannel multiplexing
- High-frequency stress tests (10,000 events)

### Manual Testing

- **Widget tests** for all UI components (`app/test/`).
- **HITL (Hardware-in-the-Loop)** for native layer — requires a physical MIDI device.
- Use `addTearDown` in tests to prevent state bleeding between cases.
- Run `flutter analyze` and `flutter test` before every commit.

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
# Monitor native logs (look for "MIDI IN: CC" or "UMP Reconstruction")
adb logcat | Select-String "openmidicontrol|MidiParser|MidiReceiver"

# Send test MIDI messages (Windows MIDI Services)
midi endpoint send-message 0x20B00140  # CC1, Value 64
```

## PR Instructions

- **Do not implement features without an issue or an explicit plan step.**
- One concern per PR — keep changes small and reviewable.
- Always update docs (README / ARCHITECTURE / CHANGELOG) when behavior changes.

### Checklist
- [ ] Conventional Commit title
- [ ] Tests added/updated (where applicable)
- [ ] Docs updated (README/ARCHITECTURE/CHANGELOG)
- [ ] No secrets in code or configs
- [ ] PR opened as draft
- [ ] Assignee: @dencelkbabu
- [ ] Reviewers: @dencelkbabu + @copilot-pull-request-reviewer + @gemini-code-assist
- [ ] Labels: `draft`, `needs review`

### GitHub CLI

```powershell
# PowerShell
git checkout -b <branch>
git push -u origin <branch>
gh pr create --base main --head <branch> `
  --title "<conventional-commit-title>" `
  --body "<description>" `
  --draft --assignee dencelkbabu --reviewer dencelkbabu `
  --label "draft,needs review"
gh pr view --web
```

```bash
# Bash
git checkout -b <branch>
git push -u origin <branch>
gh pr create --base main --head <branch> \
  --title "<conventional-commit-title>" \
  --body "<description>" \
  --draft --assignee dencelkbabu --reviewer dencelkbabu \
  --label "draft,needs review"
gh pr view --web
```

## Agent Priorities

When making decisions, agents must prioritize in this order:
1. Low-latency, low-jitter MIDI event handling
2. Reliable MIDI behavior and deterministic state
3. Multi-touch correctness
4. Battery and thermal stability on Android

## Technical Decision Records (TDR)

### TDR-001: Hybrid UMP Implementation (v0.2.2)

**Decision**: Retain `MidiDeviceService` instead of migrating to `MidiUmpDeviceService`

**Rationale**:
- `MidiUmpDeviceService` virtual UMP requires Android 15+ (API 35), not API 33
- Feature-flagged with `@FlaggedApi(Flags.FLAG_VIRTUAL_UMP)` — unreliable across OEMs
- Provides only ~20% device coverage vs. 90% for hybrid approach
- Restrictive port constraints (input=output, non-zero)

**Implementation**:
- Manual 32-bit UMP reconstruction in `MidiParser.kt`
- Big-endian bitwise shifts: `(b1 << 24) | (b2 << 16) | (b3 << 8) | b4`
- UMP enforced via `TRANSPORT_UNIVERSAL_MIDI_PACKETS` transport flag
- Real-time filtering (0xF8, 0xFE) at native entry point

**Trade-offs**:
- ✅ 90% device coverage (Android 13-15)
- ✅ Full implementation control
- ⚠️ Manual UMP maintenance burden
- ⚠️ ~0.5ms reconstruction overhead (negligible vs. USB)

**Review Date**: Permanent architecture (no migration planned)

**See**: ARCHITECTURE.md Section 3.2 for detailed data flow

### TDR-002: Kotlin SIMD Optimization (v0.3.0)

**Decision**: Implement RenderScript-based SIMD UMP reconstruction

**Rationale**:
- Current sequential bitwise ops: ~0.5ms latency
- SIMD batch processing target: <0.1ms (4x speedup)
- Works on Android 13-15 (90% coverage)
- No SDK dependencies or feature flags

**Implementation**:
```kotlin
// RenderScript SIMD: Process 16 bytes in parallel
fun reconstructUmpSimd(bytes: ByteArray): IntArray {
    // Allocate RenderScript allocation
    // Execute kernel: bitwise shifts in parallel
    // Copy results to IntArray
}
```

**Trade-offs**:
- ✅ 4x latency reduction (0.5ms → 0.1ms)
- ✅ RenderScript available since API 17
- ⚠️ RenderScript deprecated in Android 12+ (but still supported)
- ⚠️ Alternative: Vulkan compute shaders (higher complexity)

**Review Date**: v0.3.0 implementation

**See**: ARCHITECTURE.md Section 13.1

### TDR-003: NDK Fast Path (v0.4.0)

**Decision**: Migrate hot path to C++ NDK with Dart FFI

**Rationale**:
- Kotlin JVM adds ~0.3-0.5ms GC jitter
- Android `AMidi` (NDK) has direct UMP support since API 33
- Zero-copy shared memory ring buffer
- Complete GC elimination

**Migration Triggers** (ANY triggers):
- UMP reconstruction latency >0.3ms
- GC pauses >16ms during heavy automation
- Thermal throttling under 1000+ events/sec
- User reports of audio dropouts

**Implementation**:
```cpp
// C++ NDK: Zero-copy ring buffer
class UmpRingBuffer {
    void enqueue(uint32_t ump, int64_t timestamp);
    std::array<uint8_t, 1024> dequeue_batch();
};
```

**Trade-offs**:
- ✅ Sub-0.1ms latency target
- ✅ Zero GC jitter
- ✅ Works on Android 13+ (same as hybrid)
- ⚠️ C++ maintenance burden
- ⚠️ NDK build complexity

**Review Date**: v0.4.0 implementation

**See**: ARCHITECTURE.md Section 13.2

### TDR-004: MIDI 2.0 Strategy (Feb 2026 Update)

**Decision**: **INCLUDE** MIDI-CI Handshake in v0.4.0 (CRITICAL)

**Windows MIDI 2.0 Timeline**:
- **Current Status**: Release Candidate 3 (RC3) - February 2026
- **Expected Stable**: March-April 2026 (1-2 months from RC3)
- **Expected Cubase 15 MIDI 2.0**: Q3 2026 (3-4 months after Windows stable)
- **macOS Status**: Cubase already supports MIDI 2.0 high-res (CoreMIDI)

**Implementation**:
- **Priority**: CRITICAL (Q3 2026 deadline for Cubase MIDI 2.0 wave)
- **Version**: v0.4.0
- **Purpose**: Capability Inquiry for MIDI 2.0 device discovery
- **Fallback**: MIDI 1.0 for legacy DAWs without MIDI 2.0

**Why This Timeline Matters**:
- Windows MIDI 2.0 RC3 → stable in 1-2 months (March-April 2026)
- Cubase 15 will add MIDI 2.0 support 3-4 months after Windows stable (Q3 2026)
- OpenMIDIControl v0.4.0 must be ready by Q3 2026 to ride the Cubase MIDI 2.0 wave
- NI Kontrol S49 Mk3 already ships with MIDI 2.0 + MIDI-CI

**Example Implementation**:
```dart
// MIDI-CI Profile Discovery
class MidiCiNegotiator {
  Future<Midi2Profile> negotiate() async {
    // Send MIDI-CI Inquiry
    // Receive device capabilities
    // Negotiate MIDI 2.0 vs 1.0
    // Configure UMP transport
  }
}
```

**See**: ARCHITECTURE.md Section 13.4 for full rationale

## Safety & Compliance

- Do not include proprietary SDKs or copied code from restricted sources.
- Avoid bundling anything that would violate the dual-licensing intent (GPL-3.0 / commercial).
