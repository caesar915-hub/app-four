# Quickstart: Validate Multilingual Check-in Extraction (Demo)

Prerequisites: macOS + Xcode, iPhone 15 simulator available, branch `feat/nlp-multilang-demo`.

## 1. Build

```sh
xcodebuild build -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expect: clean build. The 7 JSON packs in `app-four/Resources/` auto-bundle (synchronized file
group — no pbxproj edit). A clean build is the first proof `Bundle.main.url` can find them.

## 2. Eval floors (English regression guard — the live gate)

```sh
xcodebuild test -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:app-fourTests/Eval
```

Expect: `ExtractionEvalTests.metricsMeetFloors` passes — every category's precision/recall ≥ its
floor. **If a floor breaks, STOP and investigate** the engine swap; do NOT weaken a floor
(Constitution VII). Only raise an exact expectation if the richer engine demonstrably improves it.

## 3. Selection unit tests

```sh
xcodebuild test -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:app-fourTests/Services/LanguageDetectorTests \
  -only-testing:app-fourTests/Services/LanguagePackLoaderTests
```

Expect: detector maps en/pt/es-ES/es-MX correctly (incl. the MX-vs-ES region branch); loader
decodes each non-English `config.*.json` to a non-`.english` config (no silent fallback), threads
the personalization overlay, and falls back to English on a missing pack.

## 4. Four-language manual demo (SC-001/003/004)

Run on the simulator (ios-debugger-agent). Enter each check-in and confirm **all six signals**
(mood, energy, focus, sleep, medications, side-effects) surface:

- **en**: "Took Concerta 36mg this morning. Slept five hours, woke up tired. Focus good in the morning but energy low in the afternoon. Dry mouth all day. Mood low."
- **pt**: "Tomei Concerta 36mg de manhã. Dormi cinco horas, acordei cansado. Concentração boa de manhã mas energia em baixo à tarde. Boca seca o dia todo. Humor em baixo."
- **es (Spain)**: "Tomé Concerta 36mg por la mañana. Dormí cinco horas, me desperté cansado. Concentración bien por la mañana pero energía baja por la tarde. Boca seca todo el día. Humor por los suelos."
- **mx (Mexico)**: "Tomé Concerta 36mg en la mañana. Dormí cinco horas, me desperté cansado. Concentración bien en la mañana pero energía baja en la tarde. Boca seca todo el día. Ando agüitado."

To force **es-MX vs es-ES**, set the simulator region to Mexico vs Spain
(Settings ▸ General ▸ Language & Region), since `NLLanguageRecognizer` returns only `es`.

## 5. Personalization smoke (SC-005)

Confirm a previously user-corrected term still extracts in a new English check-in (the overlay is
threaded through `LanguagePackLoader`).

## Done when

- §1 builds clean; §2 floors hold; §3 selection tests pass; §4 all four check-ins surface the six
  signals with the matching pack; §5 personalization preserved.
