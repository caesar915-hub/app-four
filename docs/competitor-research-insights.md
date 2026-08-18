# Competitor research — Insights & statistics: Daylio vs Bearable

> Researched 2026-08-18 via public web sources (official sites, FAQ/help centers, store listings, Reddit, independent reviews). Purpose: inventory every statistics/insights feature of both competitors, explain how each works, and judge fit for Squirl's Insights screen against PRODUCT.md principles (non-judgmental, deterministic, ADHD low-load, on-device privacy).
> Feeds: `html-mockups/036-insights-evolution-proposal.html` (proposal mockup). Related: `docs/brainstorm-insights.md`, `docs/ux-critique-insights.md`, `docs/archive/daylio-design.md` (visual tokens only, archived).
>
> **Honesty rule:** neither vendor publishes exact formulas. "Not publicly documented" marks behavior observed but not officially specified; nothing below invents internals.

## 1. Daylio — statistics & insights inventory

Scope: stats/charts/insights only (journaling UI excluded). Sources: daylio.net + FAQ knowledge base, App Store / Google Play listings, r/Daylio, 5 independent reviews (15 pages fetched).

| Feature | What it shows | How it works / calculation | Free/Premium | Source |
|---|---|---|---|---|
| Mood chart | Line chart of mood over week/month/year | Plots mood over time; multiple entries/day collapse to an average-mood line. Mood→value mapping not publicly documented | Free | daylio.net, androidpolice.com, moodtrackers.org |
| Average mood | Single mean-mood value for the period | Mean on the ordered 5-point scale (observed); not officially documented | Premium | moodtrackers.org |
| Mood stability | Variability of mood over the period | Not publicly documented | Premium | moodtrackers.org |
| Mood count | Count of each mood + colored ratio bar; per-activity dominant mood | Simple counts/proportions over the interval | Free | daylio.net FAQ, moodtrackers.org |
| Activity count | Count of each activity in the period | Occurrence counts | Free | moodtrackers.org, yourstory.com |
| Year in Pixels | Full-year grid, one mood-colored dot per day | Day colored by mood (day average if multiple entries; aggregation not documented); shareable image | Free (core) | daylio.net, App Store |
| Calendar view | Month calendar with mood-colored days | Same per-day coloring | Free | moodtrackers.org |
| **Advanced Stats** (per mood/activity/group) | Drill-down per mood or activity; groups since v1.39.1; intervals Last 30 days / Last year / All-time | Bundle of the 6 stats below | **Premium** | daylio.net FAQ (premium + activity-and-mood-statistics) |
| ↳ Frequency | Repetitions this period vs previous period, color-coded | Count in interval vs preceding equal interval | Premium | daylio.net FAQ |
| ↳ **Influence on Mood** | How an activity affects wellbeing — their "crown jewel" | Four percentage comparisons: entries **with vs without** the activity; **previous-day**; **same-day**; **next-day** mood. Exact formula not publicly documented | Premium | daylio.net FAQ |
| ↳ **Confidence gating** | Low / Medium / High label on Influence on Mood | "How much we believe the number is correct"; High requires many occurrences in different combinations **and** enough entries *without* the activity. Thresholds not publicly documented | Premium | daylio.net FAQ |
| ↳ Longest period | Longest run with vs without the activity/mood | Longest consecutive-day streaks each way | Premium | daylio.net FAQ |
| ↳ Occurrence during week | Bar chart of counts per weekday (Mon–Sun) | Counts per day of week | Premium | daylio.net FAQ |
| ↳ Related activities ("usually together") | Co-occurring activities as percentages | Co-occurrence %; users measured it as **symmetric** (A→B = B→A), not conditional probability | Premium | daylio.net FAQ, r/Daylio |
| Entry streak | Consecutive days with an entry | Day count, resets on miss; powers "Mighty Streak" achievements | Free | yourstory.com, r/Daylio |
| Achievements | Unlockable badges in Stats hub | Milestone triggers, incl. *Emotional Tornado* (all 5 moods in 1 day), *Zero to Hero* (awful→rad day), ***Suspiciously Sad* (5 sad days in a row)**, ***Astronomically Awful* (3 awful days)**, *Busy Bee*, *Word Wiz*, 10,000-day streak, etc. | Free | r/Daylio |
| Goals + goal stats | Habit goals (daily/weekly/monthly) with Level, Current Streak, Longest Streak, Success Rate, Completions | **Level never decreases**; weekly goals don't care *which* days; success rate = % completions per week & per 4 weeks with trend vs prior period; retroactive start dates pre-fill stats | Limited free / unlimited Premium | daylio.net FAQ (setting-up-goals) |
| Goal challenges | Pre-built suggested goals | Template goals + reminders ("87% more successful" — vendor claim) | Free (limited) | daylio.net FAQ |
| Monthly / weekly report | Auto digest "with all important insights", push when ready (v1.38.0+) | Contents thin: mostly averages; charts only in (Premium) PDF export. Full spec not publicly documented | In-app unclear; PDF **Premium** | r/Daylio, daylio.net FAQ |
| Stats sharing | Share charts / Year in Pixels as image | Image export | Free | daylio.net |
| Export CSV / PDF | Full entry export | CSV raw rows; PDF formatted report | CSV free / PDF Premium | choosingtherapy.com, daylio.net FAQ |
| On This Day | Entries from this date in prior years (v1.74.5) | Date-matched lookup | Not documented | App Store |
| Scales stats | New slider trackers (sleep, stress, energy, pain) with graphs + report averages | Weekly/monthly averages in reports; in-app charts thin per users | Not documented (2025–26 rollout) | apk.gold changelog, r/Daylio |
| Media/photo count | — | **Not found in any public documentation — unverified** | — | — |

**Cross-cutting:** stats are interval-scoped (week/month/year; advanced stats: 30d/1y/all-time). Common user complaints on r/Daylio: hard **calendar-year break** in stats (no contiguous all-time view), in-app reports showing only averages, symmetric related-activity percentages confusing users who expect conditional probability. Data is local-only, no account, optional Drive/iCloud backup — privacy is their marketing cornerstone too.

## 2. Bearable — statistics, correlations & reports inventory

Scope: insights/analytics only. Sources: bearable.app support knowledge base, homepage, App Store listing, hands-on reviews (14 pages fetched).

| Feature | What it shows | How it works / calculation | Free/Premium | Source |
|---|---|---|---|---|
| **Impacts tab (factor effect / correlation reports)** | Automated correlation reports per outcome (Mood, Symptom Score, individual symptoms, Sleep, Energy) and per factor; "% effect", broken down by time of day/week; 1–7 day lagged impact | Compares **average outcome on days with vs without** the factor, expressed as % difference. **Gating: ≥3 days with + ≥3 days without** the factor, plus outcome scores on those days. Exact statistic (test, normalization) **not publicly documented**; no p-values or confidence intervals shown | **Premium** | bearable.app support (how-to-use-premium, how-to-find-correlations) |
| Correlations grid | One factor's correlations across multiple outcomes at once; used to spot confounders / "net positive" factors | Same with/without comparison pivoted across outcomes | **Premium** | bearable.app support (free-vs-premium, correlations-troubleshooting) |
| Comparison graph | Overlay chart: metric (bar/line) vs factor as background gradient on days it occurred | Manual eyeball correlation; rotate phone on Insights tab; 30 days of data | **Free** | bearable.app support |
| Trends tab / reports | Symptom charts over time, symptom prevalence ranking, factor breakdown counts; "better on weekends?" | Aggregations over selected window. Free = past 30 days; Premium = 60/90/365-day + month/quarter/year comparisons | Free 30d / Premium longer | bearable.app support |
| **Weekly report** | Last 7 days vs previous 7 days: avg mood/symptom/sleep/energy + contributing factors | Week-over-week comparison of averages; Premium adds up to 20 metrics (incl. custom ratings) | **Free (basic)** / Premium | bearable.app support, choosingtherapy.com |
| **Health Experiments (n-of-1 A/B tests)** | Structured habit trials; results slideshow: days completed, per-outcome graph, **% change** toggle "with vs without" / "since start vs before", plain-language written explanation | Baseline = ≥3 days pre-tracking or non-completion days; recommends ≥3 completions; up to 8 outcomes; same-day vs next-day toggle; daily reminder. Stats beyond "% change in average" not publicly documented | Limited free / unlimited Premium | bearable.app support (health-experiments guide) |
| Favourite Correlations | Pinned factor's impact across many metrics at once | Same engine, curated view | **Premium** | bearable.app support |
| Discoveries tab | Saved/bookmarked correlations; dismiss noise | Manual curation layer | Premium-adjacent | bearable.app support |
| Calendar view | Monthly mood/symptom intensity; can highlight factor days | Heatmap-style aggregation | **Free** | bearable.app support |
| Period/cycle stats | Cycle diagram w/ 4 estimated phases; average length + variation; phases exposed **as correlatable factors** ("+20% symptoms in follicular phase") | Deliberately **no prediction** — next cycle purely from user-set length; ovulation ≈14 days before end; manual confirms override | **Free** (phase correlations Premium) | bearable.app support (period tracking) |
| Health measurements sync | Steps, HR, HRV, resting HR, BP, weight, temperature, sleep — usable as metrics in graphs/reports | Apple Health / Health Connect / Fitbit | Default free / custom Premium | App Store, bearable.app |
| Weather factors | Humidity/pollen/AQI as correlatable factors | **No automatic sync** — manual binary or 3-level factors; docs recommend binary buckets to "see correlations sooner" | **Free** | bearable.app support |
| Custom Ratings | Non-health 1–5 outcomes (Productivity, Motivation, focus…) in reports & correlations | Same correlation pipeline | Defaults **Free** | bearable.app support |
| Goals | Habit goals tied to factors | No streak mechanic documented | Limited free / unlimited Premium | bearable.app support |
| Significant Events | Annotate unusual days (illness…) to explain outliers in correlations | Manual context markers (not stated to auto-exclude from calcs) | **Free** | bearable.app support |
| Data export | Full CSV (3mo/6mo/all-time); screengrab-ready doctor reports | Settings → Data & Security → Export | **Free** | bearable.app support |

**Context:** Premium $34.99/yr list (frequently ~$18.99), "30+ reports" marketing claim. Cloud account required (email signup, encrypted EU servers) — the architectural opposite of Squirl's on-device model. Notably: **no published correlation statistic anywhere** — only the with-vs-without % difference, the 3/3 count gate, and time-period awareness are documented.

## 3. Side-by-side

| Dimension | Daylio | Bearable |
|---|---|---|
| Core stat model | Counts & averages; per-activity influence % (with/without, prev/same/next-day) | With-vs-without % effect per outcome, lagged 1–7 days, time-of-day splits |
| Confidence handling | **Low/Medium/High label** (requires counterfactual days; thresholds undocumented) | Minimum 3/3 days gate only; **no confidence shown on the number** |
| Cadence | Live stats + auto weekly/monthly reports (thin) | Weekly report (last 7 vs prev 7) is the default rhythm |
| Gamification | Heavy: streaks, achievements, goal levels — incl. **badges for consecutive sad/awful days** | Minimal: goals without streaks; experiments instead of badges |
| Correlation literacy | Bare percentages, no causal caveat | In-product education: reverse causation, confounders, grid view, Significant Events |
| Data model | Local-only, no account, free CSV | Cloud account, EU servers, free CSV |
| Paywall | All per-activity influence stats Premium | All automated correlations (Impacts) Premium |
| Known UX complaints | Year-boundary break in stats; reports = averages only; symmetric % confusion | Overwhelming customization → 10-min check-ins; insight paywall resentment |

## 4. Squirl-fit evaluation

Principles applied (PRODUCT.md): no streaks/badges/shame mechanics; deterministic over probabilistic, auditable over opaque; color never the only cue; effortless/low cognitive load; privacy by architecture. Also `docs/ux-critique-insights.md` (denominator honesty; gated-copy consistency).

| Competitor feature | Verdict | Why |
|---|---|---|
| Influence on Mood (with/without %) | **ADAPT** | Strongest insight both apps have. Squirl's connections are co-occurrence-only; a with-vs-without *level difference* is a strict upgrade. Must stay deterministic: plain means + documented denominator |
| Confidence label (Low/Med/High) | **ADAPT** | Rare honesty mechanic. Rebuild deterministically from day counts (with & without), thresholds published in-app — auditable, not Daylio's opaque model |
| Minimum-data gating (Bearable 3/3) | **ALREADY HAVE (stronger)** | Squirl gates at 4 med days / 5 high-energy / 3+3 sleep with explicit unlock copy. Keep; align the "3 or more days" header copy (ux-critique P3) |
| Next-day / lagged effects (1–7d) | **ADAPT (1-day lag only)** | "Poor sleep → next-day mood" is the hangover pattern users care about. 1-day lag stays simple & computable; 7-day lag grid = overload |
| Weekly report (last 7 vs prev 7) | **ADAPT** | Becomes an inline "this week vs your usual" delta row — finally delivers the subtitle's promise honestly. No push-digest PDF |
| Occurrence-per-weekday bars | **ALREADY HAVE (better)** | Squirl's weekday strips show averaged *level* per weekday with glyph encoding, not just counts. Add only the plain-language takeaway (best/hardest weekday) |
| Average mood / mood count | **ALREADY HAVE** | Gauges (mean + between-labels) and bubble chart + legend counts |
| Year in Pixels / mood calendar | **REJECT (redundant)** | Squirl's calendar already tints days; a second color-only year map adds a surface, not knowledge |
| Mood stability | **REJECT (for now)** | Undefined even by Daylio; a variance number invites judgment ("your mood is unstable") — needs careful framing before it's non-judgmental |
| Entry streaks | **REJECT** | Explicit anti-reference (shame mechanic, gets apps deleted). Presence framing instead |
| Achievements | **REJECT (hard)** | Daylio badges *consecutive sad days* — the exact anti-pattern Squirl exists to avoid |
| Goals / goal stats | **REJECT (out of scope)** | Squirl is a journal, not a habit trainer; the forgiving goal design (level never drops, retro-fill) is noted if goals ever enter scope |
| Experiments (n-of-1) | **DEFER** | Genuinely valuable but a feature, not a stat; capture in BACKLOG, not in this mockup |
| Significant Events | **DEFER** | Cheap outlier-annotation; pairs with connections later |
| Symmetric related-activities % | **REJECT** | Confuses users (r/Daylio); conditional directionality or nothing |
| PDF/CSV reports, sharing images | **REJECT (surface)** | Off-device sharing contradicts the privacy posture by default; OS share sheet of a CSV is a separate decision |
| Correlations grid / 30+ reports | **REJECT** | Wall-of-data overwhelm — the ADHD anti-goal. One screen, progressive disclosure |

## 5. Shortlist for the evolution proposal (mockup)

Four additions, all deterministic, all computable from existing `Recording` fields, all gated:

1. **Presence summary line** — "You showed up 17 of 17 days — mostly Good." Replaces streak pressure with presence; fixes the unmet "today vs your usual" promise (ux-critique Thread 2A). *Adapts: Daylio mood count + entry streak, de-shamed.*
2. **This week vs your usual** — per-signal delta chips: mean level last 7 days vs previous 7 days, direction + magnitude, gated at ≥2 check-ins in each window. *Adapts: Bearable weekly report.*
3. **Connection cards v2 — effect + confidence + sample disclosure** — upgrade co-occurrence % to a with-vs-without contrast ("Focus averages 18% higher on medication days"), a deterministic confidence chip (High/Medium/Low from day counts, thresholds shown), and "based on 9 med days vs 8 other days" sample line. *Adapts: Daylio Influence + confidence, Bearable Impacts — with the honesty both lack.*
4. **Next-day connection variant** — sleep×mood recomputed as *next-day* alignment (poor sleep → tomorrow's mood), still gated. *Adapts: Daylio next-day / Bearable same-vs-next-day toggle.*

Plus one micro-addition: **weekday takeaway sentence** under the strips ("Thursdays look brightest · Sundays flattest") — the strips already compute everything it needs. *Adapts: Daylio occurrence-during-week, elevated from bars to language.*

Explicitly NOT in the proposal: streaks, achievements, goals, year-in-pixels, stability score, reports grid, PDF export.
