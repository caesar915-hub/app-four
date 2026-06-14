import Testing
import Foundation
import NaturalLanguage
@testable import app_four

/// Gate-0 spike (spec §4 Phase D): does NLContextualEmbedding's Latin-script model
/// separate tag-relevant sentences after mean-centering? Slow + network (asset
/// download) — gated off in normal runs.
struct Gate0DiagnosticTests {

    static let synonymPairs: [(String, String)] = [
        ("I feel completely wired and can't sit still", "I'm buzzing with energy right now"),
        ("My brain is foggy and slow today", "I can't think straight, everything is hazy"),
        ("I couldn't get off the couch all morning", "My body had no energy at all today"),
        ("I'm really anxious about tomorrow", "I'm so worried I can't relax"),
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
            // SDK symbol: ObjC `requestEmbeddingAssetsWithCompletionHandler:` is
            // NS_REFINED_FOR_SWIFT to async `requestAssets()`.
            let assets = try await embedding.requestAssets()
            try #require(assets == .available, "embedding assets unavailable: \(assets)")
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

        let corpus = EvalSet.cases.flatMap {
            $0.transcript.components(separatedBy: ". ").filter { $0.count > 10 }
        }
        let vectors = try corpus.map(vector)
        var mean = [Double](repeating: 0, count: vectors[0].count)
        for v in vectors { for (i, x) in v.enumerated() { mean[i] += x } }
        mean = mean.map { $0 / Double(vectors.count) }
        func centered(_ v: [Double]) -> [Double] { zip(v, mean).map(-) }

        var rawSum = 0.0, centSum = 0.0, pairs = 0
        for i in stride(from: 0, to: vectors.count - 1, by: 1) {
            for j in (i + 1)..<min(i + 6, vectors.count) {
                rawSum += cosine(vectors[i], vectors[j])
                centSum += cosine(centered(vectors[i]), centered(vectors[j]))
                pairs += 1
            }
        }

        let synCos = try Self.synonymPairs.map { try cosine(centered(vector($0.0)), centered(vector($0.1))) }
        let unrelCos = try Self.unrelatedPairs.map { try cosine(centered(vector($0.0)), centered(vector($0.1))) }

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
        Issue.record(Comment(rawValue: report))
    }
}
