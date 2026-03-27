# GitHub Actions Modularization Guide

## Overview

This directory has been refactored to follow DRY (Don't Repeat Yourself) principles by extracting shared workflow logic into **Composite Actions**. This reduces duplication, improves maintainability, and ensures consistent behavior across all CI/CD pipelines.

## Composite Actions Structure

```
.github/
├── actions/
│   ├── flutter-ci-core/           # Existing: Setup, analysis, and testing
│   ├── release-tag-validation/    # Existing: Tag security validation
│   ├── cosign-sign-verify/        # Existing: Keyless artifact signing
│   ├── provenance-attestation/    # Existing: SLSA provenance generation
│   ├── flutter-build-android/     # NEW: Android APK build with keystore
│   ├── flutter-build-windows/     # NEW: Windows build with ZIP packaging
│   ├── generate-release-notes/    # NEW: Changelog extraction for releases
│   ├── notify-telegram/           # NEW: Telegram notifications
│   └── download-and-prepare-artifacts/  # NEW: Artifact download helper
└── workflows/
    ├── ci_main.yml                # Continuous Integration
    ├── cd_prod_auto.yml           # Automated production releases
    ├── cd_prod_man.yml            # Manual production rebuilds
    ├── cd_dev_dist.yml            # Development distribution
    └── cd_prod_retro.yml          # Legacy retroactive rebuilds
```

## New Composite Actions

### 1. `flutter-build-android`

**Purpose:** Centralizes Android APK build logic including keystore configuration.

**Inputs:**
- `working-directory` - Flutter project path (default: `app`)
- `keystore-base64` - Base64-encoded Android keystore
- `key-password` - Android key password
- `key-alias` - Android key alias
- `store-password` - Android store password
- `build-type` - Build type: `release`, `debug`, or `profile` (default: `release`)
- `split-per-abi` - Build separate APKs per ABI (`true`/`false`, default: `false`)
- `artifact-name` - Custom output APK name (without `.apk` extension)

**Outputs:**
- `apk-path` - Full path to the built APK
- `apk-name` - Name of the APK file

**Example Usage:**
```yaml
- name: Build Android APK
  uses: ./.github/actions/flutter-build-android
  with:
    working-directory: app
    keystore-base64: ${{ secrets.KEYSTORE_BASE64 }}
    key-password: ${{ secrets.KEY_PASSWORD }}
    key-alias: ${{ secrets.KEY_ALIAS }}
    store-password: ${{ secrets.STORE_PASSWORD }}
    build-type: release
    artifact-name: openmidicontrol-v1.0.0-android
```

---

### 2. `flutter-build-windows`

**Purpose:** Centralizes Windows build and ZIP packaging logic.

**Inputs:**
- `working-directory` - Flutter project path (default: `app`)
- `build-type` - Build type: `release`, `debug`, or `profile` (default: `release`)
- `artifact-name` - Custom output ZIP name (without `.zip` extension)

**Outputs:**
- `zip-path` - Full path to the created ZIP archive
- `zip-name` - Name of the ZIP file

**Example Usage:**
```yaml
- name: Build Windows ZIP
  uses: ./.github/actions/flutter-build-windows
  with:
    working-directory: app
    build-type: release
    artifact-name: openmidicontrol-v1.0.0-windows
```

---

### 3. `generate-release-notes`

**Purpose:** Extracts changelog sections and generates formatted GitHub release notes.

**Inputs:**
- `tag` - Release tag (e.g., `v1.0.0`)
- `changelog-path` - Path to CHANGELOG.md (default: `CHANGELOG.md`)
- `include-metadata` - Include build metadata section (default: `true`)
- `commit-hash` - Commit hash for metadata (optional)
- `triggered-by` - Username who triggered the release (optional)

**Outputs:**
- `notes-path` - Path to the generated release notes file

**Example Usage:**
```yaml
- name: Generate Release Notes
  uses: ./.github/actions/generate-release-notes
  with:
    tag: ${{ needs.validate-tag.outputs.tag }}
    changelog-path: CHANGELOG.md
    include-metadata: 'true'
    commit-hash: ${{ needs.validate-tag.outputs.tag_commit }}
```

---

### 4. `notify-telegram`

**Purpose:** Centralizes Telegram notification logic for all workflow types.

**Inputs:**
- `telegram-token` - Telegram Bot Token
- `telegram-chat-id` - Telegram Chat ID
- `notification-type` - Type: `ci-failure`, `release`, `dev-build`
- `tag` - Release tag (for release notifications)
- `branch` - Branch name (for dev/CI notifications)
- `commit` - Commit SHA (optional, defaults to `github.sha`)
- `status` - Status: `success` or `failure`
- `custom-message` - Custom message text (overrides templates)
- `artifact-path` - Path to artifact file (for dev builds)
- `changelog` - Changelog text (for dev build captions)

**Example Usage:**
```yaml
# Release notification
- name: Notify Telegram
  uses: ./.github/actions/notify-telegram
  with:
    telegram-token: ${{ secrets.TELEGRAM_TOKEN }}
    telegram-chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    notification-type: release
    tag: ${{ needs.validate-tag.outputs.tag }}
    status: ${{ needs.publish-release.result }}

# CI failure notification
- name: Notify Telegram
  uses: ./.github/actions/notify-telegram
  with:
    telegram-token: ${{ secrets.TELEGRAM_TOKEN }}
    telegram-chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    notification-type: ci-failure

# Dev build with artifact
- name: Send APK to Telegram
  uses: ./.github/actions/notify-telegram
  with:
    telegram-token: ${{ secrets.TELEGRAM_TOKEN }}
    telegram-chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    notification-type: dev-build
    branch: ${{ github.ref_name }}
    artifact-path: app/build/app/outputs/flutter-apk/app-debug.apk
    changelog: ${{ steps.changelog.outputs.text }}
```

---

### 5. `download-and-prepare-artifacts`

**Purpose:** Simplifies artifact download and merging for release publishing.

**Inputs:**
- `artifact-pattern` - Pattern to match artifacts (default: `*`)
- `merge-multiple` - Merge multiple artifacts into single directory (default: `true`)
- `retention-days` - Artifact retention days (default: `1`)

**Outputs:**
- `artifacts-dir` - Directory containing downloaded artifacts

**Example Usage:**
```yaml
- name: Download Artifacts
  uses: ./.github/actions/download-and-prepare-artifacts
  with:
    artifact-pattern: '*'
    merge-multiple: 'true'
```

---

## Refactoring Benefits

### Before (Duplication)
Each workflow contained 50-100+ lines of duplicated logic for:
- Keystore setup (15 lines × 4 workflows = 60 lines)
- Flutter build commands (5 lines × 8 jobs = 40 lines)
- Artifact renaming (10 lines × 6 jobs = 60 lines)
- Telegram notifications (20 lines × 5 workflows = 100 lines)
- Release notes generation (25 lines × 3 workflows = 75 lines)

**Total duplicated code: ~335 lines**

### After (Modular)
- Single source of truth for each concern
- Workflows reduced from 250+ lines to ~150 lines
- Easier to test and maintain
- Consistent behavior across all pipelines
- Security updates applied in one place

---

## Migration Checklist

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

---

## Testing Changes

Before merging changes to workflow files:

1. **Validate YAML syntax:**
   ```bash
   python -c "import yaml; yaml.safe_load(open('.github/workflows/ci_main.yml'))"
   ```

2. **Use GitHub's workflow validator:**
   - Push to a feature branch
   - Check the Actions tab for syntax errors

3. **Test with workflow_dispatch:**
   - Use `cd_prod_man.yml` or `cd_prod_retro.yml` for manual testing
   - Verify all composite actions execute correctly

---

## Best Practices

1. **Keep actions focused:** Each composite action should do one thing well
2. **Use outputs:** Pass data between jobs via outputs, not artifacts when possible
3. **Document inputs/outputs:** Every input and output should have a description
4. **Default values:** Provide sensible defaults for optional inputs
5. **Error handling:** Include validation and clear error messages in actions
6. **Security:** Never log secrets; use environment variables for sensitive data

---

## Troubleshooting

### Common Issues

**Issue:** `Error: Input required and not supplied: keystore-base64`
- **Solution:** Ensure the secret is defined in repository settings

**Issue:** `Error: Unable to find artifact`
- **Solution:** Check that the artifact was uploaded with the expected name pattern

**Issue:** `Error: Tag signature invalid`
- **Solution:** Verify GPG key setup and that the tag was created with the correct key

**Issue:** Composite action not found
- **Solution:** Ensure the path is relative to the repository root (e.g., `./.github/actions/...`)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-27 | Initial modularization: 5 new composite actions |
