> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# Whisper Notes — Visual QA (screenshots only)

Image-only audit of 5 screens (Recording Detail, Calendar, Record, Insights, Settings). No code inspected. Mapped to the `swiftui-design-principles` skill where relevant.

Your four reported issues are confirmed below (✓), plus ~20 more.

---

## P0 — Looks broken to a user

### Shared root symptom: the scroll/header/safe-area scaffold is broken
The same failure shows up on three screens, which means it's one shared container bug, not three:

- **Insights ✓** — the mood **donut chart overflows the top of the screen**, drawing *over* the "Insights" title **and into the status bar** (clock/battery). Content is also cut off at the bottom ("Your emotions during t…") — **not scrolling**.
- **Settings ✓** — the large **"Settings" title overlaps the "SYSTEM" label**, and the top card ("AI MODELS / Whisper Transcription") renders **under the status bar**. Content scrolls *under* the title instead of below it — **not scrolling** correctly.
- **Calendar ✓** — **huge dead gap** (~⅓ of the screen) between the "Calendar" title and the "JUN 2026" selector. The content is pushed down by roughly the amount Insights/Settings are pushed *up*.

> All three are the symptom the design skill warns about: *"Don't add `safeAreaInsets.top` reflexively; double-counting it creates obvious dead space."* Here it's both over- and under-counted depending on screen. One scaffold owns the top inset → fix once, fixes all three.

### Destructive action bleeds under the tab bar
- **Settings** — red **"Clear all data"** text is visible *behind* the floating tab bar at the bottom. Content isn't inset above the tab bar, so the last (and most dangerous) row is clipped/obscured.

### Floating feedback button collides with content
- The blue chat-bubble button overlaps the **"Your emotions"** heading (Insights) and the **"Reduce Motion"** toggle (Settings), and floats over the Detail screen. It's not anchored clear of content or the tab bar. (If it's a debug-only button, it shouldn't ship at all.)

---

## P0 — Data/formatting bugs visible on screen

- **`05:6` instead of `05:06`** (Calendar, third entry) — minutes aren't zero-padded.
- **Durations everywhere show `0:00`** (Detail "· 0:00", audio player "00:00", all Calendar rows) and **Storage shows `0.0 MB`** for "1 recordings" — recording length/size isn't being captured or displayed.
- **"1 recordings"** (Settings → Storage) — should be singular "1 recording". Pluralization bug.

---

## P1 — Consistency & design system

### Screen titles use three different styles
- **Calendar / Insights / Settings:** large, left-aligned title.
- **Record:** small, **center inline** title.
- **Detail:** **no title at all** — just a floating back chevron.

Pick one navigation-title treatment for all screens.

### Section-header typography has no hierarchy
- **Insights** renders section headers (**"Your mood during the day"**, "Your emotions…") at near-`largeTitle` size — as big as the *screen* title, so everything shouts.
- **Settings** uses tiny uppercase caption labels ("MEDICATION BAR", "ACCESSIBILITY").

Two screens, two opposite section-header scales. The skill calls for *fewer sizes, clear hierarchy* — section headers should be one consistent, modest style.

### Settings should be a grouped list, not floating cards
Each toggle is its own rounded card with gaps between them (4 separate cards under "MEDICATION BAR"). The skill's §5 is explicit: use **native grouped style** — rows in one container separated by `Divider()`, not a stack of individual cards. Current style is noisy and non-native.

### Over-carded UI with oversized corner radius
Nearly every element is a floating `secondarySystemBackground` card with a large (~16–20pt) radius. The skill says **10–12pt** and to reserve cards for grouped content. Detail screen especially: 5 stacked cards with big gaps and lots of internal dead space (the "Log Entries" card is tall but holds one small "Mood / Great" pill).

### Too many accent colors (restraint violation)
Visible across screens: **blue** (edit/refresh/toggles), **cyan** (mood dot/face), **teal** (mood pill), **green** (checkmarks/"Completed"), **orange** ("alert energy"), **purple** ("Concerta"), **red** (delete). That's 7 hues competing. The skill's core philosophy is *fewer colors, used consistently*.

### Mood colors don't map to meaning
Calendar dots: "Great" = cyan, but **"Okay" and "Alert" are both blue** — different states, same color. The color encoding isn't legible.

---

## P1 — Medication bar (your point ✓)

- **Only appears on the Detail screen**; missing on Calendar, Record, Insights, and Settings. You want it present in more views — agreed, and it should appear in **one consistent position** on each.
- On Detail it's a low-contrast dark bar; the **progress fill (taken→ends) barely reads** against the background. The `.ultraThinMaterial`/dark treatment you flagged makes "Concerta 36mg · 01:00 … ends 11:00" hard to scan.

---

## P1 — Per-screen UX

**Recording Detail**
- No screen title — can't tell what you're viewing except by the "Great" mood.
- Large empty black area below "Delete Recording"; content doesn't fill or balance.
- "Completed" (green), the mood pill (teal), and tags (orange/purple) are three different chip styles — unify.

**Calendar**
- Redundant labeling: row titled **"Okay · Alert"** then a tag **"alert energy"** repeats "alert".
- **Unlabeled green checkmarks** on each row — meaning unclear (transcribed? saved?). Needs a label or removal.
- Single "TODAY, 9 JUN" group floating after a big gap looks unfinished.

**Record**
- **Unbalanced vertical space**: the "Done" pill + waveform float in the upper third, then a large void down to the mic button. Anchor the content.
- Waveform looks **inert/placeholder** (uniform bars) — doesn't reflect idle vs recording.
- **No medication bar** here either.

**Insights**
- Empty state is **four big grey placeholder bars** ("0 check-ins" ×4) — reads as broken, not "no data yet." Needs a real empty state.
- "1 check-in this month · mostly neutral" centered, but the next section is left-aligned and huge — mixed alignment.

**Settings**
- Custom row icons are inconsistent (e.g. an **"Aa" glyph** for "Show Medication Name" is unintuitive).

---

## Cross-cutting tab bar note
The floating pill tab bar puts the **Record** item in a filled circle while the other four are flat glyphs — it reads like a different control type (a FAB) sitting inside the tab bar. Either make all five consistent or pull Record out as an intentional primary action.

---

## Suggested fix order
1. **One scaffold** owning top safe-area inset + scroll + tab-bar bottom inset → fixes Insights overflow, Settings overlap, Calendar gap, and the clipped "Clear all data" in one move.
2. **Formatting bugs** (`05:6`, `0:00` durations, "1 recordings") — quick, high-visibility wins.
3. **Remove/relocate the feedback button** so it never overlaps content.
4. **Settings → native grouped list**; standardize titles and section-header type.
5. **Medication bar**: one position, present on every primary screen, higher-contrast fill.
6. **Color + chip pass**: one chip component, a small fixed palette, legible mood encoding.
