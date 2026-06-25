# Calendar Timeline — UX/UI Critique & Brainstorm Brief

> **Source:** 8 device screenshots (light "paper" + dark "loam"), 2026-06-23, Calendar/Library tab.
> **Method:** impeccable Assessment-A design-review rubric (Nielsen heuristics, cognitive load, emotional journey, persona red flags, AI-slop test) + SwiftUI a11y audit, applied to screenshots. Findings are reframed as **brainstorm seeds** for superpowers `brainstorming`.
> **Status:** uncommitted working doc — feeds brainstorm → (if a feature emerges) Spec Kit.

## 1. What this screen is (objective)

The Calendar/Library tab: a collapsible week↔month calendar bound to a day-grouped timeline of check-ins. Each check-in records **mood · energy · focus** signals (a colored banner), an optional **medication dose** shown with an effect-phase **ring** (the % on the time bead), and free-form **tags** (a "General" category, "Medications", symptoms like Headache/Dry Mouth, feelings like Calm/Happy). Days **fold** to a one-line summary and **unfold** to the full timeline.

## 2. Strengths (preserve)

- **Distinctive identity — passes the AI-slop test.** Fraunces serif, warm paper/loam, signal glyphs, mood-tinted day washes. Looks designed, not defaulted.
- **The folded summary line** ("okay · steady · sharp · Vyvanse") is calm, scannable, elegant — the high point of the screen.
- **Medication phase rings** (93% / 46%) are an original, information-rich touch.
- **Mood is encoded redundantly** (color wash + named label "OKAY"/"FLAT") → not color-only, survives greyscale.

## 3. Heuristic critique (scored)

| # | Finding | Heuristic | Sev |
|---|---|---|---|
| 1 | **Expanded-card density / visual noise floor.** A 3-check-in day renders ~18 chips, all similar weight. The calm of the folded view evaporates on expand. | Aesthetic & minimalist | **P1** |
| 2 | **Redundant low-signal chips.** "General" sits on *every* entry; "Medications" duplicates the explicit "Taken X 70mg" dose chip beside it; category chips ("Symptoms") repeat alongside their specifics ("Jitters"). | Recognition / signal-to-noise | **P1** |
| 3 | **All-caps mood banners shout** ("GREAT TIRED PRESENT") — tonally at odds with a calm ADHD journal. (Chip casing already softened in the newer build; banners still caps.) | Match brand / emotional fit | P2 |
| 4 | **Floating feedback button overlaps content** — the orange (!) bubble covers tappable chips bottom-right in most shots (obscures "Dry Mouth", "LOCKED…"). | Error prevention / aesthetic | P2 |
| 5 | **Raw enum copy leaks:** "LOCKEDIN" / "lockedIn" instead of "Locked in". | Consistency & standards | P2 |
| 6 | **Phase-ring % is prominent but unlabeled** — a first-timer can't decode "93%" (dose remaining? absorption? time-in-window?). | Recognition over recall | P2 |
| 7 | **Three competing treatments per check-in** (loud caps banner / purple dose chip / grey tags) blur primary-vs-secondary hierarchy. | Visual hierarchy | P2 |
| 8 | **Content ghosts under the translucent tab bar** (e.g. "Wednesday 17 Jun" half-hidden). | Aesthetic | P3 |

## 4. Accessibility audit (SwiftUI)

- **Dark-mode banner contrast:** dark text on mid-tone green/amber/orange fills — verify ≥4.5:1 (mid-green banner is borderline).
- **Purple med-chip text on dark chip** — verify ≥4.5:1 in dark mode.
- **Dynamic Type:** dense horizontal chip rows will wrap/overflow awkwardly at AX text sizes; the expanded card has no room to grow gracefully.
- **All-caps banner text** → VoiceOver may spell short tokens; "LOCKEDIN" reads oddly.
- **FAB overlap** → covered chips are a touch-target conflict, worse at large text.
- **Positive:** every color signal has a redundant text label (mood/energy/focus named) — greyscale-safe.

## 5. Brainstorm seeds (the handoff to `/brainstorm`)

Open questions to explore — not yet decisions:

1. **Density vs. calm.** How might the *expanded* day inherit the *folded* view's calm? (Lead with signals; reveal tags on a second tap? Auto-collapse near-universal tags?)
2. **Tag signal.** Which tags inform vs. clutter? Should "General"/"Medications" be implicit? Could symptoms/feelings collapse into a count or summary pill ("2 side effects") instead of a chip wall?
3. **Phase-ring meaning.** What's the right way to convey dose-effect to a newcomer — a label, a one-time legend, or a qualitative state ("peaking" / "wearing off") instead of a bare %?
4. **Banner tone.** Does sentence/title case + softer fills fit the calm brand better without losing the at-a-glance read?
5. **Emotional fit for ADHD.** For a distractible user, is "open to a full day of data" the right default, or should a day open to a digest with drill-down?
6. **First-glance intent.** What's the ONE thing a user wants when opening a past day — and does the layout lead with it?
7. **Feedback affordance.** Is the (!) button shipping or debug? Where should it live so it never covers content?

## 6. Note on build drift

The newer (dark, 21:49) build shows the **title-case medication chip** ("Taken Vyvanse 30mg") — the critique fix has landed there. The older (light, 20:28) build still shows all-caps ("TAKEN VYVANSE 70MG"). Confirm the casing fix once you rebuild.
