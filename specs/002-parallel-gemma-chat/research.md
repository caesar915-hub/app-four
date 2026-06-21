# Phase 0 Research: Parallel Two-Model Gemma Chat

## R1 — How to host two different models concurrently on one T4

**Decision**: Ollama with `OLLAMA_MAX_LOADED_MODELS=2` and `OLLAMA_KEEP_ALIVE=-1`.
**Rationale**: Ollama keeps multiple models resident if each fits in VRAM; the default cap is `3 × #GPUs`, so two is well within it. `KEEP_ALIVE=-1` stops idle unloading so no per-turn reload (FR-002). Both target models are tiny relative to 16 GB, so co-residency needs no quantization gymnastics. ([Ollama FAQ](https://docs.ollama.com/faq))
**Alternatives considered**:
- *vLLM* — superior for high concurrent throughput, but needs one server per model and loses Ollama's auto memory management; overkill for two sub-3B models, single operator ([SitePoint](https://www.sitepoint.com/multiple-local-models-memory-management/)).
- *Two llama.cpp servers behind a custom UI* — more wiring, no benefit over Ollama here.

**Caveat carried forward**: on one T4 the two generations time-slice the compute units; "parallel" = both loaded + answering in one turn, not 2× throughput. Acceptable for qualitative use.

## R2 — Multi-model side-by-side UI

**Decision**: Open WebUI multi-model chat.
**Rationale**: One prompt is sent to all selected models simultaneously and rendered in parallel columns; native Ollama auto-detection; nothing custom to build (FR-001, FR-003). ([Multi-Model Chats](https://docs.openwebui.com/features/chat-conversations/chat-features/multi-model-chats/))
**Alternatives considered**: LibreChat, custom Gradio fan-out — both require more setup for the same single-prompt-to-two-columns behavior.

## R3 — Getting the Gemma 4 E4B QAT GGUF into Ollama

**Decision**: Pull directly from Hugging Face — `ollama pull hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf` (optionally `:<QUANT>` to pin a file). Fallback: download the `.gguf`, write a one-line `FROM ./model.gguf` Modelfile, `ollama create`.
**Rationale**: Ollama runs any public GGUF on HF with a single command, no Modelfile needed; the vendor QAT build reflects the real on-device quantization rather than a post-hoc proxy. The repo is confirmed: `google/gemma-4-E4B-it-qat-q4_0-gguf`, ~5.15 GB Q4_0, apache-2.0, **ungated**. ([repo](https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf), [HF↔Ollama](https://huggingface.co/docs/hub/en/ollama), [Ollama import](https://docs.ollama.com/import))
**Alternatives considered**:
- *`ollama pull gemma4:e4b…` from the Ollama library* — may exist, but the exact tag/quant is unverified; the HF QAT repo is the authoritative, vendor-quantized source.
- *unsloth/gemma-4-E4B-it-GGUF* — community GGUF, valid backup if the google repo lacks an Ollama-readable file.

**Operational check at standup**: confirm the HF pull resolves; if unreadable, use the Modelfile-import fallback. No fallback *model*.

## R6 — Reuse spike 001's cached weights, or pull fresh GGUF?

**Decision**: **Pull fresh GGUF into Ollama; do NOT reuse the spike 001 cache.**
**Rationale**: Spike 001 loads models with HuggingFace transformers + bitsandbytes NF4 ([summarize.py:96-98](../../spikes/flan-t5-summarizer/gemma3/summarize.py)), caching **safetensors** in `~/.cache/huggingface`. Ollama serves only **GGUF** from its own `~/.ollama/models` store and cannot populate it from the HF cache — different format, different store. The two are not interchangeable, so "the models are already on the VM" does not save a download for an Ollama-based chat UI. The fresh GGUF is also the *vendor QAT* artifact, which spike 001 explicitly notes it cannot run ("NF4 here is bitsandbytes, NOT Google's shipped QAT-q4_0 GGUF" — [models.py:10-11](../../spikes/flan-t5-summarizer/gemma3/models.py)), so the pull buys higher on-device fidelity, not redundancy.
**Alternatives considered**:
- *Reuse the safetensors via a transformers-backed OpenAI server (vLLM/TGI) behind Open WebUI* — would reuse the cache and match spike 001's exact quant path, but bitsandbytes-NF4-in-vLLM is fragile and the setup is heavier; consistency with spike 001's *scored* numbers is irrelevant for a *qualitative* chat tool. Rejected.
- *Convert the cached safetensors to GGUF locally (`llama.cpp convert`)* — possible, but slower and would reproduce the NF4-proxy quant rather than the vendor QAT. Rejected in favor of the direct QAT pull.
**Variant note**: switched target E2B → **E4B** to align with the variant spike 001 already exercised ([models.py:45](../../spikes/flan-t5-summarizer/gemma3/models.py), `google/gemma-4-E4B-it`).

## R4 — Two-layer access control

**Decision**: (a) GCloud VPC firewall rule admitting the UI port only from the operator's source IP range; (b) Open WebUI built-in authentication left on (`WEBUI_AUTH=true`), admin bootstrapped via `WEBUI_ADMIN_EMAIL`/`WEBUI_ADMIN_PASSWORD`, signup auto-disabled after first user.
**Rationale**: Satisfies FR-008's both-layers requirement. Firewall removes the model from internet reachability; UI login stops an allowlisted-but-unauthenticated client. Open WebUI auth is on by default and disables signup after the first admin, so no open registration. ([Hardening](https://docs.openwebui.com/getting-started/advanced-topics/hardening/), [Env config](https://docs.openwebui.com/reference/env-configuration/))
**Alternatives considered**: SSH-tunnel-only (rejected in clarification — wanted defense in depth); reverse proxy + OAuth (heavier than a single-operator spike needs).

## R5 — Persistence across restart

**Decision**: Docker named volumes — `ollama` (model blobs) and `open-webui` (`/app/backend/data`: chat history, accounts, config) — on the VM's persistent disk.
**Rationale**: Survives container/VM restart (FR-010, SC-006) with no manual re-creation; model blobs also persist so re-pull is avoided. Named volumes are the standard durable mount for both images.
**Alternatives considered**: bind mounts to a host path (equivalent; named volumes chosen for portability); ephemeral (rejected in clarification).

## Open items

None blocking. Single deferred operational verification: the HF QAT GGUF pull resolving on the VM (R3), guarded by the Modelfile-import fallback.
