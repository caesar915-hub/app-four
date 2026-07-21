# Settings Screen


_Last updated: 2026-06-28_
The Settings screen groups model management, preferences, data export, and debugging tools into a standard grouped list.

## Files

| File | Purpose |
|------|---------|
| `SettingsView.swift` | Main settings list, export flow, alerts |

## Supporting Components

| Component | Purpose |
|-----------|---------|
| `DayCardSettingsSection.swift` | Day card expansion preferences |
| `MedicationBarSettingsSection.swift` | Medication bar visibility preferences |
| `JournalExportSection.swift` | Encrypted export UI |
| `YourDataSection.swift` | On-device privacy promise + acknowledgements |
| `ModelDownloadRow.swift` | Model download/delete row |

## ViewModel

- [`SettingsViewModel`](../../../app-four/ViewModels/SettingsViewModel.swift)

## Screen Container

`SettingsView` is wrapped in `ScreenContainer` with the medication bar overlay; the internal `List` manages its own scroll.

## Sections

| Section | Contents |
|---------|----------|
| AI Models | Whisper model download/delete/progress |
| System | Storage summary, cellular download toggle |
| Check-in | Prompt pace picker |
| Day Card | Auto-expand on selection, always expand cards |
| Medication Bar | Show bar, show name, show taken time, show end time |
| Accessibility | Text footer explaining system Reduce Motion |
| Your Data | On-device privacy promise, acknowledgements |
| Export Journal | Encrypted backup export |
| Danger | Clear all data |
| Version | App version (5-tap in debug/TestFlight opens debug console) |

## Encrypted Export Flow

1. User taps **Save a copy of my journal — yours to keep**.
2. `ExportService` prepares an encrypted document.
3. `fileExporter` presents the system share sheet.
4. On success, a recovery key sheet appears; on failure, an alert is shown (`exportFailed`).
5. The recovery key is never persisted; it exists only in transient view state.

## Debug Console

A hidden debug console (`TestServicesView`) is available in debug/TestFlight builds via a 5-tap on the version label.

## Related Specs

- Spec 003 — Transcription lifecycle
