# Implementation Plan: Parallel Two-Model Gemma Chat

**Branch**: `spike/gemma-addrec-structured-prompt` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from [spec.md](./spec.md)

## Summary

Stand up a single-operator, side-by-side chat on the existing GCloud **T4 (16 GB)** VM that sends one prompt to **Gemma 3 1B** and **Gemma 4 E4B** at once and renders both answers in parallel. Approach: **Ollama** holds both models co-resident on the one GPU; **Open WebUI** provides the multi-model chat front end. Access is double-gated — a **GCloud VPC firewall source-IP allowlist** plus **Open WebUI's built-in login**. Chat history and config persist on **Docker named volumes** on the VM's persistent disk. This is enabling infrastructure for the edge-Gemma summarization arm ([spec 001](../001-edge-gemma-summarization/spec.md)); it draws no model-quality verdict.

## Technical Context

**Runtime / serving**: Ollama (latest), GPU via NVIDIA Container Toolkit. Co-residency through `OLLAMA_MAX_LOADED_MODELS=2` and `OLLAMA_KEEP_ALIVE=-1` (no idle unload). Source: [Ollama FAQ](https://docs.ollama.com/faq).
**Front end**: Open WebUI (`ghcr.io/open-webui/open-webui:main`), native Ollama integration, multi-model chat. Source: [Multi-Model Chats](https://docs.openwebui.com/features/chat-conversations/chat-features/multi-model-chats/).
**Models**:
- Model A — `gemma3:1b` from the Ollama library.
- Model B — Gemma 4 E4B, vendor QAT 4-bit (~5.15 GB, apache-2.0, ungated), pulled straight from HF: `hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf`. Source: [HF↔Ollama GGUF](https://huggingface.co/docs/hub/en/ollama). **Not** reused from spike 001's transformers/NF4 cache — different format and store (see research R6).
**Orchestration**: Docker Compose (two services + two named volumes). No application source code.
**Auth**: Open WebUI built-in (`WEBUI_AUTH=true` default; first user = admin; signup auto-disables). Source: [Hardening](https://docs.openwebui.com/getting-started/advanced-topics/hardening/).
**Network**: GCloud VPC firewall rule admitting the UI port only from the operator's source IP range.
**Persistence**: Docker named volumes `ollama` (model blobs) and `open-webui` (chat history + config) on the VM's persistent disk.
**Target platform**: single GCloud VM, NVIDIA T4 16 GB, Linux + Docker.
**Scale**: one operator, no concurrency requirement.
**Performance**: not a target (qualitative tool); only constraint is co-residency without per-turn reload.
**Repo placement**: `spikes/parallel-gemma-chat/` (stays within the "ML spikes only" scope as enabling infra for spike 001).

**NEEDS CLARIFICATION**: none. One operational verification deferred to standup: confirm `hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf` resolves and the repo exposes an Ollama-readable GGUF; fall back to the Modelfile-import path (`FROM ./*.gguf`) if direct pull fails — no fallback *model*.

## Constitution Check

No `.specify/memory/constitution.md` exists; checked against project [CLAUDE.md](../../CLAUDE.md) principles instead:

| Principle | Status | Note |
|-----------|--------|------|
| ML spikes only; no iOS/app code | PASS | Pure infra under `spikes/`; enables spike 001. No Swift/SwiftUI/Xcode. |
| Python for orchestration | PASS (justified deviation) | Orchestration is Docker Compose + shell, not Python — appropriate for a serving stack; no data-gen/eval logic added here. |
| Correctness over speed; no silent corner-cutting | PASS | Memory pressure surfaced, not hidden (FR-009); tag verified fail-fast (FR-005). |
| No dead code / backwards-compat shims | PASS | Single compose file + standup doc; nothing speculative. |
| Define hypothesis/dataset/metric/conclusion per spike | N/A (justified) | This is tooling, not a hypothesis-bearing spike; explicitly scoped as enabler, verdict stays in spec 001. |

No unjustified violations. Gate: **PASS**.

## Project Structure

### Documentation (this feature)

```
specs/002-parallel-gemma-chat/
├── spec.md
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1 — standup/teardown validation
├── contracts/
│   └── compose-and-env.md   # service + env + model + network contract
└── checklists/
    └── requirements.md
```

### Deliverable (created during implementation, not by /speckit-plan)

```
spikes/parallel-gemma-chat/
├── docker-compose.yml   # ollama + open-webui services, two named volumes
├── .env.example         # admin creds, allowlisted IP, model ids (no secrets committed)
├── pull-models.sh       # pulls gemma3:1b and the HF QAT GGUF; verifies co-residency
└── README.md            # standup, firewall rule, teardown; decision log
```

**Structure decision**: A single new `spikes/parallel-gemma-chat/` directory holds the whole stack. The serving runtime is containerized, so it is isolated from the LoRA/eval Python environments (FR-006) by construction — no shared venv, no shared ports beyond what the firewall admits.

## Complexity Tracking

No constitution violations requiring justification. The one deliberate asymmetry (Gemma 3 1B default quant vs Gemma 4 E4B QAT-q4) is documented in the spec as intentional (each model in its best on-device-representative form) and is a comparison caveat, not a complexity cost.

## Phase 0 — Research

See [research.md](./research.md). All decisions resolved: Ollama for co-residency, Open WebUI for fan-out UI, direct HF-GGUF pull for the QAT model, built-in auth + VPC firewall for the two access layers, named volumes for persistence.

## Phase 1 — Design & Contracts

- [data-model.md](./data-model.md) — the four spec entities (Target model, Model runtime, Chat interface, VM environment) as configuration objects with fields and validation.
- [contracts/compose-and-env.md](./contracts/compose-and-env.md) — the operational contract: compose services, required env vars, model identifiers, exposed port, firewall rule shape, volume mounts.
- [quickstart.md](./quickstart.md) — end-to-end standup, the FR-by-FR acceptance checks, and teardown.

**Agent context update**: skipped — project `CLAUDE.md` contains no `<!-- SPECKIT START/END -->` markers, and it is a checked-in strict instruction file; not modifying it automatically. Add markers manually if agent-context linkage is wanted.

## Post-Design Constitution Re-check

No new violations introduced by the design. Containerized isolation strengthens the "don't disturb other tracks" guarantee. Gate: **PASS**.
