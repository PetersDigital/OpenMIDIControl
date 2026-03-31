# GitHub Actions Workflows Guide

**Created:** 2026-03-30  
**Last Updated:** 2026-03-30  
**Owner:** @dencelkbabu  
**Related:** `BRANCH_STRATEGY.md`, `.github/workflows/`, `.github/actions/`

---

## 📋 Overview

This document provides a comprehensive guide to the GitHub Actions CI/CD workflows for OpenMIDIControl. The workflows follow a **three-tier branch hierarchy** with automated quality gates, optimized for AI-assisted development (Google Jules, GitHub Copilot) and human contributors.

All workflows are built using **modular composite actions** to ensure DRY (Don't Repeat Yourself) principles, consistency, and maintainability.

---

## 🎯 Objectives

1. **Protect production code** - `main` branch contains only stable, tested releases
2. **Enable rapid development** - `dev` branch for daily builds and testing
3. **Support release candidates** - `beta` branch for pre-release validation
4. **Optimize CI costs** - Feature branches get CI-only (no builds)
5. **AI agent compatibility** - Works with arbitrary branch names from Jules/Copilot
6. **Automated distribution** - Telegram notifications for dev builds, GitHub Releases for beta/prod

---

## 🌿 Branch Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                        main (Production)                     │
│  - Protected: Strictest rules                                │
│  - Trigger: Tags only (v1.0.0, v1.0.1, etc.)                │
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
│  - Examples (Jules/Copilot/human):                           │
│    - feat-native-android-ump-8916227028079091107            │
│    - fix-thermal-runaway-p0-9001081033840053369             │
│    - feature-v0.2.2-kickoff-ump-migration-646109743629118176 │
│    - feat-ump-ready-data-models-4322345032997536709         │
│    - copilot-midi-parser-fix                                  │
│    - my-test-branch                                           │
└─────────────────────────────────────────────────────────────┘
```

**Definition:** A "feature branch" is any branch that is NOT named `main`, `dev`, or `beta`. The CI system uses **exclusion logic** (not prefix patterns) to detect these branches, so AI agents like Jules and Copilot can create branches with arbitrary names.

---

## 🔒 Branch Protection Rules

### Rule 1: `main` (Production)

| Setting | Value |
|---------|-------|
| **Branch name pattern** | `main` |
| Require a pull request before merging | ✅ Enabled |
| Require approvals | 1 |
| Dismiss stale pull request approvals when new commits are pushed | ✅ Enabled |
| Require status checks to pass before merging | ✅ Enabled |
| → Required status checks | `analyze-and-test` |
| Require branches to be up to date before merging | ✅ Enabled |
| Require signed commits | ✅ Enabled |
| Require linear history | ❌ Disabled |
| Require merge queue | ❌ Disabled |
| Do not allow bypassing the above settings | ✅ Enabled |
| Include administrators | ✅ Enabled |
| Allow force pushes | ❌ Disabled |
| Allow deletions | ❌ Disabled |

---

### Rule 2: `dev` (Development)

| Setting | Value |
|---------|-------|
| **Branch name pattern** | `dev` |
| Require a pull request before merging | ✅ Enabled |
| Require approvals | ❌ Disabled (or 1) |
| Require status checks to pass before merging | ✅ Enabled |
| → Required status checks | `analyze-and-test` |
| Require branches to be up to date before merging | ❌ Disabled |
| Require signed commits | ❌ Disabled |
| Do not allow bypassing the above settings | ❌ Disabled |
| Include administrators | ❌ Disabled |
| Allow force pushes | ❌ Disabled |
| Allow deletions | ❌ Disabled |

---

### Rule 3: `beta` (Release Candidate)

| Setting | Value |
|---------|-------|
| **Branch name pattern** | `beta` |
| Require a pull request before merging | ✅ Enabled |
| Require approvals | ✅ 1 |
| Dismiss stale pull request approvals when new commits are pushed | ✅ Enabled |
| Require status checks to pass before merging | ✅ Enabled |
| → Required status checks | `analyze-and-test` |
| Require branches to be up to date before merging | ✅ Enabled |
| Require signed commits | ✅ Enabled |
| Do not allow bypassing the above settings | ✅ Enabled |
| Include administrators | ✅ Enabled |
| Allow force pushes | ❌ Disabled |
| Allow deletions | ❌ Disabled |

---

## 🔄 CI/CD Workflow Architecture

### Workflow Matrix

| Workflow | Branch/Tag | Analyze | Test | Build | Sign | Provenance | GitHub Release | Telegram |
|----------|------------|---------|------|-------|------|------------|----------------|----------|
| `ci_feature.yml` | any except main/dev/beta | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `ci_dev.yml` | dev | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `ci_beta.yml` | beta | ✅ | ✅ | ✅ | ✅ | ✅ | Draft (pre-release) | ✅ |
| `ci_main.yml` | main/PRs | ✅ | ✅ | ✅ (debug) | ❌ | ❌ | ❌ | ❌ |
| `cd_prod_auto.yml` | tags on main | ✅ | ✅ | ✅ | ✅ | ✅ | Public | ✅ |
| `cd_prod_man.yml` | manual tag | ✅ | ✅ | ✅ | ✅ | ✅ | Public | ✅ |
| `cd_prod_retro.yml` | legacy tag | ✅ | ✅ | ✅ | ✅ | ✅ | Public | ✅ |
| `validate_workflows.yml` | .github changes | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `license_check.yml` | all branches | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

### Workflow Details

#### 1. `ci_feature.yml` (Feature Branch CI)

**Purpose:** Fast feedback for AI agents (Jules, Copilot) and human developers working on arbitrary-named branches.

**Triggers:**
```yaml
on:
  push:
    branches:
      - '**'
      - '!main'
      - '!dev'
      - '!beta'
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**
- `analyze-and-test` (Ubuntu, ~5-10 min)
  - Flutter analyze
  - Unit tests
  - Widget tests
  - **No build artifacts**

**Outputs:**
- GitHub Checks API status (pass/fail)

**Notifications:** None (check GitHub PR status)

**Branch Detection Logic:**
The workflow uses **exclusion logic** to identify feature branches:
- If branch is `main` → `ci_main.yml` handles it
- If branch is `dev` → `ci_dev.yml` handles it
- If branch is `beta` → `ci_beta.yml` handles it
- **Any other name** → This workflow (`ci_feature.yml`) handles it

This approach supports AI agents (Jules, Copilot) that create branches with arbitrary names based on task context, without requiring predictable prefix patterns.

---

#### 2. `ci_dev.yml` (Development Branch CI/CD)

**Purpose:** Continuous development builds for testing on devices.

**Triggers:**
```yaml
on:
  push:
    branches: [dev]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**
- `analyze-and-test` (Ubuntu, ~10-15 min)
  - Flutter analyze
  - Unit tests
  - Widget tests
- `build-and-push-dev` (Ubuntu, ~15-20 min)
  - Flutter build APK (release, split per ABI)
  - **No signing** (dev only)
  - Artifact naming: `app-dev-<commit>.apk`

**Outputs:**
- APK artifacts (GitHub Actions)

**Notifications:**
- ✅ Telegram: Dev build ready (APK attached)
- ❌ No GitHub Release

---

#### 3. `ci_beta.yml` (Beta Branch CI/CD - Release Candidates)

**Purpose:** Pre-release builds for stakeholder testing and RC validation.

**Triggers:**
```yaml
on:
  push:
    branches: [beta]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**
- `analyze-and-test` (Ubuntu, ~10-15 min)
  - Flutter analyze
  - Unit tests
  - Widget tests
- `build-rc` (Ubuntu, ~15-20 min)
  - Flutter build APK (release, split per ABI)
  - Flutter build Windows ZIP (release)
  - **Cosign signing** (artifacts)
  - **Provenance attestation** (SLSA)
  - Auto-generates beta tag: `vX.Y.Z-beta.N`
- `create-draft-release` (Ubuntu, ~2-5 min)
  - GitHub Release (draft/pre-release)
  - Upload signed artifacts
- `notify-telegram` (Ubuntu, ~1 min)
  - Telegram notification with download links

**Outputs:**
- Signed APK + ZIP artifacts
- GitHub Draft Release (pre-release)

**Notifications:**
- ✅ Telegram: RC build ready (links to GitHub Release)
- ✅ GitHub: Draft Release created (pre-release flag)

---

#### 4. `ci_main.yml` (Main Branch CI)

**Purpose:** Quality gate for PRs targeting `main` and pushes to `main`.

**Triggers:**
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches: [main]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**
- `dependency-review` (Ubuntu, ~5 min)
  - Dependency vulnerability scan
  - License compliance check
- `analyze-and-test` (Ubuntu, ~10-15 min)
  - Flutter analyze
  - Unit tests
  - Widget tests
- `build-android` (Ubuntu, ~15-20 min) - Push only
  - Debug APK build (validation)
- `build-windows` (Windows, ~20-25 min) - Push only
  - Windows build (validation)

**Outputs:**
- GitHub Checks API status (required for PR merge)

**Notifications:**
- ❌ None (PR status checks only)

---

#### 5. `cd_prod_auto.yml` (Automated Production Release)

**Purpose:** Full production release on version tag push.

**Triggers:**
```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'
```

**Jobs:**
- `verify-tag-on-main` (Ubuntu, ~5 min)
  - Tag format validation
  - GPG signature verification
  - Confirm tag is on `main` branch
- `analyze-and-test` (Ubuntu, ~10-15 min)
  - Flutter analyze
  - Unit tests
  - Widget tests
- `build-android` (Ubuntu, ~15-20 min)
  - Release APK (signed with keystore)
  - Cosign signing
- `build-windows` (Windows, ~20-25 min)
  - Release ZIP (signed)
  - Cosign signing
- `provenance` (Ubuntu, ~5 min)
  - SLSA provenance attestation
- `publish-release` (Ubuntu, ~5 min)
  - GitHub Release (public)
  - Upload all artifacts
- `notify-release` (Ubuntu, ~1 min)
  - Telegram announcement

**Outputs:**
- Signed production artifacts
- Public GitHub Release
- Telegram announcement

---

#### 6. `cd_prod_man.yml` (Manual Production Rebuild)

**Purpose:** Rebuild existing production tags (e.g., for CI migration or asset recovery).

**Triggers:**
```yaml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Tag to rebuild (e.g., v1.0.2)"
        required: true
      force:
        description: "Force overwrite existing release assets"
        required: false
        default: false
```

**Jobs:** Same as `cd_prod_auto.yml`

---

#### 7. `cd_prod_retro.yml` (Legacy Production Rebuild)

**Purpose:** Rebuild old tags (pre-signing era) with modern CI actions.

**Triggers:**
```yaml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Tag to rebuild (e.g., v0.2.1)"
        required: true
      force:
        description: "Force overwrite existing release assets"
        required: false
        default: false
```

**Jobs:** Same as `cd_prod_auto.yml` + restores modern actions from `main`

---

#### 8. `validate_workflows.yml` (Workflow Validation)

**Purpose:** Lint YAML and validate GitHub Actions syntax.

**Triggers:**
```yaml
on:
  pull_request:
    paths: ['.github/**']
  push:
    branches: [main]
    paths: ['.github/**']
```

**Jobs:**
- `yaml-lint` (Ubuntu, ~2 min)
  - YAML syntax validation
- `actionlint` (Ubuntu, ~2 min)
  - GitHub Actions schema validation

---

#### 9. `license_check.yml` (License Header Check)

**Purpose:** Automated check for dual-license headers in all source files.

**Triggers:**
```yaml
on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']
```

**Jobs:**
- `license-check` (Ubuntu, ~2 min)
  - Runs `scripts/check_license_headers.sh`

---

## 🧩 Composite Actions

### Structure

```
.github/
├── actions/
│   ├── flutter-ci-core/           # Setup, analysis, and testing
│   ├── release-tag-validation/    # Tag security validation
│   ├── cosign-sign-verify/        # Keyless artifact signing
│   ├── provenance-attestation/    # SLSA provenance generation
│   ├── flutter-build-android/     # Android APK build with keystore
│   ├── flutter-build-windows/     # Windows build with ZIP packaging
│   ├── generate-release-notes/    # Changelog extraction for releases
│   ├── notify-telegram/           # Telegram notifications
│   └── download-and-prepare-artifacts/  # Artifact download helper
└── workflows/
    ├── ci_feature.yml
    ├── ci_dev.yml
    ├── ci_beta.yml
    ├── ci_main.yml
    ├── cd_prod_auto.yml
    ├── cd_prod_man.yml
    ├── cd_prod_retro.yml
    ├── validate_workflows.yml
    └── license_check.yml
```

---

### Key Composite Actions

#### `flutter-build-android`

**Purpose:** Centralizes Android APK build logic including keystore configuration.

**Inputs:**
- `working-directory` - Flutter project path
- `keystore-base64` - Base64-encoded Android keystore
- `key-password`, `key-alias`, `store-password` - Keystore credentials
- `build-type` - `release`, `debug`, or `profile`
- `split-per-abi` - Build separate APKs per ABI

**Outputs:**
- `apk-path` - Full path to the built APK
- `apk-name` - Name of the APK file

---

#### `flutter-build-windows`

**Purpose:** Centralizes Windows build and ZIP packaging logic.

**Inputs:**
- `working-directory` - Flutter project path
- `build-type` - `release`, `debug`, or `profile`
- `artifact-name` - Custom output ZIP name

**Outputs:**
- `zip-path` - Full path to the created ZIP archive
- `zip-name` - Name of the ZIP file

---

#### `notify-telegram`

**Purpose:** Centralizes Telegram notification logic for all workflow types.

**Inputs:**
- `telegram-token`, `telegram-chat-id` - Bot credentials
- `notification-type` - `ci-failure`, `release`, `dev-build`, `rc-build`
- `tag` - Release tag (for release notifications)
- `branch` - Branch name (for dev/CI notifications)
- `status` - `success` or `failure`
- `artifact-path` - Path to artifact file (for dev builds)
- `changelog` - Changelog text (for dev build captions)

---

#### `cosign-sign-verify`

**Purpose:** Keyless signing for artifact security (SLSA compliance).

**Inputs:**
- `artifact_path` - Path to artifact to sign
- `repository` - GitHub repository for keyless identity

---

#### `provenance-attestation`

**Purpose:** Generates SLSA provenance attestations for build artifacts.

**Inputs:**
- `subject_path` - Path pattern to artifacts

---

## 📈 CI Cost Optimization

### Before Implementation

| Scenario | CI Time | Build Time | Cost/Run |
|----------|---------|------------|----------|
| Feature branch push | ~25 min | ~20 min | High |
| Dev branch push | ~25 min | ~20 min | High |
| Beta branch push | N/A | N/A | N/A |
| Main branch push | ~30 min | ~25 min | High |

**Monthly Estimate:** ~50 runs × 25 min = **1,250 minutes**

---

### After Implementation

| Scenario | CI Time | Build Time | Cost/Run |
|----------|---------|------------|----------|
| Feature branch push | ~8 min | 0 min | Low |
| Dev branch push | ~25 min | ~20 min | High |
| Beta branch push | ~30 min | ~25 min | High |
| Main branch push | ~30 min | ~25 min | High |

**Monthly Estimate:**
- Feature branches: ~40 runs × 8 min = 320 min
- Dev branch: ~8 runs × 25 min = 200 min
- Beta branch: ~4 runs × 30 min = 120 min
- Main branch: ~4 runs × 30 min = 120 min
- **Total: ~760 minutes** (39% reduction)

---

## 🔐 Security Considerations

### Artifact Signing

**Dev builds:** No signing (fast iteration)

**Beta builds:** Cosign signing (keyless)
- Provenance attestation (SLSA)
- Verifiable build origin

**Production builds:** Cosign signing + keystore
- Full supply chain security
- SLSA Level 3 compliance target

---

### GPG Commit Signing

**Required for:** `main`, `beta`

**Not required for:** `dev`, feature branches

**Setup:**
```bash
git config --global user.signingkey <YOUR_GPG_KEY_ID>
git config --global commit.gpgsign true
```

---

### Secret Management

**Required Secrets:**
- `TELEGRAM_TOKEN` - Bot token for notifications
- `TELEGRAM_CHAT_ID` - Target chat/group ID
- `KEYSTORE_BASE64` - Android signing keystore
- `KEY_PASSWORD`, `KEY_ALIAS`, `STORE_PASSWORD` - Keystore credentials
- `GPG_PUBLIC_KEY` - GPG key for tag verification
- `EXPECTED_GPG_FINGERPRINT` - Expected fingerprint
- `GITHUB_TOKEN` - Auto-provided by GitHub Actions

**Secret Rotation:**
- Telegram tokens: Every 6 months
- Keystore: Never (backup securely)
- GPG keys: Every 1-2 years

---

## 🎯 AI Agent Integration

### Google Jules Workflow

**Branch Naming:** Arbitrary (task-based, no pattern)
- Examples: `feat-native-android-ump-8916227028079091107`, `fix-thermal-runaway-p0-9001081033840053369`

**CI Behavior:**
- ✅ Triggers `ci_feature.yml` on push
- ✅ Runs analyze + test only (~5-10 min)
- ❌ No build artifacts (saves CI minutes)
- ✅ Fast feedback for iterative development

**PR Workflow:**
1. Jules completes task → pushes to branch (any name)
2. CI runs automatically via `ci_feature.yml`
3. Human reviews PR (if tests pass)
4. Merge to `dev` → triggers `ci_dev.yml` (full build)

---

### GitHub Copilot Workflow

**Branch Naming:** Arbitrary (task-based, no pattern)
- Examples: `copilot-fix-midi-parser`, `feature-new-fader`

**CI Behavior:** Same as Jules (triggers `ci_feature.yml`)

---

### Human Developer Workflow

**Branch Naming:** Any pattern (no restrictions)
- Examples: `my-feature`, `bugfix-123`, `experimental`

**CI Behavior:** Same as AI agents (triggers `ci_feature.yml`)

---

## 🧪 Testing & Validation

### Feature Branch CI Test

```bash
git checkout -b test-branch-123
# Make a small change
git commit -m "test: CI feature branch trigger"
git push -u origin test-branch-123
```

**Expected:**
- ✅ `ci_feature.yml` triggers
- ✅ `analyze-and-test` job runs
- ❌ No build jobs
- ✅ GitHub Checks API shows status

---

### Dev Branch CI/CD Test

```bash
git checkout dev
# Make a small change
git commit -m "test: CI dev branch trigger"
git push -u origin dev
```

**Expected:**
- ✅ `ci_dev.yml` triggers
- ✅ `analyze-and-test` job runs
- ✅ `build-and-push-dev` job runs
- ✅ APK artifact created
- ✅ Telegram notification received

---

### Beta Branch CI/CD Test

```bash
git checkout beta
# Make a small change
git commit -m "test: CI beta branch trigger"
git push -u origin beta
```

**Expected:**
- ✅ `ci_beta.yml` triggers
- ✅ `analyze-and-test` job runs
- ✅ `build-rc` job runs
- ✅ Signed artifacts created
- ✅ GitHub Draft Release created (pre-release)
- ✅ Telegram notification received

---

### Main Branch CI Test

```bash
git checkout main
# Create a PR from a feature branch
# Merge PR to main
```

**Expected:**
- ✅ `ci_main.yml` triggers on PR
- ✅ `dependency-review` job runs
- ✅ `analyze-and-test` job runs
- ✅ Status check appears in PR
- ✅ Merge blocked if CI fails

---

## 🛠️ Troubleshooting

### Common Issues

**Issue:** `Error: Input required and not supplied: keystore-base64`
- **Solution:** Ensure the secret is defined in repository settings

**Issue:** `Error: Unable to find artifact`
- **Solution:** Check that the artifact was uploaded with the expected name pattern

**Issue:** `Error: Tag signature invalid`
- **Solution:** Verify GPG key setup and that the tag was created with the correct key

**Issue:** Composite action not found
- **Solution:** Ensure the path is relative to the repository root (e.g., `./.github/actions/...`)

**Issue:** Workflow doesn't trigger on branch push
- **Solution:** Verify branch name matches trigger pattern (check exclusion logic for feature branches)

---

## 📝 Best Practices

1. **Keep actions focused:** Each composite action should do one thing well
2. **Use outputs:** Pass data between jobs via outputs, not artifacts when possible
3. **Document inputs/outputs:** Every input and output should have a description
4. **Default values:** Provide sensible defaults for optional inputs
5. **Error handling:** Include validation and clear error messages in actions
6. **Security:** Never log secrets; use environment variables for sensitive data
7. **Action pinning:** Always pin actions to SHA versions (not tags)
8. **Concurrency:** Use concurrency groups to cancel redundant workflow runs
9. **Permissions:** Declare minimum required permissions per workflow
10. **Timeouts:** Set reasonable timeouts to prevent hung workflows

---

## 📚 Migration Checklist

When creating new workflows or modifying existing ones:

- [ ] Use `flutter-build-android` instead of manual keystore + build steps
- [ ] Use `flutter-build-windows` instead of manual build + ZIP steps
- [ ] Use `generate-release-notes` instead of inline awk/sed scripts
- [ ] Use `notify-telegram` instead of inline curl commands
- [ ] Use `download-and-prepare-artifacts` instead of manual download-artifact calls
- [ ] Use existing `cosign-sign-verify` for signing
- [ ] Use existing `provenance-attestation` for SLSA provenance
- [ ] Use existing `flutter-ci-core` for analysis and testing
- [ ] Use existing `release-tag-validation` for tag verification
- [ ] Pin all actions to SHA versions
- [ ] Add concurrency group with cancel-in-progress
- [ ] Declare minimum required permissions

---

## 📖 Related Documentation

- `BRANCH_STRATEGY.md` - Detailed branch protection and workflow architecture
- `CONTRIBUTING.md` - Contribution guidelines and PR workflow
- `IMPLEMENTATION.md` - Implementation roadmap and milestones
- `ARCHITECTURE.md` - System architecture and design decisions

---

## 📝 Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-03-27 | 1.0 | @dencelkbabu | Initial modularization: 5 new composite actions |
| 2026-03-30 | 2.0 | @dencelkbabu | Complete workflow refactor: feature/dev/beta branch strategy, 3 new workflows, consolidated documentation |
| 2026-03-31 | 3.0 | @dencelkbabu | **Phase 1-3 Release Workflow Implementation**: Enhanced beta workflow with commit markers, RC workflow, hotfix workflow, GitHub API integration for changelog generation |

---

## 🚀 Complete Workflow File Reference

This section documents **ALL 11 workflow files** in the `.github/workflows/` directory.

### Workflow Files Overview

| File | Purpose | Trigger | Jobs | Outputs |
|------|---------|---------|------|---------|
| `ci_feature.yml` | Feature branch CI | Push to non-main/dev/beta | `analyze-and-test` | GitHub Checks status |
| `ci_dev.yml` | Dev branch CI/CD | Push to `dev` | `analyze-and-test`, `build-and-push-dev` | APK artifacts, Telegram |
| `ci_beta.yml` | Beta branch CI/CD | Push to `beta` + markers | `analyze-and-test`, `build-rc`, `create-draft-release`, `notify-telegram` | Draft release, Telegram |
| `ci_main.yml` | Main branch validation | Push/PR to `main` | `dependency-review`, `analyze-and-test`, `build-android`, `build-windows` | GitHub Checks status |
| `ci_rc.yml` | Release Candidate | Tag push `v*-rc.*` | `verify-tag`, `analyze-and-test`, `build-rc`, `publish-release`, `notify-telegram` | Public RC release, Telegram |
| `ci_hotfix.yml` | Hotfix/Patch | Tag push `v*-patch.*` | `verify-tag`, `analyze-and-test`, `build-patch`, `publish-release`, `notify-telegram` | Public patch release, Telegram |
| `cd_prod_auto.yml` | Automated production | Tag push `v*.*.*` on main | `verify-tag-on-main`, `analyze-and-test`, `build-android`, `build-windows`, `provenance`, `publish-release`, `notify-release` | Signed release, Telegram |
| `cd_prod_man.yml` | Manual production rebuild | Manual dispatch (tag input) | Same as `cd_prod_auto.yml` | Rebuilt release assets |
| `cd_prod_retro.yml` | Legacy production rebuild | Manual dispatch (legacy tag) | Same as `cd_prod_auto.yml` + action restoration | Rebuilt legacy assets |
| `validate_workflows.yml` | Workflow validation | PR/push to `.github/**` | `yaml-lint`, `actionlint` | Validation status |
| `license_check.yml` | License header check | All branches/PRs | `license-check` | Pass/fail status |

---

### 1. `ci_feature.yml` (Feature Branch CI)

**File:** `.github/workflows/ci_feature.yml`

**Purpose:** Fast feedback for AI agents (Jules, Copilot) and human developers working on arbitrary-named branches.

**Triggers:**
```yaml
on:
  push:
    branches:
      - '**'              # All branches
      - '!main'           # Exclude main
      - '!dev'            # Exclude dev
      - '!beta'           # Exclude beta
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `analyze-and-test` | Ubuntu | ~5-10 min | Flutter analyze + unit tests + widget tests |

**Job Details:**
```yaml
jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/flutter-ci-core
        with:
          working-directory: ./app
      # No build artifacts (saves CI minutes)
```

**Outputs:**
- GitHub Checks API status (pass/fail)
- No build artifacts

**Notifications:** None (check GitHub PR status)

**Branch Detection Logic:**
Uses **exclusion logic** to support AI agents with arbitrary branch names:
- If branch is `main` → `ci_main.yml` handles it
- If branch is `dev` → `ci_dev.yml` handles it
- If branch is `beta` → `ci_beta.yml` handles it
- **Any other name** → This workflow handles it

---

### 2. `ci_dev.yml` (Development Branch CI/CD)

**File:** `.github/workflows/ci_dev.yml`

**Purpose:** Continuous development builds for testing on devices.

**Triggers:**
```yaml
on:
  push:
    branches: [dev]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-and-push-dev` | Ubuntu | ~15-20 min | Build APK (no signing) |

**Job Details:**
```yaml
jobs:
  analyze-and-test:
    uses: ./.github/workflows/ci_feature.yml
    with:
      working-directory: ./app
  
  build-and-push-dev:
    needs: analyze-and-test
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/flutter-build-android
        with:
          build-type: release
          split-per-abi: true
      - uses: actions/upload-artifact@v4
        with:
          name: app-dev-${{ github.sha }}
          path: app/build/**/*.apk
```

**Outputs:**
- APK artifacts: `app-dev-<commit>.apk`
- GitHub Actions artifacts (downloadable)

**Notifications:**
- ✅ Telegram: Dev build ready (APK attached)
- ❌ No GitHub Release

---

### 3. `ci_beta.yml` (Beta Branch CI/CD - Release Candidates)

**File:** `.github/workflows/ci_beta.yml`

**Purpose:** Pre-release builds for stakeholder testing and RC validation with smart release automation.

**Triggers:**
```yaml
on:
  push:
    branches: [beta]
    paths:
      - 'app/**'
      - '.github/**'
      - 'scripts/**'
      - 'pubspec.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-rc` | Ubuntu | ~15-20 min | Build + Cosign signing |
| `create-draft-release` | Ubuntu | ~2-5 min | GitHub draft release |
| `notify-telegram` | Ubuntu | ~1 min | Telegram notification |

**Release Decision Logic:**
```bash
# Check commit markers
if has_marker("[wip]") or has_marker("[skip-release"):
  SKIP_RELEASE  # Safety first
elif has_marker("[beta]"):
  CREATE_RELEASE  # Explicit request
elif commit_count >= 5:
  CREATE_RELEASE  # Auto-release threshold
else:
  SKIP_RELEASE  # Not enough changes
```

**Outputs:**
- Signed APK + ZIP artifacts
- GitHub Draft Release (pre-release flag)
- Telegram notification

---

### 4. `ci_main.yml` (Main Branch CI)

**File:** `.github/workflows/ci_main.yml`

**Purpose:** Quality gate for PRs targeting `main` and pushes to `main`.

**Triggers:**
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `dependency-review` | Ubuntu | ~5 min | Vulnerability scan |
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-android` | Ubuntu | ~15-20 min | Debug APK (validation) |
| `build-windows` | Windows | ~20-25 min | Windows build (validation) |

**Outputs:**
- GitHub Checks API status (required for PR merge)
- No artifacts (validation only)

**Notifications:** None (PR status checks only)

---

### 5. `ci_rc.yml` (Release Candidate Workflow)

**File:** `.github/workflows/ci_rc.yml`

**Purpose:** Create public release candidates for final validation before stable release.

**Triggers:**
```yaml
on:
  push:
    tags:
      - 'v*-rc.*'  # e.g., v0.2.2-rc.1, v0.2.2-rc.2
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `verify-tag` | Ubuntu | ~5 min | Tag format + GPG check |
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-rc` | Ubuntu | ~15-20 min | Build + signing |
| `publish-release` | Ubuntu | ~5 min | Public GitHub release |
| `notify-telegram` | Ubuntu | ~1 min | Telegram notification |

**Changelog Logic:**
```bash
# First RC (rc.1): Full changelog since stable
LAST_STABLE=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)
git log --oneline $LAST_STABLE..HEAD

# Subsequent RCs (rc.2+): Incremental since previous RC
PREV_RC=$(git describe --tags --match='v*-rc.*' --abbrev=0 | head -1)
git log --oneline $PREV_RC..HEAD
```

**Outputs:**
- Public GitHub Release (pre-release flag)
- Signed APK + ZIP artifacts
- Telegram notification

---

### 6. `ci_hotfix.yml` (Hotfix/Patch Workflow)

**File:** `.github/workflows/ci_hotfix.yml`

**Purpose:** Urgent production fixes without waiting for full release cycle.

**Triggers:**
```yaml
on:
  push:
    tags:
      - 'v*-patch.*'  # e.g., v0.2.2-patch.1, v0.2.2-patch.2
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `verify-tag` | Ubuntu | ~5 min | Tag format + GPG check |
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-patch` | Ubuntu | ~15-20 min | Build + signing |
| `publish-release` | Ubuntu | ~5 min | Public GitHub release |
| `notify-telegram` | Ubuntu | ~1 min | Telegram notification |

**Changelog Logic:**
```bash
# Show changes since last stable or previous patch
LAST_STABLE=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)
PREV_PATCH=$(git describe --tags --match='v*-patch.*' --abbrev=0 | head -1)
git log --oneline ${PREV_PATCH:-$LAST_STABLE}..HEAD
```

**Outputs:**
- Public GitHub Release (stable, not pre-release)
- Signed APK + ZIP artifacts
- Telegram notification

---

### 7. `cd_prod_auto.yml` (Automated Production Release)

**File:** `.github/workflows/cd_prod_auto.yml`

**Purpose:** Full production release on version tag push.

**Triggers:**
```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'  # e.g., v0.2.2, v1.0.0
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `verify-tag-on-main` | Ubuntu | ~5 min | Confirm tag on main + GPG |
| `analyze-and-test` | Ubuntu | ~10-15 min | Flutter analyze + tests |
| `build-android` | Ubuntu | ~15-20 min | Release APK (keystore signed) |
| `build-windows` | Windows | ~20-25 min | Release ZIP (signed) |
| `provenance` | Ubuntu | ~5 min | SLSA provenance attestation |
| `publish-release` | Ubuntu | ~5 min | Public GitHub release |
| `notify-release` | Ubuntu | ~1 min | Telegram announcement |

**Outputs:**
- Signed production artifacts (keystore + Cosign)
- Public GitHub Release (stable)
- Telegram announcement

---

### 8. `cd_prod_man.yml` (Manual Production Rebuild)

**File:** `.github/workflows/cd_prod_man.yml`

**Purpose:** Rebuild existing production tags (CI migration, asset recovery).

**Triggers:**
```yaml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Tag to rebuild (e.g., v1.0.2)"
        required: true
      force:
        description: "Force overwrite existing release assets"
        required: false
        default: false
```

**Jobs:** Same as `cd_prod_auto.yml`

**Use Cases:**
- CI migration (new signing keys)
- Asset recovery (lost artifacts)
- Rebuilding with updated dependencies

---

### 9. `cd_prod_retro.yml` (Legacy Production Rebuild)

**File:** `.github/workflows/cd_prod_retro.yml`

**Purpose:** Rebuild old tags (pre-signing era) with modern CI actions.

**Triggers:**
```yaml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Tag to rebuild (e.g., v0.2.1)"
        required: true
      force:
        description: "Force overwrite existing release assets"
        required: false
        default: false
```

**Jobs:** Same as `cd_prod_auto.yml` + action restoration

**Special Handling:**
- Checks out modern actions from `main` branch
- Applies to tags created before CI migration

---

### 10. `validate_workflows.yml` (Workflow Validation)

**File:** `.github/workflows/validate_workflows.yml`

**Purpose:** Lint YAML and validate GitHub Actions syntax.

**Triggers:**
```yaml
on:
  pull_request:
    paths: ['.github/**']
  push:
    branches: [main]
    paths: ['.github/**']
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `yaml-lint` | Ubuntu | ~2 min | YAML syntax validation |
| `actionlint` | Ubuntu | ~2 min | GitHub Actions schema validation |

**Tools:**
- `yamllint` — YAML syntax
- `actionlint` — GitHub Actions schema

---

### 11. `license_check.yml` (License Header Check)

**File:** `.github/workflows/license_check.yml`

**Purpose:** Automated check for dual-license headers in all source files.

**Triggers:**
```yaml
on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']
```

**Jobs:**

| Job | Runner | Duration | Purpose |
|-----|--------|----------|---------|
| `license-check` | Ubuntu | ~2 min | Run `scripts/check_license_headers.sh` |

**Script:**
```bash
./scripts/check_license_headers.sh
# Checks for:
# - Copyright notice
# - SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
```

---

## 🧩 Complete Composite Actions Reference

This section documents **ALL 9 composite actions** in the `.github/actions/` directory.

### Composite Actions Overview

| Action | Purpose | Inputs | Outputs | Used By |
|--------|---------|--------|---------|---------|
| `flutter-ci-core` | Setup, analyze, test | 3 | 2 | All CI workflows |
| `release-tag-validation` | Tag security validation | 2 | 1 | `cd_prod_*`, `ci_rc`, `ci_hotfix` |
| `cosign-sign-verify` | Keyless artifact signing | 2 | 2 | `ci_beta`, `cd_prod_*`, `ci_rc`, `ci_hotfix` |
| `provenance-attestation` | SLSA provenance | 1 | 1 | `ci_beta`, `cd_prod_*`, `ci_rc`, `ci_hotfix` |
| `flutter-build-android` | Android APK build | 6 | 2 | `ci_dev`, `ci_beta`, `cd_prod_*` |
| `flutter-build-windows` | Windows build + ZIP | 3 | 2 | `ci_main`, `cd_prod_*` |
| `generate-release-notes` | Changelog extraction | 3 | 1 | `ci_beta`, `ci_rc`, `ci_hotfix` |
| `notify-telegram` | Telegram notifications | 7 | 0 | `ci_dev`, `ci_beta`, `cd_prod_*`, `ci_rc`, `ci_hotfix` |
| `download-and-prepare-artifacts` | Artifact download helper | 2 | 1 | `cd_prod_*`, `ci_rc`, `ci_hotfix` |

---

### 1. `flutter-ci-core`

**Path:** `.github/actions/flutter-ci-core/action.yml`

**Purpose:** Centralizes Flutter setup, analysis, and testing logic.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `working-directory` | string | `./app` | Flutter project path |
| `flutter-version` | string | `3.x` | Flutter SDK version |
| `test-coverage` | boolean | `false` | Enable code coverage |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `test-result` | string | `pass` or `fail` |
| `coverage-percent` | string | Coverage percentage (if enabled) |

**Example Usage:**
```yaml
- uses: ./.github/actions/flutter-ci-core
  with:
    working-directory: ./app
    flutter-version: '3.11.0'
    test-coverage: true
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ inputs.flutter-version }}
    - run: flutter pub get
      working-directory: ${{ inputs.working-directory }}
      shell: bash
    - run: flutter analyze
      working-directory: ${{ inputs.working-directory }}
      shell: bash
    - run: flutter test
      working-directory: ${{ inputs.working-directory }}
      shell: bash
```

---

### 2. `flutter-build-android`

**Path:** `.github/actions/flutter-build-android/action.yml`

**Purpose:** Centralizes Android APK build logic including keystore configuration.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `working-directory` | string | `./app` | Flutter project path |
| `keystore-base64` | string | **required** | Base64-encoded keystore |
| `key-password` | string | **required** | Key password |
| `key-alias` | string | **required** | Key alias |
| `store-password` | string | **required** | Store password |
| `build-type` | string | `release` | `release`, `debug`, or `profile` |
| `split-per-abi` | boolean | `true` | Build separate APKs per ABI |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `apk-path` | string | Full path to built APK |
| `apk-name` | string | Name of APK file |

**Example Usage:**
```yaml
- uses: ./.github/actions/flutter-build-android
  with:
    working-directory: ./app
    keystore-base64: ${{ secrets.KEYSTORE_BASE64 }}
    key-password: ${{ secrets.KEY_PASSWORD }}
    key-alias: ${{ secrets.KEY_ALIAS }}
    store-password: ${{ secrets.STORE_PASSWORD }}
    build-type: release
    split-per-abi: true
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - name: Decode keystore
      run: echo "$KEYSTORE" | base64 -d > android/app/upload-keystore.jks
      shell: bash
      env:
        KEYSTORE: ${{ inputs.keystore-base64 }}
    - name: Build APK
      run: flutter build apk --${{ inputs.build-type }} --split-per-abi
      working-directory: ${{ inputs.working-directory }}
      shell: bash
```

---

### 3. `flutter-build-windows`

**Path:** `.github/actions/flutter-build-windows/action.yml`

**Purpose:** Centralizes Windows build and ZIP packaging logic.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `working-directory` | string | `./app` | Flutter project path |
| `build-type` | string | `release` | `release`, `debug`, or `profile` |
| `artifact-name` | string | `openmidicontrol-windows` | Custom ZIP name |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `zip-path` | string | Full path to ZIP archive |
| `zip-name` | string | Name of ZIP file |

**Example Usage:**
```yaml
- uses: ./.github/actions/flutter-build-windows
  with:
    working-directory: ./app
    build-type: release
    artifact-name: openmidicontrol-v0.2.2-windows
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - run: flutter build windows --${{ inputs.build-type }}
      working-directory: ${{ inputs.working-directory }}
      shell: bash
    - run: Compress-Archive -Path build\windows\runner\Release\* -DestinationPath ${{ inputs.artifact-name }}.zip
      shell: pwsh
```

---

### 4. `release-tag-validation`

**Path:** `.github/actions/release-tag-validation/action.yml`

**Purpose:** Validates release tag format, GPG signature, and confirms tag is on correct branch.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `expected-branch` | string | `main` | Branch where tag should exist |
| `gpg-fingerprint` | string | **required** | Expected GPG key fingerprint |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `tag-version` | string | Extracted version (e.g., `0.2.2`) |

**Example Usage:**
```yaml
- uses: ./.github/actions/release-tag-validation
  with:
    expected-branch: main
    gpg-fingerprint: ${{ secrets.EXPECTED_GPG_FINGERPRINT }}
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - name: Verify tag on correct branch
      run: |
        TAG_BRANCH=$(git branch -r --contains ${{ github.ref }} | head -1)
        if [[ ! "$TAG_BRANCH" =~ .*${{ inputs.expected-branch }} ]]; then
          echo "::error::Tag must be on ${{ inputs.expected-branch }} branch"
          exit 1
        fi
    - name: Verify GPG signature
      run: git tag -v ${{ github.ref_name }}
      shell: bash
```

---

### 5. `cosign-sign-verify`

**Path:** `.github/actions/cosign-sign-verify/action.yml`

**Purpose:** Keyless signing for artifact security (SLSA compliance) using OIDC identity.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `artifact_path` | string | **required** | Path to artifact to sign |
| `repository` | string | `github` | GitHub repository for identity |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `signature_path` | string | Path to `.sig` file |
| `certificate_path` | string | Path to `.crt` file |

**Example Usage:**
```yaml
- uses: ./.github/actions/cosign-sign-verify
  with:
    artifact_path: app/build/outputs/apk/release/app-release.apk
    repository: PetersDigital/OpenMIDIControl
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - uses: sigstore/cosign-installer@v3
    - name: Sign artifact
      run: |
        cosign sign-blob \
          --output-signature ${{ inputs.artifact_path }}.sig \
          --output-certificate ${{ inputs.artifact_path }}.crt \
          ${{ inputs.artifact_path }}
      shell: bash
```

---

### 6. `provenance-attestation`

**Path:** `.github/actions/provenance-attestation/action.yml`

**Purpose:** Generates SLSA provenance attestations for build artifacts.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `subject_path` | string | **required** | Path pattern to artifacts |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `provenance_path` | string | Path to `provenance.json` |

**Example Usage:**
```yaml
- uses: ./.github/actions/provenance-attestation
  with:
    subject_path: app/build/**/*.apk
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - uses: actions/attest-build-provenance@v1
      with:
        subject-path: ${{ inputs.subject_path }}
```

---

### 7. `generate-release-notes`

**Path:** `.github/actions/generate-release-notes/action.yml`

**Purpose:** Extracts changelog from git history using GitHub API and conventional commit parsing.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `from_tag` | string | **required** | Starting tag for changelog |
| `to_tag` | string | `HEAD` | Ending tag (default: HEAD) |
| `release_type` | string | `beta` | `beta`, `rc`, `stable`, or `hotfix` |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `changelog` | string | Markdown-formatted changelog |

**Example Usage:**
```yaml
- uses: ./.github/actions/generate-release-notes
  with:
    from_tag: v0.2.2-beta.44
    to_tag: v0.2.2-beta.45
    release_type: beta
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - name: Generate changelog
      run: |
        git log --pretty=format:"- %s" ${{ inputs.from_tag }}..${{ inputs.to_tag }} | \
        awk '
          /feat/ { print "### Added\n" $0 }
          /fix/ { print "### Fixed\n" $0 }
          /perf|refactor/ { print "### Changed\n" $0 }
        ' > changelog.md
      shell: bash
```

---

### 8. `notify-telegram`

**Path:** `.github/actions/notify-telegram/action.yml`

**Purpose:** Centralizes Telegram notification logic for all workflow types.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `telegram-token` | string | **required** | Bot token |
| `telegram-chat-id` | string | **required** | Target chat ID |
| `notification-type` | string | `ci-failure` | `ci-failure`, `release`, `dev-build`, `rc-build` |
| `tag` | string | | Release tag |
| `branch` | string | | Branch name |
| `status` | string | `success` | `success` or `failure` |
| `artifact-path` | string | | Path to artifact |

**Outputs:** None

**Example Usage:**
```yaml
- uses: ./.github/actions/notify-telegram
  with:
    telegram-token: ${{ secrets.TELEGRAM_TOKEN }}
    telegram-chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    notification-type: release
    tag: v0.2.2
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - name: Send Telegram message
      run: |
        curl -X POST "https://api.telegram.org/bot${{ inputs.telegram-token }}/sendMessage" \
          -d chat_id=${{ inputs.telegram-chat-id }} \
          -d text="${{ env.MESSAGE }}"
      shell: bash
```

---

### 9. `download-and-prepare-artifacts`

**Path:** `.github/actions/download-and-prepare-artifacts/action.yml`

**Purpose:** Downloads and organizes build artifacts from multiple jobs for release publishing.

**Inputs:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `artifact-pattern` | string | `**/*.apk` | Pattern to match artifacts |
| `output-directory` | string | `./dist` | Where to place artifacts |

**Outputs:**

| Name | Type | Description |
|------|------|-------------|
| `artifact-count` | string | Number of artifacts downloaded |

**Example Usage:**
```yaml
- uses: ./.github/actions/download-and-prepare-artifacts
  with:
    artifact-pattern: app/build/**/*.apk
    output-directory: ./dist
```

**Internal Implementation:**
```yaml
runs:
  using: composite
  steps:
    - uses: actions/download-artifact@v4
      with:
        pattern: ${{ inputs.artifact-pattern }}
        path: ${{ inputs.output-directory }}
```

---

## 📐 Architecture Diagrams

### Data Flow: Commit to Release

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER / AI AGENT                              │
│  git commit -m "feat(ui): add fader" -m "[beta]"                         │
│  git push origin beta                                                    │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions Trigger                            │
│  ci_beta.yml: push to beta branch                                        │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    Job 1: analyze-and-test                                │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/flutter-ci-core                    │          │
│  │  - Setup Flutter 3.11.0                                    │          │
│  │  - flutter pub get                                         │          │
│  │  - flutter analyze                                         │          │
│  │  - flutter test                                            │          │
│  └────────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (if tests pass)
┌──────────────────────────────────────────────────────────────────────────┐
│              Job 2: build-rc (depends on analyze-and-test)                │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/flutter-build-android              │          │
│  │  - Decode keystore                                         │          │
│  │  - flutter build apk --release --split-per-abi             │          │
│  └────────────────────────────────────────────────────────────┘          │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/cosign-sign-verify                 │          │
│  │  - cosign sign-blob app-release.apk                        │          │
│  └────────────────────────────────────────────────────────────┘          │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/provenance-attestation             │          │
│  │  - actions/attest-build-provenance                         │          │
│  └────────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│              Job 3: create-draft-release                                  │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/generate-release-notes             │          │
│  │  - git log --oneline LAST_TAG..HEAD                        │          │
│  │  - Parse conventional commits                              │          │
│  └────────────────────────────────────────────────────────────┘          │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ gh release create vX.Y.Z --draft --title "Beta X"          │          │
│  │ gh release upload vX.Y.Z ./dist/*                          │          │
│  └────────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│              Job 4: notify-telegram                                       │
│  ┌────────────────────────────────────────────────────────────┐          │
│  │ uses: ./.github/actions/notify-telegram                    │          │
│  │  - POST to Telegram API                                    │          │
│  │  - Message: "🚧 Beta Release v0.2.2-beta.45 ready"         │          │
│  └────────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         Telegram Channel                                  │
│  🚧 Beta Release v0.2.2-beta.45 ready                                    │
│  Download: https://github.com/.../releases/tag/v0.2.2-beta.45            │
└──────────────────────────────────────────────────────────────────────────┘
```

### Job Dependencies Within Workflows

```
ci_feature.yml:
┌────────────────────┐
│ analyze-and-test   │
│ (no dependencies)  │
└────────────────────┘

ci_dev.yml:
┌────────────────────┐     ┌────────────────────┐
│ analyze-and-test   │────▶│ build-and-push-dev │
│ (no dependencies)  │     │ (needs: analyze)   │
└────────────────────┘     └────────────────────┘
                                   │
                                   ▼
                          ┌────────────────────┐
                          │ notify-telegram    │
                          │ (needs: build)     │
                          └────────────────────┘

ci_beta.yml:
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│ analyze-and-test   │────▶│     build-rc       │────▶│ create-draft       │────▶│ notify-telegram    │
│ (no dependencies)  │     │ (needs: analyze)   │     │ (needs: build)     │     │ (needs: release)   │
└────────────────────┘     └────────────────────┘     └────────────────────┘     └────────────────────┘

cd_prod_auto.yml:
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│ verify-tag-on-main │────▶│ analyze-and-test   │────▶│   build-android    │───┐
│ (no dependencies)  │     │ (needs: verify)    │     │  (needs: analyze)  │   │
└────────────────────┘     └────────────────────┘     └────────────────────┘   │
                                                        ┌────────────────────┐   │
                                                        │   build-windows    │───┼──▶┌──────────────┐
                                                        │  (needs: analyze)  │   │   │  provenance  │
                                                        └────────────────────┘   │   │(needs: builds)│
                                                        ┌────────────────────┐   │   └──────────────┘
                                                        │     provenance     │───┘          │
                                                        │  (needs: builds)   │              │
                                                        └────────────────────┘              ▼
                                                                                   ┌──────────────┐
                                                                                   │publish-release│
                                                                                   │(needs: prov.)│
                                                                                   └──────────────┘
                                                                                          │
                                                                                          ▼
                                                                                   ┌──────────────┐
                                                                                   │notify-release│
                                                                                   │(needs: pub.) │
                                                                                   └──────────────┘
```

### Action Reuse Patterns

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        COMPOSITE ACTIONS LIBRARY                         │
└─────────────────────────────────────────────────────────────────────────┘
         │              │              │              │              │
         │              │              │              │              │
         ▼              ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│flutter-ci-  │ │flutter-     │ │  cosign-    │ │  notify-    │ │  generate-  │
│core         │ │build-android│ │  sign-      │ │  telegram   │ │  release-   │
│             │ │             │ │  verify     │ │             │ │  notes      │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
      │                │                │                │                │
      │                │                │                │                │
      └────────────────┴────────────────┴────────────────┴────────────────┘
                                       │
                                       ▼
         ┌─────────────────────────────────────────────────┐
         │              REUSED BY WORKFLOWS:                │
         │  - ci_feature.yml                               │
         │  - ci_dev.yml                                   │
         │  - ci_beta.yml                                  │
         │  - ci_main.yml                                  │
         │  - ci_rc.yml                                    │
         │  - ci_hotfix.yml                                │
         │  - cd_prod_auto.yml                             │
         │  - cd_prod_man.yml                              │
         │  - cd_prod_retro.yml                            │
         └─────────────────────────────────────────────────┘
```

---

## 🤔 Why This Architecture?

This section explains the design decisions behind the CI/CD architecture.

### 1. Exclusion Logic for Branch Detection

**Decision:** Use exclusion logic (`!main`, `!dev`, `!beta`) instead of prefix patterns (`feature/*`).

**Rationale:**
- **AI Agent Compatibility:** Google Jules and GitHub Copilot create branches with arbitrary names based on task context:
  - `feat-native-android-ump-8916227028079091107`
  - `fix-thermal-runaway-p0-9001081033840053369`
  - `copilot-midi-parser-fix`
- **No Naming Constraints:** Developers don't need to remember prefix patterns
- **Future-Proof:** New branch naming conventions don't require CI changes
- **Simplicity:** One workflow handles all non-protected branches

**Trade-offs:**
- ✅ Supports arbitrary branch names
- ✅ AI agent friendly
- ⚠️ Less explicit than prefix patterns (mitigated by documentation)

---

### 2. Modular Composite Actions (DRY Principle)

**Decision:** Extract reusable logic into 9 composite actions instead of duplicating across 11 workflows.

**Rationale:**
- **Consistency:** All workflows use the same build, test, and signing logic
- **Maintainability:** Fix a bug in one place, all workflows benefit
- **Code Reuse:** ~70% reduction in YAML lines
- **Testing:** Composite actions can be tested independently

**Example:**
```yaml
# Before (duplicated in 5 workflows):
- name: Setup Flutter
  uses: subosito/flutter-action@v2
- name: Install deps
  run: flutter pub get
- name: Analyze
  run: flutter analyze
- name: Test
  run: flutter test

# After (single composite action):
- uses: ./.github/actions/flutter-ci-core
  with:
    working-directory: ./app
```

**Trade-offs:**
- ✅ DRY (Don't Repeat Yourself)
- ✅ Easier to maintain
- ⚠️ Slightly higher initial complexity (mitigated by documentation)

---

### 3. Cost Optimization (Feature Branches Skip Builds)

**Decision:** Feature branches run CI-only (analyze + test), no build artifacts.

**Rationale:**
- **CI Minute Savings:** Builds consume ~20 min/run, feature branches push ~40 times/month
- **Fast Feedback:** Developers get test results in ~8 min instead of ~28 min
- **Resource Efficiency:** No need for APK artifacts on every feature branch
- **Environmental Impact:** Reduced compute = lower carbon footprint

**Cost Comparison:**
| Scenario | Before | After | Savings |
|----------|--------|-------|---------|
| Feature branch (40/month) | 40 × 28 min = 1,120 min | 40 × 8 min = 320 min | 800 min |
| Dev branch (8/month) | 8 × 28 min = 224 min | 8 × 28 min = 224 min | 0 min |
| Beta branch (4/month) | 4 × 30 min = 120 min | 4 × 30 min = 120 min | 0 min |
| **Total** | **1,464 min/month** | **664 min/month** | **800 min (55%)** |

**Trade-offs:**
- ✅ 55% CI cost reduction
- ✅ Faster feedback for developers
- ⚠️ No APK artifacts for feature branches (acceptable trade-off)

---

### 4. Security (Action Pinning, OIDC Validation)

**Decision:** Pin all actions to SHA versions and use OIDC for keyless signing.

**Rationale:**

**Action Pinning:**
```yaml
# ❌ Bad (vulnerable to tag hijacking):
uses: actions/checkout@v4

# ✅ Good (immutable):
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**OIDC Keyless Signing:**
- **No Long-Lived Secrets:** Traditional signing keys can leak
- **Short-Lived Tokens:** OIDC tokens expire in minutes
- **Identity-Bound:** Signature tied to GitHub Actions identity
- **Automatic Rotation:** No manual key rotation needed

**Example OIDC Identity:**
```
https://github.com/PetersDigital/OpenMIDIControl/.github/workflows/cd_prod_auto.yml@refs/heads/main
```

**Trade-offs:**
- ✅ No secret management overhead
- ✅ Immune to key leakage
- ✅ Automatic rotation
- ⚠️ Requires GitHub Actions (vendor lock-in, acceptable for this project)

---

### 5. Commit Message Markers for Beta Releases

**Decision:** Use `[wip]`, `[skip-release]`, `[beta]` markers to control release automation.

**Rationale:**
- **Developer Control:** Explicit opt-in for beta releases
- **Safety First:** `[wip]` prevents accidental releases
- **Auto-Release:** 5+ commits threshold catches batch fixes
- **Flexible:** Works for both small iterative pushes and large feature drops

**Example Workflow:**
```bash
# Day 1: Start feature (no release)
git commit -m "feat(ui): new fader" -m "[wip]"
git push origin beta

# Day 2: Continue work (no release)
git commit -m "fix(midi): UMP reconstruction" -m "[skip-release]"
git push origin beta

# Day 3: Feature complete (create release)
git commit -m "feat(midi): high-res CC support" -m "[beta]"
git push origin beta
# → Beta release created
```

**Trade-offs:**
- ✅ Fine-grained control
- ✅ Prevents accidental releases
- ⚠️ Requires discipline (developers must add markers)

---

### 6. Separate RC and Hotfix Workflows

**Decision:** Dedicated workflows (`ci_rc.yml`, `ci_hotfix.yml`) instead of reusing beta workflow.

**Rationale:**
- **Different Audiences:**
  - Beta: Internal testers (draft releases)
  - RC: Public testers (pre-release, public)
  - Hotfix: Production users (stable, urgent)
- **Different Changelog Logic:**
  - RC: Full changelog (rc.1) or incremental (rc.2+)
  - Hotfix: Since last stable or previous patch
  - Beta: Since last beta release
- **Different Visibility:**
  - Beta: Draft (hidden from public)
  - RC: Pre-release (visible, marked as testing)
  - Hotfix: Stable (production-ready)

**Trade-offs:**
- ✅ Clear separation of concerns
- ✅ Tailored logic per release type
- ⚠️ More workflows to maintain (mitigated by composite actions)

---

### 7. Telegram Notifications

**Decision:** Use Telegram for real-time CI/CD notifications instead of email or Slack.

**Rationale:**
- **Instant Delivery:** Push notifications to mobile devices
- **Developer Preference:** Team already uses Telegram for coordination
- **Cost:** Free (vs. Slack paid tiers for integrations)
- **Flexibility:** Custom bot with rich formatting

**Notification Types:**
| Type | Trigger | Message |
|------|---------|---------|
| CI Failure | `analyze-and-test` fails | ❌ CI failed on `<branch>`: `<error>` |
| Dev Build | `ci_dev.yml` completes | 🔧 Dev build ready: `<commit>` |
| Beta Release | `ci_beta.yml` creates release | 🚧 Beta `<tag>` ready for testing |
| RC Release | `ci_rc.yml` publishes | 🎯 RC `<tag>` - feature complete |
| Stable Release | `cd_prod_auto.yml` publishes | ✅ Stable `<tag>` - production ready |
| Hotfix | `ci_hotfix.yml` publishes | 🔥 Hotfix `<tag>` - urgent update |

**Trade-offs:**
- ✅ Real-time notifications
- ✅ Mobile-friendly
- ⚠️ Requires Telegram account (acceptable for team)

---

### 8. SLSA Provenance Attestation

**Decision:** Generate SLSA provenance for all production releases.

**Rationale:**
- **Supply Chain Security:** Prove where, when, and how build was created
- **Compliance:** Meet SLSA Level 3 requirements
- **Audit Trail:** Forensic analysis if security incident occurs
- **Industry Standard:** Adopted by Google, Microsoft, GitHub

**Provenance Contents:**
```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://github.com/actions/workflow",
      "externalParameters": {
        "repository": "PetersDigital/OpenMIDIControl",
        "ref": "refs/tags/v0.2.2"
      }
    },
    "runDetails": {
      "builder": {
        "id": "https://github.com/actions/runner"
      },
      "metadata": {
        "invocationId": "https://github.com/PetersDigital/OpenMIDIControl/actions/runs/123456"
      }
    }
  }
}
```

**Trade-offs:**
- ✅ Supply chain transparency
- ✅ Security compliance
- ⚠️ Slightly longer build time (~2 min, acceptable)

---

## Summary

The CI/CD architecture balances:
- **Speed:** Fast feedback for developers (8 min CI-only)
- **Security:** OIDC signing, SLSA provenance, action pinning
- **Cost:** 55% reduction in CI minutes
- **Flexibility:** AI agent friendly, arbitrary branch names
- **Reliability:** Automated testing, branch protection, quality gates

This design evolved from practical experience with AI-assisted development and lessons learned from thermal runaway fixes, UMP migration, and multi-touch implementation.

---

## 🚀 Release Workflow Implementation (Phase 1-3 Complete)

**Status:** ✅ **COMPLETE** - All phases implemented as of 2026-03-31

### Overview

The release workflow system provides a complete automated pipeline from development builds to stable releases, with intelligent release decision-making based on commit message markers.

**Key Features:**
- Commit message markers (`[wip]`, `[skip-release]`, `[beta]`)
- Auto-release at 5+ commits
- GitHub API integration for changelog generation
- Conventional commit parsing
- RC and hotfix workflows

---

### Release Types

| Type | Branch | Tag Format | Trigger | Draft | Pre-release | Changelog Source |
|------|--------|------------|---------|-------|-------------|------------------|
| **Beta** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-beta.{N}` | Auto (markers) | ✅ Yes | ❌ No | Git (since last beta) |
| **RC** | `beta` | `v{MAJOR}.{MINOR}.{PATCH}-rc.{N}` | Manual tag | ❌ No | ✅ Yes | Git (full/incr) |
| **Stable** | `main` | `v{MAJOR}.{MINOR}.{PATCH}` | Manual tag | ❌ No | ❌ No | CHANGELOG.md |
| **Hotfix** | `main` | `v{MAJOR}.{MINOR}.{PATCH}-patch.{N}` | Manual tag | ❌ No | ❌ No | Git (since stable/patch) |

---

### Phase 1: Enhanced Beta Workflow

**Commit:** `feat(ci/beta): implement Phase 1 enhanced beta workflow with commit markers`

**Objective:** Enhance existing `ci_beta.yml` with smart release automation based on commit message markers and auto-release thresholds.

#### Commit Message Markers

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

#### GitHub API Integration

**Problem:** Beta tags are not created in git (only GitHub release names), so `git describe --tags` cannot find previous releases.

**Solution:** Use GitHub CLI (`gh`) to query releases API.

**Implementation:**
```bash
# Find last beta release
LAST_BETA=$(gh release list --limit 30 --json tagName --jq '.[].tagName' | grep -- '-beta\.' | head -1 || echo "")

# If no beta, find last stable tag
if [ -z "$LAST_BETA" ]; then
  LAST_RELEASE=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)
else
  LAST_RELEASE="$LAST_BETA"
fi

# Generate changelog from that point
git log --oneline --pretty=format:"- %s" $LAST_RELEASE..HEAD
```

#### Conventional Commit Parsing

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

#### Beta Tag Naming

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

#### Developer Workflow Examples

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

---

### Phase 2: Release Candidate (RC) Workflow

**Commit:** `feat(ci/rc): implement Phase 2 release candidate workflow`

**Objective:** Create separate workflow for RC releases that bridges beta testing and stable release.

#### Trigger Mechanism

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

#### RC Changelog Logic

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

#### Release Settings

| Setting | Value |
|---------|-------|
| Draft | `false` (public) |
| Pre-release | `true` |
| Changelog | Full (rc.1) or Incremental (rc.2+) |
| Assets | APK + ZIP (signed + provenance) |

#### Developer Workflow Examples

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

---

### Phase 3: Hotfix/Patch Workflow

**Commit:** `feat(ci/hotfix): implement Phase 3 hotfix workflow for urgent production fixes`

**Objective:** Enable urgent fixes to stable releases without waiting for full release cycle.

#### Trigger Mechanism

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

#### Use Cases

| Scenario | Example |
|----------|---------|
| Critical bug in stable | Crash on startup |
| Security vulnerability | Dependency CVE |
| Regression | Feature broken in last release |

#### Release Settings

| Setting | Value |
|---------|-------|
| Draft | `false` |
| Pre-release | `false` |
| Changelog | Since last stable (or patch) |
| Assets | APK + ZIP (signed + provenance) |

#### Patch Numbering

```bash
# Count patches since last stable
PATCH_NUM=$(git rev-list --count v0.2.2..HEAD | grep patch || echo "1")
PATCH_TAG="v0.2.2-patch.${PATCH_NUM}"
```

#### Relationship to Stable

**After hotfix:**
- Patch release is published immediately
- Main branch updated with fix
- Next stable release (`v0.2.3`) includes patch

#### Developer Workflow Examples

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

### Workflow Comparison

#### Trigger Mechanisms

| Workflow | Trigger | Manual/Auto |
|----------|---------|-------------|
| Beta | Push to beta + markers | Auto |
| RC | Tag push (`v*-rc.*`) | Manual |
| Stable | Tag push (`v*.*.*`) | Manual |
| Hotfix | Tag push (`v*-patch.*`) | Manual |

#### Changelog Sources

| Workflow | Source | Range |
|----------|--------|-------|
| Beta | GitHub API + git log | Since last beta |
| RC | GitHub API + git log | Since stable (rc.1) or prev RC (rc.2+) |
| Stable | CHANGELOG.md | Manual entry |
| Hotfix | GitHub API + git log | Since stable or prev patch |

#### Release Visibility

| Workflow | Draft | Pre-release | Public |
|----------|-------|-------------|--------|
| Beta | ✅ Yes | ❌ No | ❌ Internal |
| RC | ❌ No | ✅ Yes | ✅ Yes |
| Stable | ❌ No | ❌ No | ✅ Yes |
| Hotfix | ❌ No | ❌ No | ✅ Yes |

---

### Technical Dependencies

#### Required Tools

| Tool | Purpose | Available |
|------|---------|-----------|
| `gh` (GitHub CLI) | Release API queries | ✅ Pre-installed on runners |
| `git` | Tag/log operations | ✅ Available |
| `jq` | JSON parsing | ✅ Pre-installed |

#### Required Permissions

```yaml
permissions:
  contents: write      # Create releases
  id-token: write      # Signing
  attestations: write  # Provenance
```

#### Existing Actions (Reused)

- `.github/actions/flutter-ci-core` - CI setup
- `.github/actions/flutter-build-android` - Android build
- `.github/actions/flutter-build-windows` - Windows build
- `.github/actions/cosign-sign-verify` - Asset signing
- `.github/actions/provenance-attestation` - SLSA provenance
- `.github/actions/generate-release-notes` - Changelog generation (enhanced)
- `.github/actions/notify-telegram` - Notifications
- `.github/actions/download-and-prepare-artifacts` - Asset preparation

---

### Testing Strategy

#### Unit Tests (Local)

```bash
# Test marker detection
bash scripts/test-release-notes.sh

# Test conventional commit parsing
# Test GitHub API queries
```

#### Integration Tests (CI)

1. **Beta workflow:**
   - Push with `[beta]` marker → Release created
   - Push with `[wip]` marker → No release
   - Push 5 commits (no marker) → Auto-release
   - Push 3 commits (no marker) → No release

2. **RC workflow:**
   - Push `v0.2.2-rc.1` → Full changelog
   - Push `v0.2.2-rc.2` → Incremental changelog

3. **Hotfix workflow:**
   - Push `v0.2.2-patch.1` → Patch release

---

### Troubleshooting

#### Common Issues

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

### Hotfix Changelog

```markdown
## 🔧 Hotfix Release: v0.2.2-patch.1

**This is an urgent production fix** for v0.2.2.

### Changes since v0.2.2

### Fixed
- fix: critical startup crash
- fix: memory leak in MIDI parser

---
### ⚠️ Hotfix Notice
This release contains urgent fixes for production issues.
All users on v0.2.2 are encouraged to update immediately.
```
