<!-- Created: 2026-08-31 01:18 (WEST) · Updated: 2026-09-28 14:24 (WEST) -->
# Shipaton Sprint Backlog — September 2026

**The board for 2026-09-01 → 2026-09-30.** `docs/BACKLOG.md` is frozen for the sprint — read it for history, never edit it.

This holds **state** (where each ticket stands). The plan lives in [SEPTEMBER_PLAN.md](SEPTEMBER_PLAN.md); the *why* lives in [DEVLOG.md](DEVLOG.md). Ticket IDs match SEPTEMBER_PLAN and are stable once assigned — never renumber.

**Stages:** 💡 Idea → 📐 Planned → 🔨 In code → ✅ Shipped · 🧊 Deferred to October

---

## Changelog

Newest first. **Keep to 15 rows** — older rows drop off; the devlog holds the narrative. Never let this become a paragraph.

| When | What changed |
|---|---|
| 2026-09-28 14:24 | UI epic scoped from the pen (spec 057): UI-01–03, UI-06–18 → 🔨 In code on `feat/057-ui-refresh` (Phase A docs + B1–B4 built, 552 tests green); UI-04/05/05b/19 partial (deviations in DEVLOG); UI-20–54 → 📐 Planned |
| 2026-08-31 01:39 | Sprint tooling landed (`/morning`, `/evening`, constitution 2.2.0). **No ticket stages moved** — RC-08 + RC-10 still 🔨 In code, uncommitted |
| 2026-08-31 01:18 | Board created. RC-08 + RC-10 → 🔨 In code; RC-01 → ⏭️ Today (blocking, owner) |

---

## ⏭️ Today

| ID | Item | Owner | Why now |
|---|---|---|---|
| **RC-01** | Activate Paid Applications Agreement + banking + tax | Owner | **Blocks the entire epic.** Until it is Active, App Store Connect shows no Subscriptions section at all. Up to 24h to propagate. Owner is checking ASC → Business. |
| **RC-10** | Paywall mockup — owner approval | Owner | Gates RC-18. Mockup built ([055-paywall.html](../html-mockups/055-paywall.html), 4 screens); needs a look before any SwiftUI. |
| — | Decide product ID scheme + the two prices | Owner | RC-06 needs both Monday. **Product IDs are permanent.** |

## 🔨 In code

| ID | Item | Branch | Notes |
|---|---|---|---|
| **RC-08** | Privacy manifest + policy revision | `main` (uncommitted) | `PrivacyInfo.xcprivacy` declares `PurchaseHistory`, not linked, not tracking, AppFunctionality + Analytics. Lint-clean; verified present inside the built `.app`. Policy rewritten and **staged — do not deploy until the paid build ships**. |
| **RC-10** | Paywall mockup (4 screens) | `main` (uncommitted) | Hard paywall · trial-ended · fail-open · settings. Built on **New Look** tokens (spec 033), dark + Dynamic Type AX3/AX5 toggles. Awaiting owner approval. |
| **UI-01** | DESIGN.md v2 (pen-derived) + CLAUDE.md/PRODUCT.md reconciled + pen exports committed | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-02** | Decisions D1–D26 answered and logged | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-03** | Plan → Epic UI table, BACKLOG 🧊 rows, DEVLOG | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-04** | Pre-flight: docs on main → #44 → #45 → #41 resolved → 055 merge + 1.1 (RC ETA) → 053/054 archived → ritual → worktrees removed, 057 re-cut | `feat/057-ui-refresh` | docs on branch, not `main`; #44/#45/#41/055 remain owner-gated |
| **UI-05** | Spec Kit 057 foundations | `feat/057-ui-refresh` | spec/plan/tasks hand-written before the PR |
| **UI-05b** | Design-system HTML mockup (Constitution I for Phase B atoms) | `feat/057-ui-refresh` | replaced by SwiftUI previews + simulator screenshots (owner away) |
| **UI-06** | Colour tokens + dark pairs + aliases + AA tests (PR B1 = full-app visual change) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-07** | Typography roles + alias map (old names kept until UI-49) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-08** | Layout tokens + card modifiers + heading atoms (0-consumer deletions only) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-09** | Button styles (Frame 3) replace three old styles + `PaywallButtonStyle` | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-10** | BillChip + ChipRow (display 6/6; interactive ≥ 44 pt pitch, D-K6) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-11** | NavPill, ToggleRow, RadioRow, SegmentedPicker, InfoRow | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-12** | Mood/energy/focus glyph redraw + identity icons | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-13** | Sleep moon + `SleepLevel` ramp/label (`sleepIndigo` aliased) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-14** | Medication glyphs + ProgressTrack + SignalMiniBar | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-15** | `CheckInRing` + Welcome migration (`CrescentRing` kept until UI-21) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-16** | `LevelTilePicker` | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-17** | SF Symbol icon map (PR B2) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-18** | FloatingTabBar + AddButton + root wiring (`ChromeVisibilityKey`; FAB hidden on hub) | `feat/057-ui-refresh` | built + full serial suite green; owner device QA pending |
| **UI-19** | Design gallery (`SandboxApp/Sources/DesignGallery.swift`) + snapshot pack attached to PRs | `feat/057-ui-refresh` | SandboxApp gallery deferred to the PR |

## 📐 Planned

Full ticket detail, estimates and acceptance criteria live in [SEPTEMBER_PLAN.md](SEPTEMBER_PLAN.md). This is the stage view only.

| ID | Item | Blocked by |
|---|---|---|
| RC-02 | Small Business Program enrolment (30% → 15%) | RC-01 |
| RC-03 | RevenueCat project + app + public SDK key | — |
| RC-04 | **In-App Purchase Key (`.p8`)** — mandatory for StoreKit 2 | RC-03 |
| RC-05 | Verify Restore Behavior = "Transfer to new App User ID" | RC-03 |
| RC-06 | ASC subscription group + monthly & annual products | RC-01 |
| RC-07 | Import products → `pro` entitlement + `default` offering | RC-04, RC-06 |
| RC-09 | Email `shipaton@revenuecat.com` re TestFlight vs public release | — |
| RC-11 | SPM dependency + In-App Purchase capability | RC-03 |
| RC-12 | Hardened `configure` + **prewarming guard** (#4623) | RC-11 |
| RC-13 | `PurchaseService` protocol + `EntitlementState` tri-state | — |
| RC-14 | `RevenueCatPurchaseService` + DI wiring | RC-12, RC-13 |
| RC-15 | **Grandfather flag** — must ship in the paid build | — |
| RC-16 | **App-level gate + fail-open path** — highest-risk ticket | RC-14, RC-15 |
| RC-17 | Paywall placement in onboarding + trial-ended state | RC-16 |
| RC-18 | Custom SwiftUI paywall (4 screens) | RC-10, RC-14 |
| RC-19 | Settings: Restore Purchases + Manage Subscription | RC-14 |
| RC-20 | Bundle EULA + privacy as native **offline** views | RC-08 |
| RC-21 | Unit tests via fakes; never configure the SDK in tests | RC-13 |
| RC-22 | Wire `PurchasesDiagnostics.checkSDKHealth()` (DEBUG) | RC-12 |
| RC-23 | Local StoreKit config testing | RC-18 |
| RC-24 | **Sandbox end-to-end** incl. offline-while-subscribed | RC-07, RC-18 |
| RC-25 | Accessibility pass on the paywall (AX5, VoiceOver, 44pt) | RC-18 |
| RC-26 | **Refresh ASC screenshots + description** (Guideline 2.3.1) | RC-18 |
| RC-27 | `/code-review` on the diff | RC-25 |
| RC-28 | **Owner device QA** — non-negotiable | RC-27 |
| RC-29 | Deploy policy · set label · archive · **submit with IAP attached** | RC-28 |
| BIP-01 | Daily #Shipaton post | — |
| BIP-02 | Collect post links + engagement | BIP-01 |
| BIP-03 | "How building in public helped" write-up | BIP-01 |
| UI-20 | Spec Kit 058 check-in trio | UI-19 |
| UI-21 | Check-in A idle hub (+ `CrescentRing`/`crescentDiameter` deleted) | UI-20 |
| UI-22 | Check-in B listening (motion per D-R2) | UI-21, UI-34 |
| UI-23 | Check-in C saved | UI-22 |
| UI-24 | Spec Kit 059 Calendar (incl. expanded previous-day card, Q25b) | UI-23 |
| UI-25 | Calendar / Mood Journal (private `Chip`/`DoseTrack` deleted first) | UI-24, UI-35, UI-36, UI-37 |
| UI-26 | Spec Kit 060 Day Details + Edit | UI-25 |
| UI-27 | Day Details (#45 regenerate hunk deleted here) | UI-26, UI-38, UI-54 |
| UI-28 | Edit Check-In (private `ChipGroup` deleted first) | UI-27, UI-39 |
| UI-29 | Spec Kit 061 Insights | UI-28, D12, UI-40 |
| UI-30 | Insights (private `ConnectionCard`/`GatedCard`/`MiniBar` deleted first) | UI-29, UI-40, UI-41 |
| UI-31 | Spec Kit 062 Settings + wave-2 secondary surfaces | UI-30, UI-04 (#41) |
| UI-32 | Settings (`ModelDownloadRow` restyled, state machine untouched; `SettingsChip` deleted first) | UI-31, UI-42 |
| UI-33a | Secondary surfaces, wave 1 (Log Dose, composer, onboarding restyle) | UI-20/24, UI-09–16 |
| UI-33b | Secondary surfaces, wave 2 (recovery key, 055 paywall surfaces, Acknowledgements restyle) | UI-31 |
| UI-34 | `CheckInViewModel.flowProgress` (test-first) | UI-20 |
| UI-35 | `DoseStatus` hoist + status semantics (D10) | UI-24 |
| UI-36 | `DayCardSummary` dose + `sleepLevel` | UI-13 |
| UI-37 | `displayLabel` in `TimelineRow` + AX | UI-04 |
| UI-38 | `RecordingDetailViewModel.relativeTitle/subtitle` | UI-26 |
| UI-39 | `ExtractionReviewViewModel.isDirty`, `medicationRows`, `cancelIfUnsaved()` (D21) | UI-26 |
| UI-40 | Sleep × Mood gate on `decodedSleepLevel` — own PR `fix/insights-sleep-mood-gate`, 1.1.x-shippable | UI-04 |
| UI-41 | Bubble diameter · rhythm tint · range-bar span fns · caption case | UI-29 |
| UI-42 | `medicationBarShowTakenTime` / `ShowEndTime` keys + `titleLine` | UI-31 |
| UI-43 | Summary correction persistence (deferred, outside waves 1–2) | owner |
| UI-44 | Dead-code sweep (refresh-orphaned code only; `Constants.swift` never) | UI-32 |
| UI-45 | Dark-mode pass (wave-2 screens) | UI-33b |
| UI-46 | Dynamic Type / AX pass (wave-2 screens) | UI-45 |
| UI-47 | VoiceOver + Reduce Motion pass (wave-2 screens) | UI-46 |
| UI-48 | Copy normalisation sweep (pen-screen strings only) | UI-32 |
| UI-49 | Token + typography alias deletion; Complexity row closed | UI-48 |
| UI-50 | PR gate (recurring, ~25 PRs; risk #11 workaround) | — |
| UI-51 | Release 1.2 (wave 1) | UI-25, UI-33a, UI-53 |
| UI-52 | Release 1.3 (wave 2) | UI-49 |
| UI-53 | Wave-1 dark / AX / VoiceOver mini-pass (A/B/C + Calendar + Log Dose/composer) | UI-25, UI-33a |
| UI-54 | Single `formattedDuration` — own PR `fix/duration-format` | UI-04 |
| LLM-01 | *TBD — scope after Sep 4* | RC epic |

## 💡 Ideas

| Item | Notes |
|---|---|
| JIRA/Linear CSV export | Column mapping defined in SEPTEMBER_PLAN §JIRA export. Needs a board and project key. Blocked on normalised epic tables (done) + owner supplying the key. |
| Peace Prize submission | ADHD mental-health angle is a genuine fit. Costs one write-up, no code. |

## ✅ Shipped

*Nothing yet — the sprint opens 2026-09-01.*

## 🧊 Deferred to October

| Item | Why deferred |
|---|---|
| Spec 053 — insights shape views | Parked in `stash@{0}`. 1.1 ships from `main`; 053 does not gate it (owner decision 2026-08-30). |
| Spec 054 — settings topic hub | Parked in `stash@{0}` alongside 053. |
| Multiple subscription tiers | Cut to fit the 5-day RevenueCat window. |
| Experiments / Targeting / A-B tests | Named nowhere in the Shipaton rules — no category rewards them. |
| Customer Center · win-back offers · promo codes | The 7-day trial already satisfies the judge-access requirement. |
