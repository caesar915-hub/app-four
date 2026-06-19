# Phase 0 bake-off — semantic extraction vs the lexicon

Three independent spikes, one shared gate. Goal: find an on-device way to extract
**mood / energy / focus** that beats the lexicon's precision/recall floors — ideally
with little or no labeling, no LLM, no Apple Foundation Models (target: iPhone 12 Pro).

| # | Spike | Approach | Labels? | Run today? | Step-1 (on-device) cost |
|---|---|---|---|---|---|
| 1 | [`zeroshot-nli/`](zeroshot-nli/) | zero-shot NLI · `xtremedistil` (~25 MB) | none | ✅ | easiest (WordPiece, traces clean) |
| 2 | [`zeroshot-deberta/`](zeroshot-deberta/) | zero-shot NLI · `deberta-v3-base` (~185 MB) | none | ✅ | hardest (SentencePiece + disentangled attn) |
| 3 | [`createml-nlmodel/`](createml-nlmodel/) | supervised Create ML → `NLModel` (<5 MB/signal) | **yes** | after labeling | smallest/native (no conversion) |

## Does running them in parallel make sense? Yes — if the contract is shared

The bake-off is only valid because all three score on **identical terms**:

- **Same test set** — `spikes/evalset.json`, generated once from `EvalSet.swift` (Spike 3
  reads `EvalSet` directly in Swift). Generate it, don't hand-copy (see below).
- **Same floors** — `mood (0.730/0.580)`, `energy (0.647/0.230)`, `focus (0.380/0.313)`.
- **Same note-level aggregation** — strongest-confidence-across-sentences wins.
- **Same gate** — per-signal **P and R ≥ floor**, plus the modality probe returns
  `focus → none` for *"lets see if I can focus now"*.
- For **1 vs 2 only**: identical verbalization / template / threshold, so the delta is
  the *model*, not the *prompt*.

Two caveats, already noted: **Spike 3 isn't zero-setup** (label first — start now, in
parallel), and **don't tune the threshold on these 40 cases** and call it calibrated
(feasibility check, not a calibrated number).

## What each spike answers

- **1** — is the *cheapest* model already good enough? (If yes, you're basically done.)
- **2** — does a *stronger* zero-shot model clear the bar / handle modality better — enough to justify a much harder deployment?
- **3** — does a *tiny supervised* model with exact label fit win, at the cost of labeling — especially on energy/focus, where no pretrained model exists?

## Decision rule

Prefer the **lightest approach that clears the gate**, not the highest score. Rough
order of preference if multiple clear: **1 (cheapest, no labels) > 3 (tiny, exact fit) >
2 (heaviest deployment)**. If the zero-shot options wobble specifically on **energy /
focus** (the likeliest outcome — they have no pretrained grounding), Spike 3 is the
fallback that fixes exactly those.

## Generate the shared `evalset.json` (once)

**Easiest — already wired:** `python spikes/gen_evalset.py` parses `EvalSet.swift`
directly and writes `spikes/evalset.json` (40 cases, no Xcode build, reproducible).
Re-run it whenever `EvalSet.swift` changes.

Alternative (from inside the app, if you prefer): add this gated test to
`app-fourTests/Eval/ExtractionEvalTests.swift` (mirrors the existing `EVAL_REPORT`
pattern), run with `EVAL_EXPORT=1`, and place the emitted file at `spikes/evalset.json`:

```swift
@Test(.enabled(if: ProcessInfo.processInfo.environment["EVAL_EXPORT"] == "1"))
func exportEvalSet() throws {
    struct Row: Encodable { let id, transcript: String; let mood, energy, focus: String? }
    let rows = EvalSet.cases.map {
        Row(id: $0.id, transcript: $0.transcript,
            mood: $0.mood, energy: $0.energy?.rawValue, focus: $0.focus?.rawValue)
    }
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("evalset.json")
    try JSONEncoder().encode(rows).write(to: url)
    Issue.record(Comment(rawValue: "wrote \(url.path)"))
}
```

## Results — fill in after running

| approach | model | mood P/R | energy P/R | focus P/R | modality probe | gate | added size | training |
|---|---|---|---|---|---|---|---|---|
| lexicon (baseline) | — | 0.73/0.58 | 0.65/0.23 | 0.38/0.31 | ✗ fires Sharp | — | 0 | none |
| 1 zero-shot | xtremedistil | | | | | | ~25 MB | none |
| 2 zero-shot | deberta-v3-base | | | | | | ~185 MB | none |
| 3 supervised | createml | | | | | | <15 MB | labels |
