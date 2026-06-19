import Testing
import Foundation
import NaturalLanguage
import CoreML
@testable import app_four

/// Throwaway diagnostic — NOT a regression test. Dumps, for the 2026-06-18 screenshot
/// transcript, how each sentence splits, its tense + temporal weight, and what each
/// trained model predicts with what confidence. Answers the four "are you sure" unknowns
/// empirically before any fix is written.
struct TemporalDiagnostic {

    static let transcript = """
    Yeah, I mean now I have a good mood actually. Bright, I would say. Cannot complain really. \
    Energy, it's okay. It's okay, I'm just getting tired now. But I have energy all day. \
    Just getting a bit tired right now. And yes, I was able to focus, but now I'm losing focus. \
    I lost focus already, 30 minutes ago, So now I really have no focus. \
    I am going to sleep in two hours. Yes, that's my plan.
    """

    @Test func inspectModelInterface() throws {
        let resources = "/Users/caesargrey/Projects/app-four/app-four/Resources/"
        var out = "==================== MODEL INTERFACE ====================\n"
        for name in ["MoodClassifier", "EnergyClassifier", "FocusClassifier"] {
            let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: resources + name + ".mlmodel"))
            let ml = try MLModel(contentsOf: compiled)
            let d = ml.modelDescription
            out += "\n--- \(name) ---\n"
            out += "inputs:\n"
            for (k, v) in d.inputDescriptionsByName { out += "  \(k): \(v.type)\n" }
            out += "outputs:\n"
            for (k, v) in d.outputDescriptionsByName { out += "  \(k): \(v.type)\n" }
            out += "predictedFeatureName: \(d.predictedFeatureName ?? "<nil>")\n"
            out += "predictedProbabilitiesName: \(d.predictedProbabilitiesName ?? "<nil>")\n"
            out += "metadata: \(d.metadata[MLModelMetadataKey.description] ?? "")\n"

            // Try calling MLModel directly with input feature "text"
            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: ["text": "I feel great today"])
                let result = try ml.prediction(from: provider)
                out += "direct predict (input 'text'): "
                for fn in result.featureNames { out += "\(fn)=\(result.featureValue(for: fn)?.stringValue ?? "?") " }
                out += "\n"
            } catch {
                out += "direct predict ERROR: \(error)\n"
            }
        }
        out += "========================================================\n"
        try out.write(toFile: "/tmp/model_interface.txt", atomically: true, encoding: .utf8)
    }

    @Test func modelSanityCheck() throws {
        let resources = "/Users/caesargrey/Projects/app-four/app-four/Resources/"
        var out = "==================== MODEL SANITY ====================\n"

        let probes = ["I feel great today", "I am so tired", "I can't focus at all",
                      "I really have no focus", "I was able to focus"]

        // Path A: production method — NLModel(contentsOf: .mlmodelc)
        for name in ["MoodClassifier", "EnergyClassifier", "FocusClassifier"] {
            let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: resources + name + ".mlmodel"))
            let viaMLModel = try NLModel(mlModel: try MLModel(contentsOf: compiled))
            let viaContents = try NLModel(contentsOf: compiled)
            out += "\n--- \(name) ---\n"
            for p in probes {
                let labelML = viaMLModel.predictedLabel(for: p) ?? "<nil>"
                let hypML = viaMLModel.predictedLabelHypotheses(for: p, maximumCount: 3)
                let labelC = viaContents.predictedLabel(for: p) ?? "<nil>"
                out += "  \"\(p)\"\n"
                out += "     mlModel:  label=\(labelML)  hyp=\(hypML.count)entries \(fmt(hypML))\n"
                out += "     contents: label=\(labelC)\n"
            }
        }
        out += "=====================================================\n"
        try out.write(toFile: "/tmp/model_sanity.txt", atomically: true, encoding: .utf8)
    }

    private func fmt(_ h: [String: Double]) -> String {
        h.sorted { $0.value > $1.value }.map { "\($0.key)=\(String(format: "%.2f", $0.value))" }.joined(separator: " ")
    }

    @Test func dumpPerSentenceBreakdown() throws {
        let resources = "/Users/caesargrey/Projects/app-four/app-four/Resources/"
        let mood   = try Self.load(resources + "MoodClassifier.mlmodel")
        let energy = try Self.load(resources + "EnergyClassifier.mlmodel")
        let focus  = try Self.load(resources + "FocusClassifier.mlmodel")
        let tense  = TenseClassifier()

        let sentences = Self.split(Self.transcript)

        var out = "==================== TEMPORAL DIAGNOSTIC ====================\n"
        out += "sentences: \(sentences.count)\n\n"

        for (i, s) in sentences.enumerated() {
            let t = tense.tense(of: s)
            out += "[\(i)] \"\(s)\"\n"
            out += "     tense=\(t)  weight=\(t.temporalWeight)\n"
            out += "     mood:   \(Self.top(mood, s))\n"
            out += "     energy: \(Self.top(energy, s))\n"
            out += "     focus:  \(Self.top(focus, s))\n\n"
        }
        out += "=============================================================\n"

        try out.write(toFile: "/tmp/tempdiag_out.txt", atomically: true, encoding: .utf8)
    }

    // MARK: - helpers

    private static func top(_ model: NLModel, _ s: String) -> String {
        let h = model.predictedLabelHypotheses(for: s, maximumCount: 2)
        let sorted = h.sorted { $0.value > $1.value }
        return sorted.map { "\($0.key)=\(String(format: "%.3f", $0.value))" }.joined(separator: "  ")
    }

    private static func split(_ text: String) -> [String] {
        var out: [String] = []
        let tok = NLTokenizer(unit: .sentence)
        tok.string = text
        tok.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let v = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if v.count > 3 { out.append(v) }
            return true
        }
        return out
    }

    private static func load(_ path: String) throws -> NLModel {
        let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: path))
        let ml = try MLModel(contentsOf: compiled)
        return try NLModel(mlModel: ml)
    }

    /// Device-safe model URL: prefer the bundled compiled model (works on device),
    /// fall back to the Mac source path (simulator runs from my checkout).
    static func modelURL(_ name: String) -> URL {
        if let u = Bundle.main.url(forResource: name, withExtension: "mlmodelc") { return u }
        if let u = Bundle.main.url(forResource: name, withExtension: "mlmodel") { return u }
        return URL(fileURLWithPath: "/Users/caesargrey/Projects/app-four/app-four/Resources/\(name).mlmodel")
    }

    @Test func requestAssetsThenPredict() async throws {
        var out = "============ REQUEST ASSETS + PREDICT ============\n"
        guard let emb = NLContextualEmbedding(language: .english) else {
            out += "NLContextualEmbedding(en) == nil\n"
            Issue.record(Comment(rawValue: out)); return
        }
        out += "before: hasAvailableAssets=\(emb.hasAvailableAssets)\n"
        if !emb.hasAvailableAssets {
            let msg: String = await withCheckedContinuation { cont in
                emb.requestAssets { result, error in
                    cont.resume(returning: "result=\(String(describing: result)) error=\(error.map { "\($0)" } ?? "nil")")
                }
            }
            out += "requestAssets: \(msg)\n"
        }
        out += "after: hasAvailableAssets=\(emb.hasAvailableAssets)\n\n"

        let probes = ["I feel great today", "I really have no focus", "I am so tired"]
        for name in ["MoodClassifier", "EnergyClassifier", "FocusClassifier"] {
            out += "--- \(name) ---\n"
            do {
                let url = Self.modelURL(name)
                let ml = url.pathExtension == "mlmodelc"
                    ? try MLModel(contentsOf: url)
                    : try MLModel(contentsOf: try await MLModel.compileModel(at: url))
                let nl = try NLModel(mlModel: ml)
                for p in probes { out += "  \"\(p)\" -> \(nl.predictedLabel(for: p) ?? "<nil>")\n" }
            } catch { out += "  ERROR: \(error)\n" }
        }
        out += "=================================================\n"
        Issue.record(Comment(rawValue: out))
    }

    @Test func deviceProbe() throws {
        var out = "==================== DEVICE PROBE ====================\n"
        out += "bundle: \(Bundle.main.bundlePath)\n"
        // contextual-embedding availability — the asset BERT models need
        let emb = NLContextualEmbedding(language: .english)
        out += "NLContextualEmbedding(en): \(emb == nil ? "nil" : "exists, hasAvailableAssets=\(emb!.hasAvailableAssets)")\n\n"

        let probes = ["I feel great today", "I really have no focus", "I am so tired"]
        for name in ["MoodClassifier", "EnergyClassifier", "FocusClassifier"] {
            out += "--- \(name) ---\n"
            let url = Self.modelURL(name)
            out += "  url: \(url.lastPathComponent) (exists=\(FileManager.default.fileExists(atPath: url.path)))\n"
            do {
                let ml = url.pathExtension == "mlmodelc"
                    ? try MLModel(contentsOf: url)
                    : try MLModel(contentsOf: MLModel.compileModel(at: url))
                let nl = try NLModel(mlModel: ml)
                for p in probes {
                    let label = nl.predictedLabel(for: p) ?? "<nil>"
                    out += "  \"\(p)\" -> \(label)\n"
                }
            } catch {
                out += "  LOAD/PREDICT ERROR: \(error)\n"
            }
        }
        out += "=====================================================\n"
        try out.write(toFile: NSTemporaryDirectory() + "device_probe.txt", atomically: true, encoding: .utf8)
        // also surface in the test result so we can read it without file retrieval
        Issue.record(Comment(rawValue: out))
    }
}
