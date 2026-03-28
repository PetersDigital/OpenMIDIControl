# AGENTS.md

OpenMIDIControl is a performance-first, multi-touch MIDI control surface built with Flutter/Dart (UI) and Kotlin (native Android MIDI layer). Current milestone: **v0.2.2 – Native UMP Backend Migration**. See [IMPLEMENTATION.md](IMPLEMENTATION.md) for the full roadmap and [ARCHITECTURE.md](ARCHITECTURE.md) for system design.

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
| `app/android/.../VirtualMidiService.kt` | Virtual MIDI device for local routing |
| `app/android/.../PeripheralMidiService.kt` | USB class compliance service |

## Build & Test Commands

### Prerequisites
- Flutter 3.x (SDK ^3.11.0)
- Android Studio / Android SDK
- Android device with USB MIDI support (API 29+)
- PowerShell 7+ (for build scripts)

### Setup

```powershell
cd app
flutter pub get
```

### Run

```powershell
.\scripts\run_debug.ps1    # debug — interactive device picker
.\scripts\run_release.ps1  # release — requires configured scripts\.env.ps1
```

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
- **Native UMP (v0.2.2+):** The native layer enforces 32-bit Universal MIDI Packets (UMP). Due to SDK constraints, client ports use legacy classes but are opened with `TRANSPORT_UNIVERSAL_MIDI_PACKETS`. Developers must implement **manual 32-bit reconstruction** from `byte[]` buffers in `MidiReceiver.onSend()`.
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
- **Unit tests** for domain logic (`MidiEvent`, `ControlState`).
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
# Monitor native logs (look for "UMP Reconstruction" or "32-bit Payload")
adb logcat | Select-String "OpenMIDIControl|PeripheralMidi|MidiReceiver"

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

## Safety & Compliance

- Do not include proprietary SDKs or copied code from restricted sources.
- Avoid bundling anything that would violate the dual-licensing intent (GPL-3.0 / commercial).
