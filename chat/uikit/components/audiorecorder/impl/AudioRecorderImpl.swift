
import AVFoundation
import AtomicXCore
import Foundation
import os.log

extension Notification.Name {
    static let voiceInputRecordStart = Notification.Name("voiceInputRecordStartNotification")
}

internal class AudioRecorderImpl: AudioRecorder {
    private let logger = Logger(subsystem: "AudioRecoder", category: "AudioRecorderControl")
    private static let kMinDuration:Int = 1000
    private static let kMaxDuration:Int = 60000

    private var recordedFilePath: String?
    private var recorder:AudioRecorderInternalProtocol?
    private var isCancelRecord:Bool = false
    private var isRecording: Bool = false
    private var minDurationMs: Int = AudioRecorderImpl.kMinDuration
    private var maxDurationMs: Int = AudioRecorderImpl.kMaxDuration
    private var currentTime:Int = 0

    override func startRecord(filepath: String? = nil,
                                     minDurationMs: Int = AudioRecorderImpl.kMinDuration, maxDurationMs: Int = AudioRecorderImpl.kMaxDuration) {
        logger.info("start record file path is \( filepath ?? "") minDuration: \(minDurationMs) maxDuration : \(maxDurationMs)")

        NotificationCenter.default.post(name: .voiceInputRecordStart, object: nil)

        self.minDurationMs = minDurationMs
        self.maxDurationMs = maxDurationMs

        checkMicPermission { [weak self] isGranted, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if isGranted {
                    self.executeOnMainThread {
                        self.startRecordInternal(filepath)
                    }
                } else {
                    self.logger.error("request record audio permission refuse")
                    self.notifyCompleteOnMainThread(.errorRecordPermissionDenied)
                }
            }
        }
    }

    override func stopRecord() {
        logger.info("stop record")
        executeOnMainThread {
            if (!self.isRecording) {
                return
            }
            self.isRecording = false
            if let recorder = self.recorder  {
                recorder.stopRecord()
            }
        }
    }

    override func cancelRecord() {
        logger.info("cancel record")
        executeOnMainThread {
            if (!self.isRecording) {
                return
            }
            self.isCancelRecord = true
            self.notifyCompleteOnMainThread(.errorCancel)
            self.stopRecord()
        }
    }

    override init() {
        super.init()

        recorder = AudioRecorderTXUGC()
        if recorder == nil {
            recorder = AudioRecorderSystem()
        }

        var listener = AudioRecorderListener()
        listener.onProgress = { [weak self] duration in
            self?.currentTime = duration
            self?.onRecordTime?(duration)
        }
        listener.onPower = { [weak self] power in
            self?.onPowerLevel?(power)
        }
        listener.onComplete = onComplete
        recorder?.setListener(listener)
    }

    private func startRecordInternal(_ filepath: String? = nil){
        logger.info("start record internal")
        if isRecording {
            logger.error("recording failed because it is currently being recorded")
            notifyCompleteOnMainThread(.errorRecording)
            return
        }

        recordedFilePath = filepath
        if recordedFilePath == nil {
            recordedFilePath = createRecordedFilePath()
        }

        guard let recordedFilePath = recordedFilePath, !recordedFilePath.isEmpty else {
            logger.error("start record fail. because recorder init fail or recorded file path is empty")
            notifyCompleteOnMainThread(.errorStorageUnavailable)
            return
        }

        guard let recorder = recorder else {
            logger.error("recorder is nil")
            return
        }

        isRecording = true
        isCancelRecord = false
        recorder.startRecord(recordedFilePath, minDurationMs, maxDurationMs)
    }

    private func createRecordedFilePath()->String {
        let path = ChatUtil.generateMediaPath(messageType: .audio, withExtension: "m4a")
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        return path
    }

    private func checkMicPermission(completion: @escaping (Bool, Bool) -> Void) {
        let permission = AVAudioSession.sharedInstance().recordPermission

        if permission == .denied || permission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted, true)
                }
            }
            return
        }

        let isGranted = permission == .granted
        completion(isGranted, false)
    }

    private func notifyCompleteOnMainThread(_ retCode: AudioRecordResultCode) {
        executeOnMainThread {
            if !self.isCancelRecord {
                self.onRecordingComplete?(retCode, self.recordedFilePath ?? "", Int(self.currentTime) / 1000)
            } else {
                DispatchQueue.global().async {
                    self.removeRecordFile(self.recordedFilePath)
                }
            }
            self.currentTime = 0;
        }
    }

    private func onComplete(_ retCode:AudioRecordResultCode) {
        // 自动停止不会经过 stopRecord，须在完成回调中复位录音状态。
        executeOnMainThread {
            self.isRecording = false
        }
        notifyCompleteOnMainThread(retCode);
    }

    private func removeRecordFile(_ path : String?) {
        logger.info("remove record file")
        if let path = path, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func executeOnMainThread(_ closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
}
