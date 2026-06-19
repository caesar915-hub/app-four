# Squirl — Product Requirements Document (PRD)
## Voice-First ADHD Check-In Journal · MVP v0.9

**Document Version:** 1.0  
**Date:** 2026-06-15  
**Author:** Hermes (AI Product Assistant)  
**Status:** Draft for Review  
**Target:** TestFlight v0.9 (June 24, 2026) → App Store v1.0 (July 6, 2026)

---

## 1. Product Overview

### 1.1 Vision
Squirl is an on-device, privacy-first iOS voice check-in journal for people with ADHD. Users voice-log (or type) a quick daily check-in in under a minute; the app transcribes, extracts structured signals (mood, energy, focus, sleep, medications, side effects, feelings), and surfaces personal patterns over time. Everything runs locally: transcription, extraction, and storage. No account, no server, no cloud by default.

### 1.2 Target User
**Primary:** Adults with ADHD (diagnosed or self-identified) who want to understand their patterns without the friction of traditional journaling.

**Secondary:** People with anxiety, depression, or chronic conditions who benefit from quick symptom tracking.

**Tertiary:** Healthcare providers (psychologists, psychiatrists) who want patients to track symptoms between sessions.

### 1.3 Core Value Proposition
> **"Say it and it's captured. No structure needed. No stigma. Just talk."**

### 1.4 Key Differentiators
| Feature | Squirl | Bearable | Daylio |
|---------|--------|----------|--------|
| Voice-first input | ✅ Native | ❌ Manual | ❌ Manual |
| ADHD-specific design | ✅ Built-in | ⚠️ Generic | ❌ Generic |
| 100% on-device privacy | ✅ Default | ⚠️ Cloud | ⚠️ Cloud |
| No gamification/streaks | ✅ By design | ❌ Streaks | ❌ Streaks |
| Medication tracking | ✅ Integrated | ✅ Yes | ❌ No |
| Auto-extraction (NLP) | ✅ Apple NL | ❌ Manual | ❌ Manual |
| Emoji-free design | ✅ Glyphs | ❌ Emoji | ❌ Emoji |

### 1.5 Success Metrics (v0.9)
- **Adoption:** 3+ check-ins per user per week (average)
- **Retention:** 50% of beta users active after 2 weeks
- **Quality:** <5% crash rate in TestFlight
- **Satisfaction:** NPS ≥ 40 from beta users

---

## 2. User Stories & Use Cases

### 2.1 Primary Use Cases

#### UC1: Morning Voice Check-In (The Core Loop)
**Actor:** User with ADHD  
**Trigger:** Morning routine, feeling "off," or reminder  
**Flow:**
1. Open app → lands on Check-in tab
2. Tap "Speak check-in" (or auto-starts if opened via widget/deep link)
3. App shows rotating crescent + "How are you, right now?"
4. User speaks freely for 30-60 seconds
5. Tap "Stop & save" → "Check-in saved" confirmation
6. App transcribes and extracts in background (5-15 seconds)
7. Results appear in Calendar and Insights

**Acceptance Criteria:**
- [ ] Recording starts within 1 second of tap
- [ ] Transcription completes within 15 seconds
- [ ] Extraction identifies ≥3 signals (mood, energy, focus, sleep, meds, feelings)
- [ ] User can review/edit extraction in detail view
- [ ] Total time from open to saved: <90 seconds

#### UC2: Medication Logging
**Actor:** User taking ADHD medication  
**Trigger:** Just took medication, or "Log meds" from hub  
**Flow:**
1. From Check-in hub, tap "Log meds"
2. Select medication name (or type new one)
3. Enter dose (e.g., "20mg")
4. Confirm time (defaults to now)
5. Save → appears in Calendar with medication bar

**Acceptance Criteria:**
- [ ] Log medication in <10 seconds
- [ ] Medication bar appears showing effect curve (empty→full→fade)
- [ ] Bar fades out when dose wears off (no alarm, no nag)
- [ ] Multiple doses tracked with correct ordinals

#### UC3: Pattern Discovery (Insights)
**Actor:** User reviewing weekly patterns  
**Trigger:** Curious about trends, or before doctor appointment  
**Flow:**
1. Open Insights tab
2. Scroll through 5 sections: breakdown, signals, averages, rhythm, connections
3. Tap any signal bead to see day detail
4. Tap day to see recording detail
5. Export or share summary (future)

**Acceptance Criteria:**
- [ ] Insights load within 2 seconds
- [ ] 5 sections scroll smoothly with snap-to-section
- [ ] Signal colors are distinguishable (colorblind-safe)
- [ ] Data shows ≥7 days of history

#### UC4: Review Past Check-In
**Actor:** User reviewing specific day  
**Trigger:** Want to remember what happened, or check medication timing  
**Flow:**
1. Open Calendar tab
2. Navigate to date (week/month view)
3. Tap day → see mood dot + medication indicators
4. Tap recording → detail view with transcript, signals, audio playback
5. Edit extraction if needed (toolbar pencil)

**Acceptance Criteria:**
- [ ] Navigate to any date in <3 taps
- [ ] Detail view loads in <1 second
- [ ] Audio playback works (seek, speed, etc.)
- [ ] Edit extraction saves corrections and trains personal lexicon

### 2.2 Secondary Use Cases

#### UC5: Type Note (Non-Voice)
**Actor:** User in quiet environment or prefers typing  
**Flow:** Check-in hub → "Type note" → signal pickers + note field → Save

#### UC6: Onboarding (First Launch)
**Actor:** New user  
**Flow:** Welcome → Permission request (mic) → Model download (optional) → Check-in hub

---

## 3. Feature Specifications

### 3.1 Core Features (v0.9 MVP)

#### F1: Voice Check-In (P0)
**Description:** Record, transcribe, and extract from voice input.

**Requirements:**
- [ ] Recording UI: idle hub → listening (rotating crescent) → saved confirmation
- [ ] Audio: 16kHz mono PCM, saved as M4A
- [ ] Transcription: WhisperKit (OpenAI Whisper Small) on-device, batch mode
- [ ] Live transcription: **disabled** in v0.9 (feature flag `liveTranscriptionEnabled = false`)
- [ ] Extraction: Apple NaturalLanguage (`NLNoteExtractor`) + personal lexicon
- [ ] Signals extracted: mood, energy, focus, sleep, medications, feelings, side effects, topics
- [ ] Processing: async background, no blocking UI
- [ ] Error handling: low disk space, mic permission denied, transcription timeout (300s)

**Technical Notes:**
- Transcription model preloaded during recording to avoid cold start
- WhisperKit unloaded before extraction handoff to free memory
- `Recording.applySummary()` writes to SwiftData, triggers `RecordingStore.save()`

#### F2: Medication Tracking (P0)
**Description:** Log medications with effect curve visualization.

**Requirements:**
- [ ] Quick log from Check-in hub or dedicated sheet
- [ ] Medication name + dose + time
- [ ] Effect curve: empty → full (onset) → fade (duration)
- [ ] No alarms, no "you're late" — goes quiet when worn off
- [ ] Multiple doses per day with correct ordinals
- [ ] Medication bar overlay on Check-in tab when dose is active

**Technical Notes:**
- `MedicationEvent` model with `name`, `dose`, `takenAt`, `durationHours`
- Bar fill calculated from `now - takenAt` vs `durationHours`
- Onset pulse: first 20 minutes shows gentle animation

#### F3: Calendar & Timeline (P0)
**Description:** Browse check-ins by date with mood/medication visualization.

**Requirements:**
- [ ] Week view: collapsible, day dots with mood color
- [ ] Month view: grid with mood dots, medication indicators
- [ ] Day timeline: chronological list of recordings
- [ ] Navigation: swipe between months, tap to select day
- [ ] Deep link: `whispernotes://checkin` switches to Check-in tab

**Technical Notes:**
- `CalendarLibraryView` with `CalendarHeaderView`
- `DayCard` components for timeline entries
- Two-way binding between week/month and day selection

#### F4: Insights & Analytics (P0)
**Description:** Surface patterns and trends from check-in data.

**Requirements:**
- [ ] 5-section snap-scroll: breakdown, signals, averages, rhythm, connections
- [ ] Mood bubble chart (breakdown)
- [ ] Signal ramps with glyph language (signals)
- [ ] Averages section with weekly/monthly stats
- [ ] Rhythm section showing patterns over time
- [ ] Connections section (correlations — basic in v0.9)
- [ ] Day detail sheet: tap signal bead → day summary → tap recording → detail

**Technical Notes:**
- Signal glyphs: mood (sprout), energy (lightning), focus (aperture), sleep (bed)
- Color ramps: Meadow·Burnt (mood), Lemon (energy), Voltage blue (focus)
- Sleep ramp deferred to v0.8.1/v1.0

#### F5: Text Check-In (P1)
**Description:** Alternative input method for non-voice situations.

**Requirements:**
- [ ] Signal pickers (glyph 1-5) for mood, energy, focus
- [ ] Note text field
- [ ] Same extraction pipeline as voice
- [ ] Save to same data model

#### F6: Onboarding (P1)
**Description:** First-run experience for new users.

**Requirements:**
- [ ] Welcome screen with app purpose
- [ ] Permission request: microphone (with skip option)
- [ ] Model download: WhisperKit (~150MB, optional skip)
- [ ] First check-in prompt
- [ ] **CRITICAL:** Fix "Welcome to Whisper Notes" → "Welcome to Squirl"

### 3.2 Deferred Features (Post-v0.9)

| Feature | Target | Reason |
|---------|--------|--------|
| iCloud Sync | v1.2 | Privacy complexity, merge conflict risk |
| HealthKit integration | v1.0 | Needs privacy policy + App Review scrutiny |
| Tag extraction Phase D | v1.1 | Requires embedding spike validation |
| Live transcription | v1.x | Performance impact, disabled in v0.9 |
| Widget | v1.x | Quick capture from home screen |
| Export/sharing | v1.0 | PDF/CSV for doctor visits |
| Custom reminders | v1.x | Gentle, not nagging |
| Dark mode polish | v1.0 | Current implementation basic |
| Sleep signal ramp | v0.8.1 | Design not finalized |

---

## 4. Technical Architecture

### 4.1 Stack Summary
| Layer | Technology |
|-------|------------|
| UI | SwiftUI, iOS 26 (Liquid Glass) |
| Architecture | Service-Oriented MVVM |
| Concurrency | Swift 6 strict concurrency, actors, async/await |
| Persistence | SwiftData (single ModelConfiguration, no CloudKit) |
| Transcription | WhisperKit (OpenAI Whisper Small) on-device |
| Extraction | Apple NaturalLanguage (`NLNoteExtractor`) |
| Design System | "Paper & Pollen" — custom tokens in `DesignSystem/` |

### 4.2 Key Architectural Decisions

#### AD1: On-Device Privacy (Non-Negotiable)
- All transcription, extraction, and storage runs locally
- Store excluded from iCloud backup by default
- No account required
- Opt-in iCloud sync deferred to v1.2

#### AD2: Service-Oriented Architecture
- `AppDependencies`/`AppServices` DI container injects protocol-driven services
- ViewModels are `@MainActor @Observable`
- Services are actors or `@Sendable` for thread safety

#### AD3: Deterministic Extraction
- Apple NL provides deterministic, measured extraction
- Personal lexicon learns from user corrections
- No LLM/cloud AI for extraction (privacy + consistency)

#### AD4: Swift 6 Strict Concurrency
- Full `Sendable` compliance
- Actor isolation for shared mutable state
- No `@preconcurrency` imports

### 4.3 Data Model (Core Entities)

```
Recording
├── id: UUID
├── createdAt: Date
├── audioFileName: String
├── duration: TimeInterval
├── fullTranscriptText: String
├── title: String
├── status: RecordingStatus
├── signals (mood, energy, focus, sleep, etc.)
├── summary: String?
├── segments: [TranscriptionSegment]
├── medicationEvents: [MedicationEvent]
└── correctionTags: [RecordingTag]

MedicationEvent
├── id: UUID
├── name: String
├── dose: String
├── takenAt: Date
├── durationHours: Double
└── recording: Recording?

TranscriptionSegment
├── id: UUID
├── text: String
├── startTime: TimeInterval
├── endTime: TimeInterval
└── recording: Recording

RecordingTag
├── id: UUID
├── name: String
├── category: String
├── source: TagSource (auto, userCorrected)
└── recording: Recording
```

### 4.4 State Machines

#### RecordingState (CheckInViewModel)
```
idle → recording → paused → processing → done → idle
       ↓ cancel              ↓ error
       idle                  idle
```

#### ProcessingState (ProcessingViewModel)
```
idle → summarizing → saving → completed
            ↓ error
            failed → idle
```

---

## 5. UI/UX Specifications

### 5.1 Design System: "Paper & Pollen"
**Reference:** [DESIGN.md](DESIGN.md) + visual companion

#### Key Principles
- **Effortless:** In and out in under a minute
- **Calm:** App is always slightly calmer than the user
- **Non-judgmental:** No streaks, no gamification, no "you're late"
- **Privacy-first:** No cloud imagery, no account prompts

#### Typography
- Display/Hero: **Fraunces** (check-in prompts, big mood numbers)
- Body/UI: **DM Sans** (buttons, labels, nav)
- Data/Mono: **IBM Plex Mono** (timers, time labels)

#### Color Foundation
| Token | Light | Dark |
|-------|-------|------|
| Background | `#F6F1E7` (warm paper) | `#14130F` (warm loam) |
| Surface | `#FCF8EF` | `#1E1C16` |
| Ink (text) | `#221E16` | `#F3EEE0` |
| Meadow green | `#5F8A4C` | `#6E9A58` |
| Meadow amber | `#E0A33A` | `#E8B255` |
| Medication purple | `#7E5CA8` | `#9277BE` |

#### Signal Ramps (v0.9)
- **Mood:** Meadow·Burnt `#DA7A2A → #EDA94A → #9FCB79 → #5FB36E → #2E8B57`
- **Energy:** Lemon `#A9A079 → #C2B25A → #D8C53E → #EAD22A → #F5D70E`
- **Focus:** Voltage blue `#7E8B96 → #6E8DAE → #5683B8 → #3E73B0 → #2C5E9E`
- **Sleep:** Deferred (no ramp yet)

#### Glyph Language
- **Mood:** Sprout (bud → bloom)
- **Energy:** Lightning bolt (grows/fills)
- **Focus:** Aperture (scattered → tight)
- **Sleep:** Bed icon (single, no level variation)
- **Medication:** Capsule (single, purple)

### 5.2 Screen Specifications

#### Check-In Screen (Core)
**States:**
1. **Idle Hub:**
   - Crescent breathing animation (scale 1→1.035, ~5s)
   - Headline: "How are you,\nright now?" (Fraunces)
   - Three buttons: "Log meds" (quiet), "Speak check-in" (primary), "Type note" (quiet)
   - Medication bar overlay when dose active

2. **Listening:**
   - Crescent rotating (~7s/rev, faster when active)
   - Prompt text rotates through nudges
   - Countdown bar + prompt dots
   - Timer + record dot
   - "Stop & save" button (single, centered)
   - Cancel button (anchored leading, fades in)

3. **Saved:**
   - Checkmark pops once
   - "Captured." text
   - "Done" (primary) + "Check in again" (secondary)
   - No transcribing UI (runs in background)

#### Calendar Screen
- Collapsible week ↔ month calendar
- Two-way bound to day-grouped timeline
- Mood-colored day dots
- Medication indicators
- Tap day → `DayCard` timeline
- Tap recording → `RecordingDetailView`

#### Insights Screen
- 5-section snap-scroll:
  1. **Breakdown:** Mood bubble chart
  2. **Signals:** Glyph ramps (sleep shows "not tracked yet")
  3. **Averages:** Weekly/monthly stats
  4. **Rhythm:** Pattern visualization
  5. **Connections:** Basic correlations
- Pinned selector, inactive headers dim
- Tap signal bead → `DayDetailSheet` → tap recording → detail

#### Recording Detail
- Title (Fraunces) + signal glyph summary
- Summary card (with Regenerate)
- Medications, Feelings, Transcript
- Audio player (last)
- "Edit check-in" toolbar button

#### Edit Sheet (ExtractionReviewView)
- Date/time
- Glyph pickers for mood/energy/focus
- Sleep: hours + quality (neutral control)
- Chip groups: medication/feelings/side-effects
- "Save corrections" → trains personal lexicon

### 5.3 Animation & Motion
- **Crescent:** idle breathing, listening rotation, saved settle
- **Transitions:** spring with gentle damping
- **Easing:** enter ease-out, exit ease-in, move ease-in-out
- **Duration:** micro 50-100ms, short 150-250ms, medium 250-400ms
- **Reduce Motion:** breathing collapses to static glow

---

## 6. Non-Functional Requirements

### 6.1 Performance
| Metric | Target |
|--------|--------|
| App launch | <2 seconds |
| Recording start | <1 second from tap |
| Transcription | <15 seconds for 60s audio |
| Extraction | <2 seconds |
| Insights load | <2 seconds |
| Detail view load | <1 second |
| Audio playback start | <500ms |

### 6.2 Privacy & Security
- **100% on-device:** No data leaves device by default
- **No account:** No signup, no login, no user ID
- **Store exclusion:** SwiftData store excluded from iCloud backup
- **Audio files:** Stored in app container, not Photos library
- **Logging:** No transcript text in system logs (CRITICAL FIX NEEDED)
- **Health data:** Classified as sensitive; encryption at rest

### 6.3 Accessibility
- **Dynamic Type:** All text scales with system setting
- **VoiceOver:** Full screen and element labels
- **Reduce Motion:** Respected throughout
- **Colorblind-safe:** Signal glyphs + color triple-redundant encoding
- **Haptics:** Used for confirmations, optional

### 6.4 Localization
- **v0.9:** English only
- **v1.x:** Portuguese (primary market), Spanish, French
- **Extraction:** NLTagger supports multiple languages; personal lexicon per language

---

## 7. App Store & Launch Requirements

### 7.1 App Store Assets (v1.0)
- [ ] App icon: 1024×1024px
- [ ] Screenshots: iPhone 16 Pro, iPhone 16, iPhone SE (6.5", 5.5", 4.7")
- [ ] App preview video (optional)
- [ ] App name: "Squirl — ADHD Voice Journal"
- [ ] Subtitle: "Check in by talking. Private. Simple."
- [ ] Description: See §7.3
- [ ] Keywords: ADHD, voice journal, mood tracker, medication tracker, mental health, check-in, symptom tracker, privacy, on-device
- [ ] Privacy policy URL (hosted)
- [ ] Support URL
- [ ] Age rating: 17+ (medical/health content)

### 7.2 App Review Requirements
- [ ] `NSMicrophoneUsageDescription` in Info.plist
- [ ] `NSSpeechRecognitionUsageDescription` in Info.plist (if using SFSpeechRecognizer)
- [ ] HealthKit usage strings (if HealthKit added in v1.0)
- [ ] Privacy nutrition label: audio, health, derived mood data
- [ ] Export compliance: standard crypto exemption

### 7.3 App Store Description (Draft)

**Short Description:**
> Squirl is the voice-first check-in journal designed for ADHD minds. Just talk — no structure, no typing, no stigma. Your data never leaves your phone.

**Full Description:**
```
**Say it and it's captured.**

Squirl is a voice-first check-in journal built for people with ADHD. Open the app, tap "Speak check-in," and just talk about how you're feeling. No forms, no sliders, no emoji faces. The app transcribes your voice, extracts your mood, energy, focus, sleep, and medications, and surfaces your patterns over time.

**Why Squirl?**

• **Voice-first** — Just talk. No typing, no structure needed.
• **100% private** — Everything stays on your device. No account, no cloud, no data selling.
• **ADHD-designed** — No streaks, no gamification, no "you're late" alarms. We know consistency is hard.
• **Medication tracking** — Log doses and see how they correlate with your mood and focus.
• **Pattern insights** — Discover what affects your energy, focus, and well-being.

**Perfect for:**
• Tracking ADHD symptoms and medication effects
• Preparing for therapy or psychiatry appointments
• Understanding your daily patterns without friction
• Anyone who finds traditional mood trackers too structured

**Privacy by design:**
All transcription, analysis, and storage happens on your iPhone. Your voice, your data, your business.

---

**Note:** Squirl is a wellness tool, not a medical device. It does not diagnose or treat any condition. Always consult a healthcare professional for medical advice.
```

### 7.4 TestFlight Plan

#### v0.8 — Internal Dogfood (June 18)
- **Audience:** Just you
- **Goal:** Daily use, catch crashes, validate core loop
- **Checklist:** See BACKLOG.md Ship checklist

#### v0.9 — Private Beta (June 24)
- **Audience:** You + 1-2 trusted users
- **Goal:** First external feedback, onboarding validation
- **Distribution:** Internal testers (no review) or external (24h Beta Review)

#### v1.0 — App Store (July 6)
- **Audience:** Public
- **Goal:** Launch with ASO, influencer campaign
- **Submit by:** July 1 (budget for one rejection)

---

## 8. Analytics & Metrics

### 8.1 In-App Metrics (Privacy-Preserving)
- Check-in frequency (daily/weekly)
- Average recording duration
- Voice vs text check-in ratio
- Medication logging frequency
- Most common feelings/side effects
- Signal distribution (mood/energy/focus levels)

### 8.2 TestFlight Analytics
- Crash rate (target: <5%)
- Session duration
- Retention (Day 1, Day 7, Day 14)
- Feature usage (voice vs text, insights views)

### 8.3 User Feedback
- In-app feedback button (TestFlight builds only)
- Email/ShareSheet for bug reports
- Beta user interview notes

---

## 9. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| WhisperKit download too large | High | Medium | Model size optimization, optional download, WiFi-only default |
| Transcription accuracy poor | High | Medium | Personal lexicon training, user correction flow, Whisper Small (not Tiny) |
| App Review rejection (HealthKit) | High | Low | Clear privacy policy, no medical claims, "wellness tool" positioning |
| User retention low | High | Medium | No streaks/gamification, gentle reminders, focus on "captured" reward |
| iOS 16 compatibility issues | Medium | Low | Test on iPhone 14/15/16, iOS 16.0+ target |
| SwiftData migration issues | Medium | Low | Single ModelConfiguration, schema versioning plan |
| Privacy concerns (audio) | Medium | Low | On-device only, no cloud, clear messaging |
| Competitor response | Low | Medium | Differentiation: voice-first, ADHD-specific, no gamification |

---

## 10. Open Questions & Decisions

| # | Question | Status | Owner |
|---|----------|--------|-------|
| 1 | Freemium model: what to gate? | Open | Product |
| 2 | Portuguese localization priority? | Open | Product |
| 3 | HealthKit integration: v1.0 or v1.1? | Open | Product |
| 4 | iCloud sync: v1.2 or later? | Deferred | Product |
| 5 | Widget design: v1.0 or v1.1? | Open | Design |
| 6 | Export format: PDF, CSV, or both? | Open | Product |
| 7 | Partnership program: psych professionals? | Open | Business |
| 8 | Influencer strategy: micro or macro? | Open | Marketing |
| 9 | Pricing: subscription or one-time? | Open | Business |
| 10 | Dark mode: ship v1.0 or polish later? | Open | Design |

---

## 11. Appendices

### Appendix A: Glossary
- **Check-in:** A voice or text entry capturing current state
- **Signal:** Extracted dimension (mood, energy, focus, sleep)
- **Glyph:** Abstract shape representing a signal level (not emoji)
- **Lexicon:** Personal vocabulary for extraction training
- **NLP:** Natural Language Processing (Apple NaturalLanguage framework)
- **WhisperKit:** On-device speech recognition (OpenAI Whisper model)

### Appendix B: References
- [DESIGN.md](DESIGN.md) — Visual design system
- [BACKLOG.md](BACKLOG.md) — Feature backlog and milestones
- [DEVLOG.md](DEVLOG.md) — Development decisions and chronology
- [CLAUDE.md](CLAUDE.md) — AI assistant instructions
- [docs/SPECKIT.md](docs/SPECKIT.md) — Spec Kit workflow

### Appendix C: Related Documents
- Competitive Analysis (Bearable vs Daylio vs Squirl)
- Freemium Business Model Recommendation
- App Store Optimization Strategy
- GDPR Privacy Policy Draft
- Partnership Outreach Template

---

**Document Status:** Draft v1.0 — Ready for review  
**Next Steps:**
1. Review with Claude Code for technical accuracy
2. Update based on feedback
3. Finalize for v0.9 TestFlight

**Last Updated:** 2026-06-15 by Hermes
