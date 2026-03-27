# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
# License Header Checker for OpenMIDIControl
# Run with: .\scripts\check_license_headers.ps1
# Returns exit code 1 if any files are missing headers

$ErrorActionPreference = "Stop"

$RootPath = Split-Path -Parent $PSScriptRoot

Write-Host "`n=== License Header Check ===" -ForegroundColor Cyan
Write-Host "Root: $RootPath" -ForegroundColor Gray

$missingCount = 0
$totalFiles = 0

# Check Dart files
Write-Host "`nChecking Dart files..." -ForegroundColor White
$dartFiles = Get-ChildItem -Path $RootPath -Filter "*.dart" -Recurse | 
             Where-Object { $_.FullName -notmatch "\\build\\|\\.g\.dart$|\.freezed\.dart$|\\.dart_tool\\" }

foreach ($file in $dartFiles) {
    $totalFiles++
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -notmatch "Copyright \(c\) \d{4} Peters Digital" -or 
        $content -notmatch "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [MISS] $($file.FullName)" -ForegroundColor Red
        $missingCount++
    }
}

# Check Kotlin files
Write-Host "`nChecking Kotlin files..." -ForegroundColor White
$kotlinFiles = Get-ChildItem -Path $RootPath -Filter "*.kt" -Recurse |
               Where-Object { $_.FullName -notmatch "\\build\\" }

foreach ($file in $kotlinFiles) {
    $totalFiles++
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -notmatch "Copyright \(c\) \d{4} Peters Digital" -or 
        $content -notmatch "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [MISS] $($file.FullName)" -ForegroundColor Red
        $missingCount++
    }
}

# Check PowerShell scripts
Write-Host "`nChecking PowerShell scripts..." -ForegroundColor White
$psFiles = Get-ChildItem -Path $RootPath -Filter "*.ps1" -Recurse | 
           Where-Object { $_.FullName -notmatch "\\build\\|node_modules\\|vendor\\" }

foreach ($file in $psFiles) {
    $totalFiles++
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -notmatch "Copyright \(c\) \d{4} Peters Digital" -or 
        $content -notmatch "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [MISS] $($file.FullName)" -ForegroundColor Red
        $missingCount++
    }
}

# Check YAML files (workflows and actions)
Write-Host "`nChecking YAML files (workflows/actions)..." -ForegroundColor White
$yamlFiles = Get-ChildItem -Path $RootPath -Filter "*.yml" -Recurse | 
             Where-Object { $_.FullName -match "\\.github\\workflows\\|\\.github\\actions\\" }

foreach ($file in $yamlFiles) {
    $totalFiles++
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -notmatch "Copyright \(c\) \d{4} Peters Digital" -or 
        $content -notmatch "SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial") {
        Write-Host "  [MISS] $($file.FullName)" -ForegroundColor Red
        $missingCount++
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total files checked: $totalFiles" -ForegroundColor Gray
Write-Host "Missing headers: $missingCount" -ForegroundColor $(if ($missingCount -gt 0) { "Red" } else { "Green" })

if ($missingCount -gt 0) {
    Write-Host "`nRun '.\scripts\add_all_license_headers.ps1' to add missing headers." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`nAll files have proper license headers!" -ForegroundColor Green
    exit 0
}
