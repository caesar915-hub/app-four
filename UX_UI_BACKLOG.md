<!-- Created: 2026-06-30 12:07 (WEST) · Updated: 2026-06-30 17:07 (WEST) -->
# UX/UI Backlog — Penpot reproduction gaps

What exists in the shipped Squirl app but is **not** in the 22 Penpot boards ("New File 1": Page 1 Calendar/detail/edit · Check-in 10 · Insights 6). Verified against the actual `app-four/Views/` tree.

## Phase 1 progress (2026-06-30 17:07 WEST) — whole-screen gaps
New page **"Settings & Onboarding"** in "New File 1". Resume bundle + how-to: **[docs/penpot/phase1/RESUME.md](docs/penpot/phase1/RESUME.md)**.
- ✅ **Tab bar** — built, exported, synced (faithful)
- ✅ **Welcome** (Onboarding) — built, exported, synced (faithful)
- ✅ **Day Detail sheet** — built, exported, synced (faithful)
- ⏸️ **Settings (full)** — precomputed (`build_settings.txt` / `mega_build.js`), NOT built — blocked by `execute_code` connection instability
- ⏸️ **ModelDownloadRow states** — precomputed, NOT built (same blocker)
- ⏸️ **Recovery-key sheet** — precomputed, NOT built (same blocker)

Blocker = Penpot MCP `execute_code` reliability (Safari throttling + idle stream death + stale hosted-session needing `/mcp` + 30s-timeout vs slow acks + heavy-call wedge). See DEVLOG 2026-06-30. The 3 unbuilt boards need only a stable channel: open page → fire `mega_build.js` → export.

---

## A. Whole screens not reproduced at all

| Screen | File(s) | Notes |
|---|---|---|
| **Settings (the 4th tab)** | `SettingsView.swift` + `Settings/{DayCardSettingsSection, JournalExportSection, MedicationBarSettingsSection, YourDataSection}.swift` + `ModelDownloadRow.swift` | Entire tab missing — model-download row, encrypted journal export, "Your data" privacy footer, day-card/med-bar toggles. |
| **Onboarding / Welcome (first-run)** | `Onboarding/WelcomeView.swift` | The whole first-launch warm-welcome screen — never built. |
| **Day Detail sheet** | `Components/DayDetailSheet.swift` | The per-day sheet (tapped from calendar/insights) — distinct from the single-recording detail. |
| **Tab bar chrome (RootTabView)** | `RootTabView.swift` | Approximated on a few boards but never reproduced faithfully as its own component (real icons / material / selected tint). |
| **Feedback flow** | `Feedback/{FeedbackButton, IssueReportView, MailComposeView, ScreenshotCapture, ShareSheetView}.swift` | Not built — though spec-024 is *removing* the feedback button, so low value. |
| **Debug: TestServicesView** | `TestServicesView.swift` | Dev-only, not user-facing — intentionally skip. |

---

## B. Built screens — missing states / variations

- **Calendar (`CalendarLibraryView`)** — built: week + month. **Missing:** the **empty / first-run state** ("No entries yet", `chart.badge.exclamationmark`) — flagged by the page-1 review, never done.
- **DayCard folded** — built: Great / Okay / Low / empty. **Missing:** the **unknown-mood day** (recordings but no mood → no glyph, weekday-only title, summary still shows energy/focus/med).
- **DayCard expanded** — built: one day, 2 rows + carryover ring. **Missing:** **single-row** day · **3+ rows** · the **hollow med-only bead** (no recording, cream circle + ring) · unknown-mood expanded.
- **Recording detail** — built: default (transcript collapsed, audio idle, all 4 cards). **Missing:** **transcript expanded** (body paragraph) · audio **playing / paused** states · transcript **"Transcribing…" / failed** states · detail with the med-bar absent.
- **Edit check-in (`ExtractionReviewView`)** — built: one fully-populated catalog state. **Missing:** med **"Missed"** state (grey vs purple) · **non-catalog free-text med** (single dose line, no grid) · empty/unselected sections · **save-error** inline state · custom-hours filled.
- **Check-in** — built: 10 states. **Missing:** the **"Wrapping up soon"** cap-approach cue visible · **returning-user idle** (no first-launch hint) as a separate variant · med-bar with 2–3 doses.
- **Insights** — built: one populated month + empty. **Missing:** **Breakdown sub-empty** (section header but no bubbles/legend, when no moods logged) · **all-gated Connections** (early-user state) · **fewer-than-5 bubbles** (a missing mood level leaves a gap) · other months.
- **Medication bar (`MedicationBarView`)** — built: one **"active"** dose. **Missing:** the other phase words **kicking in / wearing off / worn off** · **1 vs 2 vs 3** dose rows · the **absent** (no doses) state.

---

## C. Cross-cutting dimensions not reproduced (apply to *every* board)

- **Dark mode** — everything is **light "Paper" only**. The full dark "loam" variant of all 22 boards (≈14 adaptive tokens have dark hexes I captured but never drew).
- **Dynamic Type / accessibility text sizes** — static at default; AX5 / large-type layouts not reproduced.
- **Animation/motion states** — static snapshots only (crescent spin/breathe, checkmark pop, transitions) — inherent to static mocks.

---

## Bottom line

The **3 core tabs** (Calendar, Check-in, Insights) and the two detail/edit sheets are covered with most key states. The biggest genuine gaps are **Settings (a whole tab)**, **Onboarding/Welcome**, the **Day Detail sheet**, the **calendar empty state**, and **dark mode** across everything. Settings + Welcome + Day-detail would round out *screen* coverage; dark mode would round out *variation* coverage.
