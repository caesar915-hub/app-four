# WORKLOG

**Invariant:** every line here must reconcile with `git log` / `gh pr list`. If it doesn't,
the generator is wrong — fix the generator, not the prose.

This is the *what changed* record (machine-derived). For *why*, see [DEVLOG.md](DEVLOG.md);
for *what's next*, see [BACKLOG.md](BACKLOG.md). Blocks are newest-on-top, one per work
session. Code changes are grouped by Conventional-Commit type. Generated from `git log`,
`git log --merges`, `gh pr list`, `git worktree list`, `git tag`.

## 2026-07-08 13:34 – 2026-07-09 16:17 · spec-031 hardening: V3 folded header + Swift 6 warning sweep · feat/nutrition-signals-demo

**Code changes**
- _Fixes_
  - `e19abf57` fix(031): clear Swift 6 actor-isolation warnings — 5 files, +8/−8
  - `363bf171` fix(031): clear remaining Swift 6 deprecation warnings — 4 files, +43/−20
- _WIP_
  - `af1561a8` wip(031): nutrition daycard HealthKit mapping/grouping + folded header — 5 files, +77/−110 (incl. pbxproj phantom-group removal)

**Git actions**
- Branch `feat/nutrition-signals-demo` **not pushed** (no `origin/` ref); no PR yet — PR target per T043 is `feat/healthkit-signals` (stacked), not `main`.
- No merges, no new tags (latest tag remains `v0.8.0`).

**Open PRs** (`gh pr list`, 2026-07-09 17:45 WEST)
- #25 `feat/ios26-target` — raise deployment target 17.0 → 26.0
- #16 `feat/023-weather-checkin` — weather at check-in (spec 023)
- #14 `feat/nlp-multilang-demo` — multilingual on-device check-in extractor (demo)
- #8 `feat/healthkit-signals` — HealthKit signals (sleep, activity, heart, cycle) — Spec Kit 009

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  e19abf57 [feat/nutrition-signals-demo]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                2dd1e82c [feat/030-app-intents]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         eaf72ef3 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   b6f5149d [qa/device-ios26-029]
```
