$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

# Find the Flutter project directory (agnostic to "app", "appname", or root)
$flutterProjectDir = Get-ChildItem -Path $projectRoot -Filter "pubspec.yaml" -File -Recurse -Depth 1 | Select-Object -First 1 | ForEach-Object { $_.Directory.FullName }

if (-not $flutterProjectDir) {
    Write-Host "❌ Could not find a Flutter project (pubspec.yaml) in $projectRoot or its immediate subdirectories." -ForegroundColor Red
    exit 1
}

Write-Host "Fetching available Flutter devices..." -ForegroundColor Cyan
Push-Location $flutterProjectDir
$devicesString = flutter devices --machine | Out-String
$devicesJson = $devicesString | ConvertFrom-Json

if ($devicesJson -isnot [array]) {
    $devicesJson = @($devicesJson)
}

if (-not $devicesJson -or $devicesJson.Count -eq 0) {
    Write-Host "No Flutter devices found! Make sure a physical device is connected via USB/Wireless ADB." -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "`nAvailable devices:" -ForegroundColor Yellow
for ($i = 0; $i -lt $devicesJson.Count; $i++) {
    $dev = $devicesJson[$i]
    Write-Host "  [$i] $($dev.name) ($($dev.targetPlatform))"
}

$selection = Read-Host "`nSelect a device [0-$($devicesJson.Count - 1)]"
try {
    $selectedIndex = [int]$selection
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $devicesJson.Count) {
        throw "Out of bounds"
    }
} catch {
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    Pop-Location
    exit 1
}

$selectedDeviceId = $devicesJson[$selectedIndex].id
Write-Host "`n🚀 Launching OpenMIDIControl on $selectedDeviceId in DEBUG mode..." -ForegroundColor Green

try {
    flutter run -d $selectedDeviceId
} finally {
    Pop-Location # Pop out of flutterProjectDir
}
