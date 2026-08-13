# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Feature Definition & Scope

<!--
  ACTION REQUIRED: Do NOT provide a brief summary. Per Principle XI (Architectural Exhaustiveness),
  you must provide an exhaustive definition of the feature's requirements, scope, and the complete 
  technical approach from research.
-->

[Exhaustive extraction from feature spec: primary requirements, constraints, and complete technical approach]

## Technical Context

<!--
  ACTION REQUIRED: Do not provide one-word answers. Write at least one paragraph 
  for each section below explaining the *why* and *how* of the architectural choices.
-->

### 1. Language & Runtime Environment
[Detail the specific language versions, compiler flags, and runtime constraints]

### 2. Core Dependencies & Frameworks
[Exhaustively list required frameworks. Explain *why* they were chosen over alternatives and how they will be integrated]

### 3. State Management & Data Flow
[Describe exactly how state moves through the application (e.g. from UI -> ViewModel -> Service -> Storage). Identify potential bottlenecks]

### 4. Storage & Persistence Strategy
[If applicable, detail the exact storage mechanism, schema migration strategy, and data lifecycle. If N/A, explain why no state is persisted]

### 5. Performance & Constraints
[Define hard boundaries for memory, CPU, and latency. How will this feature impact the app's overall footprint?]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Mark each PASS / FAIL / N-A and justify any FAIL in Complexity Tracking. See
`.specify/memory/constitution.md` (v2.1.0).

- [ ] **I. SwiftUI-First** — UI is SwiftUI on modern APIs (iOS 26+); no UIKit
      unless no SwiftUI equivalent; new views have an HTML mockup first.
- [ ] **II. Test-Build-Ship** — plan produces a buildable, fully-tested change;
      no step ships unverified.
- [ ] **III. Correctness Over Speed** — no dead code, compat shims, or stubs; any
      tradeoff is surfaced explicitly.
- [ ] **IV. Minimal Surface** — no abstractions/flags beyond what the task needs;
      added complexity justified below.
- [ ] **V. Solo Git Discipline** — work is one revertable feature on a `feat/…` or
      `fix/…` branch, `/code-review` before merge, `main` stays releasable.
- [ ] **VI. On-Device Privacy** — no audio/health/mood/med data leaves the device;
      no cloud by default; logs are counts/durations only.
- [ ] **VIII. Service-Oriented Architecture** — new capabilities behind a `Services/`
      protocol via `AppDependencies`; `@MainActor @Observable` VMs; heavy work off-main.
- [ ] **IX. Pre-Release Data Posture** — schema stays CloudKit-compatible (optional/
      defaulted, no `@Attribute(.unique)`); any unique/required attribute justified.
- [ ] **X. Test-First Development** — logic (models, services, view-models, NLP
      extraction) is built test-first (RED→GREEN→refactor) with Swift Testing; tests
      are MANDATORY, ordered before implementation; SwiftUI views exempt (build + run).
- [ ] **XI. Architectural Exhaustiveness** — Plans and specs must not leave implementation
      details to the imagination. Every edge case, error state, and data structure must be
      explicitly defined before proceeding to tasks. Summaries are strictly forbidden; exhaustive
      detail is required.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

### File Manifest & Responsibilities

<!--
  ACTION REQUIRED: For every NEW or MODIFIED file in the tree above, create a row in the table below.
  You MUST define the exact single-responsibility of the file and its primary functions/structs.
-->

| File Path | Responsibility | Key Structs / Functions / Protocols |
|-----------|----------------|-------------------------------------|
| `path/to/file` | [Deep explanation of responsibility] | [API surface, e.g. `class XYZ`, `func abc()`] |

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
