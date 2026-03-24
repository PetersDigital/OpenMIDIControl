# AGENTS.md

This repository is primarily developed using AI coding agents (LLMs) via GitHub Copilot and other tools.

## Milestone Status: v0.1.5 (Phase 2 Refinement)

### ✅ Completed Tasks
- [x] Consolidate Fader Gesture Logic in `onVerticalDragStart`.
- [x] Apply Behavior Logic (Catch-up) to incoming hardware MIDI.
- [x] Implement Metadata-based Reconnection (Name/Manufacturer match).
- [x] Enhanced UI Highlighting for active MIDI ports.
- [x] Virtual MIDI Port implementation.

### ⏳ Current Focus: Phase 3 (App as Peripheral)
- [ ] USB MIDI Class Compliance validation.
- [ ] Pivot `MainActivity.kt` to Peripheral handshake as primary role.
- [ ] Logic for Windows-to-Android fader resolution (high-precision MIDI 2.0 readiness).

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
git checkout feat-android-midi-bridge-v0.1.5
git push -u origin feat-android-midi-bridge-v0.1.5

# 2. Create draft PR
 gh pr create --base main --head feat-android-midi-bridge-v0.1.5 `
  --title "feat(midi): v0.1.5 milestone" `
  --body "Native MIDI bridge, metadata reconnect, portrait-first UX" `
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
git checkout feat-android-midi-bridge-v0.1.5
git push -u origin feat-android-midi-bridge-v0.1.5

# 2. Create draft PR
gh pr create --base main --head feat-android-midi-bridge-v0.1.5 \
  --title "feat(midi): v0.1.5 milestone" \
  --body "Native MIDI bridge, metadata reconnect, portrait-first UX" \
  --draft --assignee dencelkbabu --reviewer dencelkbabu \
  --label "draft, needs review"

# 3. GitHub UI bot reviewers (if needed)
# - copilot-pull-request-reviewer
# - gemini-code-assist

# 4. Open PR in browser
gh pr view --web
```

