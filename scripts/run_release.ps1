$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$secretsFile = Join-Path $PSScriptRoot ".env.ps1"

if (-not (Test-Path $secretsFile)) {
    Write-Host "❌ Secrets file not found at scripts/.env.ps1" -ForegroundColor Red
    Write-Host "Please copy scripts/.env.example.ps1 to scripts/.env.ps1 and add your keystore secrets before running." -ForegroundColor Yellow
    exit 1
}

# Load secrets securely into the environment context
. $secretsFile

if (-not $env:KEYSTORE_BASE64) {
    Write-Host "❌ Environment variables were not properly loaded. Check .env.ps1." -ForegroundColor Red
    exit 1
}

$keystorePath = Join-Path $projectRoot "app\android\app\upload-keystore.jks"
$propertiesPath = Join-Path $projectRoot "app\android\key.properties"

# Decode base64 to create the JKS file locally
try {
    $Bytes = [Convert]::FromBase64String($env:KEYSTORE_BASE64)
    [IO.File]::WriteAllBytes($keystorePath, $Bytes)
} catch {
    Write-Host "❌ Failed to decode KEYSTORE_BASE64. Make sure it is a valid Base64 string from GitHub Secrets." -ForegroundColor Red
    exit 1
}

# Write key.properties for Gradle
$PropertiesContent = @"
storePassword=$env:STORE_PASSWORD
keyPassword=$env:KEY_PASSWORD
keyAlias=$env:KEY_ALIAS
storeFile=upload-keystore.jks
"@

[IO.File]::WriteAllText($propertiesPath, $PropertiesContent)

Write-Host "✅ Local release keystore and key.properties configured!" -ForegroundColor Green

Write-Host "Fetching available Flutter devices..." -ForegroundColor Cyan
Push-Location $projectRoot
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
Write-Host "`n🚀 Launching OpenMIDIControl on $selectedDeviceId in RELEASE mode..." -ForegroundColor Green

Push-Location app
try {
    flutter run --release -d $selectedDeviceId
} finally {
    Pop-Location # Pop out of app
    Pop-Location # Pop out of root
}
