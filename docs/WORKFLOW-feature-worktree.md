# Workflow: cross-machine, worktree-isolated, Spec-Kit features

A repeatable process for building a feature on app-four across two machines without entangling
other work. Runnable as a slash command: **`/new-feature <one-line description>`** (defined in
[.claude/commands/new-feature.md](../.claude/commands/new-feature.md)), or paste the steps below.

## Why this shape

- **Only `origin` crosses machines.** Pushed branches + repo-committed docs travel; **worktrees,
  uncommitted changes, and `~/.claude/` do not.** So the plan/spec must live in the repo (`specs/`,
  `docs/`), and work must be committed + pushed before switching machines.
- **Worktrees give isolation, not separate repos.** Every worktree shares one `.git` and the same
  `origin`; a feature branch in its own worktree keeps other branches/WIP untouched and merges back
  cleanly (a separate repo would lose `git merge`). One worktree per feature, per machine.
- **`main` stays releasable.** Merge only via PR + `/code-review`; everything before that is just
  push/pull on the feature branch. To *test* another machine's work you don't merge — you `pull` (or
  `merge` into a scratch worktree) and build.

## The process

### 1. Isolate
- Next feature number N from `specs/`; short kebab name. BASE = `main` unless it needs unmerged code
  (then base off that branch and note the stack).
- `git fetch origin` → `git worktree add ../app-four-<FEATURE> -b feat/<N>-<FEATURE> origin/<BASE>`.
- Baseline `build_sim` green before any change (record pre-existing warnings; `safe.bareRepository`
  lines are non-fatal).

### 2. Spec Kit (into the repo)
- `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` for N. Commit `specs/<N>-…/`. Honor the
  constitution gate — Principle X (logic test-first; views exempt).

### 3. Implement
- P1→P3 priority order; verify-then-edit (re-locate by symbol; worktree is ground truth); test-first
  for logic; `build_sim` + `test_sim` green per story; commit per logical unit (explicit `git add`,
  never `-A`). Stop and report if a story won't go green.

### 4. Cross-machine sync
- Push the branch early/often. Commit (even `wip:`) before switching machines. Other machine:
  `git fetch && git checkout feat/<N>-<FEATURE>` (or `git worktree add`). **`pull` before `push`** on
  the shared branch. First build on a fresh checkout is slow; then incremental (~20–45s here).

### 5. Finish
- PR + `/code-review` (not CodeRabbit). Never merge to `main` unattended. If stacked on a dependency
  branch, flag which PR lands first.

## Quick reference — observed build times on this Mac

| Action | Time |
|---|---|
| Incremental `build_sim` (few files) | ~20–45s |
| Clean Debug build (fresh checkout) | ~80s |
| Release build | ~350s |
| Full `test_sim` (~310 tests) | ~150s |

So: `git pull` into a warm worktree + rebuild = under a minute. The slow build is only the *first*
one on a fresh checkout.
