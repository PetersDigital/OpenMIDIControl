# OpenMIDIControl Scripts

This folder contains organizational, build-assistance, and development workflow scripts. All scripts are written in **Python 3** for cross-platform compatibility (Windows, macOS, Linux) — no PowerShell dependency required.

## Prerequisites

All scripts require:

- **Python 3.9+** (tested with 3.11+)
- **Git** (for git-dependent scripts)

Some scripts have additional dependencies:

| Script | Additional Dependencies |
| -------- | ------------------------ |
| `commit.py` | commitlint (optional) — `npm install` or available via `npx`/`pnpm`/`yarn` |
| `validate_workflows.py` | actionlint, yamllint (optional, validates without them too) |
| `run_app.py` | Flutter SDK |
| `update_changelog.py` | None (stdlib only) |
| All other scripts | None (stdlib only) |

Install Node.js dependencies for full commitlint validation:

```bash
npm install  # Installs @commitlint/cli, @commitlint/config-conventional, husky
```

## Commit Helper

### `commit.py` — Interactive Conventional Commit Helper

Guides users through creating valid conventional commit messages with type/scope selection, local validation, and auto-commit. Ensures 100% commitlint compliance for automated changelog and release notes generation.

**Features:**

- Interactive mode with numbered lists for type and scope selection
- Auto-suggest scope based on staged file paths
- Custom scope entry with lowercase validation
- Local regex validation before commitlint dependency check
- Multiline commit message support with proper `git commit -m` handling
- Commitlint fallback hierarchy (npx → pnpm → yarn → npx with install)
- Edit loop to preview and refine message before committing (description, scope, body)
- `--no-verify` flag to bypass git hooks
- Merge commit support with branch-pattern scopes (`main/release`, `dev/main`, etc.)
- Full parity with `commitlint.config.js` types and scopes

**Usage:**

```bash
python scripts/commit.py                    # Interactive mode
python scripts/commit.py "feat(ui): add button"  # Direct mode
python scripts/commit.py --no-verify        # Bypass git hooks
```

**Dependencies:** Python 3.9+ (stdlib only), Git, commitlint (optional)

## Build & Run

### `run_app.py` — Cross-Platform Flutter Launcher

Unified Flutter app launcher replacing legacy PowerShell scripts. Works on Windows, macOS, and Linux without PowerShell dependency.

**Features:**

- Automatic `pubspec.yaml` discovery in root or subdirectories
- Interactive device selection via `flutter devices --machine`
- Android release signing with `.env.ps1` keystore configuration
- Colored terminal output with clear error messages

**Usage:**

```bash
python scripts/run_app.py                   # Debug mode (default)
python scripts/run_app.py --release         # Release mode with signing
python scripts/run_app.py --help            # Show all options
```

**Dependencies:** Python 3.9+, Flutter SDK

## Changelog & Release Tools

### `update_changelog.py` — CHANGELOG.md Auto-Generator

Generates or updates `CHANGELOG.md` from git log using conventional commit format. Uses path-based routing to keep infrastructure changes separate from app development changes.

**Features:**

- Interactive mode with tag selection
- Auto-detects version from git tags
- Path-based routing: `.github/` → CI/CD Infrastructure, `scripts/` → Development Tools, everything else → type-based sections
- Commit link generation
- Footnote link management for version comparisons

**Usage:**

```bash
python scripts/update_changelog.py           # Interactive mode
python scripts/update_changelog.py 0.2.3     # Specific version
```

**Dependencies:** Python 3.9+, Git (stdlib only)

### `test_release_notes.py` — Release Notes Unit Tests

Unit tests for release notes generation logic. Validates conventional commit parsing, changelog section grouping, path-based routing (CI/CD vs Development Tools vs App), and edge cases.

**Usage:**

```bash
python scripts/test_release_notes.py
```

**Dependencies:** Python 3.9+, Git

## CI/CD Validation

### `validate_workflows.py` — GitHub Actions Workflow Validator

Validates and auto-fixes GitHub Actions YAML files. Runs actionlint for schema validation and yamllint for syntax checking.

**Features:**

- Auto-fixes CRLF → LF line endings
- Auto-fixes trailing spaces
- Removes emojis from YAML (causes parsing issues)
- Supports glob patterns: `validate_workflows.py .github/workflows/ci_*.yml`

**Usage:**

```bash
python scripts/validate_workflows.py .github/workflows/*.yml
python scripts/validate_workflows.py --fix .github/workflows/*.yml  # Auto-fix issues
```

**Dependencies:** Python 3.9+, actionlint (optional), yamllint (optional)

### `add_license_headers.py` — Add License Headers

Adds SPDX dual-license headers to all source files missing them.

**Supported file types:** Dart, Kotlin, PowerShell, YAML, Python, Shell

**Usage:**

```bash
python scripts/add_license_headers.py
```

### `check_license_headers.py` — Validate License Headers

Validates all source files have proper license headers. Returns exit code 1 if any files missing headers (CI enforcement).

**Usage:**

```bash
python scripts/check_license_headers.py
```

## Repository Maintenance

### `wipe_github_actions.py` — Clean Workflow Runs

Deletes all workflow runs from repository. Useful for cleaning up test runs.

**Usage:**

```bash
python scripts/wipe_github_actions.py          # Preview (dry-run)
python scripts/wipe_github_actions.py --confirm # Execute deletion
```

**Dependencies:** GitHub CLI (`gh`), Python 3.9+

### `wipe_github_actions_cache.py` — Clean Actions Cache

Deletes all Actions cache entries to free up storage quota.

**Usage:**

```bash
python scripts/wipe_github_actions_cache.py
```

**Dependencies:** GitHub CLI (`gh`), Python 3.9+

## Configuration

### `.env.example.ps1` — Release Keystore Template

Template for Android release signing credentials. Copy to `.env.ps1` and fill in keystore Base64 and credentials.

```powershell
Copy-Item scripts/.env.example.ps1 scripts/.env.ps1
```

**Note:** PowerShell-style syntax is parsed by `run_app.py` for cross-platform compatibility.

## Migration Notes

**Legacy PowerShell scripts removed:**

- `run_debug.ps1` → Replaced by `run_app.py`
- `run_release.ps1` → Replaced by `run_app.py`

All scripts now use Python 3 for environment-agnostic execution across Windows, macOS, and Linux.
