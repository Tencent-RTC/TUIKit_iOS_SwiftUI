import AVKit
import SwiftUI
import AtomicXCore
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct VideoRecorderViewWrapper: UIViewControllerRepresentable {
    let config: VideoRecorderConfigBuilder?
    let onMediaCaptured: (URL, MediaType) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        if let config = buildConfigJSON(from: config) {
            VideoRecorderConfig.sharedInstance().setCustom(config)
        }
        
        let videoRecorderControll = VideoRecorderController()
        let sdkAppId = NSNumber(value: LoginStore.shared.sdkAppID).stringValue
        VideoRecordSignatureChecker.shareInstance().setSignatureToSDK(sdkAppId)
        
        let recordVCEditCallback: (String?, UIImage?) -> Void = { videoPath, photo in
            videoRecorderControll.dismiss(animated: true)
            var mediaType:MediaType = .video
            var fileURL: URL?
            if let videoPath = videoPath {
                fileURL = URL(fileURLWithPath: videoPath)
                mediaType = .video
            }
            
            if let photo = photo {
                fileURL =  saveImage(photo)
                mediaType = .photo
            }
            
            onMediaCaptured(fileURL ?? URL(fileURLWithPath: ""), mediaType)
        }
    
        videoRecorderControll.resultCallback = recordVCEditCallback
        videoRecorderControll.recordFilePath = createRecordedFilePath(messageType: .video, withExtension: "mov")
        return videoRecorderControll
    }
    
    func saveImage(_ image: UIImage) -> URL? {
        
        if let imageData = image.jpegData(compressionQuality: 0.8)
        {
            let path = createRecordedFilePath(messageType: .image, withExtension: "png")
            let fileURL = URL(fileURLWithPath: path)
            try? imageData.write(to: fileURL)
            return fileURL
        }
        return nil
    }
    
    private func createRecordedFilePath(messageType: MessageType, withExtension: String?)->String {
        let path = ChatUtil.generateMediaPath(messageType: messageType, withExtension: withExtension)
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        return path
    }
    
    func buildConfigJSON(from config: VideoRecorderConfigBuilder?) -> String? {
        guard let config = config else {
            return nil;
        }
        
        var configDict: [String: Any] = [:]
        if let maxDuration = config.maxVideoDuration {
            configDict["max_record_duration_ms"] = maxDuration
        }
        
        if let minDuration = config.minVideoDuration {
            configDict["min_record_duration_ms"] = minDuration
        }
        
        if let quality = config.videoQuality {
            configDict["video_quality"] = quality.rawValue
        }
        
        if let mode = config.recordMode {
            configDict["record_mode"] = mode.rawValue
        }
        
        if let color = config.primaryColor {
            configDict["primary_theme_color"] = color
        }
        
        if let isFrontCamera = config.isDefaultFrontCamera {
            configDict["is_default_front_camera"] = isFrontCamera ? "true" : "false"
        }
        
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: configDict,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("JSON builder fail: \(error)")
            return nil
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
