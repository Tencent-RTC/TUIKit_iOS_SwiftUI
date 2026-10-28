import AtomicXCore
import SwiftUI

public struct ConversationListView: View {
    private let implementation: ConversationListImpl

    public init(onConversationClick: @escaping (ConversationInfo) -> Void,
                config: ChatConversationActionConfig? = nil,
                customActions: [ConversationCustomAction] = []) {
        implementation = ConversationListImpl(
            onConversationClick: onConversationClick,
            config: config,
            customActions: customActions
        )
    }

    public var body: some View { implementation }
}
