# Contract: Language Pack JSON Resources

Packs live in `app-four/Resources/`, auto-bundled by the synchronized file group. Resolved via
`Bundle.main.url(forResource: "<name>", withExtension: "json")`.

## Files (7)

| File | Decodes to | Required? |
|---|---|---|
| `lexicon.en.json` | `LexiconData` → `Lexicon` | yes (English vocab) |
| `lexicon.pt-PT.json` | `LexiconData` | yes |
| `lexicon.es-ES.json` | `LexiconData` | yes |
| `lexicon.es-MX.json` | `LexiconData` | yes |
| `config.pt-PT.json` | `LanguageConfig` | yes |
| `config.es-ES.json` | `LanguageConfig` | yes |
| `config.es-MX.json` | `LanguageConfig` | yes |

There is **no** `config.en.json` — English uses the in-code `LanguageConfig.english`.
The legacy `lexicon.json` is **removed** after the call-site rewire.

## `lexicon.<key>.json` shape (mirrors `LexiconData`)

Top-level keys (all arrays of strings unless noted):
`medications`, `moodSpecific` (`[{word,label}]`), `energyCharged|energyAlert|energySteady|energyTired|energySluggish`,
`focusLockedIn|focusSharp|focusPresent|focusDistracted|focusFoggy`, `feelings`,
`taskCompletionCues`, `taskAvoidanceCues`, `winCues`, `overwhelmCues`, `executiveDysfunction`,
`appointmentCues`, `sideEffectCues`, `physicalStim`, `physicalSideEffects`,
`sleepQualityGood`, `sleepQualityBad`, `sleepInsomnia`, `reboundTerms`, `appetiteLoss`,
`appetiteReturn`, `negationTokens`, `medNotTakenVerbs`,
`timeOfDayKeywords` (`[{keyword,normalized}]`), `activityKeywords` (`[{category,keywords[]}]`).

**Constraint (FR-005/FR-006)**: in `lexicon.en.json`, the `feelings` array MUST be exactly
spec-020's curated 20 Mood-Meter emotions — not the spike's pre-curation list. The vocab key stays
`feelings`; it populates the model's `emotions` field.

## `config.<key>.json` shape (mirrors `LanguageConfig`)

MUST contain **all 17** required keys (synthesized Codable throws on a missing key):
`numberWords` (`{string: number}`), `sleepWords`, `sleepMultiwordPatterns`, `sleepHoursPattern`,
`sleepBarePattern`, `weakEnergyTriggers`, `weakEnergyTable` (`[{word, level}]`, `level` ∈
EnergyLevel raw values: `sluggish|tired|steady|alert|charged`), `weakEnergyDefaultLevel`,
`weakEnergyDefaultPhrase`, `weakMoodTriggerPattern`, `weakMoodTable` (`[{word, label}]`),
`weakMoodDefaultLabel`, `weakMoodDefaultPhrase`, `presentMarkers`, `pastMarkers`,
`pastVerbSuffixes`, `irregularPastVerbs`.

**Inert keys (documented limitation)**: packs MAY contain extra keys
(`clauseBreakConjunctions`, `medContextTokens`, `medStoplist`, `stopStartTerms`,
`titleClauseSplitters`, `titleFillers`, `canonicalInflections`, `notTakenBreaks`,
`structuredPatternTriggers`, `halfDoseTerms`, `negationNarrowWindowTokens`, `weakTriggerNouns`).
`LanguageConfig` does NOT decode these, so for pt/es those paths (negation, med-clause, titles,
morphology) run **English** rules. This is the accepted demo limitation (FR-012).

## Acceptance

- Every file resolves via `Bundle.main.url` in a build (D7).
- Each `config.<key>.json` decodes to a config whose values differ from `.english` (a complete,
  non-fallback decode) — pinned by `LanguagePackLoaderTests` (D5).
