# License Header Enforcement

This document describes the license header enforcement system for OpenMIDIControl.

## Dual License

This project uses a dual-licensing model:

1. **GNU General Public License v3.0 (GPLv3)** - Open source license
2. **Commercial License (LicenseRef-Commercial)** - Proprietary license

All source files must include the following SPDX identifier:

```
SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
```

## License Header Format

### Dart Files

```dart
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
// ... rest of code
```

### Kotlin Files

```kotlin
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol
// ... rest of code
```

## CI/CD Enforcement

A GitHub Actions workflow (`.github/workflows/validate_auto_license.yml`) runs on:
- Push to `main` or `develop` branches
- All pull requests targeting `main`

The workflow:
1. Checks out the code
2. Runs `check_license_headers.sh` on Ubuntu (faster, cost-effective)
3. Fails the build if any files are missing headers

## Manual Verification

To manually verify license headers:

### PowerShell (Windows)

```powershell
# Check for SPDX identifier
Get-ChildItem -Recurse -Include *.dart,*.kt,*.ps1,*.yml |
  Select-String -Pattern "SPDX-License-Identifier" |
  Measure-Object

# Check for Peters Digital copyright
Get-ChildItem -Recurse -Include *.dart,*.kt,*.ps1,*.yml |
  Select-String -Pattern "Copyright.*Peters Digital" |
  Measure-Object
```

### Unix/Linux/macOS (Bash)

```bash
# Check for SPDX identifier
grep -R "SPDX-License-Identifier" \
  --include="*.dart" \
  --include="*.kt" \
  --include="*.ps1" \
  --include="*.yml" .

# Check for Peters Digital copyright
grep -R "Copyright.*Peters Digital" \
  --include="*.dart" \
  --include="*.kt" \
  --include="*.ps1" \
  --include="*.yml" .
```

## File Coverage

The license header system covers:

### Dart Source Files
- `app/lib/**/*.dart` - Application source code
- `app/test/**/*.dart` - Test files

### Kotlin Source Files
- `app/android/app/src/main/kotlin/**/*.kt` - Native Android layer
- `app/android/app/src/test/kotlin/**/*.kt` - Native tests

### PowerShell Scripts
- `scripts/**/*.ps1` - Build and deployment scripts

### YAML Configuration Files
- `.github/workflows/*.yml` - GitHub Actions workflows
- `.github/actions/**/*.yml` - Reusable GitHub Actions

### Excluded Files
- Generated files (`.g.dart`, `.freezed.dart`)
- Build output directories (`build/`)
- Dart tool directories (`.dart_tool/`)
- Simple config files (`pubspec.yaml`, `analysis_options.yaml`)
- Legal documents (`LICENSE`, `LICENSE-COMMERCIAL`, `NOTICE`, `COPYRIGHT`)
- Third-party configs (`.gemini/config.yaml`)
- Third-party or vendor directories (`node_modules/`, `vendor/`)

## Legal Compliance

### For Open Source Users (GPLv3)

If you use, modify, or distribute this software under GPLv3:
- You must maintain all copyright notices
- You must include the SPDX identifier in any derivative works
- You must distribute under GPLv3 terms

### For Commercial Licensees

If you have a commercial license:
- The `LicenseRef-Commercial` identifier applies
- Terms are defined in your signed agreement
- Contact: dencelbabu@gmail.com

## Enforcement Rationale

License headers serve several critical purposes:

1. **Legal Notice**: Clearly communicates ownership and licensing terms
2. **Copy Protection**: Ensures license travels with code if copied
3. **SPDX Compliance**: Standard identifier for automated license scanning
4. **Dual-License Clarity**: Explicitly states both licensing options

## Maintenance

### Adding New Source Files

Always ensure new source files include the license header. The CI check will catch missing headers, but it's best to add them immediately.

## Troubleshooting

### Headers Not Detected

If the check script reports missing headers when they exist:
- Verify the SPDX identifier matches exactly
- Check for encoding issues (should be UTF-8 without BOM)
- Ensure no extra characters before the header

### Headers Added in Wrong Location

If headers appear after package/import statements:
- This is a script bug - report it
- Manually move the header to the top of the file
- The header must be the very first content (after shebang if present)

## References

- [SPDX License List](https://spdx.org/licenses/)
- [GPLv3 License](https://www.gnu.org/licenses/gpl-3.0.html)
- [REUSE Specification](https://reuse.software/)
