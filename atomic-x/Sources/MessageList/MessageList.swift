import AtomicXCore
import AVFoundation
import Combine
import Foundation
import SwiftUI

public struct MessageCustomAction {
    public let title: String
    public let iconName: String
    public let systemIconFallback: String
    public let action: (MessageInfo) -> Void

    public init(
        title: String,
        iconName: String = "",
        systemIconFallback: String = "ellipsis",
        action: @escaping (MessageInfo) -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.action = action
    }
}

extension View {
    func onValueChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        return onChange(of: value, perform: action)
    }

    private func createValuePublisher<Value>(_ value: Value) -> AnyPublisher<Value, Never> {
        return Future<Value, Never> { promise in
            promise(.success(value))
        }
        .eraseToAnyPublisher()
    }
}

extension View {
    @ViewBuilder
    func listRowSeparatorHidden() -> some View {
        listRowSeparator(.hidden)
    }

    @ViewBuilder
    func listRowInsetsZero() -> some View {
        listRowInsets(EdgeInsets())
    }
}

// MARK: - Multi-Select Manager

class MultiSelectManager: ObservableObject {
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedMessageIDs: Set<String> = []

    func enterMultiSelectMode(initialMessageID: String?) {
        if let msgID = initialMessageID {
            selectedMessageIDs.insert(msgID)
        }
        isMultiSelectMode = true
    }

    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedMessageIDs.removeAll()
    }

    func toggleSelection(messageID: String) {
        if selectedMessageIDs.contains(messageID) {
            selectedMessageIDs.remove(messageID)
        } else {
            selectedMessageIDs.insert(messageID)
        }
    }

    func isSelected(messageID: String) -> Bool {
        return selectedMessageIDs.contains(messageID)
    }
}

private struct MultiSelectManagerKey: EnvironmentKey {
    static let defaultValue: MultiSelectManager = .init()
}

extension EnvironmentValues {
    var multiSelectManager: MultiSelectManager {
        get { self[MultiSelectManagerKey.self] }
        set { self[MultiSelectManagerKey.self] = newValue }
    }
}

private struct MessageListConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageListConfigProtocol = ChatMessageListConfig()
}

private struct MessageCustomActionsKey: EnvironmentKey {
    static let defaultValue: [MessageCustomAction] = []
}

private struct MultiSelectModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct SelectedMessageIDsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

private struct ToggleMessageSelectionKey: EnvironmentKey {
    static let defaultValue: ((MessageInfo) -> Void)? = nil
}

extension EnvironmentValues {
    var messageListConfigProtocol: MessageListConfigProtocol {
        get { self[MessageListConfigProtocolKey.self] }
        set { self[MessageListConfigProtocolKey.self] = newValue }
    }

    var messageCustomActions: [MessageCustomAction] {
        get { self[MessageCustomActionsKey.self] }
        set { self[MessageCustomActionsKey.self] = newValue }
    }

    var isMultiSelectMode: Bool {
        get { self[MultiSelectModeKey.self] }
        set { self[MultiSelectModeKey.self] = newValue }
    }

    var selectedMessageIDs: Set<String> {
        get { self[SelectedMessageIDsKey.self] }
        set { self[SelectedMessageIDsKey.self] = newValue }
    }

    var toggleMessageSelection: ((MessageInfo) -> Void)? {
        get { self[ToggleMessageSelectionKey.self] }
        set { self[ToggleMessageSelectionKey.self] = newValue }
    }
}

public struct MessageList: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var keyboardHandler = KeyboardHandler()
    @StateObject private var menuManager = MessageMenuManager()
    @StateObject private var auxiliaryTextMenuManager = AuxiliaryTextMenuManager()
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @StateObject private var multiSelectManager = MultiSelectManager()
    @StateObject private var asrDisplayManager = AsrDisplayManager()
    @StateObject private var translationDisplayManager = TranslationDisplayManager()
    @State private var isLoading = false
    @State private var isLoadingMoreMessages = false
    @State private var isLoadingMoreNewerMessages = false
    @State private var anchorMessageId: String? = nil
    @State private var messageList: [MessageInfo] = []
    @State private var hasMoreOlderMessage: Bool = false
    @State private var hasMoreNewerMessage: Bool = false
    @State private var messageListStore: MessageListStore? = nil
    @State private var isStoreInitialized = false
    @State private var isPageVisible = false
    @State private var hasInitialLoaded = false
    @State private var messageCountOnDisappear: Int = 0
    @State private var scrollProxyReference: ScrollViewProxy? = nil
    @State private var isInitialScrollComplete = false
    @State private var isFirstFetchCompleted = false
    @State private var isUserAtBottom = true
    @State private var pendingReceiptMessageIDs: Set<String> = []
    @State private var sentReceiptMessageIDs: Set<String> = []
    @State private var receiptTimer: Timer?

    // 已读回执详情页面导航
    @State private var showReadReceiptView: Bool = false
    @State private var readReceiptMessage: MessageInfo? = nil
    @State private var readReceiptStore: MessageActionStore? = nil

    // 消息转发相关状态
    @State private var showForwardTargetSelector = false
    @State private var showForwardTypeDialog = false
    @State private var showSeparateForwardLimitAlert = false
    @State private var forwardType: MessageForwardType = .separate
    @State private var messagesForForward: [MessageInfo] = []
    @State private var asrTextToForward: String? = nil
    @State private var translatedTextToForward: String? = nil

    // MessageList visible bounds for menu positioning
    @State private var messageListBounds: CGRect = .zero

    let config: MessageListConfigProtocol & MessageActionConfigProtocol
    private let customActions: [MessageCustomAction]

    private let conversationID: String
    private let onUserClick: ((String) -> Void)?
    private let onMultiSelectModeChange: ((Bool, AnyView?) -> Void)?
    private let locateMessage: MessageInfo?
    private var conversationStore: ConversationListStore

    public init(
        conversationID: String,
        config: MessageListConfigProtocol & MessageActionConfigProtocol = ChatMessageListConfig(),
        locateMessage: MessageInfo? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMultiSelectModeChange: ((Bool, AnyView?) -> Void)? = nil,
        customActions: [MessageCustomAction] = []
    ) {
        self.conversationID = conversationID
        self.locateMessage = locateMessage
        self.onUserClick = onUserClick
        self.onMultiSelectModeChange = onMultiSelectModeChange
        self.customActions = customActions
        self.conversationStore = ConversationListStore.create()
        self.config = config
    }

    private var store: MessageListStore {
        guard let store = messageListStore else {
            return MessageListStore.create(conversationID: conversationID, messageListType: .history)
        }
        return store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            themeState.colors.bgColorOperate.ignoresSafeArea()

            scrollableMessageListView
                .opacity(isInitialScrollComplete ? 1 : 0)
            MessageMenuView
                .opacity(isInitialScrollComplete ? 1 : 0)
            AuxiliaryTextMenuView(menuManager: auxiliaryTextMenuManager)
                .environmentObject(themeState)
                .zIndex(1001)
                .opacity(isInitialScrollComplete ? 1 : 0)

            if isLoading || !isInitialScrollComplete {
                loadingIndicatorView
            }
        }
        .background(themeState.colors.bgColorOperate)
        .videoPlayerSupport()
        .onAppear {
            isPageVisible = true
            initializeStoreIfNeeded()

            // Check if store already has messages (view was recreated)
            let storeHasMessages = store.state.value.messageList.count > 0

            if !hasInitialLoaded && !storeHasMessages {
                isInitialScrollComplete = false
                fetchMessages()
                hasInitialLoaded = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !isInitialScrollComplete {
                        isInitialScrollComplete = true
                    }
                }
            } else if storeHasMessages {
                // View was recreated but store has data, skip fetch and mark complete
                hasInitialLoaded = true
                isInitialScrollComplete = true
            } else {
                isInitialScrollComplete = true
                if messageList.count > messageCountOnDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let proxy = scrollProxyReference {
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                }
            }
        }
        .onDisappear {
            isPageVisible = false
            messageCountOnDisappear = messageList.count
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))) { messageList in
            self.messageList = messageList
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreOlderMessage))) { hasMoreOlderMessage in
            self.hasMoreOlderMessage = hasMoreOlderMessage
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreNewerMessage))) { hasMoreNewerMessage in
            self.hasMoreNewerMessage = hasMoreNewerMessage
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("kShowMessageReadReceiptNotification"))) { notification in
            if let message = notification.userInfo?["message"] as? MessageInfo,
               let store = notification.userInfo?["messageActionStore"] as? MessageActionStore
            {
                readReceiptMessage = message
                readReceiptStore = store
                showReadReceiptView = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("enterMultiSelectMode"))) { notification in
            let message = notification.userInfo?["initialMessage"] as? MessageInfo
            enterMultiSelectMode(initialMessage: message)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("showForwardTargetSelector"))) { notification in
            if let messages = notification.userInfo?["messages"] as? [MessageInfo] {
                messagesForForward = messages
                asrTextToForward = nil
                forwardType = .separate
                showForwardTargetSelector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("forwardAsrText"))) { notification in
            if let asrText = notification.userInfo?["asrText"] as? String {
                asrTextToForward = asrText
                messagesForForward = []
                showForwardTargetSelector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("asrTextConversionCompleted"))) { notification in
            // Scroll to bottom if the converted message is the last one
            if let msgID = notification.userInfo?["msgID"] as? String,
               let lastMessage = messageList.last,
               lastMessage.msgID == msgID,
               let proxy = scrollProxyReference
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("forwardTranslatedText"))) { notification in
            if let translatedText = notification.userInfo?["translatedText"] as? String {
                translatedTextToForward = translatedText
                asrTextToForward = nil
                messagesForForward = []
                showForwardTargetSelector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("translationCompleted"))) { notification in
            // Scroll to bottom if the translated message is the last one
            if let msgID = notification.userInfo?["msgID"] as? String,
               let lastMessage = messageList.last,
               lastMessage.msgID == msgID,
               let proxy = scrollProxyReference
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("reactionBarAppeared"))) { notification in
            // Scroll to bottom when reaction bar appears on the last message
            if let msgID = notification.userInfo?["msgID"] as? String,
               let lastMessage = messageList.last,
               lastMessage.msgID == msgID,
               let proxy = scrollProxyReference
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
        .sheet(isPresented: $showReadReceiptView) {
            if let message = readReceiptMessage,
               let actionStore = readReceiptStore
            {
                NavigationView {
                    MessageReadReceiptView(
                        messageActionStore: actionStore,
                        messageListStore: store,
                        message: message
                    )
                }
            }
        }
        .modifier(ForwardTypeDialogModifier(
            isPresented: $showForwardTypeDialog,
            onSeparateForward: { [self] in
                if multiSelectManager.selectedMessageIDs.count > 30 {
                    showSeparateForwardLimitAlert = true
                    return
                }
                forwardType = .separate
                messagesForForward = getSelectedMessages()
                showForwardTargetSelector = true
            },
            onMergedForward: {
                forwardType = .merged
                messagesForForward = getSelectedMessages()
                showForwardTargetSelector = true
            }
        ))
        .sheet(isPresented: $showForwardTargetSelector) {
            ForwardTargetSelector(
                onConfirm: { conversationIDs in
                    // Exit multi-select mode and close sheet immediately
                    showForwardTargetSelector = false
                    exitMultiSelectMode()

                    if let asrText = asrTextToForward {
                        forwardAsrTextToConversations(asrText: asrText, conversationIDs: conversationIDs)
                    } else if let translatedText = translatedTextToForward {
                        forwardTranslatedTextToConversations(translatedText: translatedText, conversationIDs: conversationIDs)
                    } else {
                        executeForward(
                            messages: messagesForForward,
                            to: conversationIDs,
                            type: forwardType
                        )
                    }
                },
                onDismiss: {
                    showForwardTargetSelector = false
                }
            )
            .environmentObject(themeState)
        }
        .alert(isPresented: $showSeparateForwardLimitAlert) {
            Alert(
                title: Text(LocalizedChatString("RelayOneByOnyOverLimit")),
                message: Text(""),
                primaryButton: .cancel(Text(LocalizedChatString("Cancel"))),
                secondaryButton: .default(Text(LocalizedChatString("RelayCombineForwad"))) {
                    forwardType = .merged
                    messagesForForward = getSelectedMessages()
                    showForwardTargetSelector = true
                }
            )
        }
    }

    private var loadingIndicatorView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("loading...")
                .font(.system(size: 14))
                .foregroundColor(themeState.colors.textColorSecondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .zIndex(2)
    }

    @ViewBuilder
    private func messageListContent(scrollProxy: ScrollViewProxy) -> some View {
        // Newer messages at Top (Visual Bottom in Inverted)
        if hasMoreNewerMessage {
            HStack {
                Spacer()
                if isLoadingMoreNewerMessages {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                Spacer()
            }
            .frame(height: 40)
            .flippedForInvertedList()
            .id("newer-sentinel")
            .onAppear {
                if !isLoadingMoreNewerMessages {
                    let anchorMsgID = messageList.last?.msgID
                    loadMoreNewerMessages {
                        if let anchorID = anchorMsgID,
                           let anchorMessage = self.messageList.first(where: { $0.msgID == anchorID })
                        {
                            let anchorViewId = self.generateMessageViewId(anchorMessage)
                            // Use multiple delayed scrollTo calls to fight against SwiftUI's auto-scroll behavior
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                scrollProxy.scrollTo(anchorViewId, anchor: .top)
                            }
                            DispatchQueue.main.async {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    scrollProxy.scrollTo(anchorViewId, anchor: .top)
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    scrollProxy.scrollTo(anchorViewId, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Only show messages up to visibleMessageCount
        // messageList is [Oldest, ..., Newest]
        // prefix(count) gets [Oldest, ..., Newest_Visible]
        // reversed() gets [Newest_Visible, ..., Oldest]

        ForEach(messageList.reversed()) { message in
            MessageView(
                message: message,
                messageListStore: store,
                conversationID: conversationID,
                audioPlayer: sharedAudioPlayer,
                audioPlaybackManager: audioPlaybackManager,
                onUserClick: onUserClick,
                parentMessageList: messageList
            )
            .environment(\.messageListConfigProtocol, config)
            .environment(\.messageCustomActions, customActions)
            .environment(\.asrDisplayManager, asrDisplayManager)
            .environment(\.translationDisplayManager, translationDisplayManager)
            .environmentObject(menuManager)
            .environmentObject(auxiliaryTextMenuManager)
            .environment(\.locateMessageID, locateMessage?.msgID)
            .id(generateMessageViewId(message))
            .flippedForInvertedList()
            .onAppear {
                handleMessageAppear(message)
                // Track if user is at bottom (newest message is visible)
                if message.msgID == messageList.last?.msgID {
                    isUserAtBottom = true
                }
            }
            .onDisappear {
                // Track if user scrolled away from bottom
                if message.msgID == messageList.last?.msgID {
                    isUserAtBottom = false
                }
            }
        }

        // Older messages at Bottom (Visual Top in Inverted)
        if hasMoreOlderMessage {
            HStack {
                Spacer()
                if isLoadingMoreMessages {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                Spacer()
            }
            .frame(height: 40)
            .flippedForInvertedList()
            .onAppear {
                if !isLoadingMoreMessages {
                    isLoadingMoreMessages = true
                    loadMoreOlderMessages {
                        isLoadingMoreMessages = false
                    }
                }
            }
        }
    }

    private var scrollableMessageListView: some View {
        GeometryReader { geometry in
            let bounds = geometry.frame(in: .global)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 0) {
                            messageListContent(scrollProxy: scrollProxy)
                        }
                    }
                    .frame(minHeight: geometry.size.height, alignment: .bottom)
                }
                .flippedForInvertedList()
                .background(themeState.colors.bgColorOperate)
                .environmentObject(multiSelectManager)
                .environment(\EnvironmentValues.toggleMessageSelection, toggleMessageSelection)
                .environment(\EnvironmentValues.messageListBounds, bounds)
                .onAppear {
                    scrollProxyReference = scrollProxy
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            hideKeyboard()
                            menuManager.hideMenu()
                            auxiliaryTextMenuManager.hideMenu()
                        }
                )

                .onAppear {
                    setupScrollDetection()
                }
                .onReceive(store.messageEventPublisher) { event in
                    handleMessageEvent(event, scrollProxy: scrollProxy)
                }
                .onReceive(keyboardHandler.$keyboardHeight) { keyboardHeight in
                    if keyboardHeight > 0 && isPageVisible && isInitialScrollComplete {
                        scrollToBottom(proxy: scrollProxy, animated: true)
                    }
                }
            }
        }
    }

    private var MessageMenuView: some View {
        MessageActionView(config: config)
            .environmentObject(menuManager)
            .environment(\.asrDisplayManager, asrDisplayManager)
            .environment(\.translationDisplayManager, translationDisplayManager)
            .zIndex(1000)
            .onValueChange(of: menuManager.menuData.isShowing) { isShowing in
                if isShowing {
                    hideKeyboard()
                }
            }
    }

    private func scrollToTargetMessage(proxy: ScrollViewProxy, targetID: String) {
        DispatchQueue.main.async {
            print("MessageListView: Executing scroll to target message")
            proxy.scrollTo(targetID, anchor: .center)
        }
    }

    private func fetchMessagesWithTarget() {
        guard locateMessage?.msgID != nil else {
            fetchMessagesNormal()
            return
        }

        if let locateMessage = locateMessage {
            var option = MessageFetchOption()
            option.message = locateMessage
            option.direction = [.Older, .Newer]
            option.pageCount = 10
            store.fetchMessageList(with: option, completion: { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.isInitialScrollComplete = true
                        print("Failed to fetch messages with target: \(error.code), \(error.message)")
                    }
                }
            })
        } else {
            fetchMessagesNormal()
        }
    }

    private func fetchMessagesNormal() {
        var option = MessageFetchOption()
        option.direction = .Older
        option.pageCount = 20
        store.fetchMessageList(with: option, completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isInitialScrollComplete = true
                    print("Failed to fetch messages: \(error.code), \(error.message)")
                }
            }
        })
    }

    private func initializeStoreIfNeeded() {
        guard !isStoreInitialized else { return }

        messageListStore = MessageListStore.create(conversationID: conversationID, messageListType: .history)
        isStoreInitialized = true
    }

    private func fetchMessages() {
        isLoading = true
        if locateMessage?.msgID != nil {
            fetchMessagesWithTarget()
        } else {
            fetchMessagesNormal()
        }
    }

    private func loadMoreOlderMessages(completion: @escaping () -> Void) {
        store.fetchMoreMessageList(direction: .Older, completion: { result in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                print("Failed to load more messages: \(error.code), \(error.message)")
                completion()
            }
        })
    }

    private func loadMoreNewerMessages(completion: @escaping () -> Void) {
        guard !isLoadingMoreNewerMessages else {
            completion()
            return
        }
        isLoadingMoreNewerMessages = true
        store.fetchMoreMessageList(direction: .Newer, completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoadingMoreNewerMessages = false
                    completion()
                }
            case .failure(let error):
                print("Failed to load more newer messages: \(error.code), \(error.message)")
                DispatchQueue.main.async {
                    self.isLoadingMoreNewerMessages = false
                    completion()
                }
            }
        })
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messageList.last else { return }
        let targetId = generateMessageViewId(lastMessage)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    // In inverted list, use .top anchor to scroll to visual bottom
                    proxy.scrollTo(targetId, anchor: .top)
                }
            } else {
                proxy.scrollTo(targetId, anchor: .top)
            }
        }
    }

    private func scrollToBottomImmediately(proxy: ScrollViewProxy) {
        guard let lastMessage = messageList.last else { return }
        let targetId = generateMessageViewId(lastMessage)
        proxy.scrollTo(targetId, anchor: .bottom)
    }

    private func handleMessageEvent(_ event: MessageEvent, scrollProxy: ScrollViewProxy) {
        switch event {
        case .fetchMessages(let messages, _):
            conversationStore.clearConversationUnreadCount(conversationID, completion: nil)

            // Fetch message reactions if supported
            if config.isSupportReaction && !messages.isEmpty {
                fetchMessageReactions(messages)
            }

            // Only scroll on the very first fetch, use dedicated flag to track
            if !isFirstFetchCompleted {
                isFirstFetchCompleted = true
                if let targetID = locateMessage?.msgID {
                    scrollToTargetMessage(proxy: scrollProxy, targetID: targetID)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isInitialScrollComplete = true
                    }
                } else {
                    // Delay scroll to wait for media messages to complete layout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        scrollToBottomImmediately(proxy: scrollProxy)
                        isInitialScrollComplete = true
                    }
                }
            } else {
                // Subsequent fetches don't scroll
                isInitialScrollComplete = true
            }
        case .fetchMoreMessages(let messages):
            // Fetch message reactions for newly loaded messages
            if config.isSupportReaction && !messages.isEmpty {
                fetchMessageReactions(messages)
            }

            if let anchorId = anchorMessageId {
                DispatchQueue.main.async {
                    withAnimation(.none) {
                        scrollProxy.scrollTo(anchorId, anchor: .top)
                    }
                }
                anchorMessageId = nil
            }
        case .sendMessage:
            if isInitialScrollComplete {
                scrollToBottom(proxy: scrollProxy, animated: true)
            }
        case .recvMessage(let message):
            // Fetch message reactions for new received message
            if config.isSupportReaction {
                fetchMessageReactions([message])
            }

            // Only scroll to bottom if user is already at bottom
            if isInitialScrollComplete && isUserAtBottom {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: scrollProxy, animated: true)
                }
            }
            conversationStore.clearConversationUnreadCount(conversationID, completion: nil)
        case .deleteMessages:
            break
        }
    }

    private func fetchMessageReactions(_ messages: [MessageInfo]) {
        guard config.isSupportReaction else { return }
        store.fetchMessageReactions(messages,
                                    maxUserCountPerReaction: 3,
                                    completion: { result in
                                        switch result {
                                        case .success:
                                            break
                                        case .failure(let error):
                                            print("Failed to fetch message reactions: \(error.code), \(error.message)")
                                        }
                                    })
    }

    private func setupScrollDetection() {}

    /// Generate a unique id for MessageView that includes reactionList info
    /// This ensures SwiftUI re-renders the view when reactions change
    private func generateMessageViewId(_ message: MessageInfo) -> String {
        let reactionSuffix = message.reactionList.map { "\($0.reactionID):\($0.totalUserCount)" }.joined(separator: ",")
        return "\(message.id)_reactions[\(reactionSuffix)]"
    }

    private func handleMessageAppear(_ message: MessageInfo) {
        guard !message.isSelf,
              message.needReadReceipt,
              let msgID = message.msgID,
              !sentReceiptMessageIDs.contains(msgID)
        else {
            return
        }

        pendingReceiptMessageIDs.insert(msgID)
        debounceReadReceipt()
    }

    private func debounceReadReceipt() {
        receiptTimer?.invalidate()
        receiptTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [self] _ in
            self.sendBatchReadReceipts()
        }
    }

    private func sendBatchReadReceipts() {
        let messagesToSend = messageList.filter {
            if let msgID = $0.msgID {
                return pendingReceiptMessageIDs.contains(msgID)
            }
            return false
        }

        guard !messagesToSend.isEmpty else {
            pendingReceiptMessageIDs.removeAll()
            return
        }

        store.sendMessageReadReceipts(messagesToSend) { result in
            if case .success = result {
                for message in messagesToSend {
                    if let msgID = message.msgID {
                        DispatchQueue.main.async {
                            self.sentReceiptMessageIDs.insert(msgID)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.pendingReceiptMessageIDs.removeAll()
            }
        }
    }

    // MARK: - 多选模式管理

    private func enterMultiSelectMode(initialMessage: MessageInfo?) {
        multiSelectManager.enterMultiSelectMode(initialMessageID: initialMessage?.msgID)
        notifyMultiSelectModeChange()
    }

    private func exitMultiSelectMode() {
        multiSelectManager.exitMultiSelectMode()
        onMultiSelectModeChange?(false, nil)
    }

    private func notifyMultiSelectModeChange() {
        let bottomBar = MultiSelectBottomBar(
            selectedCount: multiSelectManager.selectedMessageIDs.count,
            onCancel: { [self] in exitMultiSelectMode() },
            onDelete: { [self] in deleteSelected() },
            onForward: { [self] in
                let selectedMessages = getSelectedMessages()
                if selectedMessages.isEmpty {
                    return
                }
                // Check if any selected message is failed or violation
                let hasUnsupportedMessage = selectedMessages.contains { $0.status == .sendFail || $0.status == .violation }
                if hasUnsupportedMessage {
                    WindowToastManager.shared.show(LocalizedChatString("RelayUnsupportForward"), type: .error, duration: 2)
                    return
                }
                showForwardTypeDialog = true
            }
        )
        onMultiSelectModeChange?(true, AnyView(bottomBar))
    }

    private func toggleMessageSelection(_ message: MessageInfo) {
        guard let msgID = message.msgID else { return }
        multiSelectManager.toggleSelection(messageID: msgID)
        notifyMultiSelectModeChange()
    }

    private func getSelectedMessages() -> [MessageInfo] {
        return messageList.filter { message in
            if let msgID = message.msgID {
                return multiSelectManager.selectedMessageIDs.contains(msgID)
            }
            return false
        }
    }

    private func deleteSelected() {
        let messagesToDelete = getSelectedMessages()
        store.deleteMessages(messagesToDelete) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    exitMultiSelectMode()
                }
            }
        }
    }

    // MARK: - Forward

    private func executeForward(messages: [MessageInfo], to conversationIDs: [String], type: MessageForwardType) {
        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            var mergedForwardInfo: MergedForwardInfo?
            var messagesWithPushInfo = messages

            if type == .merged {
                let title = MessageListHelper.generateMergedTitle(messages: messages, conversationID: conversationID)
                let abstractList = MessageListHelper.generateAbstractList(messages: messages)
                mergedForwardInfo = MergedForwardInfo()
                mergedForwardInfo!.title = title
                mergedForwardInfo!.abstractList = abstractList
                mergedForwardInfo!.compatibleText = "Merged messages"
                mergedForwardInfo?.needReadReceipt = AppBuilderConfig.shared.enableReadReceipt
                // Build a temp merged message to get abstract
                var tempMergedMessage = MessageInfo()
                tempMergedMessage.messageType = .merged
                mergedForwardInfo?.offlinePushInfo = createOfflinePushInfo(
                    conversationID: targetConversationID,
                    message: tempMergedMessage
                )
            } else {
                mergedForwardInfo = nil
                for i in 0 ..< messagesWithPushInfo.count {
                    messagesWithPushInfo[i].needReadReceipt = AppBuilderConfig.shared.enableReadReceipt
                    messagesWithPushInfo[i].offlinePushInfo = createOfflinePushInfo(
                        conversationID: targetConversationID,
                        message: messagesWithPushInfo[i]
                    )
                }
            }

            var forwardOption = MessageForwardOption()
            forwardOption.forwardType = type
            forwardOption.mergedForwardInfo = mergedForwardInfo

            store.forwardMessages(
                messagesWithPushInfo,
                forwardOption: forwardOption,
                conversationID: targetConversationID,
                completion: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            successCount += 1
                        case .failure(let error):
                            failureCount += 1
                            print("Forward to \(targetConversationID) failed: \(error.code), \(error.message)")
                        }

                        if successCount + failureCount == totalCount {
                            if failureCount == 0 {
                                self.showForwardSuccessToast()
                            } else {
                                self.showForwardFailureToast()
                            }
                        }
                    }
                }
            )
        }
    }

    private func forwardAsrTextToConversations(asrText: String, conversationIDs: [String]) {
        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            let messageInputStore = MessageInputStore.create(conversationID: targetConversationID)

            // Build text message
            var message = MessageInfo()
            var messageBody = MessageBody()
            messageBody.text = asrText
            message.messageBody = messageBody
            message.messageType = .text
            message.offlinePushInfo = createOfflinePushInfo(
                conversationID: targetConversationID,
                message: message
            )

            messageInputStore.sendMessage(message) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        print("Failed to send ASR text to \(targetConversationID): \(error.code), \(error.message)")
                    }

                    if successCount + failureCount == totalCount {
                        if failureCount == 0 {
                            self.showForwardSuccessToast()
                        } else {
                            print("ASR text forward partially failed: \(failureCount)/\(totalCount)")
                        }
                        self.showForwardTargetSelector = false
                    }
                }
            }
        }
    }

    private func forwardTranslatedTextToConversations(translatedText: String, conversationIDs: [String]) {
        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            let messageInputStore = MessageInputStore.create(conversationID: targetConversationID)

            // Build text message
            var message = MessageInfo()
            var messageBody = MessageBody()
            messageBody.text = translatedText
            message.messageBody = messageBody
            message.messageType = .text
            message.offlinePushInfo = createOfflinePushInfo(
                conversationID: targetConversationID,
                message: message
            )

            messageInputStore.sendMessage(message) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        print("Failed to send translated text to \(targetConversationID): \(error.code), \(error.message)")
                    }

                    if successCount + failureCount == totalCount {
                        if failureCount == 0 {
                            self.showForwardSuccessToast()
                        } else {
                            print("Translated text forward partially failed: \(failureCount)/\(totalCount)")
                        }
                        self.translatedTextToForward = nil
                        self.showForwardTargetSelector = false
                    }
                }
            }
        }
    }

    private func showForwardSuccessToast() {
        WindowToastManager.shared.show(LocalizedChatString("Have_been_sent"), type: .success, duration: 3)
    }

    private func showForwardFailureToast() {
        WindowToastManager.shared.show(LocalizedChatString("TUIGroupNoteSendFail"), type: .error, duration: 3)
    }

    // MARK: - Offline Push Info

    private func createOfflinePushInfo(
        conversationID: String? = nil,
        message: MessageInfo? = nil
    ) -> OfflinePushInfo {
        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        let selfUserId = loginUserInfo?.userID ?? ""
        let selfName = loginUserInfo?.nickname ?? selfUserId

        let isGroup: Bool
        let groupId: String
        let title: String
        let description: String

        if let conversationID = conversationID {
            isGroup = conversationID.hasPrefix("group_")
            groupId = isGroup ? String(conversationID.dropFirst(6)) : ""

            let chatName = conversationStore.state.value.conversationList
                .first(where: { $0.conversationID == conversationID })?
                .title
                .flatMap { $0.isEmpty ? nil : $0 }

            title = isGroup ? (chatName ?? groupId) : selfName
        } else {
            isGroup = false
            groupId = ""
            title = selfName
        }

        if let message = message {
            description = trimPushDescription(getMessageTypeAbstract(message))
        } else {
            description = ""
        }

        let ext = createOfflinePushExtJson(
            isGroup: isGroup,
            senderId: isGroup ? groupId : selfUserId,
            senderNickName: title,
            faceUrl: loginUserInfo?.avatarURL,
            version: 1,
            action: 1,
            content: description,
            customData: nil
        )

        var pushInfo = OfflinePushInfo()
        pushInfo.title = title
        pushInfo.description = description
        pushInfo.extensionInfo = [
            "ext": ext,
            "AndroidOPPOChannelID": "tuikit",
            "AndroidHuaWeiCategory": "IM",
            "AndroidVIVOCategory": "IM",
            "AndroidHonorImportance": "NORMAL",
            "AndroidMeizuNotifyType": 1,
            "iOSInterruptionLevel": "time-sensitive",
            "enableIOSBackgroundNotification": false
        ]
        return pushInfo
    }

    private func getMessageTypeAbstract(_ message: MessageInfo) -> String {
        switch message.messageType {
        case .text:
            return EmojiManager.shared.createLocalizedStringFromEmojiCodes(message.messageBody?.text ?? "")
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .file:
            return LocalizedChatString("MessageTypeFile")
        case .sound:
            return LocalizedChatString("MessageTypeVoice")
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
        case .merged:
            return LocalizedChatString("MessageTypeMergedHistory")
        default:
            return ""
        }
    }

    private func trimPushDescription(_ text: String, maxLength: Int = 50) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if normalized.count <= maxLength {
            return normalized
        }
        return String(normalized.prefix(maxLength))
    }

    private func createOfflinePushExtJson(
        isGroup: Bool,
        senderId: String,
        senderNickName: String,
        faceUrl: String?,
        version: Int,
        action: Int,
        content: String?,
        customData: String?
    ) -> String {
        var entity: [String: Any] = [
            "sender": senderId,
            "nickname": senderNickName,
            "chatType": isGroup ? 2 : 1,
            "version": version,
            "action": action
        ]
        if let content = content, !content.isEmpty {
            entity["content"] = content
        }
        if let faceUrl = faceUrl {
            entity["faceUrl"] = faceUrl
        }
        if let customData = customData {
            entity["customData"] = customData
        }
        let timPushFeatures: [String: Int] = [
            "fcmPushType": 0,
            "fcmNotificationType": 0
        ]
        let extDict: [String: Any] = [
            "entity": entity,
            "timPushFeatures": timPushFeatures
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: extDict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }
        return "{}"
    }
}

// MARK: - Forward Type Dialog Modifier (iOS 14+ compatible)

private struct ForwardTypeDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onSeparateForward: () -> Void
    let onMergedForward: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "",
            isPresented: $isPresented,
            titleVisibility: .hidden
        ) {
            Button(LocalizedChatString("RelayOneByOneForward")) {
                onSeparateForward()
            }

            Button(LocalizedChatString("RelayCombineForwad")) {
                onMergedForward()
            }

            Button(LocalizedChatString("Cancel"), role: .cancel) {}
        }
    }
}
