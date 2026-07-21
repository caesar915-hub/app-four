<!-- Created: 2026-06-30 17:07 (WEST) · Updated: 2026-06-30 17:07 (WEST) -->
# Penpot reproduction — Phase 1 (Settings & Onboarding page)

Status record + resume guide for the Phase-1 Penpot board build. Phase 1 = the whole-*screen* gaps from [UX_UI_BACKLOG.md](../../../UX_UI_BACKLOG.md): Settings, Onboarding/Welcome, Day Detail, faithful tab bar.

## Where the boards live
- Penpot file **"New File 1"** (file-id `a234c67f-eb39-8116-8008-3f1eec680a69`), page **"Settings & Onboarding"** (a 4th page added alongside Page 1 / Check-in / Insights).
- Board names + x-offsets (Penpot uses absolute coords; each board's content is offset by its x): `P1 Welcome` (x=0) · `P1 Tab bar` (x=460) · `P1 Day Detail` (x=920) · `P1 Settings` (x=1380) · `P1 Download states` (x=1840) · `P1 Recovery key` (x=2300).
- ⚠️ There are also 6 **empty orphan boards** on Page 1 (same names) from an `openPage`-is-async mistake — harmless, deletable.

## What's DONE (built, exported, synced to Penpot — verified faithful)
1. **P1 Tab bar** — 4 tabs (Calendar selected=meadowGreen, others muted), correct SF-symbol-equivalent icons, hairline + home indicator.
2. **P1 Welcome** — angular-gradient `CrescentRing` hero (40-arc approximation), "Welcome to Squirl" / subtitle, meadow-gradient "Start" button with amber shadow, status bar.
3. **P1 Day Detail** — dimmed backdrop + rounded-top sheet + grabber, "Wednesday, 10 Jun" nav + "Done", 3 `RecordingRow` cards (mood dot + title + green check + meta + signal-glyph tag chips).

## What's NOT built (precomputed, blocked on the connection)
4. **P1 Settings** — full insetGrouped list: med-bar, AI Models (`ModelDownloadRow` idle), System (Storage + cellular toggle), Check-in (Prompt Pace), Medication Bar (4 toggles), Calendar (2 toggles), Accessibility, Your data, Export, Danger, Version.
5. **P1 Download states** — `ModelDownloadRow` × 6 states (not-installed / installed / downloading / 42% / error-no-conn / error-cellular).
6. **P1 Recovery key** — the journal-export recovery-key sheet (key box + Copy button + Done).

These three are fully authored — they just need a stable channel to fire.

## How to resume (when the Penpot connection is stable)
The engine (`storage.*` helpers) is wiped whenever the Safari tab reopens, so the build must restore it first. Two paths:

- **One-shot (fewest round-trips):** `mega_build.js` is the **entire engine + all 3 board builds inlined into a single `execute_code` body** (no chunked buffer, no `new Function`). Sequence: (1) `penpot.openPage(<"Settings & Onboarding" page>)`; (2) fire the contents of `mega_build.js` as one `execute_code`; (3) `export_shape` each of the 3 boards. ⚠️ Risk: a 41 KB call with many `createShapeFromSvg` can *wedge* the plugin runtime (see connection notes) — if it wedges, refresh the tab and use the incremental path.
- **Incremental (wedge-safe):** restore the engine from `engine.js` + `icons.js` + `phase1-additions.js` (concatenated = `_full.js`), then fire `build_settings.txt` / `build_mdr.txt` / `build_recovery.txt` snippet-by-snippet (split on `---SNIP---`). Each board's first snippet clears it, so re-firing is idempotent.

## Engine / helper reference (in this folder)
- `engine.js` — base engine (colors `C`, helpers `U`, glyphs `G`, board-helpers `B`, exported via the icons file).
- `icons.js` — `storage.I.*` base icons (heart, calendar, checkCircle, chartBar, gear, zzz, thermometer, bandage, pencil, xmark, play, pause, ellipsis).
- `phase1-additions.js` — **this session's additions**: `G.crescent`, `B.recRow/medBar/toggle/setRow/sep/secHead`, and 12 new icons (waveform, clock, trash, checkmark, antenna, clockArrow, pillsCircle, pill, rectStack, rectExpand, lockDoc, docOnDoc).
- `_full.js` — `engine.js` + `icons.js` + `phase1-additions.js` concatenated (top-level marker `return`s stripped). `mega_build.js` = `_full.js` + the 3 board builds.
- `spec_phase1_*.md` — the code-grounded reproduction specs (every value resolved to hex/pt, copy verbatim, `file:line` cited).

## Why this stalled (connection)
The build was blocked by `penpot` MCP `execute_code` instability — see the connection diagnosis in DEVLOG (2026-06-30). Root causes: Safari background-tab throttling kills the plugin WebSocket; the MCP stream dies on idle; the 30s tool timeout < slow round-trips (commands land but acks don't); the hosted-server client session goes stale (only `/mcp` fixes it); and heavy single calls can wedge the plugin runtime. `execute_code` runs the Penpot **Plugin API inside the browser tab** — there is no headless version — so a "local MCP server" does **not** remove the browser dependency.
