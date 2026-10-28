import UIKit
import AVFoundation
import Photos
import AlbumPicker
import AlbumPickerCore
import AtomicXCore

final class MessageInputAlbumPicker: NSObject {
    static let shared = MessageInputAlbumPicker()

    private static let maxSelectionCount = 9
    private static let maxVideoOutputSizeInMB = 100
    private static let maxVideoDurationInSeconds = 600

    private var activeSessions: [String: AlbumPickerSendSession] = [:]
    private var isPickerVisible = false

    private override init() {}

    func show(conversationID: String, config: ChatMessageInputConfig, primaryColor: UIColor) {
        guard !conversationID.isEmpty, !isPickerVisible, let presenter = Self.topMostViewController() else { return }
        AlbumPickerCoreTheme.shared.currentPrimaryColor = primaryColor

        let pickerController = UIViewController()
        pickerController.modalPresentationStyle = .fullScreen

        let session = AlbumPickerSendSession(
            conversationID: conversationID,
            config: config,
            pickerController: pickerController,
            onPickerDismissed: { [weak self] in self?.isPickerVisible = false },
            onCompleted: { [weak self] finished in self?.activeSessions.removeValue(forKey: finished.sessionID) }
        )
        activeSessions[session.sessionID] = session

        let albumView = AlbumPickerView()
        albumView.delegate = session
        albumView.initialize(config: Self.makeConfig(), theme: AlbumPickerTheme(currentPrimaryColor: primaryColor))
        pickerController.view = albumView

        isPickerVisible = true
        presenter.present(pickerController, animated: true)
    }

    private static func makeConfig() -> AlbumPickerConfig {
        var config = AlbumPickerConfig(
            maxSelectionCount: maxSelectionCount,
            style: .likeWeChat,
            mediaFilter: .imageAndVideo,
            compressQuality: .standard
        )
        config.maxOutputFileSizeInMB = maxVideoOutputSizeInMB
        config.maxVideoDurationInSeconds = maxVideoDurationInSeconds
        return config
    }

    private static func topMostViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private final class AlbumPickerSendSession: NSObject, AlbumPickerDelegate {
    let sessionID = UUID().uuidString

    private struct PlaceholderState {
        let placeholderID: String
        var thumbnailPath: String?
        var isThumbnailFinal: Bool
        var thumbnailSize: CGSize
        var mediaPath: String?
        var progress: Int
    }

    private static let completedProgress: Float = 1.0
    private static let progressPercentScale: Float = 100
    private static let progressUpdateStep = 5
    private static let placeholderCleanupDelay: TimeInterval = 3
    private static let placeholderIDPrefix = "album_picker_processing_"

    private let conversationID: String
    private let messageManager: MessageInputManager
    private weak var pickerController: UIViewController?
    private let onPickerDismissed: () -> Void
    private let onCompleted: (AlbumPickerSendSession) -> Void

    private var placeholderStates: [String: PlaceholderState] = [:]
    private var sentMediaIDs: Set<UInt64> = []
    private var pendingText: String?
    private var didSendPendingText = false
    private var isFinished = false

    init(conversationID: String,
         config: ChatMessageInputConfig,
         pickerController: UIViewController,
         onPickerDismissed: @escaping () -> Void,
         onCompleted: @escaping (AlbumPickerSendSession) -> Void)
    {
        self.conversationID = conversationID
        self.messageManager = MessageInputManager(messageInputStore: MessageInputStore.create(conversationID: conversationID), config: config)
        self.pickerController = pickerController
        self.onPickerDismissed = onPickerDismissed
        self.onCompleted = onCompleted
        super.init()
    }

    func onPickConfirm(pickedAlbumMedias: [AlbumMedia], textMessage: String?) {
        pendingText = textMessage
        for media in pickedAlbumMedias {
            insertPlaceholder(for: media)
        }
        dismissPicker()
    }

    func onMediaProcessing(albumMedia: AlbumMedia, progress: Float, error: Bool) {
        if error {
            markSendFailed(albumMedia)
            return
        }
        if progress < Self.completedProgress {
            updatePlaceholderProgress(for: albumMedia, progress: progress)
            return
        }
        if let path = albumMedia.mediaPath, !path.isEmpty {
            sendOnce(albumMedia) { [weak self] in
                self?.sendMedia(albumMedia, path: path)
            }
            return
        }
        markSendFailed(albumMedia)
    }

    func onMediaProcessed() {
        sendPendingTextIfNeeded()
        finish()
    }

    func onCancel() {
        finish()
    }

    private func insertPlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        let initialSize = MessageInputAlbumPicker.placeholderSize(for: media)
        placeholderStates[placeholderID] = PlaceholderState(
            placeholderID: placeholderID,
            thumbnailPath: nil,
            isThumbnailFinal: false,
            thumbnailSize: initialSize,
            mediaPath: nil,
            progress: 0
        )
        applyPlaceholder(for: media)
        requestThumbnail(for: media)
    }

    private func requestThumbnail(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        MessageInputAlbumPicker.thumbnail(for: media) { [weak self] path, size, isFinal in
            guard let self = self else { return }
            guard var state = self.placeholderStates[placeholderID] else { return }
            if state.isThumbnailFinal { return }
            if let path = path { state.thumbnailPath = path }
            if size.width > 0, size.height > 0 { state.thumbnailSize = size }
            state.isThumbnailFinal = isFinal && path != nil
            self.placeholderStates[placeholderID] = state
            self.applyPlaceholder(for: media)
        }
    }

    private func updatePlaceholderProgress(for media: AlbumMedia, progress: Float) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard var state = placeholderStates[placeholderID] else { return }
        let percent = Self.toPercent(progress)
        if percent - state.progress < Self.progressUpdateStep { return }
        state.progress = percent
        placeholderStates[placeholderID] = state
        applyPlaceholder(for: media)
    }

    private func applyPlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard let state = placeholderStates[placeholderID] else { return }
        MessageListView.addPlaceholder(
            conversationID: conversationID,
            info: MessagePlaceholderInfo(
                placeholderID: state.placeholderID,
                mediaKind: media.mediaType == .video ? .video : .image,
                thumbnailPath: state.thumbnailPath,
                thumbnailSize: state.thumbnailSize,
                mediaPath: state.mediaPath,
                videoDuration: Self.durationInSeconds(media.duration),
                progress: state.progress
            )
        )
    }

    private func markPlaceholderSending(for media: AlbumMedia, path: String) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard var state = placeholderStates[placeholderID] else { return }
        state.mediaPath = path
        placeholderStates[placeholderID] = state
        applyPlaceholder(for: media)
    }

    private func sendOnce(_ media: AlbumMedia, _ send: @escaping () -> Void) {
        if sentMediaIDs.insert(media.id).inserted {
            send()
        }
    }

    private func sendMedia(_ media: AlbumMedia, path: String) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        let state = placeholderStates[placeholderID]
        let reusableSnapshotPath = (state?.isThumbnailFinal == true ? state?.thumbnailPath : nil)
            ?? media.videoThumbnailPath
        markPlaceholderSending(for: media, path: path)
        switch media.mediaType {
        case .video:
            messageManager.sendVideoMessage(path, reusableSnapshotPath ?? "")
        case .image:
            messageManager.sendImageMessage(path)
        }
    }

    private func markSendFailed(_ media: AlbumMedia) {
        if sentMediaIDs.insert(media.id).inserted {
            removePlaceholder(for: media)
        }
    }

    private func removePlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard let state = placeholderStates.removeValue(forKey: placeholderID) else { return }
        MessageListView.removePlaceholder(conversationID: conversationID, placeholderID: state.placeholderID)
    }

    private func sendPendingTextIfNeeded() {
        if let text = pendingText, !text.isEmpty, !didSendPendingText {
            didSendPendingText = true
            messageManager.sendTextMessage(text, mentionList: [])
        }
    }

    private func dismissPicker() {
        if let controller = pickerController {
            pickerController = nil
            controller.dismiss(animated: true)
            onPickerDismissed()
        }
    }

    private func finish() {
        if isFinished { return }
        isFinished = true
        dismissPicker()
        cleanupPlaceholders()
        onCompleted(self)
    }

    private func cleanupPlaceholders() {
        let states = placeholderStates.values
        placeholderStates.removeAll()
        for state in states where state.mediaPath == nil {
            MessageListView.removePlaceholder(conversationID: conversationID, placeholderID: state.placeholderID)
        }
        let sendingIDs = states.filter { $0.mediaPath != nil }.map { $0.placeholderID }
        if sendingIDs.isEmpty { return }
        let targetConversationID = conversationID
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.placeholderCleanupDelay) {
            for placeholderID in sendingIDs {
                MessageListView.removePlaceholder(conversationID: targetConversationID, placeholderID: placeholderID)
            }
        }
    }

    private static func makePlaceholderID(sessionID: String, mediaID: UInt64) -> String {
        return "\(placeholderIDPrefix)\(sessionID)_\(mediaID)"
    }

    private static func toPercent(_ progress: Float) -> Int {
        let clamped = min(max(progress, 0), completedProgress)
        return Int((clamped * progressPercentScale).rounded())
    }

    private static func durationInSeconds(_ seconds: Int64) -> Int {
        if seconds <= 0 { return 0 }
        return Int(seconds)
    }
}


extension MessageInputAlbumPicker {
    private static let thumbnailDirectoryName = "album_picker_processing_thumbnail"
    private static let thumbnailMaxPixel: CGFloat = 720
    private static let thumbnailCompressionQuality: CGFloat = 0.8
    private static let snapshotTimescale: CMTimeScale = 60

    static func thumbnail(for media: AlbumMedia, onUpdate: @escaping (String?, CGSize, Bool) -> Void) {
        if let path = localThumbnailPath(for: media), let image = readImage(at: path) {
            onUpdate(path, image.size, true)
            return
        }
        if media.mediaType == .video, let videoPath = media.mediaPath, isReadableFile(videoPath) {
            DispatchQueue.global().async {
                let path = writeThumbnail(makeVideoSnapshot(videoPath: videoPath), mediaID: media.id)
                let image = path.flatMap { readImage(at: $0) }
                runOnMain { onUpdate(path, image?.size ?? pixelSize(of: media.asset), path != nil) }
            }
            return
        }
        if media.mediaType == .image, let imagePath = media.mediaPath, isReadableFile(imagePath) {
            if let image = readImage(at: imagePath) {
                onUpdate(imagePath, image.size, true)
                return
            }
            onUpdate(nil, .zero, true)
            return
        }
        requestAssetThumbnail(for: media, onUpdate: onUpdate)
    }

    static func placeholderSize(for media: AlbumMedia) -> CGSize {
        if media.mediaType == .video {
            if let asset = media.asset, asset.pixelWidth > 0, asset.pixelHeight > 0 {
                return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            }
            return .zero
        }
        if let path = media.mediaPath, isReadableFile(path), let image = readImage(at: path) {
            return image.size
        }
        return .zero
    }

    private static func localThumbnailPath(for media: AlbumMedia) -> String? {
        if media.mediaType == .video {
            if let path = media.videoThumbnailPath, isReadableFile(path) {
                return path
            }
            return nil
        }
        if let path = media.mediaPath, isReadableFile(path) {
            return path
        }
        return nil
    }

    private static func requestAssetThumbnail(for media: AlbumMedia, onUpdate: @escaping (String?, CGSize, Bool) -> Void) {
        let fallbackSize = pixelSize(of: media.asset)
        guard let asset = media.asset else {
            onUpdate(nil, fallbackSize, true)
            return
        }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        let targetSize = CGSize(width: thumbnailMaxPixel, height: thumbnailMaxPixel)
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
            guard let image = image else {
                if !isDegraded { onUpdate(nil, fallbackSize, true) }
                return
            }
            DispatchQueue.global().async {
                let path = writeThumbnail(image, mediaID: media.id, isPreview: isDegraded)
                let size = (path.flatMap { readImage(at: $0) }?.size) ?? fallbackSize
                runOnMain { onUpdate(path, size, path != nil && !isDegraded) }
            }
        }
    }

    private static func makeVideoSnapshot(videoPath: String) -> UIImage? {
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: snapshotTimescale), actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func writeThumbnail(_ image: UIImage?, mediaID: UInt64, isPreview: Bool = false) -> String? {
        let fileName = isPreview ? "\(mediaID)_preview.jpg" : "\(mediaID).jpg"
        guard let image = image,
              let data = image.jpegData(compressionQuality: thumbnailCompressionQuality),
              let destination = makeTemporaryFileURL(directory: thumbnailDirectoryName, fileName: fileName) else {
            return nil
        }
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return nil }
        return destination.path
    }

    private static func pixelSize(of asset: PHAsset?) -> CGSize {
        guard let asset = asset, asset.pixelWidth > 0, asset.pixelHeight > 0 else { return .zero }
        return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }

    private static func readImage(at path: String) -> UIImage? {
        guard isReadableFile(path), let image = UIImage(contentsOfFile: path), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }

    private static func isReadableFile(_ path: String?) -> Bool {
        guard let path = path, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private static func makeTemporaryFileURL(directory: String, fileName: String) -> URL? {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directory)
        guard (try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        let fileURL = directoryURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return fileURL
    }

    private static func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
