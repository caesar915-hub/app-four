# WhisperNotes: Project Context

## 1. Project Vision
**WhisperNotes** is a privacy-first, high-performance voice memo application for iOS. Its primary goal is to provide **100% on-device, local AI transcription and summarization** that rivals cloud services in accuracy while maintaining absolute user data sovereignty.

## 2. Core Technology Stack
- **Language**: Swift 6 (Strict Concurrency)
- **Framework**: SwiftUI (iOS 26 Target)
- **Persistence**: SwiftData (relationship-driven schema) + JSON flat file (diagnostics)
- **Transcription**: WhisperKit (`openai_whisper-small`, CoreML, Apple Neural Engine)
- **Summarization**: Gemma 3 1B IT (CoreML, dynamic feature inference)
- **Audio Engine**: `AVAudioEngine` + `AVAudioConverter` (16kHz PCM buffer processing)
- **Design System**: Liquid Glass (material-heavy, native-feeling UI)

## 3. Current Project State

| Phase | Description | Status |
| :--- | :--- | :--- |
| Phase 1 | UI Shell, navigation, glass components, mock waveform | ✅ Complete |
| Phase 2A | SwiftData schema, service protocols, enums | ✅ Complete |
| Phase 2B | `AVAudioEngine` recording, 16kHz resampling, interruption handling | ✅ Complete |
| Phase 2C | WhisperKit transcription (file + live stream), medical prompt conditioning, `MedicalTermCorrector` | ✅ Complete |
| Phase 2D | Gemma AI summarization, auto-download, topic tagging | ✅ Complete |
| Phase 2E | Diagnostics subsystem (`SessionSnapshot`, `DiagnosticsStore`, `MetricManager`, `ScreenTracker`) | ✅ Complete |
| Phase 2F | Beta feedback system (`FeedbackButton`, `IssueReportView`, Mail/share sheet) | ✅ Complete |
| Phase 3 | Polish & refinement (Pause/Resume wiring, Clear All Data, Folders) | ⏭️ Next |
| Phase 4 | Export & integration (SRT export, Shortcuts support) | 🔜 Planned |

## 4. Key Features

- **Live Transcription**: Real-time text display via WhisperKit during recording (2-second batches).
- **Post-Recording Transcription**: Background transcription with a 90-second timeout after recording stops.
- **Gemma AI Summarization**: On-device structured summaries (Medications, Symptoms, Other Topics) with topic tag chips.
- **Medical Context Prompt**: Optional prompt conditioning for ADHD medication and therapy terminology; post-processing via `MedicalTermCorrector`.
- **Library & Search**: Full-text title search; topic category filter chips; swipe-to-delete; favorites.
- **Glass UI**: Highly polished iOS 26 interface using `.ultraThinMaterial` and the `.glassCard()` modifier system.
- **Beta Feedback**: In-app issue report form with opt-in sensitive data toggles; sends via Mail or share sheet.
- **Export**: JSON transcript export (SRT planned).
- **Privacy**: No audio or transcript data ever leaves the device. No account or internet required for core functionality.
- **URL Scheme**: `whispernotes://checkin` deep link auto-starts recording (for widget/Shortcuts integration).

## 5. Development Roadmap

1. **Phase 1**: UI/UX Prototype — **DONE**
2. **Phase 2A–F**: Hardware, Data, AI, Diagnostics, Feedback — **DONE**
3. **Phase 3**: Pause/Resume wiring, Clear All Data, Folders
4. **Phase 4**: SRT export, Shortcuts integration
