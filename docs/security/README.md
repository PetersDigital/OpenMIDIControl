# Release Pipeline Documentation

## Workflow Implementation

The release process is implemented via:

- `.github/workflows/release_manual.yml`
- `.github/workflows/release.yml`

This repository now uses reusable action modules in `.github/actions`:
- `release-tag-validation`: tag authentication and GitHub signature validation
- `cosign-sign-verify`: artifact Cosign sign + verify
- `provenance-attestation`: `actions/attest` per artifact

`release_manual.yml` (manual tag rebuild) and `release.yml` (push tags) share the same security checks with minimal duplication.

## Overview

This repository uses a secure, manually triggered release pipeline built on GitHub Actions. The workflow enforces strong guarantees around:

- Tag authenticity (GPG + GitHub verification)
- Actor authorization
- Artifact integrity (Cosign keyless signing)
- Build provenance (GitHub attestations)

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
|------|-----------|
| Source | GPG signed tags |
| Identity | Actor allowlist |
| Integrity | Cosign signatures |
| Provenance | GitHub attestations |
| Tampering | Tag consistency checks |

---

## Result

This pipeline provides a high-assurance release process aligned with modern supply chain security practices.
