<!-- Created: 2026-07-01 18:55 (WEST) · Updated: 2026-07-01 18:55 (WEST) -->
# Plan — Rebuild the Squirl Figma design system on the OFFICIAL Figma MCP (`use_figma`)

> Supersedes the `figma-bridge` build approach in [figma-ds-reproduction-plan.md](figma-ds-reproduction-plan.md). Same source of truth (`tokens.json` from the Swift package); different, far more capable toolchain.

## Context / why switch
The first reproduction was built on **`figma-bridge`** (`@gethopp/figma-mcp-bridge`). It works but is fundamentally limited and fragile:
- **Per-node typed RPC** → each element = several calls; a screen = 100–300 calls; agents stall (~600s watchdog) and the socket drops roughly every ~200 calls.
- **No native Variables / Styles / Components** → "components" are duplicated copies that drift; tokens are a picture, not linked.
- **No vector paths** → glyphs are rasterized PNGs (`create_image`), not editable/recolorable; dark mode can't recolor them.
- Result: an independent QA scored the bridge build **2.9/5** ("not shippable"); blockers were fixed by hand, but DS/Color came out malformed and the whole thing was a slow, drop-prone grind on degraded infra.

The **official Figma MCP** exposes **`use_figma`** (arbitrary Figma **Plugin-API JavaScript**). That is the root-cause fix:
- **Many nodes per call** (a whole frame/component in one JS call) → ~10–100× fewer round-trips → no per-node stalls, far less socket exposure.
- **Native Variables** (real design tokens) with **light+dark modes**, **scopes**, and **iOS code-syntax** (`Color.bgPrimary`) → dark mode "for free" + Dev-Mode handoff back to SwiftUI.
- **Native Styles + Components/variant-sets** → true instances (no drift; fixes the instance-parity problem).
- **Vector glyphs** via `createNodeFromSvg` → editable, recolorable, crisp at any size (no PNG@3x; dashes/masks/strokes survive).
- The cached canonical skills **`figma-generate-library`**, **`figma-swiftui`**, **`figma-use`** are built for exactly this and encode the proven order + helpers.

## Feasibility (the "is it possible?" answer) — YES, with one setup gate
- **Verified this session:** `use_figma` is **NOT currently connected**. Only `figma-bridge` is in app-four's `mcpServers` (`~/.claude.json`). No official `figma`/`mcp.figma.com` server, no `use_figma` tool.
- **Gate:** install/enable the official Figma MCP that provides `use_figma` (Plugin-API execution). This is an owner/admin step — the agent cannot self-install or authenticate it. Confirm via `/mcp` that a server exposing `use_figma` shows connected, and that ToolSearch surfaces a `use_figma` (or equivalent `execute_code`) tool.
- **Nuance to verify at setup:** the hosted `mcp.figma.com` (Dev-Mode) MCP is largely **read-only**; the **write** path (`use_figma` Plugin-API JS) is what the canonical skills need. Confirm which server/mode provides write access before committing. If only read is available, we stay on figma-bridge (fallback).

## What carries over (no rework)
- **`tokens.json`** — code-derived, 90/90 mechanically verified against the Swift package. Becomes native Variables directly.
- **18 glyph geometries** (sprout×5, bolt×5, aperture×5, bed, capsule, empty) — the SVG source we already generated; import as **true vectors** now (not PNG).
- **Per-screen specs + golden table** in [figma-ds-reproduction-plan.md](figma-ds-reproduction-plan.md) — Part A (foundations/components) + Part B (10 screens), all with `file:line` provenance.
- **Deviations list** (pencil vs DESIGN.md, badgeTint usage, Energy/Focus ramp hexes, etc.).
- Lessons/quirks captured (create_text color/font/content pitfalls are moot under `use_figma`).

## Approach
- **Fresh native build in a new Figma file (or new page)** via `figma-generate-library` + `figma-swiftui`, driven by `tokens.json`. Do NOT migrate the bridge-built "picture" — rebuild it correctly as a linked system. Keep the bridge file as a visual reference until parity is reached, then retire it.

## Phases (mirror the canonical `figma-generate-library` order)
0. **Setup + spike (gate):** enable official Figma MCP; confirm `use_figma` write works with a 1-call test (create a frame + a variable + a vector from SVG). Confirm SF Pro/SF Mono availability (or record the substitute).
1. **Foundations = Variables first** (hard rule: no token → no component): color collection with **Light + Dark modes**, scopes per token, **iOS code-syntax**; number variables for spacing/radius; text styles for the 13 type roles (SF Pro / SF Mono). Source: `tokens.json` (`hexToRgb`, modes, `codeSyntax`).
2. **File structure:** pages — Cover → Getting Started → Foundations → `---` → Components → `---` → Screens (canonical naming/separators).
3. **Components (one at a time, variables-bound):** the 16 masters as **native components/variant-sets**; the 18 glyphs as **vector icon components** (recolorable via bound fills / INSTANCE_SWAP). Bind every fill/size to a variable.
4. **Screens (instance components):** the 10 views (incl. the 2 heavy ones — Recording detail, Edit) built from real instances; dark mode via a single **mode toggle** (no re-render).
5. **Verify:** variable bindings resolve; Dev-Mode inspect shows `Color.x` code-syntax; dark-mode toggle correct; a11y/contrast; per-screen visual diff vs the SwiftUI ground-truth.

## Reusable helpers (from the canonical skill, only under `use_figma`)
`createSemanticTokens.js`, `createComponentWithVariants.js`, `bindVariablesToComponent.js`, `createNodeFromSvg` for glyphs, `validateCreation.js`, `rehydrateState.js` (state ledger for long runs). Prefer these over hand-rolled code.

## Verification / acceptance
- Every token is a **native Variable** with light+dark modes + iOS code-syntax (Dev-Mode handoff works).
- Components are **real instances** (change master → propagates); zero divergent copies.
- Glyphs are **vector** (recolor test passes in both modes).
- All 10 screens present; dark mode via mode switch; independent QA ≥ 4.5/5.

## Risks
- **Setup feasibility is the gating unknown** — if `use_figma` write access can't be enabled, fall back to figma-bridge (current ceiling = the "picture" already built).
- Font availability (SF Pro/SF Mono) in the target file — confirm at Phase 0.
- Scope: full native rebuild is a real effort; but throughput is far higher than figma-bridge, so wall-clock should be much shorter and stall-free.

## Immediate next step
Owner: enable the official Figma MCP (`use_figma`) for this session, then run `/mcp` to confirm it's connected. Ping me and I'll start at Phase 0.
