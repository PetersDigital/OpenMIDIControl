# Contributing to OpenMIDIControl

## Development approach
This project is maintained by PetersDigital and is primarily implemented with AI assistance. Human review is required for merges.

## Versioning
We use **Semantic Versioning (SemVer)**:
- `MAJOR`: incompatible changes
- `MINOR`: backwards-compatible features
- `PATCH`: backwards-compatible fixes

## Commit messages (Conventional Commits)
We use Conventional Commits:

Format:
`<type>[optional scope]: <description>`

Examples:
- `feat(android): add multi-touch fader control`
- `fix(midi): prevent feedback loop on CC echo`
- `docs: update roadmap`
- `chore(deps): update dependencies`

Common types:
- `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`

## Pull requests
- Keep PRs small and focused.
- Update `CHANGELOG.md` for user-visible changes.
- Include tests when feasible.

## Reporting issues
Please include:
- OS (Windows 11 version)
- Android device model + Android version
- DAW (Cubase/FL/etc.) and routing details
- Steps to reproduce + expected vs actual behavior