#!/bin/bash
# License Header Checker for OpenMIDIControl (Linux/macOS)
# Run with: ./scripts/check_license_headers.sh
# Returns exit code 1 if any files are missing headers

set -e

echo ""
echo "=== License Header Check ==="
echo "Root: $(pwd)"
echo ""

MISSING_COUNT=0
TOTAL_FILES=0

# Check Dart files
echo "Checking Dart files..."
while IFS= read -r -d '' file; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    if ! grep -q "Copyright (c) [0-9]\{4\} Peters Digital" "$file" || \
       ! grep -q "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial" "$file"; then
        echo "  [MISS] $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done < <(find . -name "*.dart" \
    -not -path "*/build/*" \
    -not -path "*/.dart_tool/*" \
    -not -name "*.g.dart" \
    -not -name "*.freezed.dart" \
    -print0)

# Check Kotlin files
echo "Checking Kotlin files..."
while IFS= read -r -d '' file; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    if ! grep -q "Copyright (c) [0-9]\{4\} Peters Digital" "$file" || \
       ! grep -q "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial" "$file"; then
        echo "  [MISS] $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done < <(find . -name "*.kt" \
    -not -path "*/build/*" \
    -print0)

# Check PowerShell scripts
echo "Checking PowerShell scripts..."
while IFS= read -r -d '' file; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    if ! grep -q "Copyright (c) [0-9]\{4\} Peters Digital" "$file" || \
       ! grep -q "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial" "$file"; then
        echo "  [MISS] $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done < <(find . -name "*.ps1" \
    -not -path "*/build/*" \
    -print0)

# Check YAML files (workflows and actions)
echo "Checking YAML files (workflows/actions)..."
while IFS= read -r -d '' file; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    if ! grep -q "Copyright (c) [0-9]\{4\} Peters Digital" "$file" || \
       ! grep -q "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial" "$file"; then
        echo "  [MISS] $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done < <(find . -path "*/.github/workflows/*.yml" -o -path "*/.github/actions/**/*.yml" -print0)

echo ""
echo "=== Summary ==="
echo "Total files checked: $TOTAL_FILES"
echo "Missing headers: $MISSING_COUNT"

if [ $MISSING_COUNT -gt 0 ]; then
    echo ""
    echo "Run './scripts/add_all_license_headers.ps1' to add missing headers."
    exit 1
else
    echo ""
    echo "All files have proper license headers!"
    exit 0
fi
