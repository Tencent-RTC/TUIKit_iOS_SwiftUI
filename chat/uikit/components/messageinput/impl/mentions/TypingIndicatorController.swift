import AtomicXCore
import Combine
import Foundation

internal final class TypingIndicatorController: ObservableObject {
    static let typingSendInterval: TimeInterval = 4
    static let peerActiveWindow: TimeInterval = 30
    static let displayTimeout: TimeInterval = 5
    static let recentMessageScanCount = 20
    static let businessID = MessageInputView.typingStatusBusinessID
    static let actionParamTyping = "EIMAMSG_InputStatus_Ing"
    static let actionParamEnd = "EIMAMSG_InputStatus_End"
    static let typingUserActionCode = 14

    let conversationID: String
    let peerUserID: String?
    let currentUserID: String?
    let messageListStore: MessageListStore
    let messageInputStore: MessageInputStore
    var cancellables = Set<AnyCancellable>()
    var lastPeerMessageAt: TimeInterval?
    var lastTypingStartSentAt: TimeInterval = 0
    var hasSentTypingStart = false
    var displayTimeoutWorkItem: DispatchWorkItem?
    var activeSessionID: UUID?

    @Published var isTyping: Bool = false {
        didSet {
            guard isTyping != oldValue else { return }
            NotificationCenter.default.post(
                name: MessageInputView.typingStatusDidChangeNotification,
                object: nil,
                userInfo: ["conversationID": conversationID, "isTyping": isTyping]
            )
        }
    }

    init(conversationID: String, currentUserID: String?) {
        self.conversationID = conversationID
        self.currentUserID = currentUserID
        self.peerUserID = ChatUtil.getUserID(conversationID)
        self.messageListStore = MessageListStore.create(conversationID: conversationID)
        self.messageInputStore = MessageInputStore.create(conversationID: conversationID)
        activate()
    }

}
