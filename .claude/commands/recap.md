---
description: Morning standup — recap project progress since the last recap and write a dated entry to DEVLOG.md
allowed-tools: Bash(git log:*), Bash(git branch:*), Bash(git status:*), Bash(git for-each-ref:*), Bash(git rev-list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(date:*), Read, Edit
---

You are running the daily morning recap. It's a standup, not a report — but a thorough one: cover every section below, each item as **one tight line**. Lead with signal; flag anything stale, drifted, or at-risk. Don't pad.

## 1. Gather state

- Today's date: run `date +%F`.
- Read [docs/DEVLOG.md](../../docs/DEVLOG.md) and find the most recent `**Recap**` entry; note its date (the "since" point). If none exists, use the top day section's date, else the last few commits.
- Read [docs/BACKLOG.md](../../docs/BACKLOG.md): note each item's stage, and — if present — the 🎯 Milestones gates and 🚢 Ship-checklist items. **Reconcile against reality:** if an item is shown unshipped but its commits are already on `main`, call out the drift.
- Commits since: `git log --date=short --pretty=format:'%ad %h %s' --since=<since-date>`.
- Branches with dates: `git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:short) %(upstream:track) %(subject)'`.
- Merged/defunct branches (cleanup candidates): `git branch --merged main` (exclude `main`).
- Unpushed work: `git rev-list --count origin/main..main`.
- Open PRs: `gh pr list --state open --json number,title,headRefName,createdAt,isDraft`; for build/test state per PR, `gh pr checks <n>`. If `gh` fails, skip the PR/checks lines silently.

## 2. Speak the standup

Group under these headers, **one line per item**, newest/most-important first. No preamble.

- **Since <last-recap-date>** — what shipped/landed (commits + BACKLOG stage changes). Note if `main` is ahead of `origin` (unpushed).
- **Open PRs** — for each: `#N title — <age> · <checks: ✓/✗/none> · <what it does in ~6 words> · <merge blocker, if any>`.
- **Branches** — count of stale/merged-but-undeleted branches + name the notable ones to delete; flag any feature branch that's been unmerged long enough to risk conflicts.
- **Build/test health** — last-known build + test status per in-flight branch, drawn from DEVLOG/BACKLOG notes, commit messages, or recorded results. **Do not run a build or tests during the recap** (too slow for a standup) — flag any branch with no recorded verification, and note I can ask for a live check.
- **Milestones** — if the BACKLOG defines them: burn-down on the current focus milestone — gates met vs remaining, days until its TestFlight/release date, the single biggest risk to that date, and any still-open 🚢 Ship-checklist items it depends on.
- **Open decisions** — unresolved `Open` items from the DevLog + anything stuck in BACKLOG; one-line recommendation each.
- **Today — prioritized actions** — a short *ranked* to-do list (not one focus), each with a one-line why. Push back hard if the top looks stale or mis-prioritised against the nearest milestone.

Then ask: **"What do you want to tackle today?"**

## 3. Write the recap entry

Add a single `**Recap**` bullet at the **top** of today's `## <YYYY-MM-DD>` section in [docs/DEVLOG.md](../../docs/DEVLOG.md). Create the `## <today>` section above the previous day if it doesn't exist yet. Format:

```
- **Recap** — Since <last-date>: <shipped>; in flight: <branches/PRs>; open: <decisions>; today: <focus>.
```

Keep it to one line. Do not duplicate detail that belongs in BACKLOG or specs — link instead.
