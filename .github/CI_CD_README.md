# GitHub Actions & CI/CD Documentation

**Last Updated:** 2026-04-07
**Maintainer:** @dencelkbabu
**Scope:** `.github/` directory (workflows, actions, dependabot)

## Overview

The `.github/` directory contains OpenMIDIControl's complete CI/CD infrastructure, implemented as **modular, reusable composite actions** following the DRY principle. All workflows follow the **`type_trigger_tier.yml`** naming convention and are pinned to specific action SHAs for supply chain security.

## Directory Structure

```
.github/
├── dependabot.yml              # Automated dependency update configuration (actions, npm, pub)
├── actions/                    # 10 reusable composite actions
│   ├── cosign-sign-verify/
│   ├── download-and-prepare-artifacts/
│   ├── flutter-build-android/
│   ├── flutter-build-windows/
│   ├── flutter-ci-core/
│   ├── generate-release-notes/
│   ├── notify-telegram/
│   ├── prepare-release-assets/     # NEW: shared asset collection
│   ├── provenance-attestation/
│   └── release-tag-validation/
└── workflows/                  # 13 workflow files
    ├── .yamllint               # YAML linting configuration
    ├── cd_auto_*.yml           # Automated CD pipelines (dev, beta, rc, prod)
    ├── cd_man_*.yml            # Manual CD pipelines (prod, hotfix, retro)
    ├── ci_auto_*.yml           # Automated CI pipelines (main, feature)
    ├── ops_*.yml               # Operational workflows (stale management)
    └── validate_*.yml          # Validation workflows (license, yaml, commits)
```

## Workflow Naming Convention

All workflows follow the **`type_trigger_tier.yml`** pattern:

| Type | Description | Examples |
|------|-------------|----------|
| `cd_auto` | Automated Continuous Deployment | `cd_auto_dev.yml`, `cd_auto_prod.yml` |
| `cd_man` | Manual Continuous Deployment (requires approval) | `cd_man_prod.yml`, `cd_man_hotfix.yml` |
| `ci_auto` | Automated Continuous Integration | `ci_auto_main.yml`, `ci_auto_feature.yml` |
| `ops` | Operational/Management workflows | `ops_schedule_stale.yml` |
| `validate` | Code quality & compliance checks | `validate_auto_yaml.yml`, `validate_pr_commitlint.yml` |

## Composite Actions (Reusable Building Blocks)

### 1. `flutter-ci-core`
**Purpose:** Shared Flutter environment setup, static analysis, testing, Windows detection, and build metrics.

**Inputs:**
- `working-directory`: Path to Flutter project (default: `app`)
- `flutter-version`: Flutter version to use (optional, defaults to latest on channel)
- `telegram-token`: Telegram Bot Token (optional)
- `telegram-chat-id`: Target chat ID (optional)
- `notify-on-failure`: Whether to send failure notifications (default: `true`)
- `skip-format-check`: Skip dart format check for legacy code (default: `false`)

**Outputs:**
- `has_windows`: Whether the windows folder exists
- `job_status`: Status of the CI job (success/failure)
- `job_started_at`: Timestamp when the job started

**Steps:**
1. Cache Pub dependencies (`~/.pub-cache`)
2. Detect Windows platform support (`has_windows` output)
3. Setup Flutter (stable channel, cache enabled)
4. Run `flutter pub get`
5. Check code formatting (`dart format --output=none --set-exit-if-changed .`)
6. Static analysis (`flutter analyze --fatal-infos`)
7. Unit tests (`flutter test`)
8. Record build metrics (status, timestamp)
9. Send failure notification to Telegram (if enabled and credentials provided)

**Used by:** All CD workflows for pre-build validation

---

### 2. `cosign-sign-verify`
**Purpose:** Keyless Cosign signing and verification for artifact authenticity.

**Inputs:**
- `artifact_path`: Path to artifact to sign
- `repository`: GitHub repository slug (owner/repo)

**Steps:**
1. Sign artifact with Cosign (OIDC: `token.actions.githubusercontent.com`)
2. Generate `.sig` and `.pem` files
3. Verify signature with certificate identity regexp

**Security:** Uses GitHub's OIDC provider for keyless signing, eliminating secret management.

---

### 3. `provenance-attestation`
**Purpose:** Generate SLSA provenance attestation for build artifacts using GitHub native attestation.

**Inputs:**
- `subject_path`: Glob or exact path for artifact subjects (e.g., `openmidicontrol-*-android.apk`)

**Output:**
- GitHub-native provenance attestation (SLSA Level 2-3)

**Used by:** All CD workflows for supply chain security.

---

### 4. `flutter-build-android`
**Purpose:** Configure keystore and build Android APKs with optional ABI splitting.

**Inputs:**
- `working-directory`: Path to Flutter project (default: `app`)
- `keystore-base64`: Base64-encoded Android keystore
- `key-password`, `key-alias`, `store-password`: Keystore credentials
- `build-type`: `release`, `debug`, or `profile` (default: `release`)
- `split-per-abi`: Build separate APKs per ABI (default: `false`)
- `artifact-name`: Custom APK name (optional)

**Outputs:**
- `apk-path`: Path to built APK
- `apk-name`: APK filename

**Steps:**
1. Setup Java 17 (Temurin)
2. Setup Gradle with cache cleanup
3. Decode Base64 keystore to `upload-keystore.jks`
4. Generate `key.properties` with credentials
5. Build APK with specified configuration
6. Upload artifact with custom naming

---

### 5. `flutter-build-windows`
**Purpose:** Build and ZIP Windows desktop application.

**Inputs:**
- `working-directory`: Path to Flutter project (default: `app`)
- `artifact-name`: Custom ZIP name (optional)

**Outputs:**
- `zip-path`: Path to built ZIP
- `zip-name`: ZIP filename

**Steps:**
1. Setup Flutter (stable, cache)
2. Check for `windows/` directory
3. Run `flutter build windows` (if directory exists)
4. ZIP build output to `openmidicontrol-{version}-windows.zip`
5. Upload artifact

---

### 6. `download-and-prepare-artifacts`
**Purpose:** Download build artifacts with pattern matching and merge support.

**Inputs:**
- `artifact-pattern`: Glob pattern (default: `*`)
- `merge-multiple`: Merge into single directory (default: `true`)

**Outputs:**
- `artifacts-dir`: Directory containing downloaded artifacts

**Used by:** Release publishing workflows to collect Android and Windows builds.

---

### 7. `generate-release-notes`
**Purpose:** Parse CHANGELOG.md and generate release notes from conventional commits with full type detection.

**Inputs:**
- `tag`: Release tag (e.g., `v0.2.2` or `v0.2.2-beta.1`)
- `changelog-path`: Path to CHANGELOG.md (default: `CHANGELOG.md`)
- `include-metadata`: Include build metadata section (default: `true`)
- `commit-hash`: Commit hash for metadata (optional)
- `triggered-by`: Username who triggered the release (optional)
- `from-ref`: Explicit git reference for changelog (optional)
- `changelog-type`: `auto`, `full`, or `incremental` (default: `auto`)

**Outputs:**
- `notes-path`: Path to generated release notes file

**Features:**
- **Beta/RC/Hotfix Detection:** Automatically detects release type from tag pattern
- **Conventional Commit Parsing:** Groups commits by type (Added, Fixed, Changed, etc.)
- **Smart Reference Resolution:** Finds previous beta/RC/stable tags via GitHub API or git describe
- **Commit Links:** Generates markdown links to individual commits
- **Type-Specific Formatting:** RC builds include testing focus checklist, hotfixes include urgency notice
- **Fallback Handling:** Raw git log shown if no conventional commits detected

**Used by:** `cd_auto_prod.yml`, `cd_auto_beta.yml`, manual release workflows

---

### 8. `notify-telegram`
**Purpose:** Send build status and release notifications to Telegram (text-only).

**Inputs:**
- `telegram-token`: Telegram bot token (secret)
- `telegram-chat-id`: Target chat ID (secret)
- `notification-type`: `ci-failure`, `release`, `dev-build`, `beta-build`, `rc-build`, `build-skipped`, `hotfix-release`
- `tag`: Release tag (for release/beta/rc notifications)
- `branch`: Branch name (for dev/CI notifications)
- `commit`: Commit SHA (optional, defaults to `github.sha`)
- `status`: `success` or `failure` (default: `success`)
- `custom-message`: Custom message text (overrides templates)
- `changelog`: Changelog text (for dev/beta captions)
- `skip_reason`: Reason for build skip
- `actor`: GitHub username who triggered the action (optional)

**Design Decision:** This action sends **text-only notifications** using simple `curl` commands. Dev and beta builds bypass this action entirely and send APK files directly via inline `curl -F document=@...` steps in their respective workflows. This avoids HTTP 000 errors from complex multipart upload logic in composite actions.

**Features:**
- HTML parse mode with user-input escaping (prevents injection)
- Simple single `curl` command per message (proven reliable pattern)
- Sends download links to artifacts rather than attaching files
- Non-blocking: failures emit warnings without failing the workflow

**Used by:** Release, RC, and CI failure notifications. **Not used** for dev/beta APK uploads (those use inline curl).

---

### 9. `prepare-release-assets`
**Purpose:** Prepare the list of artifact files to be attached to a GitHub Release.

**Inputs:**
- `tag`: Release tag for artifact name prefix (required)
- `has-windows`: Whether Windows artifacts exist (required)
- `include-provenance`: Whether to include `.jsonl` provenance files (default: `true`)

**Outputs:**
- `files`: Newline-separated list of asset files to upload

**Steps:**
1. Scan for Android APK and signature files (`openmidicontrol-{tag}-android.{apk,sig,pem}`)
2. Scan for Windows ZIP and signature files (if `has-windows` is `true`)
3. Scan for provenance `.jsonl` files (if `include-provenance` is `true`)
4. Output file list as multiline string for use with `softprops/action-gh-release`
5. Log warnings for any missing files

**Used by:** All CD release workflows (`cd_auto_prod.yml`, `cd_auto_rc.yml`, `cd_auto_beta.yml`, `cd_man_hotfix.yml`, `cd_man_prod.yml`, `cd_man_retro.yml`)

---

### 10. `release-tag-validation`
**Purpose:** Validate release tag security invariants before production deployment.

**Inputs:**
- `tag`: Tag to validate (if empty, detects from `github.ref_name`)
- `allowed_actors`: Comma-separated allowlist of GitHub actors (empty means skip actor check)
- `gpg_public_key`: GPG public key content to import and validate tag signature
- `expected_fingerprint`: Expected GPG fingerprint for pinning
- `github_token`: GitHub token for API tag signature verification
- `main_branch`: Main branch to check ancestry against (default: `main`)

**Outputs:**
- `tag`: Resolved tag name
- `commit`: Tag commit hash
- `on_main`: Is tag on main branch (always `true` if validation passes)
- `has_windows`: Whether `app/windows` directory exists

**Validations:**
1. Actor validation (if `allowed_actors` provided)
2. Annotated tag requirement (`git cat-file -t` must be `tag`)
3. GPG signature verification with imported public key
4. Fingerprint pinning (prevents key substitution)
5. Main branch ancestry check (`git merge-base --is-ancestor`)
6. Tag retargeting protection (local vs remote commit comparison)
7. GitHub API tag signature verification (with retry logic, max 3 attempts)

**Used by:** Production release workflows as gatekeeper.

---

## Workflow Catalog

### Automated CD Pipelines (`cd_auto_*`)

#### `cd_auto_dev.yml`
**Trigger:** Push to `dev` branch
**Concurrency:** `dev-{workflow}-{ref}` (cancel-in-progress: true)

**Jobs:**
1. `analyze-and-test` - Flutter CI core (analysis + tests) — **Always runs** on push (skips for Dependabot)
2. `build-and-push-dev` - Build Android APK, normalize branch name, generate changelog from `git log`
3. Send Dev Build APK to Telegram - Direct `curl -F document=@...` upload with formatted caption

**Artifacts:** `app-{branch}-{sha}.apk` (sent directly to Telegram)
**Notification:** Dev build APK with change summary attached to Telegram message

**Telegram Behavior:** Uses inline `curl` command to send actual APK file with formatted caption. Bypasses `notify-telegram` composite action for reliable file uploads.
**APK Naming:** Normalizes branch name (strips prefixes like `feature/`, `fix/`, trailing dates) and uses first 7 chars of SHA: `app-{clean-branch}-{short-sha}.apk`

---

#### `cd_auto_beta.yml`
**Trigger:** Push to `beta` branch
**Concurrency:** `beta-{workflow}-{ref}` (cancel-in-progress: true)

**Jobs:**
1. `analyze-and-test` - Flutter CI core — **Always runs** on push (skips for Dependabot)
2. `build-rc` - Auto-generates beta tag via `gh release list` + `git rev-list --count`, builds Android APK
3. `build-windows` - Windows ZIP (if `windows/` directory exists) — conditional on `build-rc` success
4. `cosign-sign-verify` - Sign all artifacts with keyless OIDC
5. `provenance` - SLSA provenance attestation — conditional on build success
6. `create-draft-release` - Draft GitHub release with generated notes — conditional on provenance success
7. `notify-telegram` - Sends beta APK directly via `curl -F document=@...` with changelog caption

**Artifacts:** Signed APK + ZIP + Provenance (sent to Telegram + draft release)
**Notification:** Beta release APK with verification status attached to Telegram message

**Tag Generation:** Auto-generates `v{MAJOR}.{MINOR}.{PATCH}-beta.{N}` where N is commit count since last beta/stable tag.
**Telegram Behavior:** Downloads built APK, generates changelog via git log + GitHub CLI, sends actual APK file with rich formatted caption. Bypasses `notify-telegram` composite action for reliable file uploads.

---

#### `cd_auto_rc.yml`
**Trigger:** Push to `rc` branch
**Concurrency:** `rc-{workflow}-{ref}` (cancel-in-progress: true)

**Jobs:**
1. `analyze-and-test` - Flutter CI core — **Always runs** on push (skips for Dependabot)
2. `build-rc` - Auto-generates RC tag via `gh release list` + `git rev-list --count`, builds Android APK
3. `build-windows` - Windows ZIP (if `windows/` directory exists) — conditional on `build-rc` success
4. `cosign-sign-verify` - Sign all artifacts with keyless OIDC
5. `provenance` - SLSA provenance attestation — conditional on build success
6. `create-draft-release` - Draft GitHub release with generated notes — conditional on provenance success
7. `notify-telegram` - Sends RC APK directly via `curl -F document=@...` with changelog caption

**Artifacts:** Signed APK + ZIP + Provenance (sent to Telegram + draft release)
**Notification:** RC release APK with verification status attached to Telegram message

**Tag Generation:** Auto-generates `v{MAJOR}.{MINOR}.{PATCH}-rc.{N}` where N is commit count since last RC/beta/stable tag. Falls back through RC → beta → stable tags to find the previous release.
**Telegram Behavior:** Downloads built APK, generates changelog via git log + GitHub CLI, sends actual APK file with rich formatted caption. Bypasses `notify-telegram` composite action for reliable file uploads.

---

#### `cd_auto_prod.yml`
**Trigger:** Push to `v[0-9]+.[0-9]+.[0-9]+` tags (SemVer tags)
**Concurrency:** `release-{workflow}-{ref}` (cancel-in-progress: true)

**Jobs:**
1. `verify-tag-on-main` - Validates tag is annotated, GPG-signed, on main branch, not retargeted
2. `analyze-and-test` - Flutter CI core (skips if tag not on main)
3. `build-android` - Release APK with Cosign signing
4. `build-windows` - Windows ZIP with Cosign signing (if `windows/` exists)
5. `provenance` - SLSA provenance attestation
6. `publish-release` - Creates public GitHub release with generated notes
7. `notify-release` - Telegram notification via `notify-telegram` composite action

**Artifacts:** Signed APK + ZIP + Provenance (public GitHub release)
**Notification:** Production release announcement with download links

---

### Manual CD Pipelines (`cd_man_*`)

#### `cd_man_prod.yml`
**Trigger:** Manual dispatch (`workflow_dispatch`)
**Inputs:**
- `tag`: Tag to rebuild (e.g., `v1.0.2`)
- `force`: Force overwrite existing release assets (boolean)

**Jobs:**
1. `validate-tag` - Validates tag format, GPG signature, main branch ancestry
2. `analyze-and-test` - Restores modern CI actions from main, runs Flutter core
3. `build-android` - Release APK with Cosign signing
4. `build-windows` - Windows ZIP with Cosign signing (if `windows/` exists)
5. `provenance` - SLSA provenance attestation
6. `publish-release` - Updates GitHub release (deletes existing assets if `force` is true)
7. `notify-release` - Telegram notification with success/failure status

**Use Case:** Controlled production rebuilds for existing tags with optional force overwrite

---

#### `cd_man_hotfix.yml`
**Trigger:** Push to `v*-patch.*` tags (e.g., `v0.2.2-patch.1`)

**Jobs:**
1. `verify-patch-tag` - Parses base version and patch number, determines if first patch
2. `analyze-and-test` - Flutter CI core
3. `build-hotfix` - Android APK (+ Windows if supported), Cosign signing
4. `provenance` - SLSA provenance attestation
5. `create-hotfix-release` - Public GitHub release with smart changelog (since stable for patch.1, since previous patch for subsequent)
6. `notify-telegram` - Hotfix release notification with patch number and base version

**Use Case:** Urgent production fixes deployed as patch releases (e.g., `v0.2.2-patch.1`, `v0.2.2-patch.2`)

---

#### `cd_man_retro.yml`
**Trigger:** Manual dispatch (`workflow_dispatch`)
**Inputs:**
- `tag`: Tag to rebuild (e.g., `v0.2.1`)
- `force`: Force overwrite existing release assets (boolean)

**Jobs:**
1. `validate-tag` - Validates tag format, GPG signature, main branch ancestry
2. `analyze-and-test` - Restores modern CI actions from main, runs Flutter core (with `skip-format-check: true`)
3. `build-android` - Release APK with Cosign signing
4. `build-windows` - Windows ZIP with Cosign signing (if `windows/` exists)
5. `provenance` - SLSA provenance attestation
6. `publish-release` - Updates GitHub release (deletes existing assets if `force` is true)
7. `notify-release` - Telegram notification with success/failure status and failure stage detection

**Use Case:** Retroactive rebuilds of historical tags with legacy CI action restoration from main branch

---

### Automated CI Pipelines (`ci_auto_*`)

#### `ci_auto_main.yml`
**Trigger:** Push to `main` branch + Pull requests to `main`
**Path filters:** `app/**`, `.github/**`, `scripts/**`, `pubspec.yaml` (excludes `*.md`, `docs/**`)

**Jobs:**
1. `dependency-review` - Dependency review for PRs (fails on moderate severity, denies GPL-3.0/AGPL-3.0)
2. `analyze-and-test` - Flutter CI core with matrix strategy (`flutter-version: ['3.41.0', '3.41.6']`)
3. `build-android` - Debug APK build (push only)
4. `build-windows` - Debug Windows build (push only, conditional)

**Purpose:** Ensure main branch stability with multi-version Flutter testing and optional debug builds

---

#### `ci_auto_feature.yml`
**Trigger:** Push to all branches except `main`, `dev`, `beta`
**Path filters:** `app/**`, `.github/**`, `scripts/**`, `pubspec.yaml` (excludes `*.md`, `docs/**`)

**Jobs:**
1. `analyze-and-test` - Flutter CI core

**Purpose:** Validate feature branches before PR merge

---

### Validation Workflows (`validate_*`)

#### `validate_auto_yaml.yml`
**Trigger:** Push/PR to any branch modifying `.github/**` (excluding `*.md` files)
**Jobs:**
1. `yaml-lint` - YAML syntax validation using `.github/workflows/.yamllint` (ibiqlik/action-yamllint v3.4.0)
2. `actionlint` - GitHub Actions workflow schema validation (rhysd/actionlint v1.7.12)

**Configuration (`.github/workflows/.yamllint`):**
- Document start markers required (`---`)
- Line length: 150 (warning)
- Trailing spaces: warning
- Newlines: Unix (LF only)
- Comments: 1 space minimum from content
- Truthy values: `true`, `false`, `on`, `off` allowed (warning)

---

#### `validate_auto_license.yml`
**Trigger:** Push to `beta` branch; PRs targeting `main`, `beta`, `release/**`, or `hotfix/**`
**Jobs:**
1. `license-check` - Run `scripts/check_license_headers.py`

**Validation:**
- Checks all Dart, Kotlin, PowerShell, YAML, Python, Shell files
- Requires copyright notice + SPDX identifier
- Exit code 1 on failure (CI gate)
- Dependabot PRs excluded

---

#### `validate_pr_commitlint.yml`
**Trigger:** PR to `main`, `dev`, `release/**`, `hotfix/**` (types: `opened`, `synchronize`, `reopened`, `ready_for_review`)
**Jobs:**
1. `commitlint` - Validate all commits in PR using conventional commits (Node.js 20, `commitlint.config.js`)

**Configuration:**
- Skips draft PRs (`github.event.pull_request.draft == false`)
- Skips Dependabot PRs
- Validates from PR base SHA to head SHA
- Verbose output showing all violations

---

### Operational Workflows (`ops_*`)

#### `ops_schedule_stale.yml`
**Trigger:** Daily cron (`0 0 * * *`)  
**Jobs:**
1. `stale` - Mark and close inactive issues/PRs

**Configuration:**
- Stale threshold: 60 days
- Close after: 14 days (grace period)
- Exempt labels: `bug`, `security`
- Pinned to `actions/stale@b5d41d4e1d5dceea10e7104786b73624c18a190f` (v10.2.0)

**Messages:**
- Stale warning with closure timeline
- Closure notification with reason

---

## Dependabot Configuration

**File:** `.github/dependabot.yml`

### GitHub Actions
- **Schedule:** Monthly (Sunday 04:00 Asia/Kolkata)
- **Commit prefix:** `ci(actions)`
- **Grouping:** Minor/patch together, major separate

### Flutter/Pub
- **Schedule:** Monthly (Sunday 04:00 Asia/Kolkata)
- **Directory:** `app/`
- **Commit prefix:** `chore(deps)`
- **Grouping:** Minor/patch together, major separate
- **Limit:** 5 open PRs maximum

**Exemptions:** Dependabot PRs skip validation workflows to reduce CI noise.

---

## YAML Linting Configuration

**File:** `.github/workflows/.yamllint`

```yaml
# Rules enforced on all workflow files
rules:
  document-start: enable          # Requires --- at file beginning
  line-length:                    # Max 150 chars (warning)
    max: 150
    level: warning
  trailing-spaces: warn
  comments:
    min-spaces-from-content: 1
  new-lines:
    type: unix                   # LF only
  truthy:
    allowed-values: [true, false, on, off]
    level: warning
```

**Applied to:** `.github/workflows/*.yml`, `.github/actions/*/action.yml`

---

## Security Model

### Supply Chain Security
1. **Pinned Actions:** All third-party actions pinned to commit SHAs (not tags)
2. **Cosign Signing:** Keyless OIDC signing with GitHub OIDC issuer
3. **SLSA Provenance:** Native GitHub attestation for production builds
4. **GPG Verification:** Optional tag signature verification in `release-tag-validation`

### Secret Management
**Required Repository Secrets:**
- `TELEGRAM_TOKEN` - Bot token for notifications
- `TELEGRAM_CHAT_ID` - Target chat for messages
- `KEYSTORE_BASE64` - Base64-encoded Android signing keystore
- `KEY_PASSWORD` - Keystore key password
- `KEY_ALIAS` - Keystore key alias
- `STORE_PASSWORD` - Keystore store password

**Optional Secrets:**
- `GPG_PUBLIC_KEY` - For release tag verification
- `EXPECTED_GPG_FINGERPRINT` - Expected GPG key fingerprint
- `ALLOWED_RELEASE_ACTORS` - Comma-separated list of users who can trigger releases

### Permissions
All workflows use **least-privilege permissions**:
- Default: `contents: read`
- Release publishing: `contents: write`
- Stale management: `issues: write`, `pull-requests: write`
- Commitlint: `pull-requests: read`

---

## Migration History

### v0.2.2 CI/CD Overhaul (Commits: 5c09fab, d18b1cd, db2640a)

**Previous Architecture:**
- Monolithic workflows (`dev.yml`, `release.yml`)
- Duplicated build logic across files
- Inline configuration
- No reusable components

**New Architecture:**
- 10 modular composite actions
- 13 specialized workflow files
- Centralized configuration in `flutter-ci-core`
- DRY principle with single source of truth

**Deleted Files:**
- `.github/workflows/dev.yml` (119 lines)
- `.github/workflows/release.yml` (227 lines)

**New Files:**
- All 10 composite actions in `.github/actions/`
- 13 new workflow files following `type_trigger_tier` convention
- `.github/workflows/.yamllint` configuration
- `.github/dependabot.yml`

**Renamed Files:**
- `ci_dev.yml` → `cd_auto_dev.yml`
- `ci_beta.yml` → `cd_auto_beta.yml`
- `ci_main.yml` → `ci_auto_main.yml`
- `ci_feature.yml` → `ci_auto_feature.yml`
- `cd_prod_auto.yml` → `cd_auto_prod.yml`
- `cd_prod_man.yml` → `cd_man_prod.yml`
- `cd_prod_retro.yml` → `cd_man_retro.yml`
- `ci_rc.yml` → `cd_auto_rc.yml`
- `ci_hotfix.yml` → `cd_man_hotfix.yml`
- `stale.yml` → `ops_schedule_stale.yml`
- `commitlint.yml` → `validate_pr_commitlint.yml`
- `validate_workflows.yml` → `validate_auto_yaml.yml`
- `license_check.yml` → `validate_auto_license.yml`

### CI Optimization (Post-v0.2.2)

**Marker Detection Optimization:**
- Removed `check-build-markers` job from `cd_auto_dev.yml` (was spinning ubuntu runner just to grep commit messages)
- Removed `check-release-markers` job from `cd_auto_beta.yml` (same issue)
- Moved marker detection to native GitHub `if:` conditions at zero runner cost
- **Before:** Every push → ubuntu runner (~30s) → checks markers → skips/proceeds
- **After:** Every push → GitHub evaluates `contains()` inline (0s) → skips/proceeds

**Always-Run CI:**
- `analyze-and-test` now runs on every push to `dev`/`beta` (ensures code quality visibility)
- APK/release builds only triggered by `[dev]`, `[build]`, or `[beta]` markers

**Validation Scope Tightening:**
- `validate_auto_yaml.yml`: Now excludes `*.md` files (only triggers on `.yml`/`.yaml` changes)
- `validate_auto_license.yml`: PRs now target `main`, `beta`, `release/**`, `hotfix/**` (not `dev`)

### Telegram Reliability Improvements (April 2026)

**Problem:**
- Dev/beta builds failing to send APK files to Telegram (HTTP 000 errors)
- Complex retry logic, temp file handling, and multipart uploads in `notify-telegram` composite action causing network failures
- Over-engineered `generate-release-notes` action (350+ lines) with fragile git log parsing

**Simplification Strategy:**
- **Minimize failure points:** Remove complex retry loops, temp files, and response parsing from composite actions
- **Use proven patterns:** Match old working `dev.yml` approach (direct `curl -F document=@...`)
- **Keep architecture intact:** Preserve composite actions and workflow structure, only simplify internals
- **Bypass when needed:** Dev/beta builds skip `notify-telegram` entirely and upload APKs via inline curl

**Changes Made:**
- **`notify-telegram/action.yml`:** Simplified from 467 → 238 lines (removed document upload logic, retry loops)
- **`generate-release-notes/action.yml`:** Restored full version (350+ lines) with complete beta/RC/hotfix changelog generation
- **`cd_auto_dev.yml`:** Restored direct APK upload via inline `curl -F document=@...` (bypasses composite action)
- **`cd_auto_beta.yml`:** Restored direct APK upload + complex changelog generation (bypasses composite action)

**Result:**
- ✅ Dev builds send APK files to Telegram with rich changelogs
- ✅ Beta builds send APK files to Telegram with verification status
- ✅ Release notifications use text-only with download links (reliable)
- ✅ No more HTTP 000 errors from multipart uploads in composite actions
- ✅ Cosign signing and SLSA provenance completely untouched

---

## Troubleshooting

### Workflow Failures

**Symptom:** `validate_auto_yaml.yml` fails on push  
**Cause:** YAML syntax error or missing document start marker  
**Fix:** Run `python scripts/validate_workflows.py .github/workflows/your-file.yml` locally

**Symptom:** `validate_auto_license.yml` fails  
**Cause:** Missing SPDX license header in source file  
**Fix:** Run `python scripts/add_license_headers.py` to auto-add headers

**Symptom:** `validate_pr_commitlint.yml` fails  
**Cause:** Commit message doesn't follow conventional commits format  
**Fix:** Amend commit with proper format: `git commit --amend -m "type(scope): message"`

**Symptom:** Android build fails with keystore error  
**Cause:** Missing or invalid GitHub secrets  
**Fix:** Verify `KEYSTORE_BASE64`, `KEY_PASSWORD`, `KEY_ALIAS`, `STORE_PASSWORD` in repository settings

**Symptom:** Telegram notification not sent  
**Cause:** Invalid bot token or chat ID  
**Fix:** Test with `curl` using token from repository secrets

---

## Local Development

### Validate Workflows Locally

```bash
# Validate all workflows
python scripts/validate_workflows.py .github/workflows/*.yml

# Validate specific workflow
python scripts/validate_workflows.py .github/workflows/cd_auto_prod.yml

# Auto-fix common issues (CRLF, trailing spaces, emojis)
python scripts/validate_workflows.py --fix .github/workflows/*.yml
```

### Check License Headers

```bash
# Check all files for license headers
python scripts/check_license_headers.py

# Auto-add missing headers
python scripts/add_license_headers.py
```

### Test Commit Messages

```bash
# Install dependencies
npm install

# Test commit message format
npx commitlint --from HEAD~3 --to HEAD --verbose
```

---

## Contributing

When adding new workflows or actions:

1. **Follow naming convention:** `type_trigger_tier.yml`
2. **Pin all actions to SHAs:** Never use tags (e.g., `@v4` → `@de0fac2e4500dabe0009e67214ff5f5447ce83dd`)
3. **Add license headers:** Include copyright and SPDX identifier at top
4. **Document inputs/outputs:** Use composite action metadata format
5. **Test locally:** Run `python scripts/validate_workflows.py` before pushing
6. **Update this doc:** Add new workflows to the catalog above

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Reusable Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Cosign Keyless Signing](https://docs.sigstore.dev/signing/quickstart)
- [SLSA Provenance](https://slsa.dev/provenance/v1)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Dependabot Configuration](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
