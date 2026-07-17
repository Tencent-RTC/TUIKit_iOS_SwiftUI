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
    private let currentMessage: MessageInfo
    // When non-nil, the viewer is fed by this static list (used by the merged-message detail
    // view, whose sub-messages live outside any MessageListStore and therefore cannot be
    // paginated through `loadMessages`).
    private let staticMessages: [MessageInfo]?
    private var cancellables = Set<AnyCancellable>()

    init(conversationID: String, currentMessage: MessageInfo, staticMessages: [MessageInfo]? = nil) {
        self.messageListStore = MessageListStore.create(conversationID: conversationID)
        self.currentMessage = currentMessage
        self.staticMessages = staticMessages

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

    func showImageViewerIfAvailable() {
        guard !isLoadingImageData else { return }
        isLoadingImageData = true
        initialImageElements = []
        initialImageIndex = 0
        let dataManager = ImageViewerDataManager(
            conversationID: conversationID,
            currentMessage: currentMessage,
            messageListStore: messageListStore,
            staticMessages: staticMessages
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

    @ViewBuilder
    func imageViewerContent() -> some View {
        if !initialImageElements.isEmpty {
            imageViewerView
        } else {
            loadingPlaceholder
        }
    }

    private var imageViewerView: some View {
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
                        let elements = try await self.imageViewerDataManager?.loadMoreData(isOlder: isOlder) ?? []
                        completion(elements)
                    } catch {
                        completion(nil)
                    }
                }
            case "onDownloadVideo":
                guard let paramDict = eventData["param"] as? [String: Any],
                      let imagePath = paramDict["path"] as? String
                else {
                    completion(nil)
                    return
                }
                Task {
                    do {
                        guard let dataManager = self.imageViewerDataManager,
                              let locateMessage = dataManager.findMessage(byImagePath: imagePath)
                        else {
                            completion(nil)
                            return
                        }
                        let videoPath = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                            MessageActionStore.create(message: locateMessage).downloadMedia(quality: .standard, completion: { result in
                                switch result {
                                case .success:
                                    // Prefer the updated local path from the store, otherwise
                                    // fall back to the URL we already have on the payload so
                                    // merged-message playback works even when the merged
                                    // detail view's store does not receive the update.
                                    if let updatedMessage = self.messageList.first(where: { $0.id == locateMessage.id }),
                                       let videoPath = Self.videoPayload(from: updatedMessage)?.videoPath,
                                       !videoPath.isEmpty
                                    {
                                        continuation.resume(returning: videoPath)
                                    } else if let payload = Self.videoPayload(from: locateMessage) {
                                        let localPath = payload.videoPath.flatMap { $0.isEmpty ? nil : $0 }
                                        let remoteURL = payload.videoURL.flatMap { $0.isEmpty ? nil : $0 }
                                        continuation.resume(returning: localPath ?? remoteURL ?? "")
                                    } else {
                                        continuation.resume(returning: "")
                                    }
                                case .failure(let error):
                                    let error = NSError(domain: "VideoDownloadError", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message])
                                    continuation.resume(throwing: error)
                                }
                            })
                        }
                        completion([videoPath])
                    } catch {
                        completion(nil)
                    }
                }
            default:
                completion(nil)
            }
        }
        return ImageViewer(imageElements: initialImageElements, initialIndex: initialImageIndex, onEventTriggered: onEventTriggered)
    }

    private var loadingPlaceholder: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isLoadingImageData {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text(LocalizedChatString("Loading"))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
            }
        }
    }

    private static func videoPayload(from message: MessageInfo) -> VideoMessagePayload? {
        if case .video(let payload) = message.messagePayload {
            return payload
        }
        return nil
    }
}

class ImageViewerDataManager {
    @Published var messageList: [MessageInfo] = []
    @Published var hasMoreOlderMessage: Bool = false
    @Published var hasMoreNewerMessage: Bool = false
    private let conversationID: String
    private let currentMessage: MessageInfo
    private let messageListStore: MessageListStore
    // When non-nil, the manager operates in "static" mode: media elements are built from this
    // fixed snapshot (used by merged-message detail view, where sub-messages live outside any
    // MessageListStore). Pagination is disabled in this mode.
    private let staticMessages: [MessageInfo]?
    private var mediaMessages: [MessageInfo] = []
    private var isLoadingOlder = false
    private var isLoadingNewer = false
    private var cancellables = Set<AnyCancellable>()

    init(conversationID: String, currentMessage: MessageInfo, messageListStore: MessageListStore, staticMessages: [MessageInfo]? = nil) {
        self.conversationID = conversationID
        self.currentMessage = currentMessage
        self.messageListStore = messageListStore
        self.staticMessages = staticMessages

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
        if let staticMessages = staticMessages {
            return try await loadStaticInitialData(staticMessages: staticMessages)
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
            } else {
                let isVideo = msg.messageType == .video
                elements.append(ImageElement(type: isVideo ? 1 : 0, imagePath: "", videoPath: ""))
            }
        }
        let currentIndex = mediaList.firstIndex { $0.id == currentMessage.id } ?? 0
        return (elements, currentIndex)
    }

    // Build an ImageElement directly from a static MessageInfo: prefer a local file when the
    // SDK has cached it, otherwise fall back to the remote URL so ImageViewer's KFImage path
    // can still display the asset.
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

    func loadMoreData(isOlder: Bool) async throws -> [ImageElement] {
        // Static mode has no paging; bail out early.
        if staticMessages != nil { return [] }
        let hasMoreData = isOlder ? hasMoreOlderMessage : hasMoreNewerMessage
        if !hasMoreData {
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
        var option = MessageLoadOption()
        option.direction = isOlder ? .older : .newer
        option.pageCount = 5
        option.cursor = anchorMessage
        option.messageTypeList = [.image, .video]
        let newElements = try await loadMediaMessages(with: option, isInitialLoad: false)
        return newElements
    }

    private func findCurrentMessageIndex(in messages: [MessageInfo]) -> Int {
        return messages.firstIndex { $0.id == currentMessage.id } ?? 0
    }

    func findMessage(byImagePath imagePath: String) -> MessageInfo? {
        // The ImageElement.imagePath we hand to ImageViewer can be either a local file path
        // or a remote URL (static merged-message mode). Match against every variant the
        // payload can hold so we can locate the source MessageInfo for downloads.
        return mediaMessages.first { message in
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
                            if isInitialLoad {
                                self.mediaMessages = fetchedMediaMessages
                            } else {
                                if option.direction == .older {
                                    let uniqueOlderMessages = fetchedMediaMessages.filter { newMsg in
                                        !self.mediaMessages.contains { $0.id == newMsg.id }
                                    }
                                    self.mediaMessages = uniqueOlderMessages + self.mediaMessages
                                } else if option.direction == .newer {
                                    let uniqueNewerMessages = fetchedMediaMessages.filter { newMsg in
                                        !self.mediaMessages.contains { $0.id == newMsg.id }
                                    }
                                    self.mediaMessages.append(contentsOf: uniqueNewerMessages)
                                }
                            }
                            let messagesToProcess = fetchedMediaMessages
                            var tempImageElements: [ImageElement?] = Array(repeating: nil, count: messagesToProcess.count)
                            try await withThrowingTaskGroup(of: (Int, ImageElement?, MessageInfo).self) { group in
                                for (index, msg) in messagesToProcess.enumerated() {
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
                                    let isVideo = messagesToProcess[i].messageType == .video
                                    tempImageElements[i] = ImageElement(
                                        type: isVideo ? 1 : 0,
                                        imagePath: "",
                                        videoPath: ""
                                    )
                                }
                            }
                            let finalElements = tempImageElements.compactMap { $0 }
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
                    if let updatedMessage = self.messageList.first(where: { $0.id == msg.id }),
                       let updatedImagePath = Self.imagePayload(from: updatedMessage)?.originalImagePath,
                       !updatedImagePath.isEmpty
                    {
                        let element = ImageElement(type: 0, imagePath: updatedImagePath, videoPath: "")
                        continuation.resume(returning: element)
                    } else {
                        let fallbackPath = Self.imagePayload(from: msg)?.originalImagePath ?? ""
                        let element = ImageElement(type: 0, imagePath: fallbackPath, videoPath: "")
                        continuation.resume(returning: element)
                    }
                case .failure:
                    let element = ImageElement(type: 0, imagePath: "", videoPath: "")
                    continuation.resume(returning: element)
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
                        let element = ImageElement(type: 1, imagePath: snapshotPath, videoPath: videoPath)
                        continuation.resume(returning: element)
                    }
                case .failure:
                    let element = ImageElement(type: 1, imagePath: "", videoPath: "")
                    continuation.resume(returning: element)
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
