# Onboarding — Brainstorm

> Divergent exploration (superpowers-style) from [the critique brief](ux-critique-onboarding.md). Each thread ends in a **decision that's yours**. Feeds Spec Kit.


**North star:** First-run's one job is to deliver the "relief, then permission" promise and get an ADHD user to their first captured thought in under a minute — not to run a setup ceremony of grant + 150 MB download before the app does anything for them.


## Thread 1 — Thread 1 — The shape of first-run: ceremony vs. immediate reward (seeds 1, 2, 4)

**Question:** Is first-run a 3-step setup gate (welcome → grant mic → download model) the user must clear before the app is usable, or a single warm welcome that drops them straight into capturing, with permission and the model handled just-in-time?


*Why it matters:* For a time-blind, overwhelm-sensitive audience, three gates before any reward is exactly the friction that gets these apps deleted on day one. The download step today hard-gates exit on whisperComplete ([OnboardingView.swift#L266](app-four/Views/Onboarding/OnboardingView.swift#L266)) — a user on cellular or weak Wi-Fi can't reach the app at all until ~150 MB lands. Yet the app already recovers a missing mic permission gracefully at point-of-use ([CheckInView.swift#L39-L46](app-four/Views/CheckIn/CheckInView.swift#L39)), which means most of this ceremony is redundant.


### ▸ A. Welcome-only, everything just-in-time  *(effort L · feature)*
Onboarding becomes ONE screen: the brand promise + a single 'Start' that lands on the Check-in hub. Mic permission is requested by the OS the first time they tap record (CheckInView already handles grant/deny/Settings). The transcription model downloads silently in the background on first launch; if a recording finishes before the model is ready, the audio is queued and transcribed when it lands — 'transcription will be ready shortly'.
- **Pros:** Fastest possible path to first capture — honors the under-a-minute north star literally; No dead-end on poor connectivity; the app is never non-functional on entry; Reuses the existing point-of-use permission recovery, deleting a redundant gate; Smallest, calmest first impression — pure 'relief, then permission'
- **Cons:** Audio recorded before the model finishes needs a queue + 'pending transcription' state that doesn't exist yet; Background download on cellular needs to respect the existing downloadOverCellular setting ([AppSettings.swift#L10](app-four/Models/AppSettings.swift#L10)) or it's a surprise data charge; User isn't told up-front why a recording might not transcribe instantly — needs a gentle inline affordance
- **Brand fit:** Strongest fit. 'The app always slightly calmer than you' + 'one primary action per screen' (DESIGN.md#L11,L72). A single Fraunces welcome on warm paper is the most on-brand first 3 seconds.

### ▸ B. Keep three steps, but ungate the download  *(effort M)*
Preserve welcome → permission → model, but the model step no longer blocks exit. It shows 'Setting up transcription in the background' with a quiet progress affordance and a primary 'Start capturing' that's always enabled. Download continues after dismissal; the queue handles any recording made before it finishes.
- **Pros:** Removes the single worst failure mode (the connectivity dead-end) with minimal restructuring; Keeps the well-built download state machine and resumable retry ([OnboardingViewModel.swift#L43](app-four/Views/NoteExtraction/../Onboarding/OnboardingViewModel.swift#L43)) intact; Still sets expectations explicitly that a model is downloading
- **Cons:** Still three screens of ceremony before reward — only marginally faster; Two places now teach permission (here + CheckInView), risking double-prompt unless seeded from AVAudioApplication.recordPermission on appear; The 'background' framing on a screen that's clearly a setup step is slightly incoherent
- **Brand fit:** Decent. Less ceremony-forward than today, but three sequential gates still reads as a setup wizard, which is the category posture Squirl diverges from.

### ▸ C. First run IS a check-in  *(effort L · feature)*
Drop the user directly onto a lightly-dressed Check-in hub with a one-line coach-mark ('Tap to capture your first thought — it stays on this device'). The crescent breathes. Tapping record triggers the OS mic prompt inline; the model downloads in the background. The 'onboarding' is learning-by-doing, with no separate flow at all.
- **Pros:** Zero separation between learning and using — lowest possible executive-function load; The very first action produces the core reward ('I said it and it's captured', DESIGN.md#L86); Teaches the primary gesture by having them do it, not read about it
- **Cons:** No room to set the privacy story before the mic prompt — the OS dialog may feel abrupt without a beat of context first; Harder to A/B or instrument; 'did they understand the app' is fuzzier; Riskiest if first capture fails (no mic, no model) — recovery must be flawless or the first impression is a broken tap
- **Brand fit:** On-brand in spirit (effortless, in-and-out) but risks under-delivering the 'permission' half of 'relief, then permission' — that emotional beat wants at least one framed sentence before the OS dialog.

**↳ Recommendation:** Direction A (welcome-only, just-in-time). It's the truest expression of the north star and the design system's 'always slightly calmer than you', and it deletes the connectivity dead-end entirely. C is too abrupt on the privacy beat; B is a half-measure that keeps the ceremony. The real cost of A is the 'recording-before-model-ready' queue — but that capability is worth building regardless, because the same dead-end can hit any user whose model download fails later. Treat A as the target and the background-transcription queue as its enabling sub-feature.


**🟡 Your decision:** Decide the first-run shape: (A) collapse to a single welcome screen with mic + model handled just-in-time [needs a background-transcription queue], (B) keep three steps but ungate the download, or (C) no onboarding screen at all — land on a coached Check-in hub. This choice sets scope for everything below.


## Thread 2 — Thread 2 — What a Paper & Pollen first-run looks and feels like (seeds 5, 6)

**Question:** What is the ONE signature visual and typographic moment that makes the first 3 seconds read as 'relief, then permission' and unmistakably Squirl — and do we teach the glyph language here or trust users to learn it in context?


*Why it matters:* This is the most identity-defining screen in the app, and today it renders in iOS-default blue-tint-on-white system fonts ([OnboardingView.swift#L38,L69,L74](app-four/Views/Onboarding/OnboardingView.swift#L38)) — a P0 brand regression that makes first-run look like a blander, different app than the one they're about to use. The signature asset to fix it already exists and ships.


### ▸ A. Lead with the living crescent  *(effort S · quick)*
Replace the static waveform/mic/brain SF Symbols with the real CrescentRing ([CrescentRing.swift](app-four/Views/CheckIn/CrescentRing.swift)) breathing at rest, on warm paper (Theme.background), under a Fraunces headline. The same green→amber arc the user will meet on every check-in becomes the face of the welcome — first-run previews the heartbeat of the app, not a stock glyph.
- **Pros:** Continuity: the first thing they see is the exact element they'll tap forever after; The slow breathing motion (~5s) literally performs 'calmer than you' before a word is read; Zero new asset cost — it already exists, ships, and honors Reduce Motion (collapses to a static glow)
- **Cons:** The crescent currently lives inside CheckIn; lifting it to Onboarding needs a small shared-component move; If Thread 1 lands the user straight on the hub (A/C), a crescent welcome could feel redundant with the hub's own crescent
- **Brand fit:** Perfect. This IS the brand's signature motion (DESIGN.md#L80-L82). Nothing else competes.

### ▸ B. Full token pass, keep the hero glyphs  *(effort S · quick)*
Minimal-risk fix: wrap every step in Theme.background, swap Color.accentColor→Theme.accent, .green→Theme.statusDone, .red→Theme.danger, and replace .largeTitle/.body with Typography roles (Fraunces/DM Sans) — but keep representational SF Symbols, just tinted bronze/meadow and swapping brain.head.profile for something less surveillance-coded.
- **Pros:** Kills the P0 regression fast with no architectural change; Lowest effort; purely presentation-layer per the brief's own fix column; Safe if first-run shape is still unsettled
- **Cons:** Still SF Symbols — the glyph language and the signature crescent stay absent on the one screen that should define them; Tinted system icons are 'less wrong', not 'on-brand'
- **Brand fit:** Acceptable floor. Removes the off-brand signal but doesn't add the brand's actual voice.

### ▸ C. Animated glyph primer (sprout / lightning / aperture)  *(effort L · feature)*
A short, optional moment that introduces the four signal glyphs as a living legend — sprout opening, lightning filling, aperture tightening — so the abstract vocabulary has a first anchor before users meet it in Insights/Edit.
- **Pros:** Front-loads the one genuinely abstract thing in the app (glyphs aren't self-explanatory like emoji faces); A beautiful, ownable moment that doubles as brand statement
- **Cons:** The glyphs are still SF Symbols in code today; the SwiftUI Shape port is an open, unbuilt feature (DESIGN.md#L61,L115) — this can't ship until that does; Adds a teaching screen, raising first-run friction — directly against the under-a-minute goal; Teaching a legend out of context is the weakest way to learn; in-context labels ('2 · scattered') already teach on first real use
- **Brand fit:** On-brand visually but off-brand in posture — it's a tutorial, and the system prizes near-zero first-run friction and learning-in-context.

**↳ Recommendation:** Direction A (living crescent) as the hero, sitting on top of Direction B's token pass as the non-negotiable baseline — do B regardless; it's the P0 fix. Skip C: the glyphs teach themselves in context with their inline labels, and gating first-run on the unbuilt Shape port couples two features that shouldn't be coupled. The crescent + Fraunces on warm paper is the single signature moment, at S effort, using assets that already exist.


**🟡 Your decision:** Confirm the hero treatment: (A) lift the breathing CrescentRing into the welcome as the signature visual [recommended, pairs with the mandatory token pass], or (B) token-pass only with tinted SF Symbols. And rule on the glyph primer (C): teach glyphs in first-run, or trust in-context learning? (Recommend: trust context.)


## Thread 3 — Thread 3 — Permission & model posture: insist, proceed, or persuade (seeds 3, 4)

**Question:** When the mic is denied or the network is bad, what's the calmest posture — gently insist via a Settings deep-link, quietly proceed (typed notes still work), or explain the on-device privacy story harder to earn the grant — and where exactly is the line between reassurance and nagging for this audience?


*Why it matters:* ADHD users are allergic to nags; medication in this very app deliberately never nags, never goes red (DESIGN.md#L86-L87). But today the permission step advances on denial with no recovery path ([OnboardingView.swift#L45-L50](app-four/Views/Onboarding/OnboardingView.swift#L45)), and the download foregrounds 'Whisper' and '~150 MB' to a non-technical user. The posture has to win trust without ever making them feel they broke setup.


### ▸ A. Quietly proceed, recover at point-of-use  *(effort S · quick)*
Never block on permission in onboarding at all. If the OS prompt is denied (or skipped), say nothing alarming — the app opens, typed notes work immediately, and the moment they tap record, the existing CheckInView 'Open Settings' alert ([CheckInView.swift#L39-L46](app-four/Views/CheckIn/CheckInView.swift#L39)) handles recovery in context. One soft confirmation on skip: 'No problem — you can turn the mic on anytime in Settings.'
- **Pros:** Zero nag; the denial is a non-event, exactly like a worn-off med going quiet; Reuses shipped recovery code; permission is taught where it's actually needed; Typed notes mean a denied mic never produces a broken app
- **Cons:** Some users who'd have granted with one more sentence of privacy context won't be asked again until they try to record; Requires seeding initial state from AVAudioApplication.recordPermission on appear to avoid a redundant prompt for already-granted users ([OnboardingViewModel.swift#L18,L38](app-four/Views/Onboarding/OnboardingViewModel.swift#L18))
- **Brand fit:** Highest fit. 'Forgiving, no penalty' + the no-nag posture (DESIGN.md#L72,L86). The denial-as-non-event mirrors how medication is handled.

### ▸ B. Earn the grant with the privacy story (then proceed)  *(effort M)*
Keep a permission beat, but reframe it as reassurance not a gate: lead with the on-device privacy promise in Fraunces ('Your voice never leaves this device'), make 'Allow microphone' the warm primary, and on denial switch the button to 'Open Settings' with one calm line in Theme.danger-but-warm ('Mic's off — you can enable it in Settings'). No auto-advance on denial; always a 'Skip, I'll type' secondary.
- **Pros:** Privacy-first is Squirl's core differentiator; stating it before the OS dialog raises grant rates honestly; Implements the brief's P1 fix (branch on the Bool, Settings deep-link) directly; Still escapable — typed notes path preserved
- **Cons:** Keeps a dedicated permission screen, adding friction vs. Thread-1 Direction A; Risk of over-explaining; one sentence too many tips reassurance into a sales pitch; Two permission teachers (here + CheckInView) unless carefully de-duped
- **Brand fit:** Good if kept to one Fraunces line. The privacy story is brand-core; the danger of nagging is real but manageable.

### ▸ C. Soften the model story to plain language + reachability  *(effort M)*
Independent of permission: never say 'Whisper' or raw '~150 MB' as a wall. Say 'Setting up on-device transcription' with a soft '(a one-time download, about a minute on Wi-Fi)'. Pre-check reachability so an offline user sees 'You're offline — transcription will set up when you reconnect; you can start typing now' instead of tapping into a failure ([OnboardingView.swift#L175](app-four/Views/Onboarding/OnboardingView.swift#L175)).
- **Pros:** Removes jargon leak to a non-technical audience (brief P1); Time/data reassurance ('about a minute on Wi-Fi') lowers abandonment anxiety for a time-blind user; Reachability pre-check converts a frustrating dead-end into a calm 'later'
- **Cons:** Reachability adds a dependency (NWPathMonitor) and an edge-case matrix; 'About a minute' is a promise that varies wildly by connection — risks feeling wrong; Mostly copy/affordance, not a posture shift — best combined with A or B, not standalone
- **Brand fit:** On-brand: plain, warm, honest. The voice the rest of the app uses.

**↳ Recommendation:** Direction A for permission (quietly proceed, recover at point-of-use) + Direction C's plain-language/reachability copy for the model. A is the most on-brand and reuses shipped recovery; B's privacy beat is worth one Fraunces sentence on the welcome itself rather than a whole screen. Critically: regardless of choice, seed permission state from recordPermission on appear so already-granted users are never re-prompted, and harden completeOnboarding so a failed SwiftData save can't silently strand the user on a dead button ([OnboardingViewModel.swift#L101-L112](app-four/Views/Onboarding/OnboardingViewModel.swift#L101)).


**🟡 Your decision:** Pick the permission posture: (A) never gate, recover at point-of-use with a soft skip confirmation [recommended], or (B) a reassurance-framed permission screen with Settings deep-link on denial. Separately, approve (C): drop 'Whisper'/'150 MB' jargon for plain language, and decide whether an offline reachability pre-check is in scope now or deferred.


## Thread 4 — Thread 4 — Replayability & the long-term model-management story (seeds 7, 8)

**Question:** Should first-run be replayable from Settings, where does model management (re-download, delete to reclaim space, switch size) live, and what's the failure philosophy across the whole flow so a distractible user never feels they 'broke' setup?


*Why it matters:* Today onboarding is single-shot: once hasCompletedOnboarding flips, there's no replay and no model-management surface anywhere (grep of Views/Settings found none), yet a skipped model leaves recording silently non-functional with no obvious fix. For an audience that abandons at the first sign they've broken something, the recovery story can't be an afterthought.


### ▸ A. Settings 'Transcription' row as the single home  *(effort M)*
Don't make onboarding replayable. Instead add one Settings row — 'Transcription model' — that shows state (Ready / Downloading / Not set up / Failed) and offers Download / Retry / Delete to reclaim space. Onboarding stays single-shot; everything post-first-run lives in Settings, the natural home for model management. A skipped or failed model surfaces a gentle one-line hint at the Check-in hub linking straight to that row.
- **Pros:** Keeps first-run lean (no replay machinery) while giving the model a permanent, discoverable home; Re-download, delete-to-reclaim, and future size-switching all have one obvious place; Honors downloadOverCellular ([AppSettings.swift#L10](app-four/Models/AppSettings.swift#L10)) which currently isn't consulted by the download path
- **Cons:** New Settings UI + wiring AIModelService status/delete into it; A 'skipped model' hint at the hub needs a non-naggy treatment so it doesn't read as a chore
- **Brand fit:** Strong. Progressive disclosure: setup state lives in Settings, not cluttering the daily path. Calm, no nag.

### ▸ B. Full replayable onboarding from Settings  *(effort M)*
Add a 'Replay welcome' entry in Settings that re-runs the whole flow. Model management is folded back into that replayed flow rather than getting its own row.
- **Pros:** Conceptually simple — one flow, reachable again; Lets a user re-read the privacy story if they want it
- **Cons:** Re-running a setup wizard to re-download a model is heavy and indirect vs. a single tappable row; Couples 'see the intro again' (rare) with 'manage my model' (recurring) — wrong granularity; More state to manage (re-entering a completed flow) for little daily benefit
- **Brand fit:** Weaker. Re-entering a wizard is ceremony; the app prefers direct, low-friction controls.

### ▸ C. Failure-philosophy pass as a cross-cutting principle  *(effort S · quick)*
Codify one rule for every failure in the flow — network dies, save fails, mic off, model skipped: the app never says 'error' in a way that implies the user broke it. Calm clay-toned copy (Theme.danger, 'warm clay, never raw red'), a quiet retry, an always-present way forward (typed notes), a success haptic on completion (Haptics.success exists, DESIGN.md#L72-note), and a verified save so completion can't silently fail ([OnboardingViewModel.swift#L111](app-four/Views/Onboarding/OnboardingViewModel.swift#L111)).
- **Pros:** Turns the brief's scattered edge-case findings (save failure, denial, offline) into one coherent posture; Directly serves the abandonment-sensitive audience — no failure is ever a dead end or a self-blame moment; Mostly principle + small fixes; reuses existing Haptics/Theme tokens
- **Cons:** Cross-cutting, so it touches several spots rather than one tidy feature; Hard to 'finish' — it's a quality bar, not a discrete deliverable
- **Brand fit:** Definitional. 'Forgiving, no penalty', 'warm clay never raw red', success = captured (DESIGN.md#L72,L86). This is the brand's nervous system.

**↳ Recommendation:** Direction A (Settings 'Transcription' row) as the structural answer, governed by Direction C's failure philosophy as the quality bar over the whole flow. Reject B: re-running a wizard is the wrong tool for a recurring model action. A gives the model a permanent home and keeps first-run lean; C ensures every failure across both first-run and that Settings row stays calm and recoverable. Together they also fix the brief's silent-save-failure and missing-recovery findings.


**🟡 Your decision:** Decide the model-management home and replay story: (A) a single Settings 'Transcription' row (state + download/retry/delete), with no onboarding replay [recommended], or (B) a fully replayable onboarding flow. And ratify (C) the failure-philosophy bar — calm clay copy, always-a-way-forward, verified save, success haptic — as a non-negotiable across the flow.


## Wildcards

- Skip the welcome screen, mail a postcard instead: the first launch lands on the Check-in hub with the crescent already breathing and ONE Fraunces line that fades in over the paper — 'Say anything. It stays here with you.' — then fades out. No buttons, no steps, no dots. The onboarding is a single sentence and a breath. Maximally on-brand for 'relief, then permission'; riskiest because it bets everything on the first tap working (mitigated by Thread-3A point-of-use recovery + typed-note fallback).
- Make the privacy promise physical, not textual: during the on-device model download, show a tiny looping animation of the data NOT leaving — a dot that travels from a phone glyph toward a cloud, hits an invisible wall, and curves back into the phone. It teaches 'on-device' viscerally in a way no paragraph can, turns unavoidable wait time into the brand's core trust message, and needs no jargon. Risk: cute-ness creep — must stay a quiet hairline animation, not a mascot.
- Seed the first check-in so the empty app is never empty: as part of (or instead of) onboarding, pre-write a gentle example day the user can open and explore — a sample check-in showing what mood/energy/focus glyphs and a summary look like — clearly marked 'Example · tap to dismiss'. Teaches the glyph language and the payoff in-context (Thread 2C's goal) without a tutorial screen, and removes the cold-start void. Risk: a fake entry in a privacy-first personal journal can feel like clutter or a violation of 'this is mine' — must be obviously removable and never counted in any stat.
