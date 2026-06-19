#!/usr/bin/env swift
// Reproducible Create ML training for the 3 signal classifiers.
// Runs on macOS (has the NLContextualEmbedding/BERT asset). CLI, no GUI caching.
//
//   swift train.swift
//
// Writes MoodClassifier/EnergyClassifier/FocusClassifier.mlmodel next to the corpus,
// then copies them into app-four/Resources/ for the app target.

import CreateML
import Foundation

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let corpus = here.appendingPathComponent("corpus")
let resources = here.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("app-four/Resources")

let signals = ["mood", "energy", "focus"]

for signal in signals {
    let dataURL = corpus.appendingPathComponent("\(signal).json")
    let data = try MLDataTable(contentsOf: dataURL)
    print("\(signal): \(data.rows.count) rows")

    let params = MLTextClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        algorithm: .transferLearning(.bertEmbedding, revision: 1),
        language: .english
    )
    let model = try MLTextClassifier(
        trainingData: data, textColumn: "text", labelColumn: "label",
        parameters: params
    )

    let trainAcc = 1.0 - model.trainingMetrics.classificationError
    let valAcc = 1.0 - model.validationMetrics.classificationError
    print("  training acc: \(String(format: "%.3f", trainAcc))  validation acc: \(String(format: "%.3f", valAcc))")

    let name = "\(signal.prefix(1).uppercased() + signal.dropFirst())Classifier"
    let out = corpus.appendingPathComponent("\(name).mlmodel")
    try model.write(to: out)
    let dest = resources.appendingPathComponent("\(name).mlmodel")
    try? FileManager.default.removeItem(at: dest)
    try FileManager.default.copyItem(at: out, to: dest)
    print("  wrote \(name).mlmodel -> Resources/")
}
print("done")
