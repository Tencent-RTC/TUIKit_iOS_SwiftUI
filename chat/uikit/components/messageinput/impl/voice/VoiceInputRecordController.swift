import AtomicXCore
import Foundation
import SwiftUI

enum VoiceRecordOutcome {
    case none
    case send
    case cancel
    case transcribe
}

final class VoiceInputRecordController: ObservableObject {
    static let barCount = 24
    private static let minimumRecordDurationMs = 1_000

    @Published private(set) var powerLevels: [CGFloat] = Array(repeating: 0.12, count: VoiceInputRecordController.barCount)
    @Published private(set) var currentPowerLevel: Int = 0
    @Published private(set) var durationText: String = "0:00"
    @Published private(set) var activeZone: VoiceRecordOutcome = .send
    @Published private(set) var isRecording = false
    @Published private(set) var remainingSeconds: Int = 0

    var zoneFrames: (cancel: CGRect, transcribe: CGRect)?

    private let maxDurationMs: Int
    private let minDurationMs: Int
    private var completion: ((VoiceRecordOutcome, String?, Int) -> Void)?
    private var finished = false
    private var recordBeginTime: Date?

    init(maxDurationMs: Int = ChatMessageInputConfig.defaultAudioMaxRecordDurationMs, minDurationMs: Int = VoiceInputRecordController.minimumRecordDurationMs) {
        let duration = maxDurationMs > 0 ? maxDurationMs : ChatMessageInputConfig.defaultAudioMaxRecordDurationMs
        self.minDurationMs = max(Self.minimumRecordDurationMs, minDurationMs)
        self.maxDurationMs = max(self.minDurationMs, Int(Int32(clamping: duration)))
    }


    func beginRecording(completion: @escaping (VoiceRecordOutcome, String?, Int) -> Void) {
        self.completion = completion
        finished = false
        activeZone = .send
        durationText = "0:00"
        remainingSeconds = maxDurationMs / 1000
        powerLevels = Array(repeating: 0.12, count: Self.barCount)

        let recorder = AudioRecorder.shared
        recorder.onRecordTime = { [weak self] ms in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let seconds = ms / 1000
                self.durationText = String(format: "%02d:%02d", seconds / 60, seconds % 60)
                let remainingMs = max(self.maxDurationMs - ms, 0)
                self.remainingSeconds = max(Int(ceil(Double(remainingMs) / 1000)), 1)
            }
        }
        recorder.onPowerLevel = { [weak self] power in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentPowerLevel = power
                let normalized = min(1.0, max(0.12, CGFloat(power) / 100.0))
                self.powerLevels.append(normalized)
                if self.powerLevels.count > Self.barCount {
                    self.powerLevels.removeFirst()
                }
            }
        }
        recorder.onRecordingComplete = { [weak self] code, path, durationMs in
            self?.handleRecordComplete(code: code, path: path, durationMs: durationMs)
        }
        recorder.startRecord(filepath: nil, minDurationMs: minDurationMs, maxDurationMs: maxDurationMs)
        recordBeginTime = Date()
        isRecording = true
    }

    func updateZone(fingerGlobal: CGPoint) {
        guard isRecording else { return }
        var newZone: VoiceRecordOutcome = .send
        if let frames = zoneFrames {
            if frames.cancel.contains(fingerGlobal) {
                newZone = .cancel
            } else if frames.transcribe.contains(fingerGlobal) {
                newZone = .transcribe
            }
        }
        if newZone != activeZone {
            activeZone = newZone
        }
    }

    func endRecording() {
        guard isRecording, !finished else { return }
        isRecording = false
        switch activeZone {
        case .cancel:
            finished = true
            AudioRecorder.shared.cancelRecord()
            completion?(.cancel, nil, 0)
            completion = nil
        case .transcribe, .send, .none:
            let elapsedMs = Int(Date().timeIntervalSince(recordBeginTime ?? Date()) * 1000)
            if elapsedMs < minDurationMs {
                finished = true
                AudioRecorder.shared.cancelRecord()
                DispatchQueue.main.async {
                    WindowToastManager.shared.show(LocalizedChatString("AudioRecorderLessThanMinTime"), type: .warning, duration: 2)
                }
                completion?(.cancel, nil, 0)
                completion = nil
            } else {
                AudioRecorder.shared.stopRecord()
            }
        }
    }

    func forceCancel() {
        guard !finished else { return }
        finished = true
        isRecording = false
        AudioRecorder.shared.cancelRecord()
        completion?(.cancel, nil, 0)
        completion = nil
    }


    private func handleRecordComplete(code: AudioRecordResultCode, path: String, durationMs: Int) {
        guard !finished else { return }
        finished = true
        isRecording = false
        let durationSec = durationMs
        let zone = activeZone
        let cb = completion
        completion = nil
        DispatchQueue.main.async {
            switch code {
            case .success, .exceedMaxDuration:
                if zone == .transcribe {
                    cb?(.transcribe, path, durationSec)
                } else {
                    cb?(.send, path, durationSec)
                }
            case .errorLessThanMinDuration:
                WindowToastManager.shared.show(LocalizedChatString("AudioRecorderLessThanMinTime"), type: .warning, duration: 2)
                cb?(.cancel, nil, 0)
            default:
                cb?(.cancel, nil, 0)
            }
        }
    }
}
