# Spike 3 — Apple Create ML text classifier → NLModel (supervised)

**Status:** scaffolded · **Type:** throwaway · **Scope:** EN, mood/energy/focus

The native, smallest, exact-fit option — and the only one that lets you **teach**
modality directly instead of hoping a model infers it. Scored on the **same gate** as
Spikes 1 & 2, but it is **supervised**, so it has a labeling prerequisite they don't.

## ⚠️ This one is NOT zero-setup — it's gated on labels

Spikes 1 & 2 run today with zero labeling. Spike 3 cannot train until you have a
labeled corpus. **Start the labeling now, in parallel with running 1 & 2** — by the
time you've judged the zero-shot results you'll have enough to train and score this.

## Step A — Build the labeled corpus (the real work)

Three datasets — `mood.json`, `energy.json`, `focus.json` — each a list of
`{"text": "<sentence>", "label": "<level | none>"}`. Target a few hundred sentences
per signal, **with `none` the most abundant class**.

**Do NOT silver-label from the lexicon extractor** — it would auto-label *"let's see if
I can focus"* as `sharp` and teach the model your bug. Hand-label the hard cases:
hypotheticals/hopes/negations → `none`, paraphrase, past tense. Modality becomes a
*labeling discipline* here, which is this approach's whole advantage.

## Step B — Train (offline, macOS — Swift `CreateML` or the Create ML app)

```swift
import CreateML
import Foundation

for signal in ["mood", "energy", "focus"] {
    let data = try MLDataTable(contentsOf: URL(fileURLWithPath: "\(signal).json"))
    let (train, test) = data.randomSplit(by: 0.85, seed: 7)
    let model = try MLTextClassifier(
        trainingData: train,
        textColumn: "text",
        labelColumn: "label",
        parameters: MLTextClassifier.ModelParameters(
            validation: .split(strategy: .automatic),
            algorithm: .transferLearning(.dynamicEmbedding, revision: 1),  // iOS 17+ contextual embedding
            language: .english))
    let eval = model.evaluation(on: test)
    print(signal, "held-out accuracy:", 1.0 - eval.classificationError)
    try model.write(to: URL(fileURLWithPath: "\(signal.capitalized)Classifier.mlmodel"))
}
```
*(Exact `ModelParameters`/algorithm enum names vary by Create ML version; the Create ML
app is the no-code alternative. `.dynamicEmbedding` gives transformer-grade features
without you shipping a transformer — the model stays <5 MB because the embedding lives
in iOS.)*

## Step C — Evaluate on the SAME gate (Swift, reuse the existing harness)

Spike 3's eval doesn't need `evalset.json` — `EvalSet` is already Swift. Add a variant
to `ExtractionEvalTests` that runs the 3 NLModels and scores with the existing
`EvalCounts` / `EvalFloors`, so the number is directly comparable to Spikes 1 & 2:

```swift
let nl: [String: NLModel] = [
    "mood":   try NLModel(mlModel: MoodClassifier(configuration: .init()).model),
    "energy": try NLModel(mlModel: EnergyClassifier(configuration: .init()).model),
    "focus":  try NLModel(mlModel: FocusClassifier(configuration: .init()).model),
]
let tau = 0.55   // abstain threshold on predictedLabelHypotheses confidence

func classifyNote(_ transcript: String, _ model: NLModel) -> String? {
    var best: (String, Double)? = nil
    for s in sentences(of: transcript) {                       // mirror the lexicon's sentence split
        let hyp = model.predictedLabelHypotheses(for: s, maximumCount: 1)
        if let top = hyp.max(by: { $0.value < $1.value }),
           top.key != "none", top.value >= tau,
           best == nil || top.value > best!.1 {                // strongest-confidence-wins (same as zero-shot)
            best = (top.key, top.value)
        }
    }
    return best?.0
}
// feed classifyNote(...) into EvalCounts(expectedScalar:actualScalar:) vs EvalFloors — same as runEval()
```

## Why this can still win the bake-off

- **Exact label space** (your 5 levels + `none`), not a borrowed taxonomy.
- **Smallest + fastest on-device**: <5 MB/signal, 1 forward pass/signal (vs zero-shot's
  ~5 passes/label), no Core ML conversion, no tokenizer port — `NLModel` handles it.
- **Best fit for energy & focus**, where no pretrained model exists — you train *on*
  your taxonomy instead of inferring it.
- **Modality is taught, not gambled.**

The cost is the labeling in Step A. The bake-off question: does that cost buy enough
over the zero-shot options (which need none) to be worth it?

## Gate

Same as 1 & 2: per-signal **P and R ≥ floor**, and the trained `focus` model returns
`none` for *"lets see if I can focus now"* (because you labeled hypotheticals as `none`).
