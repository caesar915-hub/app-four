#!/usr/bin/env swift
// Standalone ML-path eval on macOS (has the embedding asset). Scores the production
// aggregation (split + tense present-wins + tau) against the 40-case EvalSet gold,
// using the same EvalCounts semantics as the app (wrong non-nil = FP+FN).
//
// Measures ML ALONE (abstain -> none, no lexicon backfill). The shipping composite's
// recall is >= this, since the lexicon catches some of what ML abstains on.
//   swift eval_ml.swift

import NaturalLanguage
import CoreML
import Foundation

let TAU = 0.45

let presentMarkers = ["right now","currently","today","i feel","i'm feeling","i am feeling","i am","i'm","this evening","tonight","at the moment","these days","now i","now i'm","i've been feeling","i have been feeling"]
let pastMarkers = ["i was","i felt","earlier","this morning","yesterday","last night","by evening","by the afternoon","this afternoon","woke up","had been","used to","a while ago","before","was feeling","were feeling"]
func temporalWeight(_ s: String) -> Double {
    let l = s.lowercased()
    let pres = presentMarkers.contains { l.contains($0) }, past = pastMarkers.contains { l.contains($0) }
    if pres && !past { return 1.0 }
    if past && !pres { return 0.2 }
    if pres && past {
        let lp = presentMarkers.compactMap { l.range(of: $0)?.lowerBound }.max()
        let lq = pastMarkers.compactMap { l.range(of: $0)?.lowerBound }.max()
        if let p = lp, let q = lq { return p >= q ? 1.0 : 0.2 }
        return 1.0
    }
    return 0.5
}
func sentences(_ t: String) -> [String] {
    var out: [String] = []; let tok = NLTokenizer(unit: .sentence); tok.string = t
    tok.enumerateTokens(in: t.startIndex..<t.endIndex) { r, _ in
        let s = String(t[r]).trimmingCharacters(in: .whitespaces); if s.count > 3 { out.append(s) }; return true }
    return out
}
func aggregate(_ transcript: String, _ model: NLModel) -> String? {
    var best: String? = nil; var bestScore = 0.0
    for s in sentences(transcript) {
        let h = model.predictedLabelHypotheses(for: s, maximumCount: 1)
        guard let top = h.max(by: { $0.value < $1.value }), top.key != "none", top.value >= TAU else { continue }
        let score = top.value * temporalWeight(s)
        if score > bestScore { bestScore = score; best = top.key }
    }
    return best
}

struct Counts {
    var tp = 0, fp = 0, fn = 0
    mutating func add(_ e: String?, _ a: String?) {
        switch (e, a) {
        case (nil, nil): break
        case (nil, _?): fp += 1
        case (_?, nil): fn += 1
        case let (e?, a?): if e == a { tp += 1 } else { fp += 1; fn += 1 }
        }
    }
    var precision: Double { tp + fp == 0 ? 1 : Double(tp) / Double(tp + fp) }
    var recall: Double { tp + fn == 0 ? 1 : Double(tp) / Double(tp + fn) }
}

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let res = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("app-four/Resources")
func load(_ n: String) throws -> NLModel { try NLModel(mlModel: try MLModel(contentsOf: try MLModel.compileModel(at: res.appendingPathComponent("\(n).mlmodel")))) }
let mood = try load("MoodClassifier"), energy = try load("EnergyClassifier"), focus = try load("FocusClassifier")

let evalURL = here.deletingLastPathComponent().appendingPathComponent("evalset.json")
let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: evalURL)) as! [[String: Any]]

let floors: [String: (Double, Double)] = ["mood": (0.730, 0.580), "energy": (0.647, 0.230), "focus": (0.380, 0.313)]

func run(_ subset: [[String: Any]], _ title: String) {
    var m = Counts(), e = Counts(), f = Counts()
    for c in subset {
        let t = c["transcript"] as! String
        func gold(_ k: String) -> String? { (c[k] as? String) }
        m.add(gold("mood"), aggregate(t, mood))
        e.add(gold("energy"), aggregate(t, energy))
        f.add(gold("focus"), aggregate(t, focus))
    }
    print("\n=== \(title) (\(subset.count) cases) ===")
    for (name, cnt) in [("mood", m), ("energy", e), ("focus", f)] {
        let fl = floors[name]!
        let pass = cnt.precision >= fl.0 && cnt.recall >= fl.1
        print(String(format: "%-7@ P=%.3f R=%.3f  (floor %.3f/%.3f)  [tp%d fp%d fn%d]  %@",
                     name as NSString, cnt.precision, cnt.recall, fl.0, fl.1, cnt.tp, cnt.fp, cnt.fn,
                     (pass ? "PASS" : "FAIL") as NSString))
    }
}

run(cases, "ALL 40")
run(cases.filter { ($0["id"] as? String)?.hasPrefix("en-") == true }, "ENGLISH ONLY")
