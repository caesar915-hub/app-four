<!-- Created: 2026-07-14 00:47 WEST · Updated: 2026-08-18 14:10 WEST -->
# app-four Tech-Debt Registry

Makes the *invisible* debt visible — the work that lives outside commits (stashes,
dirty worktrees, untracked bulk) and the git-hygiene state that no code review or
test run ever surfaces. Ground truth is git/gh; regenerate the counts before trusting them.

> The Swift source itself is clean: as of 2026-07-14, `app-four/` + `Packages/` had
> **0** `TODO/FIXME/HACK`, **0** `try!`/`as!`, **2** `fatalError`, and **0** disabled tests
> across 446 test funcs. The debt below is entirely process / git / integration.

---

## 1. Resolved in the 2026-07-14 hygiene pass

**Preservation of at-loss-risk work**
- **304-file design-system SPM extraction** — was uncommitted in the primary working tree.
  Preserved as `feat/spm-designsystem` (`d5a5ccd1`, **pushed**). **But see §2d — it is largely
  redundant: `main` already ships the byte-identical `Packages/` tree.**
- **spec-034 daycard-a01 WIP** — preserved as `feat/034-daycard-a01` (`f13abb5e`, committed
  properly by a concurrent session; my snapshot `8e132555` survives in reflog).
- **3 dirty worktrees snapshotted** on their own branches (verified no concurrent session, clean
  additive edits): `fix/nlp-english-recall-on-emotions` (`575d8902`), `fix/022-view-audit-remediation`
  (`8d9b7ab8`), `qa/device-ios26-029` (`d04eb5ea`). All UNBUILT snapshots.

**Git state**
- local `main` was 26 commits behind `origin/main` — synced (`git branch -f`); the one un-pushed
  local docs commit parked in `backup/main-local-pre-sync`.
- 3 dormant clean worktrees removed (11 → 8) and 4 merged branches deleted.
- stray tracked `Swift-5SCGS38H536W.swiftmodule` removed; `*.swiftmodule` + the 640M
  `spikes/flan-t5-summarizer/` dump gitignored (the dump was untracked **and** unignored).

**Stashes: 17 → 8** (adversarially analysed, one agent per stash)
- **9 removed** — each first archived as a durable `stash-archive/NN-*` tag (recoverable forever
  via `git stash apply <tag-or-sha>`), then dropped. 7 were verified redundant/obsolete; 2 held
  unique work (kept as tags, see below).
- **8 kept** in `git stash list` — all sit on **living** branches with unique, un-applied work
  (owner can `git stash pop` them on the right branch). See §2a.

**PRs**
- **#14** (`feat/nlp-multilang-demo`) **closed** — English core already landed on `main`
  (`7bde98f9`+`8e74e7b0`); only unique remainder is explicitly-demo multilingual packs on a
  superseded base. Reversible: branch + commits persist, reopen anytime.

---

## 2. Open — needs owner triage

_Refreshed 2026-08-18 against live git/gh state. The 2026-07-14 per-item analysis below the
fold is preserved but indices/PR states from that audit are no longer trustworthy._

### 2a. Stashes (12 as of 2026-08-18) — review before applying; do not bulk-delete
Current list (`git stash list`), with base-branch liveness:

| Ref | Base branch | Base alive? |
|-----|-------------|-------------|
| `stash@{0}` | feat/042-health-nutrition-signals (nutrition glyphs) | yes (worktree) |
| `stash@{1}` | feat/042-health-nutrition-signals (manual-entry overrides) | yes |
| `stash@{2}` | feat/rewrite-day-card-averaging — untracked files | branch gone? triage |
| `stash@{3}` | feat/042-health-nutrition-signals (RED test WIP) | yes |
| `stash@{4}` | 002-android-phase1-foundation | yes (Android track) |
| `stash@{5}` | main (WORKLOG regen WIP) | n/a — likely obsolete |
| `stash@{6}` | fix/app-store-readiness | merged long ago — likely obsolete |
| `stash@{7}` | feat/nutrition-signals-demo (docs/009 WIP) | yes, 41 ahead of main |
| `stash@{8}` | feat/029-calendar-day-context | branch not merged; spec 029 still planned |
| `stash@{9}` | feat/spm-designsystem | **branch retired** — stash orphaned |
| `stash@{10}` | feat/nlp-multilang-demo (spec-022 files) | yes, 8 ahead of main |
| `stash@{11}` | feat/ux-improvements-015-017 (NLP WIP) | **branch gone** — stash orphaned |

From the 07-14 analysis, the items flagged as holding unique work were: the filled
`specs/022/plan.md` (≈ stash@{10}), the "feelings"-lineage NLP WIP (≈ stash@{11}), and the
029 `CLAUDE.md` paragraph (≈ stash@{8}). Re-verify with `git stash show -p` before applying —
indices shifted when newer stashes pushed on top.

### 2b. Archived stashes (9 tags) — recoverable, review then `git tag -d` when done
`git stash apply stash-archive/<name>` restores any of these. **2 hold unique work worth acting on:**
- **`stash-archive/04-nav-fix-arch-product-docs`** — real unmerged fixes not in any branch: a SwiftUI
  navigation-warning fix (`InsightsView.swift`, `CalendarLibraryView.swift`), a `fileExists` guard in
  `AIModelServiceImpl`, and full `ARCHITECTURE.md` + product `README.md` rewrites. **Worth applying** in
  a buildable env.
- **`stash-archive/14-intra-entry-emotional-arc-idea`** — its one unique item (the "intra-entry
  emotional arc" product idea) is now captured in BACKLOG §💡 Ideas, so the tag is redundant.

The other 7 (`00,02,06,10,11,15,16`) were verified redundant/obsolete (landed on main, or dead
CoreML-spike wiring referencing the deleted `NLModelExtractor`).

### 2c. PRs — as of 2026-08-18
- **Only open PR: #39** (`feat/043-mlx-journal-service`) — CI green, mergeable.
- Merged since the 07-14 audit: **#28** (033 newlook-app-wide, merged 2026-07-16 — the audit had it as
  DO-NOT-MERGE draft; it merged anyway) and **#29** (030 US4 NFC sticker setup, merged 2026-08-04).
- **Closed unmerged — work survives only on local branches:** #8 `feat/healthkit-signals` (16 ahead),
  #27 `feat/nutrition-signals-demo` (41 ahead), #14 `feat/nlp-multilang-demo` (8 ahead),
  #30 `chore/swift6-tech-debt` (5 ahead).
- **#16 `feat/023-weather-checkin`** — closed unmerged; local branch gone and the remote branch
  was deleted 2026-08-18 (owner call: the feature isn't needed). Sole remaining trace is GitHub's
  PR ref (`git fetch origin pull/16/head`) if ever revived.

### 2d. Branches needing owner triage (the real drift debt)
- **Unmerged work, decide per branch (rebase+PR or archive):** `feat/healthkit-signals` (16 ahead),
  `feat/nutrition-signals-demo` (41 ahead), `feat/nlp-multilang-demo` (8 ahead),
  `chore/swift6-tech-debt` (5 ahead, in a worktree).
- **Branches gone locally while BACKLOG listed them as "in code":** `feat/ux-improvements-015-017`
  (onboarding redesign) and `feat/insights-palette` — verify whether their work merged; if not, it is
  unrecoverable locally (check GitHub for PR refs before mourning).
- **Merged branches — deleted 2026-08-18:** `feat/1.1-release-prep`, `feat/030-us3-us4`,
  `feat/hide-handsfree-1.0` (local + remote). `feat/llama-migration-docs` remains (docs-only,
  verify before deleting).
- **RESOLVED:** `feat/spm-designsystem` — retired as recommended; no longer exists locally.

### 2e. Repo hygiene (low)
- `add-google-cloud-ops-agent-repo.sh` (25K, Apache-2.0 Google installer) at repo root, unrelated
  to the app. Relocate/remove if not used by CI.
- ~~`spikes/flan-t5-summarizer/`~~ — **done**; no longer on disk (verified 2026-08-18).
- `docs/BACKLOG.md`'s "Last updated" line is a ~1,000-word paragraph (narrative-as-state); consider
  trimming to a real table. Two backlogs coexist (`docs/BACKLOG.md` 66K + `UX_UI_BACKLOG.md` 5K).
- Root-level one-shot scripts accumulate (`add_huggingface.rb`, `add_yams.rb`, `fix_packaging.rb`) —
  harmless, but consider a `scripts/` sweep next cleanup pass.

### 2f. Deferred product decisions
- **Re-processing fallback'd check-ins** (surfaced in the PR #39 code review, 2026-08-17) —
  recordings processed before the LLM insights model is installed keep the raw transcript as
  their "summary" forever: the model-missing alert suggests retrying, but no retry path exists
  (`RecordingDetailViewModel.startRegenerate()` is implemented yet has zero call sites).
  Options: (a) manual "Generate insights" affordance on Recording Detail, shown only for
  fallback notes — recommended; new UI surface → HTML-mockup gate (Constitution I) first;
  (b) auto-reprocess on `.aiModelAvailabilityDidChange` — zero user effort but silently
  rewrites note data + a battery/thermal burst at an arbitrary moment; (c) leave as-is.
  **Needs owner product decision, then mockup → spec → implement → device QA.**
