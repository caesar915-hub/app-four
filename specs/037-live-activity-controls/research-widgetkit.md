<!-- Created: 2026-07-16 20:22 (WEST) · Updated: 2026-07-16 20:22 (WEST) -->
# 037 — WidgetKit + ActivityKit deep research (Apple-doc-verified)

Addendum to `research.md` (D1–D19). Every claim below is grounded in an Apple
documentation page fetched this session via the `/tutorials/data/...json` API
(the HTML pages are client-rendered SPAs and return only a title to a fetcher).
This exists to de-risk T001–T004 (target/Info.plist wiring) and T017/T024/T026
(the WidgetKit views) before any Swift is built.

## Sources (all fetched 2026-07-16)

- LiveActivityIntent — https://developer.apple.com/documentation/appintents/liveactivityintent
- AppIntent.authenticationPolicy — https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy
- IntentAuthenticationPolicy.requiresAuthentication — https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requiresauthentication
- Adding interactivity to widgets and Live Activities — https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- Displaying live data with Live Activities — https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- DynamicIsland — https://developer.apple.com/documentation/widgetkit/dynamicisland
- DynamicIslandExpandedRegion — https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedregion
- Starting/updating Live Activities with push — https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- Text(timerInterval:pauseTime:…) — https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)
- NSSupportsLiveActivities — https://developer.apple.com/documentation/bundleresources/information-property-list/nssupportsliveactivities

---

## 1. The load-bearing mechanism — VERIFIED ✅

> "In general, your app needs to be in the foreground to start a Live Activity.
> However, you can use a `LiveActivityIntent` and start the Live Activity in its
> `perform()` method. When the system performs the intent, the system launches
> your app process **without opening the app**, performs the intent…"
> — *LiveActivityIntent* overview

- `protocol LiveActivityIntent : SystemIntent` (→ `AppIntent`, `PersistentlyIdentifiable`, `Sendable`). **iOS 17.0+**.
- Consequence for us: STOP / PAUSE / RESUME `perform()` runs **in the app process**, so it reaches the singleton `AudioRecordingServiceImpl`, the live `AVAudioRecorder`, and the SwiftData `ModelContext`. This is the entire premise of the feature and it is documented, not inferred. (Confirms research D7/D8.)

## 2. Running while locked — VERIFIED default, ONE thing to device-prove ⚠️

- `static var authenticationPolicy: IntentAuthenticationPolicy { get }` defaults to **`.alwaysAllowed`** — *"A policy that allows the app intent to run at any time, including when the device is locked."* (*AppIntent.authenticationPolicy*)
- `.requiresAuthentication` forces an unlock; you may only override a schema policy to be **stricter**, never weaker (build error otherwise).
- **Contradiction to reconcile on-device.** The interactivity guide also states, generally:
  > "On locked devices, buttons and toggles are **inactive until the user authenticates and unlocks** their device."
  This blanket sentence covers plain-`AppIntent` widget buttons; `LiveActivityIntent` + the `.alwaysAllowed` default is the documented path that runs while locked (this is how first-party timer / delivery / sports Live Activities pause from the Lock Screen without Face ID).
- **Decision:** build with the default `.alwaysAllowed`. Make **the first US1 device-QA gate**: "does tapping *Stop & save* on the Lock Screen fire `perform()` with no Face ID?" If a given iOS build still demands auth, US1 degrades to tap → authenticate → runs (still functional, not a data-loss path). Everything downstream is unaffected. This is the single assumption worth proving before building US2/US3.

## 3. Data model + 4 KB budget — VERIFIED ✅

- Shape confirmed: `struct …Attributes: ActivityAttributes { struct ContentState: Codable & Hashable { … }; let <static> }`.
- Hard limit: static + dynamic combined **≤ 4 KB**. Our `ContentState` = `phase` (enum) + `pausedAt` (`Date?`) + static `startedAt`/`cap` — well under. No content ever added (FR-016).
- A Live Activity **cannot access the network or location** (sandbox). We need neither.

## 4. Self-updating timer — VERIFIED ✅ (why ContentState carries no elapsed value)

```swift
init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil,
     countsDown: Bool = true, showsHours: Bool = true)   // iOS 16.0+
```

- Renders `startedAt ... (startedAt + cap)` with `countsDown: false` for a count-**up** elapsed clock; the system redraws it on-device — **no per-second app wake, no ActivityKit update per tick**.
- `pauseTime:` freezes the display at a date. Passing `pausedAt` when `phase == .paused` gives us the frozen timer for free. This is exactly why the data-model keeps the timer out of `ContentState`.

## 5. Lifecycle API — VERIFIED ✅ (drives `LiveActivityController` impl, T010)

| Op | Call | Notes |
|----|------|-------|
| Gate | `ActivityAuthorizationInfo().areActivitiesEnabled` → `Bool` | no-op `begin()` when false (FR-014 / SC-007) |
| Start | `Activity.request(attributes:content:pushType:)` → `Activity<A>` | `content: ActivityContent(state:staleDate:relevanceScore:)`; **`pushType: nil`** (local-only, no APNs) |
| Update | `await activity.update(ActivityContent(state:…))` | one call per phase change (begin→recording, pause, resume) |
| End | `await activity.end(ActivityContent(state:.init(phase:.ended)), dismissalPolicy: .immediate)` | `.immediate` clears in seconds (SC-005); `.default` would linger ≤4 h |
| Recover | `Activity<CheckInActivityAttributes>.activities` | iterate on launch, `end(.immediate)` any orphan → `endAllStale()` (research D15) |

## 6. Widget UI surface — VERIFIED ✅ (T017/T026)

- `ActivityConfiguration(for: CheckInActivityAttributes.self) { context in <LockScreen> } dynamicIsland: { context in … }` — a `Widget` living **in the extension**. `context.state` / `context.attributes` / `context.isStale`.
- `DynamicIsland(expanded:compactLeading:compactTrailing:minimal:)`.
- `DynamicIslandExpandedRegion(_ position:)` positions: **`.leading`, `.trailing`, `.center`, `.bottom`** (`.leading`/`.trailing` sit beside the TrueDepth camera).
- **Buttons are allowed only in the Lock Screen presentation and the *expanded* Dynamic Island** — never in compact/minimal (those are tap-to-expand). Confirms mockup + research D5.

## 7. Interactive buttons — VERIFIED ✅ (T016/T023)

- `Button(intent: StopRecordingIntent()) { Label("Stop & save", systemImage: "stop.fill") }`. For a Live Activity the intent **must adopt `LiveActivityIntent`** (not plain `AppIntent`).
- > "Make sure any code that's necessary for the timeline update runs **before you return** from `perform()`. …use `await` … then `return`."
  → the finalize/save **must be fully awaited inside `perform()`**, wrapped in a `beginBackgroundTask` assertion (research D9). Returning early = truncated save = lost capture.
- "Interactions with a button or toggle always guarantee a timeline reload" — the widget refreshes from `context.state` after `perform()`; we drive that via `LiveActivityController.update(...)`.

## 8. Info.plist / entitlements — VERIFIED ✅ (T003)

- **`NSSupportsLiveActivities` = `YES`** in the **app target** Info.plist. (Xcode-16 synchronized folder → set via *Target ▸ Info ▸ Custom iOS Target Properties*.)
- **Not needed:** `NSSupportsLiveActivitiesFrequentUpdates` (we push a handful of local updates, not a stream), APNs push token, `com.apple.developer.live-activity` is auto-managed by the capability.

## 9. Duration ceiling — non-issue

- Live Activity stays active up to ~8 h and lingers ≤12 h. Our recording cap is minutes; we `end(.immediate)` on finalize. Never near the ceiling.

---

## Readiness verdict

- **Design + logic layer (mine): ready and now doc-verified.** `CheckInActivityAttributes` (ContentState = phase + pausedAt), the pure `RecordingActivityContentStateMapper` + RED test, and the `RecordingSessionController` / `LiveActivityController` protocols all match the verified API shapes. `Text(timerInterval:pauseTime:)` validates the "no elapsed field in ContentState" choice.
- **Target/build layer (owner, GUI-only): 2 blocking steps.** (a) Add a **Widget Extension target** with *Include Live Activity* checked; (b) add the **`SquirlLiveActivity`** local package to **both** the app and widget targets. Then set `NSSupportsLiveActivities = YES`.
- **Prove-first gate:** §2 Lock-Screen-without-unlock. One device tap decides whether US1 ships as "no unlock" or "tap → Face ID → runs."
