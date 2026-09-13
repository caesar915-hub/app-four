# Feature Specification: Gemma 4 E2B Extraction via LiteRT-LM

**Feature Branch**: `056-gemma4-litert-extraction`

**Created**: 2026-09-13

**Status**: Draft (autonomous /speckit run — device verification pending)

**Input**: User description: "Adopt Gemma 4 E2B, text-only, via Google LiteRT-LM as a new SummarizationService backend for on-device extraction, targeting the iPhone 12 Pro (A14, 6 GB). Add the LiteRT-LM Swift runtime; download the mobile-QAT .litertlm artifact via the existing download-not-bundle pipeline; run the existing two-pass narrative→signals flow retuned for Gemma 4's chat template; keep it strictly text-only; enforce sequential model residency; gate by device RAM; and replace the current Qwen2.5-1.5B (MLX) baseline as the sole extraction runtime for the Shipaton build."

**Source**: [`docs/engineering/gemma4-e2b-litertlm-integration-brief.md`](../../docs/engineering/gemma4-e2b-litertlm-integration-brief.md) (clarify-resolved 2026-09-13) · companion [`gemma-ondevice-comparison-2026-09.md`](../../docs/engineering/gemma-ondevice-comparison-2026-09.md)

**Clarify decisions carried in** (owner, 2026-09-13): **D1** pass-2 uses Tool Use / function calling (upgrade over free-form; free-form + validator is the proven-equivalent baseline). **D2** MLX is dropped from the extraction path for the Shipaton build — LiteRT is the *sole* runtime, **no runtime fallback**. **D3** in-scope for the Shipaton App-Review submission (~Sep 23), Early-Preview runtime risk accepted.

> **Verified-fact note (2026-09-13):** the current `MLXJournalService` (Qwen2.5-1.5B) achieves JSON validity via prompt engineering + `ExtractionValidator`'s 3-stage recovery + one correction retry — it has **never** used grammar-constrained decoding. LiteRT-LM lacking constrained decoding therefore removes **no** capability the app relies on; Gemma 4 E2B (IFEval 94.6) with the same validator is expected to exceed Qwen (IFEval 42.5).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Gemma 4 signal extraction from a transcript (Priority: P1)

After a voice check-in is transcribed on-device, the transcript is fed to Gemma 4 E2B running under LiteRT-LM, which produces the same structured signals (mood, energy, focus, sleep, medications, side effects, emotions, topics, summary) the app already consumes — replacing the Qwen2.5-1.5B/MLX backend.

**Why this priority**: Core purpose. Without Gemma producing valid, correctly-labelled signals from a transcript, nothing downstream (validation, persistence, day-card, insights) functions.

**Independent Test**: Pass a representative transcript to the new service's `summarize(rawTranscription:)` and verify it returns a `SummaryResult` whose signals match `Levels.swift` enum rawValues, on par with or better than the Qwen baseline on the shared eval fixtures.

**Acceptance Scenarios**:
1. **Given** a clean transcript ("Took my Vyvanse this morning. Energy is steady, focus is sharp but I zoned out after lunch."), **When** `summarize(rawTranscription:)` runs, **Then** the returned `SummaryResult` has mood/energy/focus mapped to valid labels and a medication entry for "Vyvanse".
2. **Given** the model is installed but not resident (cold start), **When** `summarize()` is called, **Then** the LiteRT engine loads lazily by file path and inference completes, and a subsequent call within the idle window reuses the resident engine.
3. **Given** ADHD community slang ("brain keeps switching tabs", "took my addy"), **When** extraction runs, **Then** slang maps to correct labels because the lexicon vocabulary seeds the system prompt (identical mechanism to today).

---

### User Story 2 — Additive backend behind the SummarizationService seam (Priority: P1)

The Gemma backend is a new type conforming to the existing `SummarizationService` protocol. It ships **additively and inert** (behind a compile guard, DI unchanged) until it is proven on a physical iPhone 12 Pro; the production switchover (DI binding, model-repo repoint, MLX removal) is a separate, gated step. Downstream consumers (`ProcessingViewModel`, `PendingTranscriptionServiceImpl`) require **zero** changes.

**Why this priority**: The protocol is the integration boundary. Additive-first keeps `main` releasable and the app buildable while the Early-Preview runtime is unverified on-device.

**Independent Test**: With the DI binding still pointing at `MLXJournalService`, build + run the full suite green; separately, unit-test the Gemma service's model-agnostic paths (empty input, memory gate, lifecycle) without loading a real model.

**Acceptance Scenarios**:
1. **Given** the Gemma backend exists but the DI binding is unchanged, **When** the app builds and the default test plan runs, **Then** everything is green and behaviour is identical to today (MLX/Qwen still live).
2. **Given** the switchover step flips the single DI binding to the Gemma service, **When** `ProcessingViewModel`/`PendingTranscriptionServiceImpl` call `summarize()`, **Then** they receive a valid `SummaryResult` with no caller code changes.

---

### User Story 3 — Gemma chat-template rendering + prompt retune (Priority: P1)

The two-pass prompts (narrative summary → structured signals) are reused, but the **chat template** is now the app's responsibility: LiteRT-LM does not apply a tokenizer chat template the way MLX/swift-transformers did. The transcript + system prompt are rendered into Gemma 4's turn format (`<start_of_turn>user … <end_of_turn>\n<start_of_turn>model\n`), and the few-shot examples are retuned for Gemma's instruction-following.

**Why this priority**: With MLX gone, nothing applies the chat template automatically. Wrong turn framing degrades or breaks generation. This is net-new, model-specific, and fully unit-testable independent of the runtime.

**Independent Test**: Render a known (system, user) pair through the Gemma chat-template formatter and assert the exact turn-delimited string, including role markers and the trailing model-turn opener — with no LiteRT dependency.

**Acceptance Scenarios**:
1. **Given** a system prompt and a user message, **When** the formatter renders a single-turn prompt, **Then** the output is exactly `<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n<start_of_turn>model\n` (Gemma has no dedicated system role; system text is folded into the first user turn).
2. **Given** the signals system prompt with lexicon + enum labels injected, **When** rendered for Gemma, **Then** all mood/energy/focus/sleep rawValues and the medication list are present, exactly as the Qwen path injected them.

---

### User Story 4 — Structured pass-2 via Tool Use / function calling (Priority: P2)

Pass-2 (strict signals) is expressed as a **Tool Use / function-calling** contract: the signals schema is declared as a tool the model calls with typed arguments, which LiteRT parses into a structured payload. `ExtractionValidator` remains the backstop (parse-recovery + clamp/repair + one correction retry). If the tool-call path yields no usable payload, the free-form-JSON + validator path (the proven Qwen-equivalent) is used.

**Why this priority**: D1 owner decision. It is an *upgrade* to structure quality, not a prerequisite — the free-form path already works without constrained decoding. Below P1 because the baseline is proven.

**Independent Test**: Map a representative tool-call argument payload → `UnifiedExtraction` and assert field-by-field equivalence with the free-form JSON path; verify the validator backstop repairs a malformed payload identically in both paths.

**Acceptance Scenarios**:
1. **Given** the model emits a well-formed tool call, **When** pass-2 runs, **Then** the arguments decode to `UnifiedExtraction` and validate to a `SummaryResult` at least as complete as the free-form path.
2. **Given** the model emits no tool call or a malformed one, **When** pass-2 runs, **Then** the service falls through to free-form JSON parsing + `ExtractionValidator` recovery + one correction retry, and still returns a validated result.

---

### User Story 5 — Single-file `.litertlm` download via the existing pipeline (Priority: P2)

The Gemma artifact is a single LFS `.litertlm` file (CPU build `gemma-4-E2B-it.litertlm`, 2.41 GiB). It is fetched through the existing background download-not-bundle pipeline (repointed at the LiteRT community repo), stored under the LLM models directory, and its presence is verified by a `.litertlm`-aware installed-check (not the `.safetensors` check MLX used).

**Why this priority**: Load-bearing but reuses proven infrastructure (`BackgroundLLMDownloadService` is generic over repo id). Below core extraction because it is plumbing.

**Independent Test**: Point the installed-check at a directory containing a stub `.litertlm` and assert "installed"; point it at an empty/partial directory and assert "not installed" → surfaces as `.modelNotInstalled`.

**Acceptance Scenarios**:
1. **Given** the LiteRT model directory contains the expected `.litertlm` file at the expected size, **When** the installed-check runs, **Then** it reports installed and extraction may proceed.
2. **Given** the file is absent or truncated, **When** `summarize()` is called, **Then** the service throws `.modelNotInstalled` and the raw transcript is preserved (never lost).

---

### User Story 6 — Text-only, RAM-gated, sequential residency (Priority: P2)

Gemma 4 E2B is natively multimodal; the app loads and uses it **text-only** (vision/audio towers never constructed — they would push resident memory past the 6 GB ceiling). Before constructing the engine, headroom is checked via `os_proc_available_memory()`; any prior model runtime is torn down first; and the engine is unloaded on background/memory-warning/idle. **Per D2 there is no runtime fallback:** if the RAM gate fails, extraction is declined (raw transcript preserved) rather than falling back to another model.

**Why this priority**: The entire feasibility argument rests on staying under the A14 memory ceiling. It is a guardrail around the core flow.

**Independent Test**: Drive the memory-headroom check and lifecycle eviction hooks with faked signals (no real model) and assert load-gating and eviction behaviour, mirroring the existing `MLXJournalService` lifecycle tests.

**Acceptance Scenarios**:
1. **Given** headroom ≥ the configured minimum with no other model resident, **When** `summarize()` is called, **Then** the engine loads text-only by file path and inference proceeds.
2. **Given** headroom below the minimum, **When** `summarize()` is called, **Then** extraction is declined with `.insufficientMemory`, the raw transcript is preserved, the app does not crash, **and no fallback model is loaded** (D2).
3. **Given** the app is backgrounded or receives a memory warning, or the idle timer fires, **When** the lifecycle observer triggers, **Then** the engine is unloaded and memory reclaimed.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures (model download)
- **Scenario:** Connection drops mid-download of the 2.41 GiB `.litertlm`.
- **System Behavior:** The existing background `URLSession` resumes by byte range on reconnect; a stale-resume (412/416) auto-restarts the file. Extraction that is attempted before the file is complete throws `.modelNotInstalled`.
- **UX:** The model-management surface shows download progress/failed state with a retry; check-ins recorded before the model is ready keep their raw transcript and are re-extractable later. Export is never blocked.

#### 2. Data Validation & Bad Input (model output)
- **Scenario:** Gemma emits a malformed tool call, non-JSON prose, fenced JSON, or reasoning ("thinking") text before the payload.
- **System Behavior:** Tool-call path first; on failure, free-form parse with 3-stage recovery (direct decode → strip fences → first-`{`-to-last-`}`), then one correction-prompt retry, then `ExtractionValidator` clamp/repair. Thinking output is bounded to ~0 so pass-2 emits the payload without preamble. A still-unparseable result yields an empty-but-valid `SummaryResult` (raw transcript retained as the bullet).
- **UX:** The user always gets a saved entry containing at least their transcript; signals may be sparse but never a crash or data loss.

#### 3. State Restoration & Interruptions
- **Scenario:** App is backgrounded or terminated mid-inference or mid-download.
- **System Behavior:** The engine is unloaded on background entry (backgrounded apps get <50 MB). Downloads continue out-of-process via the background session. In-flight inference is not resumable — the transcript remains and extraction re-runs on next foreground processing.
- **UX:** No partial/corrupt entries; a pending entry re-processes cleanly.

#### 4. Hardware/Permission & Capability Denials
- **Scenario A — device below the RAM bar:** `physicalMemory`/headroom insufficient for Gemma text-only.
- **System Behavior:** Extraction declined (`.insufficientMemory`), transcript preserved, **no fallback** (D2). This is the accepted-risk case: on an unmeasured A14, a gate-fail degrades to transcription-only.
- **Scenario B — runtime unavailable at build/link:** the LiteRT-LM package is not present (Early Preview, device-gated tonight).
- **System Behavior:** The live LiteRT calls are compiled only when the package is available (`#if canImport`); otherwise the Gemma service reports `.modelNotInstalled` for the engine path. The app builds and runs regardless.
- **UX:** Until the switchover, users see the unchanged Qwen/MLX behaviour.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a new extraction backend conforming to the existing `SummarizationService` protocol (`summarize(rawTranscription:) async throws -> SummaryResult`), returning the same `SummaryResult` shape downstream consumers already use.
- **FR-002**: The backend MUST run Gemma 4 E2B under LiteRT-LM, loading the model **by file path** (never by in-memory bytes) to preserve memory-mapping.
- **FR-003**: The backend MUST use the model **text-only** — vision and audio backends MUST NOT be constructed, and image/audio inputs MUST NOT be passed.
- **FR-004**: The system MUST render prompts into Gemma 4's chat-turn format itself (no reliance on an automatic tokenizer chat template), folding system text into the first user turn.
- **FR-005**: Pass-2 (structured signals) MUST be attempted via Tool Use / function calling (D1); on absence or malformation of a tool call, the system MUST fall through to free-form JSON parsing with the existing 3-stage recovery + one correction retry.
- **FR-006**: The system MUST reuse `ExtractionValidator` (parse → clamp/repair → assemble) and the curated lexicon **verbatim**; signal values MUST be validated against `Levels.swift` enum rawValues, non-canonical values clamped to `nil`.
- **FR-007**: The system MUST bound model "thinking"/reasoning output for pass-2 so structured output is emitted without reasoning preamble.
- **FR-008**: The system MUST download the single `.litertlm` artifact through the existing background download-not-bundle pipeline, repointed at the LiteRT community repo, and MUST verify installation with a `.litertlm`-aware check (superseding the `.safetensors` check).
- **FR-009**: Before constructing the engine, the system MUST verify memory headroom via `os_proc_available_memory()` and MUST tear down any other resident model runtime first (sequential residency).
- **FR-010**: The system MUST unload the engine on app-background entry, memory-warning, and idle timeout, reclaiming resident memory.
- **FR-011**: On any verification/inference failure, the system MUST preserve the raw transcript and surface a typed `SummarizationError` (`.modelNotInstalled`, `.insufficientMemory`, `.parsingFailed`, `.inferenceFailed`, `.timeout`); it MUST NOT lose user data or crash.
- **FR-012**: Per D2, on RAM-gate failure the system MUST decline extraction (transcript-only) and MUST NOT load any fallback model in the shipped build.
- **FR-013**: The backend MUST ship **additively and inert** (compile-guarded, DI binding unchanged) in this feature; the production switchover (DI binding flip, `llmHubRepoID` repoint, MLX removal from the extraction path) MUST be a distinct step gated on physical iPhone 12 Pro verification.
- **FR-014**: Diagnostics MUST record only counts, durations, resident-memory figures, backend, and token estimates — never transcript text or medication content (Principle VI).
- **FR-015**: The backend MUST expose the same DEBUG-only test hooks shape as `MLXJournalService` (fake "loaded", idle-timer arm, model-loaded query) so the fast suite stays hermetic and never touches the live runtime.

### Key Entities

- **Gemma extraction service**: the `SummarizationService` conformer; owns model residency, the two-pass flow, and error mapping.
- **Gemma chat-template formatter**: pure value type; (system, user[, few-shots]) → Gemma turn-delimited string. No runtime dependency.
- **Signals tool schema**: the typed function-call contract for pass-2, mapping to `UnifiedExtraction`.
- **LiteRT model artifact**: single `.litertlm` file (CPU build 2.41 GiB / GPU build 1.87 GiB); downloaded, not bundled; verified by presence + size.
- **`SummaryResult` / `UnifiedExtraction` / lexicon / `ExtractionValidator`**: reused verbatim; unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-1** *(device-gated)*: On a physical iPhone 12 Pro with any prior model torn down, extraction runs end-to-end without a jetsam kill; logged resident `phys_footprint` is below the device ceiling (record the number + backend).
- **SC-2**: JSON/tool-call validity is **≥ the Qwen baseline** on the shared eval fixtures after `ExtractionValidator` + retry. **SC-2a**: measured tool-call schema-conformance rate on-device (a model-reliability metric — no constrained-decoding guarantee exists).
- **SC-3**: Signal-field correctness (micro-averaged P/R) is **≥ the Qwen baseline** on the shared eval set; expected to exceed it given IFEval 94.6 vs 42.5.
- **SC-4** *(device-gated)*: Sustained decode ≥ ~8 tok/s on A14 for the two-pass flow (background task; not interactive).
- **SC-5**: The full default test suite is green; `SummarizationService` API unchanged; no ViewModel/View edits; the chat-template formatter, tool-schema mapping, installed-check, and memory/lifecycle logic are unit-tested on the simulator.
- **SC-6**: The app builds and behaves identically to today while the backend is inert (additive); the switchover is a single documented, reversible change.

## Assumptions

- The current app state (post-045 SpeechAnalyzer, constitution v2.3.0) is the base; transcription is independent of this feature.
- `BackgroundLLMDownloadService` is generic over repo id and works for the LiteRT community repo's file tree (verified single `.litertlm` file).
- The CPU/XNNPACK build is the A14 default (~607 MB resident target); GPU/Metal (~1.45 GB) is an opt-in only if on-device headroom is later confirmed.
- LiteRT-LM's Swift API matches the documented Early-Preview surface (`EngineConfig(modelPath:backend:maxNumTokens:cacheDir:)` → `Engine.initialize()` → `createConversation()` → `sendMessage`); deltas are expected and are resolved during device integration.
- Simulator builds/tests validate compilation and all model-agnostic logic; they **cannot** validate A14 memory behaviour (SC-1/SC-4), which requires the physical device.

## Dependencies & Accepted Risks

- **New dependency**: LiteRT-LM Swift package (`LiteRTLM` ≥ 0.12.0), **🚀 Early Preview** — API is moving. Adopted on the critical path per D3.
- **No runtime fallback** (D2): LiteRT is the sole extraction runtime in the Shipaton build. A gate-fail or on-device failure degrades to transcription-only.
- **Unmeasured target**: no real iPhone 12 Pro (A14) memory measurement exists (only iPhone 14/A15). SC-1/SC-4 are the load-bearing device gates.
- **Timeline**: in-scope for the ~Sep 23 App-Review submission; Early-Preview runtime + Early-Preview Tool Use on the critical path is an accepted schedule risk (recorded in the brief's senior-engineer flag).

## Out of Scope

- Transcription (owned by spec 045 / SpeechAnalyzer).
- Multimodal (vision/audio) — infeasible on 6 GB.
- SwiftData schema changes; `ExtractionValidator`/lexicon logic changes.
- The Gemma 3 1B / MLX alternative path (companion brief — not chosen).
- Any ViewModel/View change.
