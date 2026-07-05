# Quickstart Validation: Nutrition & Exercise Signals on the Day Card (Demo)

How to prove the feature works end-to-end. Prerequisites: branch `feat/nutrition-signals-demo`, Xcode 16+, iOS 26 device (owner-run; no simulator per house rules).

## 1. Unit suite (owner-run)

```bash
xcodebuild -project app-four.xcodeproj -scheme app-four \
  -destination 'generic/platform=iOS' build          # compile gate

# full test suite via Xcode (⌘U) or owner's usual test destination
```

Expected: build clean; all suites green, including the six nutrition test files in [contracts/interfaces.md §9](contracts/interfaces.md). The RED→GREEN history per Constitution X is visible in the task ordering (tests committed failing first).

## 2. Demo-data path (any device, no Health data needed)

1. Settings → TestServicesView → enable `debugMockMode` → Generate mock data.
2. Calendar tab:
   - Folded cards across ~30 days show `fork.knife N kcal · cup N mg` tokens after energy/focus/med (V3). ~2 days have no tokens (seeded skip days). → **SC-001**
   - Expand a seeded day: food/exercise rows interleaved with check-in rows at correct times, clay/teal lanes, no chevrons; totals footer with `—` where a metric is absent; heart provenance glyph. → **SC-002, FR-004**
   - Expand a nutrition-only day (no check-ins): header + full-width footer + rows, expands despite zero nodes. → **FR-005**
   - Med-days show visibly lower caffeine than unmedicated days (seed correlation).
3. Toggle `debugMockMode` OFF → nutrition disappears on next calendar visit. → **US3 AC-3**

## 3. Real-data path (owner device with Health access)

1. Insights → open a day → accept the HealthKit primer (copy now mentions nutrition and workouts) → grant.
2. In Apple Health, log: a food entry with kcal+protein, a caffeine entry, and (via a workout app or Watch) a workout.
3. Return to Calendar: today shows real values in tokens, rows, and footer; footer kcal-out equals the workout's active energy (workouts-only rule). Cross-check numbers against the Health app. → **SC-003**
4. Turn mock mode ON: today still shows real values (real-wins-per-day); other days show seeded values. → **FR-009**
5. Confirm at no point did a permission sheet appear on the Calendar tab. → **SC-006, FR-010**

## 4. Regression + accessibility pass

- A day with zero nutrition renders byte-identical to current behavior (compare against a pre-feature build screenshot). → **SC-004, FR-014**
- VoiceOver: folded card label includes calories + caffeine; each event row reads name/time/values as one element; footer reads all four metrics + source. → **SC-005, FR-011**
- Dark mode: clay/teal dark variants render (`#CB8266` / `#5FAEA5`).
- Largest Dynamic Type: folded token line wraps without truncation.

## Sign-off gates (house rules)

1. Build + full suite green (Constitution II) — owner runs tests on device/Xcode per no-simulator rule.
2. `/code-review` on the PR diff.
3. Owner device QA (sections 2–4 above) — non-negotiable before any merge.
