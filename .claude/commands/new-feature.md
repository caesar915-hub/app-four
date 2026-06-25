---
description: Start a new feature with the cross-machine, worktree-isolated, Spec-Kit workflow.
argument-hint: <one-line feature description / requirements>
---

You are starting a new feature: **$ARGUMENTS**

Run this project's standard cross-machine, worktree-isolated, Spec-Kit feature workflow.
Pick the recommended option on any minor decision and state it; only stop to ask on a
destructive/irreversible action or a genuine scope fork.

## 1. Isolate (own branch + worktree, off the right base)
- Derive a short kebab FEATURE name from the description. Pick the next feature number N by
  scanning `specs/` (don't reuse a taken number).
- Resolve the BASE branch: default `main` (clean, releasable). Use a dependency branch only if
  this feature needs code not yet merged; if so, note it is stacked and will rebase onto `main`
  after that PR lands.
- Create an isolated worktree + branch off BASE (never touch other worktrees / WIP):
  - `git fetch origin`
  - `git worktree add ../app-four-<FEATURE> -b feat/<N>-<FEATURE> origin/<BASE>`
  - (Use `git worktree add` with an explicit base when BASE isn't `origin/main`.)
- Baseline: `build_sim` (XcodeBuildMCP) must be green before any change. Record pre-existing
  warnings/failures so later ones are clearly yours. `safe.bareRepository` lines are non-fatal.

## 2. Spec Kit — docs live in the REPO so they travel
- Run `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` for feature N (writes `specs/<N>-…/`
  into the repo). Never leave the plan only in `~/.claude/plans` (machine-local). Honor the
  constitution gate, especially **Principle X**: logic (models / services / view-models / NLP) is
  test-first RED→GREEN; SwiftUI views are exempt (build + sim run). Commit the spec/plan/tasks.

## 3. Implement — verify-then-edit, green per story, commit per unit
- Work P1→P3 in priority order. The worktree code is ground truth: re-locate every change by
  symbol and confirm it still applies before editing (plan/audit line numbers are hints).
- Test-first for logic; `build_sim` + `test_sim` green before each story is "done". If a story
  won't go green, STOP and report — never commit broken work.
- Commit per logical unit (explicit `git add <paths>`, never `-A`). End commit messages with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 4. Cross-machine sync
- Push the branch EARLY and OFTEN (`git push -u origin feat/<N>-<FEATURE>`). Only committed+pushed
  work crosses machines — uncommitted changes, worktrees, and `~/.claude` do NOT. Commit (even
  `wip:`) before switching machines.
- Other machine: `git fetch && git checkout feat/<N>-<FEATURE>` (or `git worktree add`). First build
  there is the slow one (SwiftPM resolves); then incremental. Always `git pull` (or `--rebase`)
  before you `git push` on the shared branch, or you'll hit non-fast-forward rejections.

## 5. Finish — review surface, no surprise merges
- Open a PR; run `/code-review` (NOT CodeRabbit). NEVER merge to `main` unattended — the human
  approves. `main` stays releasable; one PR = one revertable feature. If stacked on a dependency
  branch, flag which PR must land first.
