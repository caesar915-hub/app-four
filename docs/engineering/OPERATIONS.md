<!-- Created: 2026-06-14 23:59 WEST · Updated: 2026-06-30 12:21 WEST -->
# Operations & Release Guide

_Last updated: 2026-06-28_

This document covers release workflows, App Store considerations, and operational troubleshooting for Squirl.

---

## Table of Contents

- [Release Process](#release-process)
- [Versioning](#versioning)
- [App Store Considerations](#app-store-considerations)
- [Privacy & Compliance](#privacy--compliance)
- [Runbook](#runbook)
- [Monitoring](#monitoring)

---

## Release Process

Squirl does not yet have automated CI/CD. Releases are cut manually from a stable commit on `main`.

### Pre-Release Checklist

1. All P0 items in `docs/TODO.md` are resolved or explicitly deferred.
2. The test suite passes serially:

   ```bash
   xcodebuild test \
     -project app-four.xcodeproj \
     -scheme app-four \
     -destination 'platform=iOS Simulator,name=iPhone 16' \
     -disableParallelTesting
   ```

3. Build succeeds in Release configuration for device.
4. SwiftData schema migration strategy is documented if the schema changed.
5. `docs/BACKLOG.md` and `docs/TODO.md` are updated.
6. Release notes are drafted.

### Cutting a Release

1. Create a release branch: `release/x.y.z`.
2. Update the version and build number in Xcode target settings.
3. Run final tests on a physical device.
4. Archive the app in Xcode (**Product → Archive**).
5. Upload to App Store Connect via Xcode or `xcrun altool`.
6. Submit for TestFlight internal testing.
7. After validation, merge the release branch back to `main` and tag the commit:

   ```bash
   git tag x.y.z
   git push origin x.y.z
   ```

### Stable Channel

The project has a second TestFlight distribution channel for a persistent "Stable" reference build.

| | Dev | Stable |
|---|---|---|
| Bundle ID | `squirl-app.app-four` | `squirl-app.app-four.stable` |
| Scheme | `app-four` | `app-four-stable` |
| Archive config | `Release` | `Release-Stable` |
| Home-screen name | Squirl | Squirl Stable |
| Icon | Full colour | Greyscale (`AppIcon-Stable`) |
| App Store Connect app | Squirl (Dev) | Squirl Stable |

**To cut a Stable release from `main`:**
1. Ensure `main` is at the commit you want to freeze.
2. In Xcode, select the `app-four-stable` scheme.
3. Product → Archive (builds `Release-Stable` config).
4. Upload via Xcode Organizer to the "Squirl Stable" App Store Connect app.
5. Tag the commit: `git tag vX.Y.Z-stable && git push origin vX.Y.Z-stable`

**Note:** The two apps have separate SwiftData containers — Stable does not share data with Dev.

---

## Versioning

Squirl uses semantic versioning for releases:

- `MAJOR` — breaking changes or major product milestones.
- `MINOR` — new features or significant improvements.
- `PATCH` — bug fixes and small improvements.

Current milestones are tracked in `docs/BACKLOG.md`:

- v0.8 — Core capture, transcription, extraction, calendar, insights.
- v0.8.1 — UI parity, medication bar, signal glyphs, accessibility.
- v0.9 — Personal lexicon, export, settings polish, App Store prep.
- v1.0 — App Store release.

---

## App Store Considerations

- **Monetization:** Not yet decided. Options include free with subscription, one-time paid app, or free with one-time IAP. StoreKit is not implemented.
- **iCloud Backup:** The SwiftData store directory is excluded from iCloud backup to protect health data.
- **Permissions:** The app requests microphone access. Ensure `NSMicrophoneUsageDescription` in `Info.plist` is accurate and user-facing.
- **App Review:** Be ready to explain that all processing is on-device and no health data is uploaded.

---

## Privacy & Compliance

- No remote servers receive user data.
- No analytics or crash-reporting SDK is wired.
- Encrypted export is available before any data leaves the device.
- A privacy policy and data handling disclosure will be required for App Store submission.

---

## Runbook

### User Reports: Recordings Stuck on "Transcribing…"

1. Check if the app was killed during transcription.
2. On next launch, `RecordingStore.recoverOrphanedTranscriptions()` should move stuck recordings to `.failed`.
3. If the issue persists, verify the recording file exists in `Documents/Recordings/`.

### User Reports: Model Download Never Finishes

1. Verify network connectivity.
2. Check `downloadOverCellular` setting.
3. Check available disk space.
4. Have the user delete the model from Settings and retry.

### User Reports: Missing Data After Update

1. This is expected pre-v1.0 if the SwiftData schema changed and the wipe fallback triggered.
2. After v1.0, this indicates a migration bug; investigate immediately.

### Crash on Launch

1. Check `AppModelContainer` logs for schema conflict.
2. Check Whisper model directory permissions.
3. Review `MetricManager` startup diagnostics.

---

## Monitoring

There is no production monitoring today. Planned additions:

- Local metrics collection (already partially implemented via `DiagnosticsStore`).
- Optional, opt-in telemetry with clear privacy controls.
- Crash reporting via an on-device log export feature.

Until monitoring is in place, rely on user reports, TestFlight feedback, and manual testing.
