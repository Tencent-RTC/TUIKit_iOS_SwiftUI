import AtomicXCore
import SwiftUI

protocol MessageListConfigProtocol {
    var alignment: MessageAlignment { get }
    var bubbleMaxWidthRatio: CGFloat { get }
    var background: MessageListBackground? { get }
    var enableTyping: Bool { get }
    var isShowTimeMessage: Bool { get }
    var isShowLeftAvatar: Bool { get }
    var isShowLeftNickname: Bool { get }
    var isShowRightAvatar: Bool { get }
    var isShowRightNickname: Bool { get }
    var isShowTimeInBubble: Bool { get }
    var cellSpacing: CGFloat { get }
    var isShowSystemMessage: Bool { get }
    var isShowUnsupportMessage: Bool { get }
    var horizontalPadding: CGFloat { get }
    var avatarSpacing: CGFloat { get }
    var isSupportReaction: Bool { get }
    var messageExclusionMatchers: [MessageMatcher] { get }
    var defaultBubbleAppearance: MessageBubbleAppearance? { get }
    var ownBubbleAppearance: MessageBubbleAppearance? { get }
    var incomingBubbleAppearance: MessageBubbleAppearance? { get }
    var leftBubbleAppearance: MessageBubbleAppearance? { get }
    var rightBubbleAppearance: MessageBubbleAppearance? { get }
}

extension MessageListConfigProtocol {
    var bubbleMaxWidthRatio: CGFloat { ChatMessageListConfig.defaultBubbleMaxWidthRatio }
    var background: MessageListBackground? { nil }
    var enableTyping: Bool { true }
    var messageExclusionMatchers: [MessageMatcher] { [] }
}
