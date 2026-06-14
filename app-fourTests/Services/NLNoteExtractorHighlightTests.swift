import Testing
@testable import app_four

struct NLNoteExtractorHighlightTests {

    let extractor = NLNoteExtractor()

    @Test func fillerSentenceIsNotAHighlight() {
        let r = extractor.extract(from:
            "I went to the store and bought some milk for the week. Took my Concerta 36mg at 8am and it kicked in fast.")
        #expect(!r.highlights.contains("I went to the store and bought some milk for the week."))
        #expect(r.highlights.contains { $0.contains("Concerta") })
    }

    @Test func substringDoesNotInflateScore() {
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

    @Test func cueFreeFillerNotPaddedIntoHighlights() {
        // 9 sentences → topN = 3, but only 2 carry cues (med, win). The new scorer
        // leaves cue-free filler at score 1.0 (< 1.5 threshold), so it is never
        // padded into the remaining slot. Under the old abs(sentiment)*2 scorer the
        // negatively-biased filler qualified and filled slot 3.
        let transcript = """
        The bins go out this week. I need to renew my passport at some point. \
        The car is booked in for a service next Tuesday. Took my Concerta 36mg at 8am today. \
        The recycling lorry comes twice a week these days. I should call the bank about the statement. \
        Finally finished the tax return and nailed it. The parcel is being sent to the neighbour. \
        I must remember to buy more printer paper.
        """
        let r = NLNoteExtractor().extract(from: transcript)
        #expect(r.highlights.count == 2)
        #expect(r.highlights.contains { $0.contains("Concerta") })
        #expect(r.highlights.contains { $0.contains("nailed it") })
        #expect(!r.highlights.contains { $0.contains("printer paper") })
    }

    @Test func nearDuplicateHighlightsCollapseToOne() {
        // 5 sentences → topN = 2. The two highest-scored (8.0 each) are near-identical
        // Concerta sentences with Jaccard > 0.6; the win sentence is third (7.0). Without
        // dedup BOTH Concerta fill the top-2 (two near-duplicate bullets). Dedup drops the
        // second, so exactly ONE Concerta bullet survives. (The dedup loop prunes the
        // top-N in place; it does not backfill rank 3, so the single bullet is the result.)
        let transcript = """
        I took my Concerta 36mg at eight this morning, got locked in and felt wired. \
        I took my Concerta 36 mg at eight in the morning, got locked in and felt wired. \
        Finally finished the tax return and nailed it. \
        The bins go out on Thursday. I should renew my passport soon.
        """
        let r = NLNoteExtractor().extract(from: transcript)
        let concerta = r.highlights.filter { $0.contains("Concerta") }
        #expect(concerta.count == 1)
    }

    @Test func medSentenceAlwaysCoveredWhenPresent() {
        let r = extractor.extract(from:
            "Finally finished the tax return, nailed it, feeling accomplished. Crushed the gym session and felt amazing afterwards. So proud of clearing my inbox, a real win for me. Feeling wonderful and energized and on top of the world. Also took my Ritalin at noon.")
        #expect(r.highlights.contains { $0.contains("Ritalin") })
    }

    @Test func titleStripsFillerAndCutsAtClause() {
        let r = extractor.extract(from:
            "So yeah I took my Concerta at eight and then the whole afternoon kind of fell apart honestly.")
        #expect(r.title == "I took my Concerta at eight")
    }
}
