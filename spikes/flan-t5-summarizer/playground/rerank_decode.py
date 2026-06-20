#!/usr/bin/env python3
"""
Cheap-tier: beam search + MiniCheck-composite rerank.

Generate N beam candidates, score each by a composite of inference-available signals
(MiniCheck faithfulness + source content-word coverage proxy — NOT gold, which is
eval-only), return the top-1. Tests whether reranking improves faithfulness/coverage
over greedy top-1 without retraining.

Usage:
    python rerank_decode.py --model google/flan-t5-large --prompt faithful-large-fewshot-v2 \
        --input-file inputs-test30.json --num-beams 10 --out results/rerank-flan-large.json
"""
import argparse
import json
import statistics
from pathlib import Path

import prompts as prompt_mod
import run as run_mod
import eval as ev
import minicheck_score as mc


def coverage_proxy(source: str, summary: str) -> float:
    s, o = ev.tokens(source), ev.tokens(summary)
    return len(s & o) / len(s) if s else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--input-file", required=True)
    ap.add_argument("--num-beams", type=int, default=10)
    ap.add_argument("--w-faith", type=float, default=0.7)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    import torch
    cases = json.load(open(a.input_file))
    device = run_mod.pick_device("auto")
    tok, model = run_mod.load(a.model, "float32", device)

    rows = []
    for case in cases:
        src = case["transcript"]
        prompt = prompt_mod.build(a.prompt, src)
        inputs = tok(prompt, return_tensors="pt", max_length=512, truncation=True).to(device)
        with torch.no_grad():
            out = model.generate(**inputs, num_beams=a.num_beams,
                                 num_return_sequences=a.num_beams,
                                 max_new_tokens=120, do_sample=False)
        cands = [tok.decode(o, skip_special_tokens=True).strip() for o in out]
        best, best_score, best_faith, best_cov = None, -1.0, 0.0, 0.0
        for c in cands:
            bl = mc.bullets(c) or [c]
            faith = min(mc.support_probs(src, bl))
            cov = coverage_proxy(src, c)
            score = a.w_faith * faith + (1 - a.w_faith) * cov
            if score > best_score:
                best, best_score, best_faith, best_cov = c, score, faith, cov
        # greedy top-1 = the first beam (beam 0 is the highest-logprob sequence)
        g = cands[0]
        gbl = mc.bullets(g) or [g]
        rows.append({
            "id": case.get("id"),
            "greedy": g, "greedy_faith": round(min(mc.support_probs(src, gbl)), 3),
            "greedy_cov": round(coverage_proxy(src, g), 3),
            "reranked": best, "rerank_faith": round(best_faith, 3),
            "rerank_cov": round(best_cov, 3),
        })
        print(f"{case.get('id')}: greedy_faith={rows[-1]['greedy_faith']} -> rerank_faith={rows[-1]['rerank_faith']}", flush=True)

    Path(a.out).write_text(json.dumps(rows, indent=0))
    print("\n=== summary (test set) ===")
    print(f"entries: {len(rows)}")
    print(f"greedy  : mean_faith={statistics.mean(r['greedy_faith'] for r in rows):.3f}  mean_cov={statistics.mean(r['greedy_cov'] for r in rows):.3f}")
    print(f"reranked: mean_faith={statistics.mean(r['rerank_faith'] for r in rows):.3f}  mean_cov={statistics.mean(r['rerank_cov'] for r in rows):.3f}")
    imp = sum(1 for r in rows if r['rerank_faith'] > r['greedy_faith'])
    print(f"entries where rerank improved faithfulness: {imp}/{len(rows)}")


if __name__ == "__main__":
    main()
