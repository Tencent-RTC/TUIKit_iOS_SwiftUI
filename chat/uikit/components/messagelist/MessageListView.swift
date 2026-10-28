import AtomicXCore
import SwiftUI

public struct MessageListView: View {
    private let implementation: MessageListImpl

    public init(
        conversationID: String,
        config: ChatMessageListConfig? = nil,
        locateMessage: MessageInfo? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMultiSelectModeChange: ((Bool) -> Void)? = nil
    ) {
        implementation = MessageListImpl(
            conversationID: conversationID,
            config: config,
            locateMessage: locateMessage,
            onUserClick: onUserClick,
            onMultiSelectModeChange: onMultiSelectModeChange
        )
    }

    public var body: some View { implementation }

    public static func getMessageAbstract(_ message: MessageInfo?, showMergedTitle: Bool = false) -> String {
        MessageListHelper.getMessageAbstract(message, showMergedTitle: showMergedTitle)
    }

    public static func makeMergedMessageDetailView(
        message: MessageInfo,
        conversationID: String,
        embedInNavigationView: Bool = false
    ) -> AnyView {
        AnyView(MergedMessageDetailView(
            mergedMessage: message,
            conversationID: conversationID,
            embedInNavigationView: embedInNavigationView
        ))
    }

    public static func makeReadReceiptDetailView(
        message: MessageInfo,
        actionStore: MessageActionStore,
        embedInNavigationView: Bool = false,
        onUserClick: ((String) -> Void)? = nil
    ) -> AnyView {
        AnyView(MessageReadReceiptView(
            messageActionStore: actionStore,
            message: message,
            embedInNavigationView: embedInNavigationView,
            onUserClick: onUserClick
        ))
    }

    public static func addPlaceholder(conversationID: String, info: MessagePlaceholderInfo) {
        MessageListPlaceholderStore.shared.upsert(conversationID: conversationID, info: info)
    }

    public static func removePlaceholder(conversationID: String, placeholderID: String) {
        MessageListPlaceholderStore.shared.remove(conversationID: conversationID, placeholderID: placeholderID)
    }

    public static func registerCustomMessageCell(
        businessID: String,
        summaryProvider: @escaping (CustomMessagePayload) -> String?,
        contentViewBuilder: @escaping (CustomMessagePayload) -> AnyView
    ) {
        MessageCellRegistry.shared.register(
            businessID: businessID,
            summaryProvider: summaryProvider,
            contentViewBuilder: contentViewBuilder
        )
    }

    public static func registerCustomMessageSummary(matcher: @escaping (CustomMessagePayload) -> String?) {
        CustomMessageSummaryRegistry.shared.registerMatcher(matcher)
    }
}

private struct OpenMergedMessageDetailKey: EnvironmentKey {
    static let defaultValue: ((MessageInfo) -> Void)? = nil
}

private struct OpenReadReceiptDetailKey: EnvironmentKey {
    static let defaultValue: ((MessageInfo, MessageActionStore) -> Void)? = nil
}

extension EnvironmentValues {
    public var openMergedMessageDetail: ((MessageInfo) -> Void)? {
        get { self[OpenMergedMessageDetailKey.self] }
        set { self[OpenMergedMessageDetailKey.self] = newValue }
    }

    public var openReadReceiptDetail: ((MessageInfo, MessageActionStore) -> Void)? {
        get { self[OpenReadReceiptDetailKey.self] }
        set { self[OpenReadReceiptDetailKey.self] = newValue }
    }
}

public typealias MessageActionCustomizer = (CustomEditor<MessageActionMenuAction>) -> Void

public struct MessageActionMenuAction: CustomItem {
    public var ID: String = ""
    public let iconName: String
    public let systemIconFallback: String
    public let label: String
    public var isDangerous: Bool = false
    public var isReactionEntry: Bool = false
    public let handler: (MessageInfo, MessageActionStore) -> Void

    public init(
        ID: String = "",
        iconName: String,
        systemIconFallback: String,
        label: String,
        isDangerous: Bool = false,
        isReactionEntry: Bool = false,
        handler: @escaping (MessageInfo, MessageActionStore) -> Void
    ) {
        self.ID = ID
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.label = label
        self.isDangerous = isDangerous
        self.isReactionEntry = isReactionEntry
        self.handler = handler
    }
}
