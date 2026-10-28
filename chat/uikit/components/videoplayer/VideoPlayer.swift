import AVKit
import SwiftUI
import UIKit

public class VideoPlayer: ObservableObject {
    public static let shared = VideoPlayer()
    
    @Published public var isPresented = false
    @Published public var currentVideoData: VideoData?
    @Published public var player: AVPlayer?

    var playbackEndObserver: NSObjectProtocol?
    weak var mountedController: AVPlayerViewController?
    var playbackExitHandler: ((VideoPlaybackExitReason) -> Void)?

    private init() {}
    
    public func play(videoData: VideoData, onExit: ((VideoPlaybackExitReason) -> Void)? = nil) {
        playImplementation(videoData: videoData, onExit: onExit)
    }
    
    public func playWithUIKit(videoData: VideoData) { playWithUIKitImplementation(videoData: videoData) }
    
    public func dismiss() { dismissImplementation() }

}

public enum VideoPlaybackExitReason {
    case dismissed
    case playbackEnded
}

public struct VideoData {
    public let uri: String
    public let localPath: String?
    public let width: Int
    public let height: Int
    public let duration: TimeInterval?
    public let snapshotUrl: String?
    public let snapshotLocalPath: String?

    public init(
        uri: String,
        localPath: String? = nil,
        width: Int,
        height: Int,
        duration: TimeInterval? = nil,
        snapshotUrl: String? = nil,
        snapshotLocalPath: String? = nil
    ) {
        self.uri = uri
        self.localPath = localPath
        self.width = width
        self.height = height
        self.duration = duration
        self.snapshotUrl = snapshotUrl
        self.snapshotLocalPath = snapshotLocalPath
    }
}

public extension Notification.Name {
    static let chatVideoPlaybackDidStart = Notification.Name("ChatVideoPlaybackDidStart")
}
