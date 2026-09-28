## 2026-09-28 13:48–15:37 · board, log and task checklist for C4–C7 and the D1/D2 sweeps · feat/057-ui-refresh

**Code changes**
- _Major (feat)_
  - `3ea70ed7` feat(057/C7): Settings as card groups + medication-bar title options
  - `a4b3fa1b` feat(057/C6): Insights on the pen's four cards + connections
  - `be7a813e` feat(057/C5): Edit Check-In as a pushed page with a dirty-gated Save
  - `4b818a06` feat(057/C4): Day Details on the pen's page + wave-1 screenshot fixes
  - `e952998d` feat(057/C3): secondary surfaces wave 1 — text composer, Log Dose sheet, onboarding tokens
  - `05f0db2e` feat(057/C2): Calendar / Mood Journal on the pen's cards, week strip and medication bar
  - `f68469d1` feat(057/C1): check-in trio on the pen's anchored ring (hub · listening · saved)
  - `64179bb0` feat(057/B4): floating tab bar + Add button, chrome-less roots, chrome visibility preference
  - `c3a8f2ec` feat(057/B3): pen glyphs as SwiftUI paths, sleep ramp, medication atoms, ring, level tiles
  - `03492ed7` feat(057/B2): button styles, Bill-shape chips, nav pills, controls and icon map
  - `6bb864af` feat(057/B1): pen-derived tokens, typography roles, layout tokens and card atoms
- _Fixes_
  - `b5769642` fix(057/D2): wave-2 screenshot findings + sandbox build
- _docs_
  - `fbd43e23` docs(057): board, log and task checklist for C4–C7 and the D1/D2 sweeps
  - `de50df00` docs(057): decisions accepted (UI-02), Epic UI tickets + backlog (UI-03), Spec Kit 057 (UI-05)
  - `e0dc67b5` docs(057): pen-derived DESIGN.md, UI refresh plan, research pack and pen exports
- _chore_
  - `51576547` chore(057/D1): delete the refresh-orphaned code and the pre-057 token aliases

**gh actions**
- PR #47 opened `fix/insights-sleep-mood-gate` — "fix(insights): Sleep × Mood connection gates on the canonical sleep level (UI-40)" — OPEN/MERGEABLE

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                                               074bb264 [docs/llm-fsd-alignment]
/private/tmp/claude-501/-Users-caesargrey-Projects-app-four/9b2edc5e-33b2-475c-b128-3fa4ef03a52c/scratchpad/qa-wt 05ee8e38 [fix/audit-high-medium] prunable
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                                             9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                                                 965dcf22 [feat/037-live-activity-controls]
/Users/caesargrey/Projects/app-four/.claude/worktrees/040-sleep-mood-gate                                         51d84d44 [fix/insights-sleep-mood-gate]
/Users/caesargrey/Projects/app-four/.claude/worktrees/054-settings-topic-hub                                      4d1a3e88 [feat/054-settings-topic-hub]
/Users/caesargrey/Projects/app-four/.claude/worktrees/055-rc-foundation                                           7002bb5b [feat/055-revenuecat]
/Users/caesargrey/Projects/app-four/.claude/worktrees/057-ui-refresh                                              fbd43e23 [feat/057-ui-refresh]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals                                      5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/remove-nlp                                                  73e8a091 [chore/remove-dead-nlp]
/Users/caesargrey/Projects/app-four/.claude/worktrees/speech-transcriber-probe                                    d5d7dc31 [feat/gemma4-litert-extraction]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ui-refresh                                                  08ba8cba [feat/ui-refresh]
```

---

## 2026-08-11 19:45 – 2026-09-27 12:55 · public-repo README + untrack vendored .gems + credential git · main

**Code changes**
- _Major (feat)_
  - `a92dc759` feat(043/044): on-device MLX journal pipeline + download reliability + tuned extraction
  - `9d1aebea` feat(043): sync tuning 2026-08-18-b from macOS harness
  - `c78993af` feat(043): LLM model management UI + recording pipeline wiring
  - `ae474b6d` feat(044): download & transcription reliability
  - `9219eb40` feat(043): sync tuning 2026-08-17-c + establish tuning sync system
  - `3cf453f3` feat(043): port tuned two-pass prompts + extraction validator from macOS tuning
  - `6b3f544a` feat(043): surface Llama summary on Recording Detail; full transcript
  - `ef06ffb4` feat(043): Journal Insights row in Settings › AI Models
  - `14ba99cf` feat(043): sequential Llama download step in onboarding
  - `8362b7bc` feat(043): managed lifecycle for the Llama insights model
  - `60ec4d75` feat: extraction review ui logic and validation (Part 3)
  - `6eca6cb2` feat(mlx): add memory headroom alert and fallback handling (US7)
  - `b5612ba5` feat(043): Part 3 - Update provenance tags from .nlp to .llm in ExtractionReviewViewModel
  - `4ec0b7da` feat(043): Part 2 — validation & persistence pipeline (parseExtraction, ExtractionValidator, UnifiedExtraction)
  - `14b940e6` feat: implement MLXJournalService phase 1-7
- _Fixes_
  - `aacf1d86` fix(concurrency): mark SummaryLengthTier as nonisolated enum
  - `8a2108e4` fix(nlp): canonicalize medication alias names in NLNoteExtractor to preserve eval floors
  - `afa4cf85` fix(spm): vendor MLXLLM/MLXLMCommon as local package (CI-safe, keeps tested dep graph)
  - `c15b14be` fix(spm): switch mlx-swift-examples to remote 2.29.1, clean gitlinks & stale Hub/Tokenizers deps
  - `57bcf137` fix(043/044): address pre-merge code-review findings
  - `f48d1062` fix(043): resolve approachable-concurrency warnings
  - `9c82b541` fix(043): rebuild noteExtraction JSON on review save; wire memory alert
  - `448b64de` fix(043): interpolate transcript into LLM user message; guard stage-3 parse range
- _Tests_
  - `972afee3` test(043): on-device MLX eval harness + tuning & 044 QA reports
- _docs_
  - `93c342e9` docs: public-repo README + untrack vendored .gems + credential gitignore
  - `2553e251` docs: regenerate WORKLOG.md after the Shipaton sprint doc commits
  - `ade0967c` docs(process): September Shipaton sprint doc system
  - `f84d4585` docs(shipaton): RevenueCat research, hard-paywall decision, and md corrections
  - `4d1a3e88` docs(mockups): add 6 view concepts (J-O) from wider app-viz scan; extend research
  - `4fcdc81b` docs: regenerate WORKLOG.md after concurrency warning fix
  - `6906b873` docs: regenerate WORKLOG.md after eval-floor fix
  - `137fd8d0` docs(mockups): add 036 insights additional view concepts gallery
  - `483276a0` docs(mockups): add 036 insights evolution proposal (competitor-informed)
  - `7128996b` docs(research): daylio/bearable insights inventory; fix 036 mockup sleep dataset
  - `a2155542` docs(mockups): add 036 insights screen spec mockup
  - `45be4030` docs: regenerate WORKLOG.md after packaging fix
  - `15dd1c06` docs: regenerate WORKLOG.md after review-fix commit
  - `74d00c20` docs(044): close T035 — save-count verification via counting mocks + call-site inspection
  - `2e67073e` docs: regenerate WORKLOG.md after -c tuning sync commit
  - `63d75728` docs: regenerate WORKLOG.md after 043 tuning-port + QA commits
  - `fbc78ed3` docs(043): mockup — summary card in transcript slot, full transcript below
  - `22e3eeba` docs(043): recording-detail redesign variants mockup
  - `1abed0d2` docs(043): add device QA checklist
  - `aac3ed34` docs(043): mark completed tasks across parts 1-3
  - `8d6eaa9a` docs: rewrite processing and extraction fsd with 5-stage pipeline
- _chore_
  - `66dba5db` chore: accept Xcode project regeneration (local package refs, empty exceptions)
  - `02866367` chore: drop deterministic-extraction gate from plan template
- _other_
  - `ee08788f` Merge pull request #40 from caesar915-hub/chore/tuning-2026-08-18-b
  - `726af0c2` spec(043): add implementation tasks — test-first phased breakdown
  - `de06898d` spec(043): add implementation plan — MLXJournalService
  - `99f6fcf0` spec(043): MLXJournalService — on-device LLM extraction specification

**Git actions**
- `a92dc759` feat(043/044): on-device MLX journal pipeline + download reliability + tuned extraction
- `ee08788f` Merge pull request #40 from caesar915-hub/chore/tuning-2026-08-18-b

**gh actions**
- PR #40 merged `chore/tuning-2026-08-18-b` — "feat(043): sync tuning 2026-08-18-b from macOS harness"
- PR #39 merged `feat/043-mlx-journal-service` — "feat(043/044): on-device MLX journal pipeline + download reliability + tuned extraction"
- PR #46 opened `feat/gemma4-litert-extraction` — "feat(056): Gemma 4 E2B extraction via LiteRT-LM (additive/inert, device-gated switchover)" — OPEN/MERGEABLE
- PR #45 opened `fix/audit-high-medium` — "fix(audit): high + medium remediation (recording-cap, delete-orphan, save-safety, focus, sleep, regenerate)" — OPEN/MERGEABLE
- PR #44 opened `fix/audit-safe-cleanup` — "fix(audit): safe cleanup (dead code, debug gating, RC-30, privacy logs)" — OPEN/MERGEABLE
- PR #43 opened `docs/codebase-audit-2026-09` — "docs(audit): full codebase audit of main @ 2553e251" — OPEN/MERGEABLE
- PR #42 opened `feat/speech-transcriber-probe` — "feat(045): SpeechAnalyzer migration — plan + tasks + additive engine (REVIEW ONLY, do not merge)" — OPEN/MERGEABLE
- PR #41 opened `fix/restore-debug-menu` — "fix(settings): restore the 5-tap debug console" — OPEN/MERGEABLE
- PR #40 opened `chore/tuning-2026-08-18-b` — "feat(043): sync tuning 2026-08-18-b from macOS harness" — MERGED/CONFLICTING
- PR #39 opened `feat/043-mlx-journal-service` — "feat(043/044): on-device MLX journal pipeline + download reliability + tuned extraction" — MERGED/UNKNOWN

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                                                 074bb264 [docs/llm-fsd-alignment]
/private/tmp/claude-501/-Users-caesargrey-Projects-app-four/7f435f5e-2d88-4eca-a724-fc844837b1dd/scratchpad/main-wt 93c342e9 [main]
/private/tmp/claude-501/-Users-caesargrey-Projects-app-four/9b2edc5e-33b2-475c-b128-3fa4ef03a52c/scratchpad/qa-wt   05ee8e38 [fix/audit-high-medium]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                                               9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                                                   965dcf22 [feat/037-live-activity-controls]
/Users/caesargrey/Projects/app-four/.claude/worktrees/054-settings-topic-hub                                        4d1a3e88 [feat/054-settings-topic-hub]
/Users/caesargrey/Projects/app-four/.claude/worktrees/055-rc-foundation                                             9564e392 [feat/055-revenuecat]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals                                        5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/remove-nlp                                                    73e8a091 [chore/remove-dead-nlp]
/Users/caesargrey/Projects/app-four/.claude/worktrees/speech-transcriber-probe                                      d5d7dc31 [feat/gemma4-litert-extraction]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ui-refresh                                                    2553e251 [feat/ui-refresh]
```

---

## 2026-07-16 20:56–20:58 · DEVLOG/BACKLOG for capture-green + whisper toggle (81ce578c) · main

**Code changes**
- _Major (feat)_
  - `81ce578c` feat: unify capture-flow green (#5FB36E) + whisper install toggle
- _docs_
  - `c2322336` docs: DEVLOG/BACKLOG for capture-green + whisper toggle (81ce578c)

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                          c2322336 [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                      575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                      a490bbab [feat/036-newlook-checkin-insights]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents        9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4            f96bf1f1 [feat/037-live-activity-controls]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals 5db316a6 [feat/healthkit-signals]
```

---

## 2026-07-10 14:43 – 2026-07-16 19:46 · Merge feat/033-036: app-wide New Look migration, DayCard a01 · main

**Code changes**
- _Major (feat)_
  - `0fc4a3b0` feat(036): US2 — Insights a07: continuous scroll, carded sections, dead path deleted
  - `c5b8a748` feat(036): US1 — check-in a04-a06 re-skin + selectionSoft token + gauge level RED->GREEN
  - `cfc24983` feat(035): T004-T010 — strip scrolls + fades in-content; compact title cross-fade
  - `493bb3cf` feat(035): T002-T003 RED->GREEN — CalendarStripFade pure math + contract suite
  - `dbfa0bf3` feat(034): DayCard a01 redesign — folded chip summary + unfolded mood-disc rows
  - `ef94c869` feat(033): resolve T043/T044 owner decisions + sleepIndigo dark-mode AA
  - `8fde5caf` feat(033): app-wide New Look migration + medication-bar a01 redesign
  - `300ea271` feat(032): US2 GREEN — a02 Recording detail re-skin (T017-T021)
  - `0a15e400` feat(032): US1 GREEN — a03 Edit check-in re-skin (T009-T015)
  - `77533049` feat(032): US0 — NewLook token set + card/chip/nav grammar (T002-T008)
- _Fixes_
  - `a490bbab` fix(036): review round — kill double insets inside cards; delete orphaned CalendarDay
  - `027f67c5` fix(036): add level: to the SignalAverageGauges #Preview constructors missed by T003
  - `78df923f` fix(035): review round — strip fades out by titleReveal; harden quantization test
  - `90dce2f1` fix(035): title band below the med bar; restore the bar's app-wide position
  - `c3481b88` fix(034): address code-review findings — headline fallback, locale-aware a11y time, drop dead truncatable flag
  - `bfaeb754` fix(033): contrast ruling — fix derived dark-mode failures, log Figma-locked light values
  - `ac6d5976` fix(033): address code-review findings — mechanical set (6 of 12)
- _docs_
  - `ed126440` docs: regen WORKLOG after App Store readiness round (derived from git/gh)
  - `58b5a374` docs(036): quickstart QA guide, tasks T001-T012 checked, DEVLOG/BACKLOG/WORKLOG
  - `7511e3ad` docs: 035 code-complete checkpoint — DEVLOG/BACKLOG/WORKLOG + restored parallel-session entries
  - `198eec24` docs: DEVLOG checkpoint + WORKLOG block for the #28 review cycle
  - `4004719e` docs(033): record commit+rebase onto main; iOS 26 reconciliation
  - `50fd573b` docs(032): mark T002-T021 complete (code); T001/T007/T016/T022 = owner device gates
- _chore_
  - `be7ec5b2` chore(docs): add What/Why/How/Next-Action closing block to project CLAUDE.md
- _other_
  - `432525e9` Merge feat/033-036: app-wide New Look migration, DayCard a01, calendar scroll-collapse, check-in/Insights a04-a07 re-skin
  - `0420164d` spec+plan+tasks: 036 New Look check-in (a04-a06) + insights (a07) re-skin
  - `710545ab` tasks: 035 calendar scroll-collapse — 14 tasks, merge-gate -> RED/GREEN math -> US1 restructure+fade -> US2 title -> owner QA
  - `c10817a4` plan: 035 calendar scroll-collapse — research (D1-D9), plan, data-model, behavior contract, quickstart
  - `fe5ddd98` spec: 035 calendar strip scroll-collapse & fade — Tiimo pattern, supersedes 001
  - `15855acd` spec: 034 DayCard a01 redesign — folded 24pt word + chip summary w/ sleep; unfolded caps band + mood-disc rows, bead/ring dropped
  - `82da5059` analyze: 032 cross-artifact audit (3 Opus agents) — resolve 11 findings
  - `9c04a31d` tasks: 032 New Look screens — 28 tasks, US0 tokens -> US1 a03 -> US2 a02, US3 gated
  - `ac99df28` plan: 032 New Look screens — research (D1-D5), plan, data-model, contract, quickstart
  - `742635a0` spec: 032 New Look screens — a03 Edit check-in + a02 Recording Detail re-skin (a01 gated on 029); clarified dark-derive + mixed-look ship

**Git actions**
- `432525e9` Merge feat/033-036: app-wide New Look migration, DayCard a01, calendar scroll-collapse, check-in/Insights a04-a07 re-skin

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                                                    c713ba62 [fix/app-store-readiness]
/private/tmp/claude-501/-Users-caesargrey-Projects-app-four/f4c955f9-a44b-4930-8e07-c4c8116a8635/scratchpad/main-merge 432525e9 [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                                                                575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                                                                a490bbab [feat/036-newlook-checkin-insights]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                                                  9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                                                      83b95975 [feat/037-live-activity-controls]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals                                           5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation                                   8d9b7ab8 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                                                     d04eb5ea [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                                                        885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-10 15:42 – 2026-07-16 19:24 · App Store readiness — audit findings, submission playbook, p · main

**Code changes**
- _docs_
  - `7e4c9ed3` docs: App Store readiness — audit findings, submission playbook, privacy-policy draft
  - `d29c177b` docs: regen WORKLOG after debt-reconciliation round 2
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
- PR #33 opened `feat/036-newlook-checkin-insights` — "feat(036): New Look check-in (a04-a06) + Insights a07 re-skin" — OPEN/MERGEABLE
- PR #32 opened `feat/035-calendar-scroll-collapse` — "feat(035): calendar strip scroll-collapse & fade — Tiimo pattern" — OPEN/MERGEABLE
- PR #31 opened `feat/034-daycard-a01` — "feat(034): DayCard a01 redesign — folded chip summary + unfolded mood-disc rows" — OPEN/MERGEABLE
- PR #30 opened `chore/swift6-tech-debt` — "chore: clear Swift-6-language-mode test warnings + med color token" — OPEN/MERGEABLE
- PR #29 opened `feat/030-us3-us4` — "feat(030): US4 guided NFC sticker setup (StickerSetupView) + FR-005 amendment" — OPEN/CONFLICTING

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  7e4c9ed3 [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              a490bbab [feat/036-newlook-checkin-insights]
## 2026-07-16 16:23–18:54 · US2 — Insights a07: continuous scroll, carded sections, dead · feat/036-newlook-checkin-insights

**Code changes**
- _Major (feat)_
  - `6810220e` feat(036): US2 — Insights a07: continuous scroll, carded sections, dead path deleted
  - `4c3b7366` feat(036): US1 — check-in a04-a06 re-skin + selectionSoft token + gauge level RED->GREEN
- _Fixes_
  - `90dce2f1` fix(035): title band below the med bar; restore the bar's app-wide position
- _docs_
  - `7511e3ad` docs: 035 code-complete checkpoint — DEVLOG/BACKLOG/WORKLOG + restored parallel-session entries
- _other_
  - `570f483b` spec+plan+tasks: 036 New Look check-in (a04-a06) + insights (a07) re-skin

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  5d6f0056 [fix/app-store-readiness]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              6810220e [feat/036-newlook-checkin-insights]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                    9843f17a [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 8d9b7ab8 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   d04eb5ea [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-15 23:41 – 2026-07-16 16:16 · T004-T010 — strip scrolls + fades in-content; compact title  · feat/035-calendar-scroll-collapse

**Code changes**
- _Major (feat)_
  - `cfc24983` feat(035): T004-T010 — strip scrolls + fades in-content; compact title cross-fade
  - `493bb3cf` feat(035): T002-T003 RED->GREEN — CalendarStripFade pure math + contract suite
  - `dbfa0bf3` feat(034): DayCard a01 redesign — folded chip summary + unfolded mood-disc rows
- _Fixes_
  - `c3481b88` fix(034): address code-review findings — headline fallback, locale-aware a11y time, drop dead truncatable flag
  - `bfaeb754` fix(033): contrast ruling — fix derived dark-mode failures, log Figma-locked light values
  - `ac6d5976` fix(033): address code-review findings — mechanical set (6 of 12)
- _docs_
  - `198eec24` docs: DEVLOG checkpoint + WORKLOG block for the #28 review cycle
- _other_
  - `710545ab` tasks: 035 calendar scroll-collapse — 14 tasks, merge-gate -> RED/GREEN math -> US1 restructure+fade -> US2 title -> owner QA
  - `c10817a4` plan: 035 calendar scroll-collapse — research (D1-D9), plan, data-model, behavior contract, quickstart
  - `fe5ddd98` spec: 035 calendar strip scroll-collapse & fade — Tiimo pattern, supersedes 001
  - `15855acd` spec: 034 DayCard a01 redesign — folded 24pt word + chip summary w/ sleep; unfolded caps band + mood-disc rows, bead/ring dropped

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  cfc24983 [feat/035-calendar-scroll-collapse]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              c3481b88 [feat/034-daycard-a01]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                    9843f17a [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 8d9b7ab8 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   d04eb5ea [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-10 15:42 – 2026-07-16 00:45 · contrast ruling — fix derived dark-mode failures, log Figma- · feat/033-newlook-app-wide

**Code changes**
- _Major (feat)_
  - `ef94c869` feat(033): resolve T043/T044 owner decisions + sleepIndigo dark-mode AA
  - `8fde5caf` feat(033): app-wide New Look migration + medication-bar a01 redesign
  - `300ea271` feat(032): US2 GREEN — a02 Recording detail re-skin (T017-T021)
  - `0a15e400` feat(032): US1 GREEN — a03 Edit check-in re-skin (T009-T015)
  - `77533049` feat(032): US0 — NewLook token set + card/chip/nav grammar (T002-T008)
- _Fixes_
  - `bfaeb754` fix(033): contrast ruling — fix derived dark-mode failures, log Figma-locked light values
  - `ac6d5976` fix(033): address code-review findings — mechanical set (6 of 12)
- _docs_
  - `4004719e` docs(033): record commit+rebase onto main; iOS 26 reconciliation
  - `50fd573b` docs(032): mark T002-T021 complete (code); T001/T007/T016/T022 = owner device gates
  - `d29c177b` docs: regen WORKLOG after debt-reconciliation round 2
  - `a65010de` docs: reconcile stashes/PRs/worktrees debt (round 2) — DEBT.md + DEVLOG + BACKLOG
  - `f1dfcf54` docs: regen WORKLOG after 2026-07-14 hygiene pass (derived from git/gh)
- _chore_
  - `be7ec5b2` chore(docs): add What/Why/How/Next-Action closing block to project CLAUDE.md
  - `23dc5180` chore: repo-hygiene pass — remove stray artifact, gitignore model dump, doc debt registry
- _other_
  - `82da5059` analyze: 032 cross-artifact audit (3 Opus agents) — resolve 11 findings
  - `9c04a31d` tasks: 032 New Look screens — 28 tasks, US0 tokens -> US1 a03 -> US2 a02, US3 gated
  - `ac99df28` plan: 032 New Look screens — research (D1-D5), plan, data-model, contract, quickstart
  - `742635a0` spec: 032 New Look screens — a03 Edit check-in + a02 Recording Detail re-skin (a01 gated on 029); clarified dark-derive + mixed-look ship
  - `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
  - `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**Git actions**
- `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
- `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**gh actions**
- PR #31 opened `feat/034-daycard-a01` — "feat(034): DayCard a01 redesign — folded chip summary + unfolded mood-disc rows" — OPEN/MERGEABLE
- PR #30 opened `chore/swift6-tech-debt` — "chore: clear Swift-6-language-mode test warnings + med color token" — OPEN/MERGEABLE
- PR #29 opened `feat/030-us3-us4` — "feat(030): US4 guided NFC sticker setup (StickerSetupView) + FR-005 amendment" — OPEN/CONFLICTING

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  d29c177b [main]
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              575d8902 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              bfaeb754 [feat/033-newlook-app-wide]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                9e98adab [chore/swift6-tech-debt]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-us3-us4                    9843f17a [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 8d9b7ab8 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   d04eb5ea [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---
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

## 2026-07-13 17:33–17:47 · US4 review findings — Palette.medication, stable identity, . · feat/030-us3-us4

**Code changes**
- _Fixes_
  - `6b3ebada` fix(030): US4 review findings — Palette.medication, stable identity, .card(), Dynamic Type, honest check-in copy
- _docs_
  - `7d8b5176` docs(030): regenerate WORKLOG after US4 build + FR-005 amendment
  - `57f21f72` docs(030): FR-005 haptic amendment (T037) + BACKLOG/DEVLOG for US1-US4

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  bb62dd4f [feat/nutrition-signals-demo]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              f019e64e [feat/034-daycard-a01]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                6b3ebada [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
/Users/caesargrey/Projects/app-four/.claude/worktrees/fix+022-view-audit-remediation 08e16e53 [fix/022-view-audit-remediation]
/Users/caesargrey/Projects/app-four/.claude/worktrees/ios26-target                   b6f5149d [qa/device-ios26-029]
/Users/caesargrey/Projects/app-four/.claude/worktrees/merge-029                      885961a9 [feat/029-calendar-day-context]
```

---

## 2026-07-10 15:42 – 2026-07-13 17:33 · FR-005 haptic amendment (T037) + BACKLOG/DEVLOG for US1-US4 · feat/030-us3-us4

**Code changes**
- _Major (feat)_
  - `3317355c` feat(030): US4 StickerSetupView guided walkthrough + Settings entry (T035)
  - `db39ed5c` feat(030): US2 hands-free check-in — StartCheckInIntent + FR-022 onboarding gate (T024–T028)
- _Fixes_
  - `c8442057` fix(030): compile ConfirmationCopyTests — key-path closure trips #expect throws analysis
  - `e0ea1cc3` fix(030): mark MedicationCatalog nonisolated — pure static reference data
- _Tests_
  - `cfda413d` test(030): fix Swift 6 'mutated after capture' warning in gateIsReevaluatedPerCall
  - `66a0a40b` test(030): cover two reachable service states the pre-merge review flagged
- _docs_
  - `57f21f72` docs(030): FR-005 haptic amendment (T037) + BACKLOG/DEVLOG for US1-US4
  - `9e8eb1c4` docs(030): DEVLOG US1-intent-layer entry + WORKLOG regen
- _chore_
  - `3661a007` chore(030): remove 6 dead PBXGroups + wire test plan so ⌘U runs the suite
- _other_
  - `4b8d7573` mockup(030): US4 'Set up your sticker' guided walkthrough (T034 gate)
  - `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
  - `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**Git actions**
- `81435937` Merge pull request #26 from caesar915-hub/feat/030-app-intents
- `2e52eb66` Merge pull request #25 from caesar915-hub/feat/ios26-target

**gh actions**
- PR #26 merged `feat/030-app-intents` — "feat(030): App Intents foundation — router, dose-logging engine, Settings surface"
- PR #28 opened `feat/033-newlook-app-wide` — "feat(033): app-wide New Look migration + medication-bar a01 redesign" — OPEN/UNKNOWN

**Worktrees**
```
/Users/caesargrey/Projects/app-four                                                  bb62dd4f [feat/nutrition-signals-demo]
/Users/caesargrey/Projects/app-four-localization                                     18c3cdd4 [feat/023-localization-multilang]
/Users/caesargrey/Projects/app-four-nlp-recall                                       29af639f (detached HEAD)
/Users/caesargrey/Projects/app-four-nlp-recall-emotions                              55201477 [fix/nlp-english-recall-on-emotions]
/Users/caesargrey/Projects/app-four-spm                                              f019e64e [feat/034-daycard-a01]
/Users/caesargrey/Projects/app-four/.claude/worktrees/030-app-intents                57f21f72 [feat/030-us3-us4]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+healthkit-signals         5db316a6 [feat/healthkit-signals]
/Users/caesargrey/Projects/app-four/.claude/worktrees/feat+weather-checkin           ca0f81fc [worktree-feat+weather-checkin]
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
