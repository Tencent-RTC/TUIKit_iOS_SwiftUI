import AVFoundation
import SwiftUI
import UIKit
#if canImport(PhotosUI)
import PhotosUI
#endif

public struct VideoPickerConfig {
    var maxCount: Int = 1
    var gridCount: Int = 4
    var primaryColor: Int = -1
}

public struct VideoPicker: UIViewControllerRepresentable {
    static var selectedVideo: ((URL?) -> Void)?
    static let shared = VideoPicker()
    static var config: VideoPickerConfig?

    public static func pickVideos(videoPickerConfig: VideoPickerConfig? = nil,
                                  selectedVideo: @escaping (URL?) -> Void) -> VideoPicker
    {
        self.selectedVideo = selectedVideo
        config = videoPickerConfig
        return shared
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        #if canImport(PhotosUI)
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.filter = .videos
            config.selectionLimit = 1
            config.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = context.coordinator
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeHigh
            picker.allowsEditing = false
            return picker
        }
        #else
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        return picker
        #endif
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject {
        let parent: VideoPicker
        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        #if canImport(PhotosUI)
        @available(iOS 14, *)
        func handlePHPickerResult(_ results: [PHPickerResult]) {
            guard let result = results.first else {
                VideoPicker.selectedVideo?(nil)
                return
            }
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        VideoPicker.selectedVideo?(nil)
                    }
                    return
                }
                guard let videoURL = url else {
                    DispatchQueue.main.async {
                        VideoPicker.selectedVideo?(nil)
                    }
                    return
                }
                let tempURL = self.createTempVideoFile(from: videoURL)
                if let tempVideoURL = tempURL {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.compressAndConvertVideo(sourceURL: tempVideoURL) { compressedURL in
                            DispatchQueue.main.async {
                                if let finalURL = compressedURL {
                                    VideoPicker.selectedVideo?(finalURL)
                                } else {
                                    VideoPicker.selectedVideo?(tempVideoURL)
                                }
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        VideoPicker.selectedVideo?(videoURL)
                    }
                }
            }
        }
        #endif
    }
}

#if canImport(PhotosUI)
@available(iOS 14, *)
extension VideoPicker.Coordinator: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        handlePHPickerResult(results)
    }
}
#endif
extension VideoPicker.Coordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            let securityScoped = videoURL.startAccessingSecurityScopedResource()
            let tempURL = createTempVideoFile(from: videoURL)
            if securityScoped {
                videoURL.stopAccessingSecurityScopedResource()
            }
            if let tempVideoURL = tempURL {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.compressAndConvertVideo(sourceURL: tempVideoURL) { compressedURL in
                        DispatchQueue.main.async {
                            if let finalURL = compressedURL {
                                VideoPicker.selectedVideo?(finalURL)
                            } else {
                                VideoPicker.selectedVideo?(tempVideoURL)
                            }
                        }
                    }
                }
            } else {
                VideoPicker.selectedVideo?(videoURL)
            }
        } else {
            VideoPicker.selectedVideo?(nil)
        }
        picker.dismiss(animated: true)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        VideoPicker.selectedVideo?(nil)
        picker.dismiss(animated: true)
    }
}

extension VideoPicker.Coordinator {
    private func createTempVideoFile(from sourceURL: URL) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".mp4"
        let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            return nil
        }
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        exportSession.outputURL = tempFileURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        let semaphore = DispatchSemaphore(value: 0)
        var exportResult: URL? = nil
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                exportResult = tempFileURL
            case .failed:
                print("export video failed")
            case .cancelled:
                print("export video cancelled")
            default:
                print("export video status:\(exportSession.status.rawValue)")
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 60.0)
        return exportResult
    }

    func compressAndConvertVideo(sourceURL: URL, completion: @escaping (URL?) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            completion(nil)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                DispatchQueue.main.async {
                    completion(outputURL)
                }
            case .failed:
                DispatchQueue.main.async {
                    completion(nil)
                }
            case .cancelled:
                DispatchQueue.main.async {
                    completion(nil)
                }
            default:
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
