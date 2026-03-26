# OpenMIDIControl Scripts

This folder contains organizational and build-assistance scripts to standardize testing and release workflows across contributors. These scripts provide an interactive device-selection layer (via `flutter devices --machine`) to ensure the app targets the correct hardware during high-frequency MIDI testing.

## Key Features

### 🚀 Project-Agnostic Discovery
Both scripts automatically locate the Flutter project by searching for a `pubspec.yaml` file in the project root or its immediate subdirectories (e.g., `app/`, `appname/`). You can run these scripts from the repository root without worrying about the internal folder structure.

### 📱 Interactive Target Selection
The scripts hook into the `flutter devices` daemon to parse your connected hardware and virtual targets. They present an interactive, numbered list of all available simulators, physical devices, and web endpoints, allowing you to select a target with a single keystroke.

---

## Local Debug Testing (`run_debug.ps1`)

For regular development and debugging with hot reload, use `run_debug.ps1`. This script provides a streamlined way to launch the app without manual device ID management.

### Launch the Script
Open a PowerShell terminal from the project root and run:
```powershell
.\scripts\run_debug.ps1
```

> Requires PowerShell 7+ (the scripts use `Get-ChildItem -Depth` and other modern cmdlets).

**The script will:**
1. Dynamically find the Flutter project directory.
2. List all available targets.
3. Automatically execute `flutter run` on your chosen device.

---

## Local Release Testing (`run_release.ps1`)

To test application performance and thermal load, it is critically important to run the app in **Release Mode**. `Profile` mode retains telemetry websockets that obfuscate device load and UI jitter.

Because OpenMIDIControl's Android component requires a securely signed release configuration, you must configure local secrets to run this script:

### 1. Configure the `.env.ps1` file
1. Create a local copy of the environment template:
   PowerShell 7:
   ```powershell
   Copy-Item -Path scripts/.env.example.ps1 -Destination scripts/.env.ps1
   ```
   Unix/macOS/Linux:
   ```bash
   cp scripts/.env.example.ps1 scripts/.env.ps1
   ```
2. Open `scripts/.env.ps1` and add the `upload-keystore.jks` Base64 string and credentials provided by the repository maintainer.
*(Note: `.env.ps1` is ignored by Git and will never be tracked).*

### 2. Launch the Script
Open a PowerShell terminal from the project root and run:
```powershell
.\scripts\run_release.ps1
```

**The script will automatically:**
1. Dynamically decode and write the exact physical `upload-keystore.jks` file where Gradle looks for it.
2. Draft the `.properties` credential file.
3. Hook into the `flutter devices` daemon to parse your connected hardware targets.
4. Present an interactive numbered list of your connected simulators and physical endpoints.
5. Safely execute `flutter run --release` on your chosen target and clean up.

## Local Debug Testing (`run_debug.ps1`)

For active development and debugging (with hot reload and verbose Kotlin logging), use the debug launcher. This script skips the keystore/signing steps but retains the interactive device picker.

```powershell
.\scripts\run_debug.ps1
```

**Features:**
1. **Interactive Device Picker**: Parses connected Android/Windows targets.
2. **Auto-CWD Management**: Consistently targets the `app/` directory from the root.
3. **Verbose Logs**: Ensures `android.util.Log` output is visible in the console.
