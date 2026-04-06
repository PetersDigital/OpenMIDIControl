# GitHub Setup Guide

## Required Secrets

Go to: Settings → Secrets and variables → Actions

### Secrets

#### GPG_PUBLIC_KEY
- Export using: `gpg --armor --export your-email@example.com`

#### EXPECTED_GPG_FINGERPRINT
- Get using: `gpg --fingerprint`

#### KEYSTORE_BASE64
- Base64 encode Android keystore (PowerShell 7):
```powershell
  [Convert]::ToBase64String([System.IO.File]::ReadAllBytes('upload-keystore.jks'))
```

- (Unix/macOS/Linux alternative):
```
  base64 -w0 upload-keystore.jks
```

#### First-time: generate upload-keystore.jks if missing
- Create the keystore file in the working folder (PowerShell 7):
  ```powershell
  keytool -genkeypair -v -keystore upload-keystore.jks -alias openmidicontrol \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass $STORE_PASSWORD -keypass $KEY_PASSWORD \
    -dname "CN=Your Name, OU=OrgUnit, O=Org, L=City, S=State, C=Country"
  ```

- Unix/macOS/Linux equivalent:
  ```bash
  keytool -genkeypair -v -keystore upload-keystore.jks -alias openmidicontrol \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$STORE_PASSWORD" -keypass "$KEY_PASSWORD" \
    -dname "CN=Your Name, OU=OrgUnit, O=Org, L=City, S=State, C=Country"
  ```

- Verify keystore:
  ```powershell
  keytool -list -v -keystore upload-keystore.jks -storepass $STORE_PASSWORD
  ```

- Then encode:
  PowerShell 7:
  ```powershell
  [Convert]::ToBase64String([System.IO.File]::ReadAllBytes('upload-keystore.jks'))
  ```
  Unix/macOS/Linux:
  ```bash
  base64 -w0 upload-keystore.jks
  ```

#### STORE_PASSWORD
- Keystore password

#### KEY_PASSWORD
- Key password

#### KEY_ALIAS
- Alias used in keystore

#### TELEGRAM_TOKEN
- Bot token from BotFather

#### TELEGRAM_CHAT_ID
- Chat ID for notifications

---

## Required Variables

### ALLOWED_RELEASE_ACTORS
Comma-separated GitHub usernames allowed to trigger releases.

Example: `user1,user2`

---

## Repository Settings

### Permissions
Ensure:
- Actions enabled
- Workflow permissions:
  - Read and write
  - Allow GitHub Actions to create attestations

---

## GPG Setup (Local)

Ensure you:
- Generate a GPG key:
```bash
  gpg --full-generate-key
```
- Configure Git:
```bash
  git config --global user.signingkey <KEY_ID>
  git config --global commit.gpgsign true
```

- Create signed tag (PowerShell 7 and Unix):
```bash
  git tag -s v1.0.0 -m "release"
```

- Push tag (PowerShell 7 and Unix):
```bash
  git push origin v1.0.0
```

---

## Cosign Keyless Setup

No keys required.

Requirements:
- GitHub Actions OIDC enabled
- `id-token: write` permission in workflow

## Reusable Release Actions

To keep the release workflow hardening centralized, this repo now uses:
- `.github/actions/release-tag-validation/action.yml` for tag and API validation
- `.github/actions/cosign-sign-verify/action.yml` for artifact signing + verification
- `.github/actions/provenance-attestation/action.yml` for attestations

These are used across release workflows:
- `.github/workflows/cd_auto_prod.yml`
- `.github/workflows/cd_man_prod.yml`
- `.github/workflows/cd_man_retro.yml`
- `.github/workflows/cd_man_hotfix.yml`

---

## Verification (Post Release)

### Verify Signature

```powershell
cosign verify-blob \
  --certificate file.pem \
  --signature file.sig \
  --certificate-identity-regexp "https://github.com/<repo>" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  file
```

---

## Notes

- Only annotated, signed tags are allowed
- Releases must originate from main branch
- Unauthorized actors cannot trigger builds
- All artifacts are signed and verifiable

---

## Outcome

After setup, every release will be:
- Cryptographically signed
- Identity verified
- Provenance attested
