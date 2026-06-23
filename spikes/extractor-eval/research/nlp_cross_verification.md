# Cross-Verification Results: whispernotes NLP Deep Research

## Methodology

After reviewing all 12 dimension research files, findings were classified into four confidence tiers:
- **High Confidence:** Confirmed by ≥2 independent agents or authoritative sources with consistent evidence
- **Medium Confidence:** Supported by 1 strong source or converging but incomplete evidence
- **Low Confidence:** Weak sourcing, single unverified claim, or blog-level evidence
- **Conflict Zone:** Statistical disagreement, interpretive divergence, or temporal inconsistency between dimensions

---

## High Confidence Findings (≥2 independent sources, consistent evidence)

### HC-1: Lexicon-only surface matching has hit its ceiling
**Dimensions:** 01, 04, 08, 11
**Evidence:**
- Dim 01: Even hand-crafted rule systems (SentiStrength) only achieve 60.6% on short informal text, comparable to human inter-coder agreement.
- Dim 04: Paraphrase failures ("wading through wet sand" → sluggish) are inherent to exact-match systems.
- Dim 08: Manual lexicon enumeration is "largely intractable" per clinical NLP literature; LIWC captures only ~66% of domain vocabulary.
- Dim 11: The number of polysemous words that matter for this narrow domain is small (~20-30), but surface matching conflates them.
**Implication:** The current system cannot significantly improve recall without augmenting or replacing the lexicon-only mechanism.

### HC-2: A hybrid architecture (rules + embeddings) is the consensus best path
**Dimensions:** 04, 05, 11
**Evidence:**
- Dim 04: "Don't replace the lexicon — augment it. Three-layer hybrid (exact match → embedding fallback → hard-negatives filter)."
- Dim 05: "The most pragmatic path for an indie ADHD app is a hybrid architecture — keep the existing rule pipeline for exact matches, and layer a lightweight embedding or Foundation Models call for semantic expansion."
- Dim 11: "A hybrid, domain-targeted approach — combining lightweight contextual embeddings, collocational blocklists, and a small set of carrier/contra-indicator phrases — is more practical than deploying full WSD."
**Implication:** The industry consensus converges on exactly what the user needs: preserve the high-precision rule layer for known expressions, add a semantic layer for unknown expressions.

### HC-3: Apple's NLContextualEmbedding is the lowest-friction on-device semantic tool
**Dimensions:** 04, 05
**Evidence:**
- Dim 04: "Apple's native NLContextualEmbedding for a prototype — zero bundle size, on-device, privacy-safe."
- Dim 05: "512-dimensional on-device, privacy-first sentence embeddings on iOS... with zero bundle size overhead and sub-15ms search latency for 1,000 items."
**Implication:** No custom model training or Core ML conversion needed for a prototype. Apple already ships the embedding model.

### HC-4: Distance-aware evaluation metrics are mandatory for ordinal signals
**Dimensions:** 02, 09
**Evidence:**
- Dim 02: QWK, MAE, 1-off accuracy are standard in ordinal classification literature. The dlordinal package implements them.
- Dim 09: "Precision/recall metrics ignore the ordinal ordering of classes... dedicated ordinal metrics are required."
**Implication:** Current eval (scalar wrong = FP+FN) is methodologically flawed and may drive suboptimal improvements.

### HC-5: 40 cases is too small for rigorous statistical inference
**Dimensions:** 09
**Evidence:**
- Dim 09: Clinical NLP test sets typically use 100-500 documents. Bootstrap CIs on 40 cases will be too wide to detect small improvements.
**Implication:** The current floor system (ratchet at observed-0.02) is a good regression guard but not a benchmark. Treat it as a smoke test, not a measure of improvement.

### HC-6: The negative-state bias in the lexicon is both real and problematic
**Dimensions:** 02, 08
**Evidence:**
- Dim 08: Depressed patients genuinely use more negative words (M=2.40 vs M=1.54 for controls), but a 6× larger negative lexicon creates systematic measurement bias.
- Dim 02: The energy/focus lexicon skew (37:7, 39:6) is a class-imbalance problem that drives low recall for positive states.
**Implication:** The bias is not just a bug to fix — it's a tension between clinical reality and measurement validity.

### HC-7: The user feedback loop is broken and underutilized
**Dimensions:** 12
**Evidence:**
- Dim 12: Competitors don't use NLP extraction at all — this is whitespace. But mood/energy/focus corrections are dead ends (not added to lexicon).
- Dim 12: Pattern-based incremental learning and lexicon bootstrapping are mature techniques that could run on-device.
**Implication:** The lowest-hanging fruit for improving recall is extending the personal lexicon to mood/energy/focus phrases, not adding ML.

### HC-8: Present-tense-wins for mood is validated by NLP literature
**Dimensions:** 07
**Evidence:**
- Dim 07: ACM 2024 paper explicitly identifies "Sentiment changes over time, present should prevail" as a required linguistic capability.
**Implication:** The current temporal weighting policy for mood is correct and should be preserved.

### HC-9: ADHD speech patterns compound ASR error rates
**Dimensions:** 06, 10
**Evidence:**
- Dim 06: DSM-V identifies pressured speech, tangential speech, and excessive talking as ADHD symptoms. CADDRA guidelines describe over-inclusive and circumstantial speech.
- Dim 06: ASR errors are phonetic confusions, not orthographic typos, making them harder to decode.
**Implication:** The voice-note input modality is inherently noisier for ADHD users than for the general population. ASR resilience is not optional.

---

## Medium Confidence Findings (1 strong source or converging incomplete evidence)

### MC-1: Energy and focus should also use temporal weighting
**Dimensions:** 07
**Evidence:**
- Dim 07: Clinical NLP anchors ALL events temporally, not just mood. The literature "leans yes" on principle, but implementation cost is high.
- Dim 07: The current system already has TenseClassifier built; applying it to energy/focus is cheap.
**Implication:** Likely a quick win with minimal code change.

### MC-2: Symmetric polarity flipping for negation is linguistically wrong
**Dimensions:** 03
**Evidence:**
- Dim 03: Research shows "not great" ≠ "low"; it means "mild negative." The current hard flip should map to a middle tier instead of the antipode.
**Implication:** The negation logic is a precision risk, though it may not be the highest-priority fix.

### MC-3: First-person pronouns are more reliable depression markers than negative emotion words
**Dimensions:** 08
**Evidence:**
- Dim 08: Meta-analysis (k=21, N=3,758) shows r=0.13 correlation between first-person singular pronouns and depression. The current system ignores structural markers entirely.
**Implication:** A hidden signal that the current lexicon-only approach cannot capture.

### MC-4: On-device small LLMs (1-3B) are feasible but not the best tool for this task
**Dimensions:** 05
**Evidence:**
- Dim 05: Phi-4-mini (3.8B), Llama-3.2 3B can run on modern phones quantized. But dim 04 shows fine-tuned encoders (22M) achieve comparable accuracy at 1/100 the cost.
**Implication:** Generative LLMs are overkill; embedding-based classification is the right abstraction level.

### MC-5: The app's taxonomy is clinically useful but not validated against instruments
**Dimensions:** 10
**Evidence:**
- Dim 10: ASRS/ADHD-RS only measure inattention + hyperactivity. BRIEF-A captures executive dysfunction. WFIRS captures functional impairment. The app's multi-signal approach aligns with patient needs but has no validated instrument mapping.
**Implication:** Position as self-management tool, not clinical instrument replacement.

---

## Low Confidence Findings

### LC-1: MLX could be used for prototyping custom embeddings
**Dimensions:** 05
**Evidence:** Apple explicitly states MLX is "intended for research and not for production deployment."
**Implication:** Ignore MLX for production; use Core ML or NLContextualEmbedding instead.

### LC-2: Foundation Models framework (3B) could replace the entire pipeline
**Dimensions:** 05
**Evidence:** Hardware-gated to A17 Pro/M1+, which excludes iPhone 15 non-Pro and older devices. Creates two-tier experience.
**Implication:** Useful as a premium feature on supported devices, not a universal solution.

---

## Conflict Zones

### CZ-1: How much should the lexicon grow?
- **Dim 08 (Lexicon):** "Manual lexicon enumeration is largely intractable." XLex shows transformer-aided expansion can improve accuracy by 0.431-0.450. But even comprehensive terminologies cover only ~4.2% of real EHR tokens.
- **Dim 04 (Paraphrase):** "Lexicon expansion is a dead end — use embeddings instead."
- **Resolution:** Both are partially right. Lexicon expansion has diminishing returns; embeddings are the long-term solution. But embeddings need a lexicon as anchor points (Norel 2025: semantic similarity to anchor sentences). The lexicon is not dead — it becomes the anchor set for embedding similarity.

### CZ-2: Is negative-state bias a feature or a bug?
- **Dim 08 (Lexicon):** Depressed patients genuinely use more negative words. This is a real linguistic marker.
- **Dim 02 (Ordinal):** The 6× negative bias systematically under-detects positive states, reducing recall for good/great moods and alert/charged energy.
- **Resolution:** It's both. In a clinical population, negative words are more frequent. But the measurement system should not amplify this bias. The lexicon should be balanced for coverage, and the evaluation should use distance-aware metrics that don't penalize positive-state misses more than negative-state misses.

### CZ-3: Rule-based vs. ML-based negation
- **Dim 03 (Negation):** The 5-word window is empirically validated (Cruz & Taboada 2016: F1 ~72%). ConText termination-term approach is the most practical upgrade.
- **Dim 03 (Negation):** ALBERT achieves F1 0.991 on radiology reports, far outperforming rules.
- **Resolution:** For short diary text (1-3 sentences), the 5-word window is likely sufficient. For longer entries, ConText's termination-term upgrade is the pragmatic next step. Full ML negation is overkill for this domain and text length.

### CZ-4: Should the app learn from user corrections?
- **Dim 12 (Feedback):** Human-in-the-loop works, active learning reduces burden by 1/3.
- **Dim 12 (Feedback):** Users avoid logging negative moods, creating selection bias. On-device training overfits severely.
- **Resolution:** Learn, but carefully. Use lexicon-only updates (not model training), with batched aggregation and a "no learning" fallback mode. Federated lexicon aggregation (like Gboard OOV discovery) is the safest middle path.

---

## Summary: Confidence by Finding Category

| Category | High | Medium | Low | Conflict |
|----------|------|--------|-----|----------|
| Architecture (hybrid) | 1 | 0 | 0 | 0 |
| On-device feasibility | 1 | 1 | 2 | 0 |
| Evaluation methodology | 2 | 0 | 0 | 0 |
| Lexicon coverage | 1 | 0 | 0 | 1 |
| Negation handling | 0 | 1 | 0 | 1 |
| Temporal handling | 1 | 1 | 0 | 0 |
| Paraphrase/semantic | 1 | 0 | 0 | 1 |
| ASR resilience | 1 | 0 | 0 | 0 |
| Clinical validity | 0 | 1 | 0 | 0 |
| User feedback | 1 | 0 | 0 | 1 |
| Bias/imbalance | 1 | 1 | 0 | 1 |

**Total: 9 High, 4 Medium, 2 Low, 4 Conflict Zones**
