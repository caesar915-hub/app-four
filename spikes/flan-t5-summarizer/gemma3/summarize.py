#!/usr/bin/env python3
"""
Edge-Gemma summarization harness — decoder-only arm of the flan-t5 spike.

Tests whether tiny/edge DECODER-ONLY Gemma models can faithfully summarize ADHD
voice-note journal entries without fabricating meds/doses/times/sleep/mood.

Why this is a separate script (not playground/run.py): Gemma 3/4 are decoder-only,
so model.generate() returns prompt+completion. We MUST slice off the prompt tokens
(out[:, input_len:]) before decoding — the seq2seq path in run.py decodes the whole
output and would echo the prompt, making every metric meaningless.

It reuses the LOCKED-v3 row-level metrics from playground/eval.py (evaluate,
post_process, fmt_*) and the 'gemma-faithful' prompt from playground/prompts.py, so
the rule-based numbers are directly comparable to the flan-t5 runs. MiniCheck is a
fast-follow: playground/minicheck_score.py --inputs <set> --test-only <results.md>.

USAGE
    # local CPU smoke test (270m is f16, no bitsandbytes needed):
    python summarize.py --model g3-270m --device cpu --limit 2

    # full run on the T4 VM (one model per process — 16 GB VRAM):
    python summarize.py --model g3-1b --save
    python summarize.py --model g4-e4b --save --no-repeat-ngram 3 --repetition-penalty 1.2

Models: see models.py. NF4 here is bitsandbytes, NOT Google's shipped QAT-q4_0 GGUF.
"""

import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLAYGROUND = HERE.parent / "playground"
RESULTS_DIR = HERE / "results"
DEFAULT_INPUT = PLAYGROUND / "inputs-test30.json"

# Reuse the playground modules. eval.py/prompts.py have no package __init__; they
# bare-import each other assuming the playground dir is on sys.path. Replicate that
# from this sibling dir with an absolute insert so cwd doesn't matter.
sys.path.insert(0, str(PLAYGROUND))
import eval as eval_mod        # noqa: E402  metrics + post_process (NLI load is lazy)
import prompts as prompt_mod   # noqa: E402  build('gemma-faithful', transcript)

from models import REGISTRY, GemmaSpec  # noqa: E402  local sibling


# Heavy imports deferred so --help works without torch/transformers installed.
def _torch():
    import torch
    return torch


# ── Model loading (per quant / multimodal branch) ───────────────────────────
_CACHE = {}


def load_model(spec: GemmaSpec, device: str):
    """Return (kind, tok_or_proc, model). kind ∈ {'text','multimodal'}."""
    if spec.key in _CACHE:
        return _CACHE[spec.key]

    torch = _torch()
    print(f"Loading {spec.hf_id} ({spec.quant}) ...", file=sys.stderr)

    common = {}
    use_device_map = device != "cpu"
    if spec.quant == "nf4":
        if device == "cpu":
            raise SystemExit(
                f"{spec.key} is int4 (bitsandbytes NF4) and needs CUDA. "
                "Use a CUDA device, or smoke-test with --model g3-270m (f16) on CPU."
            )
        from transformers import BitsAndBytesConfig
        common["quantization_config"] = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16,   # T4 (Turing) has no bf16
            bnb_4bit_use_double_quant=True,
        )
    else:  # f16 — 270m is too small to quantize without wrecking it
        common["dtype"] = torch.float16 if device != "cpu" else torch.float32

    if use_device_map:
        # accelerate places the (possibly 4-bit) weights; do NOT call .to() after.
        common["device_map"] = "auto"

    if spec.multimodal:
        from transformers import AutoProcessor, AutoModelForImageTextToText
        proc = AutoProcessor.from_pretrained(spec.hf_id)
        model = AutoModelForImageTextToText.from_pretrained(spec.hf_id, **common)
        kind, tok_or_proc = "multimodal", proc
    else:
        from transformers import AutoTokenizer, AutoModelForCausalLM
        tok = AutoTokenizer.from_pretrained(spec.hf_id)
        model = AutoModelForCausalLM.from_pretrained(spec.hf_id, **common)
        kind, tok_or_proc = "text", tok

    if not use_device_map:
        model = model.to(device)
    model.eval()
    print("Ready.\n", file=sys.stderr)
    _CACHE[spec.key] = (kind, tok_or_proc, model)
    return _CACHE[spec.key]


# ── Generation (the decode-with-slicing core) ───────────────────────────────
def generate_summary(kind, tok_or_proc, model, prompt: str, gen_kwargs: dict):
    torch = _torch()

    if kind == "multimodal":
        messages = [{"role": "user", "content": [{"type": "text", "text": prompt}]}]
    else:
        messages = [{"role": "user", "content": prompt}]

    inputs = tok_or_proc.apply_chat_template(
        messages,
        add_generation_prompt=True,
        tokenize=True,
        return_dict=True,
        return_tensors="pt",
    )
    inputs = {k: v.to(model.device) for k, v in inputs.items()}
    input_len = int(inputs["input_ids"].shape[1])

    with torch.no_grad():
        t0 = time.perf_counter()
        out = model.generate(**inputs, **gen_kwargs)
        latency = time.perf_counter() - t0

    # DECODER-ONLY: out = prompt + completion. Slice off the prompt before decoding.
    gen_ids = out[:, input_len:]
    decoder = tok_or_proc.tokenizer if kind == "multimodal" else tok_or_proc
    text = decoder.decode(gen_ids[0], skip_special_tokens=True)
    return text.strip(), latency, input_len, int(gen_ids.shape[1])


def build_gen_kwargs(max_new_tokens: int, no_repeat_ngram: int, repetition_penalty: float):
    # Greedy by default — mirrors playground/config.py GenConfig and the on-device path.
    g = dict(max_new_tokens=max_new_tokens, num_beams=1, do_sample=False)
    if no_repeat_ngram > 0:
        g["no_repeat_ngram_size"] = no_repeat_ngram
    if repetition_penalty != 1.0:
        g["repetition_penalty"] = repetition_penalty
    return g


# ── Aggregate (copied from eval.py main() 445-481 — NOT imported: eval.py is
#    LOCKED-v3 and shared with the flan path; copying keeps this arm decoupled) ─
def write_aggregate(sink, rows_data, spec: GemmaSpec, prompt_name: str):
    from collections import Counter
    n_rows = len(rows_data)
    clean = [r for r in rows_data if r["reason"] == "none"]
    n_fb = n_rows - len(clean)
    sink("")
    sink("## Aggregate")
    sink(f"- model: {spec.hf_id} ({spec.quant}) | prompt: {prompt_name}")
    sink(f"- entries: {n_rows}")
    sink(f"- **fallback rate: {n_fb}/{n_rows} = {n_fb/n_rows:.0%}** (model failed → heuristic took over)")
    sink(f"- usable (non-fallback) outputs: {len(clean)}/{n_rows} = {len(clean)/n_rows:.0%}")
    if clean:
        def cavg(key):
            return sum(r["m_raw"][key] for r in clean) / len(clean)
        med_h = sum(eval_mod._ratio(r["m_raw"]["med_recall"])[0] for r in clean)
        med_t = sum(eval_mod._ratio(r["m_raw"]["med_recall"])[1] for r in clean)
        fx_h = sum(eval_mod._ratio(r["m_raw"]["side_effect_recall"])[0] for r in clean)
        fx_t = sum(eval_mod._ratio(r["m_raw"]["side_effect_recall"])[1] for r in clean)
        n_band = sum(1 for r in clean if r["in_band"])
        n_sleep = sum(1 for r in clean if r["m_raw"]["sleep_hour_ok"])
        n_arc = sum(1 for r in clean if r["m_raw"]["arc_ok"])
        sink("- non-fallback quality (raw model output):")
        sink(f"  - coverage: {cavg('coverage'):.2f}")
        sink(f"  - hallucination: {cavg('hallucination'):.2f}")
        sink(f"  - compression: {cavg('compression'):.2f}x")
        sink(f"  - in band {eval_mod.COMPRESSION_BAND}: {n_band}/{len(clean)} = {n_band/len(clean):.0%}")
        sink(f"  - med recall: {med_h}/{med_t}" + (f" = {med_h/med_t:.0%}" if med_t else ""))
        sink(f"  - fx recall: {fx_h}/{fx_t}" + (f" = {fx_h/fx_t:.0%}" if fx_t else ""))
        sink(f"  - sleep ok: {n_sleep}/{len(clean)}")
        sink(f"  - arc ok: {n_arc}/{len(clean)}")
    sink("")
    sink("### Fallback breakdown (failure modes)")
    for reason, c in Counter(r["reason"] for r in rows_data).most_common():
        sink(f"- {reason}: {c} ({c/n_rows:.0%})")


# ── Input loading ───────────────────────────────────────────────────────────
def load_inputs(input_file: str, limit: int) -> list[dict]:
    path = Path(input_file)
    if not path.is_absolute() and not path.exists():
        alt = PLAYGROUND / input_file
        if alt.exists():
            path = alt
    with open(path) as f:
        cases = json.load(f)
    return cases[:limit] if limit else cases


def load_signals(signals_file: str) -> dict:
    """Load id->signals map.

    Accepts two formats:
    - JSONL  (addrec_*_summaries.jsonl): one {"id":..., "signals":[...]} per line
    - JSON   (addrec-signals.json):      plain {id: [signals]} dict
    """
    path = Path(signals_file)
    with open(path) as f:
        raw = f.read()
    first = raw.lstrip()[:1]
    if first == "{":
        return json.loads(raw)
    out = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        out[r["id"]] = r.get("signals", [])
    return out


def main():
    p = argparse.ArgumentParser(description="Edge-Gemma summarization harness")
    p.add_argument("--model", default="g3-1b", choices=list(REGISTRY),
                   help="registry key (one model per process; default g3-1b)")
    p.add_argument("--input-file", default=str(DEFAULT_INPUT),
                   help="JSON list of {id, transcript}; default inputs-test30.json")
    p.add_argument("--prompt", default="gemma-faithful", help="prompt template (see prompts.py)")
    p.add_argument("--signals-file", default="", dest="signals_file",
                   help="JSONL with id+signals fields (required for --prompt addrec-structured)")
    p.add_argument("--max-new-tokens", type=int, default=120)
    p.add_argument("--no-repeat-ngram", type=int, default=0, dest="no_repeat_ngram",
                   help="forbid repeating any n-gram (e.g. 3) — curbs decoder loops")
    p.add_argument("--repetition-penalty", type=float, default=1.0, dest="repetition_penalty",
                   help=">1.0 discourages repeats (e.g. 1.2)")
    p.add_argument("--limit", type=int, default=0, help="first N entries only (smoke test)")
    p.add_argument("--device", default="auto", help="auto | cpu | cuda")
    p.add_argument("--save", action="store_true", help="write results/<key>-<prompt>-<stamp>.md")
    args = p.parse_args()

    signals_map = {}
    if args.prompt == "addrec-structured":
        if not args.signals_file:
            raise SystemExit("--prompt addrec-structured requires --signals-file <addrec_500_summaries.jsonl>")
        signals_map = load_signals(args.signals_file)

    spec = REGISTRY[args.model]
    device = args.device
    if device == "auto":
        device = "cuda" if _torch().cuda.is_available() else "cpu"

    gen_kwargs = build_gen_kwargs(args.max_new_tokens, args.no_repeat_ngram, args.repetition_penalty)

    t_load0 = time.perf_counter()
    kind, tok_or_proc, model = load_model(spec, device)
    load_time = time.perf_counter() - t_load0

    cases = load_inputs(args.input_file, args.limit)

    lines = []
    def sink(s):
        print(s)
        lines.append(s)

    sink(f"# {spec.key} summarization eval")
    sink(f"model={spec.hf_id} | quant={spec.quant} | prompt={args.prompt} | "
         f"device={device} | input={Path(args.input_file).name} | run={time.strftime('%Y-%m-%d %H:%M:%S')}")
    sink("")
    sink("| id | input | tags | raw model output | post-processed | fallback | raw_quality | proc_quality |")
    sink("|---|---|---|---|---|---|---|---|")

    latencies = []
    rows_data = []
    for case in cases:
        cid = case.get("id", "?")
        src = case["transcript"]
        if args.prompt == "addrec-structured":
            prompt = prompt_mod.build_addrec(src, signals_map.get(cid, []))
        else:
            prompt = prompt_mod.build(args.prompt, src)
        raw, latency, n_in, n_out = generate_summary(kind, tok_or_proc, model, prompt, gen_kwargs)
        latencies.append(latency)
        proc, reason = eval_mod.post_process(src, raw)
        tags = eval_mod.extract_tags(src)
        m_raw = eval_mod.evaluate(src, raw)
        m_proc = eval_mod.evaluate(src, proc)
        in_band = eval_mod.COMPRESSION_BAND[0] <= m_raw["compression"] <= eval_mod.COMPRESSION_BAND[1]
        rows_data.append({"reason": reason, "m_raw": m_raw, "in_band": in_band})

        short_input = src[:90] + "…" if len(src) > 90 else src
        raw_cell = raw.replace("|", "\\|").replace("\n", "<br>")
        proc_cell = proc.replace("|", "\\|").replace("\n", "<br>")
        input_cell = short_input.replace("|", "\\|")
        sink(f"| {cid} | {input_cell} | {eval_mod.fmt_tags(tags)} | {raw_cell} | {proc_cell} | "
             f"{reason} | {eval_mod.fmt_metrics(m_raw)} | {eval_mod.fmt_metrics(m_proc)} |")

    total_gen = sum(latencies)
    n = len(latencies)
    sink("")
    sink("## Timing")
    sink(f"- model: {spec.hf_id}")
    sink(f"- entries: {n}")
    sink(f"- model load: {load_time:.1f}s")
    sink(f"- total generate: {total_gen:.1f}s")
    sink(f"- avg generate/entry: {total_gen/n:.2f}s" if n else "- avg generate/entry: n/a")
    sink(f"- max generate/entry: {max(latencies):.2f}s" if n else "- max generate/entry: n/a")

    write_aggregate(sink, rows_data, spec, args.prompt)

    print(f"[timing] {spec.hf_id}: load {load_time:.1f}s | gen total {total_gen:.1f}s | "
          f"avg {total_gen/max(n,1):.2f}s/entry", file=sys.stderr)

    if args.save:
        RESULTS_DIR.mkdir(exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        out = RESULTS_DIR / f"{spec.key}-{args.prompt}-{stamp}.md"
        out.write_text("\n".join(lines) + "\n")
        print(f"\nSaved → {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
