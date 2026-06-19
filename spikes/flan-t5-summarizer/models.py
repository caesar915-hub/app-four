#!/usr/bin/env python3
"""
Model registry for the T5 summarizer pipeline.

Every stage script (01–04) takes `--model <key>` and looks the spec up here,
so adding a model is a one-line entry, not a fork of four scripts.

Specs grounded in each model's HF config.json (verified 2026-06-18):
  flan-small    : t5 arch, d_model 512,  8 layers, tie_word_embeddings=False  (instruction-tuned)
  flan-base     : t5 arch, d_model 768, 12 layers, tie_word_embeddings=False  (instruction-tuned)
  flan-large    : t5 arch, d_model 1024,24 layers, tie_word_embeddings=False  (instruction-tuned)
  medical-umesh : t5 arch, d_model 512,  6 layers, tie unset→True  (plain t5, summarize: prefix)
  medical-falcon: t5 arch, d_model 512,  6 layers, tie unset→True  (plain t5, summarize: prefix)
                  NOTE: its card claims "T5 Large" but config.json is t5-small dims — trust config.

d_model is NOT stored here — 02_convert.py reads it from the live model.config,
so the Core ML shapes can never drift from the weights.

PROMPT STRATEGY (see the prompt-design note below build_prompt):
  flan-*  → "instruction": instruction-tuned models follow a natural-language ask.
  medical → "summarize" : plain t5 was fine-tuned with the T5 "summarize: " task
            prefix and is NOT instruction-following — an instruction prompt is
            out-of-distribution for it. Different training → different prompt.
"""

# Canonical instruction prompt for flan models. This is the user's evolved
# "faithful-v2" (see playground/prompts.py): "up to 3" stops padding; the
# meta-language ban stops "the journal entry is about..." on neutral inputs.
# playground/prompts.py is the place to explore variants in pure PyTorch;
# the pipeline pins ONE prompt per model so conversions/benchmarks are reproducible.
INSTRUCTION_TEMPLATE = (
    "Summarize the following journal entry as up to 3 short bullet points.\n"
    "Use the person's own words and key phrases. Do not add anything that is "
    "not in the entry. If a detail is not mentioned, leave it out. "
    "Do not use phrases like 'the journal entry is about' or 'the narrator'. "
    "If the entry is very short, one bullet is fine.\n"
    'Start each bullet with "- ".\n\n'
    "Journal entry:\n{transcript}\n\nBullet points:"
)

MODELS = {
    "flan-small": {
        "hf": "google/flan-t5-small", "prefix": "FlanT5Small",
        "encoder_len": 128, "max_new_tokens": 80, "prompt": "instruction",
    },
    "flan-base": {
        "hf": "google/flan-t5-base", "prefix": "FlanT5Base",
        "encoder_len": 128, "max_new_tokens": 80, "prompt": "instruction",
    },
    "flan-large": {
        "hf": "google/flan-t5-large", "prefix": "FlanT5Large",
        "encoder_len": 128, "max_new_tokens": 80, "prompt": "instruction",
    },
    "medical-umesh": {
        "hf": "umeshramya/t5_small_medical_512", "prefix": "T5MedicalUmesh",
        "encoder_len": 512, "max_new_tokens": 150, "prompt": "summarize",
    },
    "medical-falcon": {
        "hf": "Falconsai/medical_summarization", "prefix": "T5MedicalFalcon",
        "encoder_len": 512, "max_new_tokens": 150, "prompt": "summarize",
    },
}

# T5 SentencePiece constants — identical across all five (vocab 32128, verified).
EOS_TOKEN_ID = 1
PAD_TOKEN_ID = 0
DECODER_START = 0


def add_model_arg(parser):
    parser.add_argument(
        "--model", choices=list(MODELS), default="flan-base",
        help="model key from the registry (default: flan-base)",
    )
    parser.add_argument(
        "--encoder-len", type=int, default=None,
        help="override the encoder input length for the selected model",
    )


def resolve(args):
    """Return a copy of the spec for args.model, applying --encoder-len if given."""
    spec = dict(MODELS[args.model])
    spec["key"] = args.model
    if getattr(args, "encoder_len", None):
        spec["encoder_len"] = args.encoder_len
    return spec


def build_prompt(style: str, transcript: str) -> str:
    """
    Map a model's prompt strategy to actual input text.

    Why two strategies and not one shared prompt:
      - flan models are instruction-tuned; they were trained to follow asks like
        "summarize as bullet points using the person's words". They CAN honor the
        format/voice constraints.
      - the medical models are plain t5 fine-tuned on clinical text with the
        "summarize: " task prefix. They were never trained on instructions, so an
        instruction prompt is out-of-distribution and the bullet/own-words
        constraints are not behaviors they have. They emit a free-form abstractive
        summary. Matching each model's training is what makes a comparison fair —
        you hold the evalset + rubric constant, not the literal prompt string.
    """
    t = transcript.strip()
    if style == "instruction":
        return INSTRUCTION_TEMPLATE.format(transcript=t)
    if style == "summarize":
        return f"summarize: {t}"
    raise ValueError(f"unknown prompt style: {style!r}")
