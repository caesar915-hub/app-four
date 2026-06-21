# Phase 1 Data Model: Parallel Two-Model Gemma Chat

No application database. The "entities" are configuration objects that define the running system. Fields, sources, and validation below.

## Target model

A model exposed in the chat picker.

| Field | Type | Notes |
|-------|------|-------|
| key | string | Ollama model id as shown in the UI |
| source | enum {ollama-library, hf-gguf} | where the weights come from |
| precision | string | e.g. `Q4_K_M` (default), `qat-q4_0` (vendor QAT) |
| role | const "comparison-target" | always one of exactly two |

**Instances (exactly two, no fallback)**:
- `gemma3:1b` — source `ollama-library`, precision = library default.
- `hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf` — source `hf-gguf`, precision `qat-q4_0` (~5.15 GB, ungated).

**Validation**:
- Both MUST resolve at standup or standup fails fast (FR-005); a wrong/absent id is an error, not a silent skip.
- Combined resident footprint MUST fit in 16 GB VRAM (FR-002), verified via `ollama ps`.
- Precision asymmetry between the two is intentional and recorded (each in its best on-device-representative form).

## Model runtime

The Ollama service hosting both targets on the T4.

| Field | Type | Notes |
|-------|------|-------|
| max_loaded_models | int | MUST be ≥ 2 (`OLLAMA_MAX_LOADED_MODELS=2`) |
| keep_alive | duration | `-1` = never idle-unload |
| gpu | const T4-16GB | single device |
| memory_pressure_behavior | enum {queue, evict} | surfaced, never silent degradation (FR-009) |

**Validation**: both targets MUST be concurrently resident across a multi-turn session with no eviction-reload under normal idle timing (SC-002).

## Chat interface

The Open WebUI front end.

| Field | Type | Notes |
|-------|------|-------|
| fan_out | const true | one prompt → all selected models in one turn (FR-001) |
| streaming | const independent-per-column | slow model can't block fast (FR-003) |
| shared_context | const true | both models get the multi-turn history (FR-004) |
| auth_enabled | const true | `WEBUI_AUTH=true`; first user = admin; signup disabled after (FR-008b) |

**Validation**: a single submission MUST yield two distinct responses every time (SC-001); UI MUST reject unauthenticated use (SC-005).

## VM environment

The GCloud T4 host and its access boundary.

| Field | Type | Notes |
|-------|------|-------|
| firewall_allowlist | list<CIDR> | operator source IP(s) only; admits the UI port (FR-008a) |
| public_reachable | const false | not reachable from open internet (SC-005) |
| persistence | list<volume> | `ollama`, `open-webui` on persistent disk (FR-010) |
| isolation | const containerized | no shared venv/ports with LoRA/eval tracks (FR-006) |

**Validation**: non-allowlisted source IPs rejected; chat history present after restart (SC-006); other tracks' environments untouched.
