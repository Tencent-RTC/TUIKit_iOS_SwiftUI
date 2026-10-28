import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

private struct MessageCellGlobalFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct MessageListImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State var isApplicationActive = UIApplication.shared.applicationState == .active
    @StateObject var menuManager = MessageMenuManager()
    @StateObject private var auxiliaryTextMenuManager = AuxiliaryTextMenuManager()
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @StateObject var multiSelectManager = MultiSelectManager()
    @StateObject var asrDisplayManager = AsrDisplayManager()
    @StateObject var translationDisplayManager = TranslationDisplayManager()
    @State var isLoading = false
    @State var isLoadingMoreMessages = false
    @State var isLoadingMoreNewerMessages = false
    @State private var anchorMessageId: String? = nil
    @State var messageList: [MessageInfo] = []
    @State var baseMessageList: [MessageInfo] = []
    @State private var hasMoreOlderMessage: Bool = false
    @State var hasMoreNewerMessage: Bool = false
    @StateObject private var storeHolder: MessageListStoreHolder
    @State var isPageVisible = false
    @State private var hasInitialLoaded = false
    @State private var messageCountOnDisappear: Int = 0
    @State var scrollProxyReference: ScrollViewProxy? = nil
    @State var dynamicLocateMessageID: String? = nil
    @State var pendingQuoteLocateMsgID: String? = nil
    // 引用定位期间抑制自动补拉，避免覆盖待执行的跳转。
    @State var isQuoteLocateInFlight = false
    @State var quoteReturnMessage: MessageInfo? = nil
    @State var scrollToLatestAfterReload = false
    @State var fullyVisibleMessageIDs: Set<String> = []
    @State var mentionMessageFrames: [Int64: CGRect] = [:]
    @State var hasResolvedInitialMentions = false
    @State var isLoadingMentionInfo = false
    @State var isMentionLocateInFlight = false
    @State var pendingMentionLocateSequence: Int64?
    @State var isClearingUnreadCount = false
    @State var quoteCheckWorkItem: DispatchWorkItem? = nil
    @StateObject var tongueController = MessageListFloatingEntryController()
    @StateObject private var joinCallBannerController = MessageListJoinCallBannerController()
    @StateObject var listenController = ListenFromHereController()
    @State var isFirstFetchCompleted = false
    @State var isUserAtBottom = true
    @State var latestContentBottomGlobalY: CGFloat = 0
    @State var listViewportGlobalMaxY: CGFloat = 0
    @State var listViewportHeight: CGFloat = 0
    @State var pendingReceiptMessageIDs: Set<String> = []
    @State var sentReceiptMessageIDs: Set<String> = []
    @State var receiptTimer: Timer?
    @StateObject private var imageViewerManager: ImageViewerManager

    @Environment(\.openReadReceiptDetail) private var openReadReceiptDetail
    @State private var showReadReceiptView: Bool = false
    @State private var readReceiptMessage: MessageInfo? = nil
    @State private var readReceiptStore: MessageActionStore? = nil
    @State var reactionFullPickerMessage: MessageInfo? = nil
    @State private var chatBackgroundURI: String? = nil
    @State private var chatBackgroundImage: UIImage? = nil

    @State var showForwardTargetSelector = false
    @State var forwardType: MessageForwardType = .separate
    @State var messagesForForward: [MessageInfo] = []
    @State private var asrTextToForward: String? = nil
    @State var translatedTextToForward: String? = nil

    @State var messageListBounds: CGRect = .zero

    let config: MessageListConfigProtocol & MessageActionConfigProtocol
    private let customActions: [MessageCustomAction]

    let conversationID: String
    private let onUserClick: ((String) -> Void)?
    let onMultiSelectModeChange: ((Bool) -> Void)?
    let locateMessage: MessageInfo?
    @State var conversationStore: ConversationListStore

    init(
        conversationID: String,
        config: (MessageListConfigProtocol & MessageActionConfigProtocol)? = nil,
        locateMessage: MessageInfo? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMultiSelectModeChange: ((Bool) -> Void)? = nil,
        customActions: [MessageCustomAction] = []
    ) {
        self.conversationID = conversationID
        self.locateMessage = locateMessage
        self.onUserClick = onUserClick
        self.onMultiSelectModeChange = onMultiSelectModeChange
        self.customActions = customActions
        self.conversationStore = ConversationListStore.create()
        self.config = config ?? ChatMessageListConfig()
        _tongueController = StateObject(wrappedValue: MessageListFloatingEntryController(conversationID: conversationID))
        _storeHolder = StateObject(wrappedValue: MessageListStoreHolder(conversationID: conversationID))
        _imageViewerManager = StateObject(wrappedValue: ImageViewerManager(conversationID: conversationID, currentMessage: MessageInfo()))
    }

    var store: MessageListStore { storeHolder.store }

    private var messageTimeHeaders: [String: String] {
        let list = messageList
        var headers: [String: String] = [:]
        headers.reserveCapacity(list.count)
        for (index, message) in list.enumerated() {
            if let header = MessageView.getMessageTimeString(for: message, at: index, messageList: list) {
                headers[message.msgID] = header
            }
        }
        return headers
    }

    var body: some View {
        VStack(spacing: 0) {
            messageListContentView
            if multiSelectManager.isMultiSelectMode {
                multiSelectBottomBar
            }
        }
    }

    private var messageListContentView: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let bannerState = joinCallBannerController.state {
                    MessageListJoinCallBannerView(state: bannerState)
                        .environmentObject(themeState)
                }
                scrollableMessageListView
            }
            .animation(.easeOut(duration: 0.22), value: joinCallBannerController.state != nil)
            if let entry = tongueController.currentEntry {
                MessageTongueView(entry: entry) {
                    handleTongueTap(entry)
                }
                .environmentObject(themeState)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.bottom, CGFloat(SpacingScheme.bubbleSpacing))
                .zIndex(900)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if listenController.state.isActive {
                GeometryReader { geo in
                    VStack {
                        HStack {
                            Spacer()
                            ListenPlaybackBar(controller: listenController)
                                .environmentObject(themeState)
                        }
                        .padding(.trailing, CGFloat(SpacingScheme.smallSpacing))
                        Spacer()
                    }
                    .padding(.top, min(max(geo.size.height * 0.4 - 18, CGFloat(SpacingScheme.smallSpacing)), max(geo.size.height - 36 - CGFloat(SpacingScheme.smallSpacing), CGFloat(SpacingScheme.smallSpacing))))
                }
                .zIndex(950)
                .transition(.identity)
            }
            MessageMenuView
            AuxiliaryTextMenuView(menuManager: auxiliaryTextMenuManager)
                .environmentObject(themeState)
                .zIndex(1001)
            if let pickerMessage = reactionFullPickerMessage {
                ReactionFullEmojiPickerSheet(
                    message: pickerMessage,
                    onSelectEmoji: { emoji in
                        handleReactionFullPickerSelect(emoji, message: pickerMessage)
                    },
                    onDismiss: {
                        reactionFullPickerMessage = nil
                    }
                )
                .environmentObject(themeState)
                .zIndex(1002)
            }
        }
        .background(themeState.colors.bgColorOperate)
        .fullScreenCover(isPresented: $imageViewerManager.isShowingImageViewer) {
            imageViewerManager.imageViewerContent()
        }
        .onAppear {
            isApplicationActive = UIApplication.shared.applicationState == .active
            isPageVisible = true
            refreshMentionTarget()
            loadInitialMentionTargets()
            joinCallBannerController.bind(conversationID: conversationID)

            let storeHasMessages = store.state.value.messageList.count > 0

            if !hasInitialLoaded && !storeHasMessages {
                fetchMessages()
                hasInitialLoaded = true
            } else if storeHasMessages {
                hasInitialLoaded = true
                isFirstFetchCompleted = true
            } else if messageList.count > messageCountOnDisappear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let proxy = scrollProxyReference {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
        .onDisappear {
            isPageVisible = false
            messageCountOnDisappear = messageList.count
            listenController.stop()
            joinCallBannerController.release()
        }
        .onChange(of: isUserAtBottom) { _ in
            feedTongueScrollState()
        }
        .onChange(of: isFirstFetchCompleted) { completed in
            guard completed else { return }
            clearUnreadCountIfVisible()
            consumeVisibleMentions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isApplicationActive = true
            guard isPageVisible else { return }
            loadInitialMentionTargets()
            clearUnreadCountIfVisible()
            consumeVisibleMentions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isApplicationActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: MessageInputView.didInteractNotification)) { _ in
            guard isPageVisible, isFirstFetchCompleted, !isUserAtBottom else { return }
            if let proxy = scrollProxyReference {
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
        .onReceive(conversationStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList)).dropFirst()) { _ in
            refreshMentionTarget()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("listenFromHereNotification"))) { notification in
            if let message = notification.userInfo?["message"] as? MessageInfo {
                handleListenFromHere(message)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceInputRecordStart)) { _ in
            listenController.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatVideoPlaybackDidStart)) { _ in
            sharedAudioPlayer.stop()
            audioPlaybackManager.clearCurrentPlayingMsgID()
            listenController.stop()
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList)).dropFirst()) { newList in
            let isFirstBatch = !isFirstFetchCompleted && !newList.isEmpty
            if isFirstBatch {
                // 首批消息禁用插入动画，避免倒置列表反向滑入。
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.baseMessageList = filteredMessageList(newList)
                    self.mergePlaceholders()
                }
            } else {
                let isTailAppend = newList.count > baseMessageList.count
                    && zip(newList, baseMessageList).allSatisfy { $0.msgID == $1.msgID }
                if isTailAppend, !isUserAtBottom, !isQuoteLocateInFlight, !scrollToLatestAfterReload, pendingQuoteLocateMsgID == nil {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.baseMessageList = filteredMessageList(newList)
                        self.mergePlaceholders()
                    }
                } else {
                    self.baseMessageList = filteredMessageList(newList)
                    self.mergePlaceholders()
                }
            }

            for message in newList where message.status == .revoked {
                tongueController.onMessageRecalled(msgID: message.msgID)
            }

            if newList.isEmpty {
                isUserAtBottom = true
                if isFirstFetchCompleted {
                    tongueController.reset()
                    mentionMessageFrames.removeAll()
                }
            }

            performPendingQuoteLocateScroll()

            if scrollToLatestAfterReload, !newList.isEmpty, !store.state.value.hasNewerMessages {
                scrollToLatestAfterReload = false
                if let proxy = scrollProxyReference {
                    scrollToBottomWithRetries(proxy: proxy)
                }
            }

            guard isFirstBatch else { return }
            isFirstFetchCompleted = true
            clearUnreadCountIfVisible()
            consumeVisibleMentions()

            if let proxy = scrollProxyReference, let targetMsg = locateMessage,
               let target = messageList.first(where: { $0.msgID == targetMsg.msgID }) {
                let targetViewId = generateMessageViewId(target)
                DispatchQueue.main.async {
                    proxy.scrollTo(targetViewId, anchor: .center)
                }
            }
        }
        .onReceive(MessageListPlaceholderStore.shared.$placeholdersByConversation) { _ in
            self.mergePlaceholders()
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasOlderMessages)).dropFirst()) { hasMoreOlderMessage in
            self.hasMoreOlderMessage = hasMoreOlderMessage
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasNewerMessages)).dropFirst()) { hasMoreNewerMessage in
            self.hasMoreNewerMessage = hasMoreNewerMessage
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("messageReactionToggle"))) { notification in
            guard let message = notification.userInfo?["message"] as? MessageInfo,
                  let reactionID = notification.userInfo?["reactionID"] as? String else { return }
            toggleReactionOptimistic(message: message, reactionID: reactionID)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("kShowMessageReadReceiptNotification"))) { notification in
            if let message = notification.userInfo?["message"] as? MessageInfo,
               let store = notification.userInfo?["messageActionStore"] as? MessageActionStore
            {
                if let open = openReadReceiptDetail {
                    open(message, store)
                } else {
                    readReceiptMessage = message
                    readReceiptStore = store
                    showReadReceiptView = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("enterMultiSelectMode"))) { notification in
            let message = notification.userInfo?["initialMessage"] as? MessageInfo
            enterMultiSelectMode(initialMessage: message)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("locateMessageNotification"))) { notification in
            guard let msgID = notification.userInfo?["msgID"] as? String, !msgID.isEmpty else { return }
            let quoteInfo = notification.userInfo?["quoteInfo"] as? MessageQuoteInfo
            let returnMsgID = notification.userInfo?["returnMsgID"] as? String
            if let returnMsgID = returnMsgID, !returnMsgID.isEmpty {
                quoteReturnMessage = messageList.first(where: { $0.msgID == returnMsgID })
            }

            if let quoteInfo = quoteInfo, isQuotedOriginalUnreachable(quoteInfo) {
                showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
                return
            }

            let targetVisible = fullyVisibleMessageIDs.contains(msgID)
            if let rawTarget = findRawQuoteTarget(msgID: msgID, quoteInfo: quoteInfo) {
                if isMessageExcludedFromDisplay(rawTarget) {
                    showQuoteToast(LocalizedChatString("QuoteOriginalFiltered"))
                    return
                }
                if let returnMsgID = returnMsgID, !returnMsgID.isEmpty, !targetVisible {
                    tongueController.onQuoteNavigated(returnMessageID: returnMsgID)
                    scheduleQuoteVisibilityCheck()
                }
                dynamicLocateMessageID = msgID
                scheduleLocateHighlightExpiry(msgID: msgID)
                if !targetVisible, let proxy = scrollProxyReference,
                   let target = messageList.first(where: { $0.msgID == rawTarget.msgID }) {
                    let targetViewId = generateMessageViewId(target)
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(targetViewId, anchor: .center)
                        }
                    }
                }
                return
            }

            loadMessagesAroundQuoteTarget(msgID: msgID, quoteInfo: quoteInfo, hostReturnMsgID: returnMsgID)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("exitMultiSelectMode"))) { _ in
            exitMultiSelectMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("showReactionFullEmojiPicker"))) { notification in
            if let message = notification.userInfo?["message"] as? MessageInfo {
                reactionFullPickerMessage = message
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ChatBackgroundStore.didChangeNotification)) { notification in
            if let changedID = notification.userInfo?[ChatBackgroundStore.conversationIDUserInfoKey] as? String, changedID == conversationID {
                loadChatBackground()
            }
        }
        .onAppear {
            loadChatBackground()
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
                MessageReadReceiptView(
                    messageActionStore: actionStore,
                    message: message,
                    embedInNavigationView: true
                )
            }
        }
        .background(
            NavigationLink(
                destination: ForwardTargetSelector(
                    onConfirm: { conversationIDs in
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
                .environmentObject(themeState),
                isActive: $showForwardTargetSelector
            ) { EmptyView() }
            .hidden()
        )
    }

    @ViewBuilder
    private func messageListContent(scrollProxy: ScrollViewProxy) -> some View {
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
                if !isLoadingMoreNewerMessages && !isQuoteLocateInFlight {
                    let anchorMsgID = messageList.last?.msgID
                    loadMoreNewerMessages {
                        guard self.isPageVisible, !self.isQuoteLocateInFlight, !self.isMentionLocateInFlight else { return }
                        if let anchorID = anchorMsgID,
                           let anchorMessage = self.messageList.first(where: { $0.msgID == anchorID })
                        {
                            let anchorViewId = self.generateMessageViewId(anchorMessage)
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                scrollProxy.scrollTo(anchorViewId, anchor: .top)
                            }
                            DispatchQueue.main.async {
                                guard self.isPageVisible, !self.isQuoteLocateInFlight, !self.isMentionLocateInFlight else { return }
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    scrollProxy.scrollTo(anchorViewId, anchor: .top)
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard self.isPageVisible, !self.isQuoteLocateInFlight, !self.isMentionLocateInFlight else { return }
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


        let timeHeaders = messageTimeHeaders
        ForEach(messageList.reversed()) { message in
            MessageView(
                message: message,
                messageListStore: store,
                conversationID: conversationID,
                audioPlayer: sharedAudioPlayer,
                audioPlaybackManager: audioPlaybackManager,
                onUserClick: onUserClick,
                parentMessageList: messageList,
                imageViewerManager: imageViewerManager,
                precomputedTimeHeader: .some(timeHeaders[message.msgID])
            )
            .environment(\.messageListConfigProtocol, config)
            .environment(\.messageCustomActions, customActions)
            .environment(\.asrDisplayManager, asrDisplayManager)
            .environment(\.translationDisplayManager, translationDisplayManager)
            .environmentObject(menuManager)
            .environmentObject(auxiliaryTextMenuManager)
            .environment(\.locateMessageID, locateMessage?.msgID ?? dynamicLocateMessageID)
            .id(generateMessageViewId(message))
            .flippedForInvertedList()
            .background(
                GeometryReader { cellGeometry in
                    let frame = cellGeometry.frame(in: .global)
                    Color.clear.preference(
                        key: MessageCellGlobalFrameKey.self,
                        value: [message.msgID: frame]
                    )
                    .onAppear { updateMentionMessageFrame(message, frame: frame) }
                    .onChange(of: frame) { updateMentionMessageFrame(message, frame: $0) }
                    .onDisappear {
                        if let sequence = message.sequence {
                            mentionMessageFrames.removeValue(forKey: sequence)
                        }
                    }
                }
            )
            .onAppear {
                handleMessageAppear(message)
                if message.msgID == messageList.last?.msgID {
                    isUserAtBottom = true
                }
            }
            .onDisappear {
                if message.msgID == messageList.last?.msgID {
                    isUserAtBottom = false
                }
            }
        }

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
                        // 底部标记须在非懒加载容器，避免离屏后停止更新距最新消息的距离。
                        latestPositionMarker
                        LazyVStack(spacing: 0) {
                            messageListContent(scrollProxy: scrollProxy)
                        }
                    }
                    .frame(minHeight: geometry.size.height, alignment: .bottom)
                }
                .flippedForInvertedList()
                .background(
                    ZStack {
                        themeState.colors.bgColorOperate
                        if let background = config.background {
                            configuredBackground(background)
                        } else if let image = chatBackgroundImage {
                            // 背景按容器实时尺寸裁剪并禁用触摸，避免覆盖导航与输入控件。
                            GeometryReader { bgGeo in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: bgGeo.size.width, height: bgGeo.size.height)
                                    .clipped()
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .clipped()
                )
                .environmentObject(multiSelectManager)
                .environment(\EnvironmentValues.toggleMessageSelection, toggleMessageSelection)
                .environment(\EnvironmentValues.messageListBounds, bounds)
                .onAppear {
                    scrollProxyReference = scrollProxy
                    updateViewportMetrics(globalFrame: bounds, height: geometry.size.height)
                }
                .onChange(of: bounds) { updateViewportMetrics(globalFrame: $0, height: geometry.size.height) }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            if let openedAt = menuManager.lastMenuOpenTime, Date().timeIntervalSince(openedAt) < 0.25 {
                                return
                            }
                            hideKeyboard()
                            menuManager.hideMenu()
                            auxiliaryTextMenuManager.hideMenu()
                            listenController.isExpanded = false
                            NotificationCenter.default.post(name: NSNotification.Name("messageListBlankAreaClickNotification"), object: nil)
                        }
                )

                .onAppear {
                    setupScrollDetection()
                }
                .onReceive(store.messageEventPublisher) { event in
                    handleMessageEvent(event, scrollProxy: scrollProxy)
                }
                // 倒置列表随键盘缩小自动贴底，不再并发 scrollTo 以免闪动。
                .onPreferenceChange(MessageCellGlobalFrameKey.self) { frames in
                    let tolerant = bounds.insetBy(dx: -1, dy: -1)
                    let fullyVisible = Set(frames.filter { tolerant.contains($0.value) }.map(\.key))
                    if fullyVisible != fullyVisibleMessageIDs {
                        fullyVisibleMessageIDs = fullyVisible
                    }
                }
                .onValueChange(of: fullyVisibleMessageIDs) { _ in
                    if tongueController.currentBackToQuoteReturnID != nil {
                        scheduleQuoteVisibilityCheck()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func configuredBackground(_ background: MessageListBackground) -> some View {
        switch background {
        case .color(let color):
            Color(color)
        case .gradient(let colors, let startPoint, let endPoint):
            LinearGradient(
                colors: colors.map { Color($0) },
                startPoint: UnitPoint(x: startPoint.x, y: startPoint.y),
                endPoint: UnitPoint(x: endPoint.x, y: endPoint.y)
            )
        case .image(let image):
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .allowsHitTesting(false)
        }
    }

    private func loadChatBackground() {
        let uri = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID)
        guard uri != chatBackgroundURI else { return }
        chatBackgroundURI = uri
        guard let uri, let url = URL(string: uri) else {
            chatBackgroundImage = nil
            return
        }
        KingfisherManager.shared.retrieveImage(with: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let value):
                    chatBackgroundImage = value.image
                case .failure:
                    chatBackgroundImage = nil
                }
            }
        }
    }
}

// 通过 StateObject 稳定 Store 生命周期，避免重复注册或过早释放监听。
private final class MessageListStoreHolder: ObservableObject {
    let store: MessageListStore

    init(conversationID: String) {
        self.store = MessageListStore.create(conversationID: conversationID)
    }
}
