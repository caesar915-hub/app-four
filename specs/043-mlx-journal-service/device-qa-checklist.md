# Device QA Checklist — 043 MLX Journal Service

**Branch**: `feat/043-mlx-journal-service` | **Target device**: Joao's iPhone (iPhone 12 Pro, A14) | **Date**: 2026-08-13

## Prerequisites

- [ ] iPhone 12 Pro connected, trusted, and visible (`xcrun devicectl list devices` → state `available`)
- [ ] Device on Wi-Fi — **first extraction downloads ~0.74 GB** (Llama 3.2 1B 4-bit from Hugging Face, cached in app Caches afterwards)
- [ ] Signed Debug build verified: `xcodebuild build -scheme app-four -destination 'generic/platform=iOS'` — **BUILD SUCCEEDED** (2026-08-13, Apple Development cert, team profile OK)
- [ ] Simulator suite green: 537 tests / 75 suites passed (2026-08-13)

Install once device is available:
```bash
xcodebuild build -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS,name=Joao’s iPhone' && \
xcrun devicectl device install app --device F0F4C38A-182C-581D-A3E0-B659C3C59E5A \
  ~/Library/Developer/Xcode/DerivedData/app-four-fgtorzrcfyngybgexxulfkuebpxb/Build/Products/Debug-iphoneos/app-four.app
```

## Test Matrix

### 1. Cold-start extraction (US1.2)
- [ ] Record a voice check-in: *"Took my Vyvanse this morning. Feeling pretty good, energy is steady. Focus is sharp but I did zone out for a bit after lunch."*
- [ ] First run: model downloads then loads lazily; extraction completes in **5–15 s on A14**
- [ ] Result: mood=`good`, energy=`steady`, focus=`sharp`, medication "Vyvanse"
- [ ] Second check-in reuses the loaded model (no reload wait)

### 2. ADHD slang mapping (US1.3)
- [ ] *"Brain keeps switching tabs, was doom scrolling all night, took my addy"* → focus=`distracted`, topic "Executive Dysfunction", medication "Adderall"

### 3. Summary length convention (US3.3)
- [ ] 1-sentence check-in → signals only, `summary: null`
- [ ] 3+ sentence journal → empathetic second-person summary + topics + lexicon phrases

### 4. Memory pressure (US7 / FR-EXT-06/07)
- [ ] Open several memory-heavy apps, then run a check-in
- [ ] Expect: "Not Enough Memory" alert, graceful fallback (transcript-only result, no crash)
- [ ] Optional: mock `MemoryMonitor` to return < 200 MB (see quickstart.md §3)

### 5. Backgrounding mid-extraction (spec edge case)
- [ ] Start extraction, immediately background the app
- [ ] ⚠️ **Known gap**: no background-task expiration handler in the extraction path — observe actual behavior; on relaunch the recording should not be stuck in "Processing…"

### 6. Extraction Review UI (Part 3)
- [ ] Sheet opens **only** from pencil toolbar button (VoiceOver label exactly "Edit check-in"), large detent, visible drag indicator
- [ ] Edit mood → save → mood tag is `.userCorrected`, untouched fields stay `.llm`
- [ ] Sleep field: type `7,5` → persists as 7.5
- [ ] Custom title wins; blank title auto-generates "Good · Steady · Sharp" style
- [ ] Change review date → medication events resolve against the new date
- [ ] Cancel button → recording marked `.failed`
- [ ] ⚠️ **Known gap**: swipe-to-dismiss bypasses `cancel()` — recording stays in its prior status

### 7. Total parse failure fallback (US5)
- [ ] Force a garbage/nil extraction (e.g. airplane mode mid-download or mock) → review sheet still opens with safe empty defaults, fully editable, saves without crash

## Known Issues Confirmed by Code Review (do not file as new bugs)

1. ~~Transcript never interpolated into the LLM user message~~ — **FIXED** (2026-08-13)
2. ~~`parseExtraction` stage-3 crash on reversed braces `}{`~~ — **FIXED** (2026-08-13)
3. Memory alert state never reaches any view; fallback is silent
4. No background-task expiration handler for extraction
5. No download progress indicator for the ~0.74 GB first-run download
6. Review-save does not rebuild `noteExtraction` JSON (production path passes nil)
7. Provenance tags duplicate on repeated saves; per-item (not per-field) granularity for emotions/meds
8. Previously user-set title is clobbered by auto-title on a later re-save
9. Low-memory reprocess of a previously extracted recording wipes its signals/med events
10. FR-EXT-15 success haptic not implemented
