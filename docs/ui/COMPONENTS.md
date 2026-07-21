# Components


_Last updated: 2026-06-28_
This directory contains reusable UI components shared across multiple screens in `app-four/Views/Components/`.

## Component Catalog

### Cards & List Items

| Component | Purpose | Used By |
|-----------|---------|---------|
| `DayCard.swift` | Folding card for a single day's entries | Library |
| `FoldedDayCardHeader.swift` | Day card header with mood tint | `DayCard` |
| `TimelineRow.swift` | Single recording/dose row inside a day card | `DayCard` |
| `TimelineBead.swift` | Timeline connector bead | `TimelineRow` |
| `RecordingRow.swift` | Recording row for day-detail sheet | `DayDetailSheet` |
| `DayDetailSheet.swift` | Sheet showing all recordings for a selected day | `InsightsView` |

### Inputs

| Component | Purpose | Used By |
|-----------|---------|---------|
| `Chip.swift` | Selectable pill chip | `ExtractionReviewView` |
| `GlyphRampPicker.swift` | Signal level picker with custom glyphs | `TextCheckInComposer`, `ExtractionReviewView` |
| `TagFlowView.swift` | Flow layout for tags | `ADHDSummarySection` |

### Sheets

| Component | Purpose | Used By |
|-----------|---------|---------|
| `MedicationLogSheet.swift` | Manual dose logging sheet | `MedicationBarView` |

### Media

| Component | Purpose | Used By |
|-----------|---------|---------|
| `AudioPlayerView.swift` | Audio playback controls | `RecordingDetailView` |
| `PlaybackWaveformBars.swift` | Playback waveform visualization | `AudioPlayerView` |

### Data Display

| Component | Purpose | Used By |
|-----------|---------|---------|
| `ADHDSummarySection.swift` | Structured summary section | `RecordingDetailView` |
| `MedicationBarView.swift` | Active effect window bar | Multiple screens via `MedicationBarOverlay` / `ScreenContainer` |

### Calendar

| Component | Purpose | Used By |
|-----------|---------|---------|
| `CalendarHeaderView.swift` | Week/month calendar header | Library |
| `CalendarDayCell.swift` | Individual day cell | `CalendarHeaderView` |

### Settings

| Component | Purpose | Used By |
|-----------|---------|---------|
| `ModelDownloadRow.swift` | Model download/delete row | Settings |

### Effects

| Component | Purpose | Used By |
|-----------|---------|---------|
| `EdgeFadeMask.swift` | Top/bottom gradient fade `ViewModifier` | `ScreenContainer`, Library, Insights |

### Value-Type Helpers (not Views)

| Component | Purpose | Used By |
|-----------|---------|---------|
| `DayCardSummary.swift` | Pure derivation of a day-card's folded summary from its timeline nodes | `FoldedDayCardHeader` |

### External Design System

| Component | Package | Purpose |
|-----------|---------|---------|
| `SignalGlyph` | `SquirlDesignSystem` | Unified signal glyph rendering | Multiple screens |

## Adding a Component

1. Create a new file in `app-four/Views/Components/`.
2. Keep the component focused and reusable.
3. Accept configuration via initializer parameters, not via global state.
4. Add a preview showing representative states.
5. Update this catalog.
