# OpenMIDIControl

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

This repository currently documents the new direction, design constraints, and implementation baseline.

## Project Direction

- Android-first touch control for expressive MIDI performance
- DAW-agnostic baseline using standard MIDI messages
- Optional host-specific integrations only after the baseline is stable
- Deterministic behavior and defensive feedback-loop prevention

## Platform & Stack (baseline)

- Android 10+ (API 29+), scaling to tablets (iPadOS/Android) and Windows touch displays
- Flutter UI (Dart) for high-performance, cross-platform Material 3 rendering
- Core app is isolated in a subdirectory (e.g., `app/`) to maintain modularity for future host adapters and desktop bridges
- Target transport: wired USB-MIDI (Milestone 1-3); WebSockets/OSC (Milestone 4+) for advanced macro integration
- Build variants: debug (verbose logging, test harness) and release (reduced logging)

## Project Goals

1. Ship a clean baseline with low-latency fader control and reliable feedback.
2. Keep architecture modular so host integrations and advanced routing can be added safely.
3. Preserve protocol and reliability learnings in clear documentation.

## Technical Baseline

- Multi-touch pointer capture per control
- "Absolute/Relative" hybrid touch behavior: touch anywhere to capture, slide to change relatively (prevents jarring value jumps)
- Responsive LayoutBuilder UI:
  - **Phones (Portrait):** Top 30% dummy display/controls, Bottom 70% extra-long CC1/CC11 faders.
  - **Tablets/Windows (Landscape):** Grid layout (Faders on left, Display top-center, Macro space on right).
- State Management (Riverpod/Bloc) emitting "Intent" events to strictly decouple UI from transport layers
- Normalized internal value domain (`0.0..1.0`)
- MIDI CC output with optional 14-bit precision (MSB/LSB pairs)
- MIDI input-driven UI feedback with touch override behavior
- Value-based deduplication and short time-window suppression to avoid echo loops
- Rate limiting/coalescing to protect battery and thermal stability

## Planned Milestones

The project uses feature milestones instead of date promises.

1. Core wired control: two expressive faders, stable feedback, test harness
2. Configurability: mappings, pickup/jump modes, smoothing controls
3. Expanded controls: buttons/switches and richer state sync
4. Optional desktop bridge and wireless transport
5. Stable contributor-ready architecture and documentation

## Repository Status

- Documentation and implementation are evolving together
- Implementation code is intentionally not yet committed
- Decisions are tracked in [ARCHITECTURE.md](ARCHITECTURE.md), [USERGUIDE.md](USERGUIDE.md), and [CHANGELOG.md](CHANGELOG.md)
- Cubase-specific reference mappings live under [references/cubase](references/cubase) and inform optional host adapters

## Development Workflow

This repository follows:

- Semantic Versioning (SemVer)
- Conventional Commits
- Small, reviewable pull requests

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for contributor and agent guardrails.

## Credits

- Project: PetersDigital
- Contributors: maintainers and community contributors (see Git history)

Full attributions: [CREDITS.md](CREDITS.md)

## License

- Open source: GPL-3.0 ([LICENSE](LICENSE))
- Commercial licensing: available separately from PetersDigital
