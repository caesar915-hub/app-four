<!-- Created: 2026-07-14 00:47 WEST · Updated: 2026-07-14 00:47 WEST -->
# app-four Tech-Debt Registry

Makes the *invisible* debt visible — the work that lives outside commits (stashes,
dirty worktrees, untracked bulk) and the git-hygiene state that no code review or
test run ever surfaces. Ground truth is git/gh; regenerate the counts before trusting them.

> The Swift source itself is clean: as of 2026-07-14, `app-four/` + `Packages/` had
> **0** `TODO/FIXME/HACK`, **0** `try!`/`as!`, **2** `fatalError`, and **0** disabled tests
> across 446 test funcs. The debt below is entirely process / git / integration.

---

## 1. Resolved in the 2026-07-14 hygiene pass

- **304-file design-system SPM extraction** — was uncommitted in the primary working
  tree (total loss risk). Preserved as `feat/spm-designsystem` (`d5a5ccd1`, **pushed** to
  origin as off-site backup). UNBUILT; based on the nutrition-demo tip, needs rebase onto
  `main` before a PR. `stash@{0}` is the same work (now redundant).
- **spec-034 daycard-a01 WIP** — was uncommitted in the `../app-four-spm` worktree.
  Preserved as `feat/034-daycard-a01` (`8e132555`, local; push when ready).
- **local `main` was 26 commits behind `origin/main`** — synced (`git branch -f`); the one
  un-pushed local docs commit is parked in `backup/main-local-pre-sync`.
- **3 dormant clean worktrees removed** (`app-four-localization`, `app-four-nlp-recall`,
  `feat+weather-checkin`) and **4 merged branches deleted** (`feat/027-…`, `feat/030-app-intents`,
  `feat/stable-testflight-channel`, `fix/nlp-english-recall`).
- **stray tracked build artifact** `Swift-5SCGS38H536W.swiftmodule` removed; `*.swiftmodule` gitignored.
- **640M `spikes/flan-t5-summarizer/` model dump** was untracked **and not gitignored** (nearly
  got mass-committed) — now gitignored.

---

## 2. Open — needs owner triage

### 2a. Stashes (17) — hidden, fragile, easy to lose
Run `git stash list`; drop each once reconciled (`git stash drop stash@{N}`). Many are anchored
to branch names that **no longer exist** (their commit objects survive, but context is gone).

| Ref | Base | Files | Note |
|-----|------|-------|------|
| `stash@{0}` | feat/nutrition-signals-demo | 304 | **Redundant** — same as preserved `feat/spm-designsystem`; safe to drop after a diff |
| `stash@{1}` | feat/nutrition-signals-demo | 1 | small tracker edit |
| `stash@{2}` | feat/027 | 1 | "stale 027-era BACKLOG.md edit (parked 2026-07-10)" — likely obsolete |
| `stash@{3}` | feat/029 | 6 | Swift-6 isolation fix WIP |
| `stash@{4}` | fix/ios17-compat *(branch gone)* | 7 | ScrollPosition/README fix |
| `stash@{5}` | feat/spm-designsystem | 3 | wip before switching to main |
| `stash@{6}` | feat/calendar-detail-push *(branch gone)* | 36 | large — reversed spec-002 D3 |
| `stash@{7}` | feat/nlp-multilang-demo | 0 | empty diffstat |
| `stash@{8}` | feat/ux-improvements-015-017 | 2 | NLP lexicon + NLNoteExtractor |
| `stash@{9}` | feat/ux-improvements-015-017 | 4 | UI WIP (restore on 019) |
| `stash@{10}` | feat/019-daycard-mood-block *(branch gone)* | 2 | day-card tuning |
| `stash@{11}` | feat/ux-improvements-015-017 | 2 | action-item log |
| `stash@{12}` | spike-nlp-performance | 2 | speckit pointer + skills lock |
| `stash@{13}` | feat/healthkit-signals | 8 | healthkit WIP |
| `stash@{14}` | spike/ml-signal-extractor-DO-NOT-MERGE *(branch gone)* | 4 | docs/pbxproj edits |
| `stash@{15}` | feat/ml-signal-extractor *(branch gone)* | 1 | backlog edit |
| `stash@{16}` | feat/screen-parity *(branch gone)* | 1 | 008 Edit-sheet review fix |

### 2b. Dirty worktrees carrying uncommitted work (NOT touched — need owner context)
- `../app-four-nlp-recall-emotions` — 2 files (`lexicon.json`, `NLNoteExtractor.swift`) on the
  **already-merged** `fix/nlp-english-recall-on-emotions`. `NLNoteExtractor` is a known 3-way
  conflict zone (see memory `nlp-extractor-branch-conflict`) — reconcile deliberately, don't blind-commit.
- `.claude/worktrees/fix+022-view-audit-remediation` — 5 files on the merged `fix/022…`.
- `.claude/worktrees/ios26-target` — 2 files on `qa/device-ios26-029`.

### 2c. Open PRs — 5 of 6 CONFLICTING (`gh pr list --json mergeable`)
Every day `main` advances, these drift further. Rebase-to-land or close; don't leave drifting.
- **#29** `feat/030-us3-us4` — **MERGEABLE** (the one healthy PR; owner device QA pending).
- **#28** `feat/033-newlook-app-wide` — CONFLICTING **draft**.
- **#27** `feat/nutrition-signals-demo` — CONFLICTING.
- **#16** `feat/023-weather-checkin` — CONFLICTING, stale since 2026-06-25.
- **#14** `feat/nlp-multilang-demo` — CONFLICTING, stale since 2026-06-25.
- **#8** `feat/healthkit-signals` — CONFLICTING, "73-behind" per commit `bb62dd4f` ("integration debt").

### 2d. Repo hygiene (low)
- `add-google-cloud-ops-agent-repo.sh` (25K, Apache-2.0 Google installer) sits at repo root,
  unrelated to the app. Left in place — relocate or remove if it's not intentionally used by CI.
- `docs/BACKLOG.md`'s "Last updated" line is a ~1,000-word single paragraph (append-only narrative
  masquerading as state). Consider trimming to a real state table.
- Two backlogs coexist: `docs/BACKLOG.md` (66K) and `UX_UI_BACKLOG.md` (root, 5K).
</content>
</invoke>
