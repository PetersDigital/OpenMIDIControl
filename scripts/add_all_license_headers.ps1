# Comprehensive License Header Adder for OpenMIDIControl
# Run with: .\scripts\add_all_license_headers.ps1
# Adds headers to all source files, scripts, and configuration files

$ErrorActionPreference = "Stop"

# Header templates for different file types
$DART_HEADER = @"
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"@

$KOTLIN_HEADER = @"
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"@

$POWERSHELL_HEADER = @"
# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"@

$YAML_HEADER = @"
# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"@

$SHELL_HEADER = @"
# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"@

$RootPath = Split-Path -Parent $PSScriptRoot

Write-Host "`n=== Adding License Headers (Comprehensive) ===" -ForegroundColor Cyan
Write-Host "Root: $RootPath" -ForegroundColor Gray

$modifiedCount = 0

# Process PowerShell scripts
Write-Host "`nProcessing PowerShell scripts..." -ForegroundColor White
$psFiles = Get-ChildItem -Path $RootPath -Filter "*.ps1" -Recurse | 
           Where-Object { $_.FullName -notmatch "\\build\\|node_modules\\|vendor\\" }

foreach ($file in $psFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # Skip if already has header
    if ($content -match "Copyright \(c\) \d{4} Peters Digital" -and 
        $content -match "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [SKIP] $($file.Name)" -ForegroundColor Yellow
        continue
    }
    
    # Check for shebang
    $lines = $content -split "`r?`n"
    $newContent = ""
    
    if ($lines.Count -gt 0 -and $lines[0].StartsWith("#!")) {
        # Keep shebang first, then add header
        $newContent = $lines[0] + "`n" + $POWERSHELL_HEADER
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $newContent += $lines[$i] + "`n"
        }
    } else {
        $newContent = $POWERSHELL_HEADER + $content
    }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
    Write-Host "  [ADD] $($file.FullName)" -ForegroundColor Green
    $modifiedCount++
}

# Process YAML files (only non-trivial ones - workflows, actions)
Write-Host "`nProcessing YAML files (workflows/actions)..." -ForegroundColor White
$yamlFiles = Get-ChildItem -Path $RootPath -Filter "*.yml" -Recurse | 
             Where-Object { $_.FullName -match "\\.github\\workflows\\|\\.github\\actions\\" }

foreach ($file in $yamlFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # Skip if already has header
    if ($content -match "Copyright \(c\) \d{4} Peters Digital" -and 
        $content -match "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [SKIP] $($file.Name)" -ForegroundColor Yellow
        continue
    }
    
    # Add header
    $newContent = $YAML_HEADER + $content
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
    Write-Host "  [ADD] $($file.FullName)" -ForegroundColor Green
    $modifiedCount++
}

Write-Host "`n=== Complete ===" -ForegroundColor Cyan
Write-Host "Total headers added: $modifiedCount" -ForegroundColor Green
Write-Host "`nNote: pubspec.yaml and analysis_options.yaml excluded (simple config files)" -ForegroundColor Gray
