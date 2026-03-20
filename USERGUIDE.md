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

## 3. First-Run Checklist

1. Connect Android device via USB and select MIDI mode.
2. Start OpenMIDIControl.
3. Confirm MIDI in/out ports are visible on host.
4. Map two controls in DAW using MIDI learn.
5. Move each fader and confirm host parameter movement.
6. Move host parameter externally and confirm UI updates.

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

## 5. MIDI Mapping Reference (Initial)

Default proposal for expressive controls:

- Fader A: CC11/CC43 (14-bit pair)
- Fader B: CC1/CC33 (14-bit pair)

Notes:

- 7-bit mode should remain available for compatibility.
- Dedup checks must use reconstructed full value in 14-bit mode.

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

## 7. Cubase Mapping Appendix (initial)
- Purpose: document how core controls map when using Cubase host adapters.
- Default proposal:
  - Fader A: CC11/CC43 (14-bit pair), Channel 1, pickup mode.
  - Fader B: CC1/CC33 (14-bit pair), Channel 1, pickup mode.
- Feedback policy: host automation updates UI when control not touched; full 14-bit value used for dedup.
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

## 9. Design References

- Architecture and event model: [ARCHITECTURE.md](ARCHITECTURE.md)
- Contribution rules: [CONTRIBUTING.md](CONTRIBUTING.md)
- Change history: [CHANGELOG.md](CHANGELOG.md)
- Cubase reference mappings: [references/cubase](references/cubase)

## 10. License

See [LICENSE](LICENSE) for licensing terms.
