import SwiftUI
import Photos
import AtomicXCore

// MARK: - ImagePicker Config
public struct ImagePickerConfig {
    public var maxImagesCount: Int
    public var columnNumber: Int
    public var primaryColor: String?
    public var showEditButton: Bool
    public var showOriginalToggle: Bool

    public init(maxImagesCount: Int = 9,
                columnNumber: Int = 4,
                primaryColor: String? = nil,
                showEditButton: Bool = false,
                showOriginalToggle: Bool = false) {
        self.maxImagesCount = maxImagesCount
        self.columnNumber = columnNumber
        self.primaryColor = primaryColor
        self.showEditButton = showEditButton
        self.showOriginalToggle = showOriginalToggle
    }
}

// MARK: - ImagePickerView
public struct ImagePicker: View {
    private let config: ImagePickerConfig
    private let onFinishedSelect: (_ ImageCount: Int) -> Void
    private let onImagesReady: (_ path: String, _ isOrigin: Bool, _ index: Int) -> Void

    public init(
        config: ImagePickerConfig = ImagePickerConfig(),
        onFinishedSelect: @escaping (_ ImageCount: Int) -> Void,
        onImagesReady: @escaping (_ path: String, _ isOrigin: Bool, _ index: Int) -> Void
    ) {
        self.config = config
        self.onFinishedSelect = onFinishedSelect
        self.onImagesReady = onImagesReady
    }

    public var body: some View {
        AlbumPicker(
            config: AlbumPickerConfig(
                maxImagesCount: config.maxImagesCount,
                columnNumber: config.columnNumber,
                showEditButton: config.showEditButton,
                showOriginalToggle: config.showOriginalToggle,
                albumMode: .images,
                primary: config.primaryColor
            ),
            onFinishedSelect: { count in
                onFinishedSelect(count)
            },
            onProgress: { pickModel, index, progress in
                if progress >= 1.0 {
                    if let imagePath = pickModel.mediaPath {
                        onImagesReady(imagePath, pickModel.isOrigin, index)
                    }
                }
            }
        )
    }
}
