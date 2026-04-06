# Supply Chain Security Deep Dive

## Overview

This document provides a formal description of the release pipeline using industry-standard supply chain security terminology, including SLSA concepts, trust boundaries, and verification workflows.

---

## Architecture Overview

```
Developer (GPG Key)
        │
        ▼
Signed Git Tag (Annotated + GPG)
        │
        ▼
GitHub Actions (OIDC Identity)
        │
        ├── Build
        │     ├── Android APK
        │     └── Windows ZIP
        │
        ├── Cosign Keyless Signing
        │     ├── Signature (.sig)
        │     └── Certificate (.pem)
        │
        ├── Verification (in CI)
        │
        └── Provenance Attestation (SLSA)
                │
                ▼
        GitHub Release (Artifacts + Metadata)
```

---

## Trust Model

### 1. Source Integrity

- Enforced via GPG-signed annotated tags
- Verified both locally and via GitHub API
- Fingerprint pinning prevents key substitution

### 2. Build Integrity

- Build runs in GitHub-hosted runners
- Identity established via OIDC tokens
- No long-lived secrets required for signing

### 3. Artifact Integrity

- Signed using Sigstore Cosign (keyless)
- Certificates bind artifact to:
  - Repository
  - Workflow identity
  - OIDC issuer

### 4. Provenance

- Generated using GitHub native attestation
- Includes:
  - Builder identity
  - Source repository
  - Commit SHA
  - Workflow metadata

---

## SLSA Mapping

| Requirement | Status |
|------------|--------|
| Source control versioning | Yes |
| Provenance available | Yes |
| Authenticated provenance | Yes |
| Build service isolation | GitHub-hosted runners |
| Ephemeral credentials | Yes (OIDC) |
| Artifact signing | Yes (Cosign) |

Approximate Level: **SLSA Level 2–3**

---

## Threat Model & Mitigations

### Tag Forgery
Mitigation:
- GPG signature verification via `release-tag-validation` action
- GitHub API tag signature verification with HTTP code+reason logging
- Fingerprint pinning

### Tag Retargeting
Mitigation:
- Local vs remote commit comparison in `release-tag-validation`
- `git fetch --tags --force` + remote `git ls-remote` check
- CI checks in `cd_auto_prod.yml`, `cd_man_prod.yml`, and `cd_man_retro.yml` include `git fetch --tags --force` + `git ls-remote --tags origin "$TAG"` to prevent retargeting after signing

### Unauthorized Release Trigger
Mitigation:
- Actor allowlist

### Artifact Tampering
Mitigation:
- Cosign signature verification

### Compromised CI Secrets
Mitigation:
- Keyless signing (no private keys stored)

---

## Verification Guide (End Users)

Users can independently verify artifacts.

### Step 1: Download Files

- Artifact (e.g., APK or ZIP)
- `.sig` (signature)
- `.pem` (certificate)

---

### Step 2: Install Cosign

`https://docs.sigstore.dev/cosign/installation/`

---

### Step 3: Verify Artifact

```powershell
cosign verify-blob \
  --certificate file.pem \
  --signature file.sig \
  --certificate-identity-regexp "https://github.com/<owner>/<repo>" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  file
```

---

### Expected Result

- Verification succeeds
- Certificate identity matches repository
- Issuer is GitHub OIDC

---

## Provenance Verification

To inspect provenance:

- Navigate to GitHub Release
- Locate attached attestation
- Use GitHub CLI or API to verify

---

## Security Guarantees

This pipeline guarantees:

- Only authorized maintainers can release
- Releases originate from verified source tags
- Artifacts are tamper-evident
- Builds are traceable to source and workflow

---

## Conclusion

This implementation follows modern supply chain security practices using:

- GPG (source authenticity)
- OIDC (identity)
- Cosign (artifact signing)
- GitHub Attestations (provenance)

It provides a verifiable and transparent release process suitable for high-trust distribution.
