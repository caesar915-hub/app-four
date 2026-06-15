> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# Medication Bar Logic - Objective Breakdown

## Data Sources (Two Parallel Tracks)

### Track 1: Manual Logging (MedicationDose)
- **Created when:** User taps medication bar → opens log sheet → saves
- **Where stored:** SwiftData `@Model MedicationDose`
- **Fields:** 
  - `name`: String (required)
  - `dose`: String? (optional)
  - `takenAt`: Date (user selects exact time)
  - `durationHours`: Double (fixed at 10.0)
  - `source`: .manual
  - `createdAt`: Date (auto timestamp)

### Track 2: Recording Extraction (MedEvent)
- **Created when:** Recording transcribed → NLP extraction → MedEvent objects parsed from transcript
- **Where stored:** Recording model → `medicationsJSON` (JSON string) → decoded as `[MedEvent]`
- **Fields:**
  - `name`: String
  - `dose`: String?
  - `time`: String? ("HH:mm" format like "10:00")
  - `timeLabel`: String? (raw phrase like "morning", "after breakfast")
  - `taken`: Bool (true = took it, false = didn't take it)
  - `quantity`: Double? (1.0 = full dose, 0.5 = half)
  - `change`: MedEventChange? (started/stopped/regular)

---

## Priority Logic in MedicationBarViewModel.refresh()

```swift
1. Check latest MANUAL dose within 24 hours
   ↓ YES → Use it, show in bar, return
   ↓ NO ↓
2. Check latest RECORDING with extracted medications (hasMedication == true)
   ↓ YES → Convert MedEvent to display, show in bar, return
   ↓ NO ↓
3. No medication → currentDose = nil, bar empty
```

**The medication bar shows the FIRST (and only) medication from Track 1 or Track 2, never both.**

---

## Why Different Info in Different Views

### MedicationBarView (Top Bar - Every Screen)
- Shows: `DoseDisplay { name, dose, takenAt, endsAt }`
- **Data from:** Manual logs (priority) OR latest recording extraction
- **Update trigger:** When user logs manually OR when recording is processed
- **Time shown:** "ends HH:mm" (progress bar shows % of 10-hour duration elapsed)

### Recording Detail Card (RecordingDetailView)
- Shows: Mood dot + Title + Date + Duration + Edit button
- **Data from:** Recording's extracted medications (not the bar)
- **Not** affected by manual logs → only shows what was in THAT recording
- **Visible even if:** Bar shows different medication (from manual or newer recording)

### Calendar/Insights
- Shows: Recording list with medication dots
- **Data from:** Each recording's extracted medications
- **Note:** Bar at top may show DIFFERENT medication (if manual log exists)

---

## Flow: When User Logs Medication

### Step 1: User taps medication bar
```
MedicationBarView (tap) → opens MedicationLogSheet
```

### Step 2: User enters data in sheet
```
Form inputs:
- name (text field)
- dose (text field, optional)
- takenAt (date picker, hour + minute)
```

### Step 3: User saves
```swift
onLog(name: String, dose: String?, takenAt: Date)
  ↓
MedicationBarViewModel.logManualDose(name, dose, takenAt)
  ↓
Creates MedicationDose(
  name: name,
  dose: dose,
  takenAt: takenAt,
  durationHours: 10.0,
  source: .manual
)
  ↓
context.insert(entry) + context.save()
  ↓
refresh() → recalculates currentDose
  ↓
MedicationBarView updates (bound to @Observable viewModel)
```

**Result:** Bar immediately shows new manual dose (overrides any recording extraction)

---

## Concrete Example

### Scenario: User had medication in recording, then manually logs different one

**State A: After recording processed**
- Recording has MedEvent: "Sertraline 50mg" at "9:30am"
- Bar shows: "Sertraline 50mg ... ends 19:30"
- Recording detail shows: "Sertraline 50mg"

**State B: User taps bar and logs "Adderall 20mg" at 2:00 PM**
- MedicationDose created: name="Adderall", dose="20mg", takenAt=2:00 PM today
- Bar shows: "Adderall 20mg ... ends 00:00 (next day)"
- Recording detail STILL shows: "Sertraline 50mg" (unchanged, only shows that recording's data)

**Key Issue:** Bar and detail show different medications. User sees inconsistency.

---

## Potential Problems

### 1. Bar shows different medication than detail
- **Why:** Bar shows manual log OR latest recording; detail shows THAT SPECIFIC recording
- **Example:** Tap recording A, bar shows medication B (from manual log or recording C)

### 2. Time parsing issues
- If NLP extracts "10:00" but sets on wrong day → falls back to recording time
- If timeLabel extracted ("morning") but no exact time → approximates to 8am

### 3. No indication of source
- User can't tell if bar medication came from manual log or auto-extraction
- Makes it unclear which dose is "current"

### 4. Manual log duration always 10 hours
- Hard-coded, can't customize per medication
- Recording extraction also assumes 10 hours for fallback display

---

## Data Integrity Questions

**Q: Is MedEvent correctly linked to Recording?**
- No direct link. MedEvent is stored as JSON in `medicationsJSON` field
- Decoded on demand: `recording.decodedMedications` → `[MedEvent]`
- ✅ Works, but read-only. Edits in detail view don't update MedEvent objects.

**Q: When editing medication in detail view, what happens?**
- See ExtractionReviewViewModel
- Updates `noteExtractionJSON` (entire extraction object)
- MedEvent objects inside are re-encoded as JSON
- But bar still reads from `MedicationDose` manual logs first (unchanged)

**Q: Is manual log ever converted to MedEvent?**
- No. Two separate types. Manual logs stay in `MedicationDose` table.
- Bar just displays them side-by-side via `DoseDisplay` wrapper.
