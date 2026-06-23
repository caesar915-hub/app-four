#!/usr/bin/env python3
"""Generate a self-contained, filterable HTML to audit the 468 judged extractions.

Joins out/extractions_500.json (text + extractor output) with
results/judge_verdicts.json (per-record LLM verdicts) and emits one HTML file with
the data embedded — opens in any browser, no server.
"""
import json, os

BASE = os.path.dirname(os.path.abspath(__file__))
ex = {r['id']: r for r in json.load(open(f'{BASE}/out/extractions_500.json'))}
vd = json.load(open(f'{BASE}/results/judge_verdicts.json'))

records = []
for v in vd:
    r = ex.get(v['id'], {})
    records.append({
        'id': v['id'][:8],
        'text': (r.get('text') or '')[:900],
        'mood': r.get('mood'), 'energy': r.get('energy'), 'focus': r.get('focus'),
        'meds': r.get('meds') or [], 'feelings': r.get('feelings') or [],
        'activities': r.get('activities') or [], 'sleepHours': r.get('sleepHours'),
        'sideEffect': r.get('sideEffect'), 'title': r.get('title') or '',
        'gold': r.get('goldSignals') or [],
        'jmood': v.get('mood', 'na'), 'jenergy': v.get('energy', 'na'),
        'jfocus': v.get('focus', 'na'), 'jmeds': v.get('meds', 'na'),
        'overall': v.get('overall', '?'), 'note': v.get('note', ''),
    })

DATA = json.dumps(records, ensure_ascii=False)

HTML = r"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NLP Extractor — Evaluation Browser</title>
<style>
  :root{--cor:#1a8a4a;--par:#c98a00;--mis:#d2691e;--fp:#c0392b;--na:#9aa0a6;--bg:#f7f6f2;--card:#fff;--ink:#23262b;--mut:#6b7178;--line:#e6e3da}
  *{box-sizing:border-box}
  body{margin:0;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:var(--bg);color:var(--ink)}
  header{position:sticky;top:0;background:rgba(247,246,242,.96);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:14px 20px;z-index:10}
  h1{font:600 17px/1.2 "Iowan Old Style",Georgia,serif;margin:0 0 8px}
  .stats{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:12px;color:var(--mut);margin-bottom:10px}
  .stats b{color:var(--ink)}
  .controls{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
  select,input,button{font:13px inherit;padding:5px 9px;border:1px solid var(--line);border-radius:7px;background:#fff;color:var(--ink)}
  input[type=search]{min-width:220px}
  button{cursor:pointer}
  button.q{background:#efece4}
  button.q:hover{background:#e6e2d6}
  #count{font-size:12px;color:var(--mut);margin-left:auto}
  main{padding:16px 20px;max-width:1000px;margin:0 auto}
  .card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin-bottom:12px;box-shadow:0 1px 2px rgba(0,0,0,.03)}
  .crow{display:flex;align-items:center;gap:8px;margin-bottom:8px;flex-wrap:wrap}
  .id{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--mut)}
  .ov{font-size:11px;font-weight:700;text-transform:uppercase;padding:2px 8px;border-radius:20px;letter-spacing:.04em}
  .ov.good{background:#e3f3e8;color:var(--cor)} .ov.ok{background:#fbf0d6;color:var(--par)} .ov.poor{background:#f8e0db;color:var(--fp)}
  .gold{font-size:11px;color:var(--mut)}
  .gold b{color:var(--ink)}
  .text{white-space:pre-wrap;color:#33373d;background:#fbfaf6;border:1px solid var(--line);border-radius:8px;padding:9px 11px;margin:6px 0;font-size:13px}
  .sig{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0}
  .chip{font-size:12px;padding:3px 9px;border-radius:20px;border:1px solid var(--line);background:#fff;display:inline-flex;gap:6px;align-items:center}
  .chip .v{font-weight:600}
  .chip[data-j=correct]{border-color:var(--cor)} .chip[data-j=correct] .dot{background:var(--cor)}
  .chip[data-j=partial]{border-color:var(--par)} .chip[data-j=partial] .dot{background:var(--par)}
  .chip[data-j=missed]{border-color:var(--mis)} .chip[data-j=missed] .dot{background:var(--mis)}
  .chip[data-j=false_positive]{border-color:var(--fp)} .chip[data-j=false_positive] .dot{background:var(--fp)}
  .chip[data-j=na]{opacity:.6} .chip[data-j=na] .dot{background:var(--na)}
  .dot{width:8px;height:8px;border-radius:50%;display:inline-block}
  .meta{font-size:12px;color:var(--mut);margin:4px 0}
  .note{font-size:13px;color:#444;border-left:3px solid var(--line);padding:2px 0 2px 10px;margin-top:8px}
  .legend{font-size:11px;color:var(--mut);display:flex;gap:12px;flex-wrap:wrap;margin-top:6px}
  .legend span{display:inline-flex;gap:5px;align-items:center}
</style></head>
<body>
<header>
  <h1>NLP Extractor — Evaluation Browser</h1>
  <div class="stats" id="stats"></div>
  <div class="controls">
    <select id="fOverall"><option value="">overall: any</option><option>good</option><option>ok</option><option>poor</option></select>
    <select id="fSignal"><option value="">signal: any</option><option>mood</option><option>energy</option><option>focus</option><option>meds</option></select>
    <select id="fVerdict"><option value="">verdict: any</option><option>correct</option><option>partial</option><option>missed</option><option>false_positive</option><option>na</option></select>
    <input type="search" id="fSearch" placeholder="search text or note…">
    <button class="q" data-q="poor">Poor only</button>
    <button class="q" data-q="moodfp">Mood FPs</button>
    <button class="q" data-q="energymiss">Energy misses</button>
    <button class="q" data-q="reset">Reset</button>
    <span id="count"></span>
  </div>
  <div class="legend">
    <span><i class="dot" style="background:var(--cor)"></i>correct</span>
    <span><i class="dot" style="background:var(--par)"></i>partial</span>
    <span><i class="dot" style="background:var(--mis)"></i>missed</span>
    <span><i class="dot" style="background:var(--fp)"></i>false positive</span>
    <span><i class="dot" style="background:var(--na)"></i>n/a</span>
  </div>
</header>
<main id="list"></main>
<script>
const DATA = __DATA__;
const SIGS = ['mood','energy','focus','meds'];
const esc = s => (s==null?'':String(s)).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));

function stats(){
  const el = document.getElementById('stats');
  const ov = {good:0,ok:0,poor:0};
  const per = {}; SIGS.forEach(s=>per[s]={correct:0,partial:0,missed:0,false_positive:0,na:0});
  DATA.forEach(d=>{ ov[d.overall]=(ov[d.overall]||0)+1; SIGS.forEach(s=>per[s][d['j'+s]]++); });
  let h = `<span><b>${DATA.length}</b> records</span><span>overall: <b>${ov.good}</b> good / <b>${ov.ok}</b> ok / <b>${ov.poor}</b> poor</span>`;
  SIGS.forEach(s=>{const p=per[s];const scored=p.correct+p.partial+p.missed+p.false_positive;
    h+=`<span>${s}: <b>${scored?(p.correct/scored).toFixed(2):'–'}</b> acc (fp ${p.false_positive}, miss ${p.missed})</span>`;});
  el.innerHTML = h;
}

function chip(sig,d){
  const v = d[sig]==null? '∅' : (Array.isArray(d[sig])? (d[sig].join(', ')||'∅') : d[sig]);
  const j = d['j'+sig];
  return `<span class="chip" data-j="${j}"><i class="dot"></i>${sig} <span class="v">${esc(v)}</span> <span style="color:var(--mut)">·${j}</span></span>`;
}

function render(rows){
  document.getElementById('count').textContent = rows.length+' shown';
  document.getElementById('list').innerHTML = rows.map(d=>`
    <div class="card">
      <div class="crow">
        <span class="id">${d.id}</span>
        <span class="ov ${d.overall}">${d.overall}</span>
        <span class="gold">gold present: <b>${d.gold.map(esc).join(', ')||'—'}</b></span>
      </div>
      <div class="text">${esc(d.text)}</div>
      <div class="sig">${SIGS.map(s=>chip(s,d)).join('')}</div>
      ${(d.feelings.length||d.activities.length||d.sleepHours!=null||d.sideEffect)?
        `<div class="meta">feelings: ${d.feelings.map(esc).join(', ')||'—'} · activities: ${d.activities.map(esc).join(', ')||'—'} · sleepHours: ${esc(d.sleepHours??'—')} · sideEffect: ${d.sideEffect?'yes':'no'}</div>`:''}
      <div class="note">${esc(d.note)}</div>
    </div>`).join('');
}

function apply(){
  const o=document.getElementById('fOverall').value, s=document.getElementById('fSignal').value,
        v=document.getElementById('fVerdict').value, q=document.getElementById('fSearch').value.toLowerCase();
  let rows = DATA.filter(d=>{
    if(o && d.overall!==o) return false;
    if(s && v && d['j'+s]!==v) return false;
    if(s && !v) {/* signal alone: no constraint */}
    if(!s && v && !SIGS.some(x=>d['j'+x]===v)) return false;
    if(q && !(d.text.toLowerCase().includes(q) || d.note.toLowerCase().includes(q))) return false;
    return true;
  });
  render(rows);
}
['fOverall','fSignal','fVerdict','fSearch'].forEach(id=>document.getElementById(id).addEventListener('input',apply));
document.querySelectorAll('button.q').forEach(b=>b.addEventListener('click',()=>{
  const q=b.dataset.q, $=id=>document.getElementById(id);
  $('fOverall').value='';$('fSignal').value='';$('fVerdict').value='';$('fSearch').value='';
  if(q==='poor'){$('fOverall').value='poor';}
  if(q==='moodfp'){$('fSignal').value='mood';$('fVerdict').value='false_positive';}
  if(q==='energymiss'){$('fSignal').value='energy';$('fVerdict').value='missed';}
  apply();
}));
stats(); apply();
</script>
</body></html>"""

out = f'{BASE}/results/eval_browser.html'
open(out, 'w').write(HTML.replace('__DATA__', DATA))
print('wrote', out, '(%.0f KB)' % (os.path.getsize(out)/1024))
