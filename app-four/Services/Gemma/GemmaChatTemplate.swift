import Foundation

/// Renders prompts into Gemma 4's chat-turn format. LiteRT-LM does not apply a
/// tokenizer chat template the way swift-transformers did for the MLX path, so
/// turn framing is the app's responsibility. Pure value type — no runtime
/// dependency, fully unit-testable. Gemma has no dedicated system role, so
/// system text is folded into the first user turn.
nonisolated enum GemmaChatTemplate {
    static let startOfTurn = "<start_of_turn>"
    static let endOfTurn = "<end_of_turn>"

    struct Turn: Sendable, Equatable {
        enum Role: String, Sendable { case user, model }
        let role: Role
        let text: String
    }

    /// A single user turn (system folded in) followed by the model-turn opener.
    static func singleTurn(system: String, user: String) -> String {
        let sys = system.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = sys.isEmpty ? user : "\(sys)\n\n\(user)"
        return "\(startOfTurn)user\n\(body)\(endOfTurn)\n\(startOfTurn)model\n"
    }

    /// Multi-turn render; always appends the trailing `<start_of_turn>model\n` opener.
    static func render(_ turns: [Turn]) -> String {
        var out = ""
        for turn in turns {
            out += "\(startOfTurn)\(turn.role.rawValue)\n\(turn.text)\(endOfTurn)\n"
        }
        out += "\(startOfTurn)model\n"
        return out
    }
}
