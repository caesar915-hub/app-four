# Insights — Brainstorm

> Divergent exploration (superpowers-style) from [the critique brief](ux-critique-insights.md). Each thread ends in a **decision that's yours**. Feeds Spec Kit.


**North star:** When an ADHD user opens Insights, in one calm glance it should tell them "you showed up, and here's one true thing about your shape this month" — reassurance first, one honest pattern second, never a wall of charts to navigate or a correlation it can't stand behind.


## Thread 1 — Container & navigation — is forced paging the right vessel?

**Question:** For a population prone to overwhelm and time-blindness, is a 5-section forced-paging carousel (each section hard-clipped to one viewport, month control reachable on only 1 of 5 pages) the right container, or does the snapping itself add navigation load a single calm scroll would remove?


*Why it matters:* The paging is the screen's defining interaction and also its biggest defect: page(height:) clips every section to one viewport with no internal scroll (InsightsView.swift:119-123), so under large Dynamic Type the gauges, matrix, and connection cards fall off-screen unreachable — and the month selector rides only on page 1 (InsightsView.swift:142-143), so 'which month am I in / get me back to now' is impossible from 4 of 5 pages. For ADHD users, content you can't reach and a position cue (header dimming) that's visual-only both read as 'the app is hiding things from me.'


### ▸ One continuous scroll  *(effort M)*
Drop .scrollTargetBehavior(.paging) entirely. Sections become a single vertically-scrolling document — title, breakdown, signals, averages, rhythm, connections — each sized to its content, separated by generous Spacing.hero air and a hairline rule. The month selector pins at the top (matches DESIGN.md:94's 'Pinned selector').
- **Pros:** Eliminates the P1 overflow defect for free — content can always be reached because the page grows with Dynamic Type; Lowest navigation load: one gesture, no snapping, nothing hidden — the calmest possible posture; Month selector can pin honestly; jumpToToday() finally has a home; Fixes the fragile scrollPosition(id:) header-dimming dependency (InsightsView.swift:103-112) by removing the mechanism that needs it
- **Cons:** Loses the editorial 'one big idea per screen' rhythm the paging gives — risk of feeling like a report dump; The dimmed-header position cue disappears; needs a replacement (e.g. a sticky active-section label); Contradicts the shipped spec (DESIGN.md:94 '5-section snapping scroll') — needs an explicit Decisions Log entry
- **Brand fit:** Strong. 'The app always slightly calmer than you' (DESIGN.md:11) argues against snapping; a slow continuous scroll with lots of paper air is more field-journal than carousel. Loses some drama but gains calm.

### ▸ Scroll-snap, not hard-clip  *(effort L · feature)*
Keep paging's feel but make it forgiving: each section sizes to max(viewport, intrinsicContentHeight) and scrolls internally when it overflows; .paging stays so a flick still settles section-to-section, but tall content (AX sizes, connections) can be scrolled past within its own page. The selector pins as an overlay above the paged area.
- **Pros:** Preserves the 'one idea per screen' editorial posture the design intends; Fixes the overflow P1 without abandoning the chosen interaction model; Keeps the satisfying settle that fits DESIGN.md:79 'everything decelerates gently'
- **Cons:** Nested-scroll gesture conflicts (brief P2): vertical paging can fight the horizontal bead strips and an internal scroll — fiddly to get right on-device; More engineering and QA than a flat scroll; the very complexity that's already biting; Header-dimming identity bug still needs the .id() moved onto the scroll-target child (brief P1 #2)
- **Brand fit:** Good. Retains the considered, paced reveal; risk is the snap feeling mechanical if not tuned to Motion tokens and Reduce Motion.

### ▸ Two-layer: glance card + optional depth  *(effort L · feature)*
Collapse the five sections into one always-visible 'this month' summary card (the reassurance + one headline pattern), with the deeper visualizations (rhythm matrix, full strips, all connections) behind a single quiet 'See the detail' disclosure that expands inline or pushes a detail screen. Insights opens calm and finished, not as a five-stop tour.
- **Pros:** Best matches the ADHD north star: the answer is on screen in one glance; depth is opt-in, never imposed; Naturally solves overflow — the glance card is small; depth lives on its own scrollable surface; Forces the team to decide the ONE headline takeaway, sharpening the screen's purpose (Thread 2)
- **Cons:** Biggest departure from shipped design — effectively a redesign, not a fix; Risk of burying the bespoke visualizations users might love; discoverability of 'See the detail' must be strong; Requires picking/deriving the single headline pattern, which is non-trivial product work
- **Brand fit:** Very strong in spirit (effortless, progressive disclosure, DESIGN.md:73), but the most visually divergent from the current editorial five-section identity.

**↳ Recommendation:** Direction A (One continuous scroll) as the immediate, correct fix, evolving toward C's two-layer posture once the headline-pattern question (Thread 2) is answered. The paging is currently buying drama at the cost of reachability, a broken position cue, gesture conflicts, and an unreachable month control — four problems that all dissolve when paging goes away. A flat calm scroll is the most on-brand and lowest-load vessel; ship that first, then consider promoting a glance card to the top as the screen's purpose crystallizes.


**🟡 Your decision:** Decide the container: (A) abandon forced paging for one continuous pinned-selector scroll [recommended], (B) keep paging but make it scroll-snap with internal overflow scrolling, or (C) commit to a glance-card + optional-depth redesign — and authorize the corresponding DESIGN.md:94 / Decisions Log update since all three diverge from the shipped 'snapping scroll' spec.


## Thread 2 — Emotional job — what is Insights FOR?

**Question:** What is the single intended takeaway when an ADHD user opens Insights — reassurance ('you showed up'), self-knowledge ('here's your shape'), or actionability ('do more of X') — given that the current mix of bubbles + gated correlations + rhythm matrix spans all three with no clear primary?


*Why it matters:* Without a primary job, the screen makes the user do the synthesis — exactly the executive-function load this audience can't spare. The 'today vs your usual' subtitle (InsightsView.swift:69) promises a contrast the page never delivers (every section is a month aggregate; no 'today' datum exists anywhere), so the screen currently over-promises and under-focuses at the same time.


### ▸ Reassurance-first ('you showed up')  *(effort S · quick)*
Lead with presence and gentleness: a warm one-line summary at the top — 'You checked in 14 days this month. Mostly Okay, often Good.' — set in Fraunces, with the visualizations below as supporting texture. The hero is that you showed up, framed without judgment. Replace the unmet 'today vs your usual' subtitle with this honest summary.
- **Pros:** Perfectly on-spec for the anti-shame posture (DESIGN.md:85-87, no streaks, reward = 'I said it and it's captured'); A single declarative sentence is the lowest-load possible takeaway; Honestly fixes the broken subtitle promise by replacing it with something the data can actually back
- **Cons:** Risks feeling thin to a user who wants to learn something, not just be patted on the head; 'Reassurance' can tip into empty praise if the copy isn't carefully neutral; Underuses the genuinely good bespoke viz that's already built
- **Brand fit:** Excellent. This is the truest expression of 'relief, then permission' (DESIGN.md:16) and the calm field-journal voice.

### ▸ Self-knowledge-first ('here's your shape')  *(effort M)*
Lead with one honest, legible pattern as the headline — e.g. the daily-rhythm signal ('Mornings sharp, evenings foggy') or the dominant mood shape — promoted out of the matrix into a plain-language hero sentence + one supporting glyph. The screen's job is a mirror, not a coach.
- **Pros:** Delivers real value (the 'aha') without telling the user what to do — respects autonomy; Leverages the rhythm/breakdown data that's already computed; Self-knowledge is what longitudinal tracking is uniquely good at
- **Cons:** Requires the underlying stats to be trustworthy — current rhythm tie-break biases dominance upward (+Signals.swift:172-174) and connection denominators overstate (Thread 3); a wrong 'shape' is worse than none; Picking THE headline pattern algorithmically is real work; One headline may not generalize across sparse early-logging months
- **Brand fit:** Strong. A calm, abstract mirror (no faces, no scores) fits the glyph-language ethos; the risk is asserting a pattern the data can't support, which violates 'match between system and real world.'

### ▸ Actionability-first ('do more of X')  *(effort M)*
Lead with a gentle, optional suggestion derived from the strongest connection — 'On medication days your focus was sharper' presented as an observation the user can act on, with the rest as evidence.
- **Pros:** Highest felt utility if the user wants to change something; Gives the otherwise-inert connection cards a reason to be the headline
- **Cons:** Closest to 'coaching/nagging' — high risk of tripping the anti-nag posture (DESIGN.md:86) for an audience allergic to being told what to do; Demands the highest statistical confidence of any option; current correlations overstate association (brief P3, +Signals.swift:196-203); A wrong or pushy suggestion erodes trust fastest in this population
- **Brand fit:** Weakest. Advice-giving sits uneasily with 'non-judgmental, the app never tells you you're late.' Only safe if framed as observation, never instruction.

**↳ Recommendation:** Reassurance-first as the primary job (Direction A), with one self-knowledge headline (Direction B) as the secondary beat once the stats are trustworthy. The ADHD north star and the entire Paper & Pollen posture point at 'you showed up' as the emotional core; actionability is the riskiest fit and should be demoted to, at most, a neutrally-phrased observation. Critically, this thread also resolves the broken 'today vs your usual' subtitle (InsightsView.swift:69): either build a real today-vs-usual contrast or replace the subtitle with the honest reassurance summary — do not leave the promise unmet.


**🟡 Your decision:** Name the ONE primary emotional job for Insights (recommended: reassurance, with self-knowledge second) — and decide the fate of 'today vs your usual': build an actual today marker/comparison, or replace that subtitle with a summary the current data can honestly support.


## Thread 3 — Trustworthiness of patterns — can the app stand behind what it claims?

**Question:** How should connections and dominant-level claims be computed and presented so the app never overstates a pattern to a population uniquely sensitive to false self-narratives — and should the correlation cards become explorable (tap to see the days behind '75% of the time') rather than asserted?


*Why it matters:* ADHD users are prone to rejection-sensitive, all-or-nothing self-stories; an over-claimed 'On medication days, sharp focus appeared 75% of the time' that's really 'days with at least one sharp-ish check-in' can become a false belief or a guilt trigger. The current math counts any qualifying check-in in a day (+Signals.swift:196-203, 228-235, 268-281), the rhythm tie-break always rounds dominance up (+Signals.swift:172-174), the section header claims '3 or more days' while two of three cards gate at 4 and 5 (+Signals.swift:191,223; InsightsView.swift:205-206), and every claim is inert — the user can't check it.


### ▸ Honest copy, same math (truth-in-labeling)  *(effort S · quick)*
Keep computations but make the language exactly match what's measured: 'On 6 of 8 medication days, at least one check-in was sharp+' instead of an implied per-check-in rate. Fix the header to stop promising a single day-count, and define + document the rhythm tie-break (e.g. lower-on-tie or closest-to-mean) so it stops biasing high.
- **Pros:** Cheapest path to trustworthiness — wording + tie-break, no new computation; Removes the overstatement and the header/threshold inconsistency immediately; '6 of 8 days' is more concrete and honest than an abstract %
- **Cons:** Still day-level, not check-in-level — a purist would want true rates; Doesn't make patterns explorable; claims remain assertions; Copy gets longer/denser, slightly at odds with minimalism
- **Brand fit:** Strong. Honesty and precision are core to a privacy-first journal that respects the user; plain 'N of M days' fits the warm, specific copy voice already present.

### ▸ Explorable evidence (tap to see the days)  *(effort M)*
Make each connection card tappable: tapping '6 of 8 med days were sharp+' reveals the actual days/beads behind it (reusing the bead strip + DayDetailSheet path), so the correlation is inspectable, not asserted. The card becomes a doorway, not a billboard.
- **Pros:** Builds trust by being checkable — the user verifies the claim themselves; Gives the currently-inert connection cards (the most 'insightful' element) a real interaction (brief §9); Reuses existing DayDetailSheet/bead infrastructure
- **Cons:** More UI surface and engineering; sparse months may show thin evidence that undercuts the claim; Could invite over-analysis/rumination — must stay calm, not investigative; Requires the honest-math fix first or it lets users discover the overstatement themselves
- **Brand fit:** Good. Progressive disclosure (DESIGN.md:73) and transparency align with privacy-first; the drill-down must stay paper-calm, not dashboard-y.

### ▸ Confidence-gated humility (only claim when sure)  *(effort M)*
Raise/standardize the gates and attach a quiet confidence posture: only surface a connection when it's robust, and phrase tentatively ('Sleep and mood seem to move together') rather than asserting precision. Below threshold, stay in the warm 'a few more check-ins and a pattern may show' nurture state — never a hard binary lock.
- **Pros:** Strongest protection against false self-narratives — the app only speaks when confident; Tentative phrasing models healthy uncertainty for a population prone to absolutes; Pairs naturally with a graceful nurture state instead of a cold lock icon
- **Cons:** Shows fewer insights, especially early — risks an empty-feeling screen for new/sporadic users; 'Confidence' on tiny n is itself shaky; thresholds are somewhat arbitrary; Could feel evasive if overdone ('seems', 'maybe' everywhere)
- **Brand fit:** Strong. Tentative, gentle, non-judgmental is exactly the Squirl voice; the nurture-over-lock framing fits 'no penalty, forgiving.'

**↳ Recommendation:** Direction A (honest copy + fixed tie-break + corrected header) is non-negotiable and should ship regardless — it's cheap and it's a correctness/trust fix, not a feature. Layer Direction C's tentative phrasing on top (claim gently, gate consistently). Pursue Direction B (explorable evidence) as the higher-effort follow-on that turns the inert cards into the screen's most trustworthy element — but only after A, so exploration reveals an honest claim, not an inflated one.


**🟡 Your decision:** Approve the truth-in-labeling fixes (day-level 'N of M' phrasing, documented non-upward rhythm tie-break, header that matches actual gates) as a correctness change; then decide whether connection cards become tappable-to-evidence now (Direction B) or stay assertions with humbler copy (Direction C) for v1.


## Thread 4 — Time horizon & sleep coherence — scope and the half-present signal

**Question:** What window should Insights cover — strict calendar month, rolling 30 days, or selectable ranges including all-time — and how should sleep be represented before its ramp ships so 'not tracked yet' never contradicts a live sleep insight?


*Why it matters:* Two coherence gaps undercut the screen. (1) Insights is hard-scoped to one calendar month (monthRecordings, InsightsViewModel.swift:49-53), which fragments exactly the longitudinal pattern-finding ADHD self-tracking benefits from — and a calendar boundary means the 2nd of the month shows a near-empty screen. (2) Sleep is self-contradictory: a 'Sleep · not tracked yet' chip (InsightsView.swift:79-94) sits two sections above a fully-live 'Sleep × mood' connection card with seed data (+Signals.swift:249-295) — the app says it isn't tracking the thing it's visibly correlating.


### ▸ Rolling window over calendar month  *(effort M)*
Replace the calendar-month scope with a rolling 'last 30 days' (or 'last 4 weeks') as the default, so the screen is always populated and patterns don't reset at midnight on the 1st. Keep month-jump available for browsing history.
- **Pros:** No more near-empty screen at the start of each month — always something to show; Rolling windows match how patterns actually accrue, not calendar arbitrariness; Removes the 'why did my insights reset?' confusion entirely
- **Cons:** Loses the clean 'this month' mental model some users like; Month selector semantics get muddier (rolling default + month browse is two modes); Re-derivation of all metrics against a moving window
- **Brand fit:** Neutral-to-good. Calmer (never resets to empty), but the 'field journal' month metaphor is slightly weakened; fine if framed as 'your recent shape.'

### ▸ Selectable ranges incl. all-time  *(effort L · feature)*
Offer a small range control — Month · 90 days · All time — so users can zoom out for longitudinal patterns. Default stays month/rolling; all-time unlocks the deeper self-knowledge horizon.
- **Pros:** Directly serves the ADHD longitudinal use case the brief flags (§9); Lets light early users see month and invested users see the arc; One control, big payoff in perceived depth
- **Cons:** Adds a control and more states to design/test against Dynamic Type and empty data; All-time aggregates can wash out recent change (and stress synchronous main-actor computation, brief P3); Scope creep risk if shipped before the core screen is calm
- **Brand fit:** Good if the control is quiet (a small segmented/menu, not a loud filter bar). Aligns with progressive disclosure; risk is dashboard creep.

### ▸ Decide sleep, then say it once  *(effort S · quick)*
Resolve the sleep contradiction by picking a single posture and enforcing it everywhere: EITHER sleep is tracked-but-unramped (then drop the 'not tracked yet' chip, give sleep a single bed-icon strip and let the connection stand) OR it's genuinely deferred (then suppress the sleep×mood card and seed data until the ramp ships). One source of truth, no mixed messaging.
- **Pros:** Removes a flat-out contradiction the user can see — directly raises 'match between system and real world'; Small, self-contained, mostly copy + gating logic; Either choice is fine; the win is consistency
- **Cons:** If sleep stays in, a bed-icon strip needs a no-ramp visual that still reads as ordinal (or accept it's binary good/poor for now); If sleep is pulled, the connections section loses a card and looks barer; Touches multiple files to keep the story aligned
- **Brand fit:** Strong. DESIGN.md already treats sleep as deferred (bed icon, ramp later, DESIGN.md:58,106); the fix is just honoring that consistently. Honesty is on-brand.

**↳ Recommendation:** Ship Direction C now — the sleep contradiction is a visible correctness bug and a near-free fix; my lean is 'tracked-but-unramped': keep the sleep×mood signal but replace 'not tracked yet' with a bed-icon sleep strip labeled honestly (e.g. good/poor until the ramp lands), so the chip stops fighting the card. On horizon, do Direction A (rolling default) to kill the start-of-month empty screen, and treat Direction B (all-time) as a deliberate later enhancement once the container (Thread 1) and trust (Thread 3) are settled — not before.


**🟡 Your decision:** Make two calls: (1) the time window — calendar month [status quo], rolling 30 days [recommended default], or add selectable ranges incl. all-time; and (2) sleep's single posture — tracked-but-unramped (bed strip, keep the connection, drop the chip) [recommended] vs genuinely deferred (pull the sleep card + seed data until the ramp ships).


## Wildcards

- 'One thing this month' as the whole screen: replace the five-section tour with a single Fraunces sentence the app is most confident about ('You showed up 14 days. Mornings were your sharpest.') on warm paper, and put ALL the bespoke viz behind one quiet 'See the detail.' The most radical expression of the ADHD north star — the insight IS the screen; charts are optional. Highest risk: buries genuinely good visualizations and demands the app pick one honest headline.
- A weekly ambient 'pollen note' instead of an on-demand dashboard: once a week Squirl quietly composes one gentle observation ('This week leaned calmer than last') as a soft, non-notifying entry the user finds when they open the app — insight that comes to them, paced, never nagging. Fits 'the app slightly calmer than you'; risk is it drifts toward the engagement-loop posture the product explicitly rejects, so it must never push or badge.
- Texture-as-data: render the month not as charts but as a single generative 'paper grain' field where each check-in adds a mark and dominant mood tints the warmth of the page — a beautiful, glanceable, non-numeric mirror that sidesteps scores and self-judgment entirely. Deeply on-brand for Paper & Pollen and the no-emoji-faces ethos; risk is it becomes decorative rather than legible, so it would need to coexist with a precise mode, not replace it.
