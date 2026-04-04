# Contributing to OpenMIDIControl

## Licensing and Contributions

### Contributor Copyright

Contributors retain full copyright to their contributions. Your name and work will be permanently credited in the Git history.

By submitting a contribution, you grant Peters Digital a perpetual, worldwide, royalty-free, non-exclusive license to use, reproduce, modify, distribute, and sublicense your contribution under both:

* GNU General Public License v3.0 (GPLv3)
* Commercial License (LicenseRef-Commercial)

This license grant allows Peters Digital to maintain the project's dual-licensing model while ensuring contributors receive full credit for their work.

### Corporate / Commercial Use

This project's open source license (GPLv3) includes a "copyleft" provision: any company that modifies and distributes this software must also release their changes under GPLv3.

If a corporate entity wishes to use this software (including open source contributions) in a proprietary, closed-source, or commercial product without complying with GPLv3, they must obtain a commercial license from Peters Digital.

This ensures the project remains free and open for community contributors, while commercial companies cannot profit from community contributions without either contributing back or obtaining a commercial license.

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
CI will fail if files are missing headers. See [docs/LICENSING.md](docs/LICENSING.md) for details.

## Development approach
This project is maintained by Peters Digital and is primarily implemented with AI assistance. Human review is required for merges.

Current phase: foundational implementation and documentation. Prefer small, reviewable increments.

## Versioning
We use **Semantic Versioning (SemVer)**:
- `MAJOR`: incompatible changes
- `MINOR`: backwards-compatible features
- `PATCH`: backwards-compatible fixes

## Commit messages (Conventional Commits)

We use Conventional Commits enforced via **Commitlint** + **Husky**.

### Automatic Validation

When you commit, Husky will automatically validate your message:

```bash
git commit -m "feat(midi): add UMP reconstruction logic"
# ✅ Commit message is valid!
```

If the message is invalid, the commit will be rejected:

```bash
git commit -m "added some stuff"
# ✖   subject may not be empty [subject-empty]
# ✖   type must be one of the defined values [type-enum]
```

### Manual Format

Format:
`<type>[optional scope]: <description>`

Examples:
- `feat(android): add multi-touch fader control`
- `fix(midi): prevent feedback loop on CC echo`
- `docs: update roadmap`
- `chore(deps): update dependencies`

- `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`, `merge`

**Important**:
- **No version numbers in commit subjects**. Versioning is handled only through Git tags and `CHANGELOG.md` updates.
- Keep the title concise (imperative mood).
- **Multiple scopes**: Use forward slashes — `feat(ui/midi): …`. **No hyphens between scopes.**

### Local Validation (without committing)

You can test your commit message before committing:

```bash
# Windows PowerShell
"feat(midi): add UMP reconstruction logic" | Out-File -Encoding utf8 -NoNewline .commitlint-temp.txt
npx commitlint --edit .commitlint-temp.txt
Remove-Item .commitlint-temp.txt

# Unix/Bash
echo "feat(midi): add UMP reconstruction logic" | npx commitlint
```

### Setup (First Time Only)

After cloning the repository, install dependencies and git hooks:

```bash
# Install Node.js dependencies and set up husky hooks
npm install
```

This only needs to be done once per clone. The husky hooks will be automatically installed.

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
Use `gh` in terminal to create and manage PRs quickly.

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

### Hardware-in-the-Loop (HITL) Testing
For v0.2.0+, developers should validate the native Kotlin transport layer using `adb` and external MIDI tools:

1. **Native Log Monitoring:**
   ```bash
   # Filter for MIDI dispatcher and USB handshake events
   adb logcat | grep -i "openmidicontrol\|PeripheralMidi\|MidiDispatcher"
   ```

2. **Stimulating Inbound MIDI:**
   Use [Windows MIDI Services](https://microsoft.github.io/MIDI/tools/) to send raw bytes to the Android Peripheral:
   ```bash
   # Send Channel 1, CC 1 (Mod Wheel), Value 64
   midi endpoint send-message 0x20B00140
   ```

See `ARCHITECTURE.md` for the defensive architecture overview and `USERGUIDE.md` for end-user validation steps.