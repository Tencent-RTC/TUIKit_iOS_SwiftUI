import AVKit
import SwiftUI
import UIKit

extension VideoPlayer {
    func playImplementation(videoData: VideoData, onExit: ((VideoPlaybackExitReason) -> Void)?) {
        dismissImplementation()
        print("VideoPlayer: Starting to play video with URI: \(videoData.uri)")
        NotificationCenter.default.post(name: .chatVideoPlaybackDidStart, object: nil)
        playbackExitHandler = onExit
        currentVideoData = videoData
        setupPlayer(with: videoData)
        isPresented = true
        print("VideoPlayer: isPresented set to true")
    }

    func playWithUIKitImplementation(videoData: VideoData) {
        print("VideoPlayer: Starting to play video with UIKit, URI: \(videoData.uri)")
        NotificationCenter.default.post(name: .chatVideoPlaybackDidStart, object: nil)
        currentVideoData = videoData

        let videoURL: URL
        if let localPath = videoData.localPath, !localPath.isEmpty {
            videoURL = URL(fileURLWithPath: localPath)
        } else {
            videoURL = URL(string: videoData.uri) ?? URL(fileURLWithPath: videoData.uri)
        }

        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player

        let containerVC = VideoPlayerContainerViewController(playerViewController: playerVC)
        containerVC.modalPresentationStyle = .fullScreen
        containerVC.modalTransitionStyle = .crossDissolve

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(containerVC, animated: true) {
                player.play()
            }
        }
    }

    func dismissImplementation(reason: VideoPlaybackExitReason = .dismissed) {
        guard isPresented || playbackExitHandler != nil else { return }
        let exitingPlayer = player
        let onExit = playbackExitHandler
        playbackExitHandler = nil
        player?.pause()
        removePlaybackEndObserver()
        Self.withoutAnimation {
            isPresented = false
            onExit?(reason)
        }
        if mountedController == nil, player === exitingPlayer {
            finishDismissal()
        }
    }

    func register(controller: AVPlayerViewController) {
        if controller.player === player {
            mountedController = controller
        }
    }

    func unregister(controller: AVPlayerViewController) {
        guard mountedController === controller else { return }
        mountedController = nil
        let exitingPlayer = controller.player
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.mountedController == nil, self.player === exitingPlayer else { return }
            self.dismiss()
            self.finishDismissal()
        }
    }

    func finishDismissal() {
        guard !isPresented, player != nil || currentVideoData != nil else { return }
        player?.pause()
        removePlaybackEndObserver()
        player = nil
        currentVideoData = nil
    }

    private func removePlaybackEndObserver() {
        if let observer = playbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackEndObserver = nil
        }
    }

    static func withoutAnimation(_ block: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            block()
        }
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

        removePlaybackEndObserver()
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.player?.currentItem === playerItem else { return }
            self.dismissImplementation(reason: .playbackEnded)
        }

        newPlayer.play()
        player = newPlayer
        print("VideoPlayer: Player created and started")
    }
}
