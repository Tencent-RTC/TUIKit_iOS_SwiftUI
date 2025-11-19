import AVKit
import SwiftUI
import AtomicXCore
import Combine
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct VideoRecorderViewWrapper: UIViewControllerRepresentable {
    let config: VideoRecorderConfig?
    let onMediaCaptured: (String?, MediaType) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        fetchVideoRecorderSignature()
        
        if let config = buildConfigJSON(from: config) {
            VideoRecorderConfigInternal.sharedInstance().setCustomConfig(config)
        }
        
        let videoRecorderControll = VideoRecorderController()
        
        let recordVCEditCallback: (String?, UIImage?) -> Void = { videoPath, photo in
            videoRecorderControll.dismiss(animated: true)
            var mediaType:MediaType = .video
            var finalPath: String?
            if let videoPath = videoPath {
                finalPath = videoPath
                mediaType = .video
            }
            
            if let photo = photo {
                finalPath =  saveImage(photo)
                mediaType = .photo
            }
            
            onMediaCaptured(finalPath, mediaType)
        }
    
        videoRecorderControll.resultCallback = recordVCEditCallback
        videoRecorderControll.recordFilePath = createRecordedFilePath(messageType: .video, withExtension: "mov")
        return videoRecorderControll
    }
    
    func saveImage(_ image: UIImage) -> String? {
        
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
    
    func buildConfigJSON(from config: VideoRecorderConfig?) -> String? {
        guard let config = config else {
            return nil;
        }
        
        var configDict: [String: Any] = [:]
        if let maxDuration = config.maxDurationMs {
            configDict["max_record_duration_ms"] = maxDuration
        }
        
        if let minDuration = config.minDurationMs {
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
                
        if let isSupportEdit = config.isSupportEdit {
            configDict["support_edit"] = isSupportEdit ? "true" : "false"
        }
        
        if let isSupportAspect = config.isSupportAspect {
            configDict["support_record_aspect"] = isSupportAspect ? "true" : "false"
        }
        
        if let isSupportBeauty = config.isSupportBeauty {
            configDict["support_record_beauty"] = isSupportBeauty ? "true" : "false"
        }
        
        if let isSupportTorch = config.isSupportTorch {
            configDict["support_record_torch"] = isSupportTorch ? "true" : "false"
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


public func fetchVideoRecorderSignature() {
    if (VideoRecordSignatureChecker.shareInstance().getSetSignatureResult() == .VIDEO_RECORD_SIGNATURE_SUCCESS) {
        return
    }
    
    let currentLoginStatus = LoginStore.shared.state.value.loginStatus
    if currentLoginStatus == .logined {
        VideoRecordSignatureChecker.shareInstance().startUpdateSignature(
            NSNumber(value: LoginStore.shared.sdkAppID).stringValue)
        return
    }
    
    var cancellables = Set<AnyCancellable>()
    LoginStore.shared.state
        .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
        .first()
        .sink { loginStatus in
            if loginStatus == .logined {
                VideoRecordSignatureChecker.shareInstance().startUpdateSignature(
                    NSNumber(value: LoginStore.shared.sdkAppID).stringValue)
            }
        }
        .store(in: &cancellables)
}
