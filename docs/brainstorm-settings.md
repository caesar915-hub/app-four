# Settings — Brainstorm

> Divergent exploration (superpowers-style) from [the critique brief](ux-critique-settings.md). Each thread ends in a **decision that's yours**. Feeds Spec Kit.


**North star:** Settings exists to let an ADHD user adjust how Squirl behaves, trust that their journal stays private and theirs, and recover when the one active task (getting the transcription model installed) goes wrong — all without ever feeling configured-at, nagged, or lost.


## Thread 1 — T1 — The dead Reduce-Motion control & the calm-renderer contract

**Question:** Should Squirl offer its own in-app motion control at all, or only honor the iOS system setting it already obeys everywhere — and if it offers one, what is the single source of truth?


*Why it matters:* For an overwhelm-sensitive audience, a 'Reduce Motion' switch that does literally nothing (it writes UserDefaults["reduceMotion"] while all 7 animated views read @Environment(\.accessibilityReduceMotion), per the brief and confirmed in SettingsViewModel.swift#L22-L31) is worse than absent: the user flips it expecting calm, the breathing crescent keeps moving, and the app silently breaks a promise on the exact screen where they reached out for control. The concept is currently triplicated (UserDefaults vs orphaned AppSettings.reduceMotionEnabled vs the system env) and they can disagree arbitrarily.


### ▸ Honor-only (delete the toggle)  *(effort S · quick)*
Remove the in-app Reduce Motion toggle entirely; rely on iOS Settings > Accessibility > Motion, which every animation already reads. Delete UserDefaults["reduceMotion"] and the orphaned AppSettings.reduceMotionEnabled field. Optionally leave a single quiet, non-interactive footer line in the Accessibility section: 'Squirl follows your iOS motion settings.'
- **Pros:** One source of truth, zero drift — eliminates the P0 and the triplication root cause in one move; Matches DESIGN.md motion rule verbatim ('Honor Reduce Motion') and Apple HIG (don't shadow system accessibility prefs); Least code, least surface, least to maintain; nothing left that can rot into another dead control; An honest 'we defer to your system choice' is itself reassuring to a privacy/control-sensitive user
- **Cons:** Loses in-app discoverability — a user who wants calm but doesn't know the iOS setting exists gets no in-app path; The footer pointer can't deep-link reliably to the exact iOS toggle, only to the app's own Settings page via UIApplication.openSettingsURLString
- **Brand fit:** Strongest. 'The app always slightly calmer than you' means it should obey the user's existing calm preference, not ask them to re-declare it. A single muted-ink footer is pure Paper & Pollen restraint.

### ▸ Override-OR (keep toggle, make it real)  *(effort M)*
Keep an app-level toggle but define one canonical value (an @Observable AppSettings field or single @AppStorage key) and change every animation gate to `systemReduceMotion || appReduceMotion`, so system-ON always wins and the app switch can only add calm, never remove it. Label it 'Reduce motion in Squirl'.
- **Pros:** In-app discoverability for users who never touch iOS Accessibility; Lets Squirl be calmer than the rest of the phone — a deliberate posture that fits the brand; OR-semantics make the relationship unsurprising (system-ON can never be overridden to motion-ON)
- **Cons:** Requires touching all 7 animated views to read the combined value — real blast radius, real regression risk; Two switches for one concept invites 'why doesn't the app one turn it back ON when iOS is ON?' confusion unless the label is perfect; More state to keep honest forever; this is the failure mode we're trying to exit
- **Brand fit:** Good if framed as additive-calm-only. Risks mild clutter; mitigated by a clear footer.

### ▸ Calm Mode (reframe, don't just gate motion)  *(effort L · feature)*
Replace the narrow motion toggle with a single broader 'Calm mode' that, when on, stills the crescent breathing, drops onset pulses, and softens transitions — a posture switch, not an accessibility shadow. Still OR'd with system Reduce Motion so it can only ever quiet things.
- **Pros:** Speaks the user's language ('I want it calmer') instead of an OS-engineering term; Bundles future quiet-ness levers (pulses, glows) under one honest control; Differentiates from a generic settings screen — a brand gesture, not a checkbox
- **Cons:** Scope creep risk — 'calm' is fuzzy and could absorb endless tuning requests; Overlaps conceptually with system Reduce Motion; needs crisp copy so it doesn't read as a duplicate; Most design + build work of the three
- **Brand fit:** Most on-brand in spirit (calm is the north star) but the heaviest; risks over-elevating a setting that most users will set once.

**↳ Recommendation:** Ship Honor-only now (S, kills the P0 and the triplication today), and park Calm Mode as a deliberate future feature rather than a settings checkbox. Override-OR is the trap: it keeps the exact two-sources-of-truth shape that caused this bug, for a control most users touch once. Honoring the system setting is both the correct engineering answer and the on-brand one — the app should already know you prefer calm.


**🟡 Your decision:** Choose the motion posture: (A) delete the in-app toggle and honor iOS only [recommended], (B) keep an OR'd app override, or (C) invest in a broader 'Calm mode'. Either way, approve removing UserDefaults["reduceMotion"] and AppSettings.reduceMotionEnabled.


## Thread 2 — T2 — Recovery when the model download fails (the one active task on this screen)

**Question:** When the required Whisper download fails or stalls, what is the right recovery posture for a low-executive-function user — silent auto-retry, one clear Retry button with a plain-language cause, or proactive pre-flight guidance ('you're on cellular, ~150 MB')?


*Why it matters:* This is the only screen where the user is actively trying to make something happen, and failures are currently swallowed to a log (SettingsViewModel.swift#L101-L103) — the status dot just silently reverts with no explanation. The model size (~150 MB) is already named once in onboarding (OnboardingView.swift#L175) but never shown at the Settings re-download point, and the cellular toggle and the failure it can cause are disconnected. For a time-blind, easily-discouraged user, a silent failure on a required asset is a dead end with no exit.


### ▸ Plain-cause Retry row  *(effort M)*
Add errorMessage: String? to the VM, set it in the catch blocks mapped to readable causes (no network / not enough space / cellular downloads off), and render an inline error state inside ModelDownloadRow with a single ghost-pill 'Try again'. Tie 'cellular off + on cellular' to its specific message with a one-tap 'Allow on cellular' shortcut.
- **Pros:** Directly closes the P1 error gap with the smallest honest surface; Cause-specific copy means the user knows what to DO, not just that it broke — critical for low executive function; Connects the cellular toggle to the failure it actually causes, fixing a real disconnect; Inline (not an alert) keeps it calm and non-interrupting
- **Cons:** Requires mapping service errors to user causes (network/space/cellular) — some error types may be coarse; One more state in ModelDownloadRow to design and a11y-label
- **Brand fit:** Strong. A quiet inline 'Try again' in muted ink with an effect-describing line matches the existing footer voice; no red alarm, no nag.

### ▸ Pre-flight clarity (prevent, don't just recover)  *(effort S · quick)*
Before download, show the size and conditions: '~150 MB · Wi-Fi recommended' under the row, and if on cellular with the toggle off, surface that BEFORE the tap rather than failing after. Pair with the Retry row for the residual failures.
- **Pros:** Stops the most common avoidable failure (metered-data surprise) before it happens — kind to ADHD users on capped plans; Reuses a number the app already knows (~150 MB from onboarding); Sets honest expectations: a big download announced is calmer than a silent stall
- **Cons:** Doesn't itself handle genuine mid-download failures — still needs a recovery path; Slightly more chrome on an otherwise clean row
- **Brand fit:** Very on-brand — 'forgiving, no penalty, progressive disclosure.' Telling someone the cost before they commit is exactly the calm posture.

### ▸ Silent auto-retry with a quiet ceiling  *(effort M)*
On transient failure, retry automatically 1–2 times with backoff; only surface UI if it still fails, then fall back to the Retry row. The happy path becomes invisible self-healing.
- **Pros:** Lowest user effort — many flaky-network failures resolve without the user ever knowing; Fewest decisions pushed onto a low-executive-function user
- **Cons:** Hidden retries on a ~150 MB asset can silently burn metered data — actively user-hostile on cellular; Masks real problems (no space won't fix itself); risks a longer silent dead-end than today; Hard to convey progress honestly while secretly retrying
- **Brand fit:** Mixed. Effortless in spirit, but silently consuming data conflicts with the privacy/control-respecting posture; only acceptable if strictly Wi-Fi-gated.

**↳ Recommendation:** Combine Pre-flight clarity (S) + Plain-cause Retry row (M) — prevent the avoidable failure and recover the rest with cause-specific copy and a one-tap fix. Skip blind auto-retry, or scope it to Wi-Fi-only single retries at most; silently re-pulling 150 MB on cellular betrays the same metered-data trust the cellular toggle is meant to protect. Also surface a one-line success-and-cancel: let the user cancel a long download (today the row hard-blocks taps while downloading, ModelDownloadRow.swift#L46).


**🟡 Your decision:** Approve adding (1) a pre-download size/conditions line, (2) an inline cause-specific error + Retry state with a cellular shortcut, and (3) a cancel affordance during download. Decide whether any auto-retry is allowed and if so cap it to Wi-Fi-only.


## Thread 3 — T3 — Privacy & data ownership: make the promise persistent and the journal portable

**Question:** For a privacy-first, on-device journal, what minimal 'how your data is handled' surface belongs in Settings, and should Settings own data portability (export/backup) — and in what format that keeps the privacy promise?


*Why it matters:* Squirl's whole pitch is 'all private, all on this device' — but that promise is spoken once in onboarding (OnboardingView.swift#L78/L122/L175) and then never re-surfaced; Settings shows only a version string. There is no export/backup anywhere in the codebase (grep: no fileExporter/ShareLink/backup in the data layer), yet the store is deliberately excluded from iCloud backup — so a user who loses or switches phones loses their entire journal with no exit, and 'Clear All Data' is a one-way door with nothing to grab first. For an audience that already distrusts surveillance-y apps, a visible, honest data home is trust infrastructure, not a nice-to-have.


### ▸ Quiet trust footer (minimum viable)  *(effort S · quick)*
Add a short 'Your data' section: one or two muted-ink lines restating the on-device promise (reusing onboarding copy), plus open-source acknowledgements (WhisperKit, Fraunces/DM Sans/IBM Plex Mono under OFL). No export yet.
- **Pros:** Persists the privacy promise where users look for it; honest and cheap; Satisfies OFL/library attribution obligations Squirl currently doesn't surface anywhere; Pure copy + static rows — no data-layer risk
- **Cons:** Doesn't solve the real ownership gap — you still can't get your journal out before clearing or switching devices; A privacy statement with no export can read as words without follow-through to a skeptical user
- **Brand fit:** Native Paper & Pollen: a calm, plain-language statement in muted ink. The voice already exists in the onboarding copy.

### ▸ Export-your-journal (encrypted archive)  *(effort L · feature)*
Add 'Export my journal' → a single password-protected/encrypted archive (recordings + check-ins + extracted signals) via ShareLink/fileExporter, framed as 'a copy you control'. Pair with the trust footer. Make it the reassuring step shown right above Clear All Data.
- **Pros:** Closes the device-loss / device-switch dead end and gives Clear All Data a safety net first; Encrypted-by-default keeps the privacy promise intact even once data leaves the sandbox; Turns a passive privacy claim into a demonstrable user right — strong trust signal for this audience
- **Cons:** Real engineering: serialize the SwiftData graph + bundle audio files + encrypt + handle large sizes/cancellation; Without a matching import, an export is a one-way escape hatch (still useful, but incomplete); Password UX adds friction and a lost-password failure mode for a forgetful audience
- **Brand fit:** On-brand if framed as 'yours to keep,' calm and non-technical. Avoid clinical 'export' jargon in the label; 'Save a copy of my journal' reads warmer.

### ▸ Full portability (export + import / migrate)  *(effort L · feature)*
Round-trip: export an encrypted archive and import it on a new device, positioning Settings as the migration home (the substitute for the deliberately-excluded iCloud backup).
- **Pros:** Genuinely solves new-phone migration — the actual user need behind 'no iCloud backup'; Complete data-ownership story end to end
- **Cons:** Largest scope by far — schema-versioned import, conflict/merge rules, validation; a whole mini-feature; Import-merge correctness is exactly the kind of edge-case work that bites later; Likely its own Spec Kit spec, not a Settings tweak
- **Brand fit:** Aligned with the privacy-first identity, but the weight argues for its own spec rather than riding this critique.

**↳ Recommendation:** Ship the Quiet trust footer now (S) — it's pure win and overdue (the OFL attributions are currently absent). Spec Export-your-journal (encrypted archive) as a near-term feature and deliberately place it directly above Clear All Data so the destructive action always offers 'save a copy first.' Treat full import/migrate as a separate, later Spec Kit effort — don't let it block the footer or the export. Naming matters: avoid 'export'; use 'Save a copy of my journal (yours to keep).'


**🟡 Your decision:** Confirm (1) adding a 'Your data' privacy + acknowledgements footer now, and (2) whether to greenlight an encrypted single-file journal export as the next Settings feature (and whether import/migrate is in scope or deferred to its own spec). Pick the export format intent: encrypted archive [recommended] vs plain JSON vs Health-style.


## Thread 4 — T4 — Clarity & legibility: title, the 'Medical Context Prompt' label, and the typography exemption

**Question:** Should Settings (and every tab) carry a visible title, how do we rename opaque controls into effect-describing language, and does the native-iOS grouped-List look get an explicit exemption from the Paper & Pollen typography rule or get rebranded?


*Why it matters:* Three recognition/clarity issues stack here. (1) Settings opens straight into 'AI Models' with no 'Settings' heading — but I confirmed EVERY tab passes title: "" (InsightsView/CalendarLibraryView/CheckInView all do), and ScreenContainer already wires .navigationTitle(title) + inline, so a title is one string away and also gives VoiceOver a landmark it currently lacks. (2) 'Medical Context Prompt' is clinical jargon filed under Accessibility, where it doesn't belong. (3) Section headers/row text render in system font because it's a vanilla .insetGrouped List — an unflagged drift from the design system's 'don't use SF as display/body' rule. All three are recognition-over-recall failures that tax a distractible scanner.


### ▸ Minimal clarity pass (title + rename + relocate)  *(effort S · quick)*
Pass title: 'Settings' to ScreenContainer (free VoiceOver landmark, inline title). Rename 'Medical Context Prompt' → 'Recognize medication names' and move it out of Accessibility into the Check-in/Transcription section with a footer like 'Helps transcription spell medication and side-effect terms correctly.' Leave list chrome as native system font (a defensible HIG stance) but DOCUMENT the exemption in DESIGN.md.
- **Pros:** Highest clarity-per-effort: fixes the missing landmark, the jargon, and the mis-filing in a few edits; Effect-describing rename matches the section's existing strong footer voice; Documenting the native-chrome exemption converts an unflagged drift into a deliberate, defensible decision
- **Cons:** A Settings-only title creates inconsistency with the other (intentionally) title-less tabs — see next direction; Keeps system fonts in the List, so brand purists still see drift even if it's now sanctioned
- **Brand fit:** Clean. Plain-language labels and an honest documented exemption are squarely on-brand; native Settings chrome is a legitimate HIG-aligned choice.

### ▸ App-wide title decision (resolve the inconsistency at the root)  *(effort M)*
Treat the empty title as the real question: either give all four tabs inline titles (consistency + VoiceOver landmarks everywhere) or formally ratify 'no visible titles' as a design stance AND add VoiceOver-only headings so landmarks exist without visible chrome.
- **Pros:** Fixes the inconsistency at its source instead of making Settings a one-off; Guarantees VoiceOver landmarks on every tab regardless of the visible-title choice; A single ratified rule prevents this resurfacing on every future tab review
- **Cons:** Bigger surface — touches all four tab views and needs an explicit DESIGN.md ruling; Visible titles may clash with the minimalist look the title-less tabs were going for (Calendar/Check-in lean on glyphs and the crescent, not a header)
- **Brand fit:** On-brand either way IF ratified; the risk is adding visual weight (a big nav title) to screens designed to feel airy.

### ▸ Rebrand the chrome (Paper & Pollen Settings)  *(effort L · feature)*
Replace the vanilla .insetGrouped List with brand-styled section headers (Typography.subheadline) and Fraunces/DM Sans row labels — possibly custom card-style sections — so Settings visually matches the other tabs instead of looking like stock iOS.
- **Pros:** Removes the typography drift entirely; Settings stops looking like a different app; Opportunity to apply the .card()/hairline language the rest of the app uses
- **Cons:** Highest effort and risk: fighting List chrome for fonts/spacing is fragile and easy to get subtly wrong at Dynamic Type/AX sizes; Apple HIG arguably WANTS Settings to use system grouped chrome for learnability — rebranding can reduce familiarity; Pure aesthetics; doesn't improve a single user task (title/jargon/errors matter far more)
- **Brand fit:** Maximally on-brand visually, but arguably over-investing brand effort where system familiarity serves the user better.

**↳ Recommendation:** Do the Minimal clarity pass now (S): set title: 'Settings', rename to 'Recognize medication names' + relocate under Check-in/Transcription with a footer, and explicitly document a native-chrome typography exemption in DESIGN.md. Then make a one-time app-wide title ruling (direction 2) so the Settings title isn't an orphan — most cleanly: ratify 'no visible titles' for the glyph-led tabs but require VoiceOver headings everywhere, OR accept inline titles on all four. Don't rebrand the List chrome — the user wins from the title/jargon/error fixes, not from re-fonting a settings list, and native chrome is the more learnable choice.


**🟡 Your decision:** Approve the S-pass (Settings title + 'Recognize medication names' rename/relocate + documented typography exemption). Then make the app-wide call: visible inline titles on all tabs, or formally keep them title-less with VoiceOver-only headings? And confirm Settings keeps native system List chrome rather than a full Paper & Pollen rebrand.


## Wildcards

- Replace 'Clear All Data' with a two-step 'Pack up & start fresh': tapping it first offers 'Save a copy of my journal' (the T3 export) and only then the wipe — turning the scariest, most irreversible control into the discovery point for the safety net, so the destructive path and the backup path are the same path. Fits the 'forgiving, no penalty' posture and means nobody clears without being offered an out.
- Make Settings adaptive/progressive: hide advanced rows (cellular, language, debug-adjacent) behind a single quiet 'More options' disclosure, so first-run Settings shows only ~4 things (model status, calm, your data, clear). Less is calmer for an overwhelm-prone audience, and it directly answers seed 7's 'how much configuration before it becomes overwhelm' — default to almost none, reveal on demand.
- Surface the dead defaultLanguage field as a real, tiny 'Transcription language' picker IF (and only if) WhisperKit multi-language is actually wired — otherwise delete the field. Right now AppSettings.defaultLanguage is declared and referenced nowhere outside its own model (confirmed by grep), so it's either a missing feature or dead code; the brainstorm forces the call. For non-English ADHD users, on-device transcription in their language is a real inclusion win, not a config knob.
