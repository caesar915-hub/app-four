import NaturalLanguage
import CoreML
import Foundation
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let resources = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("app-four/Resources")
let probes = [
  "my brain just will not concentrate today",
  "I can't seem to keep my attention on anything",
  "earlier I was sharp but right now my head is empty",
  "I'm running on fumes this afternoon",
  "today has been genuinely wonderful",
  "just took my vyvanse this morning",
  "my thoughts are crystal clear and quick right now",
  "I feel pretty average, nothing special",
]
var models: [(String, NLModel)] = []
for name in ["MoodClassifier","EnergyClassifier","FocusClassifier"] {
  let url = resources.appendingPathComponent("\(name).mlmodel")
  let nl = try NLModel(mlModel: try MLModel(contentsOf: try MLModel.compileModel(at: url)))
  models.append((name.replacingOccurrences(of:"Classifier",with:""), nl))
}
for p in probes {
  var parts: [String] = []
  for (n, m) in models {
    let h = m.predictedLabelHypotheses(for: p, maximumCount: 1)
    let top = h.max { $0.value < $1.value }
    parts.append("\(n)=\(m.predictedLabel(for: p) ?? "nil")(\(top.map{String(format:"%.2f",$0.value)} ?? "?"))")
  }
  print("\"\(p)\"\n   \(parts.joined(separator: "  "))")
}
