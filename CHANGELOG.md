# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

## [Unreleased]
### Added
- Kotlin / host integration work (Run 2) will add the native MIDI bridge, port selectors, and defensive correspondence for wired USB transport.

## [0.1.0] - 2026-03-21
### Added
- **Run 1 Flutter UI:** `OpenMIDIControl` now ships with the responsive command center (status row, 3×3 grid, and top-bar actions) plus the performance area containing two `HybridTouchFader` widgets that adjust for mobile or desktop layouts.
- **Hybrid Touch Fader polish:** Each fader displays `DSEG7Modern` readouts, supports long-press CC selection, and keeps per-control color cues, gutters, and multi-touch capture semantics.
- **Settings & MIDI placeholders:** Added the Settings view (Jump/Hybrid/Catch-Up, layout-hand toggle, version metadata) and the MIDI Settings placeholder (device disconnected banner + search tile) for the future MIDI port manager.
- **Riverpod + theming:** Riverpod providers now power layout/behavior state, and the Material 3 dark theme pulls `Space Grotesk` + `Inter` while honoring the Ethereal Console palette.
### Changed
- Renamed the Flutter package to `OpenMIDIControl`, updated build metadata, and centralized documentation around the new UI (README, DESIGN, IMPLEMENTATION) as part of the v0.1.0 release.
- Cleaned up Flutter analysis warnings, removed deprecated members, and refreshed iconography to keep the CI `flutter analyze` pass green.

## [0.0.0] - 2026-03-19
### Added
- Project initialized (documentation only).