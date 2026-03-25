# AGENTS.md

This repository is primarily developed using AI coding agents (LLMs) via GitHub Copilot and other tools.

## Milestone Status: v0.2.0 (Advanced USB MIDI & Dual-Path Routing)

### ✅ Completed (v0.2.0)
- [x] **Virtual MIDI Port**: Native Android MIDI device for local routing.
- [x] **Metadata Reconnection**: Fingerprint matching for USB hot-plug stability.
- [x] **Bi-directional Logic**: Jump/Hybrid/Catch-up applied to hardware MIDI.
- [x] **Responsive UI**: Dedicated landscape layout for ultra-wide phones (S24 Ultra).
- [x] **UI Highlighting**: Active MIDI port visualization in settings.
- [x] **Gesture Fixes**: Fader initialization moved to `onVerticalDragStart`.
- [x] **Haptic Stability**: JVM crash fix for vibration durations.
- [x] **True Peripheral Mode**: Native `MidiDeviceService` for Class Compliance.
- [x] **Port Collision Hiding**: Filtering internal ports from Flutter list to prevent Binder crashes.
- [x] **Batch Performance**: Non-blocking Coroutine buffering (8ms) for UI smoothness.

### ⏳ Current Focus: v0.3.0 (Control Expansion)
- **Phase 4 (Expansion & Precision):**
  - [ ] Implement 3x3 Performance Grid.
  - [ ] Expand tactile haptics for buttons/toggles.
  - [ ] Multi-channel support for independent control assignment.

## Human roles
- **Owner/Maintainer:** PetersDigital
- **Primary development method:** AI-assisted / agent-driven coding
- **Human responsibilities:** requirements, review, merging, releases, licensing/compliance decisions

## How agents should work in this repo
1. **Do not implement features without an issue or an explicit plan step**.
2. Prefer **small, reviewable changes** (one concern per PR).
3. Follow repository conventions:
   - **SemVer** versioning
   - **Conventional Commits** for commit messages
   - Keep docs updated when behavior changes
4. Avoid introducing heavy dependencies without justification.
5. Prioritize:
   - low-latency and low-jitter event handling
   - reliable MIDI behavior
   - multi-touch correctness
   - battery/thermal considerations on Android
6. Do not modify or add code under references/ (including references/cubase/*). 
   - That tree is for reference materials only. 
   - Host-specific adapters and mappings must live in the core codebase or designated integration modules, not in references/.

## Coding standards
- Write code that is easy to read and test.
- Prefer deterministic behavior and explicit state machines for:
  - touch capture per control
  - MIDI in/out feedback synchronization
  - feedback loop prevention

## Safety / compliance
- Do not include proprietary SDKs or copied code from restricted sources.
- Avoid bundling anything that would violate the dual-licensing intent.

## PR checklist (agents)
- [ ] Conventional Commit title
- [ ] Tests added/updated (where applicable)
- [ ] Docs updated (README/ARCHITECTURE/CHANGELOG)
- [ ] No secrets in code or configs
- [ ] PR opened as draft
- [ ] Assignee: @dencelkbabu
- [ ] Reviewers: @dencelkbabu + @copilot-pull-request-reviewer + @gemini-code-assist
- [ ] Labels: draft, needs review

## GitHub CLI guide
Recommended `gh` steps during PR workflow (PowerShell/Bash):

Windows PowerShell:

```powershell
# 1. Check out and push branch
git checkout feat-android-midi-v0.2.0
git push -u origin feat-android-midi-v0.2.0

# 2. Create draft PR
 gh pr create --base main --head feat-android-midi-v0.2.0 `
  --title "feat(midi): v0.2.0 milestone overhaul" `
  --body "True Peripheral Mode, Dual-Path Routing, Performance Batching" `
  --draft --assignee dencelkbabu --reviewer dencelkbabu `
  --label "draft, needs review"

# 3. GitHub UI bot reviewers (if needed)
# - copilot-pull-request-reviewer
# - gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

Unix/Bash:

```bash
# 1. Check out and push branch
git checkout feat-android-midi-v0.2.0
git push -u origin feat-android-midi-v0.2.0

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-v0.2.0 \
  --title "feat(midi): v0.2.0 milestone overhaul" \
  --body "True Peripheral Mode, Dual-Path Routing, Performance Batching" \
  --draft --assignee dencelkbabu --reviewer dencelkbabu \
  --label "draft, needs review"

# 3. GitHub UI bot reviewers (if needed)
# - copilot-pull-request-reviewer
# - gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

