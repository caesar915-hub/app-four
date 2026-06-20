# Roadmap — what we did, what's next

Open in the IDE markdown preview to render the diagram.

```mermaid
flowchart TD
  subgraph DONE["DONE - evaluation (synthetic, self-contained loop)"]
    A[Generate 100 synthetic<br/>multi-signal ADHD entries] --> B[Sweep 4 models:<br/>base / large / gemma-ul2 / gemma-prefixlm]
    B --> C[v1 eval: flan-large best,<br/>gemma fabricates -- but harness was flawed]
    C --> D{External critique:<br/>contamination, omission,<br/>anti-loop, weak metrics}
    D --> E[LOCK v3 methodology:<br/>dev/test split, gold anchor,<br/>MiniCheck, cascade gate, CIs]
    E --> F[Step 1: report on test-30 + Wilson CIs]
    F --> G[Step 2: human-adjudicated gold anchor]
    G --> H[Step 3: MiniCheck 3rd instrument<br/>cascade gate, kappa=0.26]
    H --> I[Step 4: decoding ablation<br/>beam+rerank NOT better than greedy]
    I --> J[Conclusion:<br/>flan-large faithful 0.789 / omits 32 pct<br/>gemma complete 93 pct / fabricates<br/>cheap tier exhausted]
  end

  J --> K{{Two parallel tracks}}

  subgraph FIX["NEXT - fix the model: LoRA spike"]
    K --> L[Teacher = Claude HERE:<br/>generate gold summaries]
    L --> M[Rejection-sample:<br/>keep only faithful + complete]
    M --> N[Push dataset to VM:<br/>LoRA rank-16 flan-t5-large GPU]
    N --> O[Eval on test-30 + real held-out<br/>same v3 metric stack]
  end

  subgraph LOOP["NEXT - break the closed loop: real data"]
    K --> P[A1 real transcripts<br/>Whisper transcribe]
    P --> Q[A2 powered held-out >= 150-300]
    Q --> R[A3 multi-annotator gold + kappa]
    R --> S[A4/A5 external metric + HUMAN gate]
  end

  O --> T{{Pre-registered gate<br/>on REAL held-out}}
  S --> T
  T -->|fabrication CI < 2pct<br/>recall >= 85pct<br/>human queue empty| U[SHIP decision]
  T -->|fail| V[iterate:<br/>two-pass / larger base / more data]
  V -.-> K
```

## Legend
- **DONE** = the evaluation, all on synthetic data inside a Claude-only loop. Conclusion is defensible *relatively* (flan-large is safest) but not ship-certified.
- **FIX track** = make flan-large complete without losing faithfulness (LoRA). Can start on existing data.
- **LOOP track** = replace the self-referential pieces with external anchors (real data, human annotators, human gate). The one thing Claude cannot be.
- **GATE** = both tracks reconverge here; a ship decision needs *real* data + a pre-registered bar, not synthetic self-evaluation.
