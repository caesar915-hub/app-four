# Penpot Reproduction Spec: Squirl App Welcome Screen
**Source of Truth: Swift Code Analysis**
**Light Mode: Paper & Pollen UI (warm paper background)**
**Date: Phase 1 - Static Hi-Fi Mock**

---

## 1. PRESENTATION & FLOW

### 1.1 Presentation Mode
- **Full-screen Cover**: WelcomeView is presented via `.fullScreenCover(isPresented: $showOnboarding)` — SquirlApp.swift:65
- **One Single Screen**: No multi-step onboarding flow; one atomic welcome screen
- **Trigger**: Gated by `@AppSettings.hasCompletedOnboarding` flag (WelcomeViewModel.swift:24)
  - On first app launch (cold start): flag is `false` → WelcomeView shows
  - On tap "Start" button: flag is persisted to `true`, cover dismisses to RootTabView/Check-in hub
- **No Mic Permission Gate**: SquirlApp.swift:7–8 explicitly states "No microphone step, no model-download gate — permission is just-in-time and the model downloads in the background."
- **Model Download**: Happens asynchronously in the background (SquirlApp.swift:83, 99–130); does not block the welcome flow

---

## 2. LAYOUT: TOP-TO-BOTTOM STRUCTURE

### 2.1 Outer Container
- **ScrollView**: WelcomeView.swift:24 wraps `content` in ScrollView to handle Dynamic Type scaling (AX5+)
- **Background**: `Theme.background` (Paper & Pollen warm paper) — applies via `.ignoresSafeArea()` (WelcomeView.swift:30)
- **GeometryReader**: Ensures content minHeight = viewport height for perfect centering at normal text sizes (WelcomeView.swift:23, 27)
- **Content Frame**: Constrained to `Metrics.maxContentWidth` (600pt) for iPad readability (WelcomeView.swift:26)

### 2.2 Content VStack — Vertical Spacing
- **Root VStack Spacing**: `Spacing.section` (32pt) — WelcomeView.swift:34
- **Padding (Horizontal)**: `Spacing.xxl` (24pt) — WelcomeView.swift:61
- **Padding (Vertical)**: `Spacing.hero` (40pt) — WelcomeView.swift:62

### 2.3 Element Order (Top to Bottom)

#### A. Top Spacer
- `Spacer(minLength: Spacing.section)` — WelcomeView.swift:35
- **Height**: 32pt

#### B. Hero Glyph: CrescentRing
- **Component**: `CrescentRing()` — WelcomeView.swift:37
- **Dimensions**: 232pt × 232pt (fixed: `crescentSize: CGFloat = 232`, line 17)
- **State**: `.isActive = false` (default, WelcomeView only shows the "breathing" idle state, never recording spin)
- **Visual Description** (CrescentRing.swift):
  - Full circle (360°) with **AngularGradient** stroke
  - Gradient colors (top to bottom, via AngularGradient):
    - 0° (top-left): `Theme.meadowGreen` — light mode: `#5F8A4C`, dark: `#6E9A58`
    - 180° (bottom): `Theme.meadowAmber` — light mode: `#E0A33A`, dark: `#E8B255`
    - 360° (back to top): `Theme.meadowGreen`
  - Stroke Width: 22pt (CrescentRing.swift:7, default `lineWidth`)
  - Gradient Angle: startAngle = 270° (top), endAngle = 630° (full rotation)
  - Animation (idle/at rest):
    - Scale breathing: 1.0 → 1.035 → 1.0 over 5 seconds, repeating forever
    - Opacity breathing: 0.94 → 1.0 → 0.94 over 5 seconds, repeating forever (easeInOut curve)
  - Accessibility: `accessibilityHidden(true)` — decorative

#### C. Headline + Subtitle Group
- **Container**: VStack with `spacing: Spacing.m` (12pt) — WelcomeView.swift:41
- **Horizontal Padding**: `Spacing.l` (16pt) — WelcomeView.swift:53

**C.1 Headline**
- **Text**: "Welcome to Squirl" (verbatim) — WelcomeView.swift:42
- **Typography**: `Typography.largeTitle`
  - **Resolved**: SF Pro, 34pt, **bold** weight (UIFont.Weight.bold)
  - **Text Style** (for Dynamic Type scaling): `largeTitle`
  - **Color**: `Theme.textPrimary` (light: `#221E16`, dark: `#F3EEE0`)
  - **Alignment**: `.multilineTextAlignment(.center)` — centered
  - **Accessibility**: `.accessibilityAddTraits(.isHeader)` — marked as heading

**C.2 Subtitle/Body
- **Text**: "A calm place to speak your day. Everything stays on this device." (verbatim) — WelcomeView.swift:48
- **Typography**: `Typography.body`
  - **Resolved**: SF Pro, 16pt, **regular** weight (UIFont.Weight.regular)
  - **Text Style** (for Dynamic Type): `body`
  - **Color**: `Theme.textSecondary` (light: `#7A7361`, dark: `#9A917C`)
  - **Alignment**: `.multilineTextAlignment(.center)` — centered

#### D. Middle Spacer
- `Spacer(minLength: Spacing.section)` — WelcomeView.swift:55
- **Height**: 32pt

#### E. Primary Action Button
- **Button Label**: "Start" (verbatim) — WelcomeView.swift:57
- **Button Style**: `.primary` (calls `PrimaryButtonStyle`) — WelcomeView.swift:58
- **Accessibility Hint**: "Opens your check-in" — WelcomeView.swift:59

**Button Styling** (from Buttons.swift, PrimaryButtonStyle):
- **Font**: `Typography.headline`
  - **Resolved**: SF Pro, 16pt, **semibold** weight
- **Foreground**: `.white` (solid white text)
- **Frame**: `.frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)` (Buttons.swift:10)
  - **Width**: Fills available width (constrained by outer padding)
  - **Min Height**: 44pt (minimum iOS tap target)
- **Background Fill**: `Theme.meadowGradient` (LinearGradient) — Buttons.swift:12
  - **Gradient Colors**: `[meadowGreen, meadowAmber]`
  - **Direction**: `startPoint: .topLeading` → `endPoint: .bottomTrailing` (~120° angle, top-left to bottom-right)
  - **Light Mode Gradient**: `#5F8A4C` (top-left) → `#E0A33A` (bottom-right)
  - **Dark Mode Gradient**: `#6E9A58` → `#E8B255`
- **Corner Radius**: `Radius.button` (16pt) — Buttons.swift:12
- **Shadow**: Applied via `.shadow()` — Buttons.swift:13
  - **Color**: `Theme.meadowAmber` at 34% opacity (0.34)
  - **Radius**: 12pt
  - **Y Offset**: 5pt (shadow drops downward)
- **Pressed State Opacity**: 0.9 (slightly dimmed when tapped) — Buttons.swift:14
- **Horizontal Padding**: `Spacing.l` (16pt) — Buttons.swift:11

#### F. Bottom Spacer
- Implicit trailing spacer at bottom (VStack stack fills remaining height via ScrollView frame)

---

## 3. VISUAL STYLE & TOKENS RESOLVED

### 3.1 Background
- **Color Token**: `Theme.background`
- **Light Mode (Paper)**: `#F6F1E7` (warm cream/beige)
- **Dark Mode (Loam)**: `#14130F` (warm dark brown)
- **Area**: Full screen, ignores safe area (top + bottom)

### 3.2 Spacing Summary
| Token Name | Point Value | Usage in Welcome |
|-----------|------------|-----------------|
| `Spacing.xs` | 4pt | (not used on welcome) |
| `Spacing.s` | 8pt | (not used on welcome) |
| `Spacing.m` | 12pt | Gap between headline + subtitle in text group |
| `Spacing.l` | 16pt | Horizontal padding inside text group; button horizontal padding |
| `Spacing.xl` | 20pt | (not used on welcome) |
| `Spacing.xxl` | 24pt | Outer content horizontal padding |
| `Spacing.section` | 32pt | VStack spacing between major blocks; top/middle spacers |
| `Spacing.hero` | 40pt | Vertical padding (top + bottom) of entire content block |

### 3.3 Typography Summary
| Element | Font | Size | Weight | Color (Light) | Color (Dark) | Text Style (DT) |
|---------|------|------|--------|---------------|-------------|-----------------|
| Headline "Welcome to Squirl" | SF Pro | 34pt | Bold | `#221E16` | `#F3EEE0` | `largeTitle` |
| Subtitle "A calm place…" | SF Pro | 16pt | Regular | `#7A7361` | `#9A917C` | `body` |
| Button Label "Start" | SF Pro | 16pt | Semibold | White | White | (none, fixed) |

### 3.4 Color Palette Resolved
| Token Name | Light Hex | Dark Hex | Usage |
|-----------|-----------|----------|-------|
| `Theme.background` | `#F6F1E7` | `#14130F` | Screen background (Paper/Loam) |
| `Theme.textPrimary` | `#221E16` | `#F3EEE0` | Headline text |
| `Theme.textSecondary` | `#7A7361` | `#9A917C` | Subtitle text |
| `Theme.meadowGreen` | `#5F8A4C` | `#6E9A58` | CrescentRing top; button gradient start |
| `Theme.meadowAmber` | `#E0A33A` | `#E8B255` | CrescentRing bottom; button gradient end; button shadow |

### 3.5 Other Token Values
| Token Name | Value | Usage |
|-----------|-------|-------|
| `Radius.button` | 16pt | Button corner radius |
| `Metrics.minTapTarget` | 44pt | Button min height |
| `Metrics.maxContentWidth` | 600pt | Content width constraint (iPad) |

---

## 4. CUSTOM COMPONENTS & GLYPHS

### 4.1 CrescentRing Component
**Source**: `/Users/caesargrey/Projects/app-four/app-four/Views/CheckIn/CrescentRing.swift`

**Purpose**: Paper & Pollen check-in ring hero; decorative breathing animation at rest.

**Geometry**:
- Base shape: `Circle()` with `.trim(from: 0, to: 1.0)` (full 360°)
- Stroke style: `.stroke()` with `lineWidth: 22pt` and `lineCap: .butt`
- Padding: `lineWidth / 2` (11pt) on all sides to accommodate stroke

**Gradient (AngularGradient)**:
```swift
AngularGradient(
  gradient: Gradient(stops: [
    .init(color: Theme.meadowGreen, location: 0.00),    // top-left (~0°)
    .init(color: Theme.meadowAmber, location: 0.50),    // bottom (~180°)
    .init(color: Theme.meadowGreen, location: 1.00),    // back to top (~360°)
  ]),
  center: .center,
  startAngle: .degrees(270),      // top (12 o'clock)
  endAngle: .degrees(270 + 360)   // full rotation
)
```

**Animation (Idle/At Rest)** — CrescentRing.swift:49–56:
- **Scale**: `1.0 → 1.035 → 1.0` (3.5% expansion)
- **Opacity**: `0.94 → 1.0 → 0.94`
- **Curve**: `easeInOut` over 5 seconds, repeating forever
- **Reduce Motion Aware**: If accessibility setting enabled, animation is `nil` (no motion)

**Accessibility**: `accessibilityHidden(true)` — purely decorative, not announced

---

## 5. INTERACTION & STATES

### 5.1 Welcome Screen States

#### State 1: At Rest (Normal)
- All elements visible and stable
- CrescentRing breathing animation running
- Button interactive, cursor shows tap affordance

#### State 2: Button Pressed
- Button opacity: 0.9 (slightly dimmed)
- CrescentRing continues breathing (not affected by button state)

#### State 3: Post-Tap
- Haptic feedback triggered: `Haptics.success()` (UIKit success feedback) — WelcomeView.swift:66
- Animation: `withAnimation(Motion.smooth)` applied to dismiss transition (0.4s smooth curve) — WelcomeView.swift:67
- `WelcomeViewModel.complete()` persists `AppSettings.hasCompletedOnboarding = true` — WelcomeViewModel.swift:21–30
- Closure `onComplete()` invoked → cover dismisses to Check-in hub — WelcomeView.swift:70

#### No "Model Downloading" Overlay
- Model downloads happen in background (SquirlApp.swift:83, 103–130)
- Welcome flow **never blocks** on this; user can tap Start immediately
- Welcome dismisses regardless of model state (FR-005 idempotency: "signals completion even when the persist write fails")

### 5.2 Accessibility Considerations
- Headline tagged as header: `.accessibilityAddTraits(.isHeader)` — helps screen readers
- Button labeled "Start"; hint "Opens your check-in" — hints at next screen
- CrescentRing marked as `.accessibilityHidden(true)` — not announced (decorative)
- Respects `@Environment(\.accessibilityReduceMotion)` — breathing animation disabled when Reduce Motion is on

---

## 6. ANIMATION & MOTION

### 6.1 Entrance Animation
- None explicitly; view appears via `.fullScreenCover()` which has default SwiftUI transition

### 6.2 CrescentRing Breathing (Idle)
- **Enabled**: Always on WelcomeView (`.isActive = false` by default)
- **Duration**: 5 seconds
- **Curve**: `easeInOut`
- **Effect**:
  - Scale: 1.0 → 1.035 → 1.0 (subtle expansion + contraction, like breathing)
  - Opacity: 0.94 → 1.0 → 0.94 (subtle fade in/out, like a pulse)
- **Looping**: `repeatForever(autoreverses: true)` (bounces back and forth)

### 6.3 Dismiss Animation
- **Trigger**: User taps "Start" button
- **Animation Applied**: `withAnimation(Motion.smooth)` — WelcomeView.swift:67
  - `Motion.smooth` = `.smooth(duration: 0.4)` (Motion.swift:12)
  - Smooth curve, 400ms
- **What Animates**: The view model's `didComplete` flag flips, triggering the cover's isPresented binding to update
- **Effect**: Smooth fade/scale transition from WelcomeView to Check-in hub

---

## 7. SF SYMBOLS & CUSTOM GLYPHS

### 7.1 Symbols Used
- **None**: WelcomeView does not use any SF Symbol icons (system or custom)
- The only hero is the **CrescentRing**, which is a hand-rolled custom shape (not an SF Symbol)

### 7.2 Custom Glyphs
- **CrescentRing**: Custom SwiftUI shape (Circle + trim + AngularGradient stroke)

---

## 8. RESPONSIVE & DYNAMIC TYPE

### 8.1 Layout Responsiveness
- **ScrollView + GeometryReader**: Ensures content is readable and centered across all screen sizes
  - At normal text sizes: minHeight fill centers everything vertically
  - At large Dynamic Type sizes (AX5+): ScrollView allows vertical scrolling to keep button reachable
- **Max Content Width**: `Metrics.maxContentWidth` (600pt) — iPad-friendly inset layout

### 8.2 Dynamic Type Scaling
- **Headline**: Scales with `largeTitle` text style
- **Subtitle**: Scales with `body` text style
- **Button Label**: Scales with `headline` text style (but button frame has minHeight 44pt, so text won't make button shorter)
- **Spacing**: Fixed (base-4/base-8 grid); does not scale with Dynamic Type

### 8.3 Safe Area & Notches
- Background ignores safe area (top + bottom bleeds)
- Content respects safe area (padding does not apply; ScrollView manages insets)

---

## 9. PENPOT-SPECIFIC REPRODUCTION NOTES

### 9.1 Design Complexity
- **Single Artboard/Frame**: One static welcome screen
- **No Multi-Step Flow**: Onboarding is one atomic page

### 9.2 Gradient Reproduction in Penpot
- **LinearGradient (Button)**: 
  - Start point: top-left (0%, 0%)
  - End point: bottom-right (100%, 100%)
  - Stop 1: `#5F8A4C` (light) / `#6E9A58` (dark) at 0%
  - Stop 2: `#E0A33A` (light) / `#E8B255` (dark) at 100%
  
- **AngularGradient (CrescentRing)**:
  - Center: circle center
  - Start angle: 270° (top / 12 o'clock)
  - End angle: 630° (full rotation + 270°)
  - Stop 1: `#5F8A4C` (light) / `#6E9A58` (dark) at 0°
  - Stop 2: `#E0A33A` (light) / `#E8B255` (dark) at 180° (bottom)
  - Stop 3: `#5F8A4C` (light) / `#6E9A58` (dark) at 360° (back to top)
  - **Penpot Workaround**: Penpot may not support AngularGradient directly; use radial gradient or multi-layer approach with conic gradient simulation

### 9.3 Shadow Reproduction (Button)
- **Color**: `Theme.meadowAmber` @ 34% opacity (`#E0A33A` light, `#E8B255` dark, α = 0.34)
- **Blur Radius**: 12pt
- **Y Offset**: 5pt (drop shadow, no X offset)
- **Spread**: 0pt (no expansion)

### 9.4 Animation Notes (Not in Static Mock)
- CrescentRing breathing animation (5s easeInOut, scale 1.0–1.035, opacity 0.94–1.0) is **not** captured in static Penpot, but should be documented as a prototype animation spec
- Button pressed state (0.9 opacity) can be shown as a variant/state

### 9.5 Text & Line Height
- All fonts use SF Pro (standard system font), no custom typefaces
- All text is left-aligned within their containers, with `.multilineTextAlignment(.center)` applied to containers

### 9.6 Light Mode Lock
- This spec is for **light mode (Paper & Pollen)**
- For dark mode, swap all color tokens to their dark-hex values (provided in tables above)

---

## 10. MOTION.SMOOTH CURVE REFERENCE

- **Curve Type**: SwiftUI `.smooth(duration: 0.4)`
- **Duration**: 400 milliseconds
- **Easing**: SwiftUI's "smooth" curve (typically a gentle ease-in-out blend)
- **Use Case**: Dismiss animation when user taps "Start"
- **Source**: Motion.swift:12

---

## 11. PERSISTED STATE & ONBOARDING GATE

### 11.1 AppSettings Data Model
- **Key**: `AppSettings.hasCompletedOnboarding` (boolean, default `false`)
- **Persistence**: Stored in SwiftData (`@Model`)
- **On Completion**: Toggled to `true` by `WelcomeViewModel.complete()`
- **Read on Launch**: `RootContainerView.hasCompletedOnboarding` (SquirlApp.swift:56–58) queries the DB; if `false`, `showOnboarding` is set to `true`

### 11.2 Debug Override
- In debug builds, if `debugMockMode` UserDefault is `true`, onboarding is skipped (SquirlApp.swift:74)
- Command-line argument `-skipOnboarding` also skips (SquirlApp.swift:73)

---

## 12. COMPREHENSIVE TOKEN TABLE

| Category | Token Name | Point / Hex (Light) | Hex (Dark) | Applied To |
|----------|-----------|-----------------|-----------|-----------|
| **Typography** | largeTitle | 34pt Bold | N/A | Headline "Welcome to Squirl" |
| | body | 16pt Regular | N/A | Subtitle "A calm place..." |
| | headline | 16pt Semibold | N/A | Button "Start" label |
| **Color** | Theme.background | #F6F1E7 | #14130F | Screen background |
| | Theme.textPrimary | #221E16 | #F3EEE0 | Headline |
| | Theme.textSecondary | #7A7361 | #9A917C | Subtitle |
| | Theme.meadowGreen | #5F8A4C | #6E9A58 | CrescentRing, button gradient, focus states |
| | Theme.meadowAmber | #E0A33A | #E8B255 | CrescentRing, button gradient, shadow |
| **Spacing** | .xxl | 24pt | — | Outer horizontal padding |
| | .l | 16pt | — | Inner text group padding, button padding |
| | .m | 12pt | — | Headline–subtitle gap |
| | .section | 32pt | — | VStack spacing, spacer height |
| | .hero | 40pt | — | Vertical content padding |
| **Radius** | button | 16pt | — | Button corner radius |
| **Metrics** | minTapTarget | 44pt | — | Button min height |
| | maxContentWidth | 600pt | — | Content width constraint |
| **Opacity** | — | 0.34 | — | Button shadow color opacity |
| | — | 0.9 | — | Button pressed state opacity |
| **Animation** | Motion.smooth | 0.4s | — | Dismiss transition |
| | CrescentRing breathing | 5s easeInOut | — | Scale 1.0–1.035, opacity 0.94–1.0 |

---

## 13. SOURCE FILES

### Swift Source
- **WelcomeView.swift**: `/Users/caesargrey/Projects/app-four/app-four/Views/Onboarding/WelcomeView.swift` (lines 1–78)
- **WelcomeViewModel.swift**: `/Users/caesargrey/Projects/app-four/app-four/Views/Onboarding/WelcomeViewModel.swift` (lines 1–31)
- **SquirlApp.swift**: `/Users/caesargrey/Projects/app-four/app-four/App/SquirlApp.swift` (lines 47–97, 65–79)
- **CrescentRing.swift**: `/Users/caesargrey/Projects/app-four/app-four/Views/CheckIn/CrescentRing.swift` (lines 1–66)

### Design System Source
- **Typography.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift` (lines 1–72)
- **Theme.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Theme.swift` (lines 1–44)
- **Spacing.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Spacing.swift` (lines 1–25)
- **Palette.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Palette.swift` (lines 1–16)
- **Buttons.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Buttons.swift` (lines 1–41)
- **Radius.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Radius.swift` (lines 1–13)
- **Metrics.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift` (lines 1–68)
- **Motion.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Motion.swift` (lines 1–15)
- **Opacity.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Opacity.swift` (lines 1–16)
- **Haptics.swift**: `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Haptics.swift` (lines 1–16)

---

## 14. SUMMARY FOR PENPOT REPRODUCTION

**Single Frame Required**: 1 artboard (the Welcome screen)

**Key Gotchas**:
1. **AngularGradient on CrescentRing**: Penpot may not have native conic/angular gradient support; may require workaround (multi-layer shapes, gradient approximation, or symbolic link to custom SVG)
2. **Breathing Animation**: Not captured in static mock; document as a separate animation spec with 5s easeInOut curve, scale 1.0–1.035, opacity 0.94–1.0
3. **Button Shadow**: 12pt blur + 5pt drop with 34% amber — ensure shadow is not system default (may be softer/harder)
4. **Gradient Direction (Button)**: Top-left to bottom-right (~120° angle); must be exact
5. **Dynamic Type Scaling**: Mention in handoff that this design is at **100% text size** (standard); scaling applies at runtime
6. **Safe Area**: Content inset but background bleeds (do not inset background in Penpot)
7. **Micro-interactions**: Button pressed opacity (0.9), CrescentRing breath, dismiss animation (0.4s smooth) — all out of scope for static Penpot but should have separate motion spec

---

**End of Spec**
