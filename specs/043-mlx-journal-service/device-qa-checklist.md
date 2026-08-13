# Device QA Checklist — 043 MLX Journal Service

**Branch**: `feat/043-mlx-journal-service` | **Target device**: Joao's iPhone (iPhone 12 Pro, A14) | **Updated**: 2026-08-13 (model lifecycle + onboarding + settings + summary UI)

## Prerequisites

- [ ] iPhone 12 Pro connected, trusted, and visible (`xcrun devicectl list devices` → state `available`)
- [ ] Device on Wi-Fi — the Llama insights model (~740 MB) downloads via onboarding, Settings, or the launch-time background task
- [ ] Signed Debug build verified: `xcodebuild build -scheme app-four -destination 'generic/platform=iOS'` — **BUILD SUCCEEDED** (2026-08-13)
- [ ] Simulator suite green: **511 tests / 65 suites** (2026-08-13)

Install once device is available:
```bash
xcodebuild build -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS,name=Joao’s iPhone' && \
xcrun devicectl device install app --device F0F4C38A-182C-581D-A3E0-B659C3C59E5A \
  ~/Library/Developer/Xcode/DerivedData/app-four-fgtorzrcfyngybgexxulfkuebpxb/Build/Products/Debug-iphoneos/app-four.app
```

## Test Matrix

### 0. Model lifecycle (new — managed download)
- [ ] Fresh install → onboarding: Welcome → Siri → **Whisper download** → **Llama "Journal Insights" screen** (new) with ~740 MB copy; both skippable
- [ ] "Download Now" on the Llama screen shows live progress and completes onboarding
- [ ] "Skip for Now" on either screen records the decline; the launch-time background download must NOT start for the declined model (check logs)
- [ ] Neither declined → after onboarding, the background task downloads Whisper then Llama on Wi-Fi with no UI
- [ ] Settings › AI Models shows **two rows** (Voice Transcription + Journal Insights) with installed/downloading states, cancel, retry, and delete
- [ ] Delete "Journal Insights" → row flips to not-installed; a new check-in then shows the **"Insights Model Not Downloaded"** alert and saves transcript-only (no signals)
- [ ] Re-download from Settings → extraction works again

### 1. Cold-start extraction (US1.2)
- [ ] With the Llama model installed, record: *"Took my Vyvanse this morning. Feeling pretty good, energy is steady. Focus is sharp but I did zone out for a bit after lunch."*
- [ ] First extraction loads the model lazily and completes in **5–15 s on A14**
- [ ] Result: mood=`good`, energy=`steady`, focus=`sharp`, medication "Vyvanse"
- [ ] Second check-in reuses the loaded model (no reload wait)

### 2. ADHD slang mapping (US1.3)
- [ ] *"Brain keeps switching tabs, was doom scrolling all night, took my addy"* → focus=`distracted`, topic "Executive Dysfunction", medication "Adderall"

### 3. Summary length convention (US3.3)
- [ ] 1-sentence check-in → signals only, `summary: null` (no Summary card on the detail view)
- [ ] 3+ sentence journal → empathetic second-person summary + topics + lexicon phrases

### 4. Recording Detail — summary + transcript (new layout)
- [ ] Detail view shows: title → signal heroes → details card → **Summary card** (Llama bullets + "written by on-device AI" footnote) → **full transcript, expanded** → audio
- [ ] The summary text matches the mockup `html-mockups/043-recording-detail-summary-then-transcript.html`
- [ ] A check-in with no summary (fallback/short note) renders no Summary card and no layout gap
- [ ] Long transcript scrolls smoothly; VoiceOver reads summary before transcript

### 5. Memory pressure (US7 / FR-EXT-06/07)
- [ ] Open several memory-heavy apps, then run a check-in
- [ ] Expect: **"Not Enough Memory" alert**, graceful fallback (transcript-only result, no crash)

### 6. Backgrounding mid-extraction (spec edge case)
- [ ] Start extraction, immediately background the app
- [ ] ⚠️ **Known gap**: no background-task expiration handler in the extraction path — observe actual behavior; on relaunch the recording should not be stuck in "Processing…"

### 7. Extraction Review UI (Part 3)
- [ ] Sheet opens **only** from pencil toolbar button (VoiceOver label exactly "Edit check-in"), large detent, visible drag indicator
- [ ] Edit mood → save → mood tag is `.userCorrected`, untouched fields stay `.llm`
- [ ] Sleep field: type `7,5` → persists as 7.5
- [ ] Custom title wins; blank title auto-generates "Good · Steady · Sharp" style
- [ ] Change review date → medication events resolve against the new date
- [ ] Review-save rebuilds `noteExtraction` JSON (meds/title/sleep edits land in the JSON)
- [ ] Cancel button → recording marked `.failed`
- [ ] ⚠️ **Known gap**: swipe-to-dismiss bypasses `cancel()` — recording stays in its prior status

### 8. Total parse failure fallback (US5)
- [ ] Force a garbage/nil extraction → review sheet still opens with safe empty defaults, fully editable, saves without crash

## Known Issues Confirmed by Code Review (do not file as new bugs)

1. ~~Transcript never interpolated into the LLM user message~~ — **FIXED**
2. ~~`parseExtraction` stage-3 crash on reversed braces `}{`~~ — **FIXED**
3. ~~Memory alert state never reaches any view~~ — **FIXED** (CheckInView alert)
4. No background-task expiration handler for extraction
5. ~~No download progress for the model download~~ — **FIXED** (managed download streams progress to onboarding/Settings rows)
6. ~~Review-save does not rebuild `noteExtraction` JSON~~ — **FIXED**
7. Provenance tags duplicate on repeated saves; per-item (not per-field) granularity for emotions/meds
8. Previously user-set title is clobbered by auto-title on a later re-save
9. Low-memory reprocess of a previously extracted recording wipes its signals/med events
10. FR-EXT-15 success haptic not implemented
