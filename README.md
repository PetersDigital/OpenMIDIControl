# OpenMIDIControl

![Release](https://img.shields.io/github/v/release/PetersDigital/OpenMIDIControl?style=for-the-badge&color=blue)
![Production](https://img.shields.io/github/actions/workflow/status/PetersDigital/OpenMIDIControl/cd_auto_prod.yml?style=for-the-badge&label=Production)
![License](https://img.shields.io/github/license/PetersDigital/OpenMIDIControl?style=for-the-badge&color=green)

- **App Namespace**: Unified Android (package) and iOS bundle identifiers directly to `com.petersdigital.openmidicontrol` (Standardized v0.2.2).

OpenMIDIControl is a performance-first, multi-touch MIDI control surface.

## Getting Started

1. Install Flutter 3.x and target Android 10+ or desktop/Windows devices.
2. Run `flutter pub get` inside the `app/` folder.
3. Start the app with `flutter run -d <device>`.
4. Open the settings or MIDI settings screens to configure ports and layouts.

## Current Status

- **v0.3.0** is the current implementation baseline, covering the DAG router, hybrid touch engine, unified layout state, and thermal hardening.
- **v0.4.x** is the next active focus for the modular layout editor and related persistence work.
- See [IMPLEMENTATION.md](IMPLEMENTATION.md) for the detailed roadmap.

## Core Docs

- [Implementation Roadmap](IMPLEMENTATION.md) - version history and future milestones.
- [Architecture](ARCHITECTURE.md) - system design, constraints, and platform decisions.
- [Design System](DESIGN.md) - UI language and interaction rules.
- [User Guide](USERGUIDE.md) - controls, mappings, and day-to-day usage.
- [Testing](TESTING.md) - automated and hardware-in-the-loop validation.
- [Contributing](CONTRIBUTING.md) - branch strategy, versioning, and contribution rules.
- [Agent Guidelines](AGENTS.md) - maintainer and automation rules.
- [CI/CD Guide](.github/CI_CD_README.md) - workflows, prerelease tags, and release flow.

## Repository Notes

- Documentation and implementation are expected to evolve together.
- Cubase-specific reference mappings live under [references/cubase](references/cubase).
- Release and branch workflow details live in [CONTRIBUTING.md](CONTRIBUTING.md) and [`.github/CI_CD_README.md`](.github/CI_CD_README.md).

## Licensing

This project is dual-licensed under:

- GNU General Public License v3.0 (GPLv3)
- Commercial License (LicenseRef-Commercial)

All source files include the SPDX identifier:

```text
SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
```

### Open Source Use (GPLv3)

This software is available under the GPLv3. If you use, modify, or distribute
this software, you must comply with the terms of the GPLv3.

### Commercial Use

If you wish to use this software without complying with GPLv3 (for example,
in proprietary or closed-source applications), you must obtain a commercial
license.

Commercial licenses are granted on a case-by-case basis.

For licensing inquiries, contact: [dencelbabu@gmail.com](mailto:dencelbabu@gmail.com)

### License Header Enforcement

License headers are automatically checked by CI.

See [docs/LICENSING.md](docs/LICENSING.md) for details.

## Credits

- Project: Peters Digital
- Contributors: maintainers and community contributors (see Git history)

Full attributions: [CREDITS.md](CREDITS.md)
