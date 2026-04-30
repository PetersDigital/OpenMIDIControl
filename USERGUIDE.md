# OpenMIDIControl User Guide

This guide describes how to use and validate the current implementation.

## 1. Scope

The first iteration focuses on a reliable, low-latency, touch-to-MIDI control path.

Expected baseline:

- Two expressive faders
- Multi-touch input
- MIDI output
- MIDI feedback into UI
- Loop-resistant behavior under echoing hosts

## 2. Environment Requirements

- Android device with USB MIDI support
- USB data cable (not charge-only)
- Host computer and DAW with MIDI learn

## 3. First-Run Checklist (USB Peripheral Mode)

1. Connect Android device to Windows 11 PC via USB-C.
2. Ensure Android USB mode is set to **"MIDI"** or **"File Transfer"** (Device will automatically handshake as a Peripheral).
3. Start OpenMIDIControl.
4. Confirm **"USB PERIPHERAL READY"** (Orange/Yellow) or **"USB HOST CONNECTED"** (Green) banner appears in the status row.
   - **READY**: The phone is in MIDI mode and visible to the PC, but no traffic has been detected yet.
   - **CONNECTED**: The DAW is actively communicating with the app.
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
- The version + build metadata at the top helps confirm you are on the `v0.3.0` UI, and this screen will later house pick-up, smoothing, and transport preferences.
- **Manual Port Selection:** Toggle this on to forcefully show internal Android ports (including physical Port 0) in the device list. Use this only for advanced debugging of routing collisions.
- Long-press any fader label to open the CC picker: the same overlay is used on both mobile and desktop layouts so you can reassign each fader without leaving the performance view.
- **Snapshots & Presets:** From the settings drawer, access the snapshot tools to save your current layout configurations and control assignments into distinct preset slots, allowing rapid recall during live performance.

### 4.5 Configuring MIDI Ports

1. Open **Settings > MIDI Ports Configuration** (or tap the **status badge** in the top bar).
2. Expand your device tile (e.g., Arturia Minilab3).
3. **Select Ports:** Standard CC users should select **Port 0** for both Input and Output.
4. **Active State:** When a port is successfully engaged, the entire port row will be **highlighted in Blue/Green**.
5. **Persistence:** If you unplug your device, the app will remember your port selection and automatically reconnect as soon as you plug it back in.

## 5. MIDI Mapping Reference (Initial)

### Current Implementation (MIDI 1.0 / 14-bit)

- Fader A: CC11/CC43 (14-bit LSB/MSB pair)
- Fader B: CC1/CC33 (14-bit LSB/MSB pair)

### Future Proposal (Native MIDI 2.0)

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

### Current Mappings (v0.3.0)

- Fader A: CC11/CC43 (14-bit pair), Channel 1.
- Fader B: CC1/CC33 (14-bit pair), Channel 1.
- Feedback policy: host automation updates UI when control not touched; full 14-bit value used for dedup via reconstructed UMP.

### Target Architecture (v0.3.0+)

- Native UMP High-Res CC without legacy byte-stitching. The DAG router strictly works with 32-bit messages, meaning it expects full resolution natively.
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

## 10. License

See [LICENSE](LICENSE) for licensing terms.
