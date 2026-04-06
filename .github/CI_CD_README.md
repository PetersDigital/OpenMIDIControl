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
    ├── cd_auto_*.yml           # Automated CD pipelines (dev, beta, prod)
    ├── cd_man_*.yml            # Manual CD pipelines (prod, rc, hotfix, retro)
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
**Purpose:** Shared Flutter environment setup, static analysis, testing, and Windows detection.

**Inputs:**
- `working-directory`: Path to Flutter project (default: `app`)

**Steps:**
1. Checkout code
2. Setup Flutter (stable channel, cache enabled)
3. Run `flutter pub get`
4. Static analysis (`flutter analyze --fatal-infos`)
5. Unit tests (`flutter test`)
6. Detect Windows platform support (`has_windows` output)

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
**Purpose:** Generate SLSA provenance attestation for build artifacts.

**Inputs:**
- `subject_path`: Path to artifact
- `repository`: GitHub repository slug

**Output:**
- GitHub-native provenance attestation (SLSA Level 2-3)

**Used by:** Production release workflows for supply chain security.

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
**Purpose:** Parse CHANGELOG.md and generate release notes from conventional commits.

**Inputs:**
- `version`: Version string (e.g., `0.2.2`)
- `changelog-path`: Path to CHANGELOG.md (default: `CHANGELOG.md`)

**Outputs:**
- `release-notes`: Formatted release notes string
- `has-changelog`: Boolean indicating if entry was found

**Features:**
- Extracts changelog section for specific version
- Falls back to conventional commit parsing if no changelog entry
- Groups commits by type (Added, Fixed, Changed, etc.)
- Generates "What's Changed" header with source attribution

---

### 8. `notify-telegram`
**Purpose:** Send build status, artifacts, and release notifications to Telegram.

**Inputs:**
- `telegram-token`: Telegram bot token (secret)
- `telegram-chat-id`: Target chat ID (secret)
- `notification-type`: `ci-failure`, `release`, `dev-build`, `beta-build`, `rc-build`, `build-skipped`, `hotfix-release`
- `tag`: Release tag (for release/beta/rc notifications)
- `branch`: Branch name (for dev/CI notifications)
- `commit`: Commit SHA (optional, defaults to `github.sha`)
- `status`: `success` or `failure` (default: `success`)
- `custom-message`: Custom message text (overrides templates)
- `artifact-path`: Path to file attachment (for dev/beta builds)
- `changelog`: Changelog text (for dev/beta captions)
- `skip_reason`: Reason for build skip
- `actor`: GitHub username who triggered the action (optional)

**Features:**
- HTML parse mode with user-input escaping (prevents injection)
- URL-encoded POST for text messages, multipart for documents
- Validates Telegram JSON `ok` field, not just HTTP status
- Retries on 429 (respects `retry_after`) and 5xx (exponential backoff, max 5 attempts)
- Enforces Telegram size limits: 4096 chars (text), 1024 chars (captions)
- Non-blocking: document upload failures emit warnings without failing the workflow

**Used by:** All CD workflows for team notifications.

---

### 9. `prepare-release-assets`
**Purpose:** Prepare and organize release artifacts with consistent naming and metadata.

**Inputs:**
- `artifacts-dir`: Directory containing build artifacts
- `version`: Release version string
- `artifact-prefix`: Custom prefix for artifact naming (optional)

**Outputs:**
- `prepared-dir`: Directory with organized artifacts
- `manifest`: JSON manifest of prepared assets

**Steps:**
1. Collect artifacts from build directory
2. Rename with version and platform identifiers
3. Generate checksums (SHA256, MD5)
4. Create artifact manifest with metadata
5. Validate all artifacts present before proceeding

**Used by:** Release workflows to ensure consistent artifact organization.

---

### 10. `release-tag-validation`
**Purpose:** Validate release tags before production deployment.

**Inputs:**
- `expected-branch`: Target branch (default: `main`)
- `allowed-actors`: Comma-separated list of users allowed to trigger releases

**Validations:**
1. Tag commit must be on expected branch (merge-base check)
2. GPG signature verification (if enabled)
3. Actor allowlist check
4. Tag format validation (`v[0-9]+.[0-9]+.[0-9]+`)

**Used by:** Production release workflows as gatekeeper.

---

## Workflow Catalog

### Automated CD Pipelines (`cd_auto_*`)

#### `cd_auto_dev.yml`
**Trigger:** Push to `dev` branch
**Concurrency:** `dev-{workflow}-{ref}` (cancel-in-progress: true)

**Marker Control:**
- `[dev]` or `[build]` → Triggers APK build + Telegram notification
- `[wip]` or `[skip-build]` → Skips APK build (tests still run)
- No marker → Runs `analyze-and-test` only (no build)

**Jobs:**
1. `analyze-and-test` - Flutter CI core (analysis + tests) — **Always runs** on push
2. `build-android` - Split-per-ABI release APK — Only on `[dev]`/`[build]`
3. `notify-telegram` - Send APK with changelog summary — Only on `[dev]`/`[build]`

**Artifacts:** `app-dev-{sha}.apk`
**Notification:** Dev build announcement with change summary

---

#### `cd_auto_beta.yml`
**Trigger:** Push to `beta` branch
**Concurrency:** `beta-{workflow}-{ref}` (cancel-in-progress: true)

**Marker Control:**
- `[beta]` → Triggers full release pipeline (build, sign, provenance, draft release)
- `[wip]` or `[skip-release]` → Skips release pipeline (tests still run)
- No marker → Runs `analyze-and-test` only (no release)

**Jobs:**
1. `analyze-and-test` - Flutter CI core — **Always runs** on push
2. `build-android` - Release APK (no split) — Only on `[beta]`
3. `build-windows` - Windows ZIP (if supported) — Only on `[beta]`
4. `cosign-sign-verify` - Sign all artifacts — Only on `[beta]`
5. `notify-telegram` - Beta build notification — Only on `[beta]`

**Artifacts:** Signed APK + ZIP
**Notification:** Beta release with verification status

---

#### `cd_auto_prod.yml`
**Trigger:** Push to `main` branch matching version tags  
**Concurrency:** `prod-{workflow}-{ref}` (cancel-in-progress: true)

**Jobs:**
1. `verify-tag` - Tag validation gate
2. `analyze-and-test` - Flutter CI core
3. `build-android` - Release APK
4. `build-windows` - Windows ZIP
5. `provenance-attestation` - SLSA provenance
6. `cosign-sign-verify` - Sign artifacts
7. `publish-release` - Create GitHub release with notes
8. `notify-telegram` - Release announcement

**Artifacts:** Signed APK + ZIP + Provenance  
**Notification:** Production release announcement with download links

---

### Manual CD Pipelines (`cd_man_*`)

#### `cd_man_prod.yml`
**Trigger:** Manual dispatch (`workflow_dispatch`)  
**Inputs:**
- `version`: Release version (e.g., `0.2.2`)
- `ref`: Git ref to build (default: `main`)

**Jobs:** Same as `cd_auto_prod.yml` with manual approval  
**Use Case:** Controlled production releases with human oversight

---

#### `cd_man_rc.yml`
**Trigger:** Manual dispatch  
**Inputs:**
- `rc-version`: Release candidate version (e.g., `0.2.2-rc.1`)
- `ref`: Git ref (default: `release/**`)

**Jobs:**
1. Build Android + Windows
2. Upload as pre-release artifacts
3. Notify Telegram for testing coordination

**Use Case:** Pre-release validation builds

---

#### `cd_man_hotfix.yml`
**Trigger:** Manual dispatch  
**Inputs:**
- `hotfix-version`: Hotfix version
- `ref`: Hotfix branch (e.g., `hotfix/crash-fix`)

**Jobs:**
1. Quick validation (skip full test suite)
2. Build patched APK
3. Emergency Telegram notification

**Use Case:** Critical bug fixes requiring immediate deployment

---

#### `cd_man_retro.yml`
**Trigger:** Manual dispatch  
**Inputs:**
- `historical-tag`: Past git tag to rebuild

**Jobs:**
1. Checkout historical commit
2. Rebuild with current toolchain
3. Publish as separate release

**Use Case:** Reproducing legacy builds for archival or compliance

---

### Automated CI Pipelines (`ci_auto_*`)

#### `ci_auto_main.yml`
**Trigger:** Push to `main` branch (non-tag)  
**Jobs:**
1. `analyze-and-test` - Flutter CI core
2. `notify-telegram` - Failure notification only

**Purpose:** Ensure main branch stability without auto-deployment

---

#### `ci_auto_feature.yml`
**Trigger:** Push to `feature/*`, `feat/*` branches  
**Jobs:**
1. `analyze-and-test` - Flutter CI core

**Purpose:** Validate feature branches before PR merge

---

### Validation Workflows (`validate_*`)

#### `validate_auto_yaml.yml`
**Trigger:** Push/PR to any branch modifying `.github/**` (excluding `*.md` files)
**Path Filter:** `.github/**/*.yml`, `.github/**/*.yaml`, `.github/dependabot.yml`
**Jobs:**
1. `yaml-lint` - YAML syntax validation using `.github/workflows/.yamllint`
2. `actionlint` - GitHub Actions schema validation with shellcheck

**Configuration:**
- Document start markers required (`---`)
- Line length: 150 (warning)
- Trailing spaces: warning
- Newlines: Unix (LF only)
- Dependabot PRs excluded

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
**Trigger:** PR to `main`, `dev`, `release/**`, `hotfix/**`  
**Jobs:**
1. `commitlint` - Validate all commits in PR using conventional commits

**Configuration:**
- Runs on `opened`, `synchronize`, `reopened`, `ready_for_review`
- Skips draft PRs
- Uses `commitlint.config.js` from repository root
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
- `ci_rc.yml` → `cd_man_rc.yml`
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
