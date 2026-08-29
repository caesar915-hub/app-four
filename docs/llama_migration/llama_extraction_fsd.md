# Llama Extraction FSD

**Project:** On-Device AI Journal & Mood Tracker

**Target Hardware:** iPhone 12 Pro (A14 Bionic, 6GB RAM, iOS 17+)

**Core Technology:** MLX-Swift, Llama 3.2 (1B) 4-bit Quantized

**Last Verified:** August 2026



---



## 1. Purpose and Scope

This document outlines the functional requirements and system behavior for migrating the application from a rigid, deterministic Natural Language (NL) pipeline to a dynamic, LLM-driven journaling platform. 



### 1.1. Core Objectives

* **Unified Experience:** Eliminate the cognitive friction between taking a quick "Mood Check-in" and writing a "Journal Entry" by combining them into a single, seamless voice-first flow.

* **Deep Comprehension:** Move beyond surface-level keyword extraction. The system must understand context, nuance, and narrative to generate empathetic summaries and dynamic topic tags.

* **Privacy by Design:** Ensure 100% of audio transcription (via WhisperKit) and semantic extraction (via Llama 3.2 1B) occurs strictly on the user's device, with zero network calls.



---



## 2. Hardware Constraints (The iPhone 12 Pro Baseline)

The architecture is fundamentally constrained by the hardware limitations of the iPhone 12 Pro (released October 23, 2020 [[1]](https://en.wikipedia.org/wiki/IPhone_12_Pro)), which acts as our baseline for stability.



### 2.1. Memory Limits (Jetsam)

* **Physical RAM:** 6GB LPDDR4X [[2]](https://www.gsmarena.com/apple_iphone_12_pro-10508.php). Apple does not officially publish RAM specifications; this was confirmed via teardowns and Xcode beta files [[3]](https://9to5mac.com/2020/10/14/iphone-12-pro-ram/).

* **App Limit:** iOS uses a kernel mechanism called **Jetsam** to enforce per-process memory limits. On a 6GB device, these limits are dynamic but historically fall in the range of **2.5GB to 3GB** for foreground apps [[4]](https://developer.apple.com/documentation/os/os_proc_available_memory()). Apple does not publish fixed numbers; the exact ceiling depends on device state, iOS version, and system-wide memory pressure.

* **Increased Memory Entitlement:** Apple provides the `com.apple.developer.kernel.increased-memory-limit` entitlement to request a higher ceiling for apps with legitimate heavy workloads (e.g., on-device LLMs). This entitlement does **not** guarantee a specific amount of additional RAM; it is advisory [[5]](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit). This entitlement **must** be enabled for this app.

* **Model Footprint:** Llama 3.2 (1B) quantized to 4-bit has approximately 1.23B parameters [[6]](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct). At 4-bit precision, the raw weights occupy **~0.6–0.7GB**, with a total runtime footprint (including framework overhead) of approximately **0.74GB** [[7]](https://modal.com/blog/llm-memory-requirements). WhisperKit's Tiny model (~39M parameters) occupies approximately **~150MB** in loaded memory [[8]](https://github.com/argmaxinc/WhisperKit). Combined, the two models consume roughly **~0.9GB**, leaving approximately **1.6–2.1GB** of headroom within the Jetsam limit for the iOS system, UI frameworks, and the LLM's Key-Value (KV) cache.



### 2.2. Compute & Thermal Dynamics

* **A14 Bionic:** A 5nm SoC with a 16-core Neural Engine capable of 11 TOPS [[9]](https://www.apple.com/newsroom/2020/10/apple-introduces-iphone-12-pro-and-iphone-12-pro-max-with-5g/). While capable, continuous GPU inference for 10-15 seconds generates significant heat.

* **Inference Speed:** On the A14 Bionic, Llama 3.2 1B at 4-bit quantization is expected to generate approximately **15 to 30 tokens per second** [[10]](https://github.com/ggml-org/llama.cpp/discussions). This is well above human reading speed (~3-5 tokens/second) but meaningfully slower than newer A17 Pro devices (~40-60 tok/s).

* **Thermal Throttling:** If the user records multiple 10-minute journals back-to-back, iOS will throttle GPU clock speeds. Under thermal throttling, generation speed can drop below 10 tokens/second. The UX must account for variable latency gracefully.

* **Context Scaling:** The KV cache memory grows linearly with the number of input tokens. For a 15-minute transcript (~3,000 tokens), the KV cache requires approximately **100-150 MB** of RAM (at fp16 precision) for the 1B model. While well within the limits, unbounded context growth must be monitored.



### 2.3. Memory Monitoring

* **Runtime API:** The app must use `os_proc_available_memory()` [[11]](https://developer.apple.com/documentation/os/os_proc_available_memory()) to monitor remaining headroom at runtime. This API, introduced in iOS 13, returns the number of bytes available before the app hits its Jetsam limit. The value is dynamic and must not be cached.



---



## 3. Functional Requirements



### 3.1. Journal Input & Transcription

* **FR-1.1 (Duration):** The user can dictate continuously for up to 15 minutes.

* **FR-1.2 (Transcription Engine):** WhisperKit will transcribe the audio locally using a CoreML-optimized Whisper model [[12]](https://github.com/argmaxinc/WhisperKit). WhisperKit includes built-in Voice Activity Detection (VAD) that gates transcription to speech segments only, preventing hallucinations during silence and saving battery [[13]](https://docs.argmaxinc.com/whisperkit/).

* **FR-1.3 (Payload Size):** The average English conversational speaking rate is approximately **150 words per minute (wpm)**, with a typical range of 120–160 wpm [[14]](https://virtualspeech.com/blog/average-speaking-rate-words-per-minute). A 15-minute recording therefore yields approximately **2,250 words** (at 150 wpm). Using a standard tokenization ratio of ~1.3 tokens per English word, this translates to approximately **2,900–3,000 tokens**.



### 3.2. AI Synthesis (The Unified Schema)

* **FR-2.1 (Trigger):** Upon pressing "Stop & Save", the raw transcript is passed to the `MLXJournalService` without any arbitrary word-count gates (the "Pure Unified Schema" strategy).

* **FR-2.2 (System Prompt):** The LLM is instructed to read the text and populate a strict JSON schema dynamically.

* **FR-2.3 (Model):** Llama 3.2 1B Instruct [[15]](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) running via MLX-Swift [[16]](https://github.com/ml-explore/mlx-swift). The model natively supports a **128,000-token context window** [[17]](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/), far exceeding the ~3,000-token requirement. Meta explicitly designed this model for edge devices and mobile hardware.

* **FR-2.4 (Data Extraction):** The LLM must reliably extract:

  * **Summary:** A 2-3 sentence empathetic narrative summary (left `null` if the user only logged a short mood).

  * **Topics:** An array of 1-4 overarching themes (e.g., `["Work", "Anxiety", "Family"]`).

  * **Mood/Energy/Focus:** Categorical strings (e.g., "Great", "Good", "Okay", "Bad", "Awful") or scalar integers.

  * **Sleep & Meds:** Extraction of hours slept and specific medication names/dosages mentioned.

  * **Lexicon:** 3-5 unique slang words, idioms, or distinct phrases used by the user to build a linguistic profile.



### 3.3. User Interface & Experience (Progressive UX)

* **FR-3.1 (Thread Safety):** LLM inference must run strictly on a background actor/queue. The main UI thread must remain fully responsive at 60fps.

* **FR-3.2 (Progressive Recording UI):** 

  * *0s – 45s:* The UI displays *"How are you feeling?"* (Mood Check-in state).

  * *45s+:* The UI smoothly animates (e.g., expanding waveform, dimming background) and changes the prompt to *"Journaling..."* to indicate long-form capture.

* **FR-3.3 (Loading State):** Upon stopping, immediately display the raw transcript overlaid with an interactive shimmer effect or localized animation reading *"Synthesizing your journal..."* to mask the 5-15 second inference latency.

* **FR-3.4 (Completion & Haptics):** Upon successful JSON parsing, trigger a `UINotificationFeedbackGenerator.success` haptic. The loading state fades out, and the structured data cards (Mood, Topics, Summary) animate into view.

* **FR-3.5 (Editing):** The user retains ultimate agency; all AI-generated fields must be editable inline before final commitment to the database.



---



## 4. System Architecture



### 4.1. The AI Pipeline (Pure Unified Schema Strategy)

1. **Input:** Raw `String` from WhisperKit (duration agnostic).

2. **Prompt Construction (Zero Gates):** The string is injected into a single, unified System Prompt. There is no word-count check or prompt swapping.

3. **Memory Handoff (Peak Shaving):** To avoid memory pressure spikes, the `WhisperKit` context and model weights are explicitly deallocated from RAM before initializing the LLM engine.

4. **Inference Engine:** `mlx-swift` [[16]](https://github.com/ml-explore/mlx-swift) loads the 4-bit Llama 3.2 (1B) model into Unified Memory and generates the response.

5. **Parsing:** A Swift `JSONDecoder` parses the LLM output into the `UnifiedExtraction` struct. The LLM handles short check-ins by naturally leaving the `journal_summary` field null, and handles long journals by populating all fields.

6. **Fallback:** If parsing fails due to an LLM hallucination, the system attempts a basic regex cleanup of the string (stripping markdown backticks). If it still fails, the UI falls back to showing only the raw transcript, notifying the user that synthesis failed.



### 4.2. Data Models (SwiftData)

The structured data must be mapped to persistent local storage.



```swift

@Model

class JournalEntry {

    var id: UUID

    var date: Date

    var rawTranscript: String

    

    // AI Synthesized Data

    var summary: String?

    var topics: [String] = []

    var lexicon: [String] = []

    

    // Signals

    var mood: String?

    var energy: String?

    var focus: String?

    var sleepHours: Double?

    

    // Relationships

    @Relationship(deleteRule: .cascade) var medications: [MedicationEvent]

    

    init(rawTranscript: String) {

        self.id = UUID()

        self.date = Date()

        self.rawTranscript = rawTranscript

    }

}

```



---



## 5. System Prompt Specification

The system prompt is the single most important lever for controlling output quality on a 1B model. It must be rigid, explicit, and include few-shot examples. The following is the production prompt to be injected before every transcript.



### 5.1. The Prompt



```

You are a journal analysis engine. You receive a voice-note transcript

from a user's daily journal. You MUST respond with ONLY a single JSON

object. Do NOT include any text before or after the JSON. Do NOT wrap

the JSON in markdown backticks.



Use this EXACT schema:

{

  "mood": one of ["Great", "Good", "Okay", "Bad", "Awful"] or null,

  "energy": one of ["High", "Medium", "Low"] or null,

  "focus": one of ["Sharp", "Normal", "Scattered"] or null,

  "sleep_hours": number or null,

  "medications": [{"name": string, "dose": string, "taken": boolean}],

  "topics": [string],

  "lexicon": [string],

  "summary": string or null

}



RULES:

- If the text is ONLY a brief mood statement with no story or context,

  set "summary" to null. Populate only the mood/energy/focus fields.

- If the text contains events, reflections, reasoning, or narrative,

  write a warm, empathetic 2-3 sentence summary in second person ("You").

- "topics" must contain 1-4 high-level themes (e.g. "Work", "Family").

- "lexicon" must contain 3-5 unique slang words, idioms, or distinct phrases the user said (or [] if none).

- "medications" must be an empty array [] if none are mentioned.

- If a signal is not mentioned at all, set it to null.

- Do NOT invent information that is not in the text.

- "sleep_hours" must be a number between 0 and 24, or null.

```



### 5.2. Few-Shot Examples (Included in Prompt)

Few-shot examples are critical for a 1B model. They cost ~200 extra input tokens but dramatically improve classification accuracy.



```

EXAMPLE 1 — Short Mood Check-in:

User: "Feeling pretty anxious today. Took my Adderall this morning."

Assistant: {"mood":"Bad","energy":null,"focus":null,"sleep_hours":null,"medications":[{"name":"Adderall","dose":"morning","taken":true}],"topics":["Medication"],"lexicon":[],"summary":null}



EXAMPLE 2 — Journal Entry:

User: "I had a terrible meeting at work today. My manager called me out in front of everyone and I just froze. I didn't know what to say. I think I only got about 4 hours of sleep last night which definitely didn't help. I need to start going to bed earlier."

Assistant: {"mood":"Bad","energy":"Low","focus":"Scattered","sleep_hours":4,"medications":[],"topics":["Work","Sleep"],"lexicon":["called me out", "froze"],"summary":"You had a rough day after your manager put you on the spot during a meeting, and you froze under pressure. The lack of sleep made it harder to cope. You're recognizing that better rest could help you handle these moments."}



EXAMPLE 3 — Hybrid (Mood + Journal):

User: "I'm feeling really good today actually. I went for a run this morning for the first time in weeks and it felt amazing. I've been taking my Lexapro consistently and I think it's starting to help. Had a great chat with my sister too."

Assistant: {"mood":"Great","energy":"High","focus":"Sharp","sleep_hours":null,"medications":[{"name":"Lexapro","dose":"daily","taken":true}],"topics":["Exercise","Medication","Family"],"lexicon":["felt amazing", "great chat"],"summary":"You're feeling genuinely upbeat today after getting back into running and having a lovely conversation with your sister. The consistent Lexapro routine seems to be making a positive difference."}

```



### 5.3. Prompt Design Rationale

| Decision | Why |

|----------|-----|

| Enumerated mood values (`["Great", "Good", ...]`) | A 1B model will hallucinate free-form descriptors ("kinda meh"). Constraining to a fixed list forces reliable, chart-friendly data. |

| Second person ("You") in summaries | Creates an empathetic, coaching tone ("You had a rough day...") rather than clinical third person ("The user reported..."). |

| `null` instead of empty string | Cleanly distinguishes "not mentioned" from "mentioned but empty". Swift `Codable` handles `Optional` natively. |

| Examples before user input | Llama 3.2 processes tokens top-down. Placing examples before the actual transcript ensures they are fully in context when generation begins. |

| "Do NOT wrap in backticks" | Small models frequently wrap JSON in ` ```json ``` `. Explicitly forbidding it reduces (but does not eliminate) this behavior. |



---



## 6. Reliability & Validation Stack

A 1B parameter model will occasionally fail to follow instructions. The system must be designed so that **a failure in LLM output never results in data loss, a crash, or garbage on screen**. Reliability is enforced through four independent layers:



### 6.1. Layer 1 — Constrained Decoding (Structure Guarantee)

Constrained decoding (also called grammar-guided generation or GBNF in `llama.cpp`) forces the token sampler to only emit tokens that produce valid JSON at each decoding step.

* **What it guarantees:** The output is always syntactically valid JSON with the exact keys defined in the schema.

* **What it does NOT guarantee:** The semantic correctness of *values* (e.g., the model could write `"mood": "purple"`).

* **Status:** MLX-Swift does not yet have native grammar-constrained decoding. If unavailable, this layer is replaced by Layer 4 (Swift-side parsing).



### 6.2. Layer 2 — System Prompt (Value Control)

The system prompt (Section 5.1) constrains the *values* the model generates by explicitly enumerating valid options. This is the primary control mechanism for output quality.



### 6.3. Layer 3 — Few-Shot Examples (Behavioral Routing)

The three examples in Section 5.2 teach the model the critical distinction between check-ins, journals, and hybrids by demonstration rather than abstract rules. On a 1B model, examples are significantly more effective than rules alone.



### 6.4. Layer 4 — Swift-Side Validation (The Safety Net)

Regardless of how well the prompt works, the Swift parsing layer must be **paranoid and resilient**:



```swift

struct UnifiedExtraction: Codable {

    var mood: String?

    var energy: String?

    var focus: String?

    var sleepHours: Double?

    var medications: [MedicationEvent]

    var topics: [String]

    var lexicon: [String]

    var summary: String?

    

    enum CodingKeys: String, CodingKey {

        case mood, energy, focus

        case sleepHours = "sleep_hours"

        case medications, topics, lexicon, summary

    }

}



struct MedicationEvent: Codable {

    var name: String

    var dose: String

    var taken: Bool

}

```



```swift

/// Attempts to parse LLM output into a validated extraction.

/// Returns nil on failure — the UI will show raw transcript only.

func parseExtraction(_ raw: String) -> UnifiedExtraction? {

    

    // Step 1: Try direct JSON parse

    if let result = tryDecode(raw) {

        return validate(result)

    }

    

    // Step 2: Strip markdown backticks (common LLM habit)

    let cleaned = raw

        .replacingOccurrences(of: "```json", with: "")

        .replacingOccurrences(of: "```", with: "")

        .trimmingCharacters(in: .whitespacesAndNewlines)

    

    if let result = tryDecode(cleaned) {

        return validate(result)

    }

    

    // Step 3: Try to extract JSON from surrounding text

    if let start = cleaned.firstIndex(of: "{"),

       let end = cleaned.lastIndex(of: "}") {

        let jsonSlice = String(cleaned[start...end])

        if let result = tryDecode(jsonSlice) {

            return validate(result)

        }

    }

    

    // Step 4: Give up gracefully

    return nil

}



private func tryDecode(_ string: String) -> UnifiedExtraction? {

    guard let data = string.data(using: .utf8) else { return nil }

    return try? JSONDecoder().decode(UnifiedExtraction.self, from: data)

}



/// Clamps all values to valid ranges. Discards hallucinated values.

private func validate(_ e: UnifiedExtraction) -> UnifiedExtraction {

    var result = e

    

    let validMoods = ["Great", "Good", "Okay", "Bad", "Awful"]

    if let mood = e.mood, !validMoods.contains(mood) {

        result.mood = nil

    }

    

    let validEnergy = ["High", "Medium", "Low"]

    if let energy = e.energy, !validEnergy.contains(energy) {

        result.energy = nil

    }

    

    let validFocus = ["Sharp", "Normal", "Scattered"]

    if let focus = e.focus, !validFocus.contains(focus) {

        result.focus = nil

    }

    

    if let hours = e.sleepHours, (hours < 0 || hours > 24) {

        result.sleepHours = nil

    }

    

    // Cap topics to 4 max

    if result.topics.count > 4 {

        result.topics = Array(result.topics.prefix(4))

    }

    

    // Cap lexicon to 5 max

    if result.lexicon.count > 5 {

        result.lexicon = Array(result.lexicon.prefix(5))

    }

    

    return result

}

```



### 6.5. Expected Reliability

| Layer | Guarantees | Failure Mode |

|-------|-----------|--------------|

| Constrained decoding | Valid JSON structure, correct keys | Values may be semantically wrong |

| System prompt | Correct value ranges ~85% of the time | Small models occasionally ignore instructions |

| Few-shot examples | Correct check-in vs journal routing ~90%+ | Ambiguous edge cases |

| Swift validation | App never crashes, bad data is discarded | User sees raw transcript + manual entry |



**Combined expected accuracy: ~90-95% correct end-to-end extraction.** The remaining 5-10% is handled gracefully — the user sees their raw transcript and can fill in the mood/energy fields manually. The app never crashes, never shows garbage, and the user always keeps their data.



---



## 7. Non-Functional Requirements

* **NFR-1 (Privacy):** 100% of data processing must occur locally. No network requests containing user voice or text data are permitted. The app must declare `NSMicrophoneUsageDescription` in the `Info.plist` with a clear explanation that audio never leaves the device.

* **NFR-2 (Latency):** The Time-to-First-Token (TTFT) must be under 3 seconds for short inputs, but prompt processing (prefill) for a 3,000-token input may take ~10 seconds. Total output generation (producing the ~150-token JSON) must complete in under 20 seconds on the iPhone 12 Pro.

* **NFR-3 (Memory Safety):** The `MLXJournalService` must actively monitor memory allocation via `os_proc_available_memory()` [[11]](https://developer.apple.com/documentation/os/os_proc_available_memory()). If available memory falls below a critical threshold (e.g., 200MB), the app must abort the generation to prevent a Jetsam crash, preserving the user's raw transcript.

* **NFR-4 (Cold Start):** The Llama 3.2 model weights should be lazy-loaded only when the user taps "Stop & Save", ensuring the app launches instantly without loading ~0.7GB of weights into RAM at startup.

* **NFR-5 (Entitlements):** The app's `.entitlements` file must include `com.apple.developer.kernel.increased-memory-limit` [[5]](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit) to request the maximum available memory ceiling from iOS.



---



## Sources

| # | Claim | Source |

|---|-------|--------|

| 1 | iPhone 12 Pro release date (Oct 23, 2020) | [Wikipedia: iPhone 12 Pro](https://en.wikipedia.org/wiki/IPhone_12_Pro) |

| 2 | iPhone 12 Pro 6GB LPDDR4X RAM | [GSMArena: iPhone 12 Pro specs](https://www.gsmarena.com/apple_iphone_12_pro-10508.php) |

| 3 | RAM confirmed via Xcode beta files | [9to5Mac](https://9to5mac.com/2020/10/14/iphone-12-pro-ram/) |

| 4 | iOS Jetsam dynamic memory limits | [Apple Developer: os_proc_available_memory()](https://developer.apple.com/documentation/os/os_proc_available_memory()) |

| 5 | Increased Memory Limit entitlement | [Apple Developer: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit) |

| 6 | Llama 3.2 1B: 1.23B parameters | [HuggingFace: Llama-3.2-1B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) |

| 7 | 4-bit quantization memory formula | [Modal: LLM Memory Requirements](https://modal.com/blog/llm-memory-requirements) |

| 8 | WhisperKit Tiny model ~150MB loaded | [GitHub: WhisperKit](https://github.com/argmaxinc/WhisperKit) |

| 9 | A14 Bionic: 5nm, 16-core Neural Engine, 11 TOPS | [Apple Newsroom](https://www.apple.com/newsroom/2020/10/apple-introduces-iphone-12-pro-and-iphone-12-pro-max-with-5g/) |

| 10 | Llama 3.2 1B: ~15-30 tok/s on A14 (4-bit) | [llama.cpp discussions](https://github.com/ggml-org/llama.cpp/discussions) |

| 11 | `os_proc_available_memory()` API (iOS 13+) | [Apple Developer](https://developer.apple.com/documentation/os/os_proc_available_memory()) |

| 12 | WhisperKit: CoreML-optimized Whisper for iOS | [GitHub: WhisperKit](https://github.com/argmaxinc/WhisperKit) |

| 13 | WhisperKit VAD (Voice Activity Detection) | [Argmax: WhisperKit Docs](https://docs.argmaxinc.com/whisperkit/) |

| 14 | Average speaking rate: ~150 wpm | [VirtualSpeech](https://virtualspeech.com/blog/average-speaking-rate-words-per-minute) |

| 15 | Llama 3.2 1B Instruct model card | [HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) |

| 16 | MLX-Swift framework | [GitHub: mlx-swift](https://github.com/ml-explore/mlx-swift) |

| 17 | Llama 3.2: 128K context window, edge-optimized | [Meta AI Blog](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/) |
