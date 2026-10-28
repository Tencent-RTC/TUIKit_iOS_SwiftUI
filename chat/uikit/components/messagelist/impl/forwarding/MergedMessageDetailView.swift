import AtomicXCore
import SwiftUI

struct MergedMessageDetailView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @StateObject private var messageStoreHolder = MergedMessageStoreHolder()
    @StateObject private var multiSelectManager = MultiSelectManager()
    @StateObject private var menuManager = MessageMenuManager()
    @StateObject private var auxiliaryTextMenuManager = AuxiliaryTextMenuManager()
    @StateObject private var quoteResolveStoreHolder: QuoteResolveStoreHolder
    @StateObject private var mediaMessagesBox = MergedMediaMessagesBox()
    @StateObject private var imageViewerManager: ImageViewerManager
    @State private var subMessages: [MessageInfo] = []
    @State private var isLoading = true
    @State private var mergedActionStore: MessageActionStore? = nil
    @State private var highlightMessageID: String? = nil

    private static let quoteResolvePageCount = 20

    let mergedMessage: MessageInfo
    let depth: Int
    let conversationID: String
    let embedInNavigationView: Bool
    @State private var nestedMergedMessage: MessageInfo? = nil
    @State private var showNestedDetail = false

    private var messageStore: MessageListStore { messageStoreHolder.store }
    private var quoteResolveStore: MessageListStore { quoteResolveStoreHolder.store }

    init(mergedMessage: MessageInfo, conversationID: String, depth: Int = 0, embedInNavigationView: Bool = false) {
        self.mergedMessage = mergedMessage
        self.depth = depth
        self.conversationID = conversationID
        self.embedInNavigationView = embedInNavigationView
        _quoteResolveStoreHolder = StateObject(wrappedValue: QuoteResolveStoreHolder(conversationID: conversationID))
        _imageViewerManager = StateObject(wrappedValue: ImageViewerManager(conversationID: conversationID, currentMessage: MessageInfo()))
    }

    private var title: String {
        if case .merged(let payload) = mergedMessage.messagePayload, !payload.title.isEmpty {
            return payload.title
        }
        return LocalizedChatString("RelayChatHistory")
    }

    var body: some View {
        if embedInNavigationView {
            NavigationView { pageContent }
        } else {
            pageContent
        }
    }

    private var pageContent: some View {
        ZStack {
            themeState.colors.listColorDefault
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if subMessages.isEmpty {
                Text(LocalizedChatString("RelayNoMessage"))
                    .foregroundColor(themeState.colors.textColorSecondary)
            } else {
                messageListView
            }

            NavigationLink(
                destination: nestedDestination,
                isActive: $showNestedDetail
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarTitle(title, displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(false)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.template)
                .foregroundColor(themeState.colors.textColorPrimary)
                .frame(width: 28, height: 44, alignment: .leading)
        })
        .fullScreenCover(isPresented: $imageViewerManager.isShowingImageViewer) {
            imageViewerManager.imageViewerContent()
        }
        .onAppear {
            if subMessages.isEmpty && isLoading {
                loadSubMessages()
            }
        }
    }

    @ViewBuilder
    private var nestedDestination: some View {
        if let nested = nestedMergedMessage {
            MergedMessageDetailView(mergedMessage: nested, conversationID: conversationID, depth: depth + 1)
                .environmentObject(themeState)
        } else {
            EmptyView()
        }
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(subMessages.filter { $0.status != .revoked }) { message in
                        MessageView(
                            message: message,
                            messageListStore: messageStore,
                            conversationID: "",
                            audioPlayer: sharedAudioPlayer,
                            audioPlaybackManager: audioPlaybackManager,
                            onUserClick: nil,
                            parentMessageList: subMessages,
                            displayMode: .merged,
                            mergedMediaSource: mediaMessagesBox,
                            imageViewerManager: imageViewerManager
                        )
                        .id(message.msgID)
                        .environment(\.isInMergedDetailView, true)
                        .environmentObject(multiSelectManager)
                        .environmentObject(menuManager)
                        .environmentObject(auxiliaryTextMenuManager)
                        .environment(\.openMergedMessageDetail, { nested in
                            nestedMergedMessage = nested
                            showNestedDetail = true
                        })
                        .environment(\.locateMessageID, highlightMessageID)
                        .environmentObject(themeState)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("locateMessageNotification"))) { notification in
                guard let msgID = notification.userInfo?["msgID"] as? String, !msgID.isEmpty else { return }
                handleQuoteLocate(msgID: msgID, proxy: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatVideoPlaybackDidStart)) { _ in
                sharedAudioPlayer.stop()
                audioPlaybackManager.clearCurrentPlayingMsgID()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("messageMediaDownloadProgress"))) { notification in
                handleMediaDownloadProgress(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("messageMediaDownload"))) { notification in
                handleMediaDownloadFinished(notification)
            }
        }
    }

    private func applySubMessages(_ list: [MessageInfo]) {
        subMessages = list
        mediaMessagesBox.messages = list
    }

    private func handleMediaDownloadProgress(_ notification: Notification) {
        guard let data = notification.userInfo?["data"],
              let messageID = Self.stringField("messageID", from: data), !messageID.isEmpty,
              let progress = Self.intField("downloadMediaProgress", from: data),
              let index = subMessages.firstIndex(where: { $0.msgID == messageID }) else { return }
        guard subMessages[index].downloadMediaProgress != progress else { return }
        subMessages[index].downloadMediaProgress = progress
        mediaMessagesBox.messages = subMessages
    }

    private func handleMediaDownloadFinished(_ notification: Notification) {
        guard let data = notification.userInfo?["data"],
              let messageID = Self.stringField("messageID", from: data), !messageID.isEmpty,
              let payload = Self.payloadField("messagePayload", from: data),
              let index = subMessages.firstIndex(where: { $0.msgID == messageID }) else { return }
        subMessages[index].messagePayload = payload
        subMessages[index].downloadMediaProgress = 100
        mediaMessagesBox.messages = subMessages
    }

    private static func stringField(_ label: String, from data: Any) -> String? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? String
    }

    private static func intField(_ label: String, from data: Any) -> Int? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? Int
    }

    private static func payloadField(_ label: String, from data: Any) -> MessagePayload? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? MessagePayload
    }

    private func handleQuoteLocate(msgID: String, proxy: ScrollViewProxy) {
        let visible = subMessages.filter { $0.status != .revoked }
        guard visible.contains(where: { $0.msgID == msgID }) else {
            WindowToastManager.shared.show(LocalizedChatString("ReplyMessageNotFoundOriginMessage"), type: .info, duration: 3)
            return
        }
        highlightMessageID = msgID
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(msgID, anchor: .center)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if highlightMessageID == msgID {
                highlightMessageID = nil
            }
        }
    }

    private func loadSubMessages() {
        let actionStore = MessageActionStore.create(message: mergedMessage)
        mergedActionStore = actionStore // 持有 Store 至异步回调完成。
        actionStore.downloadMergedMessageList(completion: MergedMessageDetailCompletionHandler(
            onSuccess: { messageList in
                DispatchQueue.main.async {
                    self.applySubMessages(messageList)
                    self.isLoading = false
                    self.mergedActionStore = nil
                    self.resolveQuotesFromCloudIfNeeded()
                }
            },
            onFailure: { code, desc in
                print(">>>>> MergedMessageDetailView downloadMergedMessageList failed: \(code), \(desc)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.mergedActionStore = nil
                }
            }
        ))
    }
}

// 由 StateObject 稳定 Store 生命周期，避免视图重建导致重复监听和悬空指针。
private final class MergedMessageStoreHolder: ObservableObject {
    let store: MessageListStore = MessageListStore.create(conversationID: "")
}

private final class QuoteResolveStoreHolder: ObservableObject {
    let store: MessageListStore
    init(conversationID: String) {
        self.store = MessageListStore.create(conversationID: conversationID)
    }
}

extension MergedMessageDetailView {
    private func resolveQuotesFromCloudIfNeeded() {
        let pending = subMessages.indices.filter { index in
            guard let quote = subMessages[index].quoteInfo,
                  !quote.msgID.isEmpty,
                  quote.messagePayload == nil,
                  quote.timestamp > 0
            else { return false }
            return true
        }
        guard !pending.isEmpty else { return }
        resolveNextQuote(pending: pending, position: 0)
    }

    private func resolveNextQuote(pending: [Int], position: Int) {
        guard position < pending.count else { return }
        let index = pending[position]
        guard let quote = subMessages[index].quoteInfo else {
            resolveNextQuote(pending: pending, position: position + 1)
            return
        }
        var anchor = MessageInfo()
        anchor.timestamp = quote.timestamp
        var option = MessageLoadOption()
        option.cursor = anchor
        option.direction = .older
        option.pageCount = Self.quoteResolvePageCount
        quoteResolveStore.loadMessages(option: option) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let loaded = self.quoteResolveStore.state.value.messageList
                    if let found = loaded.first(where: { $0.msgID == quote.msgID }) {
                        self.applyResolvedQuote(found, at: index)
                    } else {
                        self.markQuoteDeleted(at: index)
                    }
                case .failure:
                    break
                }
                self.resolveNextQuote(pending: pending, position: position + 1)
            }
        }
    }

    private func applyResolvedQuote(_ original: MessageInfo, at index: Int) {
        guard subMessages.indices.contains(index), var quote = subMessages[index].quoteInfo else { return }
        quote.status = original.status
        quote.sender = original.from
        quote.messageType = original.messageType
        quote.messagePayload = original.messagePayload
        subMessages[index].quoteInfo = quote
        mediaMessagesBox.messages = subMessages
    }

    private func markQuoteDeleted(at index: Int) {
        guard subMessages.indices.contains(index), var quote = subMessages[index].quoteInfo else { return }
        guard quote.status != .deleted else { return }
        quote.status = .deleted
        subMessages[index].quoteInfo = quote
        mediaMessagesBox.messages = subMessages
    }
}

final class MergedMediaMessagesBox: ObservableObject {
    var messages: [MessageInfo] = []
}

private final class MergedMessageDetailCompletionHandler: MergedMessageListCompletionHandler {
    private let onSuccessHandler: ([MessageInfo]) -> Void
    private let onFailureHandler: (Int, String) -> Void

    init(onSuccess: @escaping ([MessageInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }

    func onSuccess(messageList: [MessageInfo]) {
        onSuccessHandler(messageList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}
