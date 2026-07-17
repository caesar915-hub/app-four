import Foundation
import AVFoundation

/// Service implementation for managing audio recording using AVFoundation.
final class AudioRecordingServiceImpl: NSObject, AudioRecordingService, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var interruptionObserver: NSObjectProtocol?
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var isRecording: Bool = false
    private var wasInterrupted: Bool = false
    private var interruptionHandler: (@Sendable (RecordingInterruption) -> Void)?

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: AudioConstants.sampleRate,
        AVNumberOfChannelsKey: AudioConstants.channels,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    var audioLevelStream: AsyncStream<Float> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    if let recorder = recorder, recorder.isRecording {
                        recorder.updateMeters()
                        let power = recorder.averagePower(forChannel: 0)
                        
                        #if targetEnvironment(simulator)
                        // Simulator fake levels: sine wave between 0.2 and 0.8
                        let time = Date().timeIntervalSince1970
                        let normalized = Float(sin(time * 5) * 0.3 + 0.5)
                        #else
                        // Real device normalization
                        let linear = pow(10, power / 20.0)
                        let normalized = max(0.01, min(1.0, Float(linear)))
                        #endif
                        
                        continuation.yield(normalized)
                    } else {
                        continuation.yield(0.01)
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    func startRecording() async throws -> URL {
        // Disk check
        if await availableStorage() < 20_000_000 {
            throw RecordingError.deviceDiskFull
        }
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP])
        try session.setActive(true)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString.lowercased()).m4a"
        let url = tempDir.appendingPathComponent(fileName)
        
        recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true

        guard recorder?.prepareToRecord() == true, recorder?.record() == true else {
            throw RecordingError.hardwareFailure
        }
        
        startTime = Date()
        accumulatedTime = 0
        isRecording = true
        wasInterrupted = false

        setupInterruptionObserver()
        // 037 — the max-duration cap is enforced solely by CheckInViewModel's timer now
        // (which counts pause-adjusted elapsed time). The former service-level timer
        // raced the view model's finalize and could nil the recorder mid-save → lost
        // capture; it was removed.
        
        AppLogger.log("Recording started at \(url.path)")
        return url
    }
    
    func pauseRecording() async {
        guard let recorder = recorder, recorder.isRecording else { return }
        recorder.pause()
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        startTime = nil
        isRecording = false
        AppLogger.log("Recording paused. Accumulated time: \(accumulatedTime)")
    }
    
    func resumeRecording() async throws {
        guard let recorder = recorder, !recorder.isRecording else { return }
        if recorder.record() {
            startTime = Date()
            isRecording = true
            AppLogger.log("Recording resumed")
        } else {
            throw RecordingError.hardwareFailure
        }
    }
    
    func stopRecording() async throws -> (fileURL: URL, duration: TimeInterval) {
        guard let recorder = recorder else {
            throw RecordingError.unknown
        }

        let finalDuration = totalDuration
        recorder.stop()

        let url = recorder.url
        cleanup()

        // Ensure duration is at least the audio recorder's reported duration as a fallback
        let recordedDuration = max(finalDuration, recorder.currentTime)

        AppLogger.log("Recording stopped. Calculated duration: \(finalDuration)s, recorder time: \(recorder.currentTime)s, final: \(recordedDuration)s")
        return (url, recordedDuration)
    }
    
    func cancelRecording() async {
        guard let recorder = recorder else { return }
        let url = recorder.url
        recorder.stop()
        try? FileManager.default.removeItem(at: url)
        cleanup()
        AppLogger.log("Recording cancelled and file deleted")
    }

    func setInterruptionHandler(_ handler: (@Sendable (RecordingInterruption) -> Void)?) {
        interruptionHandler = handler
    }
    
    private var totalDuration: TimeInterval {
        var current = accumulatedTime
        if let start = startTime {
            current += Date().timeIntervalSince(start)
        }
        return current
    }
    
    private func cleanup() {
        recorder = nil

        startTime = nil
        accumulatedTime = 0
        isRecording = false
        wasInterrupted = false
        removeInterruptionObserver()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }
    
    private func removeInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }
    
    /// Pure decision policy for an audio-session interruption, separated from the
    /// AVFoundation side effects so it can be unit-tested.
    nonisolated enum InterruptionResponse: Equatable {
        case pause          // .began while recording — the system already paused us
        case resume         // .ended with .shouldResume after we paused
        case stayPaused     // .ended without .shouldResume — keep what we captured
        case ignore
    }

    static func interruptionResponse(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions,
        isRecording: Bool,
        wasInterrupted: Bool
    ) -> InterruptionResponse {
        switch type {
        case .began:
            return isRecording ? .pause : .ignore
        case .ended:
            guard wasInterrupted else { return .ignore }
            return options.contains(.shouldResume) ? .resume : .stayPaused
        @unknown default:
            return .ignore
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        let options = AVAudioSession.InterruptionOptions(
            rawValue: userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        )
        // Never stop/cancel from here: that path discarded the recording AND
        // bypassed the view model's save/transcribe pipeline. Pause and resume
        // instead, so a transient interruption (Siri, a brief call, a route blip)
        // never loses the in-progress recording.
        switch Self.interruptionResponse(type: type, options: options,
                                         isRecording: isRecording, wasInterrupted: wasInterrupted) {
        case .pause:      pauseForInterruption()
        case .resume:     resumeFromInterruption()
        case .stayPaused:
            AppLogger.log("Interruption ended without .shouldResume — staying paused; recording preserved")
            interruptionHandler?(.endedWithoutResume)
        case .ignore:     break
        }
    }

    private func pauseForInterruption() {
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        startTime = nil
        isRecording = false
        wasInterrupted = true
        AppLogger.log("Interruption began — recording paused (\(accumulatedTime)s captured)")
        interruptionHandler?(.paused)
    }

    private func resumeFromInterruption() {
        wasInterrupted = false
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if recorder?.record() == true {
                startTime = Date()
                isRecording = true
                AppLogger.log("Interruption ended — recording resumed")
                interruptionHandler?(.resumed)
            } else {
                AppLogger.log("Interruption ended — recorder failed to resume")
            }
        } catch {
            AppLogger.log("Interruption ended — failed to reactivate session: \(error)")
        }
    }
    
    private func availableStorage() async -> Int64 {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let attributes = (try? FileManager.default.attributesOfFileSystem(forPath: path)) ?? [:]
        return (attributes[.systemFreeSize] as? Int64) ?? 0
    }
}

