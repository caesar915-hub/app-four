# Parallel Two-Model Gemma Chat

Side-by-side chat on the GCloud **T4 (16 GB)** VM: one prompt → **Gemma 3 1B** and **Gemma 4 E4B** answer in parallel. Ollama holds both models co-resident; Open WebUI is the multi-model front end. Enabling infra for [spec 001](../../specs/001-edge-gemma-summarization/spec.md); draws no model-quality verdict.

Spec: [specs/002-parallel-gemma-chat/](../../specs/002-parallel-gemma-chat/) (spec.md, plan.md, research.md, quickstart.md).

## Models

| UI model | Pull id | Quant | Source |
|----------|---------|-------|--------|
| Gemma 3 1B | `gemma3:1b` | library default | Ollama library |
| Gemma 4 E4B | `hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf` | vendor QAT q4_0 (~5.15 GB) | Hugging Face, apache-2.0, ungated |

These are **GGUF in Ollama's store** — a different artifact from spike 001's transformers/bitsandbytes-NF4 safetensors cache, which Ollama cannot reuse. The QAT GGUF is closer to the real on-device quantization (see [research R6](../../specs/002-parallel-gemma-chat/research.md)).

## Prerequisites (on the VM)

- NVIDIA **T4** with working drivers (`nvidia-smi` ok).
- Docker + Docker Compose + **NVIDIA Container Toolkit** (so the GPU reservation works).
- Your workstation's public IP for the firewall allowlist: `curl -s ifconfig.me`.

## Standup

```bash
cp .env.example .env
# edit .env: set WEBUI_SECRET_KEY (openssl rand -hex 32), admin email/password

docker compose up -d
./pull-models.sh          # pulls both models, warms them, prints `ollama ps` + GPU memory
```

Then browse to `http://<VM_IP>:8080`, create the first account (it becomes admin), click **+** in the model selector, add both models, and send one prompt.

### Firewall — restrict the UI to your IP (required)

The compose file publishes port 8080 on the VM; the GCloud firewall is the network gate (Open WebUI's login is the second layer).

```bash
# tag the VM once:
gcloud compute instances add-tags <VM_NAME> --zone <ZONE> --tags gemma-chat

gcloud compute firewall-rules create gemma-chat-allow \
  --direction=INGRESS --action=ALLOW --rules=tcp:8080 \
  --source-ranges=<YOUR_IP>/32 --target-tags=gemma-chat
```

Confirm no broader rule opens 8080 to `0.0.0.0/0`:
```bash
gcloud compute firewall-rules list --filter="allowed.ports=8080"
```

## Verify (acceptance, maps to spec)

- One prompt → two response columns, no re-type — **SC-001 / FR-001**.
- `docker compose exec ollama ollama ps` shows both models, combined < 16 GB — **SC-002 / FR-002**.
- Hit `:8080` from a non-allowlisted IP → refused; from an allowlisted IP logged-out → login wall — **SC-005 / FR-008**.
- `docker compose restart`, reopen UI → history + account still there — **SC-006 / FR-010**.

## Teardown

```bash
docker compose down                                   # stop services, free VRAM
gcloud compute firewall-rules delete gemma-chat-allow
# volumes are kept (history preserved). Full reset:
# docker compose down -v
```

## Notes

- **Precision asymmetry is intentional**: Gemma 3 1B runs at Ollama's default quant, Gemma 4 E4B at vendor QAT-q4. Each is in its best on-device-representative form — this is not a controlled precision comparison.
- **One GPU = time-sliced compute**: both models are resident and answer in the same turn, but the T4's compute is shared between them. "Parallel" here means concurrent, not 2× throughput. Fine for these sizes.
- **Isolation**: the whole stack is containerized, so it does not touch the LoRA/eval Python venvs on the VM (FR-006).
