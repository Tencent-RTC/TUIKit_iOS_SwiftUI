import SwiftUI

internal protocol ConversationActionConfigProtocol {
    var isSupportDelete: Bool { get }
    var isSupportMute: Bool { get }
    var isSupportPin: Bool { get }
    var isSupportMarkUnread: Bool { get }
    var isSupportClearHistory: Bool { get }
    var actionCustomizer: ConversationActionCustomizer? { get }
}

extension ConversationActionConfigProtocol {
    var actionCustomizer: ConversationActionCustomizer? { nil }
}
