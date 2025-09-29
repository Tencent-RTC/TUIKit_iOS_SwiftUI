import Foundation

public struct ImageElement {
    public let type: Int // 0: Image, 1: Video
    public let imagePath: String
    public let videoPath: String?

    public init(type: Int, imagePath: String, videoPath: String? = nil) {
        self.type = type
        self.imagePath = imagePath
        self.videoPath = videoPath
    }
}
