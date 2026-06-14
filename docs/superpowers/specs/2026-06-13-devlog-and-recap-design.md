# DEVLOG + `/recap` — design

**Date:** 2026-06-13
**Status:** Approved, building
**Type:** Dev-process tooling (not an app feature)

## Problem

The project has three documentation artifacts, none of which is a chronological narrative:

- **BACKLOG.md** — forward-looking *state*: what stage each item is at.
- **specs/ + plans/** — deep *design records* per feature.
- **memory/** — cross-session *facts*, one per file.

What's missing is a backward-looking, read-it-top-to-bottom narrative — "on June 13 we decided X because Y, investigated Z, ruled out W" — and a morning-standup surface that reads from it. Git has the *what*; nothing captures the *why* in a single timeline.

## Goal

A **manual** daily-recap ritual (generated on demand when the user sits down — no automation), backed by a single living devlog.

## Design

### A. The artifact — `docs/DEVLOG.md`

One file, reverse-chronological (newest day on top). Each day is a `##` section containing terse typed bullets. It records *why / what-happened* and **links** to BACKLOG / specs / branches — it never restates them.

Entry-type vocabulary (exactly five, no more):

- **Recap** — written by `/recap`; the morning standup snapshot.
- **Decision** — a choice made, with `*why:*` rationale.
- **Investigation** — a question explored, with its outcome.
- **Direction** — a product/design direction note.
- **Shipped** — an item merged/completed (commit / PR).
- **Open** — an unresolved question or pending decision.

Format example:

```markdown
## 2026-06-13

- **Recap** — Since 06-12: shipped …; in flight: …; open: …; today: …
- **Decision** — removed live transcription from check-in · *why:* AVAudioEngine tap muted the recorder · branch `fix/checkin-remove-live-transcription`
- **Investigation** — NLContextualEmbedding on-device? → E5 won't compile on sim; Gate-0 spike decides go/no-go → [spec](2026-06-13-tag-suggestion-design.md)
- **Direction** — calendar collapses week↔month over the mood/med timeline (locked N1)
- **Open** — Insights "Meadow" palette still unresolved
```

### B. The ritual — `.claude/commands/recap.md`

A custom slash command (always explicitly invoked, so no skill description-matching needed). Running `/recap`:

1. **Reads** `git log` since the last `**Recap**` entry's date, current branches + open PRs, BACKLOG deltas, and the devlog tail.
2. **Speaks** a standup: since-last-time → shipped / in flight / open decisions → *suggested* focus, then asks what to tackle today.
3. **Writes** a dated `**Recap**` bullet at the top of today's `##` section (creating the section if absent).

**Robustness property:** step 1 reconstructs from git + BACKLOG, so the recap still works even when devlog entries were missed. The devlog adds rationale on top; git + BACKLOG are the fallback source of truth. This is what keeps the devlog from rotting into a write-only file.

### C. Maintenance + seeding

- Claude appends a bullet at *real checkpoints* — a decision made, an investigation concluded, a direction set, an item shipped — not on every edit.
- One line added to `CLAUDE.md` → Process section makes the habit durable.
- DEVLOG.md is **seeded** on creation with a `## 2026-06-13` entry reconstructing current state from BACKLOG + recent commits + memory, so the first `/recap` has history to read.

## Decisions locked

- Filename `DEVLOG.md` (matches `BACKLOG.md` casing).
- `/recap` ends by asking the user's focus → a real standup, not a readout.
- No Telegram/push notification — it's a manual ritual; push is out of scope (trivial to add later via existing `telegram_notify.py`).
- `/recap` is a command file, not a skill.

## Out of scope

- Automated/scheduled recap (cron, push notifications).
- Any app-facing feature (this is purely a dev-process change).
- Migrating existing specs/plans/memory into the devlog.
