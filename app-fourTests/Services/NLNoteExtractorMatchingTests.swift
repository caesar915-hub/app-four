import Testing
@testable import app_four

/// P0.1 — word-boundary matching. Cues must match whole tokens (or contiguous
/// token subsequences for multi-word cues), never substrings inside a larger word.
struct NLNoteExtractorMatchingTests {

    let extractor = NLNoteExtractor()

    // "window" contains "win" — must NOT register a win cue.
    @Test func windowIsNotAWin() {
        let result = extractor.extract(from: "I opened the window to let some air in.")
        #expect(result.wins.isEmpty)
    }

    // "finished" contains "fine" — must NOT yield mood "okay" from the "fine" cue.
    @Test func finishedIsNotFine() {
        let result = extractor.extract(from: "I finished the report.")
        #expect(result.mood != "okay")
    }

    // "restless" contains "rest" — must NOT register a Resting activity.
    @Test func restlessIsNotResting() {
        let result = extractor.extract(from: "I felt restless all afternoon.")
        #expect(!result.activities.contains("Resting"))
    }

    // Sanity: the real whole-word cue still matches.
    @Test func realWinStillMatches() {
        let result = extractor.extract(from: "Today was a big win for me.")
        #expect(!result.wins.isEmpty)
    }

    // Sanity: multi-word cue still matches as a contiguous subsequence.
    @Test func multiWordCueStillMatches() {
        let result = extractor.extract(from: "I am feeling calm and relaxed.")
        #expect(result.mood == "good")
    }

    @Test func paraphraseEnergyYieldsNilWithoutLexiconHit() {
        // "wading through wet sand" is not in energySluggish; the dead embedding
        // fallback never rescued it (gate 0.55 vs real distances 0.82+). Pins the
        // honest behavior so Phase D has a baseline to beat.
        let result = extractor.extract(from: "My body was wading through wet sand all morning.")
        #expect(result.energy == nil)
    }

    // MARK: - Common-word traps (Task 5)

    @Test func seenAloneIsNotAnEmotion() {
        let r = extractor.extract(from: "I've seen my therapist this morning.")
        #expect(!r.emotions.contains("seen"))
    }
    @Test func lostKeysIsNotFoggyFocus() {
        #expect(extractor.extract(from: "I lost my keys again this morning.").focus == nil)
    }
    @Test func spentMoneyIsNotSluggishEnergy() {
        #expect(extractor.extract(from: "I spent the morning at the bank.").energy == nil)
    }

    // MARK: - Function-word traps (Task 5b)

    @Test func onAsPrepositionIsNotAlertEnergy() {
        #expect(extractor.extract(from: "The meeting is on Friday and the parcel arrives on Tuesday.").energy == nil)
    }
    @Test func hereAsLocationIsNotPresentFocus() {
        #expect(extractor.extract(from: "I left my umbrella over here by the door.").focus == nil)
    }
    @Test func dimLightingIsNotTiredEnergy() {
        #expect(extractor.extract(from: "The dim lighting in the restaurant was quite cosy.").energy == nil)
    }

    // MARK: - CueMatcher refactor pins (Task 8)

    @Test func multiWordCueStillMatchesAcrossRefactor() {
        let r = extractor.extract(from: "Total task paralysis this afternoon, could not start the report.")
        #expect(!r.executiveDysfunction.isEmpty)
    }
    @Test func substringInsideWordStillRejected() {
        let r = extractor.extract(from: "The window was open all night.")   // "win" ⊄ tokens
        #expect(r.wins.isEmpty)
    }

    // MARK: - Verb-lemma fallback pins (Task 9)

    @Test func curatedEmotionDetected() {
        let r = extractor.extract(from: "I felt frustrated about the deadline.")
        #expect(r.emotions.contains("frustrated"))
    }
    @Test func inflectedAvoidanceMatches() {
        let r = extractor.extract(from: "I keep avoiding that email thread.")
        #expect(!r.tasksAvoided.isEmpty)
    }
    @Test func nounDoesNotLemmaMatchVerbCue() {
        let r = extractor.extract(from: "There were wires everywhere in the office.")
        #expect(!r.emotions.contains("wired"))
    }

    // MARK: - New activity categories (Task 10)

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
}
