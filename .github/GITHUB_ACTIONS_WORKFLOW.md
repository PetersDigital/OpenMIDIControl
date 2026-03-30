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

---

**Next Steps:** Push workflows to `dev` branch and test with feature branch pushes.
