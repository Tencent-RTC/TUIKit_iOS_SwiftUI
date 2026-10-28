import AtomicXCore
import Combine
import Foundation

extension TypingIndicatorController {
    func activate() {
        guard activeSessionID == nil else { return }
        activeSessionID = UUID()
        lastTypingStartSentAt = 0
        initializePeerActivity()
        bindIncomingMessages()
    }

    func sendTypingStatus(hasContent: Bool) {
        guard activeSessionID != nil, peerUserID != nil else { return }
        guard isPeerActive() else { return }
        let now = Date().timeIntervalSince1970
        if hasContent {
            guard now - lastTypingStartSentAt >= Self.typingSendInterval else { return }
            lastTypingStartSentAt = now
            hasSentTypingStart = true
            sendTypingMessage(isTyping: true)
        } else {
            guard hasSentTypingStart else { return }
            hasSentTypingStart = false
            sendTypingMessage(isTyping: false)
        }
    }

    func invalidate() {
        activeSessionID = nil
        displayTimeoutWorkItem?.cancel()
        displayTimeoutWorkItem = nil
        cancellables.removeAll()
        if hasSentTypingStart {
            hasSentTypingStart = false
            sendTypingMessage(isTyping: false)
        }
        isTyping = false
    }

    func bindIncomingMessages() {
        guard let sessionID = activeSessionID, cancellables.isEmpty else { return }
        messageListStore.messageEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self, self.activeSessionID == sessionID else { return }
                guard case .onReceiveNewMessage(let message) = event,
                      message.from.userID == self.peerUserID
                else { return }
                if let isTyping = self.typingStatus(from: message) {
                    self.handlePeerTypingStatus(isTyping)
                    return
                }
                self.lastPeerMessageAt = Date().timeIntervalSince1970
            }
            .store(in: &cancellables)
    }

    func typingStatus(from message: MessageInfo) -> Bool? {
        guard case .custom(let payload) = message.messagePayload,
              let data = payload.customData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let businessID = json["businessID"] as? String,
              businessID == Self.businessID
        else { return nil }
        if let typingStatus = json["typingStatus"] as? Int {
            return typingStatus == 1
        }
        if let actionParam = json["actionParam"] as? String {
            if actionParam == Self.actionParamTyping { return true }
            if actionParam == Self.actionParamEnd { return false }
        }
        return nil
    }

    func initializePeerActivity() {
        let messages = messageListStore.state.value.messageList
        for message in messages.suffix(Self.recentMessageScanCount).reversed() {
            guard let peerUserID = peerUserID, message.from.userID == peerUserID else { continue }
            if let timestamp = message.timestamp, timestamp > 0 {
                lastPeerMessageAt = TimeInterval(timestamp)
            }
            break
        }
    }

    func isPeerActive() -> Bool {
        guard let lastPeerMessageAt = lastPeerMessageAt else { return false }
        return Date().timeIntervalSince1970 - lastPeerMessageAt <= Self.peerActiveWindow
    }

    func handlePeerTypingStatus(_ isTyping: Bool) {
        guard let sessionID = activeSessionID else { return }
        displayTimeoutWorkItem?.cancel()
        displayTimeoutWorkItem = nil
        if isTyping {
            self.isTyping = true
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeSessionID == sessionID else { return }
                self.isTyping = false
            }
            displayTimeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayTimeout, execute: workItem)
        } else {
            self.isTyping = false
        }
    }

    func sendTypingMessage(isTyping: Bool) {
        let json: [String: Any] = [
            "businessID": Self.businessID,
            "typingStatus": isTyping ? 1 : 0,
            "version": 0,
            "userAction": isTyping ? Self.typingUserActionCode : 0,
            "actionParam": isTyping ? Self.actionParamTyping : Self.actionParamEnd
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        let payload = CustomSendMessagePayload(customData: jsonString)
        var option = SendMessageOption()
        option.onlineUserOnly = true
        messageInputStore.sendMessage(payload: .custom(payload), option: option, completion: nil)
    }
}
