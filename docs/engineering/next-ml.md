# Next ML: Replacing / Augmenting the NLP Extraction Layer

> Status: 💡 exploration (2026-06-12). Decision doc, not a plan yet.
> Context: current per-recording extraction is deterministic lexicon + Apple `NaturalLanguage` (see `app-two/Services/NoteExtraction/`). Concern: recall is poor on paraphrases and will worsen as we add languages. Constraints below rule out the obvious answer.

## Hard constraints

- **Device floor: iPhone 12 Pro+ (A14, 6 GB RAM).** This **rules out Apple Foundation Models** (Apple Intelligence requires iPhone 15 Pro+). That was otherwise the best fit (free, built-in, `@Generable` guided generation).
- **On-device only** — privacy is a product pillar. No cloud extraction.
- **Multilingual is a near-term goal** — whatever we pick must scale past English without re-architecting.
- **Gemma is gone** — removed before the app-four fork; too heavy for what is fundamentally topic extraction + extractive summarization. `AIModelType` now has a single case (`.whisper`); no Gemma service, engine, or download path remains in the app target.

## Reframe: this is not one generative task

"Topic extraction and summarization" is really **three different ML task shapes**, none of which require a generative LLM:

| Product feature | Real ML task | Right tool class |
|---|---|---|
| Mood / energy / focus; cue categories (side effects, wins, overwhelm, exec dysfunction…) | **Sentence classification** (multi-label) | BERT-class **encoder** + small head |
| Medications, doses, times, feelings | **Span extraction / NER** | Lexicon + regex, or encoder word-tagger |
| "Summary" | **Extractive** sentence ranking + template title (we never generate prose) | Embedding similarity ranking (encoder) |

Conclusion: **encoders (BERT-class) cover 100% of what the app does today.** They are 10–100× smaller than any generative SLM, run in milliseconds on an A14, and behave deterministically enough to test. The heavyweight-SLM question mostly dissolves.

## Options (all run on A14)

### Option 1 — Apple's built-in BERT: `NLContextualEmbedding` + CreateML heads ⭐ recommended start
Apple already ships a multilingual BERT we are not using.
- `NLContextualEmbedding` (iOS 17+) — BERT-architecture transformer; **three models grouped by writing system → 27 languages**; 512-dim vectors; up to 256 tokens/call.
- CreateML supports **transfer learning** on top of it for our exact two shapes: **text classification** and **word tagging**.
- **Build:** tiny classifier heads (mood/energy/focus levels; the 11 cue categories as multi-label) + a word tagger for feelings/side-effect spans. Each head < 1 MB.
- **Pros:** nothing to ship (OS downloads the embedding assets); multilingual for free; A14-fine; Swift-native; keeps privacy.
- **Cons:** quality ceiling below a modern fine-tuned encoder; 256-token window → per-sentence calls (already how the extractor works); **requires training data**.
- This is the **missing middle** between the lexicon and the Foundation Models we can't use.

### Option 2 — Ship a compact encoder: GLiNER-multi or MiniLM-class (escalation path)
- **GLiNER** — zero-shot NER: pass label names ("medication", "side effect", "feeling") at inference, **no training data needed**. Multilingual variant (EN/FR/DE/ES/IT/PT); ONNX int8 exports exist (~100–300 MB quantized; CPU-friendly).
- Or a fine-tuned multilingual MiniLM/DistilBERT (~50–150 MB) for the classification heads if Option 1's ceiling is too low.
- **Pros:** higher ceiling; full control; GLiNER needs zero training data.
- **Cons:** we own ONNX/CoreML conversion, shipping, and updates (same playbook as WhisperKit, so feasible — but real maintenance).
- **Use as the escalation if Option 1's measured quality disappoints**, not the starting point.

### Option 3 — Tiny generative SLM (Qwen3-0.6B / SmolLM / NuExtract-tiny) — parked
- Only justified if we later want **abstractive** summaries ("Rough morning until the Concerta kicked in…") across languages.
- ~400–700 MB quantized; seconds of latency; battery cost; needs grammar-constrained decoding to be safe.
- Not needed for extraction. Park it.

## Recommended architecture (layered; keep what works)

1. **Keep lexicon + regex for medications, doses, times.** Brand names are language-agnostic proper nouns — already our most precise layer and cheap to internationalize (per-language regex tweaks).
2. **Replace mood/energy/focus + cue-category detection** with CreateML heads over `NLContextualEmbedding`. Directly attacks both the recall (paraphrase) problem and the multilingual problem in one move.
3. **Feelings / side-effect spans:** CreateML word tagger first; GLiNER if zero-shot flexibility is wanted later.
4. **Highlights:** rank sentences by contextual-embedding similarity to signal categories — multilingual automatically.
5. **Merge semantics unchanged:** lexicon hits stay authoritative; the model fills gaps. The existing `applySummary(fillOnly:)` + tag-provenance machinery already models this.

## The real bottleneck: data, not models

Everything except GLiNER needs labeled training data.
- **Plan:** synthetic data distillation — use a frontier LLM at dev time to generate a few thousand labeled ADHD-journal transcripts **per language**; train the small heads on that.
- **Eval set:** the `RecordingTag(source: .userCorrected)` corrections are real-world lexicon misses → use them as the held-out eval, never for training.
- Model choice is the easy 20%; the dataset is the 80%.

## Next steps (in order)

1. **Build a ~100-transcript eval harness** scoring the *current* lexicon per signal (mood/energy/focus/meds/sleep/feelings/…). Turns "poor performance" from a feeling into per-signal numbers; becomes the regression suite for any future model; may show some layers (e.g. meds) need no replacement.
2. **Prototype Option 1**: one CreateML classifier head (start with mood — already exercised by `NLNoteExtractorMoodTests`) over `NLContextualEmbedding`; compare against lexicon on the eval set.
3. If the ceiling is too low → escalate to Option 2 (GLiNER zero-shot, no data needed) for the weak signals.
4. **Delete dormant Gemma** (`GemmaSummarizationService`, `GemmaInferenceEngine`, download UI) once a direction is chosen.

## Guard rail

Extraction is not the moat — the product is (ADHD-specific schema, med-timing, provenance, privacy, the correction-learning loop). Don't over-invest in the algorithm. Pick the option that maximizes recall-per-maintenance-dollar and keeps shipping.

## Sources

- [NLContextualEmbedding — Apple docs](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)
- [Apple on-device embeddings deep-dive (Callstack)](https://www.callstack.com/blog/on-device-ai-introducing-apple-embeddings-in-react-native)
- [Apple's multilingual NLP tools (Slator)](https://slator.com/apple-giving-developers-new-set-nlp-tools/)
- [GLiNER (GitHub)](https://github.com/urchade/GLiNER) · [GLiNER2 overview (TDS)](https://towardsdatascience.com/gliner2-extracting-structured-information-from-text/) · [GLiNER multilingual ONNX](https://huggingface.co/juampahc/gliner_multi-v2.1-onnx)
- [NuExtract (NuMind)](https://numind.ai/blog/nuextract-a-foundation-model-for-structured-extraction)
- [ONNX Runtime mobile](https://onnxruntime.ai/docs/tutorials/mobile/)
- [Foundation Models limitations / 4096-token window (TN3193)](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
- [Best on-device iPhone LLMs 2026](https://modelfit.io/guides/best-llm-for-iphone/) · [On-Device LLMs: State of the Union 2026](https://v-chandra.github.io/on-device-llms/)
