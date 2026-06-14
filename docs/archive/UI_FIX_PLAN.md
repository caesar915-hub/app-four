# UI Fix Plan

Plain list of fixes for the problems seen in the screenshots. Each item: what is wrong, which file, what to change, how to check it is fixed.

Order = do the top ones first. They give the biggest visual win.

---

## 1. Empty space at the top (Calendar, Insights, Settings) — HIGH

**Wrong:** A big gray band sits between the clock and the medication bar. The screen keeps room for a large title, but the title scrolls away, so the room is left empty.

**File:** `DesignSystem/ScreenContainer.swift`

**Change:**
- Switch the title mode from large to inline: `.navigationBarTitleDisplayMode(.inline)` instead of `.large`.
- This makes the title small and fixed at the top, so no empty band is left behind.

**Check:** On Calendar, Insights, Settings the medication bar sits right under the clock. No gray gap.

---

## 2. "Record" title overlaps the medication bar — HIGH

**Wrong:** On Record, the word "Record" is drawn on top of the blue bar.

**Cause:** Record is a non-scroll screen. The large title and the top safe-area bar land in the same place.

**File:** `Views/RecordView.swift`

**Change:**
- Remove the Record title. Pass an empty title to `ScreenContainer` (`title: ""`).
- After fix 1 (inline mode), there is no big title to overlap.

**Check:** No "Record" word. The blue bar is clean at the top. The mic screen starts right below it.

---

## 3. Detail screen shows the title twice — HIGH

**Wrong:** The detail screen shows the note name at the top (nav bar) and again in the card below.

**File:** `Views/RecordingDetailView.swift`

**Change:**
- Remove the nav title. Set `.navigationTitle("")` (keep the back button).
- Keep the card, because the card has the name, the color dot, the date, and the edit button.

**Check:** The note name shows one time only, in the card.

---

## 4. Medication bar is too loud and hard to read — HIGH

**Wrong:** The whole bar is bright blue. It looks like a selected button. "ends 11:00" is blue text on blue, hard to read.

**File:** `Views/Components/MedicationBarView.swift`

**Change:**
- Use a calm background, not full blue. Use a light fill like `Color(.secondarySystemBackground)` or a thin tint.
- Make the medicine name primary text color and the time secondary text color, so both are easy to read.
- Use one fixed corner radius (`Radius.card`) so the bar looks the same on every screen.
- Keep the same side padding on all screens (already `Spacing.l` in `ScreenContainer`).

**Check:** The bar is calm, not bright blue. Both the name and "ends 11:00" are clear. Same shape on all screens.

---

## 5. Feedback button covers content — HIGH

**Wrong:** The blue chat button sits on top of text, toggles, and the mic on every screen.

**File:** `App/WhisperNotesApp.swift` (the overlay with `FeedbackButton`)

**Change:**
- This button is a debug/testflight tool. Best option: hide it in normal builds (keep it only behind the debug flag).
- If it must stay, move it so it does not cover content and add bottom space above the tab bar.

**Check:** No button covers text, toggles, or the mic.

---

## 6. "Alert" mood has a gray dot — MEDIUM

**Wrong:** Good = green, Great = teal, Okay = yellow, but "Alert" shows a gray dot. Looks broken.

**File:** `Models/Recording+MoodDisplay.swift` (the `moodColor` logic)

**Change:**
- "Alert" is an energy word, not a mood. The dot should follow the mood only (Great / Good / Okay / Low).
- Give every mood a real color. If there is no mood, use one clear default color, not gray.

**Check:** Every row dot has a real color that matches the mood.

---

## 7. Settings has a card inside a card — MEDIUM

**Wrong:** "Whisper Transcription" is a gray box inside a white box. Two cards stacked.

**File:** `Views/Components/ModelDownloadRow.swift`

**Change:**
- Remove the inner card background. The List section already draws the white card.
- The row should be just icon + text + status, no extra box.

**Check:** "Whisper Transcription" is one clean row, no inner box.

---

## 8. Tab bar shows two tabs active — MEDIUM

**Wrong:** On Insights, the Calendar tab has a green highlight and Insights has blue text at the same time. Two tabs look selected.

**File:** `Views/RootTabView.swift`

**Change:**
- Check the tab tint and selection. Only the active tab should be highlighted.
- Make the Record tab icon match the others (the Record icon has a dark circle behind it; the rest are plain). Use a plain icon so all four look the same.

**Check:** Only one tab is highlighted at a time. All four icons look the same style.

---

## 9. Record screen layout is too empty — MEDIUM

**Wrong:** The "Done" box, the waveform, and the mic button are spread out with big gaps. The "Done" box floats to the left.

**File:** `Views/RecordView.swift`

**Change:**
- Center the status box and waveform as one group.
- Reduce the giant spacers (`Spacing.hero`) so the content sits as one block, not spread across the whole screen.
- Make the Voice/Text switch normal height (it is too tall now).

**Check:** The record content reads as one centered group. No giant gaps.

---

## 10. Durations show 0:00 — SEPARATE (data, not layout)

**Wrong:** Most rows show 0:00 length. Storage shows small size.

**Note:** This is a data problem (length not saved), not a layout problem. Fix after the UI items. Needs a look at the record/save code, not the views.

**Check:** New recordings show a real length.

---

## Suggested order
1, 2, 3 (titles + spacing) → 4 (med bar) → 5 (feedback button) → 6, 7, 8 (dots, card, tab bar) → 9 (record layout) → 10 (durations, separate).
