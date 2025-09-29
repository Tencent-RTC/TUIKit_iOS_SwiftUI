import AVFoundation
import Foundation
import os.log

public class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorderImpl()
    
    @Published public internal(set) var currentPower: Float = 0
    @Published public internal(set) var currentTime: Int = 0
    public var onRecordingComplete: ((_ retCode:AudioRecordResultCode, _ filepath:String, _ duration:Int) -> Void)?
    
    public func startRecord(filepath: String? = nil, enableAIDeNoise: Bool = false) {}
    
    public func stopRecord() {}
    
    public func cancelRecord() {}
    
    override internal init() {
        super.init()
    }
}

public enum AudioRecordResultCode: Int {
    case success = 0
    case errorCancel = -1
    case errorRecording = -2
    case errorStorageUnavailable = -3
    case errorLessThanMinDuration = -4
    case errorRecordInnerFail = -5
    case errorRecordPermissionDenied = -6
    case errorUseAIDenoiseNoLiteavSDK = -7
    case errorUseAIDenoiseNoIMSDK = -8
    case errorUseAIDenoiseAPPIDEMPTY = -9
    case errorUseAIDenoiseNoSignature = -10
    case errorUseAIDenoiseWrongSignature = -11
}

extension AudioRecordResultCode {
    static func fromCode(_ code: Int) -> AudioRecordResultCode {
        return AudioRecordResultCode(rawValue: code) ?? .errorRecordInnerFail
    }
}
