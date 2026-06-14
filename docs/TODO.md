# app-four TODO — foundational & pre-launch

Action list for the **load-bearing gaps** surfaced 2026-06-14 (senior-iOS + PM doc audit).
This is distinct from [BACKLOG.md](BACKLOG.md): the backlog tracks *features* by stage; this
tracks *foundations* that must exist before real users arrive. Convert relative dates on sight.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · **P0** ship-blocker · **P1** before App Store (6 Jul 2026) · **P2** soon

---

## 🔴 P0 — do before TestFlight (18 Jun 2026)

- [ ] **SwiftData migration strategy + implementation.** Today there is **no** `VersionedSchema`/`SchemaMigrationPlan`, and `App/AppModelContainer.swift` **wipes the store on any schema conflict**. Fine pre-release; the first schema change after testers have data = silent data loss. For a journaling app that is unforgivable.
  - [ ] Introduce `VersionedSchema` (snapshot the current 6-entity schema as v1).
  - [ ] Add a `SchemaMigrationPlan` with a lightweight migration stage.
  - [ ] Remove / gate the wipe-on-conflict fallback for non-DEBUG builds.
  - [ ] Document in `docs/engineering/migrations.md` (or chosen location).

## 🟠 P1 — before App Store submission (6 Jul 2026)

- [ ] **Privacy & data-handling doc.** Health-adjacent data. Cover: on-device guarantees, `PrivacyInfo.xcprivacy` rationale, iCloud-backup exclusion, App Store privacy nutrition label answers, and the medical-claims line (review risk). One page.
- [ ] **PRD-lite + one success metric.** Problem statement, target persona (ADHD-who, specifically), value prop, and a single north-star / activation metric. Decide measurement approach (privacy-light) — there is currently **zero** product analytics instrumentation.
- [ ] **Monetization decision.** No StoreKit / pricing model exists and the store date is fixed. Free / subscription / one-time IAP? Decide as a backlog entry; it gates the App Store listing. (Decision, not a doc.)

## 🟡 P2 — soon

- [ ] **Testing/quality doc.** Capture the known landmines that currently live only in agent memory: test suite is not parallel-safe (run serial), CLI `xcodebuild` env recovery steps. One page so they survive a context reset.
- [ ] **Beta feedback loop.** v0.8 dogfood + v0.9 private beta are scheduled with no intake plan. Define: TestFlight feedback → triage → BACKLOG. Lightweight.
- [x] **Docs reorg** (2026-06-14). Consolidated `.md` files under `docs/` (product/ engineering/ design/ archive/) — see [README.md](README.md). Pulled ARCHITECTURE + UI_REQUIREMENTS out of the app source tree (they were being bundled into the shipped `.app`); excluded the NoteExtraction README via a build-membership exception. Planning docs (BACKLOG/DEVLOG/TODO) intentionally kept at `docs/` root so `/recap` + CLAUDE paths stay valid.

## ⚪ Deferred (premature for now)

- CI/CD pipeline · ADRs · service-contract docs · competitive analysis · GTM/ASO · risk register.
  Revisit once the product is proven on yourself.

---

## Notes / decisions log
- 2026-06-14 — Audit rationale: write only docs that prevent an *irreversible mistake* (migration, privacy/App-Review) or *force a dodged decision* (PRD metric, monetization). Avoid doc bureaucracy for a solo, AI-built, pre-launch app.
