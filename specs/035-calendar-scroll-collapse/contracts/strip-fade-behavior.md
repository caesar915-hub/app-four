<!-- Created: 2026-07-16 14:05 (WEST) · Updated: 2026-07-16 14:41 (WEST) -->
# UI Behavior Contract — strip fade ↔ scroll ↔ title (spec-035)

The externally observable contract between the user's scroll gesture and the Calendar tab's chrome.
Consumed by `CalendarStripFadeTests` (C1–C8 are directly unit-testable; C9–C12 are device-QA assertions).

| # | Given | When | Then |
|---|---|---|---|
| C1 | list at rest (`offset = 0`) | — | strip opacity **1.0**, title hidden |
| C2 | any `offset ≤ 24` (dead zone), incl. negative rubber-band | scrolling | progress **0**, opacity **1.0** — bit-exact, no flicker |
| C3 | `offset = deadZone + band/2` | scrolling | progress **0.5** ± quantization (0.01), opacity **0.5** |
| C4 | `offset ≥ stripHeight` (week or month height) | scrolling | progress **1.0**, opacity **0** — fade completes exactly as the strip clears |
| C5 | `stripHeight = 0` (pre-measurement frame) | any offset | band floors at `minFadeDistance` (44) — finite, no div-by-zero, no instant collapse |
| C6 | any inputs | — | progress is clamped to [0, 1] and **floor**-quantized to 1/100 (Equatable dedupe without ever reporting full collapse early — nearest-rounding would hit 1.0 half a quantum before the strip clears, violating C4; caught RED→GREEN 2026-07-16) |
| C7 | `progress = 0.79` / `0.80` | — | `showsTitle` **false** / **true** (boundary exact) |
| C8 | week (~130pt) vs expanded month (~290pt) | same relative travel | both reach progress 1.0 at their own `stripHeight` — band scales with height |
| C9 | strip partially faded | user taps a visible date cell | selection works; list returns to top; strip returns to opacity 1 (device) |
| C10 | any scroll state | — | medication bar position/opacity/behavior pixel-identical to pre-change build (device) |
| C11 | strip fully faded | VoiceOver swipes | strip **not** focusable; compact title announced (device) |
| C12 | Reduce Motion ON | scroll through the band | fade still tracks the finger; title appears/disappears with **no** animation (device) |
