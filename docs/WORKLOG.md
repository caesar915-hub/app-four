# WORKLOG

**Invariant:** every line here must reconcile with `git log` / `gh pr list`. If it doesn't,
the generator is wrong — fix the generator, not the prose.

This is the *what changed* record (machine-derived). For *why*, see [DEVLOG.md](DEVLOG.md);
for *what's next*, see [BACKLOG.md](BACKLOG.md). Blocks are newest-on-top, one per work
session. Code changes are grouped by Conventional-Commit type. Generated from `git log`,
`git log --merges`, `gh pr list`, `git worktree list`, `git tag`.

## 2026-06-28 02:22–18:40 · Merge branch 'fix/ios17-compat' · main

**Code changes**
- _Fixes_
  - `9a7d188c` fix(ios17): encode JournalArchive on main actor, pass Data to detached seal task
  - `5aa44078` fix(ios17): replace ScrollPosition + delete README.md files causing build errors
- _chore_
  - `a9976afa` chore: lower SquirlSignals + SquirlDesignSystem packages to iOS 17.0
  - `01b316d0` chore: lower deployment target to iOS 17.0
- _other_
  - `ade91e71` Merge branch 'fix/ios17-compat'

**Git actions**
- `ade91e71` Merge branch 'fix/ios17-compat'

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  ade91e71 [main]
```

---

## 2026-06-27 17:46–03:06 · lower SquirlSignals + SquirlDesignSystem packages to iOS 17. · main

**Code changes**
- _docs_
  - `0f3300a1` docs(privacy): update contact email to icloud
  - `97dbca22` docs: add privacy policy page for App Store Connect
  - `84d184a8` docs: move spec-026/027/028 to Shipped; regenerate worklog
  - `8e1aa055` docs(claude): require /code-review + device QA before any PR merge
- _chore_
  - `a9976afa` chore: lower SquirlSignals + SquirlDesignSystem packages to iOS 17.0
  - `01b316d0` chore: lower deployment target to iOS 17.0
  - `300703a7` chore: rename bundle ID to squirl-app.app-four, bump build number to 2
- _other_
  - `95de74e4` Merge branch 'main' of https://github.com/caesar915-hub/app-four

**Git actions**
- `95de74e4` Merge branch 'main' of https://github.com/caesar915-hub/app-four

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  a9976afa [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-06-27 13:29–17:50 · Merge branch 'main' of https://github.com/caesar915-hub/app-four · main

**Code changes**
- _Major (feat)_
  - `517609ab` feat(027): recording detail UX pass — 4 info cards, pencil toolbar, delete button, Log Dose restyle
- _Fixes_
  - `b068a37d` fix(027): sleepHours branch missing GlyphBadge — restore parity with original extraTags
  - `e97e5502` fix(concurrency): nonisolate three declarations for SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
  - `2fb66bbd` fix: add missing import SwiftData to ProcessingViewModel
- _docs_
  - `1fd187fe` docs(027): DEVLOG entry — spec-027 shipped to feat/027-recording-detail-ux-pass PR #24
  - `8e1aa055` docs(claude): require /code-review + device QA before any PR merge
  - `9e6c5930` docs(worklog): regenerate — spec-026 + spec-028 shipped to main (PRs #22, #23)
- _other_
  - `95de74e4` Merge branch 'main' of https://github.com/caesar915-hub/app-four
  - `df3f66cb` Merge pull request #24 from caesar915-hub/feat/027-recording-detail-ux-pass

**gh actions**
- PR #24 merged `feat/027-recording-detail-ux-pass` — "feat(027): recording detail UX pass — 4 info cards, pencil toolbar, delete button, Log Dose restyle"

---

## 2026-06-27 13:18–13:27 · weekday-average signal strips in Insights (#23) · main

**Code changes**
- _Major (feat)_
  - `22c37cbe` feat(028): weekday-average signal strips in Insights (#23)
- _Fixes_
  - `bfa578d3` fix(026): audit-critical UI fixes — concurrency, view mechanics, and accessibility
- _Tests_
  - `51f70a9a` test(nlp): port sleep/side-effect recall tests from PR #11 + ratchet floors
- _docs_
  - `b666ae79` docs: worklog + backlog — fix/026 shipped to main (PR #22)

**Git actions**
- `bfa578d3` fix(026): audit-critical UI fixes — concurrency, view mechanics, and accessibility

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  22c37cbe [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b666ae79 [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---

## 2026-06-27 03:15–13:00 · no-op button at AX text sizes — show plain Text, not Button · fix/026-audit-critical-fixes

**Code changes**
- _Fixes_
  - `f7d7bd2c` fix(026): no-op button at AX text sizes — show plain Text, not Button
  - `4f5fead0` fix(026): remove duplicate deinit + startRegenerate in RecordingDetailViewModel
  - `659eceb3` fix(026): audit-critical fixes — concurrency, view mechanics, and accessibility
- _docs_
  - `52469592` docs(worklog): regenerate — spec-028 implementation session

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  51f70a9a [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              f7d7bd2c [fix/026-audit-critical-fixes]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---

## 2026-06-24 20:12–12:49 · spec + plan + tasks — Insights weekday-average signal strips · feat/028-weekday-signals

**Code changes**
- _Major (feat)_
  - `da9e8e22` feat(028): weekday-average signal strips in Insights
  - `f07b3dd0` feat(024/025): QA round + closed check-in ring (300pt, actions inside)
  - `85fb5cc1` feat(023): DayCard redesign — SF typography, no-pill rows, no-disc header + calendar push-to-detail
  - `b9ad1fa6` feat(025): closed ring 300pt — green-dominant, amber at 6 o'clock, idle actions inside ring
  - `48b16958` feat(024): QA round — calendar/check-in/settings mechanical fixes
  - `c2800be4` feat(daycard): spec-023 redesign — SF typography + no-pill rows + no-disc header
  - `7bde98f9` feat(nlp): port recall-improved English extractor (supersedes PR #11)
- _Fixes_
  - `82350ed0` fix(whisper): tighten model-ready check to weights/ subdir, not mlmodelc skeleton
  - `9bf406ac` fix(whisper): guard localPath against partially-downloaded model directory
  - `9daf3596` fix(settings): Paper & Pollen theming — cream rows, paper gutter, green pills
  - `d15e10c9` fix(daycard): calmer expand — anchored header title + ease curve
- _refactor_
  - `8e74e7b0` refactor(nlp): address extractor review — precompiled matching, scan-back sleep guard, clock-time fix
- _docs_
  - `5535ecf5` docs(028): spec + plan + tasks — Insights weekday-average signal strips
  - `fd583f82` docs(024): spec + plan + tasks — calendar/check-in/settings QA round
  - `d92821ad` docs: codify 'invoke Swift skills before SwiftUI code' in CLAUDE.md

**gh actions**
- PR #21 merged `feat/024-calendar-checkin-settings-qa` — "feat(024/025): QA round + closed check-in ring (300pt, actions inside)"
- PR #20 merged `feat/daycard-v8` — "feat(023): DayCard redesign — SF typography, no-pill rows, no-disc header + calendar push-to-detail"
- PR #17 merged `feat/spm-packages` — "fix(settings): Paper & Pollen theming — cream rows, paper gutter, green pills"
- PR #15 merged `fix/022-view-audit-remediation` — "fix(022): view-layer audit remediation — P1+P2 + modern-API polish"
- PR #13 merged `fix/nlp-english-recall` — "feat(nlp): port recall-improved English extractor (supersedes PR #11)"

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  82350ed0 [main]
/Users/caesargrey/Projects/app-four-spm                                              5535ecf5 [feat/028-weekday-signals]
```

---

## 2026-06-26 00:33 · Calendar → recording detail · feat/daycard-v8 (→ PR #18)

**Code changes**
- _Major (feat)_
  - `d28b611d` feat(calendar): push to recording detail instead of sheet (reverses spec-002 D3)

**gh actions**
- PR **#18** opened `feat/calendar-detail-push` — "feat(calendar): push to recording detail instead of sheet" — `MERGEABLE`, open

---

## 2026-06-25 20:00–20:01 · Settings theming · feat/spm-packages (→ PR #17)

**Code changes**
- _Fixes_
  - `c466f575` fix(settings): Paper & Pollen theming — cream rows, paper gutter, green pills
- _docs_
  - `b47354aa` docs: add PR #17 link to BACKLOG Settings fix entry

**gh actions**
- PR **#17** opened `feat/spm-packages` — "fix(settings): Paper & Pollen theming …" — `MERGEABLE`, open

---

## 2026-06-25 10:59–12:52 · SPM extraction + sandbox + 022 view-audit remediation · feat/spm-designsystem → feat/spm-packages

**Code changes**
- _Major (feat)_
  - `d2578787` feat(spm): extract SquirlDesignSystem package (tokens, glyphs, palette, fonts)
  - `63f70fe7` feat(sandbox): XcodeGen UI-only app + DesignGallery on the real package
  - `9d6b4d47` feat(sandbox): Calendar tab with fold/unfold on mock data (real design system)
  - `0e10b108` feat(sandbox): -dark/-gallery launch args for screenshotting both themes/tabs
  - `ceb16a0a` feat(sandbox): Insights tab — mood bubbles, signal strips, gauges, connection card
  - `4fb374f7` feat(debug): default mock-data ON in DEBUG for UI/UX dev
- _Fixes (022 view-audit remediation)_
  - `9ab67b90` fix(022): P1 — restore detail toolbar from Calendar + scale chip text (US1, US2)
  - `d289a263` fix(022): P2/US3 — fence debug scaffolding out of Release builds
  - `11a5c690` fix(022): P2/US4 — remove dead files + unobserved VM state machines
  - `b85be773` fix(022): P2/US4 — drop dead summary mirror + exportJSON from RecordingDetailViewModel
  - `6799cd4e` fix(022): P2/US4 — drop unused .card(elevated:) + Elevation, dead ScreenshotCapture state
  - `5bdf8b1a` fix(022): P3 — modern Text interpolation for the two iOS 26 '+' deprecations
  - `1931e097` fix(calendar): design-review mechanical fixes — DM Sans day numbers, 44pt header targets, sleep glyph
- _Tests_
  - `08e16e53` test(022): retarget ProcessingViewModelTests to persisted summaryStatus; drop LibraryViewModelTests
  - `98d66a2e` test: stop persisting debugMockMode=false from the test host
- _chore / docs_
  - `45e90bf1` docs: final overnight report — all phases complete, run instructions, merge notes
  - `b2f32220` docs(022): view-audit remediation spec, plan, tasks + audit reports
  - `d8681b1c` chore: Xcode pbxproj normalization (local-package comment labels, empty exceptions block)

**Git actions**
- `36215ba4` merge: bring in 022 view-audit-remediation under the SPM layout

**gh actions**
- PR **#16** opened `feat/023-weather-checkin` — "feat: weather at check-in (spec 023)" — `MERGEABLE`, open
- PR **#15** opened `fix/022-view-audit-remediation` — "fix(022): view-layer audit remediation — P1+P2 + modern-API polish" — `MERGEABLE`, open

---

## 2026-06-25 02:50–03:06 · Overnight SPM leaf package · feat/spm-designsystem

**Code changes**
- _Major (feat)_
  - `2ad9e030` feat(spm): extract SquirlSignals leaf package (4 level enums)
- _docs_
  - `c2323331` docs: overnight progress log (Phase 1 done; concurrency incident + worktree pivot)

**gh actions**
- PR **#14** opened `feat/nlp-multilang-demo` — "feat(021): multilingual on-device check-in extractor (en/pt-PT/es-ES/es-MX) — demo" — `MERGEABLE`, open

---

## Baseline — ≤ 2026-06-24 (pre-worklog)

The worklog begins at the `main` tip. Everything above is **unmerged work ahead of `main`**
(24 commits on `feat/daycard-v8`, merge-base `55201477`). History before this is recorded in
`git log` and in PRs #1–#10; it is not re-narrated here.

- `main` tip: `55201477` (2026-06-24 23:15) feat(020): rename check-in Feelings→Emotions, curated 20-word Mood-Meter lexicon
- Tag `v0.8.0`: `62eaee08` (2026-06-16 18:34) fix(ui): reset Settings scroll, simplify check-in header, scroll Insights month selector
- Last merge to `main`: PR **#10** `feat/daycard-update` merged 2026-06-24 21:10 — "feat(014): daily-card redesign — folded summary opens to the day"
- Merged PRs to date: #10, #6, #5, #4, #3, #2. Closed-unmerged: #1 (`fix/calendar-header-scroll-fade`).

---

## State snapshot (as of 2026-06-26, `gh pr list` / `git worktree list`)

**Open PRs (11)** — all unmerged:

| PR | Branch | Mergeable |
|----|--------|-----------|
| #18 | feat/calendar-detail-push | MERGEABLE |
| #17 | feat/spm-packages | MERGEABLE |
| #16 | feat/023-weather-checkin | MERGEABLE |
| #15 | fix/022-view-audit-remediation | MERGEABLE |
| #14 | feat/nlp-multilang-demo | MERGEABLE |
| #13 | fix/nlp-english-recall | **CONFLICTING** |
| #12 | feat/ux-improvements-015-017 | MERGEABLE |
| #11 | fix/extractor-recall | MERGEABLE |
| #9  | fix/testflight-readiness | MERGEABLE |
| #8  | feat/healthkit-signals | MERGEABLE |
| #7  | chore/track-prds-mockups-spikes | MERGEABLE |

⚠️ 11 PRs stacked unmerged against `main` — growing merge-conflict surface (#13 already CONFLICTING).

**Worktrees (9)** — `git worktree list`:
- `app-four` → feat/spm-designsystem `eb37b397`
- `app-four-localization` → feat/023-localization-multilang `18c3cdd4`
- `app-four-nlp-recall` → fix/nlp-english-recall `7bde98f9`
- `app-four-nlp-recall-emotions` → fix/nlp-english-recall-on-emotions `55201477`
- `app-four-recall-fix` → fix/extractor-recall `422af53f`
- `app-four-spm` → feat/daycard-v8 `d28b611d` _(current)_
- `.claude/worktrees/feat+healthkit-signals` → feat/healthkit-signals `f032126b`
- `.claude/worktrees/feat+weather-checkin` → worktree-feat+weather-checkin `ca0f81fc`
- `.claude/worktrees/fix+022-view-audit-remediation` → fix/022-view-audit-remediation `08e16e53`
