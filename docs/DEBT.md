<!-- Created: 2026-07-14 00:47 WEST · Updated: 2026-07-14 01:52 WEST -->
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

### 2a. Remaining stashes (8) — all on living branches, unique un-applied work
Keep or pop on the named branch; drop after reconciling. (Indices are post-compaction.)

| Ref | Base branch | Holds |
|-----|-------------|-------|
| `stash@{0}` | feat/nutrition-signals-demo | 1-line tracker edit |
| `stash@{1}` | feat/029-calendar-day-context | unique `CLAUDE.md` DESIGNLOG.md-workflow paragraph (+ mostly-applied pbxproj/scheme) |
| `stash@{2}` | feat/spm-designsystem | unique DEVLOG localization entry (+ stale CLAUDE.md) |
| `stash@{3}` | feat/nlp-multilang-demo | the **filled** `specs/022/plan.md` (main only committed the template stub) |
| `stash@{4}` | feat/ux-improvements-015-017 | "feelings"-lineage NLP WIP (lexicon + NLNoteExtractor weak-tables + sleep-hours heuristic) |
| `stash@{5}` | feat/ux-improvements-015-017 | 4 UI tweaks (meadowGreen tint, Settings title blank, Fraunces date size) |
| `stash@{6}` | spike-nlp-performance | feature.json pointer + skills-lock nlp entry |
| `stash@{7}` | feat/healthkit-signals | menstrual-cycle-disable-for-v1 WIP (product decision) |

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

### 2c. Open PRs (6) — all active workstreams; drift is the risk
Per-PR adversarial analysis: none are abandoned/superseded except the now-closed #14. All are
merge-gated on the repo's device-QA rule, not just conflicts.
- **#30** `chore/swift6-tech-debt` — **MERGEABLE**; gated on code-review + Settings device QA.
- **#29** `feat/030-us3-us4` — conflicts are **docs-only** (regenerated BACKLOG/DEVLOG/WORKLOG);
  zero code conflict. Gated on owner NFC device QA (S21–S24).
- **#28** `feat/033-newlook-app-wide` — sole source of the New Look DS (spec 032/033); explicit
  DO-NOT-MERGE draft. Rebase onto main + work open gates. Drift grows daily.
- **#27** `feat/nutrition-signals-demo` — stacked demo on #8; conflicts inherited from its base.
- **#16** `feat/023-weather-checkin` — complete WeatherKit feature, not on main; has a **spec-number
  collision** (023 reused) and bundles an **un-adopted constitution amendment** softening the on-device
  privacy principle — needs a conscious owner decision. Rebase + renumber, or close.
- **#8** `feat/healthkit-signals` — spec-009 HealthKit, not on main; conflicts limited to 3 non-source
  files (feature.json, Info.plist, DEVLOG). Gated on on-device HealthKit verification.

### 2d. `feat/spm-designsystem` is redundant — retire, do not rebase
`git merge-tree` proof: `origin/main:Packages` and `feat/spm-designsystem:Packages` are the
**byte-identical tree `9c624e8f`** — `main` already landed the SPM extraction, which is why zero
`Packages/` files conflict. The branch is 42 commits on an unmerged nutrition-demo tip; a rebase would
replay them and re-conflict on append-only docs + (dangerously) on `pbxproj`/xcscheme at nearly every
step, all un-buildable/un-QA-able here. **Recommendation:** treat the extraction as shipped and retire
the branch; if any non-DS delta is wanted, cherry-pick just that onto `main` in a buildable environment.

### 2e. Repo hygiene (low)
- `add-google-cloud-ops-agent-repo.sh` (25K, Apache-2.0 Google installer) at repo root, unrelated
  to the app. Relocate/remove if not used by CI.
- `spikes/flan-t5-summarizer/` — 640M now gitignored, still on disk; the ML spike concluded
  non-viable, so `rm -rf` reclaims 640M when you're sure it's unneeded.
- `docs/BACKLOG.md`'s "Last updated" line is a ~1,000-word paragraph (narrative-as-state); consider
  trimming to a real table. Two backlogs coexist (`docs/BACKLOG.md` 66K + `UX_UI_BACKLOG.md` 5K).
