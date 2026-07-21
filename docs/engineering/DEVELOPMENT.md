# Development Guide

_Last updated: 2026-06-28_

This document explains how to build, run, test, and debug Squirl.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Opening the Project](#opening-the-project)
- [Running the App](#running-the-app)
- [Working with the Sandbox App](#working-with-the-sandbox-app)
- [Working with WhisperCLI](#working-with-whispercli)
- [Testing](#testing)
- [Debugging](#debugging)
- [Common Commands](#common-commands)
- [Useful Launch Arguments](#useful-launch-arguments)

---

## Prerequisites

- macOS 15 or later
- Xcode 16 or later
- iOS 17.0+ Simulator or device
- (Optional) [XcodeGen](https://github.com/yonaskolb/XcodeGen) for the sandbox app

---

## Opening the Project

Open the main Xcode project:

```bash
open /Users/caesargrey/Projects/app-four/app-four.xcodeproj
```

The project uses:

- Local Swift packages in `Packages/`
- External dependency `WhisperKit` resolved through Swift Package Manager

---

## Running the App

1. Select the `app-four` scheme.
2. Choose an iOS 17+ simulator or device.
3. Build and run (`⌘R`).

On first launch the app will:

- Show onboarding (unless overridden; see launch arguments below).
- Begin downloading the Whisper Small model in the background.
- Seed mock data on debug builds if the store is empty.

### First-Run Model Download

The model is downloaded on demand. You can also trigger it from **Settings → Model Management**. Until the model is present, voice recordings are queued with status `.pendingTranscription` and processed once the download completes.

---

## Working with the Sandbox App

`SandboxApp/` is a lightweight XcodeGen target for iterating on `SquirlDesignSystem` and `SquirlSignals` without launching the full app.

```bash
cd /Users/caesargrey/Projects/app-four/SandboxApp
xcodegen generate
open SquirlSandbox.xcodeproj
```

The sandbox target depends on both local packages and runs with iOS 26.4.

---

## Working with WhisperCLI

`WhisperCLI/` is a standalone macOS SPM executable for experimenting with WhisperKit.

```bash
cd /Users/caesargrey/Projects/app-four/WhisperCLI
swift build
swift run WhisperCLI --help
```

Use it to test transcription behavior, prompt tuning, or model loading outside the iOS app.

---

## Testing

Tests live in `app-fourTests/` and use XCTest. The suite is **not parallel-safe** because tests share the in-memory SwiftData container and file system.

### From Xcode

1. Select the `app-four` scheme.
2. Choose **Product → Test** (`⌘U`).

### From Command Line

```bash
cd /Users/caesargrey/Projects/app-four
xcodebuild test \
  -project app-four.xcodeproj \
  -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -disableParallelTesting
```

See [`TESTING.md`](TESTING.md) for the full testing strategy.

---

## Debugging

### Debug-Only Features

In debug builds, the app automatically enables mock data seeding and exposes a debug console in Settings.

### Inspecting SwiftData

Use the SwiftData browser in Xcode's Debug Navigator or add temporary fetch logs through `AppLogger`.

### Audio File Locations

Recorded audio is stored in:

```
<App Documents>/Recordings/<audioFileName>
```

You can inspect this directory in the Simulator by navigating to:

```
~/Library/Developer/CoreSimulator/Devices/<device-id>/data/Containers/Data/Application/<app-id>/Documents/Recordings/
```

### Model Download Issues

If the model fails to download:

1. Check network connectivity.
2. Verify `downloadOverCellular` setting if on cellular.
3. Check disk space.
4. Look at `AppLogger` output in the Xcode console.
5. Delete the model from Settings and retry.

---

## Common Commands

| Task | Command |
|------|---------|
| Build app | `⌘B` in Xcode or `xcodebuild -project app-four.xcodeproj -scheme app-four` |
| Run tests | `⌘U` in Xcode or `xcodebuild test ... -disableParallelTesting` |
| Generate sandbox project | `cd SandboxApp && xcodegen generate` |
| Build WhisperCLI | `cd WhisperCLI && swift build` |
| Find app documents on Simulator | `xcrun simctl get_app_container <device> squirl-app.app-four documents` |

---

## Useful Launch Arguments

Pass these via **Product → Scheme → Edit Scheme → Run → Arguments**:

| Argument | Effect |
|----------|--------|
| `-skipOnboarding` | Skips the welcome flow. |
| `-UITestMode` | Puts the app in UI-test mode if supported. |

Environment variables:

| Variable | Effect |
|----------|--------|
| `debugMockMode` (UserDefaults) | When `true` on debug builds, seeds mock data and filters recordings by `isMockData`. |

---

## Release Builds

Release builds exclude mock data seeding and debug-only UI. To test a release-like build locally:

1. Select the `app-four` scheme.
2. Choose **Product → Scheme → Edit Scheme → Run → Build Configuration → Release**.
3. Run on a device or simulator.

Do not ship a build with `debugMockMode` enabled.
