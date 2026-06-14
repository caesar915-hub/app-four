import Foundation
import AVFoundation

@Observable
@MainActor
final class AudioPlaybackViewModel: NSObject {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing(currentTime: TimeInterval)
        case paused(currentTime: TimeInterval)
        case finished
        case error(String)
    }

    private(set) var state: PlaybackState = .idle
    private(set) var duration: TimeInterval = 0
    var currentTime: TimeInterval = 0
    private(set) var isScrubbing = false

    private var player: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?
    private let recording: Recording
    private let storageService: AudioFileStorageService

    init(recording: Recording, storageService: AudioFileStorageService) {
        self.recording = recording
        self.storageService = storageService
    }

    func play() {
        if player == nil {
            guard let url = storageService.getAudioURL(for: recording) else {
                state = .error("Audio file not found")
                return
            }
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.delegate = self
                p.prepareToPlay()
                player = p
                duration = p.duration
            } catch {
                state = .error(error.localizedDescription)
                return
            }
        }

        if case .finished = state {
            player?.currentTime = 0
        }

        player?.play()
        currentTime = player?.currentTime ?? 0
        state = .playing(currentTime: currentTime)
        startProgressPolling()
    }

    func pause() {
        player?.pause()
        state = .paused(currentTime: player?.currentTime ?? 0)
        progressTask?.cancel()
    }

    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        player?.currentTime = clamped
        currentTime = clamped
        switch state {
        case .playing:
            state = .playing(currentTime: clamped)
        case .paused, .finished, .idle, .loading, .error:
            state = .paused(currentTime: clamped)
        }
    }

    func beginScrubbing() {
        isScrubbing = true
    }

    func endScrubbing(at time: TimeInterval) {
        isScrubbing = false
        seek(to: time)
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        progressTask?.cancel()
        state = .idle
        currentTime = 0
    }

    func cleanup() {
        progressTask?.cancel()
        player?.stop()
        player = nil
    }

    private func startProgressPolling() {
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                if !isScrubbing, let t = player?.currentTime {
                    currentTime = t
                    if case .playing = state {
                        state = .playing(currentTime: t)
                    }
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}

extension AudioPlaybackViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.state = .finished
            self.currentTime = self.duration
            self.progressTask?.cancel()
        }
    }
}
