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
    private var cancellables = Set<AnyCancellable>()

    init(conversationID: String, currentMessage: MessageInfo) {
        self.messageListStore = MessageListStore.create(conversationID: conversationID, messageListType: .history)
        self.currentMessage = currentMessage

        setupDataSubscriptions()
    }

    private func setupDataSubscriptions() {
        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))
            .sink { [weak self] messageList in
                guard let self = self else { return }
                self.messageList = messageList
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreOlderMessage))
            .sink { [weak self] hasMoreOlderMessage in
                guard let self = self else { return }
                self.hasMoreOlderMessage = hasMoreOlderMessage
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreNewerMessage))
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
            currentMessage: currentMessage
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
                        let videoPath = try await withCheckedThrowingContinuation { continuation in
                            self.messageListStore.downloadMessageResource(locateMessage, resourceType: .video, completion: { result in
                                switch result {
                                case .success:
                                    if let updatedMessage = self.messageList.first(where: { $0.id == locateMessage.id }),
                                       let videoPath = updatedMessage.messageBody?.videoPath
                                    {
                                        continuation.resume(returning: videoPath)
                                    } else {
                                        continuation.resume(returning: locateMessage.messageBody?.videoPath ?? "")
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
}

class ImageViewerDataManager {
    @Published var messageList: [MessageInfo] = []
    @Published var hasMoreOlderMessage: Bool = false
    @Published var hasMoreNewerMessage: Bool = false
    private let conversationID: String
    private let currentMessage: MessageInfo
    private let messageListStore: MessageListStore
    private var mediaMessages: [MessageInfo] = []
    private var isLoadingOlder = false
    private var isLoadingNewer = false
    private var cancellables = Set<AnyCancellable>()

    init(conversationID: String, currentMessage: MessageInfo) {
        self.conversationID = conversationID
        self.currentMessage = currentMessage
        self.messageListStore = MessageListStore.create(conversationID: conversationID, messageListType: .history)

        setupDataSubscriptions()
    }

    private func setupDataSubscriptions() {
        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))
            .sink { [weak self] messageList in
                guard let self = self else { return }
                self.messageList = messageList
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreOlderMessage))
            .sink { [weak self] hasMoreOlderMessage in
                guard let self = self else { return }
                self.hasMoreOlderMessage = hasMoreOlderMessage
            }
            .store(in: &cancellables)

        messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreNewerMessage))
            .sink { [weak self] hasMoreNewerMessage in
                guard let self = self else { return }
                self.hasMoreNewerMessage = hasMoreNewerMessage
            }
            .store(in: &cancellables)
    }

    func loadInitialData() async throws -> ([ImageElement], Int) {
        var option = MessageFetchOption()
        option.direction = [.Older, .Newer]
        option.pageCount = 5
        option.message = currentMessage
        option.filterType = [.Image, .Video]
        let mediaElements = try await loadMediaMessages(with: option, isInitialLoad: true)
        let currentIndex = findCurrentMessageIndex(in: mediaMessages)
        return (mediaElements, currentIndex)
    }

    func loadMoreData(isOlder: Bool) async throws -> [ImageElement] {
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
        var option = MessageFetchOption()
        option.direction = isOlder ? [.Older] : [.Newer]
        option.pageCount = 5
        option.message = anchorMessage
        option.filterType = [.Image, .Video]
        let newElements = try await loadMediaMessages(with: option, isInitialLoad: false)
        return newElements
    }

    private func findCurrentMessageIndex(in messages: [MessageInfo]) -> Int {
        return messages.firstIndex { $0.id == currentMessage.id } ?? 0
    }

    func findMessage(byImagePath imagePath: String) -> MessageInfo? {
        return mediaMessages.first { message in
            if message.messageType == .image,
               let originalImagePath = message.messageBody?.originalImagePath,
               originalImagePath == imagePath
            {
                return true
            }
            if message.messageType == .video,
               let videoSnapshotPath = message.messageBody?.videoSnapshotPath,
               videoSnapshotPath == imagePath
            {
                return true
            }
            return false
        }
    }

    private func loadMediaMessages(with option: MessageFetchOption, isInitialLoad: Bool) async throws -> [ImageElement] {
        return try await withCheckedThrowingContinuation { continuation in
            messageListStore.fetchMessageList(with: option, completion: { result in
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
                                if option.direction.contains(.Older) {
                                    let uniqueOlderMessages = fetchedMediaMessages.filter { newMsg in
                                        !self.mediaMessages.contains { $0.id == newMsg.id }
                                    }
                                    self.mediaMessages = uniqueOlderMessages + self.mediaMessages
                                } else if option.direction.contains(.Newer) {
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
        if let existingImagePath = msg.messageBody?.largeImagePath,
           !existingImagePath.isEmpty,
           FileManager.default.fileExists(atPath: existingImagePath)
        {
            return ImageElement(type: 0, imagePath: existingImagePath, videoPath: "")
        }
        return try await withCheckedThrowingContinuation { continuation in
            guard msg.messageBody != nil else {
                continuation.resume(throwing: NSError(domain: "MessageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: LocalizedChatString("MessageBodyEmpty")]))
                return
            }
            do {
                messageListStore.downloadMessageResource(msg, resourceType: .largeImage, completion: { result in
                    switch result {
                    case .success:
                        if let updatedMessage = self.messageList.first(where: { $0.id == msg.id }),
                           let updatedImagePath = updatedMessage.messageBody?.originalImagePath,
                           !updatedImagePath.isEmpty
                        {
                            let element = ImageElement(type: 0, imagePath: updatedImagePath, videoPath: "")
                            continuation.resume(returning: element)
                        } else {
                            let fallbackPath = msg.messageBody?.originalImagePath ?? ""
                            let element = ImageElement(type: 0, imagePath: fallbackPath, videoPath: "")
                            continuation.resume(returning: element)
                        }
                    case .failure(let error):
                        let element = ImageElement(type: 0, imagePath: "", videoPath: "")
                        continuation.resume(returning: element)
                    }
                })
            }
        }
    }

    private func processVideoMessage(_ msg: MessageInfo) async throws -> ImageElement {
        if let existingSnapshotPath = msg.messageBody?.videoSnapshotPath,
           !existingSnapshotPath.isEmpty,
           FileManager.default.fileExists(atPath: existingSnapshotPath)
        {
            let videoPath = msg.messageBody?.videoPath ?? ""
            return ImageElement(type: 1, imagePath: existingSnapshotPath, videoPath: videoPath)
        }
        return try await withCheckedThrowingContinuation { continuation in
            guard msg.messageBody != nil else {
                continuation.resume(throwing: NSError(domain: "MessageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: LocalizedChatString("VideoMessageBodyEmpty")]))
                return
            }
            do {
                messageListStore.downloadMessageResource(msg, resourceType: .videoSnapshot, completion: { result in
                    switch result {
                    case .success:
                        if let updatedMessage = self.messageList.first(where: { $0.id == msg.id }),
                           let snapshotPath = updatedMessage.messageBody?.videoSnapshotPath
                        {
                            let videoPath = updatedMessage.messageBody?.videoPath ?? ""
                            let element = ImageElement(type: 1, imagePath: snapshotPath, videoPath: videoPath)
                            continuation.resume(returning: element)
                        } else {
                            let snapshotPath = msg.messageBody?.videoSnapshotPath ?? ""
                            let videoPath = msg.messageBody?.videoPath ?? ""
                            let element = ImageElement(type: 1, imagePath: snapshotPath, videoPath: videoPath)
                            continuation.resume(returning: element)
                        }
                    case .failure(let error):
                        let element = ImageElement(type: 1, imagePath: "", videoPath: "")
                        continuation.resume(returning: element)
                    }
                })
            }
        }
    }
}
