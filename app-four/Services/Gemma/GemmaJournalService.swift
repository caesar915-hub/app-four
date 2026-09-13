import Foundation
import os
import UIKit

/// On-device extraction backend: Gemma 4 E2B (text-only) via LiteRT-LM.
///
/// Two-pass pipeline (identical shape to `MLXJournalService`):
///   Pass 1 (`SummaryPromptBuilder`) → holistic 1–2 sentence narrative summary.
///   Pass 2 (`SignalPromptBuilder`)  → structured signals, via Tool Use (D1) with a
///   free-form-JSON + `ExtractionValidator` recovery + one correction retry fallthrough.
///
/// Reuses the model-agnostic prompt builders, lexicon, and `ExtractionValidator` verbatim.
/// Ships ADDITIVE/INERT: the `AppDependencies` binding stays on `MLXJournalService` and the
/// live LiteRT calls are compile-guarded; the switchover is device-gated (spec 056, D2/D3).
nonisolated struct GemmaJournalService: SummarizationService {
    private let lexicon: Lexicon
    private let summarySystemPrompt: String
    private let signalsSystemPrompt: String
    let modelHolder: ModelHolder
    private let lifecycleCoordinator: LifecycleCoordinator

    init() {
        self.init(idleEvictionInterval: .seconds(180))
    }

    internal init(
        idleEvictionInterval: Duration = .seconds(180),
        notificationCenter: NotificationCenter = .default,
        installedCheck: @escaping @Sendable () -> Bool = {
            AIModelServiceImpl.gemmaLiteRTModelInstalled(in: ModelConstants.llmDownloadBase)
        },
        memoryMinimumBytes: UInt64 = 1_000_000_000,
        generatorProvider: (@Sendable () async throws -> LiteRTTextGenerator)? = nil,
        preloadedGenerator: LiteRTTextGenerator? = nil
    ) {
        let lex = LexiconLoader.loadBundled()
        self.lexicon = lex
        self.summarySystemPrompt = SummaryPromptBuilder.buildSystemPrompt()
        self.signalsSystemPrompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lex)
        let holder = ModelHolder(
            installedCheck: installedCheck,
            memoryMinimumBytes: memoryMinimumBytes,
            generatorProvider: generatorProvider ?? Self.makeDefaultGeneratorProvider(),
            preloaded: preloadedGenerator
        )
        self.modelHolder = holder
        self.lifecycleCoordinator = LifecycleCoordinator(
            evict: { await holder.evict() },
            idleInterval: idleEvictionInterval,
            notificationCenter: notificationCenter
        )
        Task { [lifecycleCoordinator] in
            await lifecycleCoordinator.startObserving()
        }
    }

    func summarize(rawTranscription: String) async throws -> SummaryResult {
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.emptyResult() }

        try await modelHolder.loadIfNeeded()

        // Pass 1 owns the summary; Pass 2 owns the signals. Both are non-fatal.
        let summaryText = await runSummaryPass(transcript: trimmed)
        let extraction = await runSignalsPass(transcript: trimmed)

        var merged = extraction ?? UnifiedExtraction()
        merged.summary = summaryText ?? extraction?.summary

        let validated = ExtractionValidator.validate(merged, lexicon: lexicon, rawTranscript: trimmed)
        await lifecycleCoordinator.arm()
        return ExtractionValidator.assembleSummaryResult(from: validated, lexicon: lexicon, rawTranscript: trimmed)
    }

    // MARK: - Pass 1

    private func runSummaryPass(transcript: String) async -> String? {
        do {
            let user = SummaryPromptBuilder.buildUserMessage(transcript: transcript)
            let raw = try await modelHolder.generate(system: summarySystemPrompt, user: user, maxTokens: 120)
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            AppLogger.log("GemmaJournalService: pass1 failed: \(error)")
            return nil
        }
    }

    // MARK: - Pass 2 (Tool Use → free-form fallthrough → one correction retry)

    private func runSignalsPass(transcript: String) async -> UnifiedExtraction? {
        let user = SignalPromptBuilder.buildUserMessage(transcript: transcript)

        // Path A — Tool Use / function calling (D1). No tool call (or a throw) ⇒ Path B.
        // `try?` flattens the throwing `SignalsToolArguments?` to a single optional.
        if let args = try? await modelHolder.callSignalsTool(system: signalsSystemPrompt, user: user) {
            return SignalsTool.unifiedExtraction(from: args)
        }

        // Path B — free-form JSON + 3-stage recovery (proven Qwen-equivalent).
        let raw: String
        do {
            raw = try await modelHolder.generate(system: signalsSystemPrompt, user: user, maxTokens: 512)
        } catch {
            AppLogger.log("GemmaJournalService: pass2 generation failed: \(error)")
            return nil
        }
        if let extraction = ExtractionValidator.parseExtraction(from: raw) {
            return extraction
        }

        // One correction retry with a stricter prompt.
        let correctionUser = PromptLoader.loadSignalCorrectionPrompt(transcript: transcript)
        let retry: String
        do {
            retry = try await modelHolder.generate(system: signalsSystemPrompt, user: correctionUser, maxTokens: 512)
        } catch {
            AppLogger.log("GemmaJournalService: pass2 retry generation failed: \(error)")
            return nil
        }
        return ExtractionValidator.parseExtraction(from: retry)
    }

    private static func emptyResult() -> SummaryResult {
        SummaryResult(
            bullets: [], medications: [], generatedTitle: "Empty Note",
            energyLevel: nil, focusLevel: nil, mood: nil, sleepHours: nil,
            sleepQuality: nil, sleepEvent: nil, sleepLevel: nil,
            sideEffects: [], emotions: [], topics: [], noteExtraction: nil
        )
    }

    /// Gemma 4 E2B (CPU/XNNPACK) targets ~607 MB resident, so the floor is 1 GB
    /// (model + KV + margin) — lower than the MLX/Qwen 1.5 GB it was NOT copied from.
    /// Recalibrate to the measured A14 `phys_footprint` (device-qa-checklist).
    static func checkMemoryHeadroom(minimumBytes: UInt64 = 1_000_000_000) -> Bool {
        os_proc_available_memory() >= minimumBytes
    }

    private static func makeDefaultGeneratorProvider() -> @Sendable () async throws -> LiteRTTextGenerator {
        return {
            #if canImport(LiteRTLM)
            let modelURL = ModelConstants.llmDownloadBase
                .appendingPathComponent("models")
                .appendingPathComponent(ModelConstants.gemmaLiteRTRepoID)
                .appendingPathComponent(ModelConstants.gemmaLiteRTFileName)
            let cacheDir = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("litert").path
            return try await LiteRTEngineGenerator(modelPath: modelURL.path, cacheDir: cacheDir)
            #else
            // No runtime linked (simulator / additive phase) ⇒ engine path is unavailable.
            throw SummarizationError.modelNotInstalled
            #endif
        }
    }

    // MARK: - ModelHolder

    actor ModelHolder {
        private(set) var isLoaded = false
        private var generator: LiteRTTextGenerator?
        private var isGenerating = false
        private var inFlightLoad: Task<Void, Error>?
        private let installedCheck: @Sendable () -> Bool
        private let memoryMinimumBytes: UInt64
        private let generatorProvider: @Sendable () async throws -> LiteRTTextGenerator

        init(
            installedCheck: @escaping @Sendable () -> Bool,
            memoryMinimumBytes: UInt64,
            generatorProvider: @escaping @Sendable () async throws -> LiteRTTextGenerator,
            preloaded: LiteRTTextGenerator?
        ) {
            self.installedCheck = installedCheck
            self.memoryMinimumBytes = memoryMinimumBytes
            self.generatorProvider = generatorProvider
            if let preloaded {
                self.generator = preloaded
                self.isLoaded = true
            }
        }

        func loadIfNeeded() async throws {
            if isLoaded { return }
            if let inFlightLoad { return try await inFlightLoad.value }
            let task = Task { try await self.performLoad() }
            inFlightLoad = task
            defer { inFlightLoad = nil }
            try await task.value
        }

        private func performLoad() async throws {
            // Never trigger an implicit multi-GB hub download mid-check-in; if the model
            // isn't installed, say so and let the raw transcript survive upstream.
            guard installedCheck() else { throw SummarizationError.modelNotInstalled }
            guard GemmaJournalService.checkMemoryHeadroom(minimumBytes: memoryMinimumBytes) else {
                throw SummarizationError.insufficientMemory
            }
            generator = try await generatorProvider()
            isLoaded = true
        }

        func generate(system: String, user: String, maxTokens: Int) async throws -> String {
            guard let generator else { throw SummarizationError.modelNotInstalled }
            isGenerating = true
            defer { isGenerating = false }
            return try await generator.generate(system: system, user: user, maxTokens: maxTokens)
        }

        func callSignalsTool(system: String, user: String) async throws -> SignalsToolArguments? {
            guard let generator else { throw SummarizationError.modelNotInstalled }
            isGenerating = true
            defer { isGenerating = false }
            return try await generator.callSignalsTool(system: system, user: user)
        }

        /// Evicts the resident engine (mmap'd + KV state). Returns `false` while
        /// generating; callers re-arm eviction.
        func evict() -> Bool {
            guard !isGenerating else { return false }
            generator = nil
            isLoaded = false
            return true
        }

        #if DEBUG
        func markLoadedForTesting() { isLoaded = true }
        #endif
    }

    // MARK: - LifecycleCoordinator

    private actor LifecycleCoordinator {
        private let evictAction: @Sendable () async -> Bool
        private let idleInterval: Duration
        private let notificationCenter: NotificationCenter
        private var timerTask: Task<Void, Never>?
        private var observerTokens: [any NSObjectProtocol] = []
        private var hasStartedObserving = false

        init(
            evict: @escaping @Sendable () async -> Bool,
            idleInterval: Duration,
            notificationCenter: NotificationCenter
        ) {
            self.evictAction = evict
            self.idleInterval = idleInterval
            self.notificationCenter = notificationCenter
        }

        deinit {
            timerTask?.cancel()
            for token in observerTokens { notificationCenter.removeObserver(token) }
        }

        func startObserving() {
            guard !hasStartedObserving else { return }
            hasStartedObserving = true
            let memoryWarningToken = notificationCenter.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { [weak self] in await self?.evict(cause: "memory warning") }
            }
            let backgroundToken = notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { [weak self] in await self?.evict(cause: "background entry") }
            }
            observerTokens = [memoryWarningToken, backgroundToken]
        }

        func arm() {
            timerTask?.cancel()
            let interval = idleInterval
            let action = evictAction
            timerTask = Task.detached(priority: .utility) {
                do {
                    try await Task.sleep(for: interval)
                    _ = await action()
                } catch {
                    // Re-armed or cancelled; nothing to do.
                }
            }
        }

        func evict(cause: String) async {
            timerTask?.cancel()
            let evicted = await evictAction()
            if !evicted { arm() }
        }

        #if DEBUG
        func currentTimerTaskForTesting() -> Task<Void, Never>? { timerTask }
        #endif
    }

    var isModelLoaded: Bool {
        get async { await modelHolder.isLoaded }
    }

    #if DEBUG
    func armIdleTimerForTesting() async { await lifecycleCoordinator.arm() }
    func currentIdleTimerTaskForTesting() async -> Task<Void, Never>? {
        await lifecycleCoordinator.currentTimerTaskForTesting()
    }
    func startLifecycleObservingForTesting() async { await lifecycleCoordinator.startObserving() }
    #endif
}
