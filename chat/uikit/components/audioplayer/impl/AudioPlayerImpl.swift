import AVFoundation
import AVKit
import Combine
import SwiftUI

extension AudioPlayer {
    static func createImplementation() -> AudioPlayer {
        return AudioPlayer()
    }

    func playImplementation(_ url: URL) {
        if isPlaying, currentPlayingURL == url {
            teardownPlayer()
            return
        }
        if player != nil {
            teardownPlayer()
        }
        playInternal(url)
    }

    func pauseImplementation() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
        isPaused = true
    }

    func resumeImplementation() {
        guard let player = player, isPaused else { return }
        player.play()
        isPlaying = true
        isPaused = false
    }

    func stopImplementation() {
        guard player != nil else { return }
        teardownPlayer()
    }

    func setAudioOutputDeviceImplementation() {
        // TODO: Implement audio output device selection
        // This would typically involve AVAudioSession route change handling
    }

    func getCurrentPositionImplementation() -> Int {
        guard let item = playerItem else { return 0 }
        let seconds = CMTimeGetSeconds(item.currentTime())
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return Int(seconds * 1000)
    }

    func getDurationImplementation() -> Int {
        guard let item = playerItem else { return 0 }
        let seconds = CMTimeGetSeconds(item.duration)
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return Int(seconds * 1000)
    }

    private func playInternal(_ url: URL) {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioPlayer: AVAudioSession setup failed: \(error.localizedDescription)")
            teardownPlayer()
            return
        }
        #endif

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .pause

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            print("AudioPlayer: Playback finished")
            self?.teardownPlayer()
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            print("AudioPlayer: Item failed to play to end: \(error?.localizedDescription ?? "unknown")")
            self?.teardownPlayer()
        }

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self = self else { return }
            switch observedItem.status {
            case .failed:
                print("AudioPlayer: Item status failed: \(observedItem.error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { self.teardownPlayer() }
            case .readyToPlay, .unknown:
                break
            @unknown default:
                break
            }
        }

        playerItem = item
        player = avPlayer
        currentPlayingURL = url
        isPlaying = true
        isPaused = false

        avPlayer.play()
    }

    func teardownPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        if let observer = failedObserver {
            NotificationCenter.default.removeObserver(observer)
            failedObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        player?.pause()
        player = nil
        playerItem = nil

        // 避免重复发布停止状态，否则延迟事件会清除新音频的播放标记。
        if isPlaying { isPlaying = false }
        if isPaused { isPaused = false }
        if currentPlayingURL != nil { currentPlayingURL = nil }
    }

    func registerRecordStartObserver() {
        recordStartObserver = NotificationCenter.default.addObserver(
            forName: .voiceInputRecordStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
        }
}
