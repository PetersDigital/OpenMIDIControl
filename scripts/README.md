# OpenMIDIControl Scripts

This folder contains organizational and build-assistance scripts to standardize testing and release workflows across contributors.

## Local Release Testing (`run_release.ps1`)

To test the application's performance on mobile devices locally, it is critically important to run the app in **Release Mode**. `Profile` mode retains the constant Dart VM telemetry websockets needed for external tooling to connect, which severely obfuscates device thermal load and UI jitter. 

Because OpenMIDIControl's Android component strictly requires a securely signed `release` configuration in `build.gradle` (which pulls from GitHub Secrets in the CI environment), you cannot run `--release` locally out of the box without the keys. To safely test releases locally without tracking secrets in Git, follow these steps:

### 1. Configure the `.env.ps1` file
1. Create a copy of the template `scripts/.env.example.ps1` and name it `.env.ps1`.
   ```bash
   cp scripts/.env.example.ps1 scripts/.env.ps1
   ```
2. Open `scripts/.env.ps1` and paste the `upload-keystore.jks` Base64 string and the three associated key passwords. Ask the repository maintainer for these values.
*(Note: `.env.ps1` is deliberately ignored by the `.gitignore` policy and will never be tracked).*

### 2. Launch the Script
Open a PowerShell terminal from the project root and run the launcher:
```powershell
.\scripts\run_release.ps1
```

**The script will automatically:**
1. Dynamically decode and write the exact physical `upload-keystore.jks` file where Gradle looks for it.
2. Draft the `.properties` credential file.
3. Hook into the `flutter devices` daemon to parse your connected hardware targets.
4. Present an interactive numbered list of your connected simulators and physical endpoints.
5. Safely execute `flutter run --release` on your chosen target and clean up.
