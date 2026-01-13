import SwiftUI
import Photos
import AtomicXCore

public enum VideoPickerMode {
    case videos
    case all
}

public enum VideoTranscodeQuality: String {
    case low
    case medium
    case high
}

public enum PickMediaType {
    case image
    case video
    case gif
}

public class VideoPickModel: NSObject {
    public var id : Int = 0
    public var mediaPath: String? = nil
    public var mediaType: PickMediaType = .image
    public var videoThumbnailPath: String? = nil
    public var isOrigin: Bool = false
}

// MARK: - VideoPickerView Config
public struct VideoPickerConfig {
    public var maxImagesCount: Int
    public var columnNumber: Int
    public var showEditButton: Bool
    public var showOriginalToggle: Bool
    public var model: VideoPickerMode
    public var primaryColor: String?
    public var maxConcurrentTranscodingCount: Int
    public var transcodeQuality: VideoTranscodeQuality
    
    public init(model: VideoPickerMode = .all,
                maxImagesCount: Int = 9,
                columnNumber: Int = 4,
                showEditButton: Bool = false,
                showOriginalToggle: Bool = false,
                primary: String? = nil,
                transcodeQuality: VideoTranscodeQuality = .medium,
                maxConcurrentTranscodingCount: Int = 3) {
        self.maxImagesCount = maxImagesCount
        self.columnNumber = columnNumber
        self.showEditButton = showEditButton
        self.showOriginalToggle = showOriginalToggle
        self.model = model
        self.primaryColor = primary
        self.maxConcurrentTranscodingCount = maxConcurrentTranscodingCount
        self.transcodeQuality = transcodeQuality
    }
}


// MARK: - VideoPickerView
public struct VideoPicker: View {
    private let config: VideoPickerConfig
    private let onFinishedSelect: (_ ImageCount: Int) -> Void
    private let onProgress: ((VideoPickModel, Int, Double) -> Void)?

    public init(
        config: VideoPickerConfig = VideoPickerConfig(),
        onFinishedSelect: @escaping (_ ImageCount: Int) -> Void,
        onProgress: ((VideoPickModel, Int, Double) -> Void)? = nil
    ) {
        self.config = config
        self.onFinishedSelect = onFinishedSelect
        self.onProgress = onProgress
    }

    public var body: some View {
        AlbumPicker(
            config: AlbumPickerConfig(
                maxImagesCount: config.maxImagesCount,
                columnNumber: config.columnNumber,
                albumMode: (config.model == .videos ? .videos : .all),
                primary: config.primaryColor
            ),
            onFinishedSelect: { count in
                self.onFinishedSelect(count)
            },
            onProgress: { alumbPickModel, index, progress in
                let model = VideoPickModel()
                model.id = alumbPickModel.id
                model.mediaPath = alumbPickModel.mediaPath
                model.mediaType = alumbPickModel.mediaType
                model.videoThumbnailPath = alumbPickModel.videoThumbnailPath
                model.isOrigin = alumbPickModel.isOrigin
                self.onProgress?(model, index, progress)
            }
        )
    }
}


// MARK: - Helpers
fileprivate func saveImageToTempPath(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }

    let path = ChatUtil.generateMediaPath(messageType: .image, withExtension: "jpg")
    let directory = (path as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)

    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        return path
    } catch {
        print("ImagePickerView: failed to write image to path: \(path), error: \(error)")
        return nil
    }
}
