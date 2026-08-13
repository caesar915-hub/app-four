# Quickstart: 043-mlx-journal-service

To get started with the `043-mlx-journal-service` feature in development:

## 1. Model Downloads (managed lifecycle)
Both on-device models are managed via `AIModelService`:
- **Whisper** (~40–150 MB, transcription) — downloads from onboarding, Settings › AI Models, or the launch-time background task.
- **Llama 3.2 1B 4-bit** (~740 MB, extraction) — same three paths; lands in `Library/llama/` (HubApi cache layout).

`MLXJournalService` loads only from that managed directory and throws `SummarizationError.modelNotInstalled` if absent — it never downloads implicitly. In the simulator, tests exercise this fail-fast path; for a real extraction run, download the model first (Settings row works in DEBUG builds).

## 2. Simulating Low Memory
To test the `os_proc_available_memory() < 200MB` fallback, you can either:
- Use an older device (e.g., iPhone 12 Pro) and open several memory-heavy apps.
- Temporarily mock the memory check to return `< 200MB` in development to ensure the "Not Enough Memory" alert and graceful fallback work without crashing.

## 3. Background Task Expiration
To test the background task expiration handler:
1. Start an extraction in the app.
2. Immediately background the app.
3. In Xcode, simulate a background task expiration (Debug > Simulate Background Fetch or by using Instruments). 
4. Ensure the UI shows "Processing..." and the extraction correctly resumes/retries on the next launch.

## 4. Device QA
See `device-qa-checklist.md` in this directory for the full on-device test matrix.
