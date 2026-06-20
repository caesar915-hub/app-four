"""
Model registry for the edge-Gemma summarization arm.

Each entry pins the HF id, the load precision, and the chat-template flag.
Quantization is per-model on purpose:
  - 270m stays f16: at INT4 the quant error dominates a model this small.
  - 1b / 4b use bitsandbytes NF4: enough redundancy to absorb 4-bit, and this is
    the size we'd actually ship on edge.

NOTE: NF4 here is bitsandbytes, NOT Google's shipped QAT-q4_0 GGUF. It is the
closest int4 we can run inside transformers; the on-device artifact would differ.
gemma-3-270m and gemma-3-1b-it are gated (manual) — accept the license on each
model page with the HF account behind HF_TOKEN before first download.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class GemmaSpec:
    key: str           # short label used in CLI + result tags
    hf_id: str
    quant: str         # "f16" | "nf4"
    gated: bool
    multimodal: bool   # gemma-4 E4B is any-to-any; load via the conditional-gen class


REGISTRY = {
    "g3-270m": GemmaSpec(
        key="g3-270m",
        hf_id="google/gemma-3-270m-it",
        quant="f16",
        gated=True,
        multimodal=False,
    ),
    "g3-1b": GemmaSpec(
        key="g3-1b",
        hf_id="google/gemma-3-1b-it",
        quant="nf4",
        gated=True,
        multimodal=False,
    ),
    "g4-e4b": GemmaSpec(
        key="g4-e4b",
        hf_id="google/gemma-4-E4B-it",
        quant="nf4",
        gated=False,
        multimodal=True,
    ),
}

DEFAULT_KEYS = ["g3-270m", "g3-1b", "g4-e4b"]
