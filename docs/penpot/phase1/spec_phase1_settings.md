# Penpot Reproduction Spec: Squirl Settings Screen

**Date:** 2026-06-30  
**Source Files:** app-four/Views/SettingsView.swift, Settings/* sections, Components/ModelDownloadRow.swift, ViewModels/SettingsViewModel.swift  
**Design System:** SquirlDesignSystem (Typography, Theme, Palette, Spacing, Radius, Metrics)  
**Target:** Light mode "Paper" theme static hi-fi mockup

---

## 1. Screen Structure

### Overall Layout
- **Container:** `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` wrapping a `List` (SettingsView.swift:43)
- **List Style:** `.insetGrouped` (line 58)
- **Backgrounds:**
  - **Screen background:** `Theme.background` (#F6F1E7) (Theme.swift:9)
  - **Scroll content visible:** `.scrollContentBackground(.hidden)` (SettingsView.swift:59) — reveals paper beneath
  - **Row/Card background:** `Theme.cardBackground` (#FCF8EF) (line 60)

### Navigation
- **Title:** "Settings" (implicit via ScreenContainer; no explicit inline title text in the view)
- **Style:** Exposed to VoiceOver as a heading landmark (line 42 comment)
- **Medication Bar:** Visible at top (`showsMedicationBar: true`, line 43)

### Section Order (Top → Bottom)
1. **AI Models** (line 46)
2. **System** (line 48)
3. **Check-in** (line 49)
4. **Medication Bar** (line 51)
5. **Calendar** (line 50)  [**Note: DayCardSettingsSection**]
6. **Accessibility** (line 52)
7. **Your data** (line 53)
8. **Export** (line 54)  [**Note: journalExportSection, labeled with footer**]
9. **Danger Zone** (line 55)
10. **Version** (line 56)

---

## 2. Detailed Sections & Rows

### 2.1 AI Models Section
**Header:** "AI Models" (SettingsView.swift:110)  
**Content:** `ModelDownloadRow` (see Section 3 for full details)

---

### 2.2 System Section
**Header:** "System" (SettingsView.swift:133)

#### Row 1: Storage
- **Type:** `LabeledContent` (label on left, value on right)
- **Label:** "Storage"
- **Value:** Text computed from viewModel: `"\(count) \(count == 1 ? "recording" : "recordings") · \(String(format: "%.1f", viewModel.storageUsedMB)) MB"` (line 136)
  - **Example:** "3 recordings · 127.5 MB"
  - **Style:** `Theme.textSecondary` (#7A7361)
  - **Font:** (implicit body)

#### Row 2: Download over Cellular
- **Type:** `Toggle` with `Label`
- **Label Text:** "Download over Cellular"
- **Label Icon:** `systemImage: "antenna.radiowaves.left.and.right"` (SF Symbol)
- **Binding:** `@State var downloadOverCellular` (SettingsViewModel.swift:44)
- **On Toggle:** Calls `syncDownloadOverCellular()` (line 143)

---

### 2.3 Check-in Section
**Header:** "Check-in" (SettingsView.swift:157)  
**Footer:** "How long each prompt stays on screen during a voice check-in." (line 159)

#### Row: Prompt Pace
- **Type:** `Picker` / NavigationLink-style picker
- **Label:** "Prompt Pace"
- **Options:** `ForEach(PromptPace.allCases, id: \.self)` with `Text(pace.displayLabel)` (line 152)
  - PromptPace enum (assumed from AppSettings.swift:11): likely `quick`, `normal`, `relaxed` (or similar)
- **Binding:** `@State var promptPace` (SettingsViewModel.swift:45)
- **On Change:** Calls `syncPromptPace()` (line 155)
- **UI Affordance:** In insetGrouped List, appears as a gray disclosing row with current selection on right

---

### 2.4 Medication Bar Settings Section
**Header:** "Medication Bar" (MedicationBarSettingsSection.swift:11)  
**Content:**

#### Row 1: Show Medication Bar
- **Type:** `Toggle` with `Label`
- **Label:** "Show Medication Bar"
- **Icon:** `systemImage: "pills.circle"`
- **Binding:** `@AppStorage("medicationBarVisible")` (line 5)
- **AccessibilityHint:** "Shows a medication progress bar at the top of each screen." (line 15)

#### Row 2: Show Medication Name (conditional, appears if `barVisible == true`)
- **Type:** `Toggle` with `Label`
- **Label:** "Show Medication Name"
- **Icon:** `systemImage: "pill"`
- **Binding:** `@AppStorage("medicationBarShowName")` (line 6)
- **Indentation:** Nested under Row 1 (conditional if barVisible)
- **AccessibilityHint:** "Displays the medication name and dose in the bar." (line 21)

#### Row 3: Show Taken Time (conditional)
- **Type:** `Toggle` with `Label`
- **Label:** "Show Taken Time"
- **Icon:** `systemImage: "clock"`
- **Binding:** `@AppStorage("medicationBarShowTime")` (line 7)
- **AccessibilityHint:** "Displays when the medication was taken." (line 26)

#### Row 4: Show End Time (conditional)
- **Type:** `Toggle` with `Label`
- **Label:** "Show End Time"
- **Icon:** `systemImage: "clock.arrow.circlepath"`
- **Binding:** `@AppStorage("medicationBarShowEndTime")` (line 8)
- **AccessibilityHint:** "Displays when the medication effect is expected to end." (line 31)

---

### 2.5 Calendar Settings Section (DayCardSettingsSection)
**Header:** "Calendar" (DayCardSettingsSection.swift:11)  
**Content:**

#### Row 1: Always expand cards
- **Type:** `Toggle` with `Label`
- **Label:** "Always expand cards"
- **Icon:** `systemImage: "rectangle.stack"`
- **Binding:** `@AppStorage("alwaysExpandCards")` (line 8)
- **AccessibilityHint:** "When on, every day's check-ins stay open in the calendar." (line 15)

#### Row 2: Auto-expand selected day
- **Type:** `Toggle` with `Label`
- **Label:** "Auto-expand selected day"
- **Icon:** `systemImage: "rectangle.expand.vertical"`
- **Binding:** `@AppStorage("autoExpandOnSelection")` (line 7)
- **AccessibilityHint:** "When on, tapping a date opens that day's check-ins automatically." (line 20)

---

### 2.6 Accessibility Section
**Header:** "Accessibility" (SettingsView.swift:173)  
**Content:** Plain text (no interactive controls)

#### Text Block
- **Copy:** "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations." (line 174)
- **Font:** `Typography.caption` (12pt SF Pro regular, scale-relative)
- **Color:** `Theme.textSecondary` (#7A7361)

---

### 2.7 Your Data Section
**Header:** "Your data" (YourDataSection.swift:9)  
**Content:**

#### Text Block (Privacy statement)
- **Copy:** "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." (line 10)
- **Font:** `Typography.body` (16pt SF Pro regular)
- **Color:** `Theme.textSecondary` (#7A7361)

#### NavigationLink Row
- **Label:** "Acknowledgements"
- **Icon:** `systemImage: "heart"`
- **Destination:** `AcknowledgementsView()` (line 15)
- **Appearance:** Disclosure arrow on right (standard iOS navigation indicator)

---

### 2.8 Journal Export Section
**Header:** (None — unnamed section, just footer text)  
**Footer:** "Saves one encrypted file you can keep or share. We'll show you a key to open it — keep it safe. If you lose the key, the backup can't be recovered — not even by us." (SettingsView.swift:193)

#### Button Row
- **Type:** `Button` inside `HStack`
- **Label:** "Save a copy of my journal — yours to keep"
- **Icon:** `systemImage: "lock.doc"`
- **Action:** `startExport()` (line 182)
- **State:**
  - **Idle:** Label + icon displayed normally, no progress
  - **Exporting:** Label + icon on left, `ProgressView()` on right (line 187), button disabled (line 191)
- **Accessibility:** Properly wrapped as button with accessibility traits

#### Modal Flows (Triggered by button)
1. **File Exporter** (line 83–96)
   - File type: `.data` (generic binary)
   - Default filename: `"Squirl Journal yyyy-MM-dd"` (line 29)
2. **Recovery Key Sheet** (line 97–99)
   - Shown AFTER file save succeeds (only if export result is `.success`)
   - Details in Section 4 below
3. **Failure Alert** (line 100–104)
   - Title: "Couldn't save a copy"
   - Message: "Something went wrong preparing your backup. Please try again."
   - Button: "OK"

---

### 2.9 Danger Zone Section
**Header:** (None)  
**Content:**

#### Button Row
- **Type:** `Button(role: .destructive)`
- **Label:** "Clear All Data"
- **Icon:** `systemImage: "trash"`
- **Action:** Shows confirmation alert (line 216)
- **Alert Details:**
  - **Title:** "Clear All Data?" (line 75)
  - **Message:** "This permanently deletes all your recordings and check-ins. Your downloaded transcription model and preferences are kept. This can't be undone." (line 81)
  - **Destructive Button:** "Clear All Data" → calls `viewModel.clearAllData()` (line 77)
  - **Cancel Button:** "Cancel" (line 79)

---

### 2.10 Version Section
**Header:** (None)  
**Content:** Centered text

#### Version Label
- **Computed Text:** `"\(name) v\(version)"` where `name` = CFBundleDisplayName (default "Squirl"), `version` = CFBundleShortVersionString (default "—") (SettingsView.swift:224–226)
- **Example:** "Squirl v1.0.2"
- **Font:** `Typography.caption` (12pt SF Pro regular)
- **Color:** `Theme.textSecondary` (#7A7361)
- **Alignment:** Centered in row (wrapped in `HStack { Spacer() Text(...) Spacer() }`, line 231–239)
- **Row Background:** `.listRowBackground(Color.clear)` (line 242) — no card background, blends into page background
- **Debug Easter Egg (Dev builds only):** 5-tap gesture opens TestServicesView (line 237)

---

## 3. ModelDownloadRow Component

**File:** app-four/Views/Components/ModelDownloadRow.swift  
**Context:** Used in AI Models section (SettingsView.swift:111–128)  
**Parameters:** title, icon, isInstalled, isDownloading, downloadProgress, errorMessage, canAllowCellular, onDownload, onRetry, onCancel, onAllowCellular, onDelete

### Layout
- **Outer Container:** `VStack(alignment: .leading, spacing: Spacing.s)` (line 26)
- **Row Height:** Min 44pt (inset grouped List row baseline; content can expand)

### State 1: Not Installed, Idle
**Visual:**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription  ◯ Not installed │
│ ~150 MB · Wi-Fi recommended                       │
└──────────────────────────────────────────────────┘
```

**Components:**
- **Top Row (HStack):** Icon + label on left; trailing status on right
  - Icon: `systemImage: "waveform"` (SF Symbol, 16pt inline size implied by Label)
  - Label text: "Voice Transcription" (line 28, `Typography.body` / 16pt)
  - **Trailing Status:** Gray circle (8pt diameter) + "Not installed" text (line 94–97)
    - Circle: `Theme.statusInProgress` (#E0A33A meadowAmber)
    - Text: `Typography.caption` (#7A7361), "Not installed"
- **Caption Row:** "~150 MB · Wi-Fi recommended" (line 37)
  - Font: `Typography.caption` (#7A7361)
  - Shown only when `!isInstalled && !isDownloading` (line 36)

**Interaction:** Tap row → calls `onDownload()` (line 48)

---

### State 2: Installed
**Visual:**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription  ◯ Installed   │
└──────────────────────────────────────────────────┘
```

**Components:**
- **Top Row:** Icon + label; trailing status
  - Label: "Voice Transcription"
  - **Trailing Status:** Green circle + "Installed" text (line 94–97)
    - Circle: `Theme.statusDone` (#5F8A4C meadowGreen), 8pt diameter
    - Text: `Typography.caption` (#7A7361), "Installed"

**Interaction:** Tap row → shows `confirmationDialog` with "Delete Model" (destructive) and "Cancel" options (line 51–58)

---

### State 3: Downloading (Indeterminate)
**Visual (Progress = 0):**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription               │
│                               ◌ Starting… [Cancel] │
└──────────────────────────────────────────────────┘
```

**Components:**
- **Indeterminate Progress:** Small spinner (0.8x scale, line 78), text "Starting…", "Cancel" button
  - Spinner: `ProgressView()` with `.scaleEffect(0.8)`
  - Text: `Typography.caption` (#7A7361)
  - Cancel Button: `buttonStyle(.plain)`, font `Typography.caption.weight(.medium)`, color `Theme.meadowGreen` (#5F8A4C) (line 83–86)

---

### State 4: Downloading (With Progress)
**Visual (Progress = 42%):**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription               │
│                  [=====>      ] 42% [Cancel]      │
└──────────────────────────────────────────────────┘
```

**Components:**
- **Progress Bar:** `ProgressView(value: downloadProgress)` with `.progressViewStyle(.linear)` (line 69)
  - Frame width: 80pt (line 71)
  - Track: `Theme.surface2` (#EFE8D8) implied by system style
  - Fill: `Theme.meadowGreen` (#5F8A4C)
- **Percentage Text:** `Typography.caption` (#7A7361), monospacedDigit (line 72–75)
  - Example: "42%"
- **Cancel Button:** Same styling as indeterminate state

---

### State 5: Error (Generic)
**Visual:**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription  ● (red)     │
│ No connection. Reconnect…                        │
│ [Try again] [Open Settings]                      │
└──────────────────────────────────────────────────┘
```

**Components:**
- **Top Row:** Icon + label; red error circle (8pt, `Theme.danger` #B5503A) (line 88–90)
- **Error Message Block:** `VStack(alignment: .leading, spacing: Spacing.s)` (line 105)
  - Message text: `Typography.caption`, color `Theme.danger` (#B5503A) (line 106–109)
  - Example (no network): "No connection. Reconnect to the internet, then try again." (SettingsViewModel.swift:138)
  - Example (no space): "Not enough space on this device. Free up some room, then try again." (line 140)
  - Example (other): "The download didn't finish. Try again in a moment." (line 144)
- **Action Pill Row:** `FlowLayout(spacing: Spacing.s)` (line 112)
  - Pills: "Try again" always; "Allow on cellular" + "Open Settings" only if `canAllowCellular == true`
  - Style: "ghost pill" — outlined capsule (line 124–135)
    - Padding: horizontal `Spacing.m` (12pt), vertical `Spacing.s` (8pt)
    - Min height: `Metrics.minTapTarget` (44pt) — ensures tap target
    - Text: `Typography.caption.weight(.medium)`, color `Theme.meadowGreen` (#5F8A4C)
    - Border: `Capsule().strokeBorder(Theme.separator #E3DAC7, lineWidth: 1)`
    - Button style: `.plain` (no system button chrome)

---

### State 6: Error – Cellular Blocked (Special Case)
**Visual:**
```
┌──────────────────────────────────────────────────┐
│ [waveform icon] Voice Transcription  ● (red)     │
│ You're on cellular and downloads… [Try again]    │
│ [Allow on cellular] [Open Settings]              │
└──────────────────────────────────────────────────┘
```

**Components:**
- Same error block structure as State 5
- Message: "You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular below." (SettingsViewModel.swift:142)
- Pills: "Try again", "Allow on cellular", "Open Settings" (3 pills total, line 114–119)

---

## 4. Recovery Key Sheet (Post-Export Modal)

**File:** app-four/Views/Settings/JournalExportSection.swift, `RecoveryKeySheet` struct (lines 30–86)  
**Trigger:** Shown AFTER file is successfully saved; user is shown the key once and can copy it (line 97–99)

### Layout
- **Container:** `NavigationStack` with `VStack(alignment: .leading, spacing: Spacing.xxl)` (line 39)
- **Background:** `Theme.background` (#F6F1E7) with `.ignoresSafeArea()` (line 78)
- **Padding:** Horizontal `Spacing.l` (16pt), top `Spacing.section` (32pt) (line 75–76)

### Content Stack

#### 1. Header
- **VStack(alignment: .leading, spacing: Spacing.m)** (line 40)
  - **Title:** "Keep this key safe" (line 41)
    - Font: `Typography.title` (22pt SF Pro semibold)
    - Color: `Theme.textPrimary` (#221E16)
  - **Body:** "This file can only be opened by a future version of Squirl, using this exact key. If you lose the key, the backup can't be recovered — not even by us. Save it somewhere only you can reach." (line 44)
    - Font: `Typography.body` (16pt SF Pro regular)
    - Color: `Theme.textSecondary` (#7A7361)

#### 2. Recovery Key Display
- **Text(keyBase64)** (line 49)
  - Font: `Typography.mono12` (12pt SF Mono regular) — fixed-width
  - Color: `Theme.textPrimary` (#221E16)
  - **Text Selection:** `.textSelection(.enabled)` (line 52) — user can select and copy manually
  - **Layout:** Max width infinity, leading alignment (line 53)
  - **Styling:** Wrapped in `.padding(Spacing.l)` (16pt all sides), background `Theme.surface2` (#EFE8D8), corner radius `Radius.card` (16pt) (line 54–55)
  - **Accessibility Label:** "Recovery key" (line 56)

#### 3. Copy Button
- **Button(action: copyToClipboard)** (line 59)
  - **Label State (Idle):** "Copy key" with `systemImage: "doc.on.doc"` (line 69)
  - **Label State (After Copy):** "Copied" with `systemImage: "checkmark"` (line 69)
    - Triggered by tapping the button; animated with `Motion.smooth` (line 67)
  - **Button Style:** `.primary` (Squirl primary button → likely green gradient or solid color)
  - **Clipboard Behavior:** Sets UIPasteboard with UTF-8 plaintext, expiration 120 seconds (line 60–65)
    - Option: `.localOnly` = true, `.expirationDate` = 120s from now

#### 4. Spacer & Toolbar
- **Spacer()** between copy button and bottom (line 73)
- **Toolbar:** `ToolbarItem(placement: .confirmationAction)` with "Done" button (line 79–82)
  - Calls `onDone()` to dismiss sheet

---

## 5. SF Symbols Used

| Location | Symbol Name | Purpose |
|----------|------------|---------|
| AI Models row | `"waveform"` | Voice Transcription icon |
| System section | `"antenna.radiowaves.left.and.right"` | Download over Cellular |
| Med Bar toggles | `"pills.circle"` | Show Medication Bar |
| Med Bar toggles | `"pill"` | Show Medication Name |
| Med Bar toggles | `"clock"` | Show Taken Time |
| Med Bar toggles | `"clock.arrow.circlepath"` | Show End Time |
| Calendar toggles | `"rectangle.stack"` | Always expand cards |
| Calendar toggles | `"rectangle.expand.vertical"` | Auto-expand selected day |
| Your Data row | `"heart"` | Acknowledgements |
| Export button | `"lock.doc"` | Save a copy of journal |
| Danger row | `"trash"` | Clear All Data |
| Recovery Key button | `"doc.on.doc"` (idle) / `"checkmark"` (copied) | Copy key |

---

## 6. Token Resolution Table

### Colors (Light Mode / Paper)
| Token Name | Usage | Hex Value | Type |
|-----------|-------|-----------|------|
| `Theme.background` | Screen background | #F6F1E7 | Page background |
| `Theme.cardBackground` | List row/card background | #FCF8EF | Card/row fill |
| `Theme.surface2` | Inset fields (recovery key box) | #EFE8D8 | Secondary surface |
| `Theme.textPrimary` | Headers, body copy | #221E16 | Primary text |
| `Theme.textSecondary` | Captions, descriptions | #7A7361 | Secondary text |
| `Theme.separator` | Hairline borders, pill outlines | #E3DAC7 | Divider/border |
| `Theme.meadowGreen` | Primary accent (buttons, toggle on, done status) | #5F8A4C | Accent (green) |
| `Theme.meadowAmber` | Secondary accent, in-progress status | #E0A33A | Accent (amber) |
| `Theme.statusDone` | Installed status circle | #5F8A4C | (alias: `meadowGreen`) |
| `Theme.statusInProgress` | Not-installed status circle | #E0A33A | (alias: `meadowAmber`) |
| `Theme.danger` | Error text, error circle, failed delete | #B5503A | Destructive/error |

### Typography
| Token | Size (pt) | Weight | Face | Scaling | Usage |
|-------|-----------|--------|------|---------|-------|
| `Typography.largeTitle` | 34 | bold | SF Pro | UIFontMetrics(.largeTitle) | (not used in Settings) |
| `Typography.title` | 22 | semibold | SF Pro | UIFontMetrics(.title2) | Recovery key sheet title |
| `Typography.headline` | 16 | semibold | SF Pro | UIFontMetrics(.headline) | Section headers (implicit via Label) |
| `Typography.body` | 16 | regular | SF Pro | UIFontMetrics(.body) | Row labels, recovery key body copy |
| `Typography.callout` | 15 | regular | SF Pro | UIFontMetrics(.callout) | Acknowledgements detail text |
| `Typography.caption` | 12 | regular | SF Pro | UIFontMetrics(.caption1) | Captions, footers, progress %, error text |
| `Typography.label` | 12 | medium | SF Pro | UIFontMetrics(.caption1) | (not used in Settings) |
| `Typography.mono12` | 12 | regular | SF Mono | UIFontMetrics(.caption1) | Recovery key display (fixed-width) |

### Spacing
| Token | Value (pt) | Usage |
|-------|-----------|-------|
| `Spacing.xs` | 4 | Tight gaps (icon + label) |
| `Spacing.s` | 8 | Gaps within components (error pills row spacing) |
| `Spacing.m` | 12 | Horizontal pill padding, internal card vertical padding |
| `Spacing.l` | 16 | Standard outer margin, recovery key padding |
| `Spacing.xl` | 20 | (not primary in Settings) |
| `Spacing.xxl` | 24 | Section header spacing, recovery key header spacing |
| `Spacing.section` | 32 | Between major sections, recovery key top padding |
| `Spacing.hero` | 40 | (not used in Settings) |

### Radii
| Token | Value (pt) | Usage |
|-------|-----------|-------|
| `Radius.card` | 16 | Card/row corners, recovery key box |
| `Radius.control` | 10 | (not used in Settings) |
| `Radius.button` | 16 | (not used as explicit radius in Settings) |
| `Radius.chip` | 15 | (not used in Settings) |

### Metrics
| Token | Value (pt) | Usage |
|-------|-----------|-------|
| `Metrics.minTapTarget` | 44 | Min height for error action pills |
| `Metrics.rowMinHeight` | 44 | List row baseline height |

---

## 7. Penpot Reproduction Notes & Gotchas

### 7.1 List/Row Styling (Not Available in Penpot)
- iOS `.insetGrouped` List style has specific **inset padding, inter-row spacing, and background treatment**
  - Inset margin: ~16–20pt on left/right (varies by screen width)
  - Section header padding: Snug top, generous bottom
  - Row separator: Hairline below each row (except last in section)
  - **Penpot Approach:** Hand-code the row structure as repeating component; use divider lines between rows
- `listRowBackground(Theme.cardBackground)` replaces default system gray → **mock with solid #FCF8EF background on each row rect**

### 7.2 Toggle Control Styling
- iOS native Toggle has **rounded pill shape, variable width**, and green tint (system color, not Squirl token in standard builds)
  - **Penpot Approach:** Create Toggle component showing:
    - Oval pill (width ~51pt, height ~31pt @ default size)
    - Gray background when off, meadowGreen (#5F8A4C) when on
    - White dot (thumb) positioned left (off) or right (on)
    - Shadow: subtle (iOS default)

### 7.3 Label + Icon Alignment
- SwiftUI `Label` with `systemImage` renders icon + text horizontally
  - Icon size: ~16pt baseline for body text
  - Spacing: Tight (Spacing.xs = 4pt)
  - **Penpot Approach:** Group icon (SF Symbol placeholder) + text label; use 4pt horizontal gap

### 7.4 Picker/DisclosingRow
- Picker in insetGrouped List renders as a disclosing row: gray text on left, current selection in secondary color on right, > chevron
  - **Penpot Approach:** Show row label ("Prompt Pace"), right-aligned disclosure text (e.g., "Relaxed") in `Theme.textSecondary`, chevron (>) indicator

### 7.5 ProgressView Styling
- Linear progress bar: track color = system gray, fill color = system green (NOT Squirl token)
  - **Penpot Note:** Use `Theme.meadowGreen` (#5F8A4C) as the fill for consistency with Squirl palette
  - Percentage text is monospaced, secondary color

### 7.6 FlowLayout (Error Pills)
- Custom layout that wraps pill buttons to next line if they exceed row width
  - **Penpot Approach:** Show typical 2–3 pill layout (e.g., "Try again", "Allow on cellular"); note that it REFLOWS at large Dynamic Type
  - Pills have 1pt border (`Theme.separator` #E3DAC7), capsule shape, transparent fill

### 7.7 Conditional Row Visibility
- Med Bar sub-toggles appear/disappear based on parent toggle state
- **Penpot Approach:** Create one board showing all toggles visible (med bar ON), and a second board or state showing only the parent toggle (med bar OFF)

### 7.8 Modal/Sheet Layering
- Recovery Key Sheet is presented modally (NavigationStack + VStack in a sheet)
  - **Penpot Approach:** Create separate artboard/board for the recovery key sheet; link from export section button via prototype interaction or document it as a separate flow

### 7.9 Color Accuracy in Light Mode
- Theme colors are **adaptive light/dark tokens**; ensure you use **light-mode hex values only**:
  - `Theme.background` = #F6F1E7 (warm paper, NOT #F5F5F5 system white)
  - `Theme.cardBackground` = #FCF8EF (cream, NOT system white)
  - `Theme.textSecondary` = #7A7361 (warm tan, NOT system gray)
  - **Critical:** This is not standard iOS system colors; it is Squirl's custom warm palette

### 7.10 No Gradients in Core Settings Screen
- The settings screen itself uses **solid colors only** (`Theme.*` tokens resolve to solid hex)
- The `meadowGradient` (green→amber) is used in other parts of the app (buttons, crescent), but NOT in the Settings List rows themselves
- **Exception:** Primary button in recovery key sheet likely uses the gradient (`.buttonStyle(.primary)`)

### 7.11 Safe Area & Padding
- ScreenContainer handles top safe area (navigation bar / status bar)
- Recovery key sheet uses `.ignoresSafeArea()` on background, but content is padded (Spacing.l, Spacing.section)
  - **Penpot Approach:** Define artboard with standard iPhone safe areas (top status/nav, bottom home indicator) and position content accordingly

### 7.12 Font Metrics & Dynamic Type
- All fonts scale with Dynamic Type (via UIFontMetrics), but **for a static hi-fi mockup, use the BASE sizes** listed in Typography.swift
  - `Typography.caption` = 12pt (base)
  - `Typography.body` = 16pt (base)
  - `Typography.title` = 22pt (base)
  - Do NOT apply scaling; the spec is for the DEFAULT text-size setting

---

## 8. Boards & States Needed for Complete Penpot Mockup

### Board 1: Settings Screen – Main List (All Sections, Default State)
- **Content:** Complete scrollable settings screen showing all 10 sections
- **States Shown:**
  - Med Bar toggles: all visible (parent toggle ON)
  - ModelDownloadRow: Idle/not-installed state
  - All toggles in OFF position (for contrast)
- **Dimensions:** iPhone 14 (390pt wide × scrollable height; typically 844pt, but list scrolls)

### Board 2: Settings Screen – Med Bar Toggle OFF
- **Content:** Same as Board 1 but with "Show Medication Bar" toggle OFF
- **Change:** Med Bar sub-toggles are hidden (removed from view)

### Board 3: ModelDownloadRow – All States
- **Sub-boards:**
  - 3.1: Idle / Not Installed
  - 3.2: Installed
  - 3.3: Downloading (Indeterminate "Starting…")
  - 3.4: Downloading (With Progress %, e.g., 42%)
  - 3.5: Error (No Connection)
  - 3.6: Error (Cellular Blocked with 3 pills)
  - 3.7: Error (Generic / Other)
- **Context:** Show each row in isolation with appropriate trailing status, error message, and actions

### Board 4: Recovery Key Sheet
- **Content:** Full modal view showing recovery key display, copy button, and Done toolbar
- **States:**
  - 4.1: Initial (button says "Copy key" with doc.on.doc icon)
  - 4.2: After Copy (button says "Copied" with checkmark icon, animated state)

### Board 5: Confirmation Alerts (Optional, Documented)
- **5.1:** "Clear All Data?" alert (title + message + destructive/cancel buttons)
- **5.2:** "Couldn't save a copy" error alert (title + message + OK button)

### Board 6: Design Tokens Reference (Documentation)
- **Content:** Table showing all colors (hex + semantic name), typography (size/weight/face), spacing, radius values used in the mockup
- **Purpose:** Hand-off to developers; ensure 1:1 fidelity

---

## 9. Source File References (Cited Line Numbers)

### SettingsView.swift
- Line 39–70: Overall layout, List style, section order
- Line 43: ScreenContainer setup
- Line 58–60: List style and background configuration
- Line 109–130: aiModelsSection
- Line 132–146: systemSection (Storage, Download over Cellular)
- Line 148–161: checkInSection (Prompt Pace picker)
- Line 164–166: medicationBarSection
- Line 168–170: dayCardSection
- Line 172–178: accessibilitySection
- Line 180–195: journalExportSection
- Line 213–221: dangerSection
- Line 223–243: versionSection

### DayCardSettingsSection.swift
- Line 11–21: Calendar section with two toggles

### MedicationBarSettingsSection.swift
- Line 11–34: Medication Bar section with four toggles (one parent, three conditional)

### YourDataSection.swift
- Line 9–21: Your data section with text and Acknowledgements link
- Line 25–54: AcknowledgementsView (secondary screen, for reference)

### JournalExportSection.swift (Part of SettingsView)
- Line 30–86: RecoveryKeySheet full modal view

### ModelDownloadRow.swift
- Line 3–167: Complete component with all states
- Line 26–41: Main content VStack and header row
- Line 65–101: trailingStatus builder (all state variants)
- Line 103–122: errorBlock builder
- Line 124–135: ghostPill builder (error action buttons)

### SettingsViewModel.swift
- Line 135–146: message(for:) — plain-language error copy

### Design System Files
- **Typography.swift:** Line 1–72 (all font tokens)
- **Theme.swift:** Line 1–44 (all color tokens)
- **Spacing.swift:** Line 1–25 (all spacing tokens)
- **Radius.swift:** Line 1–13 (all radius tokens)
- **Metrics.swift:** Line 1–68 (all metric tokens)

---

## Appendix A: Exact Copy (Verbatim from Source)

### Section Headers
- "AI Models" (SettingsView.swift:110)
- "System" (line 133)
- "Check-in" (line 157)
- "Medication Bar" (MedicationBarSettingsSection.swift:11)
- "Calendar" (DayCardSettingsSection.swift:11)
- "Accessibility" (SettingsView.swift:173)
- "Your data" (YourDataSection.swift:9)

### Row Labels
- "Storage" (SettingsView.swift:134)
- "Download over Cellular" (line 140)
- "Prompt Pace" (line 150)
- "Show Medication Bar" (MedicationBarSettingsSection.swift:12)
- "Show Medication Name" (line 18)
- "Show Taken Time" (line 23)
- "Show End Time" (line 28)
- "Always expand cards" (DayCardSettingsSection.swift:12)
- "Auto-expand selected day" (line 17)
- "Acknowledgements" (YourDataSection.swift:17)
- "Save a copy of my journal — yours to keep" (SettingsView.swift:184)
- "Clear All Data" (line 218)
- Voice Transcription (ModelDownloadRow: title parameter)

### Captions & Footers
- "~150 MB · Wi-Fi recommended" (ModelDownloadRow.swift:37)
- "How long each prompt stays on screen during a voice check-in." (SettingsView.swift:159)
- "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." (YourDataSection.swift:10)
- "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations." (SettingsView.swift:174)
- "Saves one encrypted file you can keep or share. We'll show you a key to open it — keep it safe. If you lose the key, the backup can't be recovered — not even by us." (line 193)
- "Keep this key safe" (JournalExportSection.swift:41)
- "This file can only be opened by a future version of Squirl, using this exact key. If you lose the key, the backup can't be recovered — not even by us. Save it somewhere only you can reach." (line 44)
- "No connection. Reconnect to the internet, then try again." (SettingsViewModel.swift:138)
- "Not enough space on this device. Free up some room, then try again." (line 140)
- "You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular below." (line 142)
- "The download didn't finish. Try again in a moment." (line 144)
- "Couldn't save a copy" (SettingsView.swift:100)
- "Something went wrong preparing your backup. Please try again." (line 103)
- "Clear All Data?" (line 75)
- "This permanently deletes all your recordings and check-ins. Your downloaded transcription model and preferences are kept. This can't be undone." (line 81)

---

**End of Specification**
