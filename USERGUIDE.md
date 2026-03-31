# OpenMIDIControl User Guide

This guide describes how to use and validate the current implementation.

**Current Version**: v0.2.2 – Hybrid UMP Implementation with manual 32-bit reconstruction, automated test suite, and defensive bounds checking.

## 1. Scope

The first iteration focuses on a reliable, low-latency, touch-to-MIDI control path.

Expected baseline:

- Two expressive faders
- Multi-touch input
- MIDI output (UMP-enabled via hybrid implementation)
- MIDI feedback into UI
- Loop-resistant behavior under echoing hosts
- Real-time diagnostics console with native timestamps

## 2. Environment Requirements

- Android device with USB MIDI support
- USB data cable (not charge-only)
- Host computer and DAW with MIDI learn

## 3. First-Run Checklist (USB Peripheral Mode)

1. Connect Android device to Windows 11 PC via USB-C.
2. Ensure Android USB mode is set to **"MIDI"** or **"File Transfer"** (Device will automatically handshake as a Peripheral).
3. Start OpenMIDIControl.
4. Confirm **"USB PERIPHERAL MODE ACTIVE"** green banner appears in the status row.
5. In your DAW (Cubase/Ableton), select **"OpenMIDIControl"** as the MIDI Input/Output device.
6. Move a fader and confirm MIDI data is received.

## 4. Operating Behavior

### 4.1 Touch ownership

- While touching a control, local touch input has priority.
- Incoming MIDI for the touched control is deferred/ignored.
- When touch ends, external-follow mode resumes.

### 4.2 Feedback behavior

- UI follows host feedback when control is not touched.
- Duplicate echo values are suppressed through dedup caches.

### 4.3 Output behavior

- Outbound events are rate-limited per control.
- Rapid motion is coalesced with last-value-wins semantics.
- Final value is always emitted on release.

### 4.4 Behavior & layout settings

- Tap the **kebab icon** in the top bars of any layout to open the `Settings` screen.
- The screen exposes three fader-behavior modes (Jump, Hybrid, Catch-Up) that immediately affect whether the fader snaps to your finger, moves relatively, or waits to cross the ribbon before updating host values.
- A layout toggle lets you switch which side of the command center the faders sit on so you can mirror the UI for your dominant hand.
- The version + build metadata at the top helps confirm you are on the `v0.2.1` UI, and this screen will later house pick-up, smoothing, and transport preferences.
- **Manual Port Selection:** Toggle this on to forcefully show internal Android ports (including physical Port 0) in the device list. Use this only for advanced debugging of routing collisions.
- Long-press any fader label to open the CC picker: the same overlay is used on both mobile and desktop layouts so you can reassign each fader without leaving the performance view.

### 4.5 Configuring MIDI Ports

1. Open **Settings > MIDI Ports Configuration** (or tap the **status badge** in the top bar).
2. Expand your device tile (e.g., Arturia Minilab3).
3. **Select Ports:** Standard CC users should select **Port 0** for both Input and Output.
4. **Active State:** When a port is successfully engaged, the entire port row will be **highlighted in Blue/Green**.
5. **Persistence:** If you unplug your device, the app will remember your port selection and automatically reconnect as soon as you plug it back in.

## 5. MIDI Mapping Reference (Initial)

### Current Implementation (MIDI 1.0 / 14-bit):
- Fader A: CC11/CC43 (14-bit LSB/MSB pair)
- Fader B: CC1/CC33 (14-bit LSB/MSB pair)

### Future Proposal (Native MIDI 2.0):
- Native 32-bit UMP CC values (v0.2.2+)

Notes:

- 7-bit mode remains available for legacy compatibility.
- Dedup checks use reconstructed 14-bit values (Current) or native 32-bit UMP (v0.2.2+).

## 6. Validation Tests

### 6.1 Multi-touch test

1. Touch and move both faders simultaneously.
2. Verify independent movement and independent MIDI streams.
3. Verify no pointer stealing between controls.

### 6.2 Echo-loop test

1. Enable host MIDI echo/feedback.
2. Move faders quickly and repeatedly.
3. Verify no oscillation, jitter storms, or frozen UI.

### 6.3 Long-session stability test

1. Run continuous interaction for at least 20 minutes.
2. Verify consistent responsiveness (latency <10 ms median, <20 ms p95).
3. Observe battery/thermal behavior for abnormal spikes; device surface temp stays within OEM comfort range.

### 6.4 Reconnect test

1. Unplug USB during active use.
2. Reconnect USB.
3. Verify automatic recovery without restarting the app.

### 6.5 Rate-limit verification
1. Sweep a fader rapidly for 5 seconds.
2. Confirm outbound MIDI rate caps at the configured limit (target 60–120 Hz per control) and still emits final value on release.

## 7. Cubase Mapping Appendix (Initial)
- Purpose: document how core controls map when using Cubase host adapters.
### Current Mappings (v0.2.1):
- Fader A: CC11/CC43 (14-bit pair), Channel 1, pickup mode.
- Fader B: CC1/CC33 (14-bit pair), Channel 1, pickup mode.
- Feedback policy: host automation updates UI when control not touched; full 14-bit value used for dedup.

### Target Architecture (v0.2.2+):
- Native UMP High-Res CC without legacy byte-stitching.
- See reference scripts and mappings under [references/cubase](references/cubase) for vendor-specific examples.

## 8. Troubleshooting

### Device not visible on host

- Confirm cable supports data.
- Confirm Android USB mode is MIDI.
- Reconnect cable and restart app if needed.

### Host responds but UI does not follow

- Confirm MIDI input is enabled for feedback path.
- Confirm control/channel mapping is correct.
- Check whether control is currently in touch ownership state.

### Jitter or looping behavior

- Verify dedup cache is keyed by full control value.
- Verify suppression window is enabled.
- Verify outbound event cap and coalescing are active.

## 9. Debugging & Testing (v0.2.0+)

### 9.1 Diagnostics Console (NEW)
Open the **MIDI Connection Settings** screen and tap the **bug icon** (labeled with a "View Diagnostics" tooltip) in the top bar. This reveals a real-time, terminal-style MIDI event logger directly on the device.
- **Auto-Dispose**: The logging subscription is automatically terminated when you close the modal to preserve CPU cycles.
- **Parsed Events**: View incoming `MidiEvent` data, including high-precision native timestamps, CC numbers, and values.

### 9.2 Native Logging (ADB)
To monitor the internal MIDI dispatcher and USB handshake events, use `adb`:
```powershell
# Windows PowerShell
adb -s <devicename> logcat -c; adb -s <devicename> logcat | Select-String "OpenMIDIControl|flutter"
```

### 9.2 Sending Test MIDI
Use the [Windows MIDI Services](https://microsoft.github.io/MIDI/tools/) CLI to send test messages to the app:
```bash
# Send CC 1 Value 33 to Channel 1
midi endpoint send-message 0x20B00121
```

## 10. Design References
- Architecture and event model: [ARCHITECTURE.md](ARCHITECTURE.md)
- Contribution rules: [CONTRIBUTING.md](CONTRIBUTING.md)
- Change history: [CHANGELOG.md](CHANGELOG.md)
- Cubase reference mappings: [references/cubase](references/cubase)

## 11. CI/CD & Release Information

This section provides information about OpenMIDIControl's automated build, test, and release system. It is intended for **end users**, **testers**, and **stakeholders** who want to understand release types and how to verify downloads.

### For End Users

#### Release Types

OpenMIDIControl publishes four types of releases. Understanding the differences helps you choose the right version for your needs.

| Release Type | Stability | Audience | Tag Format | Where to Find |
|--------------|-----------|----------|------------|---------------|
| **Beta** | 🟡 Unstable | Internal testers, developers | `v0.2.2-beta.45` | GitHub Releases (draft) |
| **RC** (Release Candidate) | 🟢 Stable (feature complete) | Public testers, early adopters | `v0.2.2-rc.1` | GitHub Releases (pre-release) |
| **Stable** | ✅ Production-ready | All users | `v0.2.2` | GitHub Releases (public) |
| **Hotfix** | ✅ Production-ready (urgent) | Users affected by critical bug | `v0.2.2-patch.1` | GitHub Releases (public) |

#### Understanding Release Tags

**Beta Releases (`v0.2.2-beta.45`):**
- **What it means:** 45th beta build in the v0.2.2 development cycle
- **Frequency:** Multiple per week (auto-generated from beta branch)
- **Use case:** Testing in-progress features, providing early feedback
- **Warning:** May contain bugs, incomplete features, or breaking changes
- **Where:** GitHub Releases (may be in draft state, not publicly visible)

**RC Releases (`v0.2.2-rc.1`):**
- **What it means:** First release candidate for v0.2.2 (feature complete)
- **Frequency:** 1-3 per release cycle (manual tags)
- **Use case:** Final validation before stable release
- **Warning:** Feature complete, but may have undiscovered bugs
- **Where:** GitHub Releases (public, marked as "pre-release")

**Stable Releases (`v0.2.2`):**
- **What it means:** Production-ready version 0.2.2
- **Frequency:** Monthly or when major features are complete
- **Use case:** Daily use, production environments
- **Warning:** None — this is the recommended version for all users
- **Where:** GitHub Releases (public, latest release)

**Hotfix Releases (`v0.2.2-patch.1`):**
- **What it means:** First urgent fix for v0.2.2
- **Frequency:** As needed (critical bugs only)
- **Use case:** Fixing critical issues without waiting for next stable
- **Warning:** Minimal testing — urgent fixes only
- **Where:** GitHub Releases (public)

#### Where to Find Releases

All releases are published on the **GitHub Releases page**:
- **URL:** `https://github.com/PetersDigital/OpenMIDIControl/releases`
- **Latest stable:** Look for the top release without "pre-release" badge
- **RC releases:** Look for "pre-release" badge
- **Beta releases:** May be in draft state (not visible to public)
- **Hotfix releases:** Listed chronologically with stable releases

**Download Assets:**
Each release includes:
- `app-release.apk` — Android APK (for all devices)
- `openmidicontrol-windows.zip` — Windows build (if applicable)
- `checksums.txt` — SHA256 hashes for verification
- `provenance.json` — SLSA provenance attestation

### For Testers & Stakeholders

#### Beta Releases: Internal Testing

**Purpose:** Validate in-progress features before public release.

**Who should test:**
- Core development team
- Trusted beta testers
- Contributors who submitted features in the beta cycle

**How to access:**
1. Go to GitHub Releases page
2. Look for draft releases (may require invitation)
3. Download APK and install on test device
4. Report issues via:
   - **Telegram:** [OpenMIDIControl Community](https://t.me/openmidicontrol)
   - **GitHub Issues:** Use "Bug Report" template

**Feedback expectations:**
- Test specific features mentioned in release notes
- Report crashes, regressions, or unexpected behavior
- Provide device model, Android version, and DAW setup
- Include logs if possible (`adb logcat`)

#### RC Releases: Public Testing

**Purpose:** Final validation before stable release.

**Who should test:**
- All users interested in new features
- Power users with complex setups
- Hardware-in-the-loop (HITL) testers

**How to access:**
1. Go to GitHub Releases page
2. Find release with "pre-release" badge
3. Download APK and install
4. Focus testing on:
   - **Regression testing:** Ensure existing features still work
   - **Edge cases:** Unusual MIDI setups, long sessions
   - **Performance:** Latency, thermal stability, battery drain

**Feedback channels:**
- **Telegram:** Quick feedback, community discussion
- **GitHub Issues:** Formal bug reports, feature requests
- **Direct contact:** @dencelkbabu for urgent issues

**RC Timeline:**
```
RC.1 → (bug fixes) → RC.2 → (final validation) → Stable Release
  ↑                    ↑                          ↑
  Public testing       Final fixes                Production
```

If no critical issues are found in RC.2, it becomes the stable release.

#### How to Provide Feedback

**Bug Reports (GitHub Issues):**
1. Use the "Bug Report" template
2. Include:
   - **Release version:** e.g., `v0.2.2-rc.1`
   - **Device:** Android model + version
   - **DAW:** Cubase/Ableton/other
   - **Steps to reproduce:** Clear, numbered steps
   - **Expected behavior:** What should happen
   - **Actual behavior:** What actually happened
   - **Logs:** `adb logcat` output (if applicable)

**Feature Feedback (Telegram):**
- Join: https://t.me/openmidicontrol
- Share: Screenshots, videos, MIDI traces
- Discuss: Usability, workflow improvements
- Vote: React to messages to prioritize issues

### Build Metadata & Verification

OpenMIDIControl uses **SLSA (Supply-chain Levels for Software Artifacts)** compliance to ensure build integrity.

#### Provenance Attestation (SLSA)

**What it is:** Cryptographic proof of how, when, and by whom a build was created.

**What it includes:**
- Build timestamp
- GitHub Actions runner ID
- Source commit SHA
- Build commands executed
- Dependency versions

**How to verify:**
1. Download `provenance.json` from release assets
2. Use GitHub's verification tool:
   ```bash
   gh attestation verify <artifact> --owner PetersDigital
   ```
3. Or use `cosign` directly:
   ```bash
   cosign verify-blob <artifact> \
     --signature <artifact>.sig \
     --certificate <artifact>.crt
   ```

**What to look for:**
- ✅ `buildType`: "github-workflow"
- ✅ `builder.id`: GitHub Actions runner
- ✅ `materials[0].digest.sha256`: Matches your download
- ✅ `invocation.configSource.uri`: Points to `.github/workflows/` in this repo

#### Cosign Signatures (OIDC)

**What it is:** Keyless signing using OpenID Connect (OIDC) identity.

**Why keyless:** No long-lived signing keys to manage or leak.

**How it works:**
1. GitHub Actions requests OIDC token from GitHub
2. Token proves identity: `https://github.com/PetersDigital/OpenMIDIControl/.github/workflows/cd_prod_auto.yml@refs/heads/main`
3. Cosign signs artifact with short-lived key
4. Signature is tied to GitHub identity, not a static key

**How to verify:**
```bash
cosign verify-blob app-release.apk \
  --signature app-release.apk.sig \
  --certificate app-release.apk.crt \
  --certificate-identity-regexp "https://github.com/PetersDigital/OpenMIDIControl" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

**Expected output:**
```
Verified OK
```

#### Checksum Verification

**Quick verification (SHA256):**
```bash
# Windows PowerShell
Get-FileHash app-release.apk -Algorithm SHA256

# Compare with checksums.txt
```

**Expected:** Hash matches the value in `checksums.txt`

#### Full Verification Workflow

For maximum security:

```bash
# 1. Download all assets
gh release download v0.2.2 --pattern "*.apk" --pattern "*.sig" --pattern "*.crt" --pattern "provenance.json"

# 2. Verify checksum
sha256sum app-release.apk | diff - checksums.txt

# 3. Verify signature
cosign verify-blob app-release.apk \
  --signature app-release.apk.sig \
  --certificate app-release.apk.crt \
  --certificate-identity-regexp "https://github.com/PetersDigital/OpenMIDIControl" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"

# 4. Verify provenance
gh attestation verify app-release.apk --owner PetersDigital
```

**If all checks pass:** ✅ The APK is authentic and untampered.

### Release Notification Channels

Stay informed about new releases:

| Channel | Type | Frequency | Audience |
|---------|------|-----------|----------|
| **Telegram** | Instant | Every release | All users |
| **GitHub Releases** | RSS/Feed | Every release | Developers |
| **GitHub Watch** | Email | Every release | Contributors |
| **Twitter/X** | Announcements | Major releases | Community |

**Recommended setup:**
- **End users:** Watch GitHub Releases (latest only)
- **Testers:** Join Telegram for beta/RC notifications
- **Contributors:** Watch all activity + Telegram

### Release Cadence

**Typical release cycle:**
```
Week 1-2: Beta builds (v0.2.2-beta.1 to beta.45)
  ↓
Week 3:   RC builds (v0.2.2-rc.1, rc.2)
  ↓
Week 4:   Stable release (v0.2.2)
```

**Hotfix releases:** As needed (typically within 48 hours of critical bug report)

**Major releases:** Quarterly (v0.3.0, v0.4.0)

**Minor releases:** Monthly (v0.2.1, v0.2.2, v0.2.3)

### Troubleshooting Downloads

**Issue:** "App not installed" on Android
- **Solution:** Enable "Install from Unknown Sources" in Settings
- **Alternative:** Use ADB: `adb install app-release.apk`

**Issue:** Checksum mismatch
- **Solution:** Re-download — file may be corrupted
- **Warning:** If mismatch persists, report immediately (security concern)

**Issue:** Signature verification fails
- **Solution:** Ensure you downloaded from official GitHub Releases
- **Warning:** Do not install APKs from unofficial sources

**Issue:** Provenance verification fails
- **Solution:** Check GitHub CLI version (`gh --version`)
- **Alternative:** Use `cosign` directly (see above)

---

## 10. License

See [LICENSE](LICENSE) for licensing terms.
