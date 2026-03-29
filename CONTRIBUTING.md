# Contributing to OpenMIDIControl

## Development approach
This project is maintained by Peters Digital and is primarily implemented with AI assistance. Human review is required for merges.

Current phase: foundational implementation and documentation. Prefer small, reviewable increments.

## Versioning
We use **Semantic Versioning (SemVer)**:
- `MAJOR`: incompatible changes
- `MINOR`: backwards-compatible features
- `PATCH`: backwards-compatible fixes

## Commit messages (Conventional Commits)
We use Conventional Commits:

Format:
`<type>[optional scope]: <description>`

Examples:
- `feat(android): add multi-touch fader control`
- `fix(midi): prevent feedback loop on CC echo`
- `docs: update roadmap`
- `chore(deps): update dependencies`

- `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`

**Important**:
- **No version numbers in commit subjects**. Versioning is handled only through Git tags and `CHANGELOG.md` updates.
- Keep the title concise (imperative mood).

## Release process

Releases are triggered by pushing **signed SemVer tags**:

```bash
git tag -s v0.2.1 -m "Release v0.2.1"
git push origin v0.2.1
```

1. Ensure the `CHANGELOG.md` is updated with the version header and changes.
2. Tag the commit on the `main` branch.
3. Tags must follow the `vX.Y.Z` format.

## Pull requests
- Keep PRs small and focused.
- Update `CHANGELOG.md` for user-visible changes.
- Include tests when feasible.

### Review bots & draft process
- Open PR as draft for in-progress feature updates.
- Assignee: `@dencelkbabu`.
- Reviewers: `@dencelkbabu`, `@copilot-pull-request-reviewer`, `@gemini-code-assist`.
- Labels: `draft`,`needs review`.
- When ready, convert draft to ready for review and remove `draft` label.

### GitHub CLI workflow
Use `gh` in terminal to create and manage PRs quickly (PowerShell + Unix syntax).

Windows PowerShell (line continuation with backtick `):

```powershell
# 1. Check out and push branch
git checkout feat-android-midi-v0.2.1
git push -u origin feat-android-midi-v0.2.1

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-v0.2.1 `
  --title "feat(midi): v0.2.1 milestone overhaul" `
  --body "Canonical 32-bit MidiEvent model, ControlState separation, MidiPortBackend abstraction" `
  --draft --assignee dencelkbabu --reviewer dencelkbabu `
  --label "draft,needs review"

# 3. Add bot reviewers in GitHub UI (if not automatic):
#   copilot-pull-request-reviewer, gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

Unix/Bash style (line continuation with backslash `\`):

```bash
# 1. Check out and push branch
git checkout feat-android-midi-v0.2.1
git push -u origin feat-android-midi-v0.2.1

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-v0.2.1 \
  --title "feat(midi): v0.2.1 milestone overhaul" \
  --body "Canonical 32-bit MidiEvent model, ControlState separation, MidiPortBackend abstraction" \
  --draft --assignee dencelkbabu --reviewer dencelkbabu \
  --label "draft,needs review"

# 3. Add bot reviewers in GitHub UI:
#   copilot-pull-request-reviewer, gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

## Reporting issues
Please include:
- OS (Windows 11 version)
- Android device model + Android version
- DAW and routing details
- Steps to reproduce + expected vs actual behavior

## Coding standards & patterns

### Defensive programming for MIDI reliability
All MIDI-related code should implement **value-based deduplication** to prevent feedback loops:

- **Caching**: Store the last-sent value for each message type/parameter
- **Comparison**: Check incoming values against cache before processing/forwarding
- **Time windows**: Use millisecond-level (not tick-based) timestamps for dedup checks; empirical safe window is 50ms
- **Multi-tier**: Apply dedup at multiple layers (UI logic, MIDI service, transport adapter) for robustness

Example (Dart):
```dart
// Bad (only checks lower 7 bits)
if (lastSent == value7Bit) return;

// Good (checks complete 14-bit value - MIDI 1.0)
final cachedValue14 = _cc14Cache[faderIndex];
if (cachedValue14 == value14Bit && timeSinceSent < 100ms) return;
_cc14Cache[faderIndex] = value14Bit;

// Good (checks full 32-bit native UMP value - MIDI 2.0)
final cachedValue32 = _umpCache[faderIndex];
if (cachedValue32 == value32Bit && timeSinceSent < 100ms) return;
_umpCache[faderIndex] = value32Bit;
```

### API specification verification
When modifying host integration or Android integration:
1. Verify against official host/API documentation (if available)
2. Test callback signatures against the documentation
3. Add defensive `if (obj && obj.mMethod)` guards for version compatibility
4. Document the exact line/signature from spec in adjacent comments

### State machine clarity
Prefer explicit state tracking over implicit logic:
- Use named flags for connection states (e.g., `handshakeConfirmed: bool`)
- Track per-object or per-command caches (e.g., `_nrpnStateCache: Map<String, int>`)
- Avoid side effects in dedup checks; separate concerns into dedicated methods
## Testing requirements (v0.2.2+)

### Automated Test Suite

All contributions must maintain or improve test coverage. The v0.2.2 test suite includes **10 comprehensive test files** covering all layers of the application.

See [TESTING.md](TESTING.md) for complete documentation on test structure and execution.

**Phase A: Kotlin Native Tests**
```powershell
cd app/android
.\gradlew.bat :app:testDebugUnitTest
```
Required for:
- Changes to `MidiParser.kt` (UMP reconstruction logic)
- Changes to native batching or filtering
- New MIDI message type handling

**Phase B: Dart Unit Tests**
```powershell
# Run all tests
cd app
flutter test

# Or run specific test files
flutter test test/midi_event_test.dart           # MidiEvent, Riverpod equality
flutter test test/midi_models_test.dart          # MidiPort, MidiStatus
flutter test test/control_state_test.dart        # ControlState, CcNotifier
flutter test test/diagnostics_test.dart          # DiagnosticsLoggerNotifier
flutter test test/settings_screen_test.dart      # Settings UI
flutter test test/midi_settings_screen_test.dart # MIDI Settings UI
flutter test test/midi_settings_state_test.dart  # Settings state
flutter test test/open_midi_screen_test.dart     # Main screen, faders
```
Required for:
- Changes to `MidiEvent` model
- Changes to `ControlState` or `CcNotifier`
- Riverpod provider modifications
- UMP transport logic
- UI component changes

**Phase C: Integration Tests**
```powershell
cd app
flutter test test/midi_pipeline_integration_test.dart
```
Required for:
- EventChannel bridge modifications
- High-frequency event handling changes
- State batching optimizations

### Test Writing Guidelines

**Kotlin Native Tests** (`app/android/app/src/test/kotlin/...`):
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

**Dart Unit Tests** (`app/test/`):
```dart
test('MidiEvent extracts channel from UMP', () {
  // Arrange
  const ump = 0x20B00140; // MT=2, Group=0, Status=0xB0, CC=1, Value=64
  
  // Act
  final event = MidiEvent(ump: ump, timestamp: 0, sourceId: 'test');
  
  // Assert
  expect(event.channel, 0);
  expect(event.data1, 1); // CC number
  expect(event.data2, 64); // CC value
});
```

### Hardware-in-the-Loop (HITL) Testing
For v0.2.0+, developers should validate the native Kotlin transport layer using `adb` and external MIDI tools:

1. **Native Log Monitoring:**
   ```powershell
   # Filter for MIDI dispatcher and USB handshake events
   adb logcat | Select-String "OpenMIDIControl|PeripheralMidi|MidiDispatcher"
   ```

2. **Stimulating Inbound MIDI:**
   Use [Windows MIDI Services](https://microsoft.github.io/MIDI/tools/) to send raw bytes to the Android Peripheral:
   ```bash
   # Send Channel 1, CC 1 (Mod Wheel), Value 64
   midi endpoint send-message 0x20B00140
   ```

See `ARCHITECTURE.md` for the defensive architecture overview and `USERGUIDE.md` for end-user validation steps.