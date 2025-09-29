//  Created by lzmlsfe on 2025/7/4.

import os.log
import AVFoundation
import Foundation

internal class AudioRecorderSystem: AudioRecorderInternalProtocol {
    let logger = Logger(subsystem: "AudioRecoder", category: "AudioRecorderSystem")
    private static let kMinDuration:Int = 1000
    
    private var listener: AudioRecorderListener?
    private var recorder: AVAudioRecorder?
    
    private var recordTimer: Timer?
    private var currentPower: Int = 0
    private var currentTime: TimeInterval = 0
    private var isEnableAIDeNoise:Bool = false
    
    private var recordSetting:[String: Any]
    
    init() {
        recordSetting = [
            AVSampleRateKey: 16000.0,
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVLinearPCMBitDepthKey: 16,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
    
    func startRecord(_ path : String) {
        if isEnableAIDeNoise {
            listener?.onComplete(.errorUseAIDenoiseNoLiteavSDK);
            return
        }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setActive(true)
        } catch {
            logger.error("Failed to set audio session category or activate session: \(error)")
            listener?.onComplete(.errorRecordInnerFail);
            return
        }
        
        let url = URL(fileURLWithPath: path)
        do {
            recorder = try AVAudioRecorder(url: url, settings: recordSetting)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()
            recorder?.updateMeters()
        } catch {
            logger.error("Failed to initialize AVAudioRecorder: \(error)")
            listener?.onComplete(.errorRecordInnerFail);
            return
        }
        
        recordTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onRecordTimer), userInfo: nil, repeats: true)
        RunLoop.current.add(recordTimer!, forMode: .common)
        logger.info("start system recording")
    }
    
    func stopRecord() {
        guard AVAudioSession.sharedInstance().recordPermission != .denied else {
            return
        }
        onRecordTimer()
        
        recorder?.stop()
        recorder = nil
        
        recordTimer?.invalidate()
        recordTimer = nil
        
        if Int(currentTime) * 1000 < AudioRecorderSystem.kMinDuration {
            listener?.onComplete(.errorLessThanMinDuration)
        } else {
            listener?.onComplete(.success)
        }
        
        currentTime = 0
        logger.info("stop system recording")
    }
    
    func setListener(_ listener: AudioRecorderListener) {
        self.listener = listener
    }
    
    func enableAIDeNoise(_ enable : Bool) {
        logger.error("system audio record do not support ai de noise");
        isEnableAIDeNoise = enable
    }
    
    @objc private func onRecordTimer() {
        recorder?.updateMeters()
        
        let time = recorder?.currentTime ?? 0
        print("record time = \(time)")
        if time > currentTime {
            currentTime = time
            listener?.onProgress(Int(time * 1000))
        }
        
        let power = recorder?.averagePower(forChannel: 0) ?? 0
        currentPower = Int(power)
        listener?.onPower(currentPower)
    }
}
