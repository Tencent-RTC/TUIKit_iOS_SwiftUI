import AVKit
import SwiftUI

public class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var currentPlayingURL: URL? = nil
    private var audioPlayer: AVAudioPlayer?

    public static func create() -> AudioPlayer {
        return AudioPlayer()
    }

    public func play(_ url: URL) {
        if isPlaying && currentPlayingURL == url {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
            currentPlayingURL = nil
            return
        }
        if isPlaying {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
            currentPlayingURL = nil
        }
        playInternal(url)
    }

    public func pause() {
        guard let player = audioPlayer, isPlaying else { return }
        player.pause()
        isPlaying = false
        isPaused = true
    }

    public func resume() {
        guard let player = audioPlayer, isPaused else { return }
        if player.play() {
            isPlaying = true
            isPaused = false
        }
    }

    public func stop() {
        guard let player = audioPlayer else { return }
        player.stop()
        audioPlayer = nil
        isPlaying = false
        isPaused = false
        currentPlayingURL = nil
    }

    public func setAudioOutputDevice() {
        // TODO: Implement audio output device selection
        // This would typically involve AVAudioSession route change handling
    }

    public func getCurrentPosition() -> Int {
        guard let player = audioPlayer else { return 0 }
        return Int(player.currentTime * 1000) // Return milliseconds
    }

    public func getDuration() -> Int {
        guard let player = audioPlayer else { return 0 }
        return Int(player.duration * 1000) // Return milliseconds
    }

    private func playInternal(_ url: URL) {
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            if audioPlayer?.play() == true {
                isPlaying = true
                isPaused = false
                currentPlayingURL = url
            } else {
                print("Audio playback failed")
                audioPlayer = nil
                isPlaying = false
                isPaused = false
                currentPlayingURL = nil
            }
        } catch {
            print("Audio playback error: \(error.localizedDescription)")
            audioPlayer = nil
            isPlaying = false
            isPaused = false
            currentPlayingURL = nil
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Playback finished successfully: \(flag)")
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        isPaused = false
        currentPlayingURL = nil
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decoding error: \(error?.localizedDescription ?? "Unknown error")")
        audioPlayer = nil
        isPlaying = false
        isPaused = false
        currentPlayingURL = nil
    }
}
