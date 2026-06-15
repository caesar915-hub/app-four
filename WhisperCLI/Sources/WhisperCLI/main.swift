import Foundation
import WhisperKit

let args = CommandLine.arguments

guard args.count >= 2 else {
    print("Usage: WhisperCLI <path-to-audio-file>")
    print("       WhisperCLI --summarize <path-to-audio-file>")
    print("")
    print("Supported formats: m4a, wav, mp3, flac, aiff")
    exit(1)
}

let shouldSummarize = args.contains("--summarize")
let audioPath = args.last { !$0.hasPrefix("-") && $0 != args[0] } ?? ""

let audioURL = URL(fileURLWithPath: audioPath)
guard FileManager.default.fileExists(atPath: audioURL.path) else {
    print("❌ File not found: \(audioPath)")
    exit(1)
}

print("🎙️  WhisperNotes CLI Transcription Tool")
print("========================================")
print("Audio file: \(audioURL.path)")
print("Duration: \(String(format: "%.1f", AudioConverter.getDuration(url: audioURL)))s")
print("")

let service = WhisperKitTranscriptionService()

// Preload model so the first run isn't slow
print("⏳ Loading Whisper model (will download on first run)...")
do {
    try await service.loadModel()
    print("✅ Model ready.\n")
} catch {
    print("❌ Failed to load model: \(error)")
    exit(1)
}

print("⏳ Transcribing...")
print("----------------------------------------")

do {
    let stream = try await service.transcribe(audioURL: audioURL)
    var finalText = ""

    for await segment in stream {
        if !segment.isFinal {
            print("[progress] \(segment.text)")
        } else {
            finalText = segment.text
        }
    }

    print("----------------------------------------")
    print("")
    print("📝 TRANSCRIPT:")
    print(finalText)
    print("")

    if shouldSummarize {
        print("(Summarization not wired in CLI. Transcript is above.)")
    }

    // Unload model to free RAM
    await service.unloadModel()

} catch {
    print("❌ Transcription failed: \(error)")
    exit(1)
}
