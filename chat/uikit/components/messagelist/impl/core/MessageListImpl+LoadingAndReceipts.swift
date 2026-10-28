import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

extension MessageListImpl {
    func filteredMessageList(_ list: [MessageInfo]) -> [MessageInfo] {
        let matchers = config.messageExclusionMatchers
        guard !matchers.isEmpty else { return list }
        return list.filter { message in
            !matchers.contains(where: { $0(message) })
        }
    }

    func mergePlaceholders() {
        let visible = visiblePlaceholders()
        messageList = visible.isEmpty ? baseMessageList : baseMessageList + visible
    }


    private func visiblePlaceholders() -> [MessageInfo] {
        let processing = MessageListPlaceholderStore.shared.placeholdersByConversation[conversationID] ?? []
        guard !processing.isEmpty else { return [] }
        let sentMediaPaths = Set(baseMessageList.compactMap { MessageListPlaceholderStore.localMediaPath(of: $0) })
        guard !sentMediaPaths.isEmpty else { return processing }
        return processing.filter { placeholder in
            guard let mediaPath = MessageListPlaceholderStore.localMediaPath(of: placeholder) else { return true }
            return !sentMediaPaths.contains(mediaPath)
        }
    }

    private func fetchMessagesWithTarget() {
        guard locateMessage?.msgID != nil else {
            fetchMessagesNormal()
            return
        }

        if let locateMessage = locateMessage {
            var option = MessageLoadOption()
            option.cursor = locateMessage
            option.direction = .both
            option.pageCount = 10
            store.loadMessages(option: option, completion: { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if self.messageList.isEmpty {
                            self.isFirstFetchCompleted = true
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.isFirstFetchCompleted = true
                        print("Failed to fetch messages with target: \(error.code), \(error.message)")
                    }
                }
            })
        } else {
            fetchMessagesNormal()
        }
    }

    private func fetchMessagesNormal() {
        var option = MessageLoadOption()
        option.direction = .older
        option.pageCount = 20
        store.loadMessages(option: option, completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoading = false
                    if self.messageList.isEmpty {
                        self.isFirstFetchCompleted = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isFirstFetchCompleted = true
                    print("Failed to fetch messages: \(error.code), \(error.message)")
                }
            }
        })
    }

    func fetchMessages() {
        isLoading = true
        if locateMessage?.msgID != nil {
            fetchMessagesWithTarget()
        } else {
            fetchMessagesNormal()
        }
    }

    func loadMoreOlderMessages(completion: @escaping () -> Void) {
        store.loadOlderMessages(completion: { result in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                print("Failed to load more messages: \(error.code), \(error.message)")
                completion()
            }
        })
    }

    func loadMoreNewerMessages(completion: @escaping () -> Void) {
        guard !isLoadingMoreNewerMessages else {
            completion()
            return
        }
        isLoadingMoreNewerMessages = true
        store.loadNewerMessages(completion: { result in
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

    func handleMessageEvent(_ event: MessageEvent, scrollProxy: ScrollViewProxy) {
        switch event {
        case .onReceiveNewMessage(let message):
            let myID = LoginStore.shared.state.value.loginUserInfo?.userID
            let isAtAll = message.atUserList.contains(MessageInputView.mentionAllUserID)
            let isAtMe = myID.map { message.atUserList.contains($0) } ?? false
            if conversationID.hasPrefix("group_"), !message.isSentBySelf, let sequence = message.sequence,
               isAtAll || isAtMe {
                tongueController.mergeMentionTargets([GroupAtInfo(msgSeq: sequence, atType: isAtAll ? .atAll : .atMe)])
                consumeVisibleMentions()
            }
            tongueController.onNewMessage(message, isLatestVisible: isPageVisible && isUserAtBottom)
            if config.isSupportReaction {
                fetchMessageReactions([message])
            }

            if isPageVisible, isApplicationActive, isFirstFetchCompleted, isUserAtBottom,
               !hasMoreNewerMessage, !isQuoteLocateInFlight, !isMentionLocateInFlight {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard isPageVisible, isApplicationActive, !hasMoreNewerMessage,
                          !isQuoteLocateInFlight, !isMentionLocateInFlight else { return }
                    scrollToBottom(proxy: scrollProxy, animated: true)
                }
            }
            clearUnreadCountIfVisible()
        }
    }

    private func fetchMessageReactions(_ messages: [MessageInfo]) {
        guard config.isSupportReaction else { return }
    }

    func setupScrollDetection() {}

    func generateMessageViewId(_ message: MessageInfo) -> String {
        let reactionSuffix = message.reactionList.map { "\($0.reactionID):\($0.totalUserCount)" }.joined(separator: ",")
        return "\(message.id)_reactions[\(reactionSuffix)]"
    }

    func handleMessageAppear(_ message: MessageInfo) {
        let msgID = message.msgID
        guard !message.isSentBySelf,
              message.needReadReceipt,
              !msgID.isEmpty,
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
            let msgID = $0.msgID
            return !msgID.isEmpty && pendingReceiptMessageIDs.contains(msgID)
        }

        guard !messagesToSend.isEmpty else {
            pendingReceiptMessageIDs.removeAll()
            return
        }

        store.sendMessageReadReceipts(messageList: messagesToSend) { result in
            if case .success = result {
                for message in messagesToSend {
                    let msgID = message.msgID
                    if !msgID.isEmpty {
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
}
