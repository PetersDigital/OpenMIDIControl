# Contributing to OpenMIDIControl

## Licensing and Contributions

All contributions to this project are considered to be owned by Peters Digital.

By contributing, you agree that your contributions are licensed under:

* GNU General Public License v3.0 (GPLv3)
* Commercial License (LicenseRef-Commercial)

You grant Peters Digital the right to relicense your contributions under
both licenses.

### License Headers

All source files must include the dual-license header:

**Dart:**
```dart
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
```

**Kotlin:**
```kotlin
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol
```

To add headers to new files, run:
```powershell
.\scripts\add_all_license_headers.ps1
```

CI will fail if files are missing headers. See [docs/LICENSING.md](docs/LICENSING.md) for details.

## Development approach
This project is maintained by Peters Digital and is primarily implemented with AI assistance. Human review is required for merges.

Current phase: **v0.2.2 – Hybrid UMP Implementation**. Focus on stability, test coverage, and performance optimization. Prefer small, reviewable increments.

## CI/CD Workflows

OpenMIDIControl uses a comprehensive CI/CD system built on GitHub Actions. This section covers the essential information for contributors. For complete technical details, see [.github/GITHUB_ACTIONS_WORKFLOW.md](.github/GITHUB_ACTIONS_WORKFLOW.md).

### Branch Protection & Workflow Architecture

The project uses a **4-tier branch hierarchy** with automated quality gates:

```
┌─────────────────────────────────────────────────────────────┐
│                        main (Production)                     │
│  - Protected: Strictest rules                                │
│  - Trigger: Tags only (v1.0.0, v0.2.2, etc.)                │
│  - Output: Signed production releases                        │
│  - Direct commits: ❌ Never                                  │
└─────────────────────────────────────────────────────────────┘
                            ↑
                            │ Merge PR (tagged release)
                            │
┌─────────────────────────────────────────────────────────────┐
│                        beta (Release Candidate)              │
│  - Protected: Strict rules                                   │
│  - Trigger: Pushes to beta branch                            │
│  - Output: Draft GitHub pre-release + Telegram notification  │
│  - Direct commits: ❌ Never                                  │
└─────────────────────────────────────────────────────────────┘
                            ↑
                            │ Merge PR (RC preparation)
                            │
┌─────────────────────────────────────────────────────────────┐
│                        dev (Development)                     │
│  - Protected: Moderate rules                                 │
│  - Trigger: Pushes to dev branch                             │
│  - Output: Unsigned dev builds + Telegram notification       │
│  - Direct commits: ⚠️ Maintainers only (bypass allowed)      │
└─────────────────────────────────────────────────────────────┘
                            ↑
                            │ Merge PR (feature complete)
                            │
┌─────────────────────────────────────────────────────────────┐
│              feature (Any other branch name)                 │
│  - Protected: CI-only (no build artifacts)                   │
│  - Trigger: Any push to feature branches                     │
│  - Output: Fast feedback (analyze + test only)               │
│  - Direct commits: ✅ Yes (AI agents, developers)            │
│  - Naming: Arbitrary (no prefix pattern required)            │
└─────────────────────────────────────────────────────────────┘
```

**AI Agent Compatibility:** The CI system uses **exclusion logic** (not prefix patterns) to detect branch types. This means AI agents like Google Jules and GitHub Copilot can create branches with arbitrary names:
- `feat-native-android-ump-8916227028079091107`
- `fix-thermal-runaway-p0-9001081033840053369`
- `copilot-midi-parser-fix`
- `my-test-branch`

All are automatically treated as feature branches and receive fast CI-only feedback.

### Release Workflow (Phase 1-3 Complete)

The release system provides automated pipelines from development to stable releases with intelligent release decision-making.

#### Commit Message Markers (Beta Branch)

When pushing to the `beta` branch, use these markers to control release behavior:

| Marker | Build + Test | Create Release | When to Use |
|--------|-------------|----------------|-------------|
| `[wip]` | ✅ Yes | ❌ No | Work in progress, testing in progress |
| `[skip-release]` | ✅ Yes | ❌ No | Complete but not ready for beta release |
| `[beta]` | ✅ Yes | ✅ Yes | Explicit request for beta release |
| (none) + 5+ commits | ✅ Yes | ✅ Yes | Auto-release after 5+ commits |
| (none) + <5 commits | ✅ Yes | ❌ No | Not enough changes yet |

**Priority Logic:**
```
1. Check skip markers ([wip], [skip-release]) → SKIP (safety first)
2. Check [beta] marker → CREATE RELEASE (explicit)
3. Check commit count (≥5) → CREATE RELEASE (auto)
4. Otherwise → SKIP (not enough changes)
```

**Example:**
```bash
# Small fix (no release, just build/test)
git commit -m "fix(midi): reduce latency" -m "Testing new algorithm.

[wip]"
git push origin beta

# Feature complete (create beta release)
git commit -m "feat(ui): add new fader" -m "Implements hybrid touch fader.

[beta]"
git push origin beta

# Batch of 5 small fixes (auto-release)
git commit -m "fix: bug 1"
git commit -m "fix: bug 2"
git commit -m "fix: bug 3"
git commit -m "fix: bug 4"
git commit -m "fix: bug 5"
git push origin beta
# → Auto-creates beta release
```

#### Release Types

| Type | Branch | Tag Format | Trigger | Draft | Pre-release | Changelog Source |
|------|--------|------------|---------|-------|-------------|------------------|
| **Beta** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-beta.{N}` | Auto (markers) | ✅ Yes | ❌ No | Git (since last beta) |
| **RC** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-rc.{N}` | Manual tag | ❌ No | ✅ Yes | Git (full/incr) |
| **Stable** | `main` | `v{MAJOR}.{MINOR}.{PATCH}` | Manual tag | ❌ No | ❌ No | CHANGELOG.md |
| **Hotfix** | `main` | `v{MAJOR}.{MINOR}.{PATCH}-patch.{N}` | Manual tag | ❌ No | ❌ No | Git (since stable/patch) |

#### RC Workflow (Manual)

Release Candidates bridge beta testing and stable release:

```bash
# Feature complete, ready for public testing
git checkout beta
git tag v0.2.2-rc.1
git push origin v0.2.2-rc.1
# → Creates RC.1 release (public, pre-release)

# Fix bug found in RC1
git commit -m "fix: RC1 crash on startup"
git tag v0.2.2-rc.2
git push origin v0.2.2-rc.2
# → Creates RC.2 release (shows changes since RC.1)
```

#### Hotfix Workflow (Manual)

For urgent production fixes:

```bash
# Critical bug in stable
git checkout main
git commit -m "fix: critical startup crash"
git tag v0.2.2-patch.1
git push origin v0.2.2-patch.1
# → ci_hotfix.yml creates patch release
```

### Workflow Triggers Summary

| Workflow | Branch/Tag | Analyze | Test | Build | Sign | Release | Telegram |
|----------|------------|---------|------|-------|------|---------|----------|
| **Feature branches** | any except main/dev/beta | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **dev branch** | dev | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| **beta branch** | beta | ✅ | ✅ | ✅ | ✅ | Draft | ✅ |
| **main branch** | main/PRs | ✅ | ✅ | ✅ (debug) | ❌ | ❌ | ❌ |
| **Production tags** | `v*.*.*` on main | ✅ | ✅ | ✅ | ✅ | Public | ✅ |
| **RC tags** | `v*-rc.*` | ✅ | ✅ | ✅ | ✅ | Public | ✅ |
| **Hotfix tags** | `v*-patch.*` | ✅ | ✅ | ✅ | ✅ | Public | ✅ |

### Contributor Checklist

Before submitting a PR, ensure:

#### License Headers
- [ ] All source files include dual-license header:
  ```dart
  // Copyright (c) 2026 Peters Digital
  // SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
  ```
- [ ] Run `.\scripts\add_all_license_headers.ps1` for new files
- [ ] CI license check will fail if headers are missing

#### Tests Required
- [ ] **MIDI changes:** Kotlin native tests (`app/android/gradlew.bat :app:testDebugUnitTest`)
- [ ] **UI/State changes:** Dart unit tests (`flutter test test/`)
- [ ] **Bridge changes:** Integration tests (`flutter test test/midi_pipeline_integration_test.dart`)
- [ ] All tests pass locally before pushing

#### Conventional Commits
- [ ] Use proper format: `type(scope): description`
- [ ] Use proper scopes: `android/midi`, `ui/fader`, `core/state`, `test/midi`, etc.
- [ ] Multiple scopes: use forward slashes — `feat(ui/midi): …` (no hyphens)
- [ ] No version numbers in commit subjects
- [ ] For beta releases, add markers: `[beta]`, `[wip]`, or `[skip-release]`

#### PR Process
1. [ ] Create branch (any name, AI agents can use arbitrary names)
2. [ ] Make changes with proper commits
3. [ ] Run tests locally
4. [ ] Push branch → CI runs automatically
5. [ ] Create **draft PR** using GitHub CLI:
   ```powershell
   gh pr create --base main --head <branch> `
     --title "feat(midi): v0.2.2 hybrid UMP implementation" `
     --body "Manual 32-bit UMP reconstruction, primitive EventChannel batching" `
     --draft --assignee dencelkbabu --reviewer dencelkbabu `
     --label "draft,needs-review"
   ```
6. [ ] Wait for CI to pass
7. [ ] Convert from draft to ready for review
8. [ ] Address review feedback
9. [ ] Merge (requires approval + passing checks)

### Documentation References

- **Full CI/CD Guide:** [.github/GITHUB_ACTIONS_WORKFLOW.md](.github/GITHUB_ACTIONS_WORKFLOW.md)
- **Branch Strategy:** [.github/BRANCH_STRATEGY.md](.github/BRANCH_STRATEGY.md)
- **Composite Actions:** See `.github/actions/` directory
- **Workflow Files:** See `.github/workflows/` directory

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
- **Multiple scopes**: Use forward slashes — `feat(ui/midi): …`. **No hyphens between scopes.**

### Scope Guidelines (v0.2.2+)

Use these standardized scopes for commit messages:

| Scope | When to Use |
|-------|-------------|
| `android/midi` | Native Kotlin MIDI layer (`MidiParser.kt`, `MainActivity.kt`) |
| `android/ui` | Android-specific UI code (services, receivers) |
| `ui/midi` | Dart MIDI service layer (`midi_service.dart`) |
| `ui/fader` | Fader widgets (`hybrid_touch_fader.dart`) |
| `core/midi` | Core MIDI models (`midi_event.dart`) |
| `core/state` | State management (`control_state.dart`, Riverpod providers) |
| `test/midi` | MIDI test suites (UMP transport tests) |
| `docs` | Documentation updates |
| `build` | Build configuration (Gradle, pubspec) |
| `ci` | CI/CD workflows |

Examples:
- `feat(midi/bridge): optimize EventChannel JNI bridge with primitive batching`
- `fix(android/midi): enhance isUmp detection with MT heuristic`
- `test(midi/pipeline): implement automated UMP transport test suite`

## Release process

Releases are triggered by pushing **signed SemVer tags**:

Windows PowerShell 7:
```powershell
git tag -s v0.2.2 -m "Release v0.2.2"
git push origin v0.2.2
```

Unix/macOS/Linux:
```bash
git tag -s v0.2.2 -m "Release v0.2.2"
git push origin v0.2.2
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
git checkout feat-android-midi-v0.2.2
git push -u origin feat-android-midi-v0.2.2

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-v0.2.2 `
  --title "feat(midi): v0.2.2 hybrid UMP implementation" `
  --body "Manual 32-bit UMP reconstruction, primitive EventChannel batching, automated test suite" `
  --draft --assignee dencelkbabu --reviewer dencelkbabu `
  --label "draft,needs-review"

# 3. Add bot reviewers in GitHub UI (if not automatic):
#   copilot-pull-request-reviewer, gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

Unix/Bash style (line continuation with backslash `\`):

```bash
# 1. Check out and push branch
git checkout feat-android-midi-v0.2.2
git push -u origin feat-android-midi-v0.2.2

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-v0.2.2 \
  --title "feat(midi): v0.2.2 hybrid UMP implementation" \
  --body "Manual 32-bit UMP reconstruction, primitive EventChannel batching, automated test suite" \
  --draft --assignee dencelkbabu --reviewer dencelkbabu \
  --label "draft,needs-review"

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

### Hybrid UMP Implementation (v0.2.2)

**Critical**: This project uses a **hybrid UMP architecture** instead of native `MidiUmpDeviceService`. Contributors must understand:

**Why Hybrid?**
- `MidiUmpDeviceService` requires Android 15+ (API 35) and is feature-flagged
- Hybrid provides 90% device coverage (Android 13-15) vs. 20% for native UMP

**Implementation Pattern**:
```kotlin
// Native Kotlin: Manual 32-bit UMP reconstruction
val umpInt = (byte1 shl 24) or (byte2 shl 16) or (byte3 shl 8) or byte4

// Dart: Bitwise extraction from 32-bit UMP
int get messageType => (ump >> 28) & 0xF;
int get channel => (ump >> 16) & 0x0F;
int get data1 => (ump >> 8) & 0xFF;   // CC number
int get data2 => ump & 0xFF;          // CC value
```

**Key Files**:
- `MidiParser.kt`: UMP reconstruction, real-time filtering
- `midi_event.dart`: 32-bit UMP model with bitwise getters
- `midi_service.dart`: EventChannel primitive batching (`LongArray`)

**Do NOT**:
- Migrate to `MidiUmpDeviceService` without explicit TDR approval
- Change UMP reconstruction logic without test coverage
- Remove bounds checking in native layer

See `ARCHITECTURE.md` Section 3.2 and TDR-001 in `AGENTS.md` for full rationale.

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

### Thermal Stability Patterns (v0.2.2+)

Learned from thermal runaway fix (commit b3d0dc6):

**Stream Lifecycle Management**:
```dart
// ✅ GOOD: late final ensures single allocation
late final Stream<dynamic> _rawStream = _eventsChannel
    .receiveBroadcastStream()
    .asBroadcastStream();

// ❌ BAD: Lazy getter can cause multiple subscriptions
Stream<dynamic> get _rawStream {
  _broadcastStream ??= ... // Can leak!
}
```

**State Update Guards**:
```dart
// ✅ GOOD: Check for actual changes before state mutation
void updateMultipleCCs(Map<int, int> updates) {
  var hasChanges = false;
  for (final entry in updates.entries) {
    if (state.ccValues[entry.key] != entry.value) {
      hasChanges = true;
      break;
    }
  }
  if (!hasChanges) return; // Skip redundant rebuilds
  // ... update state
}
```

**Throttling High-Frequency Events**:
```dart
// ✅ GOOD: 8ms throttle (~120Hz max)
int _lastMidiUpdateTimeMs = 0;
static const _midiUpdateThrottleMs = 8;

void _sendMidiUpdateThrottled() {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (nowMs - _lastMidiUpdateTimeMs < _midiUpdateThrottleMs) return;
  _lastMidiUpdateTimeMs = nowMs;
  _sendMidiUpdate();
}
```

**Batching Diagnostics Updates**:
```dart
// ✅ GOOD: Schedule for next frame (~60Hz)
bool _pendingUpdate = false;
SchedulerBinding.instance.scheduleFrameCallback((_) {
  _pendingUpdate = false;
  state = _logs.toList(); // Single batch update
});
```

**Avoid Global Watch at App Root**:
```dart
// ❌ BAD: Causes full-tree rebuilds on every MIDI event
class _MyAppState extends ConsumerState<MyApp> {
  Widget build(BuildContext context) {
    ref.watch(connectedMidiDeviceProvider); // Triggers rebuild!
    return MaterialApp(...);
  }
}

// ✅ GOOD: Remove watch from root, let children subscribe
class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(...); // No ref.watch here
  }
}
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

All contributions must maintain or improve test coverage. The v0.2.2 test suite has three phases:

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
cd app
flutter test test/midi_event_test.dart
flutter test test/midi_pipeline_integration_test.dart
```
Required for:
- Changes to `MidiEvent` model
- Changes to `ControlState` or `CcNotifier`
- Riverpod provider modifications
- UMP transport logic

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

For native layer changes, validate with physical MIDI hardware:

**Windows PowerShell:**

1. **Native Log Monitoring**:
   ```powershell
   adb logcat | Select-String "openmidicontrol|MidiParser|MidiReceiver"
   ```

2. **Stimulating Inbound MIDI** (Windows MIDI Services):
   ```powershell
   # Send Channel 1, CC 1 (Mod Wheel), Value 64
   midi endpoint send-message 0x20B00140
   ```

3. **Thermal Stability Validation**:
   - Run app for 5+ minutes with continuous MIDI automation
   - Monitor device temperature (should not overheat)
   - Verify no thermal throttling or frame drops

**Unix/macOS/Linux:**

1. **Native Log Monitoring**:
   ```bash
   adb logcat | grep -E "openmidicontrol|MidiParser|MidiReceiver"
   ```

2. **Stimulating Inbound MIDI** (Windows MIDI Services on remote PC):
   ```bash
   # Send Channel 1, CC 1 (Mod Wheel), Value 64
   midi endpoint send-message 0x20B00140
   ```

### Performance Benchmarks

For performance-sensitive changes, validate:

| Metric | Target | Measurement |
|--------|--------|-------------|
| UMP reconstruction latency | <0.5ms | Native timestamps |
| UI rebuild frequency | ≤120Hz | Flutter DevTools |
| GC allocation per batch | <100KB | Android Profiler |
| Idle CPU usage | ~0% | `adb shell top` |
| Thermal stability | No throttling | 5+ min continuous use |

See `TESTING.md` for complete test suite architecture and `ARCHITECTURE.md` for defensive architecture overview.