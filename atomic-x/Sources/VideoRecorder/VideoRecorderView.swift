import AtomicXCore
import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
}

public enum MediaType {
    case photo
    case video
}

public enum VideoQuality: Int {
    case low = 1
    case medium = 2
    case high = 3
}

public class VideoRecorderConfigBuilder {
    var maxVideoDuration: Int?
    var minVideoDuration: Int?
    var videoQuality: VideoQuality?
    var recordMode: RecordMode?
    var primaryColor: String?
    var isDefaultFrontCamera: Bool?

    init() {}

    init(
        maxVideoDuration: Int? = nil,
        minVideoDuration: Int? = nil,
        videoQuality: VideoQuality? = nil,
        recordMode: RecordMode? = nil,
        primaryColor: String? = nil,
        isDefaultFrontCamera: Bool? = nil
    ) {
        self.maxVideoDuration = maxVideoDuration
        self.minVideoDuration = minVideoDuration
        self.videoQuality = videoQuality
        self.recordMode = recordMode
        self.primaryColor = primaryColor
        self.isDefaultFrontCamera = isDefaultFrontCamera
    }
}

public struct VideoRecorderView: View {
    @Environment(\.presentationMode) var presentationMode
    let config: VideoRecorderConfigBuilder?
    let onMediaCaptured: (URL, MediaType) -> Void

    public init(config: VideoRecorderConfigBuilder?, onMediaCaptured: @escaping (URL, MediaType) -> Void) {
        self.config = config
        self.onMediaCaptured = onMediaCaptured
    }

    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            VideoRecorderViewWrapper(config: config, onMediaCaptured: onMediaCaptured)
                .edgesIgnoringSafeArea(.all)
            #else
            EmptyView()
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
}
