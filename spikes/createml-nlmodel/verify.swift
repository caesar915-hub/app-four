#!/usr/bin/env swift
// Verify the FULL production aggregation (sentence-split + tense present-wins + tau)
// on macOS, against the real screenshot transcript, BEFORE writing it into the app.
//   swift verify.swift

import NaturalLanguage
import CoreML
import Foundation

let TAU = 0.45

// --- faithful inline copy of app's TenseClassifier markers/logic ---
let presentMarkers = ["right now","currently","today","i feel","i'm feeling","i am feeling","i am","i'm","this evening","tonight","at the moment","these days","now i","now i'm","i've been feeling","i have been feeling"]
let pastMarkers = ["i was","i felt","earlier","this morning","yesterday","last night","by evening","by the afternoon","this afternoon","woke up","had been","used to","a while ago","before","was feeling","were feeling"]
func temporalWeight(_ s: String) -> Double {
    let l = s.lowercased()
    let pres = presentMarkers.contains { l.contains($0) }
    let past = pastMarkers.contains { l.contains($0) }
    if pres && !past { return 1.0 }
    if past && !pres { return 0.2 }
    if pres && past {
        let lp = presentMarkers.compactMap { l.range(of: $0)?.lowerBound }.max()
        let lq = pastMarkers.compactMap { l.range(of: $0)?.lowerBound }.max()
        if let p = lp, let q = lq { return p >= q ? 1.0 : 0.2 }
        return 1.0
    }
    return 0.5  // neutral
}

func sentences(_ t: String) -> [String] {
    var out: [String] = []
    let tok = NLTokenizer(unit: .sentence); tok.string = t
    tok.enumerateTokens(in: t.startIndex..<t.endIndex) { r, _ in
        let s = String(t[r]).trimmingCharacters(in: .whitespaces)
        if s.count > 3 { out.append(s) }; return true
    }
    return out
}

func aggregate(_ transcript: String, _ model: NLModel) -> String {
    var best: String? = nil; var bestScore = 0.0
    for s in sentences(transcript) {
        let h = model.predictedLabelHypotheses(for: s, maximumCount: 1)
        guard let top = h.max(by: { $0.value < $1.value }), top.key != "none", top.value >= TAU else { continue }
        let score = top.value * temporalWeight(s)
        if score > bestScore { bestScore = score; best = top.key }
    }
    return best ?? "none"
}

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let res = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("app-four/Resources")
func load(_ n: String) throws -> NLModel { try NLModel(mlModel: try MLModel(contentsOf: try MLModel.compileModel(at: res.appendingPathComponent("\(n).mlmodel")))) }
let mood = try load("MoodClassifier"), energy = try load("EnergyClassifier"), focus = try load("FocusClassifier")

let cases = [
    "Yeah, I mean now I have a good mood actually. Bright, I would say. Cannot complain really. Energy, it's okay. It's okay, I'm just getting tired now. But I have energy all day. Just getting a bit tired right now. And yes, I was able to focus, but now I'm losing focus. I lost focus already, 30 minutes ago, So now I really have no focus. I am going to sleep in two hours. Yes, that's my plan.",
    "Earlier I was sharp but right now my head is empty.",
]
print("TAU=\(TAU)\n")
for c in cases {
    print("TRANSCRIPT: \(c.prefix(70))...")
    print("   mood=\(aggregate(c, mood))  energy=\(aggregate(c, energy))  focus=\(aggregate(c, focus))\n")
}
