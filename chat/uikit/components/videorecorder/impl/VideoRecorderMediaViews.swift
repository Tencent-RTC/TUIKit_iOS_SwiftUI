import AlbumPickerCore
import AVFoundation
import SwiftUI
import UIKit

struct VideoRecorderCameraPreview: UIViewRepresentable {
    let onCreate: (UIView) -> Void

    func makeUIView(context: Context) -> VideoRecorderCameraPreviewHostView {
        let view = VideoRecorderCameraPreviewHostView()
        DispatchQueue.main.async {
            onCreate(view)
        }
        return view
    }

    func updateUIView(_ uiView: VideoRecorderCameraPreviewHostView, context: Context) {}
}

final class VideoRecorderCameraPreviewHostView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayers?.compactMap { $0 as? AVCaptureVideoPreviewLayer }.forEach { $0.frame = bounds }
        CATransaction.commit()
    }
}

struct VideoRecorderPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoRecorderPlayerHostView {
        let view = VideoRecorderPlayerHostView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: VideoRecorderPlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class VideoRecorderPlayerHostView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
}

struct VideoRecorderPhotoEditView: UIViewRepresentable {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ImageEditView {
        AlbumPickerCoreTheme.shared.currentPrimaryColor = UIColor(ThemeState.shared.colors.buttonColorPrimaryDefault)
        let editView = ImageEditView(sourceImage: image)
        editView.editDelegate = context.coordinator
        return editView
    }

    func updateUIView(_ uiView: ImageEditView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: ImageEditDelegate {
        var parent: VideoRecorderPhotoEditView

        init(parent: VideoRecorderPhotoEditView) {
            self.parent = parent
        }

        func imageEditView(_ editView: ImageEditView, didCompleteWithImage editedImage: UIImage) {
            parent.onConfirm(editedImage)
        }

        func imageEditViewDidCancel(_ editView: ImageEditView) {
            parent.onCancel()
        }
    }
}
