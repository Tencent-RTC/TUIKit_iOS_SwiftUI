import AtomicXCore
import SwiftUI

public struct NavigationInfo {
    public let conversation: ConversationInfo
    public let locateMessage: MessageInfo?

    public init(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        self.conversation = conversation
        self.locateMessage = locateMessage
    }
}

public struct ConversationsPage: View {
    private let implementation: ConversationsPageImpl

    public init(
        config: ConversationActionConfig? = nil,
        onConversationClick: ((NavigationInfo) -> Void)? = nil
    ) {
        implementation = ConversationsPageImpl(
            config: config ?? ConversationActionConfig(),
            onConversationClick: onConversationClick
        )
    }

    public var body: some View { implementation }
}
