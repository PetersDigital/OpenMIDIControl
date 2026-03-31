# Release Workflow Implementation Plan

**Document Version:** 1.2
**Created:** 2026-03-31
**Updated:** 2026-03-31
**Author:** AI Assistant
**Status:** All Phases Implemented (Phase 3 Complete)

---

## Overview

This document outlines the three-phase implementation plan for automated release workflows in OpenMIDIControl. The system provides a complete release pipeline from development builds to stable releases.

---

## Release Types

| Type | Branch | Tag Format | Audience | Draft | Pre-release |
|------|--------|------------|----------|-------|-------------|
| **Beta** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-beta.{N}` | Internal testing | ✅ Yes | ❌ No |
| **RC** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-rc.{N}` | Public testing | ❌ No | ✅ Yes |
| **Stable** | `main` | `v{MAJOR}.{MINOR}.{PATCH}` | Production | ❌ No | ❌ No |
| **Hotfix** | `main` | `v{MAJOR}.{MINOR}.{PATCH}-patch.{N}` | Production (urgent) | ❌ No | ❌ No |

---

## Phase 1: Enhanced Beta Workflow

### Objective

Enhance existing `ci_beta.yml` with smart release automation based on commit message markers and auto-release thresholds.

### Files to Modify

- `.github/workflows/ci_beta.yml`
- `.github/actions/generate-release-notes/action.yml`

### Implementation Details

#### 1.1 Commit Message Markers

**Format:**
```bash
git commit -m "type(scope): description" -m "Extended description.

[beta]"
```

**Markers:**

| Marker | Build + Test | Create Release | Priority |
|--------|-------------|----------------|----------|
| `[wip]` | ✅ Yes | ❌ No | High (skip) |
| `[skip-release]` | ✅ Yes | ❌ No | High (skip) |
| `[beta]` | ✅ Yes | ✅ Yes | Medium (explicit) |
| (none) + 5+ commits | ✅ Yes | ✅ Yes | Low (auto) |
| (none) + <5 commits | ✅ Yes | ❌ No | Low (auto) |

**Priority Logic:**
```
1. Check skip markers ([wip], [skip-release]) → SKIP (safety first)
2. Check [beta] marker → CREATE RELEASE (explicit)
3. Check commit count (≥5) → CREATE RELEASE (auto)
4. Otherwise → SKIP (not enough changes)
```

#### 1.2 GitHub API Integration

**Problem:** Beta tags are not created in git (only GitHub release names), so `git describe --tags` cannot find previous releases.

**Solution:** Use GitHub CLI (`gh`) to query releases API.

**Implementation:**
```bash
# Find last beta release
LAST_BETA=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' | grep beta || echo "")

# If no beta, find last stable tag
if [ -z "$LAST_BETA" ]; then
  LAST_RELEASE=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)
else
  LAST_RELEASE="$LAST_BETA"
fi

# Generate changelog from that point
git log --oneline --pretty=format:"- %s" $LAST_RELEASE..HEAD
```

#### 1.3 Conventional Commit Parsing

**Parse commit types into changelog sections:**

| Commit Type | Changelog Section |
|-------------|-------------------|
| `feat`, `feature` | ### Added |
| `fix` | ### Fixed |
| `perf`, `refactor` | ### Changed |
| `docs` | ### Documentation |
| `test` | ### Testing |
| `chore`, `ci`, `build` | ### Maintenance |
| `break` | ### Breaking Changes |

**Example Output:**
```markdown
🚧 **Beta Release** - Release candidate for testing. Final changelog will be available on stable release.

### Changes since v0.2.2-beta.44

### Added
- feat(ui): add new fader component

### Fixed
- fix(midi): resolve UMP reconstruction bug
- fix(ci): improve build stability

### Maintenance
- chore(deps): update dependencies
- ci(workflow): optimize pipeline
```

#### 1.4 Beta Tag Naming

**Auto-generated (no manual tags):**
```bash
# Calculate beta number from commit count
BETA_NUM=$(git rev-list --count $LAST_STABLE..HEAD)
BETA_TAG="v{MAJOR}.{MINOR}.{PATCH}-beta.${BETA_NUM}"
```

**Example:**
- Last stable: `v0.2.2`
- Commits since: 45
- Generated tag: `v0.2.2-beta.45`

#### 1.5 Release Settings

| Setting | Value |
|---------|-------|
| Draft | `true` |
| Pre-release | `false` |
| Changelog | Incremental (since last beta) |
| Assets | APK + ZIP (signed + provenance) |

---

## Phase 2: Release Candidate (RC) Workflow

### Objective

Create separate workflow for RC releases that bridges beta testing and stable release.

### Files to Create

- `.github/workflows/ci_rc.yml`

### Implementation Details

#### 2.1 Trigger Mechanism

**Manual tag push (from beta branch):**
```bash
git checkout beta
git tag v0.2.2-rc.1
git push origin v0.2.2-rc.1
```

**Workflow trigger:**
```yaml
on:
  push:
    tags:
      - 'v*-rc.*'
```

#### 2.2 RC Changelog Logic

**First RC (rc.1):**
```bash
# Show ALL changes since last stable
LAST_STABLE=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)
git log --oneline $LAST_STABLE..HEAD
```

**Subsequent RCs (rc.2+):**
```bash
# Show changes since previous RC
PREV_RC=$(git describe --tags --match='v*-rc.*' --abbrev=0 | head -1)
git log --oneline $PREV_RC..HEAD
```

**Example:**
```markdown
## v0.2.2-rc.1
**Full release candidate for v0.2.2**

### All Changes since v0.2.2
- 45 commits from beta cycle
- New features, performance improvements, bug fixes

---

## v0.2.2-rc.2
**Second release candidate**

### Changes since v0.2.2-rc.1
- fix: RC1 crash on startup
- fix: MIDI port detection issue
```

#### 2.3 Release Settings

| Setting | Value |
|---------|-------|
| Draft | `false` (public) |
| Pre-release | `true` |
| Changelog | Full (rc.1) or Incremental (rc.2+) |
| Assets | APK + ZIP (signed + provenance) |

#### 2.4 RC Workflow Structure

```yaml
name: "CI: Release Candidate"

on:
  push:
    tags:
      - 'v*-rc.*'

jobs:
  verify-tag:
    # Validate tag format and signature
  
  analyze-and-test:
    # Same as beta workflow
  
  build-android:
    # Same as beta workflow
  
  build-windows:
    # Same as beta workflow (if applicable)
  
  provenance:
    # Same as beta workflow
  
  create-rc-release:
    # Create public pre-release
    # Changelog: full (rc.1) or incremental (rc.2+)
  
  notify-telegram:
    # Notify team of RC availability
```

---

## Phase 3: Hotfix/Patch Workflow (Future)

### Objective

Enable urgent fixes to stable releases without waiting for full release cycle.

### Files to Create (Future)

- `.github/workflows/ci_hotfix.yml`

### Implementation Details (Planned)

#### 3.1 Trigger Mechanism

**Manual tag push (from main branch):**
```bash
git checkout main
git commit -m "fix: critical bug fix"
git tag v0.2.2-patch.1
git push origin v0.2.2-patch.1
```

**Workflow trigger:**
```yaml
on:
  push:
    tags:
      - 'v*-patch.*'
```

#### 3.2 Use Cases

| Scenario | Example |
|----------|---------|
| Critical bug in stable | Crash on startup |
| Security vulnerability | Dependency CVE |
| Regression | Feature broken in last release |

#### 3.3 Release Settings

| Setting | Value |
|---------|-------|
| Draft | `false` |
| Pre-release | `false` |
| Changelog | Since last stable (or patch) |
| Assets | APK + ZIP (signed + provenance) |

#### 3.4 Patch Numbering

```bash
# Count patches since last stable
PATCH_NUM=$(git rev-list --count v0.2.2..HEAD | grep patch || echo "1")
PATCH_TAG="v0.2.2-patch.${PATCH_NUM}"
```

#### 3.5 Relationship to Stable

**After hotfix:**
- Patch release is published immediately
- Main branch updated with fix
- Next stable release (`v0.2.3`) includes patch

---

## Workflow Comparison

### Trigger Mechanisms

| Workflow | Trigger | Manual/Auto |
|----------|---------|-------------|
| Beta | Push to beta + markers | Auto |
| RC | Tag push (`v*-rc.*`) | Manual |
| Stable | Tag push (`v*.*.*`) | Manual |
| Hotfix | Tag push (`v*-patch.*`) | Manual |

### Changelog Sources

| Workflow | Source | Range |
|----------|--------|-------|
| Beta | GitHub API + git log | Since last beta |
| RC | GitHub API + git log | Since stable (rc.1) or prev RC (rc.2+) |
| Stable | CHANGELOG.md | Manual entry |
| Hotfix | GitHub API + git log | Since stable or prev patch |

### Release Visibility

| Workflow | Draft | Pre-release | Public |
|----------|-------|-------------|--------|
| Beta | ✅ Yes | ❌ No | ❌ Internal |
| RC | ❌ No | ✅ Yes | ✅ Yes |
| Stable | ❌ No | ❌ No | ✅ Yes |
| Hotfix | ❌ No | ❌ No | ✅ Yes |

---

## Developer Workflow Examples

### Beta Phase (Daily Development)

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

### RC Phase (Final Validation)

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

### Stable Phase (Production)

```bash
# Merge tested RC to main
git checkout main
git merge beta
git tag v0.2.2
git push origin v0.2.2
# → cd_prod_auto.yml creates stable release
# → Changelog from CHANGELOG.md
```

### Hotfix Phase (Urgent Fixes)

```bash
# Critical bug in stable
git checkout main
git commit -m "fix: critical startup crash"
git tag v0.2.2-patch.1
git push origin v0.2.2-patch.1
# → ci_hotfix.yml creates patch release

# Second hotfix (if needed)
git commit -m "fix: memory leak in MIDI parser"
git tag v0.2.2-patch.2
git push origin v0.2.2-patch.2
# → Shows changes since v0.2.2-patch.1
```

---

## Implementation Checklist

### Phase 1: Enhanced Beta (Current)

- [x] Update `ci_beta.yml` with marker detection
- [x] Add GitHub CLI authentication
- [x] Implement commit counting logic
- [x] Update `generate-release-notes` action for GitHub API
- [x] Add conventional commit parsing
- [x] Test all marker scenarios
- [x] Update documentation

**Status:** ✅ **COMPLETE** - Implemented in commit `434a82c`

### Phase 2: RC Workflow (Current)

- [x] Create `ci_rc.yml` workflow file
- [x] Implement RC tag detection
- [x] Add changelog logic (full vs incremental)
- [x] Configure release settings (public, pre-release)
- [x] Test RC.1 and RC.2+ scenarios
- [x] Add Telegram notification

**Status:** ✅ **COMPLETE** - Implemented

### Phase 3: Hotfix Workflow (Future)

- [x] Create `ci_hotfix.yml` workflow file
- [x] Implement patch tag detection
- [x] Add patch numbering logic
- [x] Configure release settings
- [x] Test hotfix scenarios
- [x] Document hotfix process

**Status:** ✅ **COMPLETE** - Implemented

---

## Technical Dependencies

### Required Tools

| Tool | Purpose | Available |
|------|---------|-----------|
| `gh` (GitHub CLI) | Release API queries | ✅ Pre-installed on runners |
| `git` | Tag/log operations | ✅ Available |
| `jq` | JSON parsing | ✅ Pre-installed |

### Required Permissions

```yaml
permissions:
  contents: write      # Create releases
  id-token: write      # Signing
  attestations: write  # Provenance
```

### Existing Actions (Reused)

- `.github/actions/flutter-ci-core` - CI setup
- `.github/actions/flutter-build-android` - Android build
- `.github/actions/flutter-build-windows` - Windows build
- `.github/actions/cosign-sign-verify` - Asset signing
- `.github/actions/provenance-attestation` - SLSA provenance
- `.github/actions/generate-release-notes` - Changelog generation
- `.github/actions/notify-telegram` - Notifications
- `.github/actions/download-and-prepare-artifacts` - Asset preparation

---

## Testing Strategy

### Unit Tests (Local)

```bash
# Test marker detection
bash scripts/test-release-notes.sh

# Test conventional commit parsing
# Test GitHub API queries
```

### Integration Tests (CI)

1. **Beta workflow:**
   - Push with `[beta]` marker → Release created
   - Push with `[wip]` marker → No release
   - Push 5 commits (no marker) → Auto-release
   - Push 3 commits (no marker) → No release

2. **RC workflow:**
   - Push `v0.2.2-rc.1` → Full changelog
   - Push `v0.2.2-rc.2` → Incremental changelog

3. **Hotfix workflow (Phase 3):**
   - Push `v0.2.2-patch.1` → Patch release

---

## Rollback Plan

### If Beta Workflow Fails

1. Revert `ci_beta.yml` changes
2. Use previous manual release process
3. Debug in isolated branch

### If RC Workflow Fails

1. Delete RC tag: `git tag -d v0.2.2-rc.1`
2. Delete GitHub release manually
3. Fix workflow, push new tag

### If Hotfix Workflow Fails (Phase 3)

1. Same as RC workflow
2. Use manual release process as fallback

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Beta release time | < 15 minutes | CI duration |
| RC release time | < 20 minutes | CI duration |
| Hotfix release time | < 15 minutes | CI duration (Phase 3) |
| Changelog accuracy | 100% correct | Manual review |
| Marker detection | 100% accurate | Test scenarios |

---

## Maintenance

### Regular Tasks

- [ ] Monitor CI duration
- [ ] Review changelog accuracy
- [ ] Update marker logic if needed
- [ ] Document edge cases

### Troubleshooting

**Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| Release not created | Marker not detected | Check commit message format |
| Wrong changelog range | GitHub API fails | Verify `gh auth` |
| Build fails | Action restoration | Check `.github/actions` checkout |

---

## Appendix A: Commit Message Examples

### Valid Formats

```bash
# Beta release
git commit -m "feat(ui): add new fader" -m "Implements hybrid touch fader.

[beta]"

# WIP (no release)
git commit -m "fix(midi): experimental fix" -m "Testing new approach.

[wip]"

# Skip release (complete but don't release)
git commit -m "docs: update README" -m "Minor updates.

[skip-release]"

# Auto-release (5+ commits, no marker)
git commit -m "fix: bug 1"
git commit -m "fix: bug 2"
git commit -m "fix: bug 3"
git commit -m "fix: bug 4"
git commit -m "fix: bug 5"
git push
```

### Invalid Formats

```bash
# Marker in title (not description)
git commit -m "fix: bug [beta]"  # ❌ Won't work

# Marker without -m flag
git commit -m "fix: bug" -m "[beta]"  # ✅ Correct
git commit -m "fix: bug [beta]"  # ❌ Wrong
```

---

## Appendix B: GitHub CLI Commands

### Find Last Release

```bash
# Last release (any type)
gh release list --limit 1 --json tagName --jq '.[0].tagName'

# Last beta release
gh release list --limit 10 --json tagName | grep beta | head -1

# Filter by pattern
gh release list --json tagName --jq '.[].tagName' | grep 'v0.2.2-beta' | tail -1
```

### Authentication

```yaml
- name: Authenticate GitHub CLI
  run: gh auth setup-git
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Appendix C: Changelog Generation Examples

### Beta Changelog (Incremental)

```markdown
🚧 **Beta Release** - Release candidate for testing.

### Changes since v0.2.2-beta.44

### Added
- feat(ui): add new fader component

### Fixed
- fix(midi): resolve UMP reconstruction bug
- fix(ci): improve build stability

### Maintenance
- chore(deps): update dependencies

---
### Build & Security Metadata
- **Tag:** v0.2.2-beta.45
- **Triggered By:** @dencelkbabu
- 🛡️ **Provenance:** GitHub Native SLSA Attestation
- 🔐 **Signatures:** Cosign (OIDC)
```

### RC Changelog (Full)

```markdown
## 🎯 Release Candidate: v0.2.2-rc.1

**This is a release candidate** - feature complete, ready for final testing.

### All Changes since v0.2.2

### Added
- feat(ui): add new fader component
- feat(midi): implement MIDI 2.0 support

### Fixed
- fix(midi): resolve UMP reconstruction bug
- fix(ci): improve build stability

### Changed
- perf(core): reduce latency by 20%

---
### Testing Focus
- [ ] USB Peripheral Mode stability
- [ ] MIDI 2.0 compatibility
- [ ] Performance under load

**If no critical issues found, this becomes v0.2.2 stable.**
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.2 | 2026-03-31 | AI Assistant | Phase 3 hotfix workflow implementation complete |
| 1.1 | 2026-03-31 | AI Assistant | Phase 1 & Phase 2 implementation complete |
| 1.0 | 2026-03-31 | AI Assistant | Initial implementation plan |

---

## Approval

**Status:** ✅ Approved for Implementation

**Next Steps:**
1. Implement Phase 1 (Enhanced Beta)
2. Test Phase 1 thoroughly
3. Implement Phase 2 (RC)
4. Test Phase 2 thoroughly
5. Document Phase 3 (Hotfix) for future implementation
