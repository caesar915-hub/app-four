<!--
SYNC IMPACT REPORT
==================
Version change: 2.0.0 → 2.1.0
Rationale: Added Principle XI (Architectural Exhaustiveness) to ensure detailed and comprehensive documentation in plans and specs.
Modified sections:
  - Added Principle XI
  - Governance updated to require compliance with Principles I-XI
Templates requiring updates:
  - .specify/templates/plan-template.md — Constitution Check references updated
Deferred TODOs: none
-->

# app-four Constitution

## Core Principles

### I. SwiftUI-First (NON-NEGOTIABLE)

All UI MUST be implemented in SwiftUI using modern APIs (iOS 26+ / SwiftData /
Swift Concurrency). UIKit is permitted only where SwiftUI has no equivalent API.
No backwards-compatibility shims, no deprecated APIs, no `@objc` bridging unless
unavoidable. New views MUST start as an HTML mockup before SwiftUI implementation.

### II. Test-Build-Ship (NON-NEGOTIABLE)

Every code change MUST pass a build and the full test suite before being
reported as done. This is non-negotiable and non-skippable — no exceptions for
"small" changes. Use `ios-debugger-agent` (XcodeBuildMCP) to verify. A PR is
not ready until CI is green on the branch.

### III. Correctness Over Speed

The codebase MUST prefer correct, complete implementations over fast or partial
ones. No silent corner-cutting: if a tradeoff is made it MUST be surfaced
explicitly. Dead code, backwards-compat shims, and placeholder stubs MUST NOT be
merged. Comments are written only when the WHY is non-obvious — not to describe
what the code does.

### IV. Minimal Surface

Features MUST NOT introduce abstractions, helpers, or error-handling paths
beyond what the task explicitly requires. Three similar lines beat a premature
abstraction. No half-finished implementations, no feature flags for hypothetical
future requirements. Complexity MUST be justified in the Complexity Tracking
table of the plan before it is introduced.

### V. Solo Git Discipline

This is a solo project; all code is written by Claude. `main` MUST always be
releasable. Every code change MUST go through a feature branch (`feat/…` or
`fix/…`) and a PR with `/code-review` run before merging. Trivial non-code
changes (typos, BACKLOG.md, CLAUDE.md) MAY go directly to `main`. TestFlight
uploads MUST be tagged (`git tag vX.Y.Z`) immediately after the upload commit.
Feature branches MUST NOT stack unmerged for long — growing merge-conflict risk
MUST be flagged.

### VI. On-Device Privacy (NON-NEGOTIABLE)

All transcription, extraction, and storage MUST run on-device. There is no
account, no server, and no cloud by default. Raw audio and derived health, mood,
or medication data MUST NOT leave the device. iCloud sync, if added, MUST be
opt-in and OFF by default, and the SwiftData store MUST stay excluded from iCloud
backup (`isExcludedFromBackupKey`) because transcripts and medication data are
sensitive health information. Diagnostics and logging MUST record counts,
durations, and token estimates ONLY — never transcript text or medication
content.

### VII. On-Device LLM Extraction

The extraction pipeline (`MLXJournalService`) uses Llama 3.2 1B (4-bit quantised)
via MLX-Swift, running 100% on-device off the main actor. The curated lexicon
(`Resources/lexicon.json`, 718 entries) is retained as the source of truth for
ADHD-specific vocabulary: it seeds the LLM system prompt and provides the
canonical allowlists for Swift-side validation (Layer 4). Signal output MUST be
validated against `Levels.swift` enum rawValues — any value not in the canonical
set is clamped to `nil`. Memory lifecycle MUST follow Peak Shaving: Whisper
unloads before Llama loads, and `os_proc_available_memory()` is checked before
loading weights. The `SummarizationService` protocol is the integration boundary;
downstream consumers MUST remain unaware of the extraction backend.

### VIII. Service-Oriented Architecture

Every external capability (audio, transcription, model management, storage,
summarization) MUST sit behind a protocol in `Services/`, injected via the
`AppDependencies`/`AppServices` DI container, so implementations are swappable and
mockable at the seam. ViewModels MUST be `@MainActor @Observable`, hold no
persistence logic, and dispatch CPU/IO-heavy work off the main actor. Model
lifecycle MUST be RAM-isolated: load lazily, then unload (free Metal/CoreML
buffers) BEFORE downstream extraction runs.

### IX. Pre-Release Data Posture

The schema is pre-release: there is no versioned migration plan, and a schema
conflict is recovered by wiping and rebuilding the store. The schema MUST remain
CloudKit-COMPATIBLE — every non-relationship attribute optional or defaulted, no
`@Attribute(.unique)` — to preserve the future opt-in sync path even though
CloudKit is not configured. Mock vs. real data is partitioned by the `isMockData`
boolean, not by separate stores. Introducing a unique constraint or a required
(non-defaulted) attribute MUST be justified against the CloudKit path in the
plan's Complexity Tracking before it is merged.

### X. Test-First Development (NON-NEGOTIABLE)

Testable logic — SwiftData `@Model` types, `Services/` implementations,
`@MainActor @Observable` view-models, and the `MLXJournalService` extraction
pipeline — MUST be built test-first: a failing test (**RED**) is written and
confirmed to fail BEFORE the implementation that makes it pass (**GREEN**), after
which the code is refactored with the test staying green. Tests for this logic are
MANDATORY, not optional — a `/speckit-tasks` breakdown that omits them, or an
implementation task ordered before its test, VIOLATES this constitution. SwiftUI
views are EXEMPT from unit-test-first: they are verified by build + on-simulator
run (Principle II) and an HTML mockup (Principle I); snapshot tests are encouraged,
not required. Tests use **Swift Testing** (`@Test`, `#expect`/`#require`). This
complements Principle II (the full suite stays green before "done") and Principle
VII (Layer 4 validation and signal enum conformance).

### XI. Architectural Exhaustiveness

Plans and specs must not leave implementation details to the imagination. Every edge case, error state, and data structure must be explicitly defined before proceeding to tasks. Summaries are strictly forbidden; exhaustive detail is required.

## Technology Stack

- **Language**: Swift 6+ (strict concurrency enabled)
- **UI**: SwiftUI (iOS 26+)
- **Persistence**: SwiftData
- **Async**: Swift Concurrency (`async/await`, `Actor`, `AsyncStream`)
- **On-device ML**: WhisperKit running OpenAI Whisper Small (`openai_whisper-small`)
  for transcription; Llama 3.2 1B (4-bit quantised) via MLX-Swift
  (`MLXJournalService`) for extraction. `AIModelType` has two cases: `.whisper`
  and `.llama`. Lexicon (`lexicon.json`, 718 entries) seeds prompts and validation.
- **Testing**: Swift Testing (`@Test`/`#expect`) for unit + integration, test-first per Principle X; XCUITest for UI flows where warranted
- **Platform**: iOS (primary), iPadOS (secondary)
- **Target / identity**: Xcode target & module `app-four`; bundle id
  `Rythm-App.app-four`; display name **Squirl** (`@main` type `WhisperNotesApp`
  is a harmless legacy internal name)
- **Tooling**: Xcode, XcodeBuildMCP, gcloud (claude-dev VM), gh CLI

## Development Workflow

- **Backlog**: `docs/BACKLOG.md` is the single registry. Update stage on every
  state change: 💡 Idea → 📐 Plan → 🔨 In code → ✅ Shipped.
- **Session start**: Read `docs/BACKLOG.md` and `docs/DEVLOG.md` before any work.
- **New UI**: HTML mockup MUST precede SwiftUI implementation.
- **Devlog**: Log to `docs/DEVLOG.md` at real checkpoints (decisions, directions,
  investigations concluded, items shipped) — the WHY, not every edit.
- **PR flow**: Branch → build + tests pass → open PR → `/code-review` → human
  approves/merges. No force-push to `main`.
- **Spec-kit flow**: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement`. Run `/speckit-clarify` before specifying if intent is
  underspecified.

## Governance

This constitution supersedes all other practices documented in this repository.
Amendments require:
1. A clear rationale (what changed and why).
2. A version bump per semantic versioning (MAJOR: principle removal/redefinition;
   MINOR: new principle or section; PATCH: clarification/wording).
3. A sync pass over all spec-kit templates to verify alignment.
4. Update to `LAST_AMENDED_DATE`.

All specs and plans MUST include a Constitution Check gate that verifies
compliance with Principles I–XI before Phase 0 research proceeds.

Runtime development guidance lives in `CLAUDE.md` at the repository root. The
Spec Kit operating procedure lives in `docs/SPECKIT.md`.

**Version**: 2.1.0 | **Ratified**: 2026-06-15 | **Last Amended**: 2026-08-11
