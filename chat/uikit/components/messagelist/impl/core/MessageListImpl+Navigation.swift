import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

private final class MentionConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let completion: (ConversationInfo?) -> Void

    init(completion: @escaping (ConversationInfo?) -> Void) {
        self.completion = completion
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        completion(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        completion(nil)
    }
}

extension MessageListImpl {
    var latestPositionMarker: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { updateLatestContentBottom(geo.frame(in: .global).maxY) }
                        .onChange(of: geo.frame(in: .global).maxY) { updateLatestContentBottom($0) }
                }
            )
    }

    private func updateLatestContentBottom(_ globalMaxY: CGFloat) {
        latestContentBottomGlobalY = globalMaxY
        feedTongueScrollState()
    }

    func updateViewportMetrics(globalFrame: CGRect, height: CGFloat) {
        listViewportGlobalMaxY = globalFrame.maxY
        listViewportHeight = height
        messageListBounds = globalFrame
        feedTongueScrollState()
        consumeVisibleMentions()
    }

    func feedTongueScrollState() {
        let distance = max(0, latestContentBottomGlobalY - listViewportGlobalMaxY)
        tongueController.onScroll(
            distanceFromLatest: distance,
            viewportHeight: listViewportHeight,
            isLatestVisible: isUserAtBottom
        )
    }


    private static let aroundQuotePageCount = 20

    func isQuotedOriginalUnreachable(_ quoteInfo: MessageQuoteInfo) -> Bool {
        if quoteInfo.status == .revoked { return true }
        if quoteInfo.status == .deleted, quoteInfo.messagePayload == nil { return true }
        return false
    }

    func findRawQuoteTarget(msgID: String, quoteInfo: MessageQuoteInfo?) -> MessageInfo? {
        let rawList = store.state.value.messageList
        if !msgID.isEmpty, let hit = rawList.first(where: { $0.msgID == msgID }) {
            return hit
        }
        if let quoteInfo = quoteInfo, quoteInfo.sequence > 0 {
            return rawList.first(where: { $0.sequence == quoteInfo.sequence })
        }
        return nil
    }

    func isMessageExcludedFromDisplay(_ message: MessageInfo) -> Bool {
        if config.messageExclusionMatchers.contains(where: { $0(message) }) { return true }
        guard message.messageType == .custom,
              let callModel = CallMessageParser.parse(message) else { return false }
        return callModel.isExcludeFromHistory
    }

    func showQuoteToast(_ text: String) {
        WindowToastManager.shared.show(text, type: .info, duration: 3)
    }

    func scheduleLocateHighlightExpiry(msgID: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if dynamicLocateMessageID == msgID {
                dynamicLocateMessageID = nil
            }
        }
    }

    func loadMessagesAroundQuoteTarget(msgID: String, quoteInfo: MessageQuoteInfo?, hostReturnMsgID: String?) {
        var cursor = MessageInfo()
        cursor.msgID = msgID
        if let quoteInfo = quoteInfo {
            if conversationID.hasPrefix("group_") {
                cursor.sequence = quoteInfo.sequence
                cursor.timestamp = quoteInfo.timestamp
            } else {
                cursor.timestamp = quoteInfo.timestamp
            }
        }
        var option = MessageLoadOption()
        option.cursor = cursor
        option.direction = .both
        option.pageCount = Self.aroundQuotePageCount
        isQuoteLocateInFlight = true
        store.loadMessages(option: option) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.handleQuoteAroundLoadCompleted(msgID: msgID, quoteInfo: quoteInfo, hostReturnMsgID: hostReturnMsgID)
                case .failure(let error):
                    self.isQuoteLocateInFlight = false
                    print(">>>>> loadMessagesAroundQuoteTarget failed: \(error.code), \(error.message)")
                    self.showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
                }
            }
        }
    }

    private func handleQuoteAroundLoadCompleted(msgID: String, quoteInfo: MessageQuoteInfo?, hostReturnMsgID: String?) {
        guard let rawTarget = findRawQuoteTarget(msgID: msgID, quoteInfo: quoteInfo) else {
            isQuoteLocateInFlight = false
            showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
            return
        }
        if isMessageExcludedFromDisplay(rawTarget) {
            isQuoteLocateInFlight = false
            showQuoteToast(LocalizedChatString("QuoteOriginalFiltered"))
            return
        }
        if let hostReturnMsgID = hostReturnMsgID, !hostReturnMsgID.isEmpty {
            tongueController.onQuoteNavigated(returnMessageID: hostReturnMsgID)
        }
        dynamicLocateMessageID = rawTarget.msgID
        scheduleLocateHighlightExpiry(msgID: rawTarget.msgID)
        pendingQuoteLocateMsgID = rawTarget.msgID
        performPendingQuoteLocateScroll()
        scheduleQuoteVisibilityCheck()
    }

    func performPendingQuoteLocateScroll() {
        guard let pendingID = pendingQuoteLocateMsgID,
              let target = messageList.first(where: { $0.msgID == pendingID }),
              let proxy = scrollProxyReference else { return }
        pendingQuoteLocateMsgID = nil
        let targetViewId = generateMessageViewId(target)
        // 整窗消息插入时单次滚动可能被重布局丢弃，需无动画重试定位。
        let mentionSequence = pendingMentionLocateSequence
        DispatchQueue.main.async {
            guard isPageVisible else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(targetViewId, anchor: .center)
            }
            if let sequence = mentionSequence, target.sequence == sequence,
               pendingMentionLocateSequence == sequence {
                pendingMentionLocateSequence = nil
                tongueController.consume(.mention(sequence: sequence, isAtAll: false))
                clearUnreadCountIfVisible()
            }
        }
        for delay in [0.1, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(targetViewId, anchor: .center)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isQuoteLocateInFlight = false
        }
    }

    private func loadMessagesAroundQuoteReturn(_ message: MessageInfo) {
        var option = MessageLoadOption()
        option.cursor = message
        option.direction = .both
        option.pageCount = Self.aroundQuotePageCount
        isQuoteLocateInFlight = true
        store.loadMessages(option: option) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.performPendingQuoteLocateScroll()
                case .failure(let error):
                    self.isQuoteLocateInFlight = false
                    self.pendingQuoteLocateMsgID = nil
                    print(">>>>> loadMessagesAroundQuoteReturn failed: \(error.code), \(error.message)")
                }
            }
        }
    }

    private func reloadLatestMessages() {
        var option = MessageLoadOption()
        option.direction = .older
        option.pageCount = 20
        store.loadMessages(option: option) { _ in }
    }

    func scrollToBottomWithRetries(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            self.scrollToBottomImmediately(proxy: proxy)
        }
        for delay in [0.1, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.scrollToBottomImmediately(proxy: proxy)
            }
        }
    }

    func scheduleQuoteVisibilityCheck() {
        quoteCheckWorkItem?.cancel()
        let item = DispatchWorkItem {
            if let returnID = tongueController.currentBackToQuoteReturnID,
               fullyVisibleMessageIDs.contains(returnID) {
                tongueController.onReturnMessageVisible()
            }
        }
        quoteCheckWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    var MessageMenuView: some View {
        MessageActionView(config: config)
            .environmentObject(menuManager)
            .environment(\.messageListBounds, messageListBounds)
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

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messageList.last else { return }
        let targetId = generateMessageViewId(lastMessage)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
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

    func handleTongueTap(_ entry: MessageListFloatingEntry) {
        guard let proxy = scrollProxyReference else { return }
        switch entry {
        case .backToLatest:
            if hasMoreNewerMessage {
                scrollToLatestAfterReload = true
                reloadLatestMessages()
            } else {
                scrollToBottom(proxy: proxy, animated: true)
            }
        case .newMessages(_, let firstMessageID):
            if let target = messageList.first(where: { $0.msgID == firstMessageID }) {
                withAnimation { proxy.scrollTo(generateMessageViewId(target), anchor: .center) }
            } else {
                scrollToBottom(proxy: proxy, animated: true)
            }
        case .backToQuote(let returnMessageID):
            if let target = messageList.first(where: { $0.msgID == returnMessageID }) {
                withAnimation { proxy.scrollTo(generateMessageViewId(target), anchor: .center) }
            } else if let host = quoteReturnMessage, host.msgID == returnMessageID {
                pendingQuoteLocateMsgID = returnMessageID
                loadMessagesAroundQuoteReturn(host)
            }
        case .mention(let sequence, _):
            guard isFirstFetchCompleted, !isQuoteLocateInFlight, !isMentionLocateInFlight,
                  !isLoadingMoreMessages, !isLoadingMoreNewerMessages else { return }
            if let target = messageList.first(where: { $0.sequence == sequence }) {
                dynamicLocateMessageID = target.msgID
                scheduleLocateHighlightExpiry(msgID: target.msgID)
                pendingMentionLocateSequence = sequence
                pendingQuoteLocateMsgID = target.msgID
                isQuoteLocateInFlight = true
                performPendingQuoteLocateScroll()
            } else {
                loadMessagesAroundMention(sequence: sequence)
            }
            return
        }
        tongueController.consume(entry)
    }

    private func loadMessagesAroundMention(sequence: Int64) {
        var cursor = MessageInfo()
        cursor.sequence = sequence
        var option = MessageLoadOption()
        option.cursor = cursor
        option.direction = .both
        option.pageCount = Self.aroundQuotePageCount
        isMentionLocateInFlight = true
        isQuoteLocateInFlight = true
        store.loadMessages(option: option) { result in
            DispatchQueue.main.async {
                self.isMentionLocateInFlight = false
                guard self.isPageVisible else {
                    self.isQuoteLocateInFlight = false
                    return
                }
                switch result {
                case .success:
                    guard let target = self.store.state.value.messageList.first(where: { $0.sequence == sequence }),
                          !self.isMessageExcludedFromDisplay(target) else {
                        self.isQuoteLocateInFlight = false
                        self.showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
                        return
                    }
                    self.dynamicLocateMessageID = target.msgID
                    self.scheduleLocateHighlightExpiry(msgID: target.msgID)
                    self.pendingMentionLocateSequence = sequence
                    self.pendingQuoteLocateMsgID = target.msgID
                    self.performPendingQuoteLocateScroll()
                case .failure:
                    self.isQuoteLocateInFlight = false
                    self.showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
                }
            }
        }
    }

    func handleListenFromHere(_ message: MessageInfo) {
        let startIndex = messageList.firstIndex(where: { $0.msgID == message.msgID })
        guard let startIndex else { return }
        let slice = Array(messageList[startIndex...])
        let plan = ListenPlanBuilder.build(messages: slice)
        listenController.start(plan: plan)
    }

    func refreshMentionTarget() {
        guard conversationID.hasPrefix("group_") else { return }
        let conversation = conversationStore.state.value.conversationList.first(where: { $0.conversationID == conversationID })
        tongueController.mergeMentionTargets(conversation?.groupAtInfoList ?? [])
        consumeVisibleMentions()
    }

    func loadInitialMentionTargets() {
        guard conversationID.hasPrefix("group_") else {
            hasResolvedInitialMentions = true
            clearUnreadCountIfVisible()
            return
        }
        guard !isLoadingMentionInfo else { return }
        isLoadingMentionInfo = true
        conversationStore.getConversationInfo(conversationID: conversationID, completion: MentionConversationInfoHandler { conversation in
            DispatchQueue.main.async {
                self.isLoadingMentionInfo = false
                self.tongueController.mergeMentionTargets(conversation?.groupAtInfoList ?? [])
                self.hasResolvedInitialMentions = true
                self.consumeVisibleMentions()
                self.clearUnreadCountIfVisible()
            }
        })
    }

    func clearUnreadCountIfVisible() {
        guard isPageVisible, isApplicationActive, isFirstFetchCompleted, hasResolvedInitialMentions,
              !isClearingUnreadCount else { return }
        isClearingUnreadCount = true
        let currentStore = conversationStore
        currentStore.clearConversationUnreadCount(conversationID: conversationID) { result in
            DispatchQueue.main.async {
                self.isClearingUnreadCount = false
                switch result {
                case .success:
                    NotificationCenter.default.post(name: .chatConversationUnreadDidClear, object: nil,
                                                    userInfo: ["conversationID": self.conversationID])
                    currentStore.markConversation(conversationIDList: [self.conversationID], markType: .unread, enable: false) { result in
                        DispatchQueue.main.async {
                            if case .failure(let error) = result {
                                print(">>>>> clearConversationUnreadMark failed: \(error.code), \(error.message)")
                            }
                            NotificationCenter.default.post(name: .chatConversationUnreadDidClear, object: nil,
                                                            userInfo: ["conversationID": self.conversationID])
                        }
                    }
                case .failure(let error):
                    print(">>>>> clearConversationUnreadCount failed: \(error.code), \(error.message)")
                }
            }
        }
    }

    func updateMentionMessageFrame(_ message: MessageInfo, frame: CGRect) {
        guard let sequence = message.sequence, sequence > 0 else { return }
        mentionMessageFrames[sequence] = frame
        consumeVisibleMentions()
    }

    func consumeVisibleMentions() {
        guard isPageVisible, isApplicationActive, isFirstFetchCompleted, listViewportHeight > 0 else { return }
        for (sequence, frame) in mentionMessageFrames {
            tongueController.onMentionMessageFrameChanged(sequence: sequence, frame: frame, viewport: messageListBounds)
        }
    }
}
