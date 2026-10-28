import AtomicXCore
import SwiftUI

public typealias ConversationActionCustomizer = (CustomEditor<ConversationCustomAction>) -> Void

public struct ConversationCustomAction: CustomItem {
    public var ID: String
    public let title: String
    public let dangerous: Bool
    public let action: (ConversationInfo) -> Void

    public init(ID: String, title: String, dangerous: Bool = false, action: @escaping (ConversationInfo) -> Void) {
        self.ID = ID
        self.title = title
        self.dangerous = dangerous
        self.action = action
    }

    public init(title: String, action: @escaping (ConversationInfo) -> Void) {
        self.init(ID: UUID().uuidString, title: title, action: action)
    }
}

public typealias ConversationActionConfig = ChatConversationActionConfig

public struct ChatConversationActionConfig {
    public var userIsSupportDelete: Bool? = nil
    public var userIsSupportMute: Bool? = nil
    public var userIsSupportPin: Bool? = nil
    public var userIsSupportMarkUnread: Bool? = nil
    public var userIsSupportClearHistory: Bool? = nil
    public var userActionCustomizer: ConversationActionCustomizer? = nil
}
