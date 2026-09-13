import Foundation

/// Runtime seam for Gemma text generation. `GemmaJournalService` depends on this
/// protocol so tests inject a fake; the real implementation wraps LiteRT-LM and is
/// compiled ONLY when the (Early-Preview) package is present (`#if canImport(LiteRTLM)`).
/// System text and user text are passed separately so the concrete generator owns
/// chat-template framing (via `GemmaChatTemplate`).
protocol LiteRTTextGenerator: Sendable {
    func generate(system: String, user: String, maxTokens: Int) async throws -> String
    func callSignalsTool(system: String, user: String) async throws -> SignalsToolArguments?
}

#if DEBUG
/// Scriptable fake for hermetic tests and previews. Never touches the runtime.
public struct FakeLiteRTGenerator: LiteRTTextGenerator {
    public typealias GenerateHandler = @Sendable (_ system: String, _ user: String, _ maxTokens: Int) async throws -> String
    public typealias ToolHandler = @Sendable (_ system: String, _ user: String) async throws -> SignalsToolArguments?
    private let generateHandler: GenerateHandler
    private let toolHandler: ToolHandler

    public init(
        generate: @escaping GenerateHandler = { _, _, _ in "" },
        callTool: @escaping ToolHandler = { _, _ in nil }
    ) {
        self.generateHandler = generate
        self.toolHandler = callTool
    }

    public func generate(system: String, user: String, maxTokens: Int) async throws -> String {
        try await generateHandler(system, user, maxTokens)
    }

    public func callSignalsTool(system: String, user: String) async throws -> SignalsToolArguments? {
        try await toolHandler(system, user)
    }
}
#endif

#if canImport(LiteRTLM)
import LiteRTLM

/// Real LiteRT-LM backend — compiled ONLY when the package is added (device day, task T013).
/// Loads text-only, by file path, CPU/XNNPACK on A14. The Early-Preview API surface is
/// documented but moving; reconcile any deltas HERE (single seam) and NOWHERE else.
actor LiteRTEngineGenerator: LiteRTTextGenerator {
    private let engine: Engine

    init(modelPath: String, cacheDir: String, maxTokens: Int = 2048) async throws {
        let config = EngineConfig(
            modelPath: modelPath,
            backend: .cpu(),          // A14: CPU/XNNPACK for memory safety
            maxNumTokens: maxTokens,
            cacheDir: cacheDir
            // visionBackend / audioBackend left nil ⇒ text-only (never construct them)
        )
        self.engine = Engine(engineConfig: config)
        try await engine.initialize()
    }

    func generate(system: String, user: String, maxTokens: Int) async throws -> String {
        let prompt = GemmaChatTemplate.singleTurn(system: system, user: user)
        let conversation = try await engine.createConversation()
        // TODO(device, T013): confirm Message construction + response-text accessor against
        // the shipping LiteRTLM API, and bound the thinking-token budget ≈ 0 for determinism.
        // Also verify Conversation does NOT re-apply a chat template (avoid double-templating).
        let reply = try await conversation.sendMessage(Message(text: prompt))
        return reply.text
    }

    func callSignalsTool(system: String, user: String) async throws -> SignalsToolArguments? {
        // TODO(device, T013/T014): register a `record_signals` Tool via ConversationConfig(tools:)
        // and decode its arguments into SignalsToolArguments. LiteRT Tool Use is Early Preview and
        // unverified on-device — until reconciled, return nil so the proven free-form fallthrough
        // carries pass-2. This keeps D1 (Tool Use) an explicit device-day activation, not a blind claim.
        return nil
    }
}
#endif
