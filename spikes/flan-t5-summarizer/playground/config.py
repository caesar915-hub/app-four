"""
Playground configuration — edit these defaults, or override any of them
on the command line (see `python run.py --help`).

Why a dataclass and not YAML/JSON: zero extra dependencies, inline comments,
and CLI flags in run.py override every field so quick experiments don't need
file edits.
"""
from dataclasses import dataclass, field


@dataclass
class GenConfig:
    # Generation knobs (HuggingFace `model.generate`).
    # DEFAULTS MATCH THE CORE ML PATH: greedy, no sampling — so what you see
    # here is what the on-device decoder will produce. Turn on beams/sampling
    # only to *explore* quality ceilings; the shipped path is greedy.
    max_new_tokens:      int   = 120
    num_beams:           int   = 1      # 1 = greedy (matches Core ML). >1 = beam search.
    do_sample:           bool  = False  # True enables temperature/top_p
    temperature:         float = 1.0
    top_p:               float = 1.0
    top_k:               int   = 50
    repetition_penalty:  float = 1.0    # >1.0 discourages repeats (try 1.2–1.4 if it loops)
    no_repeat_ngram_size: int  = 0      # e.g. 3 forbids repeating any 3-gram
    length_penalty:      float = 1.0    # <1 favors shorter (beam search only)


@dataclass
class Config:
    # ── Model ────────────────────────────────────────────────────────────
    # Swap freely: google/flan-t5-small | -base | -large | -xl
    model_name: str = "google/flan-t5-base"

    # float32 is REQUIRED for trustworthy quality — T5 is unstable in float16
    # (known nan-logit issue). Options: "float32" | "bfloat16".
    # bfloat16 is safe on Apple Silicon (MPS) and ~2x faster than float32.
    dtype: str = "float32"

    # "auto" picks cuda → cpu. MPS is deliberately skipped for T5 on this
    # torch/transformers combo: torch.isin (used in generate stopping criteria)
    # is not implemented on MPS and crashes. Override to "cpu" if needed.
    device: str = "auto"

    # ── Prompt ───────────────────────────────────────────────────────────
    # Name of a template defined in prompts.py. Try "faithful" | "balanced" | "fluent".
    prompt: str = "faithful"

    # Truncate the tokenized prompt to this many tokens (encoder input length).
    # The Core ML spike fixes this at 128 — keep them aligned for representativeness.
    max_input_tokens: int = 512

    # ── Generation ───────────────────────────────────────────────────────
    gen: GenConfig = field(default_factory=GenConfig)


DEFAULT = Config()
