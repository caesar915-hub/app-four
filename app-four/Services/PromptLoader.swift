import Foundation
import SquirlSignals
import Yams

/// Loads the MLX pipeline prompts from `Resources/Prompts.yaml`.
///
/// `Prompts.yaml` is the editable source of truth for every system and user
/// prompt. Placeholders like `{{transcript}}` are replaced at runtime.
///
/// If the YAML file is missing or a key cannot be read, the loader falls back
/// to the compiled-in defaults and logs a warning so the pipeline keeps
/// working while edits are being iterated on.
nonisolated enum PromptLoader {

    // MARK: - YAML model

    private struct Prompts: Codable {
        let summarySystem: String
        let summaryUser: String
        let signalSystem: String
        let signalUser: String
        let signalCorrection: String

        enum CodingKeys: String, CodingKey {
            case summarySystem = "summary_system"
            case summaryUser = "summary_user"
            case signalSystem = "signal_system"
            case signalUser = "signal_user"
            case signalCorrection = "signal_correction"
        }
    }

    // MARK: - Defaults

    private static let defaultSummarySystem = """
    You are an objective voice journal summarizer.
    Write a clear, concise 1-2 sentence summary capturing the full arc of the speaker's experience, feelings, and actions.
    Output only the summary text. Do not converse with the user, do not give advice, do not make medical claims, and do not assume unmentioned side effects.
    """

    private static let defaultSummaryUser = """
    Transcript: "{{transcript}}"

    Write a 1-2 sentence summary capturing what the speaker experienced:
    """

    private static let defaultSignalSystem = """
    You are a strict JSON-only clinical extraction API for an ADHD tracking app.
    Your entire response must be a single valid JSON object. No prose, no markdown, no code fences, no explanations.

    TEMPORAL RULES (CRITICAL):
    1. Ground every signal in the user's CURRENT state — the present moment ("NOW") at the time of the check-in.
    2. If the user contrasts past/earlier states with their current state (e.g. "I was exhausted and sad all morning, but right now I feel energized and good" or "woke up feeling awful, but after my Concerta I'm locked in and feeling sharp now"), extract ONLY the current state (mood "good" / "great", energy "alert" / "charged", focus "lockedIn" / "sharp") — NEVER extract the earlier morning state.
    3. If the user felt great earlier but experienced a crash or headache later (e.g. "felt on top of the world until 3pm when I crashed hard and now have a migraine"), extract the current post-crash state: mood "low", energy "sluggish", sideEffects ["migraine"].
    4. If a medication is skipped or missed (e.g. "skipped my Elvanse today"), extract it with "taken": false: [{"name":"Elvanse","dose":null,"taken":false}].
    5. Past states belong only in narrative summaries; they must NEVER appear in the signals JSON.
    6. Sleep metrics (sleepHours, sleepQuality) always refer to the preceding night.

    WHEN TO USE null:
    Use null ONLY when the transcript contains no evidence at all for the field. Explicit statements MUST be mapped to the closest allowed label — "I feel great" / "feeling unstoppable" → mood "great"; "well-rested" → mood "good", energy "alert"; "ready to work" → focus "present"; "no energy" / "exhausted" / "tired" → energy "sluggish" or "tired"; "can't focus" / "can't concentrate" / "severe brain fog" → focus "foggy" or "distracted"; "my mood is flat" / "meh" → mood "flat"; "zombie mode" / "brain fried" → mood "flat", energy "sluggish", focus "foggy". Never return null for a signal the user explicitly states.

    ALLOWED VALUES:
    - mood: {{moodLabels}}
    - energy: {{energyLabels}}
    - focus: {{focusLabels}}
    - sleepQuality: {{sleepLabels}}
    - medications: {{medications}}, Vyvanse, Concerta, Elvanse, Adderall, Ritalin, Strattera

    EXAMPLES:
    Transcript: "I was exhausted and sad all morning, but right now I feel energized and good."
    Output:
    {"mood":"good","energy":"charged","focus":"sharp","sleepHours":null,"sleepQuality":null,"medications":[],"emotions":["energized"],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}

    Transcript: "Woke up feeling awful and foggy, could barely function. But after lunch and my 20mg Concerta, I'm locked in and feeling sharp."
    Output:
    {"mood":"good","energy":"charged","focus":"lockedIn","sleepHours":null,"sleepQuality":null,"medications":[{"name":"Concerta","dose":"20mg","taken":true}],"emotions":[],"activities":[],"topics":["Medications"],"lexicon":[],"sideEffects":[]}

    Transcript: "My mood is flat, energy is sluggish, can't focus on anything."
    Output:
    {"mood":"flat","energy":"sluggish","focus":"foggy","sleepHours":null,"sleepQuality":null,"medications":[],"emotions":[],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}

    Transcript: "Woke up at 6am, ran 5k, had breakfast. Took 20mg Adderall at 8am. Was feeling on top of the world until 3pm when I crashed hard and now have a migraine."
    Output:
    {"mood":"low","energy":"sluggish","focus":"foggy","sleepHours":null,"sleepQuality":null,"medications":[{"name":"Adderall","dose":"20mg","taken":true}],"emotions":[],"activities":["exercise"],"topics":["Medications"],"lexicon":[],"sideEffects":["migraine"]}

    Transcript: "In total zombie mode, brain is completely fried, doomscrolling for 3 hours."
    Output:
    {"mood":"flat","energy":"sluggish","focus":"foggy","sleepHours":null,"sleepQuality":null,"medications":[],"emotions":["frustrated"],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}

    Transcript: "Nailed my presentation, got shit done, feeling unstoppable!"
    Output:
    {"mood":"great","energy":"charged","focus":"sharp","sleepHours":null,"sleepQuality":null,"medications":[],"emotions":["excited"],"activities":["presentation"],"topics":[],"lexicon":[],"sideEffects":[]}

    Transcript: "I skipped my Elvanse today because I woke up too late."
    Output:
    {"mood":null,"energy":"tired","focus":null,"sleepHours":null,"sleepQuality":null,"medications":[{"name":"Elvanse","dose":null,"taken":false}],"emotions":[],"activities":[],"topics":["Medications"],"lexicon":[],"sideEffects":[]}

    Transcript: "Tired."
    Output:
    {"mood":null,"energy":"tired","focus":null,"sleepHours":null,"sleepQuality":null,"medications":[],"emotions":[],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}
    """

    private static let defaultSignalUser = """
    Extract the CURRENT check-in signals from this transcript into JSON matching this schema:
    {
      "mood": string or null,
      "energy": string or null,
      "focus": string or null,
      "sleepHours": number or null,
      "sleepQuality": string or null,
      "medications": [{ "name": string, "dose": string or null, "taken": boolean }],
      "emotions": [string],
      "activities": [string],
      "topics": [string],
      "lexicon": [string],
      "sideEffects": [string]
    }

    Transcript:
    "{{transcript}}"
    """

    private static let defaultSignalCorrection = """
    The previous response was not valid JSON. Return ONLY a single JSON object for the transcript below. No prose, no markdown, no code fences, no explanations.

    Transcript:
    "{{transcript}}"
    """

    // MARK: - Public API

    static func loadSummarySystemPrompt() -> String {
        return load(key: .summarySystem, fallback: defaultSummarySystem)
    }

    static func loadSummaryUserPrompt(transcript: String) -> String {
        let template = load(key: .summaryUser, fallback: defaultSummaryUser)
        return template.replacingOccurrences(of: "{{transcript}}", with: transcript)
    }

    static func loadSignalSystemPrompt(lexicon: Lexicon) -> String {
        let template = load(key: .signalSystem, fallback: defaultSignalSystem)
        return template
            .replacingOccurrences(of: "{{moodLabels}}", with: MoodLevel.allCases.map(\.rawValue).joined(separator: ", "))
            .replacingOccurrences(of: "{{energyLabels}}", with: EnergyLevel.allCases.map(\.rawValue).joined(separator: ", "))
            .replacingOccurrences(of: "{{focusLabels}}", with: FocusLevel.allCases.map(\.rawValue).joined(separator: ", "))
            .replacingOccurrences(of: "{{sleepLabels}}", with: SleepLevel.allCases.map(\.rawValue).joined(separator: ", "))
            .replacingOccurrences(of: "{{medications}}", with: formatMedications(lexicon.medications))
    }

    static func loadSignalUserPrompt(transcript: String) -> String {
        let template = load(key: .signalUser, fallback: defaultSignalUser)
        return template.replacingOccurrences(of: "{{transcript}}", with: transcript)
    }

    static func loadSignalCorrectionPrompt(transcript: String) -> String {
        let template = load(key: .signalCorrection, fallback: defaultSignalCorrection)
        return template.replacingOccurrences(of: "{{transcript}}", with: transcript)
    }

    // MARK: - YAML loading

    private static let cache = Cache()

    private enum PromptKey: String {
        case summarySystem = "summary_system"
        case summaryUser = "summary_user"
        case signalSystem = "signal_system"
        case signalUser = "signal_user"
        case signalCorrection = "signal_correction"
    }

    private static func load(key: PromptKey, fallback: String) -> String {
        if let cached = cache.value(for: key.rawValue) {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "Prompts", withExtension: "yaml"),
              let data = try? Data(contentsOf: url),
              let yamlString = String(data: data, encoding: .utf8),
              let prompts = try? YAMLDecoder().decode(Prompts.self, from: yamlString) else {
            AppLogger.log("PromptLoader warning: could not load key '\(key.rawValue)' from Prompts.yaml; using compiled-in default.")
            return fallback
        }

        let value: String
        switch key {
        case .summarySystem: value = prompts.summarySystem
        case .summaryUser: value = prompts.summaryUser
        case .signalSystem: value = prompts.signalSystem
        case .signalUser: value = prompts.signalUser
        case .signalCorrection: value = prompts.signalCorrection
        }

        cache.set(value: value, for: key.rawValue)
        return value
    }

    private static func formatMedications(_ medications: [String]) -> String {
        medications
            .joined(separator: ", ")
            .replacingOccurrences(of: "PM", with: "pm")
            .replacingOccurrences(of: "AM", with: "am")
    }

    // MARK: - Cache

    private final class Cache: @unchecked Sendable {
        private var storage: [String: String] = [:]
        private let lock = NSLock()

        func value(for key: String) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func set(value: String, for key: String) {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = value
        }
    }
}
