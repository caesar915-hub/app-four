# Quickstart: Parallel Two-Model Gemma Chat

End-to-end standup, acceptance checks, and teardown. Run on the GCloud T4 VM. Implementation files live in `spikes/parallel-gemma-chat/`.

## Prerequisites

- GCloud VM with NVIDIA **T4 (16 GB)**, working drivers (`nvidia-smi` succeeds).
- Docker + Docker Compose + **NVIDIA Container Toolkit** installed (so `--gpus all` works). *(Provisioning these is out of scope — see spec.)*
- Your current public IP (for the firewall allowlist): `curl -s ifconfig.me`.
- A Hugging Face account if the Gemma 4 repo requires license acceptance.

## Standup

1. **Configure secrets**
   - Copy `.env.example` → `.env`; set `WEBUI_ADMIN_EMAIL`, `WEBUI_ADMIN_PASSWORD`, `WEBUI_SECRET_KEY`, and your allowlisted IP.

2. **Firewall (FR-008a)** — restrict the UI port to your IP:
   ```
   gcloud compute firewall-rules create gemma-chat-allow \
     --direction=INGRESS --action=ALLOW --rules=tcp:8080 \
     --source-ranges=<YOUR_IP>/32 --target-tags=gemma-chat
   ```
   Ensure the VM carries the `gemma-chat` network tag and no broader rule opens `8080` to `0.0.0.0/0`.

3. **Bring up the stack**
   ```
   docker compose up -d
   ```

4. **Pull both models (FR-005)**
   ```
   docker compose exec ollama ollama pull gemma3:1b
   docker compose exec ollama ollama pull hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf
   ```
   If the second pull fails (gated/no Ollama-readable GGUF): download the `.gguf`, write `FROM ./model.gguf`, `ollama create gemma4-e2b-qat`. Do **not** substitute a different model.

5. **Verify co-residency (FR-002, SC-002)**
   ```
   docker compose exec ollama ollama ps
   ```
   Expected: both models listed, combined size < 16 GB.

## Acceptance checks (map to spec)

| Check | How | Pass condition |
|-------|-----|----------------|
| SC-001 / FR-001 | In the UI, add both models (the **+** in the model selector), send one prompt | two distinct responses in one turn, no re-type |
| FR-003 | Send a prompt; watch columns | each column streams independently; slow model doesn't block the other |
| FR-004 | Send a follow-up | both models answer with shared context |
| SC-002 / FR-002 | `ollama ps` after several alternating turns | both still resident, no reload |
| SC-005 / FR-008 | Hit the UI from a non-allowlisted IP, then allowlisted-but-logged-out | refused at firewall; then blocked by login |
| FR-009 | (Optional) load a long context near budget | memory pressure visible (queue/evict), not silent failure |
| SC-006 / FR-010 | `docker compose restart` (or reboot VM), reopen UI | prior chat history + account still present |

## Teardown (SC-003)

```
docker compose down                 # stop services, release VRAM
gcloud compute firewall-rules delete gemma-chat-allow
# keep volumes to preserve history; to fully reset:
# docker compose down -v
```
`nvidia-smi` should show the T4 memory released after `down`.

## Notes

- Precision asymmetry (Gemma 3 1B default quant vs Gemma 4 E4B QAT-q4) is intentional; read this as "each model in its best on-device-representative form", not a controlled precision comparison.
- This tool produces qualitative side-by-side reads only. Scored evaluation stays in [spec 001](../001-edge-gemma-summarization/spec.md).
