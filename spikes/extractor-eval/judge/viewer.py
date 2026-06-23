"""Minimal browsable audit viewer (spec 013, US3, FR-010/011).

Self-contained: emits out/eval_browser.html from out/verdicts_1082.json joined with
the corpus + extractor dump. Filter by signal x verdict (FP/FN/TP/TN). The original
make_eval_html.py is not on this branch, so this is a standalone replacement.
"""
import html
import json

from judge.io import SIGNALS, load_corpus, load_extractions, join, extractor_presence
from judge.schema import parse_verdict
from judge.metrics import derive_label


def build_rows(verdicts, joined):
    rows = []
    jmap = {m["id"]: m for m in joined}
    for pid, pv in verdicts.items():
        m = jmap.get(pid)
        if not m:
            continue
        ep = extractor_presence(m["extraction"])
        for s in SIGNALS:
            label = derive_label(pv.signals[s].present, ep[s])
            rows.append({
                "id": pid, "signal": s, "label": label,
                # escape all post-derived content — it is rendered via innerHTML
                "reason": html.escape(pv.signals[s].reason),
                "ext": html.escape(str(m["extraction"].get(s if s != "sleep" else "sleepHours"))),
                "text": html.escape(" ".join(m["text"].split())[:500]),
            })
    return rows


_HTML = """<!doctype html><meta charset=utf-8><title>013 judge audit</title>
<style>body{{font:14px system-ui;margin:1.5rem;max-width:60rem}}
button{{margin:2px;padding:4px 8px}} .card{{border:1px solid #ddd;border-radius:6px;padding:8px;margin:6px 0}}
.FP{{border-left:5px solid #e55}} .FN{{border-left:5px solid #e90}} .TP{{border-left:5px solid #5a5}} .TN{{border-left:5px solid #ccc}}
.tag{{font-weight:700}} .meta{{color:#666;font-size:12px}}</style>
<h2>LLM-judge audit — {n} verdicts ({posts} posts)</h2>
<div id=bar></div><div id=list></div>
<script>const R={rows};
const sigs=['all','mood','energy','focus','sleep'], labs=['all','FP','FN','TP','TN'];
let fs='all', fl='poor';
function poor(r){{return r.label==='FP'||r.label==='FN'}}
function draw(){{
 document.getElementById('list').innerHTML=R.filter(r=>(fs==='all'||r.signal===fs)&&
   (fl==='all'?1:fl==='poor'?poor(r):r.label===fl)).map(r=>
   `<div class="card ${{r.label}}"><span class="tag">${{r.signal}} · ${{r.label}}</span>
    <span class="meta">ext=${{r.ext}} · ${{r.id.slice(0,8)}}</span>
    <div class="meta">judge: ${{r.reason}}</div><div>${{r.text}}</div></div>`).join('');}}
function bar(){{const b=document.getElementById('bar');
 b.innerHTML='signal: '+sigs.map(s=>`<button onclick="fs='${{s}}';draw()">${{s}}</button>`).join('')+
 ' &nbsp; verdict: <button onclick="fl=\\'poor\\';draw()">FP+FN</button>'+
 labs.map(l=>`<button onclick="fl='${{l}}';draw()">${{l}}</button>`).join('');}}
bar();draw();</script>"""


def main():
    corpus = list({r["id"]: r for r in load_corpus("data/addrec_1082_summaries.jsonl")}.values())
    extr = load_extractions("out/extractions_500.json")
    joined = join(corpus, extr)
    verdicts = {v["id"]: parse_verdict(v) for v in json.load(open("out/verdicts_1082.json"))}
    rows = build_rows(verdicts, joined)
    out = _HTML.format(n=len(rows), posts=len({r["id"] for r in rows}),
                       rows=json.dumps(rows))
    open("out/eval_browser.html", "w").write(out)
    print(f"wrote out/eval_browser.html — {len(rows)} verdict rows, "
          f"{sum(1 for r in rows if r['label'] in ('FP', 'FN'))} FP/FN to audit")


if __name__ == "__main__":
    main()
