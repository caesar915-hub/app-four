#!/usr/bin/env swift
// Quick validation: run the device-failure probes through the freshly trained
// models on macOS (which has the BERT asset). No simulator/device needed.
//   swift predict.swift

import NaturalLanguage
import CoreML
import Foundation

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let resources = here.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("app-four/Resources")

let probes = [
    "I feel great today",                              // mood=great, energy/focus=none
    "I really have no focus",                          // focus=foggy, energy/mood=none
    "I am so tired",                                   // energy=tired, mood/focus=none
    "lets see if I can focus now",                     // all none (hypothetical)
    "I was able to focus but now I have no focus",     // focus=foggy (recency)
    "Took elvanse 50mg",                               // all none (medication)
]

for name in ["MoodClassifier", "EnergyClassifier", "FocusClassifier"] {
    let url = resources.appendingPathComponent("\(name).mlmodel")
    let compiled = try MLModel.compileModel(at: url)
    let nl = try NLModel(mlModel: try MLModel(contentsOf: compiled))
    print("\n--- \(name) ---")
    for p in probes {
        let hyp = nl.predictedLabelHypotheses(for: p, maximumCount: 1)
        let top = hyp.max { $0.value < $1.value }
        let label = nl.predictedLabel(for: p) ?? "<nil>"
        let conf = top.map { String(format: "%.2f", $0.value) } ?? "?"
        print("  \"\(p)\" -> \(label) (\(conf))")
    }
}
