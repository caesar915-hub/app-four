# Contract: Compose Stack, Env, Model & Network Interface

The operational contract the implementation MUST satisfy. Concrete values live in `spikes/parallel-gemma-chat/` (created during implementation); this defines the required shape and is the acceptance reference.

## Service contract (Docker Compose)

Two services + two named volumes:

| Service | Image | Responsibility | GPU | Persists to |
|---------|-------|----------------|-----|-------------|
| `ollama` | `ollama/ollama:latest` | host both models on the T4 | yes (all) | volume `ollama` → `/root/.ollama` |
| `open-webui` | `ghcr.io/open-webui/open-webui:main` | multi-model chat UI + auth | no | volume `open-webui` → `/app/backend/data` |

Requirements:
- `ollama` MUST request the NVIDIA GPU (Compose `deploy.resources.reservations.devices`, driver `nvidia`).
- `open-webui` MUST point `OLLAMA_BASE_URL` at the `ollama` service and `depends_on` it.
- Only `open-webui`'s port is published to the host; `ollama`'s API is **not** published to the host network.

## Environment contract

| Variable | Service | Required | Purpose |
|----------|---------|----------|---------|
| `OLLAMA_MAX_LOADED_MODELS` | ollama | yes | `2` — co-residency (FR-002) |
| `OLLAMA_KEEP_ALIVE` | ollama | yes | `-1` — no idle unload |
| `OLLAMA_BASE_URL` | open-webui | yes | `http://ollama:11434` |
| `WEBUI_AUTH` | open-webui | yes | `true` (default) — UI login (FR-008b) |
| `WEBUI_ADMIN_EMAIL` | open-webui | recommended | bootstrap admin on first start |
| `WEBUI_ADMIN_PASSWORD` | open-webui | recommended | bootstrap admin password (from `.env`, never committed) |
| `WEBUI_SECRET_KEY` | open-webui | recommended | stable session signing across restarts |

Secrets MUST come from an uncommitted `.env`; the repo ships `.env.example` with placeholders only.

## Model contract

| UI label | Pull command | Source |
|----------|--------------|--------|
| Gemma 3 1B | `ollama pull gemma3:1b` | Ollama library |
| Gemma 4 E4B (QAT) | `ollama pull hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf` | HF GGUF |

- Both pulls MUST succeed before the UI is used; failure is fatal with an actionable message (FR-005).
- Fallback path if direct HF pull fails: download the `.gguf`, `FROM ./model.gguf` Modelfile, `ollama create gemma4-e2b-qat`. No fallback model.
- After pull, `ollama ps` MUST show both resident within 16 GB (FR-002).

## Network contract

| Rule | Value |
|------|-------|
| Exposed port | the published Open WebUI host port (e.g. `8080`/`3000`) |
| GCloud firewall `source-ranges` | operator IP/CIDR only (FR-008a) |
| Target | the VM (via network tag) |
| Default-deny | no `0.0.0.0/0` ingress to the UI port |

Acceptance: a request from a non-allowlisted IP is refused at the firewall; an allowlisted IP still hits the Open WebUI login (SC-005).

## Persistence contract

| Volume | Mount | Holds |
|--------|-------|-------|
| `ollama` | `/root/.ollama` | model blobs (avoids re-pull) |
| `open-webui` | `/app/backend/data` | chat history, accounts, config |

Both on the VM's persistent disk; MUST survive container/VM restart (FR-010, SC-006).
