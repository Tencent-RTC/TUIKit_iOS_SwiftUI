import Photos
import SwiftUI
import UIKit

public struct ImageViewerView: View {
    private let implementation: ImageViewerImpl

    public init(imageElements: [ImageElement], initialIndex: Int = 0, presentsVideoPlayer: Bool = true, onEventTriggered: @escaping ([String: Any], @escaping (Any?) -> Void) -> Void) {
        implementation = ImageViewerImpl(
            imageElements: imageElements,
            initialIndex: initialIndex,
            presentsVideoPlayer: presentsVideoPlayer,
            onEventTriggered: onEventTriggered
        )
    }

    public var body: some View { implementation }
}

public struct ImageElement {
    public let type: Int
    public let imagePath: String
    public let videoPath: String?

    public init(type: Int, imagePath: String, videoPath: String? = nil) {
        self.type = type
        self.imagePath = imagePath
        self.videoPath = videoPath
    }
}
