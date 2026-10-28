import AVFoundation
import AVKit
import Combine
import SwiftUI

public class AudioPlayer: NSObject, ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var currentPlayingURL: URL? = nil

    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var endObserver: NSObjectProtocol?
    var failedObserver: NSObjectProtocol?
    var itemStatusObservation: NSKeyValueObservation?
    var recordStartObserver: NSObjectProtocol?

    public override init() {
        super.init()
        registerRecordStartObserver()
    }

    public static func create() -> AudioPlayer { Self.createImplementation() }

    public func play(_ url: URL) { playImplementation(url) }

    public func pause() { pauseImplementation() }

    public func resume() { resumeImplementation() }

    public func stop() { stopImplementation() }

    public func setAudioOutputDevice() { setAudioOutputDeviceImplementation() }

    public func getCurrentPosition() -> Int { getCurrentPositionImplementation() }

    public func getDuration() -> Int { getDurationImplementation() }

    deinit {
        if let recordStartObserver {
            NotificationCenter.default.removeObserver(recordStartObserver)
        }
        teardownPlayer()
    }
}
