# Contributing to OpenMIDIControl

## Development approach
This project is maintained by PetersDigital and is primarily implemented with AI assistance. Human review is required for merges.

Current phase: foundational implementation and documentation. Prefer small, reviewable increments.

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

- `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`

**Important**:
- **No version numbers in commit subjects**. Versioning is handled only through Git tags and `CHANGELOG.md` updates.
- Keep the title concise (imperative mood).

## Release process

Releases are triggered by pushing **signed SemVer tags**:

```bash
git tag -s v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

1. Ensure the `CHANGELOG.md` is updated with the version header and changes.
2. Tag the commit on the `main` branch.
3. Tags must follow the `vX.Y.Z` format.

## Pull requests
- Keep PRs small and focused.
- Update `CHANGELOG.md` for user-visible changes.
- Include tests when feasible.

## Reporting issues
Please include:
- OS (Windows 11 version)
- Android device model + Android version
- DAW and routing details
- Steps to reproduce + expected vs actual behavior

## Coding standards & patterns

### Defensive programming for MIDI reliability
All MIDI-related code should implement **value-based deduplication** to prevent feedback loops:

- **Caching**: Store the last-sent value for each message type/parameter
- **Comparison**: Check incoming values against cache before processing/forwarding
- **Time windows**: Use millisecond-level (not tick-based) timestamps for dedup checks; empirical safe window is 50ms
- **Multi-tier**: Apply dedup at multiple layers (UI logic, MIDI service, transport adapter) for robustness

Example (Dart):
```dart
// Bad (only checks MSB)
if (lastSent == msb) return;

// Good (checks complete 14-bit value)
final cachedValue = _cc14Cache[faderIndex];
if (cachedValue == value14Bit && timeSinceSent < 100ms) return;
_cc14Cache[faderIndex] = value14Bit;
```

### API specification verification
When modifying host integration or Android integration:
1. Verify against official host/API documentation (if available)
2. Test callback signatures against the documentation
3. Add defensive `if (obj && obj.mMethod)` guards for version compatibility
4. Document the exact line/signature from spec in adjacent comments

### State machine clarity
Prefer explicit state tracking over implicit logic:
- Use named flags for connection states (e.g., `handshakeConfirmed: bool`)
- Track per-object or per-command caches (e.g., `_nrpnStateCache: Map<String, int>`)
- Avoid side effects in dedup checks; separate concerns into dedicated methods

See `ARCHITECTURE.md` for the defensive architecture overview.