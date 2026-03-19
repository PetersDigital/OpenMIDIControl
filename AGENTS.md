# AGENTS.md

This repository is primarily developed using AI coding agents (LLMs) via GitHub Copilot and other tools.

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