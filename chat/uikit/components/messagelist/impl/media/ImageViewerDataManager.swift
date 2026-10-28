import AtomicXCore
import Combine
import Foundation
import SwiftUI

class ImageViewerManager: ObservableObject {
    @Published var isShowingImageViewer = false
    @Published var initialImageElements: [ImageElement] = []
    @Published var initialImageIndex: Int = 0
    @Published var isLoadingImageData = false
    @Published var messageList: [MessageInfo] = []
    @Published var hasMoreOlderMessage: Bool = false
    @Published var hasMoreNewerMessage: Bool = false
    @Published var conversationID: String = ""
    private var imageViewerDataManager: ImageViewerDataManager?
    private let messageListStore: MessageListStore
    private var currentMessage: MessageInfo
    private var staticMessagesProvider: (() -> [MessageInfo])?
    private var cancellables = Set<AnyCancellable>()
    @Published private var didInitiatePlayback = false

    init(conversationID: String, currentMessage: MessageInfo, staticMessagesProvider: (() -> [MessageInfo])? = nil) {
        self.messageListStore = MessageListStore.create(conversationID: conversationID)
        self.currentMessage = currentMessage
        self.staticMessagesProvider = staticMessagesProvider

        setupDataSubscriptions()
    }

    private func handlePlaybackExit(_ reason: VideoPlaybackExitReason) {
        guard didInitiatePlayback else { return }
        didInitiatePlayback = false
        if reason == .dismissed {
            isShowingImageViewer = false
        }
    }

    private func setupDataSubscriptions() {
        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))
            .sink { [weak self] messageList in
                guard let self = self else { return }
                self.messageList = messageList
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasOlderMessages))
            .sink { [weak self] hasMoreOlderMessage in
                guard let self = self else { return }
                self.hasMoreOlderMessage = hasMoreOlderMessage
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasNewerMessages))
            .sink { [weak self] hasMoreNewerMessage in
                guard let self = self else { return }
                self.hasMoreNewerMessage = hasMoreNewerMessage
            }
            .store(in: &cancellables)
    }

    func showImageViewer(for message: MessageInfo, staticMessagesProvider: (() -> [MessageInfo])? = nil) {
        currentMessage = message
        self.staticMessagesProvider = staticMessagesProvider
        showImageViewerIfAvailable()
    }

    func showImageViewerIfAvailable() {
        guard !isLoadingImageData, !isShowingImageViewer else { return }
        didInitiatePlayback = false
        isLoadingImageData = true
        initialImageElements = []
        initialImageIndex = 0
        let dataManager = ImageViewerDataManager(
            conversationID: conversationID,
            currentMessage: currentMessage,
            messageListStore: messageListStore,
            staticMessagesProvider: staticMessagesProvider
        )
        imageViewerDataManager = dataManager
        Task {
            do {
                let (mediaElements, currentIndex) = try await dataManager.loadInitialData()
                await MainActor.run {
                    self.initialImageElements = mediaElements
                    self.initialImageIndex = currentIndex
                    self.isLoadingImageData = false
                }
            } catch {
                print(">>>>> ImageViewerManager loadInitialData failed: \(error)")
                await MainActor.run {
                    self.isLoadingImageData = false
                }
            }
        }
        isShowingImageViewer = true
    }

    func imageViewerContent() -> some View {
        ImageViewerContent(manager: self)
    }

    @ViewBuilder
    fileprivate func renderedImageViewerContent() -> some View {
        ZStack {
            if !initialImageElements.isEmpty {
                imageViewerView
                    .opacity(didInitiatePlayback ? 0 : 1)
                    .allowsHitTesting(!didInitiatePlayback)
                    .accessibilityHidden(didInitiatePlayback)
            } else {
                loadingPlaceholder
            }
            if didInitiatePlayback {
                VideoPlayerView()
            }
        }
    }

    private var imageViewerView: some View {
        let sessionDataManager = imageViewerDataManager
        let onEventTriggered: ([String: Any], @escaping (Any?) -> Void) -> Void = { eventData, completion in
            guard let eventType = eventData["event"] as? String else {
                completion(nil)
                return
            }
            switch eventType {
            case "onImageTap":
                self.isShowingImageViewer = false
                completion(nil)
            case "onLoadMore":
                guard let paramDict = eventData["param"] as? [String: Any],
                      let isOlder = paramDict["isOlder"] as? Bool
                else {
                    completion(nil)
                    return
                }
                Task {
                    do {
                        guard self.isShowingImageViewer,
                              let dataManager = sessionDataManager,
                              self.imageViewerDataManager === dataManager else {
                            completion(nil)
                            return
                        }
                        let elements = try await dataManager.loadMoreData(isOlder: isOlder)
                        guard self.isShowingImageViewer, self.imageViewerDataManager === dataManager else {
                            completion(nil)
                            return
                        }
                        completion(ImageViewerPage(elements: elements, hasMore: dataManager.hasMoreMedia(isOlder: isOlder)))
                    } catch {
                        completion(nil)
                    }
                }
            case "onPlayVideo":
                guard self.isShowingImageViewer, !self.didInitiatePlayback,
                      let dataManager = sessionDataManager,
                      self.imageViewerDataManager === dataManager,
                      let paramDict = eventData["param"] as? [String: Any],
                      let videoPath = paramDict["path"] as? String,
                      !videoPath.isEmpty
                else {
                    completion(nil)
                    return
                }
                let isLocal = FileManager.default.fileExists(atPath: videoPath)
                let videoData = VideoData(uri: videoPath, localPath: isLocal ? videoPath : nil, width: 1920, height: 1080)
                VideoPlayer.shared.play(videoData: videoData) { [weak self, weak dataManager] reason in
                    guard let self = self, let dataManager = dataManager,
                          self.imageViewerDataManager === dataManager else { return }
                    self.handlePlaybackExit(reason)
                }
                self.didInitiatePlayback = true
                completion(nil)
            case "onDownloadVideo":
                guard let paramDict = eventData["param"] as? [String: Any],
                      let imagePath = paramDict["path"] as? String
                else {
                    completion(nil)
                    return
                }
                Task { @MainActor in
                    do {
                        guard self.isShowingImageViewer,
                              let dataManager = sessionDataManager,
                              self.imageViewerDataManager === dataManager,
                              let locateMessage = dataManager.findMessage(byImagePath: imagePath)
                        else {
                            completion(nil)
                            return
                        }
                        let resolver = VideoDownloadResultResolver(messageID: locateMessage.msgID)
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            MessageActionStore.create(message: locateMessage).downloadMedia(quality: .standard, completion: { result in
                                switch result {
                                case .success:
                                    continuation.resume()
                                case .failure(let error):
                                    continuation.resume(throwing: NSError(domain: "VideoDownloadError", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message]))
                                }
                            })
                        }
                        let videoPath = try await resolver.waitForDownloadedPath(
                            messages: {
                                let previewMessage = dataManager.findMessage(byImagePath: imagePath)
                                let listMessage = self.messageListStore.state.value.messageList.first { $0.msgID == locateMessage.msgID }
                                return [previewMessage, listMessage, locateMessage].compactMap { $0 }
                            },
                            isActive: { self.isShowingImageViewer && self.imageViewerDataManager === dataManager }
                        )
                        completion([videoPath])
                    } catch {
                        completion(nil)
                    }
                }
            default:
                completion(nil)
            }
        }
        return ImageViewerView(imageElements: initialImageElements, initialIndex: initialImageIndex, presentsVideoPlayer: false, onEventTriggered: onEventTriggered)
    }

    private var loadingPlaceholder: some View {
        ZStack {
            Colors.Black1.ignoresSafeArea()
            if isLoadingImageData {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Colors.White1))
                        .scaleEffect(1.5)
                    Text(LocalizedChatString("Loading"))
                        .foregroundColor(Colors.White1)
                        .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                }
            }
        }
    }

}

@MainActor
final class VideoDownloadResultResolver {
    private let messageID: String
    private var downloadedPath: String?
    private var subscription: AnyCancellable?
    private static let maximumAttempts = 30
    private static let retryIntervalNanoseconds: UInt64 = 100_000_000

    init(messageID: String) {
        self.messageID = messageID
        subscription = NotificationCenter.default.publisher(for: Notification.Name("messageMediaDownload"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.receive(notification)
            }
    }

    func receive(_ notification: Notification) {
        guard let data = notification.userInfo?["data"] else { return }
        let fields = Mirror(reflecting: data)
        guard fields.children.first(where: { $0.label == "messageID" })?.value as? String == messageID,
              let payload = fields.children.first(where: { $0.label == "messagePayload" })?.value as? MessagePayload,
              case .video(let video) = payload,
              let path = Self.localPath(video.videoPath) else { return }
        downloadedPath = path
    }

    func waitForDownloadedPath(messages: () -> [MessageInfo], isActive: () -> Bool) async throws -> String {
        for attempt in 0..<Self.maximumAttempts {
            try Task.checkCancellation()
            guard isActive() else { throw CancellationError() }
            if let path = downloadedPath { return path }
            for message in messages() {
                guard case .video(let payload) = message.messagePayload,
                      let path = Self.localPath(payload.videoPath) else { continue }
                return path
            }
            if attempt < Self.maximumAttempts - 1 {
                try await Task.sleep(nanoseconds: Self.retryIntervalNanoseconds)
            }
        }
        throw NSError(domain: "VideoDownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded video path unavailable"])
    }

    private static func localPath(_ path: String?) -> String? {
        guard let path = path, !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }
}

private struct ImageViewerContent: View {
    @ObservedObject var manager: ImageViewerManager

    var body: some View {
        manager.renderedImageViewerContent()
    }
}

class ImageViewerDataManager {
    @Published var messageList: [MessageInfo] = []
    @Published var hasMoreOlderMessage: Bool = false
    @Published var hasMoreNewerMessage: Bool = false
    private let conversationID: String
    private let currentMessage: MessageInfo
    private let messageListStore: MessageListStore
    private let staticMessagesProvider: (() -> [MessageInfo])?
    private var mediaMessages: [MessageInfo] = []
    private var isLoadingOlder = false
    private var isLoadingNewer = false
    private var cancellables = Set<AnyCancellable>()

    init(conversationID: String, currentMessage: MessageInfo, messageListStore: MessageListStore, staticMessagesProvider: (() -> [MessageInfo])? = nil) {
        self.conversationID = conversationID
        self.currentMessage = currentMessage
        self.messageListStore = messageListStore
        self.staticMessagesProvider = staticMessagesProvider

        setupDataSubscriptions()
    }

    private func setupDataSubscriptions() {
        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))
            .sink { [weak self] messageList in
                guard let self = self else { return }
                self.messageList = messageList
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasOlderMessages))
            .sink { [weak self] hasMoreOlderMessage in
                guard let self = self else { return }
                self.hasMoreOlderMessage = hasMoreOlderMessage
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasNewerMessages))
            .sink { [weak self] hasMoreNewerMessage in
                guard let self = self else { return }
                self.hasMoreNewerMessage = hasMoreNewerMessage
            }
            .store(in: &cancellables)
    }

    func loadInitialData() async throws -> ([ImageElement], Int) {
        if let staticMessagesProvider = staticMessagesProvider {
            return try await loadStaticInitialData(staticMessages: staticMessagesProvider())
        }
        var option = MessageLoadOption()
        option.direction = .both
        option.pageCount = 5
        option.cursor = currentMessage
        option.messageTypeList = [.image, .video]
        let mediaElements = try await loadMediaMessages(with: option, isInitialLoad: true)
        let currentIndex = findCurrentMessageIndex(in: mediaMessages)
        return (mediaElements, currentIndex)
    }

    private func loadStaticInitialData(staticMessages: [MessageInfo]) async throws -> ([ImageElement], Int) {
        let mediaList = staticMessages.filter { $0.messageType == .image || $0.messageType == .video }
        mediaMessages = mediaList
        var elements: [ImageElement] = []
        elements.reserveCapacity(mediaList.count)
        for msg in mediaList {
            if let element = staticElement(from: msg) {
                elements.append(element)
                continue
            }
            if msg.messageType == .image, let downloaded = await downloadStaticImage(msg) {
                elements.append(downloaded)
                continue
            }
            elements.append(Self.placeholderElement(for: msg))
        }
        let currentIndex = mediaList.firstIndex { $0.id == currentMessage.id } ?? 0
        return (elements, currentIndex)
    }

    private func downloadStaticImage(_ msg: MessageInfo) async -> ImageElement? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            MessageActionStore.create(message: msg).downloadMedia(quality: .standard) { _ in
                continuation.resume()
            }
        }
        if let refreshed = staticMessagesProvider?().first(where: { $0.id == msg.id }) {
            return staticElement(from: refreshed)
        }
        return nil
    }

    private func staticElement(from msg: MessageInfo) -> ImageElement? {
        if msg.messageType == .image {
            guard let payload = Self.imagePayload(from: msg) else { return nil }
            if let path = payload.originalImagePath ?? payload.largeImagePath ?? payload.thumbImagePath,
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path)
            {
                return ImageElement(type: 0, imagePath: path, videoPath: "")
            }
            if let url = payload.originalImageURL ?? payload.largeImageURL ?? payload.thumbImageURL,
               !url.isEmpty
            {
                return ImageElement(type: 0, imagePath: url, videoPath: "")
            }
            return nil
        }
        if msg.messageType == .video {
            guard let payload = Self.videoPayload(from: msg) else { return nil }
            let snapshotSource: String?
            if let path = payload.videoSnapshotPath,
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path)
            {
                snapshotSource = path
            } else if let url = payload.videoSnapshotURL, !url.isEmpty {
                snapshotSource = url
            } else {
                snapshotSource = nil
            }
            guard let snapshot = snapshotSource else { return nil }
            let videoSource: String?
            if let path = payload.videoPath,
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path)
            {
                videoSource = path
            } else if let url = payload.videoURL, !url.isEmpty {
                videoSource = url
            } else {
                videoSource = nil
            }
            return ImageElement(type: 1, imagePath: snapshot, videoPath: videoSource ?? "")
        }
        return nil
    }

    private var reachedEndOlder = false
    private var reachedEndNewer = false
    private var cloudCursorOlder: MessageInfo?
    private var cloudCursorNewer: MessageInfo?

    func hasMoreMedia(isOlder: Bool) -> Bool {
        staticMessagesProvider == nil && !(isOlder ? reachedEndOlder : reachedEndNewer)
    }

    func loadMoreData(isOlder: Bool) async throws -> [ImageElement] {
        if staticMessagesProvider != nil { return [] }
        if isOlder ? reachedEndOlder : reachedEndNewer {
            return []
        }
        let isCurrentlyLoading = isOlder ? isLoadingOlder : isLoadingNewer
        if isCurrentlyLoading {
            return []
        }
        guard !mediaMessages.isEmpty else {
            return []
        }
        if isOlder {
            isLoadingOlder = true
        } else {
            isLoadingNewer = true
        }
        defer {
            if isOlder {
                isLoadingOlder = false
            } else {
                isLoadingNewer = false
            }
        }
        let anchorMessage = isOlder ? mediaMessages.first! : mediaMessages.last!
        if (isOlder ? cloudCursorOlder : cloudCursorNewer) != nil {
            return try await loadCloudFallback(isOlder: isOlder, anchor: anchorMessage)
        }
        var option = MessageLoadOption()
        option.direction = isOlder ? .older : .newer
        option.pageCount = 5
        option.cursor = anchorMessage
        option.messageTypeList = [.image, .video]
        var newElements = try await loadMediaMessages(with: option, isInitialLoad: false)
        if newElements.isEmpty {
            // 指定消息类型只能查询本地历史，缺页须用无类型云查询补齐后筛选媒体。
            newElements = try await loadCloudFallback(isOlder: isOlder, anchor: anchorMessage)
        }
        return newElements
    }

    private func loadCloudFallback(isOlder: Bool, anchor: MessageInfo) async throws -> [ImageElement] {
        var cursor = (isOlder ? cloudCursorOlder : cloudCursorNewer) ?? anchor
        var collected: [MessageInfo] = []
        var reachedEnd = false
        for _ in 0 ..< 5 {
            var option = MessageLoadOption()
            option.direction = isOlder ? .older : .newer
            option.pageCount = 20
            option.cursor = cursor
            let page = try await loadRawMessagePage(with: option)
            if page.isEmpty {
                reachedEnd = true
                break
            }
            let media = page.filter { $0.messageType == .image || $0.messageType == .video }
            collected = isOlder ? media + collected : collected + media
            guard let edge = isOlder ? page.first : page.last, edge.id != cursor.id else {
                throw NSError(domain: "ImageViewerPagination", code: 1, userInfo: [NSLocalizedDescriptionKey: "Message cursor did not advance"])
            }
            cursor = edge
            if page.count < 20 { reachedEnd = true }
            if collected.count >= 5 || reachedEnd { break }
        }
        var seenIDs = Set(mediaMessages.map { $0.id })
        let unique = collected.filter { seenIDs.insert($0.id).inserted }
        let elements = try await processMediaMessages(unique)
        if isOlder {
            mediaMessages = unique + mediaMessages
            cloudCursorOlder = cursor
            reachedEndOlder = reachedEnd
        } else {
            mediaMessages.append(contentsOf: unique)
            cloudCursorNewer = cursor
            reachedEndNewer = reachedEnd
        }
        return elements
    }

    private func loadRawMessagePage(with option: MessageLoadOption) async throws -> [MessageInfo] {
        try await withCheckedThrowingContinuation { continuation in
            messageListStore.loadMessages(option: option) { result in
                switch result {
                case .success:
                    continuation.resume(returning: self.messageList)
                case .failure(let error):
                    continuation.resume(throwing: NSError(domain: "MessageLoadError", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message]))
                }
            }
        }
    }

    private func findCurrentMessageIndex(in messages: [MessageInfo]) -> Int {
        return messages.firstIndex { $0.id == currentMessage.id } ?? 0
    }

    func findMessage(byImagePath imagePath: String) -> MessageInfo? {
        let candidates = staticMessagesProvider?() ?? mediaMessages
        return candidates.first { message in
            if message.messageType == .image, let payload = Self.imagePayload(from: message) {
                return payload.originalImagePath == imagePath
                    || payload.originalImageURL == imagePath
                    || payload.largeImagePath == imagePath
                    || payload.largeImageURL == imagePath
                    || payload.thumbImagePath == imagePath
                    || payload.thumbImageURL == imagePath
            }
            if message.messageType == .video, let payload = Self.videoPayload(from: message) {
                return payload.videoSnapshotPath == imagePath
                    || payload.videoSnapshotURL == imagePath
            }
            return false
        }
    }

    private func loadMediaMessages(with option: MessageLoadOption, isInitialLoad: Bool) async throws -> [ImageElement] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ImageElement], Error>) in
            messageListStore.loadMessages(option: option, completion: { result in
                switch result {
                case .success:
                    Task {
                        do {
                            let fetchedMediaMessages = self.messageList.filter { msg in
                                msg.messageType == .image || msg.messageType == .video
                            }
                            // 分页仅返回增量，避免重复路径破坏页面身份。
                            let messagesToProcess: [MessageInfo]
                            if isInitialLoad {
                                self.mediaMessages = fetchedMediaMessages
                                messagesToProcess = fetchedMediaMessages
                            } else if option.direction == .older {
                                let uniqueOlderMessages = fetchedMediaMessages.filter { newMsg in
                                    !self.mediaMessages.contains { $0.id == newMsg.id }
                                }
                                self.mediaMessages = uniqueOlderMessages + self.mediaMessages
                                messagesToProcess = uniqueOlderMessages
                            } else {
                                let uniqueNewerMessages = fetchedMediaMessages.filter { newMsg in
                                    !self.mediaMessages.contains { $0.id == newMsg.id }
                                }
                                self.mediaMessages.append(contentsOf: uniqueNewerMessages)
                                messagesToProcess = uniqueNewerMessages
                            }
                            let finalElements = try await self.processMediaMessages(messagesToProcess)
                            continuation.resume(returning: finalElements)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    let error = NSError(domain: "MessageLoadError", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message])
                    continuation.resume(throwing: error)
                }
            })
        }
    }

    private func processMediaMessage(msg: MessageInfo) async throws -> ImageElement {
        if msg.messageType == .image {
            return try await processImageMessage(msg)
        } else if msg.messageType == .video {
            return try await processVideoMessage(msg)
        } else {
            throw NSError(domain: "MessageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "message not support"])
        }
    }

    private func processMediaMessages(_ messages: [MessageInfo]) async throws -> [ImageElement] {
        var tempImageElements: [ImageElement?] = Array(repeating: nil, count: messages.count)
        try await withThrowingTaskGroup(of: (Int, ImageElement?, MessageInfo).self) { group in
            for (index, msg) in messages.enumerated() {
                group.addTask {
                    let element = try await self.processMediaMessage(msg: msg)
                    return (index, element, msg)
                }
            }
            for try await (index, element, _) in group {
                tempImageElements[index] = element
            }
        }
        for i in 0 ..< tempImageElements.count {
            if tempImageElements[i] == nil {
                tempImageElements[i] = Self.placeholderElement(for: messages[i])
            }
        }
        return tempImageElements.compactMap { $0 }
    }

    // 占位路径须唯一，避免空路径导致页面身份冲突。
    private static func placeholderElement(for msg: MessageInfo) -> ImageElement {
        let isVideo = msg.messageType == .video
        let token = msg.msgID.isEmpty ? msg.id : msg.msgID
        return ImageElement(type: isVideo ? 1 : 0, imagePath: "placeholder://\(token)", videoPath: "")
    }

    private func processImageMessage(_ msg: MessageInfo) async throws -> ImageElement {
        if let existingImagePath = Self.imagePayload(from: msg)?.largeImagePath,
           !existingImagePath.isEmpty,
           FileManager.default.fileExists(atPath: existingImagePath)
        {
            return ImageElement(type: 0, imagePath: existingImagePath, videoPath: "")
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ImageElement, Error>) in
            guard Self.imagePayload(from: msg) != nil else {
                continuation.resume(throwing: NSError(domain: "MessageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: LocalizedChatString("MessageBodyEmpty")]))
                return
            }
            MessageActionStore.create(message: msg).downloadMedia(quality: .standard, completion: { result in
                switch result {
                case .success:
                    Task { @MainActor in
                        let updatedMessage = self.messageListStore.state.value.messageList.first(where: { $0.id == msg.id }) ?? msg
                        let payload = Self.imagePayload(from: updatedMessage)
                        let paths = [payload?.largeImagePath, payload?.originalImagePath]
                        let localPath = paths.compactMap { $0 }.first { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
                        let remotePath = [payload?.largeImageURL, payload?.originalImageURL].compactMap { $0 }.first { !$0.isEmpty }
                        let element = (localPath ?? remotePath).map { ImageElement(type: 0, imagePath: $0) }
                            ?? Self.placeholderElement(for: msg)
                        continuation.resume(returning: element)
                    }
                case .failure:
                    continuation.resume(returning: Self.placeholderElement(for: msg))
                }
            })
        }
    }

    private func processVideoMessage(_ msg: MessageInfo) async throws -> ImageElement {
        if let existingSnapshotPath = Self.videoPayload(from: msg)?.videoSnapshotPath,
           !existingSnapshotPath.isEmpty,
           FileManager.default.fileExists(atPath: existingSnapshotPath)
        {
            let videoPath = Self.videoPayload(from: msg)?.videoPath ?? ""
            return ImageElement(type: 1, imagePath: existingSnapshotPath, videoPath: videoPath)
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ImageElement, Error>) in
            guard Self.videoPayload(from: msg) != nil else {
                continuation.resume(throwing: NSError(domain: "MessageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: LocalizedChatString("VideoMessageBodyEmpty")]))
                return
            }
            MessageActionStore.create(message: msg).downloadMedia(quality: .thumbnail, completion: { result in
                switch result {
                case .success:
                    if let updatedMessage = self.messageList.first(where: { $0.id == msg.id }),
                       let snapshotPath = Self.videoPayload(from: updatedMessage)?.videoSnapshotPath
                    {
                        let videoPath = Self.videoPayload(from: updatedMessage)?.videoPath ?? ""
                        let element = ImageElement(type: 1, imagePath: snapshotPath, videoPath: videoPath)
                        continuation.resume(returning: element)
                    } else {
                        let snapshotPath = Self.videoPayload(from: msg)?.videoSnapshotPath ?? ""
                        let videoPath = Self.videoPayload(from: msg)?.videoPath ?? ""
                        let element = snapshotPath.isEmpty
                            ? Self.placeholderElement(for: msg)
                            : ImageElement(type: 1, imagePath: snapshotPath, videoPath: videoPath)
                        continuation.resume(returning: element)
                    }
                case .failure:
                    continuation.resume(returning: Self.placeholderElement(for: msg))
                }
            })
        }
    }

    private static func imagePayload(from message: MessageInfo) -> ImageMessagePayload? {
        if case .image(let payload) = message.messagePayload {
            return payload
        }
        return nil
    }

    private static func videoPayload(from message: MessageInfo) -> VideoMessagePayload? {
        if case .video(let payload) = message.messagePayload {
            return payload
        }
        return nil
    }
}
