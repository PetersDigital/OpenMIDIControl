# Cubase Reference Mappings

This directory contains vendor-specific Cubase controller scripts and mapping notes. Use them as examples when building optional host adapters without altering the DAW-agnostic core.

## Structure
- `vendor/model/` folders contain script snippets or mapping tables for that device.
- Keep additions isolated; do not change core app behavior or MIDI policies here.

## Contribution guidelines
- **DAW Handshake**: Document any required initialization messages (SysEx or Note/CC) sent in `mOnActivate` to put your "host adapter" in the correct mode.
- **Per-Control Mapping**: Detail CC/Channel/PitchBend usage. Use **Pitch Bend** for 14-bit fader resolution when UMP is not yet active.
- **Relative Controls**: Specify if encoders use `RelativeSignedBit` or other modes.
- **Feedback & LEDs**: Document color palettes and any custom SysEx used for displays or RGB pads.
- **Automation Hierarchy**: Group controls into `SubPages` (e.g., Mixer, EQ, Sends) as seen in Novation/Arturia reference implementations.
- **Quirks**: Note if your script expects specific NRPN sequences or proprietary startup bits.
- Prefer human-readable tables (Markdown) over screenshots.