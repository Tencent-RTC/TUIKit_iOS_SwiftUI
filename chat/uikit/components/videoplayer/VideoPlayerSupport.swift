import AVKit
import SwiftUI
import UIKit

public extension View {
    func videoPlayerSupport() -> some View {
        modifier(VideoPlayerSupportModifier())
    }
}

public struct VideoPlayerOverlayView: View {
    @ObservedObject private var videoPlayer = VideoPlayer.shared

    public init() {}

    public var body: some View {
        EmptyView()
            .fullScreenCover(isPresented: $videoPlayer.isPresented) {
                VideoPlayerView()
            }
    }
}

public struct VideoPlayerView: View {
    @ObservedObject private var videoPlayer = VideoPlayer.shared
    public init(showsCloseButton: Bool = false) {}

    public var body: some View {
        ZStack {
            Colors.Black1.ignoresSafeArea()
            CustomVideoPlayerView(
                player: videoPlayer.player,
                allowSeeking: true,
                onDismiss: {
                    videoPlayer.dismiss()
                }
            )
            .ignoresSafeArea(.all)
        }
        .accessibilityIdentifier("chat_video_player")
    }
}

public struct CustomVideoPlayerView: UIViewControllerRepresentable {
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
        VideoPlayer.shared.register(controller: controller)

        return controller
    }

    public static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        VideoPlayer.shared.unregister(controller: uiViewController)
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
            self.onDismiss?()
        }
    }
}
