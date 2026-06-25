# App Localization (en / pt / es · 6 regions) + Multilingual Voice & Extraction

> Supersedes the tri-lens audit plan below (that work shipped as **PR #15**). This is the active plan.

## Context

Squirl ships English-only UI and English-only **voice** transcription. The goal: make the app usable end-to-end in **English (UK + USA)**, **Portuguese (Portugal + Brazil)**, and **Spanish (Spain + Latin America)** — UI chrome *and* the on-device NLP extraction of spoken/typed check-ins.

**Most of the NLP is already built — do not reinvent it:**
- **`feat/nlp-multilang-demo` / PR #14** (approved, 333 tests passing) already ships a multilingual extractor: language packs (`lexicon.en/pt-PT/es-ES/es-MX.json` + configs), `LanguageDetector` (`NLLanguageRecognizer` + device-region disambiguation), `LanguagePackLoader`, `LanguageConfig`. It auto-detects the content language **per check-in** and is decoupled from the UI language.
- A detailed **UI-localization plan** already exists (`~/.claude/plans/right-thi-sin-the-replicated-russell.md`) with locked decisions (OS per-app language screen; String Catalog; ~195 literals to wrap).

**Gaps your region list exposes (the new work):**
1. **Brazil (`pt-BR`) is missing** — only `pt-PT` exists. pt-BR differs materially (vocabulary, "você"/"tu", "celular"/"telemóvel"). Needs its own extractor pack + UI localization.
2. **"Latin America" Spanish** is currently just `es-MX` (Mexico). The proper umbrella is `es-419`.
3. **Voice is hardcoded English** — [WhisperKitTranscriptionService.swift:133](app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L133) `language = "en"` and [SpeechTranscriptionService.swift:7](app-four/Services/Speech/SpeechTranscriptionService.swift#L7) `en-US`. So spoken PT/ES check-ins won't transcribe even though the extractor handles them.
4. **The entire UI is hardcoded English** — no `.xcstrings`; ~280–350 user-facing strings (views + enum display labels + accessibility).

## How the multilingual extractor works (you asked)

Per check-in, **after transcription**: `LanguageDetector` runs `NLLanguageRecognizer` (constrained to en/pt/es) on the text, then disambiguates region via `Locale` → a **pack key** (`en`, `pt-PT`, `pt-BR`, `es-ES`, `es-419`). `LanguagePackLoader` loads that pack's `lexicon.*.json` (vocab) + `config.*` (tense markers, spelled-out numbers, sleep patterns, negation) + the user's **personal overlay**, and builds an `NLNoteExtractor`. That extractor does **deterministic whole-token / contiguous-phrase matching** (Apple `NaturalLanguage`, no embeddings, no sentiment — Constitution VII) → the 6 signals: **mood, energy, focus, sleep, medications, side-effects**.

Two independent language axes (the key design idea):
- **UI language** = OS per-app setting (defaults to device language). Drives chrome only.
- **Content language** = auto-detected per check-in. Drives extraction. *A user can journal in Spanish under an English UI.*

**Voice ties them together:** Whisper auto-detects the spoken language during transcription; we capture that detected language and feed it to the extractor (reviving the currently-dead `language` param), so detection is consistent and not duplicated.

## Scope decisions (recommended + adopted — adjust at approval)

| Axis | Decision | Why |
|---|---|---|
| English | **one base `en`** (UK + USA) | UI strings are near-identical; defer `en-GB` spelling layer. Extractor: one `en` pack covers both. |
| Portuguese | `pt-PT` (exists) + **`pt-BR` (new)** | You named Brazil; pt-BR vocab differs enough to need its own pack + localization. |
| Spanish | `es-ES` (exists) + **`es-419`** (Latin America) | `es-419` is the correct LatAm umbrella; **reuse the existing `es-MX` pack as its initial vocab** (Mexico is representative), broaden later. |
| Voice | **multilingual** (Whisper auto-detect) | The app's premise is "speak your day"; English-only voice would strand PT/ES users. |
| UI override | **OS per-app language screen** (deep-link) | From the existing UI plan; `.environment(\.locale)` is broken for `String(localized:)`/`.alert`. |
| Extraction | **auto-detect per check-in, decoupled from UI** | Already built on PR #14. |

## Spec Kit

Run as a feature: **`/speckit-specify` → plan → tasks → implement**, numbered **023** (021 = multilingual extractor, 022 = view-audit remediation). Constitution gates: **VII** (deterministic extraction — per-language eval floors, lexicon-as-data, no NLEmbedding/sentiment), **X** (test-first for the pt-BR pack + voice-language threading), **VI** (on-device — Whisper multilingual stays local), **I** (modern SwiftUI/String Catalog).

## Phases

**P0 — Foundation: merge the extractor.** Merge `feat/nlp-multilang-demo` (PR #14) to trunk; `/code-review`; confirm 333 tests pass. **Sequencing hazard:** do localization string-wrapping (P2) **before** the `feat/spm-designsystem` View-extraction lands, or a moved `Text("…")` resolves `Bundle.main` and silently breaks. Coordinate or freeze that branch.

**P1 — Extractor + voice gap-fill (the genuinely new NLP work).**
- Add `Resources/lexicon.pt-BR.json` + `config.pt-BR.json` (Brazilian check-in vocab) and **`pt` region disambiguation** in `LanguageDetector` (region `BR` → `pt-BR`, else `pt-PT`) — mirror the existing `es-MX`/`es-ES` logic.
- Add **`es-419` selection** mapping to the existing `es-MX` pack (region-based), so "Latin America" resolves; flag pan-LatAm vocab broadening as follow-up.
- **Multilingual voice:** un-hardcode Whisper to **auto-detect** (`language = nil` → Whisper detects); capture the detected language from the result and thread it (revive the dead `language` param: [CheckInViewModel.swift:263,430](app-four/ViewModels/CheckInViewModel.swift#L263) → `ProcessingViewModel` → `NLNoteExtractor`/`LanguageDetector`). Apple Speech fallback: drive `SFSpeechRecognizer` from `Locale.current`, gated by `SFSpeechRecognizer.supportedLocales()` with `en-US` fallback.
- **Eval floors (Constitution VII):** establish baseline precision/recall for `pt-BR` and `es-419` against new per-language eval cases, ratchet to observed − 0.02; confirm English floors don't regress. Test-first per Principle X.
- *Reuse, don't rebuild:* `LanguageDetector`, `LanguagePackLoader`, `LanguageConfig`, the pack JSON contract (`specs/021-.../contracts/language-pack.md`), and the existing pt-PT/es-ES/es-MX packs as templates for pt-BR.

**P2 — UI localization infra + wrap all strings (from the existing UI plan, P1 there).** Create `app-four/Localizable.xcstrings`; `CFBundleLocalizations = [en]`; wrap ~280–350 strings — bare `LocalizedStringKey` literals extract automatically on build, the real work is `String`-typed call sites (`String(localized:)`), the **enum display labels** (`MoodLevel`/`EnergyLevel`/`FocusLevel` displayLabel+subtitle in `NoteExtraction.swift`, `AppEnums.TopicCategory`, `GlyphSignal.title`, `PromptPace`), and **53 accessibility labels/hints**. Keep user content (`journal text`, med/tag names) `Text(verbatim:)`. Delete the dead `AppSettings.defaultLanguage`. **Verify: pseudolanguage run** (Accented/Double-Length) — any plain English = a missed literal. Share the scheme.

**P3 — Translations (UI plan P2), all 5 UI localizations.** Add `es-ES`, `es-419`, `pt-PT`, `pt-BR` to `CFBundleLocalizations` + catalog; fill translations (`.xcloc` export per locale). Plurals via catalog "Vary by Plural" (audit the count strings in `InsightsViewModel+Signals`, `SettingsView`, `MoodLegend`). Confirm dates/numbers use `.formatted()`/`Date.FormatStyle` (fix the ~8 hardcoded `DateFormatter`s + the `["M","T","W","T","F","S","S"]` weekday header in `CalendarHeaderView`).

**P4 — Settings language row + speech locale (UI plan P3).** Add a gated Language deep-link row to `SettingsView` (`Bundle.main.localizations.filter { $0 != "Base" }.count > 1`) using the existing `openSettingsURLString` idiom. (Speech-locale work folded into P1's voice change.)

**P5 — Deferred.** SPM package catalogs (`Packages/SquirlSignals` gets its own `defaultLocalization` + `.xcstrings`) — owned by the `feat/spm-designsystem` View-extraction PR.

## Critical files

- **Extractor (P0/P1):** `Resources/lexicon.{en,pt-PT,pt-BR,es-ES,es-419}.json` + `config.*`; `Services/NoteExtraction/{LanguageDetector,LanguagePackLoader,LanguageConfig,NLNoteExtractor}.swift` (on PR #14); eval in `app-fourTests/Eval/`.
- **Voice (P1):** `Services/WhisperKit/WhisperKitTranscriptionService.swift:133`, `Services/Speech/SpeechTranscriptionService.swift:7`, `ViewModels/CheckInViewModel.swift:263,430`, `ViewModels/ProcessingViewModel.swift` (revive `language`).
- **UI (P2–P4):** `app-four/Localizable.xcstrings` (new), `Info.plist` (`CFBundleLocalizations`), `Views/` (~195 literals), `Models/{AppEnums,MoodLevel+Palette,AppSettings,PromptPace}.swift`, `Services/NoteExtraction/NoteExtraction.swift` (enum labels), `Views/SettingsView.swift` (language row).

## Verification (end-to-end)

1. **Extractor:** 6 reference check-ins (en, pt-PT, **pt-BR**, es-ES, **es-419**) assert correct signals; per-language eval floors hold; English floors not regressed; build + tests green.
2. **Voice:** speak a PT and an ES check-in on the simulator → transcribes in that language → detected language flows to the extractor → correct signals.
3. **UI pseudolanguage run** (primary gate): no plain English visible.
4. **Per-language UI:** App Language → es-ES/es-419/pt-PT/pt-BR; walk every screen; dates/numbers reformat.
5. **Device per-app screen:** Settings → Squirl → Language → switch → relaunch → chrome localized; row gated correctly.

## Out of scope

RTL (all LTR); `en-GB` spelling layer (one `en` base); localizing user journal content (verbatim); native pharmacy-brand review of packs (tracked under spec-021); pan-LatAm `es-419` vocab beyond the `es-MX` base (follow-up).

---
---

# Tri-Lens View-Layer Audit — app-four (SHIPPED as PR #15 — historical)

## Context

We want a full audit of app-four's view layer. The codebase is already modern
(148 Swift files, ~15.8k lines; **0 `AnyView`**, **0 `ObservableObject`**, **20
`@Observable`**), so the audit is **not** about API modernity — it targets
**architecture/altitude**, **code quality**, and **rendered visual design**.

Three skills pair as orthogonal lenses, agreed with the user:
- **Lens A — `swiftui-ui-patterns`** — architecture (ownership, sheets, navigation, composition). Static.
- **Lens B — `swiftui-pro`** — code quality / maintainability / perf APIs. Static.
- **Lens C — `ios-design-review`** — rendered visual design, HIG, a11y, AI-slop. **Runtime, on-device.**

The deliverable is **findings reports**, not code changes. No fixes are made in
this pass; fixes (if any) are a separate, user-approved follow-up.

## Scope

All view-layer code under `app-four/`:

| Group | Path | Files |
|---|---|---|
| Screens | `Views/` (+ `CheckIn`, `Insights`, `Feedback`, `Settings`, `Onboarding`, `Library`) | ~32 |
| Components | `Views/Components` | 23 |
| Design system | `DesignSystem/` (+ `Glyphs`) | 25 |
| View models | `ViewModels/` | 14 (audited with their owning views) |

Models/Services are in scope only where a view reaches into them.

## Phase 0 — Recon (DONE — captured here so the audit is reproducible)

Two Explore agents already mapped the layer. Real targets surfaced:

**Confirmed issues (will become findings):**
- **Chip duplication** — `Views/Components/Chip.swift` unifies topic+filter chips, but standalone `TopicChip.swift` (L3-19) and `FilterChip` (L21-39) still exist. Dead-code / retire-or-document. (Lens B)
- **3 sheets forward closures instead of `dismiss()` internally** — violates the skill's sheet rule:
  - `Views/Insights/InsightsView.swift:44` → `{ id in path.append(id) }`
  - `IssueReportView.swift:56` → mail-result handler
  - `MedicationLogSheet` callsites: `CheckInView.swift:34`, `MedicationBarView.swift:42` (Lens A)
- **Large units** — `CheckInViewModel.swift` (488L), `CheckInView.swift` (475L), `ExtractionReviewView.swift` (464L). Decomposition candidates. (Lens A+B)
- **No debouncing** on the audio-level stream (gate-only use). Confirm intentional. (Lens B)

**Already clean (audit confirms, doesn't re-litigate):**
- @Observable @MainActor VMs; `@State` init-injection; app-level `MedicationBarViewModel` via `@Environment`.
- Enum-modeled async state (`RecordingState`, `ProcessingState`, `PlaybackState`, `SummaryState`) + explicit `Task` cancellation.
- No live service calls in `body` (all in `.task`/`.onAppear`/`.onChange`).
- No AnyView, no flag-soup, `LazyVStack` + explicit `ForEach` ids in lists.
- Centralized design system (Palette/Theme/Typography/Spacing/Radius), Canvas glyphs via single `SignalGlyph` surface.

## Phase 1 — Lens A: `swiftui-ui-patterns` (architecture, static)

Grade each screen + its VM against the skill rubric: state ownership ("no
unnecessary view models" — interrogate the 14 VMs against SwiftData
`@Observable` models), `.sheet(item:)` vs `isPresented`, sheet ownership of
`dismiss()`, navigation ownership, composition / giant-view smell.
Order: VMs first (a redundant VM changes its view's audit), then giant views,
then presentation/nav.

## Phase 2 — Lens B: `swiftui-pro` (code quality, static)

Best-practices / maintainability / modern-API / perf review over the same
files. Owns: dead-code (Chip dup), API currency, render-cost in `body`, naming,
debounce question. Runs after/alongside Lens A on the same source.

## Phase 3 — Lens C: `ios-design-review` (visual, runtime, on-device)

**Runs AFTER Lens A+B (decision below), against a BOOTED SIMULATOR.**
Prerequisite: app built + `gstack-ios-qa-daemon` running + simulator booted
(observe-capability token). Cannot run in plan mode.
Simulator caveat: covers layout, spacing, typography, color hierarchy, and
Dynamic Type / VoiceOver a11y well; does NOT exercise real haptics or
true-hardware contrast (note any contrast finding as "verify on device"). The
A14/iPhone-12 minimum target is best confirmed on real hardware later if a
finding hinges on it.
Screenshots every screen, scores 10 dimensions 0-10 vs HIG + `DESIGN.md`,
AskUserQuestion on any score < 7. Writes its own report (see Deliverables).

## Sequencing decision (LOCKED)

**Static lenses (A+B) first → then runtime (C) on a booted simulator.**
Rationale: A/B may recommend decomposing `CheckInView`/`CheckInViewModel`;
auditing the rendered result of code about to be refactored wastes the visual
pass. So: produce the static `docs/audits` report first; run Lens C afterward
(ideally after any quick fixes land) so it grades the real UI.

## Dedup matrix (avoid triple-reporting where rubrics touch)

| Concern | Owner | Others suppress |
|---|---|---|
| Accessibility (static) | Lens B / `swift-accessibility-skill` | — |
| Accessibility (rendered: VoiceOver, Dynamic Type, contrast) | **Lens C dim 6** | Lens B notes only code-level a11y gaps |
| Performance (code/API) | Lens B | — |
| Performance (runtime jank) | out of scope here → `swiftui-performance-audit` if needed | — |
| Spacing/typography tokens (code) | Lens A/B (design-system structure) | — |
| Spacing/typography (rendered) | **Lens C dims 1-2** | — |

Each finding is owned by exactly one lens.

## Deliverables

- **Static (A+B):** `docs/audits/2026-06-25-views-audit.md` — severity-ranked
  (🔴 architecture/correctness · 🟡 maintainability · 🟢 polish), one row per
  finding: `[sev] file:line — rule — problem — fix`.
- **Runtime (C):** `~/.gstack/projects/<slug>/ios-design-review-<date>.md` —
  the skill writes this with inline screenshots + per-screen 0-10 scores.
- **Synthesis:** a one-page top-of-report summary tying recurring themes across
  all three lenses (e.g. "VM layer broadly redundant", "sheet-dismiss pattern
  inconsistent", "glyph sizing fails HIG at small Dynamic Type").

## Verification

The audit is complete when: each lens has produced its report; findings are
deduped per the matrix; every static finding carries file:line + severity + a
concrete fix; every visual finding carries a screenshot + score + "what makes it
a 10". Reproducibility: Phase 0 grep signals re-run identically, so the report
is a baseline that can be diffed over time.

## Resolved decisions

- **Run order:** static-first (Lens A+B), then visual (Lens C). LOCKED.
- **Lens C device:** booted simulator (real-hardware contrast/haptics deferred).
- **Outstanding at execution time:** confirm `gstack-ios-qa-daemon` is available
  and the app builds clean before Phase 3.
