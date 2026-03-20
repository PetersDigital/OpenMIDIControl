# Cubase Reference Mappings

This directory contains vendor-specific Cubase controller scripts and mapping notes. Use them as examples when building optional host adapters without altering the DAW-agnostic core.

## Structure
- `vendor/model/` folders contain script snippets or mapping tables for that device.
- Keep additions isolated; do not change core app behavior or MIDI policies here.

## Contribution guidelines
- Document per-control mapping: CC/Channel, 7-bit vs 14-bit, pickup/jump mode, feedback expectations.
- Note any Cubase script quirks (e.g., needs SysEx init, expects NRPN).
- Prefer human-readable tables (Markdown) over screenshots.