import AVFoundation
import SwiftUI
import UIKit

struct VideoRecorderAlert: Identifiable {
    let id = UUID()
    let restartsPreview: Bool
}

struct VideoRecorderEditingPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

enum VideoRecorderCaptureResult {
    case cancelled
    case video(path: String, durationMs: Int)
    case photo(UIImage)
}

final class VideoRecorderModel: ObservableObject {
    private static let minZoom: CGFloat = 1.0

    private static let maxZoom: CGFloat = 5.0

    private static let millisecondsPerSecond: Float = 1000

    private static let secondsPerMinute: Float = 60

    private static let progressAnimationDuration: TimeInterval = 0.25

    private static let editorAnimationDuration: TimeInterval = 0.15

    @Published private(set) var progress: CGFloat = 0

    @Published private(set) var durationText = "00:00"

    @Published private(set) var isDurationVisible = false

    @Published private(set) var areOperationsHidden = false

    @Published private(set) var isFlashOn = false

    @Published private(set) var isUsingFrontCamera: Bool

    @Published private(set) var aspectRatio: VideoRecordAspectRatio = .ratio9x16

    @Published private(set) var previewPlayer: AVPlayer?

    @Published private(set) var editingPhoto: VideoRecorderEditingPhoto?

    @Published var alert: VideoRecorderAlert?

    @Published private(set) var captureResult: VideoRecorderCaptureResult?

    let settings: VideoRecorderSettings

    let isAspectSupported: Bool

    private let recordCore: VideoRecordCore

    private let encodeConfig: VideoRecorderEncodeConfig

    private let recordFilePath: String

    private let minDurationSeconds: Float

    private let maxDurationSeconds: Float

    private weak var previewView: UIView?

    private var isPreviewRequested = false

    private var zoom: CGFloat = 1.0

    private var recordDuration: Float = 0

    private var previewVideoPath: String?

    private var loopObserver: NSObjectProtocol?

    init(settings: VideoRecorderSettings) {
        self.settings = settings
        isUsingFrontCamera = settings.isDefaultFrontCamera
        minDurationSeconds = Float(settings.minDurationMs) / Self.millisecondsPerSecond
        maxDurationSeconds = Float(settings.maxDurationMs) / Self.millisecondsPerSecond
        encodeConfig = VideoRecorderEncodeConfig(videoQuality: settings.videoQuality)
        recordFilePath = VideoRecorderMediaFiles.makeVideoPath()
        if let ugcRecordCore = UGCReflectVideoRecordCore.create() {
            recordCore = ugcRecordCore
        } else {
            print("Because it does not rely on the LiteAV module, the UGC video recorder cannot be used. Instead, the system video recorder can be used. For more details, please refer to the relevant documentation")
            recordCore = SystemVideoRecordCore()
        }
        isAspectSupported = settings.isSupportAspect && recordCore is UGCReflectVideoRecordCore
    }

    deinit {
        removeLoopObserver()
    }

    var tipText: String {
        switch settings.recordMode {
        case .videoPhotoMix:
            return LocalizedChatString("record_mode_mix_tip")
        case .photoOnly:
            return LocalizedChatString("record_mode_photo_tip")
        case .videoOnly:
            return LocalizedChatString("record_mode_video_tip")
        }
    }

    func attachPreviewView(_ view: UIView) {
        previewView = view
        if isPreviewRequested {
            startPreview()
        }
    }

    func onAppear() {
        isPreviewRequested = true
        startPreview()
    }

    func onDisappear() {
        isPreviewRequested = false
        recordCore.stopCameraPreview()
        setFlash(false)
    }

    func appDidBecomeActive() {
        previewPlayer?.play()
        startPreview()
    }

    func appWillResignActive() {
        recordCore.stopCameraPreview()
        previewPlayer?.pause()
        setFlash(false)
    }

    func exit() {
        recordCore.stopCameraPreview()
        setFlash(false)
        finish(.cancelled)
    }

    func cancelByEdgeSwipe() {
        finish(.cancelled)
    }

    func switchCamera() {
        if isUsingFrontCamera {
            isUsingFrontCamera = false
        } else {
            isUsingFrontCamera = true
            setFlash(false)
        }
        recordCore.switchCamera(isUsingFrontCamera)
    }

    func toggleFlash() {
        if isUsingFrontCamera {
            return
        }
        setFlash(!isFlashOn)
    }

    func toggleAspectRatio() {
        aspectRatio = aspectRatio == .ratio9x16 ? .ratio3x4 : .ratio9x16
        applyAspectRatio()
    }

    func zoom(by scale: CGFloat) {
        zoom = min(max(zoom * scale, Self.minZoom), Self.maxZoom)
        recordCore.setZoom(zoom)
    }

    func recordButtonTapped() {
        if settings.recordMode != .videoOnly {
            takePhoto()
        }
    }

    func recordButtonLongPressBegan() {
        if settings.recordMode != .photoOnly {
            startRecord()
            isDurationVisible = true
        } else {
            isDurationVisible = false
        }
        areOperationsHidden = true
    }

    func recordButtonLongPressEnded() {
        if settings.recordMode != .photoOnly {
            finishRecord()
        } else {
            takePhoto()
        }
        restoreOperations()
    }

    func recordButtonLongPressCancelled() {
        if settings.recordMode != .photoOnly {
            finishRecord()
        }
        restoreOperations()
    }

    func acceptPreview() {
        guard let videoPath = previewVideoPath else { return }
        let durationMs = Int(recordDuration * Self.millisecondsPerSecond)
        cleanupPreviewPlayer()
        finish(.video(path: videoPath, durationMs: durationMs))
    }

    func cancelPreview() {
        print("VideoPreviewViewDelegate cancle")
        cleanupPreviewPlayer()
        resetRecordState()
    }

    func confirmEditing(_ image: UIImage) {
        finish(.photo(image))
    }

    func cancelEditing() {
        withAnimation(.easeInOut(duration: Self.editorAnimationDuration)) {
            editingPhoto = nil
        }
        resetRecordState()
        startPreview()
    }

    func alertConfirmed(_ alert: VideoRecorderAlert) {
        if alert.restartsPreview {
            startPreview()
        }
    }

    private func startPreview() {
        guard isPreviewRequested, editingPhoto == nil, let previewView = previewView else { return }
        let config: [String: Any] = [
            "videoResolution": encodeConfig.getVideoRecordResolution().rawValue,
            "videoFPS": encodeConfig.fps,
            "videoBitratePIN": encodeConfig.bitrate,
            "minDuration": minDurationSeconds,
            "maxDuration": maxDurationSeconds,
            "frontCamera": isUsingFrontCamera
        ]
        applyAspectRatio()
        recordCore.startCameraCustom(config, preview: previewView)
    }

    private func applyAspectRatio() {
        switch aspectRatio {
        case .ratio3x4:
            recordCore.setAspectRatio(.ratio3x4)
        case .ratio9x16:
            recordCore.setAspectRatio(.ratio9x16)
        default:
            break
        }
    }

    private func setFlash(_ isOn: Bool) {
        isFlashOn = isOn
        recordCore.toggleTorch(isOn)
    }

    private func restoreOperations() {
        isDurationVisible = false
        areOperationsHidden = false
    }

    private func resetRecordState() {
        recordDuration = 0
        progress = 0
        durationText = "00:00"
        restoreOperations()
    }

    private func startRecord() {
        recordCore.recordDelegate = self
        let result = recordCore.startRecord(recordFilePath)
        print("record start. res = \(result)")
        if result != 0 {
            updateProgress(0, duration: 0)
            setFlash(false)
            alert = VideoRecorderAlert(restartsPreview: false)
            return
        }
        recordDuration = 0
    }

    private func finishRecord() {
        recordCore.stopRecord()
        setFlash(false)
    }

    private func takePhoto() {
        let result = recordCore.snapshot { [weak self] image in
            Self.runOnMain {
                print("take photo complete")
                guard let self = self else { return }
                if let image = image {
                    self.showEditor(image)
                }
                self.setFlash(false)
            }
        }
        if result != 0 {
            alert = VideoRecorderAlert(restartsPreview: false)
        }
    }

    private func showEditor(_ image: UIImage) {
        setFlash(false)
        withAnimation(.easeOut(duration: Self.editorAnimationDuration)) {
            editingPhoto = VideoRecorderEditingPhoto(image: image)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.editorAnimationDuration) { [weak self] in
            guard let self = self, self.editingPhoto != nil else { return }
            self.recordCore.stopCameraPreview()
        }
    }

    private func showPreview(_ videoPath: String) {
        cleanupPreviewPlayer()
        previewVideoPath = videoPath
        let player = AVPlayer(url: URL(fileURLWithPath: videoPath))
        loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                              object: player.currentItem, queue: .main) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        player.play()
        previewPlayer = player
    }

    private func cleanupPreviewPlayer() {
        previewPlayer?.pause()
        removeLoopObserver()
        previewPlayer = nil
    }

    private func removeLoopObserver() {
        if let loopObserver = loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        loopObserver = nil
    }

    private func updateProgress(_ progress: Float, duration: Float) {
        withAnimation(.easeInOut(duration: Self.progressAnimationDuration)) {
            self.progress = CGFloat(max(0, min(1, progress)))
        }
        let minutes = Int(floor(duration / Self.secondsPerMinute))
        let seconds = Int(floor(duration - Float(minutes) * Self.secondsPerMinute))
        durationText = String(format: "%02d:%02d", minutes, seconds)
    }

    private func finish(_ result: VideoRecorderCaptureResult) {
        guard captureResult == nil else { return }
        captureResult = result
    }

    private static func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

extension VideoRecorderModel: VideoRecorderCoreListener {
    func onRecordProgress(_ milliSecond: Int) {
        Self.runOnMain { [weak self] in
            self?.handleRecordProgress(milliSecond)
        }
    }

    func onRecordComplete(_ result: VideoRecordResult) {
        Self.runOnMain { [weak self] in
            self?.handleRecordComplete(result)
        }
    }

    private func handleRecordProgress(_ milliSecond: Int) {
        if milliSecond == 0 {
            return
        }

        recordDuration = Float(milliSecond) / Self.millisecondsPerSecond
        updateProgress(recordDuration / maxDurationSeconds, duration: recordDuration)
        if recordDuration >= maxDurationSeconds {
            recordCore.stopRecord()
            setFlash(false)
        }
    }

    private func handleRecordComplete(_ result: VideoRecordResult) {
        recordCore.deleteTempFile()
        if result.retCode == .failed {
            alert = VideoRecorderAlert(restartsPreview: true)
            return
        }

        print("on record complete record duration: \(recordDuration)")
        if recordDuration < minDurationSeconds {
            if settings.recordMode == .videoPhotoMix {
                takePhoto()
            }
            return
        }

        guard let videoPath = result.videoPath, !videoPath.isEmpty else { return }
        showPreview(videoPath)
    }
}
