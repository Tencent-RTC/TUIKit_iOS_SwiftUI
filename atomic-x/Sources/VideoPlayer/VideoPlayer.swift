import AVKit
import SwiftUI
import UIKit

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

public class VideoPlayer: ObservableObject {
    public static let shared = VideoPlayer()
    
    @Published public var isPresented = false
    @Published public var currentVideoData: VideoData?
    @Published public var player: AVPlayer?
    
    private init() {}
    
    public func play(videoData: VideoData) {
        print("VideoPlayer: Starting to play video with URI: \(videoData.uri)")
        currentVideoData = videoData
        setupPlayer(with: videoData)
        isPresented = true
        print("VideoPlayer: isPresented set to true")
    }
    
    public func dismiss() {
        print("VideoPlayer: Dismissing video player")
        player?.pause()
        player = nil
        currentVideoData = nil
        isPresented = false
    }
    
    private func setupPlayer(with videoData: VideoData) {
        let videoURL: URL
        if let localPath = videoData.localPath, !localPath.isEmpty {
            videoURL = URL(fileURLWithPath: localPath)
            print("VideoPlayer: Using local path: \(localPath)")
        } else {
            videoURL = URL(string: videoData.uri) ?? URL(fileURLWithPath: videoData.uri)
            print("VideoPlayer: Using URI: \(videoData.uri)")
        }
        
        print("VideoPlayer: Final video URL: \(videoURL)")
        
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            print("VideoPlayer: Video finished playing")
            self?.dismiss()
        }
        
        newPlayer.play()
        player = newPlayer
        print("VideoPlayer: Player created and started")
    }
}

public struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    let allowSeeking: Bool
    let onDismiss: (() -> Void)?
    
    public init(player: AVPlayer?, allowSeeking: Bool = true, onDismiss: (() -> Void)? = nil) {
        self.player = player
        self.allowSeeking = allowSeeking
        self.onDismiss = onDismiss
    }
    
    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.modalPresentationStyle = .fullScreen
        controller.showsPlaybackControls = allowSeeking
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.delegate = context.coordinator
        
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.showsPlaybackControls = allowSeeking
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    public class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: (() -> Void)?
        
        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {}
        
        public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {}
        
        public func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {}
        
        public func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            coordinator.animate(alongsideTransition: nil) { _ in
                self.onDismiss?()
            }
        }
    }
}

public struct VideoPlayerView: View {
    @ObservedObject private var videoPlayer = VideoPlayer.shared
    
    public init() {}
    
    public var body: some View {
        CustomVideoPlayer(
            player: videoPlayer.player,
            allowSeeking: true,
            onDismiss: {
                videoPlayer.dismiss()
            }
        )
        .ignoresSafeArea(.all)
    }
}

public struct VideoPlayerOverlay: View {
    @ObservedObject private var videoPlayer = VideoPlayer.shared
    
    public init() {}
    
    public var body: some View {
        EmptyView()
            .fullScreenCover(isPresented: $videoPlayer.isPresented) {
                VideoPlayerView()
            }
    }
}

public struct VideoPlayerSupportModifier: ViewModifier {
    @ObservedObject private var videoPlayer = VideoPlayer.shared
    
    public func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $videoPlayer.isPresented) {
                VideoPlayerView()
            }
    }
}

public extension View {
    func videoPlayerSupport() -> some View {
        modifier(VideoPlayerSupportModifier())
    }
}
