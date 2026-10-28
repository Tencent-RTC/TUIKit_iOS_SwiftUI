import AtomicXCore
import SwiftUI

public struct ChatPage: View {
    private let implementation: ChatPageImpl

    public init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        messageListConfig: ChatMessageListConfig? = nil,
        messageInputConfig: ChatMessageInputConfig? = nil,
        isShowMoreButton: Bool = true,
        showsNavigationBar: Bool = true,
        topBannerView: AnyView? = nil,
        onBack: (() -> Void)? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMoreClick: (() -> Void)? = nil
    ) {
        implementation = ChatPageImpl(
            conversation: conversation,
            locateMessage: locateMessage,
            messageListConfig: messageListConfig,
            messageInputConfig: messageInputConfig,
            isShowMoreButton: isShowMoreButton,
            showsNavigationBar: showsNavigationBar,
            topBannerView: topBannerView,
            onBack: onBack,
            onUserClick: onUserClick,
            onMoreClick: onMoreClick
        )
    }

    public var body: some View { implementation }
}
