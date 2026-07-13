---
name: deep-plan-review
description: Use when planning a non-trivial task where correctness matters more than speed (architecture, migrations, reproductions, anything with unverified tool/API assumptions or stale docs). Runs a multi-agent loop — parallel exploration, a draft plan, adversarial + capability review, independent skill-informed reviews, user-resolved forks, then a merged hardened plan. Invoke before committing to an implementation plan.
---

# Deep Plan Review

A reusable methodology for producing a plan you can trust: parallel research → draft → adversarial review → skill-informed review → resolve forks with the user → merge → gate. It trades tokens/time for correctness. Use it when a wrong plan is expensive; skip it for trivial edits.

> Origin: distilled from the app-four "code-derived Figma design system" planning session (2026-06-30), where it caught a token-schema blocker, a stale-doc extraction hazard, and a misframed tool limit that turned out to be a tool *choice*.

## When to use
- Multi-area or uncertain-scope work; architecture or migration decisions.
- Any plan resting on **tool / API / MCP capability assumptions** ("the tool can't do X").
- Domains where **docs may have drifted from code** (treat code as truth).
- Reproductions / "1:1 fidelity" work that needs an objective acceptance bar.

Skip for typos, single-file changes, or work already fully specified.

## The flow (six phases)

### 1. Explore (parallel, read-only)
Launch up to **3 Explore agents in one message** to gather facts grounded in **primary sources** — `file:line`, command output, schemas — never memory. Give each a distinct area (e.g. "feature A code", "feature B code", "shared tokens/config"). Demand exact values with provenance, not loose summaries. Reconcile any doc claim against the code; **code/primary-source wins**.

### 2. Draft
Write a first plan from the findings into a single plan file. State the goal, the approach, the constraints, and the build order. Capture exact values (the golden table) so the plan is self-contained.

### 3. Adversarial + capability review (parallel, read-only)
Two agents:
- **Skeptic** — hunt gaps, wrong values, wrong hierarchy, ordering mistakes, precision risks. Prioritize blocker / major / minor with a concrete fix each, quoting `file:line`.
- **Capability verifier** — inspect the **actual tool/MCP/API schemas** (e.g. via ToolSearch / reading definitions). Confirm or refute every "the tool can/can't do X" assumption. A claimed *platform* limit is often just a *tool* limit — verify before designing around it.

### 4. Skill-informed review (N independent agents, read-only)
Have **N independent agents each read the relevant installed skill(s)** in full, then cross-check and improve the plan against that standard of rigor. Give them diverse lenses (methodology/tooling, fidelity/assets, process/completeness). They work independently — do not let them coordinate. Watch for the highest-value finding: an existing skill/toolchain that already does the task, or a constraint the plan misframed.

### 5. Resolve forks with the user
When reviews surface a genuine decision the user owns (toolchain A vs B, scope, fidelity bar), use **AskUserQuestion** — recommendation first, honest tradeoffs, concrete previews. Do not silently pick a load-bearing fork.

### 6. Merge → gate
Fold every blocker/major into the plan (cite the source). Re-review if the changes are large. Then request approval. Keep iterating draft↔review until no blocker/major remains.

## Principles to bake into every plan
- **Primary-source-as-truth.** Reconcile stale docs/comments against code; list the discrepancies as a "deviations & flags-to-owner" section so reviewers don't "correct" intentional choices.
- **Verify tool limits, don't assume them.** Inspect schemas. Reframe "platform can't" → "this tool can't (here's the one that can)".
- **A fidelity claim needs a referent.** "1:1 / matches" is unfalsifiable without a ground-truth artifact to diff against. Capture one.
- **Define a termination rubric.** Objective blocker/major/minor + tolerances so review→correction loops can actually stop. Prefer mechanical gates (value diffs) over eyeball checks.
- **Serialize on shared single-resource channels.** One socket / one file / one external session ⇒ serialize mutations; parallelize only analysis.
- **State ledger for long runs.** Persist a logical-key→id map so a multi-call build survives drops/context resets and can resume.
- **Mechanical extraction over hand-copy.** When mirroring values, generate them (compiled dump / script) with a fail-on-diff gate; don't transcribe by eye.

## Quick checklist (TodoWrite these)
- [ ] 1–3 Explore agents dispatched; findings have `file:line` provenance
- [ ] Draft plan written to a single file
- [ ] Skeptic review + capability/schema verification done; blockers/majors listed
- [ ] N skill-informed reviews done (each read the skill in full)
- [ ] Forks resolved with the user (AskUserQuestion)
- [ ] All blocker/major folded in with citations; deviations section present
- [ ] Acceptance rubric + verification gates defined
- [ ] Approval requested

## Anti-patterns
- Asking clarifying questions *before* the skill/exploration check.
- Treating a planning doc / changelog as current state instead of verifying via primary sources.
- Designing around an assumed tool limitation without inspecting the schema.
- A review loop with no defined "done" → it oscillates or never converges.
- Hand-authoring a values table that a script could emit and diff.
