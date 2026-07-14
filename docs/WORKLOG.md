# WORKLOG

## 2026-07-10 15:42 – 2026-07-14 01:55 · reconcile stashes/PRs/worktrees debt (round 2) — DEBT.md + D · main

**Code changes**
- _Tests_
  - `cfda413d` test(030): fix Swift 6 'mutated after capture' warning in gateIsReevaluatedPerCall
- _docs_
  - `a65010de` docs: reconcile stashes/PRs/worktrees debt (round 2) — DEBT.md + DEVLOG + BACKLOG
  - `f1dfcf54` docs: regen WORKLOG after 2026-07-14 hygiene pass (derived from git/gh)
- _chore_
  - `23dc5180` chore: repo-hygiene pass — remove stray artifact, gitignore model dump, doc debt registry
- _other_
  - `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
  - `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**Git actions**
- `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
- `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**gh actions**
- PR #26 merged `feat/030-app-intents` — "feat(030): App Intents foundation — router, dose-logging engine, Settings surface"
- PR #30 opened `chore/swift6-tech-debt` — "chore: clear Swift-6-language-mode test warnings + med color token" — OPEN/MERGEABLE
- PR #29 opened `feat/030-us3-us4` — "feat(030): US4 guided NFC sticker setup (StickerSetupView) + FR-005 amendment" — OPEN/CONFLICTING

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  a65010de [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              f13abb5e [feat/034-daycard-a01]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                00cca98a [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 8d9b7ab8 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   d04eb5ea [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-10 15:42 – 2026-07-14 00:51 · repo-hygiene pass — remove stray artifact, gitignore model d · main

**Code changes**
- _Major (feat)_
  - `db39ed5c` feat(030): US2 hands-free check-in — StartCheckInIntent + FR-022 onboarding gate (T024–T028)
- _Fixes_
  - `c8442057` fix(030): compile ConfirmationCopyTests — key-path closure trips #expect throws analysis
  - `e0ea1cc3` fix(030): mark MedicationCatalog nonisolated — pure static reference data
- _Tests_
  - `cfda413d` test(030): fix Swift 6 'mutated after capture' warning in gateIsReevaluatedPerCall
  - `66a0a40b` test(030): cover two reachable service states the pre-merge review flagged
- _docs_
  - `9e8eb1c4` docs(030): DEVLOG US1-intent-layer entry + WORKLOG regen
- _chore_
  - `23dc5180` chore: repo-hygiene pass — remove stray artifact, gitignore model dump, doc debt registry
  - `3661a007` chore(030): remove 6 dead PBXGroups + wire test plan so ⌘U runs the suite
- _other_
  - `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
  - `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**Git actions**
- `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
- `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**gh actions**
- PR #26 merged `feat/030-app-intents` — "feat(030): App Intents foundation — router, dose-logging engine, Settings surface"
- PR #30 opened `chore/swift6-tech-debt` — "chore: clear Swift-6-language-mode test warnings + med color token" — OPEN/MERGEABLE
- PR #29 opened `feat/030-us3-us4` — "feat(030): US4 guided NFC sticker setup (StickerSetupView) + FR-005 amendment" — OPEN/MERGEABLE
- PR #28 opened `feat/033-newlook-app-wide` — "feat(033): app-wide New Look migration + medication-bar a01 redesign" — OPEN/CONFLICTING

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  23dc5180 [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              f13abb5e [feat/034-daycard-a01]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                00cca98a [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   b6f5149d [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-11 02:15–15:13 · US1 intent layer — LogDefaultDoseIntent + Shortcuts + DI (T0 · feat/030-app-intents

**Code changes**
- _Major (feat)_
  - `4c07f7bb` feat(030): US1 intent layer — LogDefaultDoseIntent + Shortcuts + DI (T019–T021)
- _Fixes_
  - `1e60ee02` fix(030): verification-pass findings — explicit dose tap, flow chips, a11y
  - `ffeff928` fix(030): Settings sections match the approved T011 mockup — inline, no push
- _Tests_
  - `57420d56` test(030): round-trips reload via fresh ModelContext, autosave pinned off
- _docs_
  - `6947d03b` docs(030): DEVLOG review-cycle entry + WORKLOG regen

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  bb62dd4f [feat/nutrition-signals-demo]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              11a25657 [feat/032-newlook-screens]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                4c07f7bb [feat/030-app-intents]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   b6f5149d [qa/device-ios26-029]
```

---

## 2026-07-03 17:56–18:26 · 029 calendar-day-context task breakdown (45 tasks, test-firs · main

**Code changes**
- _docs_
  - `3e8b6646` docs: regenerate WORKLOG after 029 plan
- _other_
  - `a13b7987` tasks: 029 calendar-day-context task breakdown (45 tasks, test-first, mockup-gated)
  - `6abd77e2` plan: 029 calendar-day-context implementation plan (research, data-model, contracts, quickstart)

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  a13b7987 [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-07-03 17:37–17:56 · 029 calendar-day-context implementation plan (research, data · main

**Code changes**
- _docs_
  - `758c1e03` docs: regenerate WORKLOG after data-flow diagram
- _other_
  - `6abd77e2` plan: 029 calendar-day-context implementation plan (research, data-model, contracts, quickstart)

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  6abd77e2 [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-07-03 17:12–17:37 · investor-facing calendar data-flow diagram + root PRODUCT.md · main

**Code changes**
- _docs_
  - `7a74284d` docs: investor-facing calendar data-flow diagram + root PRODUCT.md
  - `c82ed9f7` docs: regenerate WORKLOG after spec 029 clarify
- _other_
  - `2e2b9213` spec: 029 clarify session — classified context line (wireframe-decided), full-list UI deferred, check-in-only trigger

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  7a74284d [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-07-03 14:42–17:12 · 029 clarify session — classified context line (wireframe-dec · main

**Code changes**
- _docs_
  - `cd387611` docs: regenerate WORKLOG after spec 029
- _other_
  - `2e2b9213` spec: 029 clarify session — classified context line (wireframe-decided), full-list UI deferred, check-in-only trigger
  - `24478e7a` spec: 029 calendar-day-context (Phase 1) via speckit-specify + adversarial validation

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  2e2b9213 [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-07-03 14:03–14:42 · 029 calendar-day-context (Phase 1) via speckit-specify + adv · main

**Code changes**
- _docs_
  - `a6518fe6` docs: regenerate WORKLOG; worklog.sh multi-day header fix
- _other_
  - `24478e7a` spec: 029 calendar-day-context (Phase 1) via speckit-specify + adversarial validation

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  24478e7a [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-06-30 16:15 – 2026-07-03 14:01 · calendar-integration design spec (post-v1.0 flagship) + BACK · main

**Code changes**
- _docs_
  - `a154959d` docs: calendar-integration design spec (post-v1.0 flagship) + BACKLOG/DEVLOG
  - `26ff1769` docs: Phase 1 grep correction — badgeTint used by TimelineBead
  - `d0e57a72` docs: fold Phase 0 outcome into Figma plan (PNG@3x glyphs, SF Mono stand-in)
  - `59d5b106` docs: add deep-plan-review skill + Figma DS reproduction plan
  - `fa9856a5` docs: regenerate WORKLOG after Stable TestFlight channel merge

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  a154959d [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---
## 2026-06-29 17:07–16:14 · add Stable TestFlight channel (squirl-app.app-four.stable) · main

**Code changes**
- _Major (feat)_
  - `35a7ef96` feat: add Stable TestFlight channel (squirl-app.app-four.stable)
  - `e5491464` feat: add shared schemes app-four and app-four-stable
  - `32339be1` feat: add AppIcon-Stable asset (desaturated variant for Stable TestFlight channel)
  - `971fae64` feat: add Debug-Stable / Release-Stable build configurations for Stable TestFlight channel
- _docs_
  - `2fa2516e` docs: document Stable TestFlight channel in OPERATIONS.md and BACKLOG.md
  - `272d7760` docs: regenerate WORKLOG for the docs-convention session

**Git actions**
- `35a7ef96` feat: add Stable TestFlight channel (squirl-app.app-four.stable)

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  35a7ef96 [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---

**Invariant:** every line here must reconcile with `git log` / `gh pr list`. If it doesn't,
the generator is wrong — fix the generator, not the prose.

This is the *what changed* record (machine-derived). For *why*, see [DEVLOG.md](DEVLOG.md);
for *what's next*, see [BACKLOG.md](BACKLOG.md). Blocks are newest-on-top, one per work
session. Code changes are grouped by Conventional-Commit type. Generated from `git log`,
`git log --merges`, `gh pr list`, `git worktree list`, `git tag`.

## 2026-06-28 18:41–17:03 · require created/updated timestamps on all markdown files · main

**Code changes**
- _docs_
  - `7848fcce` docs: require created/updated timestamps on all markdown files
  - `20bd0b16` docs: record spec-023 typography reversal in CLAUDE.md
  - `7ba84a70` docs: decouple app-four README from private docs path
  - `a1987ab2` docs: regenerate WORKLOG after fix/ios17-compat merge

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  7848fcce [main]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              b068a37d [feat/027-recording-detail-ux-pass]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         f032126b [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
```

---

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
