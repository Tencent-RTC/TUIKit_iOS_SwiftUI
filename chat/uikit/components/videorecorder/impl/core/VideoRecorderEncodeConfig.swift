import Foundation

final class VideoRecorderEncodeConfig {
    private static let lowBitrate = 1000

    private static let mediumBitrate = 3000

    private static let highBitrate = 5000

    private static let normalFps = 25

    private static let highFps = 30

    let fps: Int

    let bitrate: Int

    private let videoQuality: VideoQuality

    init(videoQuality: VideoQuality) {
        switch videoQuality {
        case .low:
            bitrate = Self.lowBitrate
            fps = Self.normalFps
        case .high:
            bitrate = Self.highBitrate
            fps = Self.highFps
        case .medium:
            bitrate = Self.mediumBitrate
            fps = Self.normalFps
        }
        self.videoQuality = videoQuality
    }

    func getVideoEditCompressed() -> VideoRecordCompressed {
        return videoQuality == .high ? .compressed1080P : .compressed720P
    }

    func getVideoRecordResolution() -> VideoRecordResolution {
        return videoQuality == .high ? .resolution1080x1920 : .resolution720x1280
    }
}
