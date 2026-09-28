---
description: Evening wrap for the September Shipaton sprint — log the day's why, move backlog stages, re-plan tomorrow, and flag slippage against the release train.
allowed-tools: Bash(git log:*), Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git rev-list:*), Bash(gh pr list:*), Bash(date:*), Read, Edit
---

You are running the **evening wrap** for the September 2026 Shipaton sprint. Close the day honestly: what actually happened, why it happened that way, and what tomorrow looks like given the deadline. Keep the whole thing tight — the ceremony must not compete with the building.

**Do NOT run a build or the test suite** unless the day's work is unverified *and* the user asks. Report recorded status instead.

## 1. Gather the day

- Now: `date "+%Y-%m-%d %H:%M %Z"`.
- Today's commits: `git log --since="today 00:00" --pretty=format:'%h %ad %s' --date=format:'%H:%M'`.
- Uncommitted state: `git status --porcelain`. Unpushed: `git rev-list --count origin/main..main`.
- Read the `## Today` block in [SEPTEMBER_PLAN.md](../../shipaton_plan/SEPTEMBER_PLAN.md) — this morning's ranked plan.
- Read [shipaton_plan/BACKLOG.md](../../shipaton_plan/BACKLOG.md) for current stages.

## 2. Judge the day

Compare what was planned against what happened. Be factual, not generous:

- Which of this morning's ranked items are **done**, **partial**, or **untouched**?
- What was done that **wasn't** planned, and was it worth it?
- What is **blocked**, and on whom?
- Did anything **slip** against the release train? Recompute days to the next gate, to the last safe submission (~Sep 23), and to Devpost close (Sep 30).

If the train is slipping, say so in the first line of your report and propose what to cut — do not bury it.

## 3. Write the record

**a. One DEVLOG entry.** Append to today's `## YYYY-MM-DD` section in [shipaton_plan/DEVLOG.md](../../shipaton_plan/DEVLOG.md) (create the section at the top if needed). **Exactly one entry** — the *why*, not every edit:

```
- **[HH:MM TZ] Evening — <headline>.** _what:_ <what actually landed, with ticket IDs>. _why:_ <the reasoning or decision behind it>. _open:_ <what's unresolved>.
```

Use a more specific type than `Evening` when the day earned one — `Decision`, `Shipped`, `Investigation`, `Direction`, `Open`.

**b. Move backlog rows.** In [shipaton_plan/BACKLOG.md](../../shipaton_plan/BACKLOG.md), move any ticket whose stage changed, and prepend **one** row to the changelog table:

```
| YYYY-MM-DD HH:MM | RC-18 → ✅ Shipped; RC-24 → 🔨 In code |
```

Keep the changelog to its most recent **15 rows** — drop older ones; the devlog holds the narrative. Never let this table grow into a run-on paragraph.

**c. Re-plan tomorrow.** Rewrite the `## Today` block in SEPTEMBER_PLAN.md as tomorrow's ranked list, and update any ticket estimates that today proved wrong.

**d. Bump the `Updated:` stamp** on every file touched.

## 4. Report

Ten lines maximum:

- One line on whether the train is on schedule (lead with slippage if any).
- Done / partial / untouched against this morning's plan.
- Ticket stage changes made.
- What's blocked and on whom.
- Tomorrow's top item.

**Never edit `docs/BACKLOG.md` or `docs/DEVLOG.md`** — both are frozen for the sprint.
