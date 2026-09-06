# Convergence — Spec 045 (SpeechAnalyzer migration)

Cross-check of spec ↔ plan ↔ tasks ↔ implementation after the autonomous pipeline run (2026-09-06). "speckit-converge" is non-standard; this is the convergence/consistency pass in its place.

## Build/test state
- Baseline (pre-change): `app-fourTests` **544/544 passed** on iOS 26 Simulator (iPhone 17 Pro).
- After Phase 2 additive code: **553/553 passed** (+9 new tests). `** TEST SUCCEEDED **`, exit 0.
- Device (`iPhone 12 Pro`) was **unavailable** this session → all verification on Simulator; on-device QA is owner-pending.

## Requirement coverage (FR / SC)

| Item | State | Where |
|---|---|---|
| FR-001 on-device only | Designed + partially implemented | plan §Technical Context; engine uses on-device `SpeechAnalyzer` |
| FR-002 SpeechTranscriber primary | **Implemented (additive, unwired)** | `SpeechAnalyzerTranscriptionService` |
| FR-003 auto fallback to Dictation | Ladder **logic implemented + tested**; Dictation *module* deferred | `SpeechAnalyzerCapability` (tested); T012 |
| FR-004 locale via equivalentTo | **Implemented + tested** | capability + service |
| FR-005 system-managed assets | **Implemented** | `AssetInventory` in service |
| FR-006 no WhisperKit | **Not yet** (destructive-last) | T015–T021 |
| FR-007 live/partial results | Deferred | T007–T010 |
| FR-008 pending-not-lost | Design done; reconciliation deferred | data-model §state; T013 |
| FR-009 seam unchanged / extraction untouched | **Holds** | no change to `SummarizationService`/`MLXJournalService` |
| FR-010 mic-denial handling | Existing behavior retained | (live path T008/T010) |
| FR-011 silent/empty audio | **Implemented + tested** | `makeFinalSegment` → "(no speech detected)" |
| FR-013 behind protocol | **Holds** | conforms to `TranscriptionService`; no VM/View change |
| FR-015 logs counts only | **Implemented** | service logging |
| FR-016 per-recording selection | Logic present | capability resolver |
| FR-017 remove SFSpeech path | **Not yet** | T015 |
| FR-018 live streaming | Deferred | T007–T010 |
| FR-019 no vocab biasing | **Holds** (none added) | — |
| FR-020 no user migration | **Holds** (no data touched) | — |
| SC-001 footprint −~500 MB | Pending removal | T017/T019 |
| SC-006 WhisperKit grep = 0 | **Not yet** (WhisperKit intact by design) | T021 |
| SC-007 no regression / suite green | **Holds** | 553/553 |

## Consistency checks
- Plan's additive-first/removal-last sequencing is reflected in tasks (Phase 2 done; Phases 3–5 deferred) and in the actual commits (WhisperKit untouched, engine unwired).
- Constitution amended (2.3.0) consistent with the removal the tasks will perform; no other doc contradicts.
- Data-model claim "no SwiftData change" holds — no model files touched.
- Contract (`contracts/transcription-service.md`) describes a live entry point not yet added to the protocol — flagged as T007; the file-based method matches the shipped code.

## Open findings carried forward (from code review)
- **MAJ-1**: explicit `analyzer.cancelAndFinishNow()` on cancel → T009.
- **MIN-1**: factor `loadModel`/inline install duplication → T009.
- **MIN-2**: map `SFSpeechError.Code` to clearer copy → T014.

## Verdict
The additive foundation (primary-engine service + capability ladder) is **complete, tested, green, and non-disruptive**. The remainder of the migration — live streaming (P1 US1 wiring), DictationTranscriber module + pending reconciliation (P2), and WhisperKit/SFSpeech removal (P3, destructive-last) — is **staged and unstarted**, gated on owner device QA. This is a **multi-session migration**; the branch is in a clean, buildable, releasable-of-itself state at every commit.
