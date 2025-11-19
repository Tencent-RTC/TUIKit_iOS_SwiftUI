import AtomicXCore
import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
    case videoOnly = 2
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

public class VideoRecorderConfig {
    var recordMode: RecordMode?
    var videoQuality: VideoQuality?
    var minDurationMs: Int?
    var maxDurationMs: Int?
    var isDefaultFrontCamera: Bool?
    var primaryColor: String?
    var isSupportEdit: Bool?
    var isSupportBeauty: Bool?
    var isSupportTorch: Bool?
    var isSupportAspect:Bool?
    
    init() {}

    init(recordMode: RecordMode? = nil,
         videoQuality: VideoQuality? = nil,
         minDurationMs: Int? = nil,
         maxDurationMs: Int? = nil,
         isDefaultFrontCamera: Bool? = nil,
         primaryColor: String? = nil,
         isSupportEdit: Bool? = nil,
         isSupportBeauty: Bool? = nil,
         isSupportTorch: Bool? = nil,
         isSupportAspect:Bool? = nil
    ) {
        
        self.videoQuality = videoQuality
        self.recordMode = recordMode
        self.minDurationMs = minDurationMs
        self.maxDurationMs = maxDurationMs
        self.primaryColor = primaryColor
        self.isDefaultFrontCamera = isDefaultFrontCamera
        self.isSupportEdit = isSupportEdit
        self.isSupportBeauty = isSupportBeauty
        self.isSupportTorch = isSupportTorch
        self.isSupportAspect = isSupportAspect
    }
}

public struct VideoRecorder: View {
    @Environment(\.presentationMode) var presentationMode

    let config: VideoRecorderConfig?
    let onMediaCaptured: (String?, MediaType) -> Void


    public init(config: VideoRecorderConfig?, onMediaCaptured: @escaping (String?, MediaType) -> Void) {
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
