---
description: Morning standup for the September Shipaton sprint — recap progress, compute days to the next gate, set today's ranked focus, and write one line to the sprint devlog.
allowed-tools: Bash(git log:*), Bash(git branch:*), Bash(git status:*), Bash(git for-each-ref:*), Bash(git rev-list:*), Bash(git stash list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(date:*), Read, Edit
---

You are running the **morning standup** for the September 2026 Shipaton sprint. It's a standup, not a report — thorough, but every item **one tight line**. Lead with signal; flag anything stale, drifted, or at-risk. No preamble, no padding.

**Do NOT run a build or the test suite.** Too slow for a standup. Flag anything with no recorded verification and note that a live check can be requested.

## 1. Gather state

- Today's date and time: `date "+%Y-%m-%d %H:%M %Z"`.
- Read [SEPTEMBER_PLAN.md](../../shipaton_plan/SEPTEMBER_PLAN.md) — the release train, the epic/ticket tables, and the current `## Today` block.
- Read [shipaton_plan/DEVLOG.md](../../shipaton_plan/DEVLOG.md); find the most recent entry and note its date (the "since" point). If the file has no entries yet, use the last few commits.
- Read [shipaton_plan/BACKLOG.md](../../shipaton_plan/BACKLOG.md): note each ticket's stage. **Reconcile against reality** — if a ticket shows unshipped but its commits are already on `main`, call out the drift.
- Commits since: `git log --date=short --pretty=format:'%ad %h %s' --since=<since-date>`.
- Branches: `git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:short) %(upstream:track) %(subject)'`.
- Unpushed work: `git rev-list --count origin/main..main`. Parked work: `git stash list`.
- Open PRs: `gh pr list --state open --json number,title,headRefName,createdAt,isDraft`; per-PR checks via `gh pr checks <n>`. If `gh` fails, skip those lines silently.

## 2. Compute the clock

From the release train in SEPTEMBER_PLAN.md, work out and state up front:

- **Days to the next gate** (and which gate it is).
- **Days to the last safe App Store submission (~Sep 23)** — the binding constraint for anything that must be live.
- **Days to Devpost close (Wed Sep 30, 11:45pm PDT).**

If today's plan cannot fit before the next gate, say so plainly and propose what to cut.

## 3. Speak the standup

One line per item, most important first:

- **Since `<last-entry-date>`** — what landed (commits + backlog stage changes). Note if `main` is ahead of `origin`.
- **Clock** — the three numbers from §2, plus one line on whether the train is on schedule.
- **In flight** — branches/PRs: `#N title — <age> · <checks ✓/✗/none> · <what it does in ~6 words> · <blocker if any>`.
- **Blocked** — anything waiting on the owner (account state, approvals, prices, decisions). Name the person-action needed.
- **Drift** — backlog rows that disagree with git reality; stale branches at conflict risk.
- **Today — ranked** — a short ordered list, each with a one-line why. Push back hard if the top item is stale or mis-prioritised against the next gate.

Then ask: **"What do you want to tackle today?"**

## 4. Write the record

1. Rewrite the `## Today` block in [SEPTEMBER_PLAN.md](../../shipaton_plan/SEPTEMBER_PLAN.md) with the ranked list from §3, and bump the file's `Updated:` stamp.
2. Append a **single line** to today's `## YYYY-MM-DD` section in [shipaton_plan/DEVLOG.md](../../shipaton_plan/DEVLOG.md) (create the section at the top if today's doesn't exist yet), and bump its `Updated:` stamp:

```
- **[HH:MM TZ] Recap** — Since <date>: <what landed>; in flight: <branches/PRs>; blocked: <what>; today: <top focus>. <N> days to <next gate>.
```

Keep it to one line. Do not restate what belongs in BACKLOG or the plan — link instead.

**Never edit `docs/BACKLOG.md` or `docs/DEVLOG.md`** — both are frozen for the sprint.
