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

### Recommended: Use the Interactive Commit Helper

We provide an interactive commit helper script to ensure all commits follow the correct format:

```bash
python scripts/commit.py
```

This script guides you through:
1. Selecting commit type (feat, fix, docs, etc.)
2. Selecting scope (android, ui, ci, scripts, etc.)
3. Entering description with validation
4. Optional body, breaking changes, and issue references
5. Preview and edit before committing
6. Automatic validation against commitlint

**Features:**
- Auto-suggests scope based on staged files
- Local validation before commitlint (no Node.js required)
- Full commitlint integration if available
- Merge commit support with branch-pattern scopes

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
# Using the interactive helper
python scripts/commit.py

# Or validate a message directly
echo "feat(midi): add UMP reconstruction logic" | npx commitlint
```

### Setup (First Time Only)

After cloning the repository, install dependencies and git hooks:

```bash
# Install Node.js dependencies and set up husky hooks
npm install
```

This only needs to be done once per clone. The husky hooks will be automatically installed.

### Script Dependencies

All scripts in `scripts/` require:
- **Python 3.9+** (stdlib only for most scripts)
- **Git** (for git-dependent scripts)

Optional dependencies for enhanced functionality:
- **commitlint** — Used by `commit.py` for validation (falls back to local regex if unavailable)
  - Install: `npm install @commitlint/cli @commitlint/config-conventional`
  - Or use via: `npx`, `pnpm`, or `yarn`
- **actionlint, yamllint** — Used by `validate_workflows.py` (optional)
- **Flutter SDK** — Required for `run_app.py`
- **GitHub CLI (`gh`)** — Required for `wipe_github_actions.py` scripts

See `scripts/README.md` for detailed dependency information.

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

## CI/CD Infrastructure

The repository uses modular GitHub Actions workflows and reusable composite actions. See [`.github/CI_CD_README.md`](.github/CI_CD_README.md) for complete documentation.

### Workflow Types

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `cd_auto_*` | Automated deployment on branch pushes | `cd_auto_dev.yml`, `cd_auto_prod.yml` |
| `cd_man_*` | Manual deployment (requires approval) | `cd_man_prod.yml`, `cd_man_hotfix.yml` |
| `ci_auto_*` | Automated integration testing | `ci_auto_main.yml`, `ci_auto_feature.yml` |
| `validate_*` | Code quality gates | `validate_auto_yaml.yml`, `validate_pr_commitlint.yml` |
| `ops_*` | Operational automation | `ops_schedule_stale.yml` |

### Validation Gates

All PRs must pass these automated checks:

1. **Flutter Analysis & Tests** - `flutter analyze --fatal-infos` + `flutter test`
2. **YAML Validation** - yamllint + actionlint for workflow correctness
3. **License Headers** - SPDX identifier validation across all source files
4. **Commit Messages** - Conventional Commits format enforcement

### Local Validation

Run these commands before pushing:

```bash
# Flutter analysis and tests
flutter analyze --fatal-infos
flutter test

# Validate workflow YAML
python scripts/validate_workflows.py .github/workflows/*.yml

# Check license headers
python scripts/check_license_headers.py

# Validate commit messages (after commit)
npx commitlint --from HEAD~3 --to HEAD --verbose
```

### Dependabot

Automated dependency updates are configured for:
- **GitHub Actions**: Monthly checks, `ci(actions)` commit prefix
- **Flutter/Pub**: Monthly checks, `chore(deps)` commit prefix

Dependabot PRs skip validation workflows to reduce CI noise.

### Composite Actions

The CI/CD pipeline uses 10 reusable composite actions in `.github/actions/`:
- `flutter-ci-core` - Shared Flutter setup, analysis, testing
- `cosign-sign-verify` - Keyless artifact signing
- `provenance-attestation` - SLSA provenance generation
- `flutter-build-android` - Android APK builds with keystore
- `flutter-build-windows` - Windows desktop builds
- `download-and-prepare-artifacts` - Artifact collection
- `generate-release-notes` - CHANGELOG parsing
- `notify-telegram` - Build notifications
- `release-tag-validation` - Release gate validation
- `prepare-release-assets` - Shared asset list generation for releases

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