# Feature Specification: Parallel Two-Model Gemma Chat

**Feature Branch**: `spike/gemma-addrec-structured-prompt` (spec directory is independent of branch)
**Created**: 2026-06-21
**Status**: Draft
**Input**: Set up a parallel two-model chat on a Google Cloud VM (NVIDIA T4): run Gemma 3 1B and Gemma 4 E4B concurrently, fronted by a multi-model chat UI so a single prompt returns both responses side by side.

## Why this exists (Context)

The edge-Gemma summarization arm ([spec 001](../001-edge-gemma-summarization/spec.md)) grades tiny Gemma models against the locked flan-large baseline through an automated test-30 harness. Before — and alongside — that quantitative pass, the spike lead needs a **fast, interactive way to qualitatively eyeball two Gemma generations against the same prompt**: send one ADHD-journal-style prompt and read both models' answers next to each other, to build intuition about which model class is worth the heavier eval.

This is **enabling infrastructure for the spike**, not a shipped user feature. The "user" is the spike lead (single operator). Success is operational: the environment stands up, both models stay resident on one T4, and one prompt reliably yields two side-by-side answers. There is no model-quality verdict here — that remains the job of spec 001's pre-registered gate.

## Clarifications

### Session 2026-06-21

- Q: Which model is the second comparison target? → A: **Gemma 4 E4B is the target, no fallback.** Switched from E2B to **E4B** to match the variant already exercised by spike 001 ([gemma3/models.py](../../spikes/flan-t5-summarizer/gemma3/models.py)). Confirmed on Hugging Face as `google/gemma-4-E4B-it` (instruction-tuned), with the vendor QAT 4-bit GGUF `google/gemma-4-E4B-it-qat-q4_0-gguf` (~5.15 GB, apache-2.0, ungated) adopted as the on-device-representative build. Standup still fails fast on a wrong/absent tag.
- Q: Can the models already cached on the VM by spike 001 be reused for this chat tool? → A: **No — different format and runtime.** Spike 001 loads HF safetensors via transformers + bitsandbytes NF4 ([summarize.py](../../spikes/flan-t5-summarizer/gemma3/summarize.py)); the chat tool serves **GGUF via Ollama**, a separate store Ollama cannot populate from the HF cache. The GGUF is therefore a distinct (and more on-device-faithful, vendor-QAT) artifact, pulled fresh — not a reuse of the cached weights.
- Q: How is the chat UI reached on the GCloud VM? → A: **Firewall source-IP allowlist AND UI authentication** — the serving port is opened only to the lead's allowlisted source IP(s), and the UI itself requires a login. Both layers are required, not either/or.
- Q: Should chat history and UI settings survive a VM/container restart? → A: **Persist on a durable volume** — comparison sessions and UI configuration are stored so they survive restarts.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — One prompt, two answers side by side (Priority: P1)

The spike lead opens the chat interface, selects both Gemma models, types a single prompt, and receives both models' responses rendered side by side in the same turn.

**Why this priority**: This is the entire purpose of the tool — without simultaneous dual output there is no comparison.

**Independent Test**: From the chat UI, select both models, submit one prompt, and confirm two distinct response columns appear for that single submission.

**Acceptance Scenarios**:

1. **Given** both models are selected, **When** the lead submits one prompt, **Then** two responses (one per model) are displayed for that turn without re-typing the prompt.
2. **Given** a multi-turn conversation, **When** the lead sends a follow-up, **Then** both models receive the shared conversation context and each produces its own continuation.
3. **Given** one model is slower than the other, **When** responses stream in, **Then** each column populates independently and a slow model does not block display of the faster one.

### User Story 2 — Both models resident on one T4 (Priority: P1)

The lead can keep both Gemma models loaded simultaneously on the single T4 GPU, so neither is evicted and re-loaded between turns.

**Why this priority**: Eviction/reload on every alternating turn would make interactive comparison slow and defeat the "parallel" goal; co-residency is the core infrastructure constraint.

**Independent Test**: After a prompt to both models, inspect the GPU/runtime state and confirm both models are reported as concurrently loaded within the T4's memory budget.

**Acceptance Scenarios**:

1. **Given** both models are pulled, **When** a dual-model prompt is sent, **Then** both models are resident at once and the combined footprint fits within the T4's 16 GB VRAM.
2. **Given** both models are resident, **When** the lead sends several alternating prompts, **Then** no model is unloaded and reloaded between turns under normal idle timing.

### User Story 3 — Reproducible standup of the environment (Priority: P2)

A reader can bring the whole environment up on a fresh GCloud T4 VM from documented steps, and tear it down, without bespoke manual fixes.

**Why this priority**: The VM is shared with the in-progress LoRA and eval tracks; a documented, repeatable standup avoids polluting those environments and lets the tool be recreated on demand. It is a fast-follow, not a blocker for first interactive use.

**Independent Test**: On a clean VM, follow the documented steps end to end and reach a working dual-model chat; run the teardown and confirm the host returns to its prior state.

**Acceptance Scenarios**:

1. **Given** a fresh T4 VM with GPU drivers available, **When** the documented standup steps are followed, **Then** a working two-model chat is reachable by the lead.
2. **Given** a running environment, **When** the documented teardown is run, **Then** the serving processes stop and reserved VRAM is released.

### Edge Cases

- The exact registry tag for the Gemma 4 E4B model is wrong or unavailable → the pull fails fast with an actionable message; the tag is confirmed against the model registry before relying on it.
- A gated model's license has not been accepted → standup halts early with a clear instruction, not a mid-session failure.
- Combined VRAM for both models plus context exceeds the T4 budget → the system surfaces the memory pressure (queuing/eviction) rather than silently degrading; the lead is expected to reduce context or quantization.
- The chat UI is reachable from the public internet → treated as a misconfiguration; access is expected to be restricted to the lead (see Assumptions).
- One model emits a degenerate repetition loop → it is visible in its column and does not corrupt the other model's output.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST send a single user prompt to two selected models in the same turn and display both responses side by side, without the user re-entering the prompt.
- **FR-002**: The system MUST keep both target models — Gemma 3 1B and Gemma 4 E4B — concurrently resident on the single T4 GPU within its 16 GB VRAM budget, so neither is evicted between alternating turns under normal idle timing.
- **FR-003**: Each model's response MUST stream/display independently, so a slower model does not block presentation of the faster model's answer.
- **FR-004**: Both models MUST receive the shared multi-turn conversation context on follow-up prompts, each producing its own continuation.
- **FR-005**: Standup MUST fail fast with an actionable message when a target model is unavailable due to a wrong/absent registry tag or unaccepted license, before the lead begins chatting.
- **FR-006**: The environment MUST run on the existing GCloud T4 VM without disturbing the in-progress LoRA and eval tracks' environments (isolated processes/storage).
- **FR-007**: The standup and teardown MUST be documented as a repeatable procedure that brings the dual-model chat up on a clean T4 VM and releases reserved VRAM on teardown.
- **FR-008**: The chat interface MUST be protected by two layers: (a) a firewall rule that admits the serving port only from the lead's allowlisted source IP(s), AND (b) authentication on the UI itself. It MUST NOT be reachable from unrestricted public network access.
- **FR-009**: The system MUST surface VRAM/memory pressure (e.g., queuing or eviction) rather than silently degrading when combined model + context footprint approaches the T4 budget.
- **FR-010**: Chat history and UI configuration MUST persist on a durable volume so they survive a VM/container restart.

### Key Entities

- **Target model**: one of two Gemma models — Gemma 3 1B and Gemma 4 E4B — each identified by a registry tag and a VRAM footprint; the two compared side by side.
- **Model runtime**: the local serving process that hosts both models concurrently on the T4 and answers prompts; owns the co-residency and memory-pressure behavior.
- **Chat interface**: the multi-model front end the lead interacts with; owns the single-prompt-to-two-columns behavior and shared conversation context.
- **VM environment**: the GCloud T4 host, shared with other tracks; the isolation boundary the standup must respect.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A single submitted prompt returns two distinct model responses in the same turn, every time, with no re-typing.
- **SC-002**: Both target models are confirmed concurrently resident on the one T4, with combined VRAM use within the 16 GB budget, across a multi-turn session with no eviction-reload between turns.
- **SC-003**: From documented steps, the lead can stand up a working two-model chat on a clean T4 VM and tear it down, releasing reserved VRAM, with no undocumented manual fixes.
- **SC-004**: When a model tag is wrong or its license unaccepted, standup stops with a message that names the problem and the corrective action, before any chat session begins.
- **SC-005**: The chat interface rejects connections from any non-allowlisted source IP, and an allowlisted client still cannot use it without authenticating; it is not reachable from the open internet.
- **SC-006**: After a VM/container restart, prior chat history and UI configuration are still present (loaded from the durable volume), with no manual re-creation.

## Assumptions

- **Model identity**: "Gemma 4 E4B" is the Gemma 4 effective-4B variant ("E" = effective parameters; edge tier carried over from Gemma 3n's E2B/E4B). E4B was chosen over E2B to match the variant spike 001 already ran. It is the committed comparison target — no fallback model. Confirmed source: Hugging Face `google/gemma-4-E4B-it` (instruction-tuned), with the vendor QAT 4-bit build `google/gemma-4-E4B-it-qat-q4_0-gguf` (~5.15 GB, apache-2.0, ungated) preferred so the run reflects the real on-device quantization rather than a post-hoc proxy. This GGUF is served by Ollama and is NOT the same artifact as spike 001's transformers/bitsandbytes-NF4 cache — it is pulled fresh into Ollama's own store. Standup verifies the pull resolves and fails fast on a wrong or absent tag rather than substituting another model.
- **Single operator**: the only user is the spike lead; no multi-user concurrency, accounts, or sharing requirements.
- **Purpose is qualitative**: this tool produces interactive side-by-side reads for intuition-building, NOT scored evaluation. Any quantitative verdict comes from spec 001's harness, not from this chat.
- **VRAM headroom**: Gemma 3 1B (sub-1 GB quantized) and a ~2B-effective model fit together with large margin inside the T4's 16 GB; aggressive quantization is not required for co-residency. Combined footprint MUST still be verified after pull.
- **Compute is time-sliced**: on a single T4 the two generations share the GPU's compute units; "parallel" means both models are loaded and serve in the same turn, not that throughput doubles. Acceptable for two sub-3B models.
- **Access model**: the UI is protected by both a firewall source-IP allowlist and UI-level authentication (FR-008); standup documents both layers. It is not reachable from the open internet.
- **GPU drivers present**: the VM already has working NVIDIA drivers and container GPU passthrough, or these are a documented prerequisite of standup, not part of this feature's scope.

## Out of Scope

- **Model-quality verdict**: no faithfulness/completeness/fallback scoring here — that is spec 001's pre-registered gate. This tool draws no conclusion about which Gemma is better.
- **Automated batch evaluation**: no test-set harness, no metrics, no persisted scored reports; interactive use only.
- **On-device / phone fidelity**: the T4 is not a phone; latency, battery, and the vendor's quantization-aware artifact are not represented.
- **Multi-user serving, auth, or high-concurrency throughput**: single operator only; no production-grade request batching.
- **Fine-tuning or training**: frozen inference only.
- **Provisioning the VM itself or installing GPU drivers**: assumed present or a documented prerequisite, not built here.

## Dependencies

- The existing GCloud VM with an NVIDIA T4 (16 GB VRAM) and working GPU drivers / container passthrough.
- Network access to the model registry to pull both Gemma models, including license acceptance for any gated model.
- The Gemma 4 E4B model: HF `google/gemma-4-E4B-it`, preferring the vendor QAT build `google/gemma-4-E4B-it-qat-q4_0-gguf` (ungated, apache-2.0); no fallback model. Pulled fresh into Ollama's GGUF store — the spike 001 safetensors cache is not reusable here.
- A durable storage volume on the VM for persisting chat history and UI configuration (FR-010).
- A local multi-model serving runtime capable of holding two models resident on one GPU and a front end capable of fan-out (single prompt → multiple model columns).
- An isolation boundary on the shared VM so this environment does not disturb the LoRA and eval tracks.
