# WhisperNotes: System Instructions

These instructions govern all code generation and architectural decisions for the WhisperNotes project.

## 1. Coding Standards (Swift 6)
- **Concurrency**: Use `async/await`, `Task`, and `AsyncStream`. Strictly avoid `completionHandlers` or `Delegates` for new logic.
- **Actors**: Use `actor` for services that manage shared state or hardware. Use `@MainActor` for ViewModels and UI-facing components.
- **Observation**: Exclusively use the `@Observable` macro. Never use `ObservableObject`, `@Published`, or `Combine` unless bridging to legacy system APIs.
- **Protocols**: Always define a protocol for services before implementing them. Injected services in ViewModels must be typed to the protocol, not the implementation.

## 2. File & Project Management
- **Size Limit**: No single Swift file should exceed **300 lines**. If a file grows larger, split it into smaller components or utility extensions.
- **Directory Structure**: Strictly follow the established structure:
    - `App/`: App entry and container setup.
    - `Views/`: SwiftUI views and specialized `Components/` subfolder.
    - `ViewModels/`: `@Observable` orchestration logic.
    - `Services/`: Protocol definitions and concrete implementations (subfolded by domain).
    - `Models/`: SwiftData `@Model` classes and project-wide Enums.
    - `Utils/`: Helpers, Constants, and Logger.

## 3. UI & Design Rules
- **Aesthetic**: Follow the **Liquid Glass** system. Use `.ultraThinMaterial` for cards and `.glassCard()` modifier for consistency.
- **Typography**: Use the `GlassTypography` constants. Support Dynamic Type (no fixed-size text).
- **SF Symbols**: Use system icons only. No custom asset icons unless specifically requested.
- **Accessibility**: Every interactive element MUST have an `.accessibilityLabel()`. Respect `.isReduceMotionEnabled` for all animations.

## 4. Documentation & Logging
- **AppLogger**: Every significant event (hardware start/stop, AI progress, disk errors) must be logged via `AppLogger.log()`.
- **Comments**: Use "surgical" comments to explain "why" (complex logic), not "what" (obvious code).
- **Commit Messages**: When asked to commit, use clear, intent-based messages (e.g., `feat: Implement WhisperKit resampler`, `fix: Resolve race condition in audio tap`).

## 5. Security & Privacy
- **On-Device Only**: Never include code that transmits audio or transcript data over the network.
- **Secrets**: Never hardcode API keys or sensitive strings.
