#!/usr/bin/env python3
"""
FLAN-T5 summarization playground — test quality on your laptop (PyTorch, no Core ML)
before committing to the Swift/Core ML path.

QUICK START
    pip install torch transformers sentencepiece     # (or use ../requirements.txt)
    python run.py                                    # run every input in inputs.json

COMMON USES
    python run.py --interactive                      # type a transcript, get a summary
    python run.py --input "I felt wired all night"   # one-off transcript
    python run.py --all-prompts                       # compare faithful/balanced/fluent per input
    python run.py --model google/flan-t5-large        # swap model size
    python run.py --compare-models                    # base vs large side-by-side
    python run.py --compare-models flan,gemma --evalset   # flan vs gated T5Gemma (needs .venv-gemma + HF token)
    python run.py --prompt fluent                     # pick one prompt template
    python run.py --evalset                           # use ../evalset.json transcripts
    python run.py --num-beams 4 --no-repeat-ngram 3   # explore beam search quality
    python run.py --save                              # write results to results/<stamp>.md

EVERYTHING is overridable: edit config.py for persistent defaults, or pass flags
for one-off experiments. Add inputs to inputs.json. Add/edit prompts in prompts.py.
"""

import argparse
import json
import sys
import time
from dataclasses import asdict, replace
from pathlib import Path

import config as cfg_mod
import prompts as prompt_mod

# Comparison-model aliases for --compare-models (e.g. `--compare-models flan,gemma`).
# T5Gemma are GATED Gemma encoder-decoders (~0.6B) — need HF license + token AND
# transformers>=4.53, so run them from .venv-gemma, not the Core ML pipeline venv.
T5GEMMA_MODELS = [
    "google/t5gemma-b-b-prefixlm-it",
    "google/t5gemma-b-b-ul2-it",
]
_MODEL_ALIASES = {
    "gemma": T5GEMMA_MODELS,
    "flan":  ["google/flan-t5-base", "google/flan-t5-large"],
}


def _expand_model_aliases(spec: str) -> list[str]:
    out: list[str] = []
    for tok in (s.strip() for s in spec.split(",")):
        if tok:
            out.extend(_MODEL_ALIASES.get(tok, [tok]))
    return out


def is_t5gemma(model_name: str) -> bool:
    return "t5gemma" in model_name.lower()


# Heavy imports are deferred so --help works even when dependencies are not installed.
def _torch():
    import torch
    return torch


def _load_hf(model_name: str, dtype: str, device: str, dtypes: dict):
    from transformers import AutoTokenizer
    tok = AutoTokenizer.from_pretrained(model_name)
    if is_t5gemma(model_name):
        # Gemma encoder-decoder: generic seq2seq class + Gemma tokenizer (~256k vocab),
        # NOT T5ForConditionalGeneration.
        from transformers import AutoModelForSeq2SeqLM
        model = AutoModelForSeq2SeqLM.from_pretrained(
            model_name, torch_dtype=dtypes[dtype]
        ).to(device)
    else:
        from transformers import T5ForConditionalGeneration
        model = T5ForConditionalGeneration.from_pretrained(
            model_name, torch_dtype=dtypes[dtype]
        ).to(device)
    model.eval()
    return tok, model

HERE = Path(__file__).parent
INPUTS_PATH = HERE / "inputs.json"
EVALSET_PATH = HERE.parent.parent / "evalset.json"
RESULTS_DIR = HERE / "results"

_DTYPES = None  # set lazily after torch is imported


def _get_dtypes():
    global _DTYPES
    if _DTYPES is None:
        torch = _torch()
        _DTYPES = {"float32": torch.float32, "bfloat16": torch.bfloat16}
    return _DTYPES


# ── Model loading ────────────────────────────────────────────────────────
def pick_device(pref: str) -> str:
    if pref != "auto":
        return pref
    torch = _torch()
    # MPS is intentionally avoided for T5 on this torch/transformers combo:
    # torch.isin (used in stopping_criteria) is not implemented on MPS and
    # raises NotImplementedError during generate(). Use CPU unless cuda wins.
    if torch.cuda.is_available():
        return "cuda"
    return "cpu"


_CACHE = {}

def load(model_name: str, dtype: str, device: str):
    key = (model_name, dtype, device)
    if key in _CACHE:
        return _CACHE[key]
    print(f"Loading {model_name} ({dtype}) on {device}...", file=sys.stderr)
    tok, model = _load_hf(model_name, dtype, device, _get_dtypes())
    print("Ready.\n", file=sys.stderr)
    _CACHE[key] = (tok, model)
    return tok, model


# ── Summarization ──────────────────────────────────────────────────────────
def summarize(cfg: cfg_mod.Config, prompt_name: str, transcript: str):
    device = pick_device(cfg.device)
    tok, model = load(cfg.model_name, cfg.dtype, device)

    prompt = prompt_mod.build(prompt_name, transcript)
    if is_t5gemma(cfg.model_name):
        # -it variants are chat-tuned: wrap the instruction as a user turn so the
        # model sees its training format (Gemma chat template), not a bare string.
        # Comparable to the flan runs in TASK, not byte-identical input.
        messages = [{"role": "user", "content": prompt}]
        inputs = tok.apply_chat_template(
            messages, return_tensors="pt", return_dict=True,
            add_generation_prompt=True,
        ).to(device)
    else:
        inputs = tok(
            prompt,
            return_tensors="pt",
            max_length=cfg.max_input_tokens,
            truncation=True,
        ).to(device)

    g = cfg.gen
    gen_kwargs = dict(
        max_new_tokens=g.max_new_tokens,
        num_beams=g.num_beams,
        do_sample=g.do_sample,
        repetition_penalty=g.repetition_penalty,
        length_penalty=g.length_penalty,
    )
    if g.no_repeat_ngram_size > 0:
        gen_kwargs["no_repeat_ngram_size"] = g.no_repeat_ngram_size
    if g.do_sample:
        gen_kwargs.update(temperature=g.temperature, top_p=g.top_p, top_k=g.top_k)

    with _torch().no_grad():
        t0 = time.perf_counter()
        out = model.generate(**inputs, **gen_kwargs)
        latency = time.perf_counter() - t0

    text = tok.decode(out[0], skip_special_tokens=True)
    n_in = int(inputs["input_ids"].shape[1])
    n_out = int(out.shape[1])
    return text.strip(), latency, n_in, n_out


# ── Input loading ────────────────────────────────────────────────────────
def load_inputs(args) -> list[dict]:
    if args.input:
        return [{"id": "cli", "transcript": args.input}]
    if args.evalset:
        with open(EVALSET_PATH) as f:
            return [{"id": c["id"], "transcript": c["transcript"]} for c in json.load(f)]
    path = Path(args.input_file) if args.input_file else INPUTS_PATH
    with open(path) as f:
        return json.load(f)


# ── Rendering ──────────────────────────────────────────────────────────────
def render_case(cfg, prompt_names, model_names, case, sink):
    cid = case.get("id", "?")
    note = case.get("note", "")
    sink(f"\n── {cid} {'· ' + note if note else ''} ──────────────────────")
    sink(f"INPUT: {case['transcript']}")
    for mname in model_names:
        cfg_for_model = replace(cfg, model_name=mname)
        for pname in prompt_names:
            text, latency, n_in, n_out = summarize(cfg_for_model, pname, case["transcript"])
            tag_parts = []
            if len(model_names) > 1:
                tag_parts.append(mname.split("/")[-1])
            if len(prompt_names) > 1:
                tag_parts.append(pname)
            tag = f"[{' | '.join(tag_parts)}] " if tag_parts else ""
            sink(f"\n{tag}OUTPUT ({latency:.2f}s · in {n_in}tok · out {n_out}tok):")
            sink(text)


def main():
    p = argparse.ArgumentParser(description="FLAN-T5 summarization playground")
    # input selection
    p.add_argument("--input", help="single transcript string (one-off)")
    p.add_argument("--input-file", help="path to a JSON file of {id, transcript}")
    p.add_argument("--evalset", action="store_true", help="use ../evalset.json transcripts")
    p.add_argument("--interactive", action="store_true", help="REPL: type a transcript")
    # model / prompt
    p.add_argument("--model", help="HF model id (overrides config)")
    p.add_argument("--dtype", choices=["float32", "bfloat16"], help="float32 (safe) | bfloat16 (fast)")
    p.add_argument("--device", help="auto | cpu | mps | cuda")
    p.add_argument("--prompt", help="prompt template name (see prompts.py)")
    p.add_argument("--all-prompts", action="store_true", help="run every prompt template")
    p.add_argument("--compare-models", nargs="?", const="google/flan-t5-base,google/flan-t5-large",
                   help="compare models side-by-side per input (default: base,large; override with comma-separated list)")
    # generation
    p.add_argument("--max-new-tokens", type=int)
    p.add_argument("--num-beams", type=int)
    p.add_argument("--sample", action="store_true", help="enable sampling (temperature/top_p)")
    p.add_argument("--temperature", type=float)
    p.add_argument("--top-p", type=float)
    p.add_argument("--repetition-penalty", type=float)
    p.add_argument("--no-repeat-ngram", type=int, dest="no_repeat_ngram")
    # output
    p.add_argument("--save", action="store_true", help="write results to results/<timestamp>.md")
    args = p.parse_args()

    # Build config: defaults ← CLI overrides
    cfg = replace(cfg_mod.DEFAULT)
    if args.model:  cfg = replace(cfg, model_name=args.model)
    if args.dtype:  cfg = replace(cfg, dtype=args.dtype)
    if args.device: cfg = replace(cfg, device=args.device)
    if args.prompt: cfg = replace(cfg, prompt=args.prompt)

    g = replace(cfg.gen)
    if args.max_new_tokens is not None: g = replace(g, max_new_tokens=args.max_new_tokens)
    if args.num_beams is not None:      g = replace(g, num_beams=args.num_beams)
    if args.sample:                     g = replace(g, do_sample=True)
    if args.temperature is not None:    g = replace(g, temperature=args.temperature)
    if args.top_p is not None:          g = replace(g, top_p=args.top_p)
    if args.repetition_penalty is not None: g = replace(g, repetition_penalty=args.repetition_penalty)
    if args.no_repeat_ngram is not None:    g = replace(g, no_repeat_ngram_size=args.no_repeat_ngram)
    cfg = replace(cfg, gen=g)

    prompt_names = list(prompt_mod.PROMPTS) if args.all_prompts else [cfg.prompt]

    model_names = [cfg.model_name]
    if args.compare_models:
        model_names = _expand_model_aliases(args.compare_models)

    # ── Interactive mode ────────────────────────────────────────────────
    if args.interactive:
        print(f"Interactive mode — models={model_names}, prompts={prompt_names}")
        print("Type a journal entry and press Enter (blank line or Ctrl-D to quit).\n")
        while True:
            try:
                line = input("entry> ").strip()
            except EOFError:
                break
            if not line:
                break
            render_case(cfg, prompt_names, model_names, {"id": "live", "transcript": line}, print)
            print()
        return

    # ── Batch mode ──────────────────────────────────────────────────────
    cases = load_inputs(args)
    lines: list[str] = []
    def sink(s):
        print(s)
        lines.append(s)

    sink(f"# FLAN-T5 playground run")
    sink(f"models={model_names} dtype={cfg.dtype} device={pick_device(cfg.device)}")
    sink(f"prompts={prompt_names}")
    sink(f"gen={asdict(cfg.gen)}")
    for case in cases:
        render_case(cfg, prompt_names, model_names, case, sink)

    if args.save:
        RESULTS_DIR.mkdir(exist_ok=True)
        # No Date.now() concerns here — plain Python; stamp from time.
        stamp = time.strftime("%Y%m%d-%H%M%S")
        out_path = RESULTS_DIR / f"{stamp}.md"
        out_path.write_text("\n".join(lines) + "\n")
        print(f"\nSaved → {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
