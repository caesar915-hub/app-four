# Quickstart — build, test, verify (Spec 045)

## Build (Simulator — this session; device unavailable)
```bash
cd /Users/caesargrey/Projects/app-four/.claude/worktrees/speech-transcriber-probe
xcodebuild build -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS Simulator,id=C49AC93D-B5BE-4CB2-A759-AB8B6731587A' \
  -derivedDataPath /tmp/af-dd -skipMacroValidation CODE_SIGNING_ALLOWED=NO
```

## Test (full suite; test-first gate)
```bash
xcodebuild test -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS Simulator,id=C49AC93D-B5BE-4CB2-A759-AB8B6731587A' \
  -derivedDataPath /tmp/af-dd -skipMacroValidation CODE_SIGNING_ALLOWED=NO
# Only the new suites while iterating:
#   -only-testing:app-fourTests/SpeechAnalyzerCapabilityTests
#   -only-testing:app-fourTests/SpeechAnalyzerTranscriptionServiceTests
```
New-logic tests must FAIL first (RED), then pass (GREEN). Tests never touch the live Speech SDK (Simulator `isAvailable == false`); they exercise pure logic + fakes.

## Verify success criteria
- **SC-006 (WhisperKit gone):** `grep -rn "WhisperKit" app-four app-four.xcodeproj/project.pbxproj` → **0** (after the removal phase; `WhisperCLI/` excluded — separate package).
- **SC-001 (footprint):** app no longer downloads `openai_whisper-small` (~484 MB); `ModelConstants.whisperDownloadBase` removed.
- **SC-007 (no regression):** full `app-fourTests` green; existing recordings/transcripts intact.

## Device QA (owner — required before merge, cannot be automated)
On the physical iPhone 12 Pro (A14, iOS 26): record a check-in → confirm live partial text → final transcript → extraction runs. Test airplane-mode after assets installed; test a fresh install first-run (asset download + pending-queue drain); test an interruption (incoming call) mid-record. Confirm `en-PT`-style regional locale resolves and transcribes.

## Guardrail
Branch `feat/speech-transcriber-probe` only. Do NOT merge or TestFlight until owner device QA passes. PR is review-only.
