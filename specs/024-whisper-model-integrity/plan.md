# Plan — 024 Whisper model integrity check

## Problem

`AIModelServiceImpl.findWhisperModelFolder(in:)` returns non-nil as soon as the
`openai_whisper-small/` directory exists on disk. WhisperKit creates this directory
skeleton early in the download/move pipeline, so `localPath(for: .whisper)` reports
the model as ready before critical CoreML weight files have been written.

Consequence: `pendingTranscriptionService.drainIfModelReady()` fires and transcription
is attempted on a structurally incomplete model → `modelsUnavailable` crash.

Observed failure: `AudioEncoder.mlmodelc/weights/weight.bin` failed to move from
`.incomplete` cache; directory existed; `localPath` returned non-nil; Settings showed
"Installed"; transcription crashed.

## Fix — one file, one function

**File:** `app-four/Services/AIModelServiceImpl.swift`  
**Function:** `findWhisperModelFolder(in:)` (line 133)

Add two existence checks inside the `openai_whisper-small` guard:
1. `AudioEncoder.mlmodelc/` — the primary CoreML model; absent when weight move fails.
2. `config.json` — root-level config written last by WhisperKit; absent on partial downloads.

Both files must exist for `localPath` to return non-nil.

## Test

**File:** `app-fourTests/Services/WhisperModelIntegrityTests.swift` (new)

Two cases using a `tmp` directory:
1. Directory only → `localPath` returns nil.
2. Directory + `AudioEncoder.mlmodelc/` + `config.json` → `localPath` returns non-nil.

## Constraints

- `findWhisperModelFolder` is `nonisolated static` — stays synchronous, no actor hops.
- No UI changes.
- Commit directly to `main` (owner decision, scope too small for a PR).
