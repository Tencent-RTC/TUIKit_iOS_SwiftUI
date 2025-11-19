import AVFoundation
import AVKit
import SwiftUI

public struct AudioRecorderViewConfig {
    public var enableAIDeNoise: Bool
    public var minDurationMs: Int // ms
    public var maxDurationMs: Int // ms
    public var primaryColor: String
    public var backgroundColor: String

    public init(enableAIDeNoise: Bool? = nil,
                minDurationMs: Int? = nil,
                maxDurationMs: Int? = nil,
                primaryColor: String? = nil,
                backgroundColor: String? = nil,
                heigh: CGFloat? = nil) {
        // To use AI noise reduction, the app must depend on LiteAVSDK_Professional v12.7+ and have the feature enabled.
        // Dependency: Add the dependency in your project or any module’s Podfile: “pod 'TXLiteAVSDK_Professional'”
        // For enabling permissions, see documentation: https://cloud.tencent.com/document/product/269/113290
        self.enableAIDeNoise = enableAIDeNoise ?? true
        self.minDurationMs = minDurationMs ?? 1000
        self.maxDurationMs = maxDurationMs ?? 60000
        self.primaryColor = primaryColor ?? "#147AFF"
        self.backgroundColor = backgroundColor ?? "#FFFFFF"
    }
}


public struct AudioRecorderView: View {
    @Binding var cancelRecording: Bool
    private let config: AudioRecorderViewConfig
    private var onRecordingComplete: ((String?, Int) -> Void)?

    public init(cancelRecording: Binding<Bool>,
                config: AudioRecorderViewConfig = AudioRecorderViewConfig(),
                onRecordingComplete: ((String?, Int) -> Void)? = nil) {
        self._cancelRecording = cancelRecording
        self.config = config
        self.onRecordingComplete = onRecordingComplete
    }

    public var body: some View {
        AudioRecorderViewImpl(
            cancelRecording: $cancelRecording,
            config: config,
            onRecordingComplete: onRecordingComplete
        )
    }
}

public class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorderImpl()
    
    public var onRecordingComplete: ((_ resultCode: AudioRecordResultCode, _ filePath: String, _ durationMs: Int) -> Void)?
    public var onRecordTime: ((_ timeMs: Int) -> Void)?
    public var onPowerLevel: ((_ powerLevel: Int) -> Void)?
    
    public func startRecord(filepath: String? = nil, enableAIDeNoise: Bool = false, minDurationMs: Int = 1000, maxDurationMs: Int = 60000) {}
    
    public func stopRecord() {}
    
    public func cancelRecord() {}

    override internal init() {
        super.init()
    }
}

public enum AudioRecordResultCode: Int {
    case exceedMaxDuration = 1
    case success = 0
    case errorCancel = -1
    case errorRecording = -2
    case errorStorageUnavailable = -3
    case errorLessThanMinDuration = -4
    case errorRecordInnerFail = -5
    case errorRecordPermissionDenied = -6
}
