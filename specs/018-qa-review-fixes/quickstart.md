# Quickstart / Validation: QA fixes (018)

How to prove the three fixes work. All verification is build + on-simulator (Constitution Principle II / X SwiftUI-view exemption) — there are no new unit tests to run for this feature.

## Prerequisites

- Build the `app-four` scheme on an iPhone simulator (iOS 26) via the `ios-debugger-agent` skill (XcodeBuildMCP).
- Seed the test build with signals so the calendar has registered days and the med bar shows a phase (the walkthrough used *Vyvanse 70mg · wearing off*).

## Build & test gate

1. Build the app — must compile clean.
2. Run the full suite — must stay green (expect no count change; this feature adds no tests). Confirm `CalendarHeaderScrollFadeTests` still passes (A2 must not touch the Calendar header fade).

## A2 — top scroll fade (Insights + Settings)

1. Open **Insights**; scroll content upward toward the medication bar.
   - ✅ Content dissolves to transparent at the bar's bottom edge (no sharp text beside/above the floating capsule), symmetric with the bottom fade. → C-A2-1, C-A2-3
2. Open **Settings**; scroll the list upward.
   - ✅ List content fades behind the bar at the top. → C-A2-2
   - ✅ Tap a row and trigger tab-reselect scroll-to-top — selection + scroll still work. → C-A2-6
3. Set an **accessibility Dynamic Type** size (Settings → larger text or the simulator environment override); repeat on both screens.
   - ✅ Fade still reaches the (now taller) bar's bottom edge — no sharp band, no over-fade. → C-A2-4
4. Turn **Show Medication Bar OFF**; re-check Settings/Insights.
   - ✅ No spurious top fade where there's no bar. → C-A2-5
5. Repeat steps 1–2 in **dark mode**.

## A1 — greyed registered day keeps its dot

1. In the calendar, select a **past day** that has at least one **more-recent day with check-ins**.
   - ✅ The more-recent registered day greys/dims but still shows its mood-coloured dot. → C-A1-1
   - ✅ A more-recent day with no entries shows no dot. → C-A1-2
2. Find a greyed day whose entries are **neutral** (no mood) — its neutral dot should still show, dimmed. → C-A1-3
3. Enable **VoiceOver**, focus a greyed registered day.
   - ✅ Announces "…, has check-ins" (or "has entries"). → C-A1-4

## A3 — Log-Dose colour

1. Go **Check-in → Log meds** to open the Log-Dose sheet; screenshot it. Compare against the rest of the app and `DESIGN.md`.
   - ✅ Surface + chip colours use design-system tokens; the originally-flagged colour now renders correctly. → C-A3-1, C-A3-4
2. Toggle a chip selected/unselected.
   - ✅ Colours use the medication/design tokens consistently. → C-A3-2
3. Repeat in **dark mode**.
   - ✅ All colours correct + legible. → C-A3-3

## Done when

- App builds, full suite green, and every ✅ above is observed on-sim in light **and** dark mode.
- `specs/014-daily-card/spec.md` FR-011/FR-014 amended to record the dot-dimmed decision + greyscale tradeoff (research D3).
- See [contracts/ui-behavior.md](contracts/ui-behavior.md) for the full behaviour matrix.
