import AVKit
import SwiftUI
import AtomicXCore
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct VideoRecorderViewWrapper: UIViewControllerRepresentable {
    let config: VideoRecorderConfig?
    let onVideoCaptured: (String?, Int, String?) -> Void
    let onPhotoCaptured: (String?) -> Void
    var primaryColor: String?

    func makeUIViewController(context: Context) -> UIViewController {
        applyConfig()

        let videoRecorderControll = VideoRecorderController()

        let recordVCEditCallback: VideoRecorderRecordResultCallback = { videoPath, photo, duration in
            videoRecorderControll.dismiss(animated: true)
            var finalPath: String?
            if let finalPath = videoPath {
                onVideoCaptured(videoPath, Int(duration), getThumbnail(finalPath))
                return
            }

            if let photo = photo {
                finalPath = saveImage(photo)
                onPhotoCaptured(finalPath)
                return
            }

            onPhotoCaptured(nil)
        }

        videoRecorderControll.resultCallback = recordVCEditCallback
        videoRecorderControll.photoPreviewOverride = { controller, image in
            VideoRecorderPhotoEditBridge.present(from: controller, image: image, onConfirm: { editedImage in
                controller.resultCallback?(nil, editedImage, 0)
            }, onCancel: {})
        }
        videoRecorderControll.recordFilePath = createRecordedFilePath(messageType: .video, withExtension: "mov")
        return videoRecorderControll
    }

    private func saveImage(_ image: UIImage) -> String? {

        if let imageData = image.jpegData(compressionQuality: 0.8)
        {
            let path = createRecordedFilePath(messageType: .image, withExtension: "png")
            let fileURL = URL(fileURLWithPath: path)
            try? imageData.write(to: fileURL)
            return path
        }
        return nil
    }

    private func createRecordedFilePath(messageType: MessageType, withExtension: String?)->String {
        let path = ChatUtil.generateMediaPath(messageType: messageType, withExtension: withExtension)
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        return path
    }

    private func getThumbnail(_ videoPath: String) -> String? {
        let thumbnail = createThumbnail(from: URL(fileURLWithPath: videoPath))
        if let thumbnail = thumbnail {
            return saveImage(thumbnail)
        }
        return nil
    }

    private func createThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            let thumbnailCGImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailCGImage)
        } catch {
            return nil
        }
    }

    private func applyConfig() {
        let settings = VideoRecorderConfigInternal.sharedInstance()
        settings.resetToDefaults()
        if let color = primaryColor, !color.isEmpty {
            settings.themeColor = VideoRecorderCommon.color(fromHex: color)
        }
        guard let config = config else { return }
        let maxDuration = config.maxDurationMs
        let minDuration = config.minDurationMs
        settings.maxDurationMs = Int32(clamping: maxDuration > 0 ? maxDuration : VideoRecorderConfig.defaultMaxDurationMs)
        settings.minDurationMs = Int32(clamping: minDuration > 0 ? minDuration : VideoRecorderConfig.defaultMinDurationMs)
        settings.minDurationMs = min(settings.minDurationMs, settings.maxDurationMs)
        settings.videoQuality = Int32(config.videoQuality.rawValue)
        settings.recordMode = Int32(config.recordMode.rawValue)
        settings.frontCamera = config.isDefaultFrontCamera
        settings.supportAspect = config.isSupportAspect
        settings.supportTorch = config.isSupportTorch
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
