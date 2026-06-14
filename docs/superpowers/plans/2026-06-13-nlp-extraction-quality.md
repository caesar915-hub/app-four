# NLP Extraction Quality (Phases A–C, E + Gate-0 Spike) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an eval harness for the extraction pipeline, fix the P0 precision bugs, add cheap recall multipliers, fix summary quality, and run the Gate-0 embedding spike — per spec `docs/superpowers/specs/2026-06-13-tag-suggestion-design.md`.

**Architecture:** Measure-first: Tasks 1–2 build a labeled eval set + metrics runner with committed regression floors; every later task re-runs it. Tasks 3–8 are P0 precision fixes (dead fallback, tense, common-word guards, highlight scoring, topics pipeline). Tasks 9–12 are recall multipliers (cue cache, lemmatization, lexicon activities, fuzzy meds). Task 13 fixes summary/title. Task 15 is the Gate-0 spike that decides Phase D.

**Tech Stack:** Swift 6, Swift Testing (`import Testing`, `@Test`, `#expect`), SwiftData, NaturalLanguage framework. No new dependencies.

**Conventions (read once, apply everywhere):**
- Branch: `feat/nlp-eval-and-precision` off `main`.
- Module for `@testable import` is `app_two` (underscore). Scheme `app-two`, test target `app-twoTests`.
- New files need NO pbxproj edits (synchronized folder groups, both targets).
- The project default actor isolation is `MainActor` — every new extraction-layer type must be declared `nonisolated` (match `NLNoteExtractor`).
- Test command (full suite):
```bash
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 xcodebuild test \
  -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' \
  -resultBundlePath /tmp/t.xcresult -disableAutomaticPackageResolution
```
Single suite: append `-only-testing 'app-twoTests/<SuiteName>'`. Read results: `xcrun xcresulttool get test-results summary --path /tmp/t.xcresult`. Use a fresh `-resultBundlePath` per run (`/tmp/t2.xcresult`, …) — xcodebuild refuses to overwrite. `print()` does NOT reach the result bundle; metrics are surfaced via `Issue.record` (Task 2).
- `lexicon.json` edits: `moodSpecific` is intentionally IDENTICAL in `app-two/Resources/lexicon.json` and `Lexicon.defaultMoodSpecific` (Lexicon.swift) — edit BOTH. Other categories: JSON is a superset; edit JSON, and code defaults only where the entry exists there too.

---

### Task 1: Eval metrics engine

**Files:**
- Create: `app-twoTests/Eval/EvalMetrics.swift`
- Test: `app-twoTests/Eval/EvalMetricsTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// app-twoTests/Eval/EvalMetricsTests.swift
import Testing
@testable import app_two

struct EvalMetricsTests {

    @Test func setCountsBasic() {
        let c = EvalCounts(expected: ["a", "b"], actual: ["b", "c"])
        #expect(c.tp == 1)   // b
        #expect(c.fp == 1)   // c
        #expect(c.fn == 1)   // a
    }

    @Test func scalarCounts() {
        #expect(EvalCounts(expectedScalar: "low", actualScalar: "low") == EvalCounts(tp: 1, fp: 0, fn: 0))
        #expect(EvalCounts(expectedScalar: "low", actualScalar: "flat") == EvalCounts(tp: 0, fp: 1, fn: 1))
        #expect(EvalCounts(expectedScalar: nil, actualScalar: "low") == EvalCounts(tp: 0, fp: 1, fn: 0))
        #expect(EvalCounts(expectedScalar: "low", actualScalar: nil) == EvalCounts(tp: 0, fp: 0, fn: 1))
        #expect(EvalCounts(expectedScalar: nil, actualScalar: nil) == EvalCounts(tp: 0, fp: 0, fn: 0))
    }

    @Test func precisionRecallAggregation() {
        var agg = EvalCounts(tp: 0, fp: 0, fn: 0)
        agg.add(EvalCounts(tp: 3, fp: 1, fn: 0))
        agg.add(EvalCounts(tp: 1, fp: 0, fn: 2))
        #expect(agg.precision == 0.8)          // 4 / (4+1)
        #expect(agg.recall == (4.0 / 6.0))     // 4 / (4+2)
    }

    @Test func emptyDenominatorsAreOne() {
        let c = EvalCounts(tp: 0, fp: 0, fn: 0)
        #expect(c.precision == 1.0)
        #expect(c.recall == 1.0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: full suite command + `-only-testing 'app-twoTests/EvalMetricsTests'`
Expected: BUILD FAILS — `cannot find 'EvalCounts' in scope`.

- [ ] **Step 3: Implement**

```swift
// app-twoTests/Eval/EvalMetrics.swift
import Foundation

/// Micro-averaged precision/recall counts for one tag category.
struct EvalCounts: Equatable {
    var tp: Int
    var fp: Int
    var fn: Int

    init(tp: Int, fp: Int, fn: Int) {
        self.tp = tp; self.fp = fp; self.fn = fn
    }

    /// Set-valued categories (feelings, activities, meds, topics).
    init(expected: Set<String>, actual: Set<String>) {
        tp = expected.intersection(actual).count
        fp = actual.subtracting(expected).count
        fn = expected.subtracting(actual).count
    }

    /// Scalar categories (mood, energy, focus, sleepHours-as-string).
    /// Wrong non-nil value counts as both a false positive and a false negative.
    init(expectedScalar: String?, actualScalar: String?) {
        switch (expectedScalar, actualScalar) {
        case (nil, nil):                  self.init(tp: 0, fp: 0, fn: 0)
        case (nil, .some):                self.init(tp: 0, fp: 1, fn: 0)
        case (.some, nil):                self.init(tp: 0, fp: 0, fn: 1)
        case let (.some(e), .some(a)):
            self.init(tp: e == a ? 1 : 0, fp: e == a ? 0 : 1, fn: e == a ? 0 : 1)
        }
    }

    mutating func add(_ other: EvalCounts) {
        tp += other.tp; fp += other.fp; fn += other.fn
    }

    var precision: Double { tp + fp == 0 ? 1.0 : Double(tp) / Double(tp + fp) }
    var recall: Double    { tp + fn == 0 ? 1.0 : Double(tp) / Double(tp + fn) }
}
```

- [ ] **Step 4: Run to verify pass**

Same command. Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app-twoTests/Eval/
git commit -m "test(eval): precision/recall counting engine for extraction eval"
```

---

### Task 2: Eval set + runner + baseline floors

**Files:**
- Create: `app-twoTests/Eval/EvalSet.swift`
- Create: `app-twoTests/Eval/ExtractionEvalTests.swift`

**Design notes:** Cases are Swift source, not a JSON fixture — the test target has never carried resources and Swift literals are type-checked. Expected labels are TRUTH (what *should* be extracted), so PT/ES recall correctly reads ≈0 at baseline. Labels are canonical English IDs in every language (chips key off these IDs). Topic truth uses `TopicCategory` rawValues (Capitalized) — recall is 0 until Task 8 lands; that is the point of a baseline.

- [ ] **Step 1: Create the case schema + 10 exemplar cases**

```swift
// app-twoTests/Eval/EvalSet.swift
import Foundation
@testable import app_two

struct EvalCase {
    let id: String
    let language: String          // "en" | "pt" | "es"
    let transcript: String
    var mood: String? = nil
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var feelings: Set<String> = []
    var activities: Set<String> = []
    var medNames: Set<String> = []
    var sleepHours: Double? = nil
    var topics: Set<String> = []          // TopicCategory rawValues
    var anySideEffect: Bool = false
}

enum EvalSet {
    static let cases: [EvalCase] = [
        // ── EN: multi-signal med day ──
        EvalCase(
            id: "en-med-day", language: "en",
            transcript: "Took my Concerta 36mg at 8am with breakfast. It kicked in after about 45 minutes and I was firing on all cylinders until lunch. Crashed hard around 3pm, dry mouth all afternoon. Still managed to finish the report, proud of that.",
            mood: "great",                       // "proud" → great via moodSpecific? No — "proud" is a winCue; "accomplished" absent. TRUTH: no explicit mood word → but "proud of that" expresses good mood. Truth: "good".
            energy: .charged, feelings: ["proud"], medNames: ["Concerta"],
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── EN: paraphrase energy (current pipeline SHOULD miss — recall gap doc) ──
        EvalCase(
            id: "en-paraphrase-energy", language: "en",
            transcript: "Honestly today my body just would not get going, like wading through wet sand from the moment I woke up. Could not get off the couch until noon.",
            energy: .sluggish
        ),
        // ── EN: neutral filler — NOTHING should fire ──
        EvalCase(
            id: "en-neutral", language: "en",
            transcript: "I went to the store and bought milk. The meeting is at three tomorrow. Nothing much happened today."
        ),
        // ── EN: common-word traps (Task 5 targets) ──
        EvalCase(
            id: "en-traps", language: "en",
            transcript: "The fridge was empty so I ordered groceries. My gym bag felt heavy. I've seen my therapist this morning and we talked about raw vegetables.",
            activities: ["Eating"], topics: ["Appointments"]
        ),
        // ── EN: past-progressive mood (Task 4 target) ──
        EvalCase(
            id: "en-past-progressive", language: "en",
            transcript: "I was feeling really anxious on Monday. Today I'm actually calm and got my inbox to zero.",
            mood: "good", feelings: ["anxious"]
        ),
        // ── EN: sleep + side effects ──
        EvalCase(
            id: "en-sleep", language: "en",
            transcript: "Slept maybe 5 hours, tossed and turned all night. Skipped my Vyvanse because my heart was racing yesterday. Felt foggy and irritable the whole morning.",
            mood: "low", focus: .foggy, medNames: ["Vyvanse"], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── EN: inflection recall (Task 10 target) ──
        EvalCase(
            id: "en-inflection", language: "en",
            transcript: "I'm panicking about the deadline and I keep avoiding the email thread. Spent the evening doomscrolling instead.",
            feelings: ["panicked"], activities: ["Screen Time"]
        ),
        // ── EN: activities beyond the original six (Task 11 target) ──
        EvalCase(
            id: "en-activities", language: "en",
            transcript: "Folded the laundry, did the dishes, then went for a long walk in the park to clear my head. Read a few chapters before bed.",
            activities: ["Chores", "Outdoors", "Hobbies"]
        ),
        // ── PT: truth labels, zero expected recall today except med/dose ──
        EvalCase(
            id: "pt-med-day", language: "pt",
            transcript: "Tomei o Concerta de 36mg às 8 da manhã. Dormi só 5 horas e passei o dia todo ansioso, sem conseguir começar nada. Boca seca a tarde inteira.",
            mood: "low", feelings: ["anxious"], medNames: ["Concerta"], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── ES: truth labels, zero expected recall today except med/dose ──
        EvalCase(
            id: "es-med-day", language: "es",
            transcript: "Hoy no tomé el Vyvanse y estuve agotado toda la tarde, sin poder concentrarme. Cené temprano y caminé un rato por el parque.",
            energy: .sluggish, focus: .distracted, medNames: ["Vyvanse"],
            activities: ["Outdoors", "Eating"], topics: ["Medications"]
        ),
    ]
}
```

Fix the `en-med-day` mood inline while writing: set `mood: "good"` (the inline comment above documents why — there is no `great`-mapped word in the transcript; "proud of that" reads as good). Delete the comment chain, keep `mood: "good"`.

- [ ] **Step 2: Extend to 40 cases following the exemplars**

Author 30 more cases in the same file matching this distribution. Every case must have truth labels chosen by reading the transcript against the canonical vocabularies (`MoodLevel`: low/flat/okay/good/great; `EnergyLevel`; `FocusLevel`; feelings = lexicon feelings entries; activities = the Task-11 category names; topics = TopicCategory rawValues):
- 8 EN mood/feelings-centric (mix of exact lexicon words, paraphrases the current pipeline misses, and 2 with NO mood at all)
- 5 EN medication-centric (doses, skips, changes, one ASR typo case: "Conserta" — truth `medNames: ["Concerta"]`, Task 12 target)
- 4 EN sleep-centric (hours phrasing variants, one "worked 12 hours" trap with NO sleepHours truth)
- 4 EN executive-dysfunction / overwhelm / win register
- 3 EN neutral/no-signal (errands, weather, logistics — all-empty truth)
- 3 PT + 3 ES covering mood/meds/sleep/activities (truth in canonical IDs)

Rules: no two cases share a transcript skeleton; transcripts are spoken-register (fillers, run-ons welcome); every lexicon trap word used appears in at least one negative context.

- [ ] **Step 3: Write the runner + floors + report**

```swift
// app-twoTests/Eval/ExtractionEvalTests.swift
import Testing
import Foundation
@testable import app_two

/// Regression floors. Raise (never lower) as tasks land. Baseline captured in Task 2 Step 5.
enum EvalFloors {
    static let mood            = (precision: 0.0, recall: 0.0)
    static let energy          = (precision: 0.0, recall: 0.0)
    static let focus           = (precision: 0.0, recall: 0.0)
    static let feelings        = (precision: 0.0, recall: 0.0)
    static let activities      = (precision: 0.0, recall: 0.0)
    static let meds            = (precision: 0.0, recall: 0.0)
    static let sleepHours      = (precision: 0.0, recall: 0.0)
    static let topics          = (precision: 0.0, recall: 0.0)
    static let sideEffectFlag  = (precision: 0.0, recall: 0.0)
}

struct ExtractionEvalTests {

    struct CategoryResult {
        let name: String
        var counts = EvalCounts(tp: 0, fp: 0, fn: 0)
        let floor: (precision: Double, recall: Double)
    }

    static func runEval() -> [CategoryResult] {
        let extractor = NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay: nil))
        var mood = CategoryResult(name: "mood", floor: EvalFloors.mood)
        var energy = CategoryResult(name: "energy", floor: EvalFloors.energy)
        var focus = CategoryResult(name: "focus", floor: EvalFloors.focus)
        var feelings = CategoryResult(name: "feelings", floor: EvalFloors.feelings)
        var activities = CategoryResult(name: "activities", floor: EvalFloors.activities)
        var meds = CategoryResult(name: "meds", floor: EvalFloors.meds)
        var sleep = CategoryResult(name: "sleepHours", floor: EvalFloors.sleepHours)
        var sideFx = CategoryResult(name: "sideEffectFlag", floor: EvalFloors.sideEffectFlag)

        for c in EvalSet.cases {
            let r = extractor.extract(from: c.transcript)
            mood.counts.add(.init(expectedScalar: c.mood, actualScalar: r.mood))
            energy.counts.add(.init(expectedScalar: c.energy?.rawValue, actualScalar: r.energy?.rawValue))
            focus.counts.add(.init(expectedScalar: c.focus?.rawValue, actualScalar: r.focus?.rawValue))
            feelings.counts.add(.init(expected: c.feelings, actual: Set(r.feelings)))
            activities.counts.add(.init(expected: c.activities, actual: Set(r.activities)))
            meds.counts.add(.init(expected: c.medNames, actual: Set(r.medications.map(\.name))))
            sleep.counts.add(.init(expectedScalar: c.sleepHours.map { String($0) },
                                   actualScalar: r.sleepHours.map { String($0) }))
            let actualSideFx = !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty)
            sideFx.counts.add(.init(expectedScalar: c.anySideEffect ? "yes" : nil,
                                    actualScalar: actualSideFx ? "yes" : nil))
        }
        return [mood, energy, focus, feelings, activities, meds, sleep, sideFx]
    }

    @Test func metricsMeetFloors() {
        for cat in Self.runEval() {
            #expect(cat.counts.precision >= cat.floor.precision,
                    "\(cat.name) precision \(cat.counts.precision) below floor \(cat.floor.precision)")
            #expect(cat.counts.recall >= cat.floor.recall,
                    "\(cat.name) recall \(cat.counts.recall) below floor \(cat.floor.recall)")
        }
    }

    /// Manual metrics dump: run with EVAL_REPORT=1 in the scheme/CLI env.
    /// Records one Issue containing the full table — read it from the xcresult.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EVAL_REPORT"] == "1"))
    func report() {
        let lines = Self.runEval().map { c in
            let p = String(format: "%.3f", c.counts.precision)
            let r = String(format: "%.3f", c.counts.recall)
            return "\(c.name): P=\(p) R=\(r) (tp\(c.counts.tp) fp\(c.counts.fp) fn\(c.counts.fn))"
        }
        Issue.record(Comment(rawValue: "EVAL REPORT\n" + lines.joined(separator: "\n")))
    }
}
```

Note: topics are NOT in the runner yet — `NoteExtraction` has no topics until Task 8, which adds the category here. The `topics` truth field already exists in cases.

- [ ] **Step 4: Run floors test (passes — floors are 0)**

Run with `-only-testing 'app-twoTests/ExtractionEvalTests'`. Expected: `metricsMeetFloors` PASS, `report` SKIPPED.

- [ ] **Step 5: Capture baseline + set floors**

Run:
```bash
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 EVAL_REPORT=1 xcodebuild test \
  -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' \
  -only-testing 'app-twoTests/ExtractionEvalTests' \
  -resultBundlePath /tmp/eval-baseline.xcresult -disableAutomaticPackageResolution
```
Expected: `report` FAILS deliberately with the metrics table. Read it:
```bash
xcrun xcresulttool get test-results tests --path /tmp/eval-baseline.xcresult | grep -A2 'EVAL REPORT'
```
Set every `EvalFloors` entry to the observed value **minus 0.02** (slack for sim variance). Record the raw table in a new section `## Baseline 2026-06-13` appended to `docs/superpowers/specs/2026-06-13-tag-suggestion-design.md` under §7.

- [ ] **Step 6: Re-run floors test → PASS. Commit**

```bash
git add app-twoTests/Eval/ docs/superpowers/specs/2026-06-13-tag-suggestion-design.md
git commit -m "test(eval): 40-case labeled eval set, P/R runner, committed baseline floors"
```

---

### Task 3: Delete the dead NLEmbedding fallback

**Files:**
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (lines 27–31, 80, 88, 103, 110, 382–437)
- Test: `app-twoTests/Services/NLNoteExtractorMatchingTests.swift`

**Why:** gate `d < 0.55` can essentially never pass (measured synonym distances 0.82–1.33), so the fallback adds ~zero recall while costing `words × ~186` distance calls per non-matching sentence.

- [ ] **Step 1: Add a pinning test (documents current truth, passes before AND after)**

```swift
// Append to NLNoteExtractorMatchingTests.swift
@Test func paraphraseEnergyYieldsNilWithoutLexiconHit() {
    // "wading through wet sand" is not in energySluggish; the dead embedding
    // fallback never rescued it (gate 0.55 vs real distances 0.82+). Pins the
    // honest behavior so Phase D has a baseline to beat.
    let result = extractor.extract(from: "My body was wading through wet sand all morning.")
    #expect(result.energy == nil)
}
```

Run `-only-testing 'app-twoTests/NLNoteExtractorMatchingTests'`. Expected: PASS already.

- [ ] **Step 2: Delete the fallback**

In `NLNoteExtractor.swift`:
1. Delete the `englishEmbedding` static (lines 27–31) and `let embedding = Self.englishEmbedding` (line 80).
2. Delete `let words = lower.split(separator: " ").map(String.init)` (line 88) — only the fallback used it.
3. Change signatures and calls: `nearestEnergy(_:words:tokens:embedding:)` → `nearestEnergy(tokens:)`, same for `nearestFocus`; update the two call sites.
4. Replace `nearestCategoryHybrid` with exact-only matching, longest-phrase-wins, and drop `distance`:

```swift
private struct CategoryMatch<T> {
    let level: T
    let phrase: String
}

private func nearestCategory<T>(tokens: [String], candidates: [([String], T)]) -> CategoryMatch<T>? {
    var best: CategoryMatch<T>?
    for (seedWords, value) in candidates {
        for seed in seedWords where containsCue(seed, in: tokens) {
            if best == nil || seed.count > best!.phrase.count {
                best = CategoryMatch(level: value, phrase: seed)
            }
        }
    }
    return best
}
```

5. Selection policy: `energyCandidates`/`focusCandidates` lose `distance`. Longest matched phrase across sentences wins (a longer lexicon phrase is a more specific signal):

```swift
var energyCandidates: [(level: EnergyLevel, phraseLength: Int)] = []
// in loop: energyCandidates.append((effectiveEnergy, energyMatch.phrase.count))
// after loop:
if let bestEnergy = energyCandidates.max(by: { $0.phraseLength < $1.phraseLength }) {
    extraction.energy = bestEnergy.level
}
```
Same for focus. Update the policy comment: "strongest match = longest exact lexicon phrase".

- [ ] **Step 3: Full suite**

Run full suite. Expected: ALL PASS (the fallback contributed nothing the suite could see).

- [ ] **Step 4: Eval check + commit**

Run `ExtractionEvalTests` — floors hold. Commit:
```bash
git add app-two/Services/NoteExtraction/NLNoteExtractor.swift app-twoTests/Services/NLNoteExtractorMatchingTests.swift
git commit -m "fix(nlp): remove dead NLEmbedding energy/focus fallback; longest-exact-match wins"
```

---

### Task 4: Tense — past-progressive bug

**Files:**
- Modify: `app-two/Services/NoteExtraction/TenseClassifier.swift` (presentMarkers/pastMarkers)
- Test: `app-twoTests/Services/NLNoteExtractorTenseTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorTenseTests.swift
@Test func pastProgressiveIsPast() {
    #expect(TenseClassifier().tense(of: "I was feeling really anxious") == .past)
}

@Test func presentPerfectProgressiveIsPresent() {
    #expect(TenseClassifier().tense(of: "I've been feeling great lately") == .present)
}

@Test func presentMoodBeatsPastProgressiveMood() {
    let r = NLNoteExtractor().extract(from: "I was feeling really anxious on Monday. Today I am calm.")
    #expect(r.mood == "good")   // calm → good; past anxious must not win the headline
}
```

Run `-only-testing 'app-twoTests/NLNoteExtractorTenseTests'`. Expected: first and third FAIL (bare `"feeling"` marker makes past-progressive read as present).

- [ ] **Step 2: Fix the marker lists**

In `TenseClassifier.swift`:
- `presentMarkers`: REMOVE `"feeling"`; ADD `"i've been feeling"`, `"i have been feeling"`. (Bare "feeling …" openers fall through to `verbTense` → `.neutral`, weight 0.5 — still beats past.)
- `pastMarkers`: ADD `"was feeling"`, `"were feeling"`.

- [ ] **Step 3: Run tense suite → all PASS (including the existing 6). Then full suite → PASS.**

- [ ] **Step 4: Eval + commit**

```bash
git add app-two/Services/NoteExtraction/TenseClassifier.swift app-twoTests/Services/NLNoteExtractorTenseTests.swift
git commit -m "fix(nlp): past-progressive mood no longer classified present"
```

---

### Task 5: Common-word lexicon guards + longest-match mood

**Files:**
- Modify: `app-two/Resources/lexicon.json`
- Modify: `app-two/Services/NoteExtraction/Lexicon.swift` (defaultMoodSpecific, defaultFeelings, defaultEnergySluggish, defaultFocusFoggy — apply the same edits where the entry exists)
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (`nearestMood`)
- Test: `app-twoTests/Services/NLNoteExtractorMoodTests.swift`, `app-twoTests/Services/NLNoteExtractorMatchingTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorMoodTests.swift
@Test func nothingAsPronounDoesNotSetMood() {
    #expect(extractor.extract(from: "Nothing much happened today.").mood == nil)
}
@Test func feelNothingSetsFlat() {
    #expect(extractor.extract(from: "I feel nothing today.").mood == "flat")
}
@Test func emptyObjectDoesNotSetMood() {
    #expect(extractor.extract(from: "The fridge was empty so I ordered groceries.").mood == nil)
}
@Test func feelEmptySetsFlat() {
    #expect(extractor.extract(from: "Honestly I just feel empty.").mood == "flat")
}
@Test func heavyObjectDoesNotSetMood() {
    #expect(extractor.extract(from: "My gym bag felt heavy.").mood == nil)
}
@Test func longestMoodPhraseWins() {
    // "not bad" (okay) must beat its substring-overlapping "bad"-class neighbors
    // regardless of array order once longest-match-wins lands.
    #expect(extractor.extract(from: "Today was not bad at all.").mood == "okay")
}

// Append to NLNoteExtractorMatchingTests.swift
@Test func sawTherapistIsNotFeelingSeen() {
    let r = extractor.extract(from: "I've seen my therapist this morning.")
    #expect(!r.feelings.contains("seen"))
}
@Test func feelingSeenDetected() {
    let r = extractor.extract(from: "She really listened and I left feeling seen.")
    #expect(r.feelings.contains("feeling seen"))
}
@Test func lostKeysIsNotFoggyFocus() {
    #expect(extractor.extract(from: "I lost my keys again this morning.").focus == nil)
}
@Test func spentMoneyIsNotSluggishEnergy() {
    #expect(extractor.extract(from: "I spent the morning at the bank.").energy == nil)
}
```

Run both suites. Expected: the negative tests FAIL (current bare entries fire).

- [ ] **Step 2: Edit the vocabularies (JSON + matching code defaults)**

`moodSpecific` (edit in BOTH lexicon.json and `Lexicon.defaultMoodSpecific`, keeping identical order):
- DELETE: `heavy → low`, `empty → flat`, `nothing → flat`
- ADD (at the end of the array): `feel empty → flat`, `feeling empty → flat`, `felt empty → flat`, `feel nothing → flat`, `feeling nothing → flat`, `felt nothing → flat`, `feel heavy → low`, `feeling heavy → low`

`feelings` (lexicon.json; also remove `seen`/`light`/`alive` from `defaultFeelings` in code — `raw` is JSON-only):
- DELETE: `seen`, `light`, `raw`, `alive`
- ADD: `feeling seen`, `feel seen`, `feeling light`, `feel light`, `feeling raw`, `feel raw`, `feeling alive`, `feel alive`

`energySluggish` (lexicon.json; mirror any of these that exist in `defaultEnergySluggish`):
- DELETE: `heavy`, `empty`, `spent`, `slow`
- ADD: `feel heavy`, `feeling heavy`, `felt heavy`, `feel empty of energy`, `totally spent`, `feel spent`, `felt spent`, `feeling slow`, `feel slow`

`focusFoggy` (lexicon.json; mirror in `defaultFocusFoggy` where present):
- DELETE: `lost`, `blank`, `scattered`, `chaos`
- ADD: `feel lost`, `feeling lost`, `went blank`, `drawing a blank`, `feel scattered`, `feeling scattered`, `felt scattered`, `so scattered`

- [ ] **Step 3: Make `nearestMood` longest-match-wins (kills order dependence)**

```swift
private func nearestMood(tokens: [String]) -> MoodMatch? {
    // Longest matching phrase wins: more words = more specific signal
    // ("feel nothing" beats "nothing"-class single words; "not bad" beats "bad").
    // Replaces first-match-in-array-order, which made vocabulary order load-bearing.
    var best: MoodMatch?
    for (word, label) in lexicon.moodSpecific where containsCue(word, in: tokens) {
        if best == nil || word.count > best!.matchedPhrase.count {
            best = MoodMatch(label: label, matchedPhrase: word)
        }
    }
    return best
}
```
Also update the order-matters comment block in `Lexicon.swift` (lines ~174–177): order is no longer load-bearing for mood; keep entries grouped by label for readability.

- [ ] **Step 4: Full suite.** Expected: new tests PASS; if any existing mood test depended on a deleted bare entry (e.g. asserts on "empty"), update that test to use the feel-context phrase and note it in the commit body.

- [ ] **Step 5: Eval — precision must rise**

Run with `EVAL_REPORT=1`; mood/feelings/energy/focus precision should improve vs baseline. Raise those floors to observed −0.02. Recall must not drop below floors; if it does, STOP and report (spec §6 risk: guard-rules cutting real recall).

- [ ] **Step 6: Commit**

```bash
git add app-two/Resources/lexicon.json app-two/Services/NoteExtraction/Lexicon.swift \
        app-two/Services/NoteExtraction/NLNoteExtractor.swift app-twoTests/
git commit -m "fix(nlp): guard common-word lexicon entries; longest-match mood selection"
```

---

### Task 6: Highlight scoring — remove sentiment bias, tokenized matching

**Files:**
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (`extractHighlights`, delete `sentimentScore`)
- Create: `app-twoTests/Services/NLNoteExtractorHighlightTests.swift`

**Why:** `abs(sentiment)×2` gives cue-free filler ~1.2–1.6 (NLTagger's negativity bias on neutral text) + 1.0 length bonus = over the 1.5 threshold. And the scorer still uses `lower.contains` substring matching the cue matcher already abandoned.

- [ ] **Step 1: Failing tests (first-ever highlight coverage)**

```swift
// app-twoTests/Services/NLNoteExtractorHighlightTests.swift
import Testing
@testable import app_two

struct NLNoteExtractorHighlightTests {

    let extractor = NLNoteExtractor()

    @Test func fillerSentenceIsNotAHighlight() {
        let r = extractor.extract(from:
            "I went to the store and bought some milk for the week. Took my Concerta 36mg at 8am and it kicked in fast.")
        #expect(!r.highlights.contains("I went to the store and bought some milk for the week."))
        #expect(r.highlights.contains { $0.contains("Concerta") })
    }

    @Test func substringDoesNotInflateScore() {
        // "window"⊃"win": with one real cue sentence present, the window sentence
        // must not be selected on a phantom win-cue boost.
        let r = extractor.extract(from:
            "I stared out the window at the rain for a while this morning. Finally finished the tax return, nailed it.")
        #expect(!r.highlights.contains { $0.contains("window") })
        #expect(r.highlights.contains { $0.contains("nailed it") })
    }

    @Test func cueFreeTranscriptYieldsAtMostOneHighlight() {
        let r = extractor.extract(from:
            "The meeting moved to Thursday. I need to renew my passport before July. The car is due for a service soon.")
        #expect(r.highlights.count <= 1)
    }
}
```

Run `-only-testing 'app-twoTests/NLNoteExtractorHighlightTests'`. Expected: first two FAIL.

- [ ] **Step 2: Rewrite `extractHighlights`; delete `sentimentScore`**

```swift
private func extractHighlights(from sentences: [String]) -> [String] {
    guard !sentences.isEmpty else { return [] }

    var scored: [(sentence: String, score: Double)] = []
    for sentence in sentences {
        var score = 0.0
        let tokens = tokenize(sentence)

        // No sentiment term: NLTagger's paragraph sentiment is negatively biased
        // on neutral factual text (≈ -0.6), so abs() rewarded filler. Cue
        // presence is the salience signal; sentiment added noise, not signal.
        func hasAny(_ cues: [String]) -> Bool {
            cues.contains { containsCue($0, in: tokens) }
        }

        if hasAny(lexicon.medications.map { $0.lowercased() }) { score += 3.0 }
        if lexicon.timeOfDayKeywords.contains(where: { containsCue($0.0, in: tokens) }) { score += 1.0 }
        if hasAny(lexicon.taskCompletionCues) || hasAny(lexicon.taskAvoidanceCues) { score += 2.0 }
        if hasAny(lexicon.winCues) { score += 2.5 }
        if hasAny(lexicon.energyCharged) || hasAny(lexicon.energyAlert)
            || hasAny(lexicon.energyTired) || hasAny(lexicon.energySluggish) { score += 1.5 }
        if hasAny(lexicon.focusLockedIn) || hasAny(lexicon.focusSharp) || hasAny(lexicon.focusPresent)
            || hasAny(lexicon.focusDistracted) || hasAny(lexicon.focusFoggy) { score += 1.5 }
        if lexicon.moodSpecific.contains(where: { containsCue($0.word, in: tokens) })
            || hasAny(lexicon.feelings) { score += 1.5 }
        if hasAny(lexicon.sideEffectCues) || hasAny(lexicon.physicalSideEffects) { score += 2.0 }
        if hasAny(lexicon.reboundTerms) { score += 2.5 }
        if hasAny(lexicon.appetiteLoss) || hasAny(lexicon.appetiteReturn) { score += 1.5 }
        if hasAny(lexicon.executiveDysfunction) { score += 2.0 }

        let len = sentence.count
        if len >= 40 && len <= 200 { score += 1.0 } else if len < 20 { score -= 1.0 }

        scored.append((sentence, score))
    }

    // Threshold now means "at least one weak cue beyond the length bonus".
    let threshold = 1.5
    let qualified = scored.enumerated().filter { $0.element.score >= threshold }

    let topIndices: [Int]
    if qualified.isEmpty {
        topIndices = scored.enumerated()
            .max(by: { $0.element.score < $1.element.score })
            .map { [$0.offset] } ?? []
    } else {
        let topN = min(5, max(1, sentences.count / 4 + 1))
        let sorted = qualified.sorted { $0.element.score > $1.element.score }
        topIndices = sorted.prefix(topN).map { $0.offset }.sorted()
    }
    return topIndices.map { sentences[$0] }
}
```
Delete `sentimentScore(for:)` (lines 293–299) and the `// MARK: - Sentiment` section — `extractHighlights` was its only caller. (Med names: `containsCue` tokenizes its argument, so multi-word brands like "Concerta XL" match as token runs.)

- [ ] **Step 3: Run highlight suite → PASS. Full suite → PASS.**

- [ ] **Step 4: Eval + commit**

```bash
git add app-two/Services/NoteExtraction/NLNoteExtractor.swift app-twoTests/Services/NLNoteExtractorHighlightTests.swift
git commit -m "fix(nlp): highlight scoring — drop biased sentiment term, boundary-aware cue matching"
```

---

### Task 7: Topics — wire into SummaryResult → topicTagsJSON

**Files:**
- Modify: `app-two/Services/NoteExtraction/LexiconData.swift` (+`appointmentCues`), `app-two/Services/NoteExtraction/Lexicon.swift` (+field/+default), `app-two/Resources/lexicon.json` (+key)
- Modify: `app-two/Services/NoteExtraction/NoteExtraction.swift` (+`appointments: [String]`)
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (cue table + field)
- Modify: `app-two/Services/Protocols.swift` (`SummaryResult` +`topics: [String]`)
- Modify: `app-two/Services/NLSummarizationService.swift` (derive topics)
- Modify: `app-two/Models/Recording.swift` (`applySummary` writes `topicTagsJSON`)
- Modify (construction sites): `app-two/ViewModels/ExtractionReviewViewModel.swift:85` and `:176`, `app-twoTests/Mocks/MockSummarizationService.swift:5`, `app-twoTests/ViewModels/ExtractionReviewViewModelTests.swift:28`, `app-twoTests/Models/RecordingApplySummaryTests.swift:21`
- Test: `app-twoTests/Models/RecordingApplySummaryTests.swift`, `app-twoTests/Services/NLSummarizationServiceTopicTests.swift` (new), `app-twoTests/Eval/ExtractionEvalTests.swift` (+topics category)

- [ ] **Step 1: Failing service test**

```swift
// app-twoTests/Services/NLSummarizationServiceTopicTests.swift
import Testing
@testable import app_two

struct NLSummarizationServiceTopicTests {

    @Test func medAndSideEffectTranscriptYieldsTopics() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "Took my Concerta 36mg this morning. Dry mouth all afternoon.")
        #expect(result.topics.contains("Medications"))
        #expect(result.topics.contains("Symptoms"))
        #expect(!result.topics.contains("Appointments"))
    }

    @Test func appointmentTranscriptYieldsAppointments() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "Saw my psychiatrist today, we have a follow-up appointment next month.")
        #expect(result.topics.contains("Appointments"))
    }

    @Test func neutralTranscriptYieldsNoTopics() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "I went to the store and bought milk.")
        #expect(result.topics.isEmpty)
    }
}
```

Expected: BUILD FAILS — `SummaryResult` has no `topics`.

- [ ] **Step 2: Add the appointment cue category**

1. `lexicon.json` — add key (decoder requires it; same commit):
```json
"appointmentCues": ["appointment", "appointments", "psychiatrist", "psychiatry", "therapist", "therapy session", "doctor", "gp", "dentist", "check-up", "checkup", "follow-up", "follow up", "prescription renewal", "refill appointment", "blood test", "bloodwork"]
```
2. `LexiconData.swift` — add `public var appointmentCues: [String]` (after `executiveDysfunction`) and pass through in `toLexicon`.
3. `Lexicon.swift` — add `public let appointmentCues: [String]`, init param `appointmentCues: [String]? = nil`, `self.appointmentCues = appointmentCues ?? Lexicon.defaultAppointmentCues`, and:
```swift
static let defaultAppointmentCues: [String] = [
    "appointment", "psychiatrist", "therapist", "doctor", "dentist",
    "check-up", "checkup", "follow-up", "follow up"
]
```
4. `NoteExtraction.swift` — add `public var appointments: [String]` with default `[]` (memberwise init + Codable follow the existing fields' pattern).
5. `NLNoteExtractor.swift` — add to the cue table in the sentence loop:
```swift
if nonNegatedCueMatch(lexicon.appointmentCues) { appointments.append(sentence) }
```
with `var appointments: [String] = []` above the loop and `extraction.appointments = Array(Set(appointments)).sorted()` after it.

- [ ] **Step 3: Add `topics` to SummaryResult and derive it**

`Protocols.swift` — add `let topics: [String]` after `feelings`.

`NLSummarizationService.summarize` — before the `return`, derive:
```swift
var topics: [String] = []
if !extraction.medications.isEmpty { topics.append(TopicCategory.medications.rawValue) }
if !extraction.sideEffects.isEmpty || !extraction.physicalSideEffects.isEmpty
    || !extraction.reboundTerms.isEmpty || !extraction.appetiteLoss.isEmpty {
    topics.append(TopicCategory.symptoms.rawValue)
}
if !extraction.appointments.isEmpty { topics.append(TopicCategory.appointments.rawValue) }
```
and pass `topics: topics,` (after `feelings:`) in the `SummaryResult(...)` call.

Update the other five construction sites:
- `ExtractionReviewViewModel.swift:85` (convenience init): `topics: recording.topicCategories.map(\.rawValue),`
- `ExtractionReviewViewModel.swift:176` (`confirm()`): `topics: originalResult.topics,`
- `MockSummarizationService.swift:5`: `topics: [],`
- `ExtractionReviewViewModelTests.swift:28` helper: `topics: [],`
- `RecordingApplySummaryTests.swift:21` helper: add parameter `topics: [String] = []` to the helper and pass it through.

- [ ] **Step 4: Write `topicTagsJSON` in `applySummary`**

`Recording.swift`, after the `feelingsJSON` block (before `summary = …`):
```swift
if !result.topics.isEmpty,
   let data = try? JSONEncoder().encode(result.topics),
   let json = String(data: data, encoding: .utf8) {
    topicTagsJSON = json
}
```

Append to `RecordingApplySummaryTests.swift`:
```swift
@Test func appliesTopicsToTopicTagsJSON() {
    let r = Recording(audioFileName: "t.m4a")
    r.applySummary(makeResult(topics: ["Medications", "Symptoms"]))
    #expect(r.topicCategories == [.medications, .symptoms])
}

@Test func emptyTopicsLeaveExistingJSONUntouched() {
    let r = Recording(audioFileName: "t.m4a")
    r.topicTagsJSON = "[\"General\"]"
    r.applySummary(makeResult())
    #expect(r.topicCategories == [.general])
}
```
(Match the file's existing `Recording` test-construction pattern if it differs — copy how the suite's other tests build a Recording.)

- [ ] **Step 5: Add topics to the eval runner**

In `ExtractionEvalTests.runEval()`: the runner works on `NoteExtraction`, so derive topics the same way the service does (extract the derivation into a shared helper `static func deriveTopics(from extraction: NoteExtraction) -> [String]` on `NLSummarizationService`, call it from both places):
```swift
var topicsCat = CategoryResult(name: "topics", floor: EvalFloors.topics)
// in loop:
topicsCat.counts.add(.init(expected: c.topics, actual: Set(NLSummarizationService.deriveTopics(from: r))))
```
Make `deriveTopics` a `static nonisolated` function on `NLSummarizationService`.

- [ ] **Step 6: Full suite → PASS. Eval with `EVAL_REPORT=1` — topics recall jumps from 0; set the topics floor to observed −0.02. Commit**

```bash
git add app-two/ app-twoTests/
git commit -m "feat(nlp): derive topic tags from extraction and persist topicTagsJSON

Fixes the mock-only topic chips: SummaryResult gains topics, applySummary
writes topicTagsJSON, appointments become a 12th cue category."
```

---

### Task 8: CueMatcher — pre-tokenized cue cache

**Files:**
- Create: `app-two/Services/NoteExtraction/CueMatcher.swift`
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (all `containsCue` call paths)
- Test: existing suites (behavior-preserving refactor) + `app-twoTests/Services/NLNoteExtractorMatchingTests.swift`

**Why:** `containsCue` re-tokenizes its cue argument on every call — ≈550 `NLTokenizer` allocations per sentence. Tokenize each cue once at extractor init.

- [ ] **Step 1: Pinning tests (pass before and after)**

```swift
// Append to NLNoteExtractorMatchingTests.swift
@Test func multiWordCueStillMatchesAcrossRefactor() {
    let r = extractor.extract(from: "Total task paralysis this afternoon, could not start the report.")
    #expect(!r.executiveDysfunction.isEmpty)
}
@Test func substringInsideWordStillRejected() {
    let r = extractor.extract(from: "The window was open all night.")   // "win" ⊄ tokens
    #expect(r.wins.isEmpty)
}
```
Run — PASS already.

- [ ] **Step 2: Implement CueMatcher**

```swift
// app-two/Services/NoteExtraction/CueMatcher.swift
import Foundation
import NaturalLanguage

/// Pre-tokenized cue lists: every cue's token sequence is computed once at init
/// instead of on every (sentence × cue) check. Pure value type, Sendable.
public nonisolated struct CueMatcher: Sendable {

    public struct CueList: Sendable {
        let cues: [(surface: String, tokens: [String])]
    }

    public static func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        let lower = text.lowercased()
        tokenizer.string = lower
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            tokens.append(String(lower[range]))
            return true
        }
        return tokens
    }

    public static func makeList(_ cues: [String]) -> CueList {
        CueList(cues: cues.map { ($0, tokenize($0)) })
    }

    /// First cue (by longest token form) whose tokens appear as a contiguous run.
    public static func longestMatch(in tokens: [String], list: CueList) -> String? {
        var best: String?
        for (surface, cueTokens) in list.cues where contains(tokens, cueTokens) {
            if best == nil || surface.count > best!.count { best = surface }
        }
        return best
    }

    public static func anyMatch(in tokens: [String], list: CueList) -> Bool {
        list.cues.contains { contains(tokens, $0.tokens) }
    }

    private static func contains(_ tokens: [String], _ cueTokens: [String]) -> Bool {
        guard !cueTokens.isEmpty else { return false }
        if cueTokens.count == 1 { return tokens.contains(cueTokens[0]) }
        guard tokens.count >= cueTokens.count else { return false }
        for start in 0...(tokens.count - cueTokens.count) {
            if Array(tokens[start..<(start + cueTokens.count)]) == cueTokens { return true }
        }
        return false
    }
}
```

- [ ] **Step 3: Adopt in NLNoteExtractor**

Add cached lists as `let` properties built in `init` from the lexicon — one per cue category used in the sentence loop and in `extractHighlights` (sideEffect, taskCompletion, taskAvoidance, win, overwhelm, executiveDysfunction, physicalStim, physicalSideEffects, rebound, appetiteLoss, appetiteReturn, appointment, feelings, moodSpecific surfaces, the 5 energy + 5 focus lists, medications, timeOfDay keywords). Replace `containsCue(x, in: tokens)` with `CueMatcher.anyMatch`/`longestMatch` against the cached lists; `tokenize(_:)` in the extractor delegates to `CueMatcher.tokenize`. Delete the now-unused private `containsCue`/`tokenize` bodies. The per-category loop becomes:

```swift
func nonNegatedCueMatch(_ list: CueMatcher.CueList) -> Bool {
    guard let cue = CueMatcher.longestMatch(in: tokens, list: list) else { return false }
    return !isNegatedBefore(target: cue, in: lower)
}
```
(`longestMatch` instead of first-match also makes negation check the most specific matched cue.)

- [ ] **Step 4: Full suite → PASS (refactor is behavior-preserving except longest-vs-first cue selection inside a category, which no test pins). Eval floors hold. Commit**

```bash
git add app-two/Services/NoteExtraction/ app-twoTests/
git commit -m "refactor(nlp): CueMatcher pre-tokenized cue cache; longest-cue negation targeting"
```

---

### Task 9: Lemma-augmented matching

**Files:**
- Modify: `app-two/Services/NoteExtraction/CueMatcher.swift`
- Test: `app-twoTests/Services/NLNoteExtractorMatchingTests.swift`

**Design:** verb-only lemma fallback, single-word cues only. Sentence tokens tagged VERB by `NLTagger(.lexicalClass)` get their lemma (`.lemma` scheme); a single-word cue matches if its surface OR its lemma equals the token's surface or lemma. Restricting to verbs covers the real wins (panicking→panicked, crashing→crashed, avoiding→avoided) while keeping noun noise out ("wires" ≠ feeling "wired").

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorMatchingTests.swift
@Test func inflectedVerbMatchesLexiconForm() {
    let r = extractor.extract(from: "I'm panicking about the deadline.")
    #expect(r.feelings.contains("panicked"))
}
@Test func inflectedAvoidanceMatches() {
    let r = extractor.extract(from: "I keep avoiding that email thread.")
    #expect(!r.tasksAvoided.isEmpty)   // pins existing "avoiding" + adds lemma safety net
}
@Test func nounDoesNotLemmaMatchVerbCue() {
    let r = extractor.extract(from: "There were wires everywhere in the office.")
    #expect(!r.feelings.contains("wired"))
}
```
Run — first FAILS ("panicking" ∉ lexicon), third must PASS before and after.

- [ ] **Step 2: Implement**

In `CueMatcher`:
1. New token model: `public struct Token: Sendable { let surface: String; let verbLemma: String? }`.
2. `tokenize` gains a variant `tokenizeWithLemmas(_ text: String) -> [Token]`: one `NLTagger(tagSchemes: [.lexicalClass, .lemma])` pass; for each word token, `verbLemma` = lowercased lemma when `lexicalClass == .verb` and the lemma differs from the surface, else nil.
3. Cue side: in `makeList`, for single-word cues also store `lemma` (run the same tagger on the cue; most cue words tag as verbs/adjectives — store the lemma unconditionally for single-word cues).
4. `contains` for single-word cues becomes: match if `tokens.contains { $0.surface == cue.surface || (cue.lemma != nil && $0.verbLemma == cue.lemma) }`. Multi-word cues stay surface-only.
5. `NLNoteExtractor` switches the per-sentence call to `tokenizeWithLemmas`; everywhere `[String]` tokens were passed, pass `[Token]` (update `nearestMood`/`nearestCategory` signatures; they read `.surface` for the existing behavior, and the lemma path lives inside `CueMatcher.contains`).

Performance note: this replaces the old per-sentence `NLTokenizer` with one `NLTagger` pass — net allocation count stays at one pass per sentence.

- [ ] **Step 3: Full suite → PASS. Eval: feelings/cue recall must rise; raise floors to observed −0.02. Watch the precision row — if any category's precision drops >0.03 vs Task 8's report, list the new false positives from the failing cases and tighten (e.g. exclude specific cue lemmas) before committing.**

- [ ] **Step 4: Commit**

```bash
git add app-two/Services/NoteExtraction/ app-twoTests/
git commit -m "feat(nlp): verb-lemma fallback in cue matching (panicking->panicked class)"
```

---

### Task 10: Activities → lexicon-as-data, expanded

**Files:**
- Modify: `app-two/Services/NoteExtraction/LexiconData.swift`, `Lexicon.swift`, `app-two/Resources/lexicon.json`
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (delete hardcoded `activityKeywords`)
- Test: `app-twoTests/Services/NLNoteExtractorMatchingTests.swift`, `app-twoTests/Services/LexiconDataTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorMatchingTests.swift
@Test func choresActivityDetected() {
    let r = extractor.extract(from: "Folded the laundry and did the dishes after dinner.")
    #expect(r.activities.contains("Chores"))
}
@Test func outdoorsActivityDetected() {
    let r = extractor.extract(from: "Went for a long walk in the park to clear my head.")
    #expect(r.activities.contains("Outdoors"))
}
@Test func screenTimeActivityDetected() {
    let r = extractor.extract(from: "Spent the whole evening doomscrolling on the couch.")
    #expect(r.activities.contains("Screen Time"))
}
```
Expected: FAIL (categories don't exist).

- [ ] **Step 2: Move + expand the vocabulary**

1. `LexiconData.swift` — nested type + field:
```swift
public struct ActivityEntry: Codable, Sendable {
    public let category: String
    public let keywords: [String]
}
public var activityKeywords: [ActivityEntry]
```
pass through in `toLexicon` as `[(String, [String])]`.
2. `Lexicon.swift` — `public let activityKeywords: [(category: String, keywords: [String])]`, init param + `defaultActivityKeywords` = the verbatim 6 categories currently hardcoded in `NLNoteExtractor.activityKeywords` (lines 14–21).
3. `lexicon.json` — add the 6 existing categories verbatim PLUS:
```json
{"category": "Work", "keywords": ["work", "meeting", "meetings", "deadline", "email", "emails", "office", "standup", "presentation", "shift"]},
{"category": "Chores", "keywords": ["laundry", "dishes", "cleaning", "tidying", "tidied", "vacuum", "vacuuming", "groceries", "grocery run"]},
{"category": "Errands", "keywords": ["errand", "errands", "post office", "bank", "pharmacy", "dry cleaner", "returns"]},
{"category": "Outdoors", "keywords": ["outside", "park", "nature", "fresh air", "hike", "hiking", "garden", "gardening", "walk in the park", "long walk"]},
{"category": "Screen Time", "keywords": ["scrolling", "doomscrolling", "netflix", "youtube", "tiktok", "instagram", "binge watched", "binged", "screen time"]}
```
4. `NLNoteExtractor.swift` — delete the `static let activityKeywords` property; the loop reads `lexicon.activityKeywords` and matches via a cached `CueMatcher.CueList` per category (built in init like the other lists).

Note: "walking"/"running" stay in Fitness (existing); "long walk"/"walk in the park" land in Outdoors — a sentence can legitimately yield both, and `activities` is already de-duplicated set semantics.

- [ ] **Step 3: Update `LexiconDataTests`** — the superset test pattern: assert JSON `activityKeywords` count ≥ code-default count, mirroring the file's existing assertions for other categories (copy its style).

- [ ] **Step 4: Full suite → PASS. Eval: activities recall rises; raise floor. Commit**

```bash
git add app-two/ app-twoTests/
git commit -m "feat(nlp): activities move to lexicon-as-data, 5 new categories"
```

---

### Task 11: Fuzzy medication matching (ASR errors)

**Files:**
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (`extractMedications`)
- Create helper inside `CueMatcher.swift`: `editDistanceAtMostOne`
- Test: `app-twoTests/Services/NLNoteExtractorMedicationTests.swift`

**Design (precision-first):** fuzzy fires ONLY when (a) no exact med hit exists in the sentence, (b) the sentence has med context (any of: dose regex hit, or a token in ["took","take","taking","taken","dose","skipped","forgot","missed","mg"]), (c) candidate token length ≥ 6, (d) Damerau-Levenshtein distance to a single-token med name == 1, (e) token is not in a stoplist `["concert", "concerts"]`. Matched events get the canonical name.

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorMedicationTests.swift
@Test func asrTypoMatchesCanonicalMed() {
    let r = extractor.extract(from: "Took my Conserta 36mg at 8 this morning.")
    #expect(r.medications.contains { $0.name == "Concerta" })
}
@Test func vyvanseTypoMatches() {
    let r = extractor.extract(from: "I skipped my Vyvance today.")
    #expect(r.medications.contains { $0.name == "Vyvanse" && $0.taken == false })
}
@Test func concertIsNotConcerta() {
    let r = extractor.extract(from: "I took my kids to a concert last night.")
    #expect(r.medications.isEmpty)
}
@Test func noMedContextNoFuzzyMatch() {
    let r = extractor.extract(from: "Conserta sounds like a furniture brand.")
    #expect(r.medications.isEmpty)
}
```
Expected: first two FAIL.

- [ ] **Step 2: Implement**

In `CueMatcher`:
```swift
/// True iff Damerau-Levenshtein distance (substitution/insertion/deletion/
/// adjacent transposition) between a and b is exactly 1.
public static func editDistanceIsOne(_ a: String, _ b: String) -> Bool {
    let x = Array(a), y = Array(b)
    if abs(x.count - y.count) > 1 { return false }
    if x == y { return false }
    if x.count == y.count {
        let diffs = zip(x, y).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
        if diffs.count == 1 { return true }
        if diffs.count == 2, diffs[1] == diffs[0] + 1,
           x[diffs[0]] == y[diffs[1]], x[diffs[1]] == y[diffs[0]] { return true }  // transposition
        return false
    }
    let (longer, shorter) = x.count > y.count ? (x, y) : (y, x)
    var i = 0, j = 0, skipped = false
    while i < longer.count && j < shorter.count {
        if longer[i] == shorter[j] { i += 1; j += 1 }
        else if skipped { return false }
        else { skipped = true; i += 1 }    // one insertion in the longer string
    }
    return true
}
```

In `extractMedications`, after the exact-hit collection (`hits`) and before `guard !hits.isEmpty`:
```swift
if hits.isEmpty {
    let medContextTokens: Set<String> = ["took", "take", "taking", "taken", "dose", "skipped", "forgot", "missed", "mg"]
    let stoplist: Set<String> = ["concert", "concerts"]
    let hasContext = ADHDRegexPatterns.extractDose(from: sentence) != nil
        || tokens.contains { medContextTokens.contains($0.surface) }
    if hasContext {
        let singleTokenMeds = lexicon.medications.filter { !$0.contains(" ") }
        for token in tokens where token.surface.count >= 6 && !stoplist.contains(token.surface) {
            if let canonical = singleTokenMeds.first(where: {
                CueMatcher.editDistanceIsOne(token.surface, $0.lowercased())
            }), let r = lower.range(of: token.surface) {
                hits.append((canonical, r))
            }
        }
    }
}
```
(`tokens` here are the Task-9 `Token` values; use `.surface`. Known trade-off, documented in the test: fuzzy never fires when ANY exact med hit exists in the sentence — a sentence naming Concerta correctly once and typo'd once yields one event.)

- [ ] **Step 3: Full suite → PASS. Eval: meds recall on the ASR-typo case flips; raise floor. Commit**

```bash
git add app-two/Services/NoteExtraction/ app-twoTests/
git commit -m "feat(nlp): fuzzy med matching for ASR typos (edit distance 1, context-gated)"
```

---

### Task 12: Summary dedup, coverage slots, title quality (Phase E)

**Files:**
- Modify: `app-two/Services/NoteExtraction/NLNoteExtractor.swift` (`extractHighlights` post-selection, `makeTitle`)
- Test: `app-twoTests/Services/NLNoteExtractorHighlightTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Append to NLNoteExtractorHighlightTests.swift
@Test func nearDuplicateSentencesDedupedInHighlights() {
    let r = extractor.extract(from:
        "Took my Concerta at 8 this morning. I took my Concerta at 8 in the morning. Slept badly, maybe 5 hours, woke up exhausted.")
    let concertaBullets = r.highlights.filter { $0.contains("Concerta") }
    #expect(concertaBullets.count == 1)
}

@Test func medSentenceAlwaysCoveredWhenPresent() {
    // Four high-scoring mood/win sentences + one med sentence: med must survive selection.
    let r = extractor.extract(from:
        "Finally finished the tax return, nailed it, feeling accomplished. Crushed the gym session and felt amazing afterwards. So proud of clearing my inbox, a real win for me. Feeling wonderful and energized and on top of the world. Also took my Ritalin at noon.")
    #expect(r.highlights.contains { $0.contains("Ritalin") })
}

@Test func titleStripsFillerAndCutsAtClause() {
    let r = extractor.extract(from:
        "So yeah I took my Concerta at eight and then the whole afternoon kind of fell apart honestly.")
    #expect(r.title == "I took my Concerta at eight")
}
```
Expected: FAIL (dup survives; title is "So yeah I took my Concerta").

- [ ] **Step 2: Implement dedup + coverage in `extractHighlights`**

After computing `topIndices` (both branches), replace `return topIndices.map { sentences[$0] }` with:

```swift
var selected = topIndices

// Dedup: drop a selected sentence whose token-set Jaccard overlap with an
// earlier-selected (higher-scored first) sentence exceeds 0.6.
let bySentenceTokens: [Int: Set<String>] = Dictionary(uniqueKeysWithValues:
    selected.map { ($0, Set(CueMatcher.tokenize(sentences[$0]))) })
let scoreOrdered = selected.sorted { scored[$0].score > scored[$1].score }
var kept: [Int] = []
for idx in scoreOrdered {
    let tokens = bySentenceTokens[idx] ?? []
    let isDup = kept.contains { other in
        let otherTokens = bySentenceTokens[other] ?? []
        let union = tokens.union(otherTokens).count
        guard union > 0 else { return false }
        return Double(tokens.intersection(otherTokens).count) / Double(union) > 0.6
    }
    if !isDup { kept.append(idx) }
}
selected = kept.sorted()

// Coverage: if any med sentence exists in the transcript but none survived,
// swap it in for the lowest-scored survivor (meds are the app's core signal).
let medList = medCueList   // the cached CueMatcher list from Task 8
let medIndices = sentences.indices.filter {
    CueMatcher.anyMatch(in: CueMatcher.tokenize(sentences[$0]), list: medList)
}
if let bestMed = medIndices.max(by: { scored[$0].score < scored[$1].score }),
   !selected.contains(where: { medIndices.contains($0) }) {
    if selected.count >= 5, let worst = selected.min(by: { scored[$0].score < scored[$1].score }) {
        selected.removeAll { $0 == worst }
    }
    selected.append(bestMed)
    selected.sort()
}

return selected.map { sentences[$0] }
```

- [ ] **Step 3: Implement title quality in `makeTitle`**

```swift
private static let titleFillers: Set<String> = [
    "so", "yeah", "um", "uh", "like", "okay", "ok", "well", "anyway", "right", "honestly", "basically"
]

private func makeTitle(from highlights: [String], fallback: String) -> String {
    let source = highlights.first ?? fallback
    // Cut at the first clause boundary, then strip leading spoken fillers.
    let clause = source
        .components(separatedBy: CharacterSet(charactersIn: ",;"))[0]
        .components(separatedBy: " and then ")[0]
        .components(separatedBy: " but ")[0]
    var words = clause.split(separator: " ").map(String.init)
    while let first = words.first,
          Self.titleFillers.contains(first.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
        words.removeFirst()
    }
    let title = words.prefix(8).joined(separator: " ")
        .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    guard !title.isEmpty else { return String(fallback.split(separator: " ").prefix(6).joined(separator: " ")) }
    return title.prefix(1).uppercased() + title.dropFirst()
}
```
Note "and then"/"but" as clause cuts but NOT bare "and" — "Concerta and coffee" must survive. If `medCueList` isn't accessible where `extractHighlights` lives, hoist the cached lists into a single `let cueLists: ...` struct property on the extractor (Task 8 likely already did).

- [ ] **Step 4: Full suite → PASS. Eval floors hold (highlights aren't scored by the eval, but mood/etc. must not move). Commit**

```bash
git add app-two/Services/NoteExtraction/ app-twoTests/
git commit -m "feat(nlp): highlight dedup + med coverage slot; clause-bounded filler-stripped titles"
```

---

### Task 13: Final eval re-baseline + backlog

**Files:**
- Modify: `app-twoTests/Eval/ExtractionEvalTests.swift` (floors)
- Modify: `docs/superpowers/specs/2026-06-13-tag-suggestion-design.md` (results table)
- Modify: `docs/BACKLOG.md`

- [ ] **Step 1:** Run full suite — green. Run eval with `EVAL_REPORT=1`; copy the final table into the spec under `## Results after Phases A–C+E (2026-06-13)` next to the baseline table. Raise every floor to final observed −0.02.
- [ ] **Step 2:** `docs/BACKLOG.md`: move "Tag suggestion engine" row to **🔨 In code** with branch `feat/nlp-eval-and-precision`, note "Phases A–C+E done, Gate-0 next, Phase D pending spike".
- [ ] **Step 3: Commit**

```bash
git add app-twoTests/Eval/ docs/
git commit -m "test(eval): final floors after precision+recall phases; backlog update"
```

---

### Task 14: Gate-0 spike — NLContextualEmbedding anisotropy diagnostic

**Files:**
- Create: `app-twoTests/Eval/Gate0DiagnosticTests.swift`
- Create (from results): `docs/superpowers/specs/2026-06-13-gate0-report.md`

**Not TDD** — this is a measurement spike. The test is env-gated (network asset download; never runs in normal suites).

- [ ] **Step 1: Write the diagnostic**

```swift
// app-twoTests/Eval/Gate0DiagnosticTests.swift
import Testing
import Foundation
import NaturalLanguage
@testable import app_two

/// Gate-0 spike (spec §4 Phase D): measures whether NLContextualEmbedding's
/// Latin-script model separates tag-relevant sentences after mean-centering.
/// Run manually: GATE0=1 in the environment. Requires network once (asset download).
struct Gate0DiagnosticTests {

    static let synonymPairs: [(String, String)] = [
        ("I feel completely wired and can't sit still", "I'm buzzing with energy right now"),
        ("My brain is foggy and slow today", "I can't think straight, everything is hazy"),
        ("I couldn't get off the couch all morning", "My body had no energy at all today"),
        ("I'm really anxious about tomorrow", "I'm so worried I can't relax"),
        // cross-lingual EN↔PT/ES
        ("I'm really anxious about tomorrow", "Estou muito ansioso com o dia de amanhã"),
        ("I slept terribly last night", "Dormí fatal anoche"),
    ]
    static let unrelatedPairs: [(String, String)] = [
        ("I feel completely wired and can't sit still", "The dishwasher finished its cycle"),
        ("My brain is foggy and slow today", "We booked flights to Lisbon in July"),
        ("I'm really anxious about tomorrow", "The new season starts on Friday"),
        ("I slept terribly last night", "La factura llega a final de mes"),
    ]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GATE0"] == "1"))
    func anisotropyAndSeparation() async throws {
        let embedding = try #require(NLContextualEmbedding(script: .latin))
        if !embedding.hasAvailableAssets {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                embedding.requestEmbeddingAssets { _, error in
                    if let error { c.resume(throwing: error) } else { c.resume() }
                }
            }
        }
        try embedding.load()

        func vector(_ text: String) throws -> [Double] {
            let result = try embedding.embeddingResult(for: text, language: nil)
            var sum = [Double](repeating: 0, count: embedding.dimension)
            var count = 0
            result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vec, _ in
                for (i, v) in vec.enumerated() { sum[i] += v }
                count += 1
                return true
            }
            return count == 0 ? sum : sum.map { $0 / Double(count) }
        }
        func cosine(_ a: [Double], _ b: [Double]) -> Double {
            let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
            let na = (a.reduce(0) { $0 + $1 * $1 }).squareRoot()
            let nb = (b.reduce(0) { $0 + $1 * $1 }).squareRoot()
            return na * nb == 0 ? 0 : dot / (na * nb)
        }

        // Corpus = all eval transcripts' sentences (realistic register, 3 languages).
        let corpus = EvalSet.cases.flatMap {
            $0.transcript.components(separatedBy: ". ").filter { $0.count > 10 }
        }
        let vectors = try corpus.map(vector)
        var mean = [Double](repeating: 0, count: vectors[0].count)
        for v in vectors { for (i, x) in v.enumerated() { mean[i] += x } }
        mean = mean.map { $0 / Double(vectors.count) }
        func centered(_ v: [Double]) -> [Double] { zip(v, mean).map(-) }

        // 1. Anisotropy: mean pairwise cosine over up to 500 random unrelated pairs.
        var rawSum = 0.0, centSum = 0.0, pairs = 0
        for i in stride(from: 0, to: vectors.count - 1, by: 1) {
            for j in (i + 1)..<min(i + 6, vectors.count) {
                rawSum += cosine(vectors[i], vectors[j])
                centSum += cosine(centered(vectors[i]), centered(vectors[j]))
                pairs += 1
            }
        }

        // 2. Synonym vs unrelated separation, centered.
        let synCos = try Self.synonymPairs.map { cosine(centered(vector($0.0)), centered(vector($0.1))) }
        let unrelCos = try Self.unrelatedPairs.map { cosine(centered(vector($0.0)), centered(vector($0.1))) }

        let report = """
        GATE0 REPORT
        corpus sentences: \(corpus.count), pairs: \(pairs)
        anisotropy raw mean cosine: \(String(format: "%.3f", rawSum / Double(pairs)))
        anisotropy centered mean cosine: \(String(format: "%.3f", centSum / Double(pairs)))
        synonym cosines (centered): \(synCos.map { String(format: "%.3f", $0) }.joined(separator: ", "))
        unrelated cosines (centered): \(unrelCos.map { String(format: "%.3f", $0) }.joined(separator: ", "))
        min synonym: \(String(format: "%.3f", synCos.min() ?? 0))  max unrelated: \(String(format: "%.3f", unrelCos.max() ?? 0))
        SEPARATION: \((synCos.min() ?? 0) > (unrelCos.max() ?? 0) ? "CLEAN" : "OVERLAPPING")
        """
        Issue.record(Comment(rawValue: report))   // deliberate fail = report carrier
    }
}
```

- [ ] **Step 2: Run it**

```bash
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 GATE0=1 xcodebuild test \
  -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' \
  -only-testing 'app-twoTests/Gate0DiagnosticTests' \
  -resultBundlePath /tmp/gate0.xcresult -disableAutomaticPackageResolution
```
Read the GATE0 REPORT from the xcresult. If asset download fails on the simulator (no network entitlement issues expected, but possible), note it and re-run on a device or macOS destination.

- [ ] **Step 3: Write `docs/superpowers/specs/2026-06-13-gate0-report.md`**

Record: the four numbers, the go/no-go call per spec §4 (go = centered unrelated mean ≪ centered synonym min, i.e. a usable threshold band exists; cross-lingual pairs land in the synonym band), and the decision: **GO → plan Phase D** / **NO-GO → MiniLM escalation per spec §6**.

- [ ] **Step 4: Commit**

```bash
git add app-twoTests/Eval/Gate0DiagnosticTests.swift docs/superpowers/specs/2026-06-13-gate0-report.md
git commit -m "test(nlp): Gate-0 NLContextualEmbedding anisotropy spike + report"
```

---

## Self-review (done at authoring)

- **Spec coverage:** Phase A → Tasks 1–2; Phase B → Tasks 3–7 (dead fallback ✓, sentiment bias ✓, scorer substring ✓, tense ✓, common-word guards ✓, topics ✓); Phase C → Tasks 8–11 (cue cache ✓, lemmas ✓, activities ✓, fuzzy meds ✓); Phase E → Task 12; Gate-0 → Task 14. Phase D/F deliberately excluded (own plan after Gate-0). Negation-position mismatch (review finding 7) intentionally absorbed by Task 8's longest-cue targeting — partial fix; full positional fix deferred to Phase D's sentence rework.
- **Type consistency:** `CueMatcher.tokenize` introduced Task 8, used Tasks 9/11/12; `Token.surface` (Task 9) used in Task 11; `EvalCounts` (Task 1) used in Task 2/7; `deriveTopics` defined Task 7 Step 5 where first used. `medCueList` naming: Task 12 references the cached list from Task 8 — executor must match the actual property name chosen in Task 8 Step 3 (flagged inline).
- **Placeholders:** none — every step has code, commands, or an explicit bounded authoring rule (Task 2 Step 2's distribution).
