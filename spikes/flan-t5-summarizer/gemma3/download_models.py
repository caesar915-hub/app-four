#!/usr/bin/env python3
"""
Pre-stage Gemma weights so a long eval fails fast on gating, not mid-run.

    HF_TOKEN=hf_xxx python download_models.py            # all three
    HF_TOKEN=hf_xxx python download_models.py g3-1b      # one

gemma-3-270m-it and gemma-3-1b-it are gated(manual): accept the license on each
model page with the account behind HF_TOKEN BEFORE first download, or you get 401.
"""

import os
import sys

from models import REGISTRY, GemmaSpec


def prefetch(keys: list[str] | None = None) -> None:
    from huggingface_hub import snapshot_download
    from huggingface_hub.utils import GatedRepoError, HfHubHTTPError

    token = os.environ.get("HF_TOKEN")
    specs = [REGISTRY[k] for k in (keys or list(REGISTRY))]

    for spec in specs:
        print(f"→ {spec.hf_id} ({spec.quant}, gated={spec.gated}) ...", file=sys.stderr)
        try:
            snapshot_download(spec.hf_id, token=token)
            print(f"  cached {spec.hf_id}", file=sys.stderr)
        except (GatedRepoError, HfHubHTTPError) as e:
            url = f"https://huggingface.co/{spec.hf_id}"
            print(f"\nFAILED on {spec.hf_id}: {e}\n"
                  f"If gated, accept the license at {url} with the HF_TOKEN account, "
                  f"then re-run.\n", file=sys.stderr)
            raise SystemExit(1)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a in REGISTRY]
    bad = [a for a in sys.argv[1:] if a not in REGISTRY]
    if bad:
        raise SystemExit(f"unknown keys {bad}; valid: {list(REGISTRY)}")
    prefetch(args or None)
    print("All requested models cached.", file=sys.stderr)
