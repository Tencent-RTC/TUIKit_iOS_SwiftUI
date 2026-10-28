import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

extension MessageListImpl {
    func enterMultiSelectMode(initialMessage: MessageInfo?) {
        multiSelectManager.enterMultiSelectMode(initialMessageID: initialMessage?.msgID)
        notifyMultiSelectModeChange()
    }

    func exitMultiSelectMode() {
        multiSelectManager.exitMultiSelectMode()
        onMultiSelectModeChange?(false)
    }

    var multiSelectBottomBar: some View {
        MultiSelectBottomBar(
            selectedCount: multiSelectManager.selectedMessageIDs.count,
            onForwardSeparate: { [self] in forwardSelected(type: .separate) },
            onForwardMerge: { [self] in forwardSelected(type: .merged) },
            onDelete: { [self] in deleteSelected() }
        )
    }

    private func notifyMultiSelectModeChange() {
        onMultiSelectModeChange?(multiSelectManager.isMultiSelectMode)
    }

    private func forwardSelected(type: MessageForwardType) {
        let selectedMessages = getSelectedMessages()
        if selectedMessages.isEmpty {
            return
        }
        let hasUnsupportedMessage = selectedMessages.contains { $0.status != .sendSuccess }
        if hasUnsupportedMessage {
            WindowToastManager.shared.show(LocalizedChatString("RelayUnsupportForward"), type: .error, duration: 2)
            return
        }
        if type == .separate && selectedMessages.count > 30 {
            WindowToastManager.shared.show(LocalizedChatString("RelayOneByOnyOverLimit"), type: .error, duration: 2)
            return
        }
        forwardType = type
        messagesForForward = selectedMessages
        showForwardTargetSelector = true
    }

    func toggleMessageSelection(_ message: MessageInfo) {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return }
        multiSelectManager.toggleSelection(messageID: msgID)
        notifyMultiSelectModeChange()
    }

    private func getSelectedMessages() -> [MessageInfo] {
        return messageList.filter { message in
            let msgID = message.msgID
            return !msgID.isEmpty && multiSelectManager.selectedMessageIDs.contains(msgID)
        }
    }

    func handleReactionFullPickerSelect(_ emoji: EmojiData, message: MessageInfo) {
        guard let emojiName = emoji.name else { return }
        let hasReacted = message.reactionList.contains { $0.reactionID == emojiName && $0.reactedByMyself }
        if !hasReacted {
            EmojiManager.shared.addRecentEmoji(emoji, groupID: EmojiManager.shared.reactionGroupID())
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("messageReactionToggle"),
            object: nil,
            userInfo: ["message": message, "reactionID": emojiName]
        )
        reactionFullPickerMessage = nil
    }


    func toggleReactionOptimistic(message: MessageInfo, reactionID: String) {
        guard !reactionID.isEmpty, !message.msgID.isEmpty else { return }
        guard let index = baseMessageList.firstIndex(where: { $0.msgID == message.msgID }) else { return }
        let current = baseMessageList[index]
        let isAdd = !(current.reactionList.first(where: { $0.reactionID == reactionID })?.reactedByMyself ?? false)

        let snapshot = current.reactionList
        var optimistic = current
        optimistic.reactionList = Self.makeOptimisticReactionList(from: current.reactionList, reactionID: reactionID, add: isAdd)
        baseMessageList[index] = optimistic
        mergePlaceholders()

        let actionStore = MessageActionStore.create(message: current)
        let completion: (Result<Void, ErrorInfo>) -> Void = { result in
            if case .failure = result {
                DispatchQueue.main.async {
                    guard let idx = baseMessageList.firstIndex(where: { $0.msgID == message.msgID }) else { return }
                    baseMessageList[idx].reactionList = snapshot
                    mergePlaceholders()
                }
            }
        }
        if isAdd {
            actionStore.addReaction(reactionID: reactionID, completion: completion)
        } else {
            actionStore.removeReaction(reactionID: reactionID, completion: completion)
        }
    }

    private static func makeOptimisticReactionList(from list: [MessageReaction], reactionID: String, add: Bool) -> [MessageReaction] {
        var list = list
        guard let index = list.firstIndex(where: { $0.reactionID == reactionID }) else {
            if add {
                var reaction = MessageReaction(reactionID: reactionID)
                reaction.reactedByMyself = true
                reaction.totalUserCount = 1
                if let me = LoginStore.shared.state.value.loginUserInfo { reaction.partialUserList = [me] }
                list.append(reaction)
            }
            return list
        }

        var reaction = list[index]
        if add, !reaction.reactedByMyself {
            reaction.reactedByMyself = true
            reaction.totalUserCount += 1
            if let me = LoginStore.shared.state.value.loginUserInfo { reaction.partialUserList.append(me) }
        } else if !add, reaction.reactedByMyself {
            reaction.reactedByMyself = false
            reaction.totalUserCount = max(reaction.totalUserCount - 1, 0)
            if let myID = LoginStore.shared.state.value.loginUserInfo?.userID {
                reaction.partialUserList.removeAll { $0.userID == myID }
            }
        }

        if reaction.totalUserCount <= 0 {
            list.remove(at: index)
        } else {
            list[index] = reaction
        }
        return list
    }

    private func deleteSelected() {
        let messagesToDelete = getSelectedMessages()
        guard !messagesToDelete.isEmpty else { return }
        MessageListHelper.presentDeleteConfirmation {
            store.deleteMessages(messageList: messagesToDelete) { result in
                DispatchQueue.main.async {
                    if case .success = result {
                        exitMultiSelectMode()
                    }
                }
            }
        }
    }


    func executeForward(messages: [MessageInfo], to conversationIDs: [String], type: MessageForwardType) {
        let validMessages = messages.filter { $0.status == .sendSuccess }
        let filteredCount = messages.count - validMessages.count
        if filteredCount > 0 {
            print(">>>>> executeForward: \(filteredCount) message(s) filtered out, status is not sendSuccess")
        }
        guard !validMessages.isEmpty else {
            WindowToastManager.shared.show(LocalizedChatString("RelayUnsupportForward"), type: .error, duration: 3)
            return
        }

        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            var mergedForwardInfo: MergedForwardInfo?
            var messagesWithPushInfo = validMessages

            if type == .merged {
                let title = MessageListHelper.generateMergedTitle(messages: validMessages, conversationID: conversationID)
                let abstractList = MessageListHelper.generateAbstractList(messages: validMessages)
                mergedForwardInfo = MergedForwardInfo()
                mergedForwardInfo!.title = title
                mergedForwardInfo!.abstractList = abstractList
                mergedForwardInfo!.compatibleText = "Merged messages"
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

            var sendOption = SendMessageOption()
            sendOption.needReadReceipt = AppBuilderConfig.shared.enableReadReceipt
            sendOption.offlinePushInfo = createOfflinePushInfo(
                conversationID: targetConversationID,
                pushDescription: type == .merged ? LocalizedChatString("MessageTypeMergedHistory") : nil
            )

            var forwardOption = ForwardMessageOption()
            forwardOption.forwardType = type
            forwardOption.mergedForwardInfo = mergedForwardInfo
            forwardOption.sendMessageOption = sendOption

            store.forwardMessages(
                messageList: messagesWithPushInfo,
                option: forwardOption,
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

    func forwardAsrTextToConversations(asrText: String, conversationIDs: [String]) {
        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            let messageInputStore = MessageInputStore.create(conversationID: targetConversationID)

            var option = SendMessageOption()
            option.offlinePushInfo = createOfflinePushInfo(
                conversationID: targetConversationID,
                pushDescription: EmojiManager.shared.createLocalizedStringFromEmojiCodes(asrText)
            )

            messageInputStore.sendMessage(payload: .text(TextSendMessagePayload(text: asrText)), option: option) { result in
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

    func forwardTranslatedTextToConversations(translatedText: String, conversationIDs: [String]) {
        var successCount = 0
        var failureCount = 0
        let totalCount = conversationIDs.count

        for targetConversationID in conversationIDs {
            let messageInputStore = MessageInputStore.create(conversationID: targetConversationID)

            var option = SendMessageOption()
            option.offlinePushInfo = createOfflinePushInfo(
                conversationID: targetConversationID,
                pushDescription: EmojiManager.shared.createLocalizedStringFromEmojiCodes(translatedText)
            )

            messageInputStore.sendMessage(payload: .text(TextSendMessagePayload(text: translatedText)), option: option) { result in
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
}
