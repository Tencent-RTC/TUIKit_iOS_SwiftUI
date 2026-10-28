import AVKit
import SwiftUI
import UIKit

class VideoPlayerContainerViewController: UIViewController {
    private let playerViewController: AVPlayerViewController

    init(playerViewController: AVPlayerViewController) {
        self.playerViewController = playerViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Colors.Black1)

        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerViewController.didMove(toParent: self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

struct VideoPlayerSupportModifier: ViewModifier {
    @ObservedObject private var videoPlayer = VideoPlayer.shared
    private let presentsInCover: Bool

    init(presentsInCover: Bool = true) {
        self.presentsInCover = presentsInCover
    }

    func body(content: Content) -> some View {
        if presentsInCover {
            content
                .fullScreenCover(isPresented: $videoPlayer.isPresented, onDismiss: {
                    videoPlayer.finishDismissal()
                }) {
                    VideoPlayerView()
                }
        } else {
            content
        }
    }
}
