import Foundation
import os
import UIKit
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon

// Two-pass pipeline (spec: two-pass-mlx-pipeline):
//   Pass 1 (SummaryPromptBuilder)  → holistic 1-2 sentence narrative summary.
//   Pass 2 (SignalPromptBuilder)   → strict JSON of present-moment signals.
// JSON decoding uses UnifiedExtraction via ExtractionValidator.parseExtraction().

nonisolated struct MLXJournalService: SummarizationService {
    private let lexicon: Lexicon
    private let summarySystemPrompt: String
    private let signalsSystemPrompt: String

    init() {
        self.init(idleEvictionInterval: .seconds(180))
    }

    internal init(
        idleEvictionInterval: Duration = .seconds(180),
        notificationCenter: NotificationCenter = .default
    ) {
        // loadBundled() is non-throwing: it falls back to code defaults if the
        // bundled lexicon.json is missing or malformed.
        let lex = LexiconLoader.loadBundled()
        self.lexicon = lex
        self.summarySystemPrompt = SummaryPromptBuilder.buildSystemPrompt()
        self.signalsSystemPrompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lex)
        self.lifecycleCoordinator = LifecycleCoordinator(
            holder: modelHolder,
            idleInterval: idleEvictionInterval,
            notificationCenter: notificationCenter
        )
        Task { [lifecycleCoordinator] in
            await lifecycleCoordinator.startObserving()
        }
    }

    func summarize(rawTranscription: String) async throws -> SummaryResult {
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.emptyResult()
        }

        try await loadModelIfNeeded()

        // Pass 1: holistic narrative summary. Failure is non-fatal — the
        // assembler falls back to the raw transcript as the summary bullet.
        let summaryText = await runSummaryPass(transcript: trimmed)

        // Pass 2: present-moment signal extraction, with one correction retry.
        // Failure is non-fatal — signals default to nil/empty.
        let extraction = await runSignalsPass(transcript: trimmed)

        // Merge: Pass 1 owns the summary; Pass 2 owns the signals.
        var merged = extraction ?? UnifiedExtraction()
        merged.summary = summaryText ?? extraction?.summary

        // Validate and clamp all fields against Levels.swift enums + lexicon allowlists.
        let validated = ExtractionValidator.validate(merged, lexicon: lexicon, rawTranscript: trimmed)
        AppLogger.log("MLXJournalService: extraction parsed — mood=\(String(describing: validated.mood)), energy=\(String(describing: validated.energy)), focus=\(String(describing: validated.focus)), summary=\(validated.summary == nil ? "nil" : "present")")

        #if !targetEnvironment(simulator)
        MLX.GPU.clearCache()
        #endif
        await lifecycleCoordinator.arm()

        return ExtractionValidator.assembleSummaryResult(
            from: validated, lexicon: lexicon, rawTranscript: trimmed
        )
    }

    // MARK: - Pass 1: Holistic Summary

    private func runSummaryPass(transcript: String) async -> String? {
        let systemPrompt = self.summarySystemPrompt
        let holder = self.modelHolder
        let userMessage = SummaryPromptBuilder.buildUserMessage(transcript: transcript)
        do {
            let raw = try await Task.detached(priority: .userInitiated) {
                try await holder.generateText(systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 120)
            }.value
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                AppLogger.log("MLXJournalService: pass1 returned empty summary")
                return nil
            }
            AppLogger.log("MLXJournalService: pass1 summary: \(text.prefix(200))")
            return text
        } catch {
            AppLogger.log("MLXJournalService: pass1 failed: \(error)")
            return nil
        }
    }

    // MARK: - Pass 2: Present-Moment Signals

    private func runSignalsPass(transcript: String) async -> UnifiedExtraction? {
        let systemPrompt = self.signalsSystemPrompt
        let holder = self.modelHolder
        let userMessage = SignalPromptBuilder.buildUserMessage(transcript: transcript)

        var rawJSON: String
        do {
            rawJSON = try await Task.detached(priority: .userInitiated) {
                try await holder.generateText(systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 512)
            }.value
        } catch {
            AppLogger.log("MLXJournalService: pass2 generation failed: \(error)")
            return nil
        }
        AppLogger.log("MLXJournalService: pass2 raw: \(rawJSON.prefix(500))")

        // 3-stage recovery (direct → backtick strip → substring). If the model
        // ignored the JSON-only contract, retry once with a stricter prompt.
        if let extraction = await ExtractionValidator.parseExtraction(from: rawJSON) {
            return extraction
        }

        AppLogger.log("MLXJournalService: pass2 first pass not parseable (len \(rawJSON.count)) — retrying with correction prompt")
        let correction = PromptLoader.loadSignalCorrectionPrompt(transcript: transcript)
        do {
            rawJSON = try await Task.detached(priority: .userInitiated) {
                try await holder.generateText(systemPrompt: systemPrompt, userMessage: correction, maxTokens: 512)
            }.value
        } catch {
            AppLogger.log("MLXJournalService: pass2 retry generation failed: \(error)")
            return nil
        }
        AppLogger.log("MLXJournalService: pass2 retry raw: \(rawJSON.prefix(500))")

        if let extraction = await ExtractionValidator.parseExtraction(from: rawJSON) {
            return extraction
        }
        AppLogger.log("MLXJournalService: pass2 output not parseable as extraction JSON (len \(rawJSON.count))")
        return nil
    }

    private static func emptyResult() -> SummaryResult {
        return SummaryResult(
            bullets: [],
            medications: [],
            generatedTitle: "Empty Note",
            energyLevel: nil,
            focusLevel: nil,
            mood: nil,
            sleepHours: nil,
            sleepQuality: nil,
            sleepEvent: nil,
            sleepLevel: nil,
            sideEffects: [],
            emotions: [],
            topics: [],
            noteExtraction: nil
        )
    }

    actor ModelHolder {
        var isLoaded: Bool = false
        var modelContainer: ModelContainer?
        private var isGenerating = false

        func loadIfNeeded() async throws {
            guard !isLoaded else { return }

            // The model's lifecycle is managed by AIModelService (onboarding /
            // Settings / background download). Never trigger an implicit ~740 MB
            // hub download mid-check-in — if it isn't installed, say so.
            guard let directory = AIModelServiceImpl.findLLMModelDirectory(
                in: ModelConstants.llmDownloadBase
            ) else {
                os_log(.error, "Insights model not installed")
                throw SummarizationError.modelNotInstalled
            }

            guard MLXJournalService.checkMemoryHeadroom() else {
                os_log(.error, "Insufficient memory to load MLX model")
                throw SummarizationError.insufficientMemory
            }

            #if !targetEnvironment(simulator)
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            #endif

            AppLogger.log("Loading insights model into Unified Memory...")
            let config = ModelConfiguration(directory: directory)
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)

            isLoaded = true
            AppLogger.log("Insights model loaded (resident footprint ~1.2 GB)")
        }

        func generateText(systemPrompt: String, userMessage: String, maxTokens: Int) async throws -> String {
            guard let modelContainer = modelContainer else {
                throw SummarizationError.modelNotInstalled
            }

            isGenerating = true
            defer { isGenerating = false }

            var parameters = GenerateParameters(temperature: 0.0)
            parameters.maxTokens = maxTokens
            let session = ChatSession(modelContainer, instructions: systemPrompt, generateParameters: parameters)
            let result = try await session.respond(to: userMessage)
            #if !targetEnvironment(simulator)
            MLX.GPU.clearCache()
            #endif
            return result
        }

        /// Evicts the model container and clears the MLX buffer cache. Returns `false`
        /// when the model is currently generating text; callers should re-arm eviction.
        func evict() -> Bool {
            guard !isGenerating else {
                AppLogger.log("MLX eviction deferred — generation in flight")
                return false
            }
            modelContainer = nil
            isLoaded = false
            #if !targetEnvironment(simulator)
            MLX.GPU.clearCache()
            #endif
            AppLogger.log("MLX model evicted — Unified Memory reclaimed")
            return true
        }

        #if DEBUG
        func markLoadedForTesting() {
            isLoaded = true
        }
        #endif
    }

    /// Coordinates MLX model eviction in response to idle time, memory pressure,
    /// and the app entering the background. Runs on its own actor so notification
    /// observers and timers do not block the main thread or the service.
    private actor LifecycleCoordinator {
        private let holder: ModelHolder
        private let idleInterval: Duration
        private let notificationCenter: NotificationCenter
        private var timerTask: Task<Void, Never>?
        private var observerTokens: [any NSObjectProtocol] = []
        private var hasStartedObserving = false

        init(
            holder: ModelHolder,
            idleInterval: Duration = .seconds(180),
            notificationCenter: NotificationCenter = .default
        ) {
            self.holder = holder
            self.idleInterval = idleInterval
            self.notificationCenter = notificationCenter
        }

        deinit {
            timerTask?.cancel()
            for token in observerTokens {
                notificationCenter.removeObserver(token)
            }
        }

        func startObserving() {
            guard !hasStartedObserving else { return }
            hasStartedObserving = true

            let memoryWarningToken = notificationCenter.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.evict(cause: "memory warning")
                }
            }

            let backgroundToken = notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.evict(cause: "background entry")
                }
            }

            observerTokens = [memoryWarningToken, backgroundToken]
        }

        /// Arms (or re-arms) the idle eviction timer. The previous timer, if any,
        /// is cancelled so a new inference resets the idle countdown.
        func arm() {
            timerTask?.cancel()
            let holder = self.holder
            let interval = self.idleInterval
            AppLogger.log("MLX idle eviction timer armed (\(interval))")
            timerTask = Task.detached(priority: .utility) { [holder] in
                do {
                    try await Task.sleep(for: interval)
                    AppLogger.log("MLX idle timer fired — evicting")
                    _ = await holder.evict()
                } catch is CancellationError {
                    // Eviction was re-armed or cancelled; nothing to do.
                } catch {
                    // Ignore unexpected sleep errors.
                }
            }
        }

        #if DEBUG
        /// Test hook: the currently armed idle-timer task, so tests can assert
        /// re-arm cancellation deterministically instead of racing wall-clock.
        func currentTimerTaskForTesting() -> Task<Void, Never>? { timerTask }
        #endif

        func evict(cause: String) async {
            timerTask?.cancel()
            AppLogger.log("MLX eviction triggered: \(cause)")
            let evicted = await holder.evict()
            if !evicted {
                // Model is currently generating; arm a fresh timer to retry after
                // the idle interval once generation finishes.
                arm()
            }
        }
    }

    let modelHolder = ModelHolder()
    private let lifecycleCoordinator: LifecycleCoordinator

    var isModelLoaded: Bool {
        get async {
            await modelHolder.isLoaded
        }
    }

    static func checkMemoryHeadroom(minimumBytes: UInt64 = 200 * 1024 * 1024) -> Bool {
        return os_proc_available_memory() >= minimumBytes
    }

    private func loadModelIfNeeded() async throws {
        try await modelHolder.loadIfNeeded()
    }

    #if DEBUG
    /// Test hook: arms the idle eviction timer with the service's configured interval.
    func armIdleTimerForTesting() async {
        await lifecycleCoordinator.arm()
    }

    /// Test hook: the currently armed idle-timer task, for deterministic
    /// cancellation assertions (wall-clock races flake under parallel load).
    func currentIdleTimerTaskForTesting() async -> Task<Void, Never>? {
        await lifecycleCoordinator.currentTimerTaskForTesting()
    }

    /// Test hook: ensures notification observers are registered before tests post them.
    func startLifecycleObservingForTesting() async {
        await lifecycleCoordinator.startObserving()
    }
    #endif
}
