# Release Pipeline Documentation

## Workflow Implementation

The release process is implemented via:

- `.github/workflows/cd_auto_prod.yml`
- `.github/workflows/cd_man_prod.yml`
- `.github/workflows/cd_man_retro.yml`
- `.github/workflows/cd_man_hotfix.yml`

This repository now uses reusable action modules in `.github/actions`:

- `release-tag-validation`: tag authentication and GitHub signature validation
- `flutter-build-android`: Android release artifact build
- `flutter-build-windows`: Windows release artifact build (optional)
- `cosign-sign-verify`: artifact Cosign sign + verify
- `provenance-attestation`: `actions/attest` per artifact
- `generate-release-notes`: structured notes from changelog + commits
- `prepare-release-assets`: canonical asset set selection for publish
- `notify-telegram`: release/failure notifications with action links

These workflows share the same hardening controls with minimal duplication through composite actions.

## Overview

This repository uses secure tag-triggered and manual rebuild release pipelines built on GitHub Actions. The workflows enforce strong guarantees around:

- Branch promotion integrity (`dev -> beta/rc -> main`)
- Tag authenticity (GPG + GitHub verification)
- Actor authorization
- Artifact integrity (Cosign keyless signing)
- Build provenance (GitHub attestations)
- Dependency update hygiene (Dependabot weekly checks + grouped security updates)

---

## Workflow Structure

### 1. Tag Validation (`validate-tag`)

This job enforces strict security controls:

- Actor allowlist validation
- Tag format enforcement (`v*`)
- Annotated tag requirement
- GPG signature verification
- Fingerprint pinning (prevents key substitution)
- GitHub API verification of signature
- Main branch ancestry check
- Tag retargeting protection

Related branch policy:

- Pre-main promotion sync check (`beta`/`rc` must already be present in `dev` before merge to `main`)

Output:

- Resolved commit hash
- Validated tag name
- Windows build availability flag

---

### 2. Analysis & Testing

- Runs Flutter dependency resolution
- Static analysis (`flutter analyze`)
- Unit tests (`flutter test`)

---

### 3. Build

#### Android

- Builds release APK
- Signs APK using Cosign (keyless, OIDC)
- Verifies signature immediately

#### Windows (optional)

- Builds Windows executable
- Packages into ZIP
- Signs and verifies using Cosign

---

## Artifact Signing (Cosign)

Artifacts are signed using Sigstore Cosign in keyless mode:

- Uses GitHub OIDC identity
- Generates:
  - `.sig` (signature)
  - `.pem` (certificate)

Verification ensures:

- Signature validity
- Identity bound to repository
- Issuer is GitHub

### Hardening details in workflow

- Post-sign step includes `cosign verify-blob` with:
  - `--certificate-identity-regexp "https://github.com/<owner>/<repo>"`
  - `--certificate-oidc-issuer https://token.actions.githubusercontent.com`
- Tag verification step now validates GitHub API HTTP status and dumps response on failure
- Additional retargeting check: local commit vs remote tag commit must match

---

## Provenance (SLSA Attestation)

- Uses `actions/attest` (replaces legacy `actions/attest-build-provenance`)
- Generates verifiable metadata about build process
- Tied to specific artifacts

---

## Release Publishing

- Downloads signed artifacts
- Optionally deletes existing assets (force mode)
- Generates release notes from CHANGELOG
- Publishes via GitHub Releases

---

## Notification

- Sends Telegram notification with status
- Includes release and workflow links

---

## Security Model Summary

| Layer | Protection |
| ------ | ----------- |
| Source | GPG signed tags |
| Identity | Actor allowlist |
| Integrity | Cosign signatures |
| Provenance | GitHub attestations |
| Tampering | Tag consistency checks |

---

## Dependency Security (Dependabot)

Dependency update automation is defined in `.github/dependabot.yml` and is part of the release security posture.

- Cadence: weekly (`Sunday 04:00 Asia/Kolkata`)
- Target branch: `dev`
- Ecosystems covered:
  - GitHub Actions (`/`)
  - npm (`/`)
  - pub (`/app`)
- Security posture:
  - Dedicated `security-updates` groups are enabled for all three ecosystems
  - Security fixes are surfaced as grouped Dependabot PRs for faster triage
- Noise control:
  - `pub` updates are limited to `open-pull-requests-limit: 5`

This keeps dependency risk continuously monitored without creating uncontrolled PR volume.

---

## Result

These workflows provide a high-assurance release process aligned with modern supply chain security practices.
