#!/usr/bin/env swift
// Phase 2 training: 3-level models on the realistic v2 corpus, with a PROPER held-out
// test evaluation (Apple's method) + confusion matrix. Trains on the earlier-check-ins
// train split, reports trainingMetrics/validationMetrics AND evaluation(on:) on the
// later-check-ins held-out test.
//   swift train_v2.swift

import CreateML
import Foundation

struct Row: Codable { let text: String; let label: String }

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let dir = here.appendingPathComponent("corpus_v2_3lvl")

for signal in ["mood", "energy", "focus"] {
    let trainData = try MLDataTable(contentsOf: dir.appendingPathComponent("\(signal)_train.json"))
    let params = MLTextClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        algorithm: .transferLearning(.bertEmbedding, revision: 1),
        language: .english)
    let model = try MLTextClassifier(
        trainingData: trainData, textColumn: "text", labelColumn: "label", parameters: params)

    // held-out test via evaluation(on:) — the only number that counts
    let testRows = try JSONDecoder().decode([Row].self,
        from: Data(contentsOf: dir.appendingPathComponent("\(signal)_test.json")))
    var byLabel: [String: [String]] = [:]
    for r in testRows { byLabel[r.label, default: []].append(r.text) }
    let metrics = model.evaluation(on: byLabel)

    print("\n========== \(signal.uppercased()) ==========")
    print(String(format: "train acc %.3f   val acc %.3f   HELD-OUT TEST acc %.3f",
                 1 - model.trainingMetrics.classificationError,
                 1 - model.validationMetrics.classificationError,
                 1 - metrics.classificationError))
    print("— held-out test confusion (rows=true, cols=predicted) —")
    print(metrics.confusion)
    print("— per-class precision/recall —")
    print(metrics.precisionRecall)

    let name = "\(signal.prefix(1).uppercased() + signal.dropFirst())Classifier3"
    try model.write(to: dir.appendingPathComponent("\(name).mlmodel"))
}
print("\ndone")
