import AtomicXCore
import SwiftUI

extension ChatMessageListConfig {
    static let defaultCellSpacing: CGFloat = 10.0
    static let defaultBubbleMaxWidthRatio: CGFloat = 0.72
}

extension ChatMessageListConfig {
    public var defaultBubbleAppearance: MessageBubbleAppearance? {
        get { userDefaultBubbleAppearance }
        set { userDefaultBubbleAppearance = newValue }
    }

    public var ownBubbleAppearance: MessageBubbleAppearance? {
        get { userOwnBubbleAppearance }
        set { userOwnBubbleAppearance = newValue }
    }

    public var incomingBubbleAppearance: MessageBubbleAppearance? {
        get { userIncomingBubbleAppearance }
        set { userIncomingBubbleAppearance = newValue }
    }

    public var leftBubbleAppearance: MessageBubbleAppearance? {
        get { userLeftBubbleAppearance }
        set { userLeftBubbleAppearance = newValue }
    }

    public var rightBubbleAppearance: MessageBubbleAppearance? {
        get { userRightBubbleAppearance }
        set { userRightBubbleAppearance = newValue }
    }

    public var alignment: MessageAlignment {
        get { userAlignment ?? AppBuilderConfig.shared.messageAlignment }
        set { userAlignment = newValue }
    }

    public var bubbleMaxWidthRatio: CGFloat {
        get { userBubbleMaxWidthRatio ?? Self.defaultBubbleMaxWidthRatio }
        set { userBubbleMaxWidthRatio = newValue }
    }

    public var background: MessageListBackground? {
        get { userBackground }
        set { userBackground = newValue }
    }

    public var enableTyping: Bool {
        get { userEnableTyping ?? true }
        set { userEnableTyping = newValue }
    }

    public var isShowTimeMessage: Bool {
        get { userIsShowTimeMessage ?? true }
        set { userIsShowTimeMessage = newValue }
    }

    public var isShowLeftAvatar: Bool {
        get { userIsShowLeftAvatar ?? true }
        set { userIsShowLeftAvatar = newValue }
    }

    public var isShowLeftNickname: Bool {
        get { userIsShowLeftNickname ?? true }
        set { userIsShowLeftNickname = newValue }
    }

    public var isShowRightAvatar: Bool {
        get { userIsShowRightAvatar ?? false }
        set { userIsShowRightAvatar = newValue }
    }

    public var isShowRightNickname: Bool {
        get { userIsShowRightNickname ?? true }
        set { userIsShowRightNickname = newValue }
    }

    public var isShowTimeInBubble: Bool {
        get { userIsShowTimeInBubble ?? true }
        set { userIsShowTimeInBubble = newValue }
    }

    public var cellSpacing: CGFloat {
        get { userCellSpacing ?? Self.defaultCellSpacing }
        set { userCellSpacing = newValue }
    }

    public var isShowSystemMessage: Bool {
        get { userIsShowSystemMessage ?? true }
        set { userIsShowSystemMessage = newValue }
    }

    public var isShowUnsupportMessage: Bool {
        get { userIsShowUnsupportMessage ?? true }
        set { userIsShowUnsupportMessage = newValue }
    }

    public var isSupportCopy: Bool {
        get { userIsSupportCopy ?? AppBuilderConfig.shared.messageActionList.contains(.copy) }
        set { userIsSupportCopy = newValue }
    }

    public var isSupportDelete: Bool {
        get { userIsSupportDelete ?? AppBuilderConfig.shared.messageActionList.contains(.delete) }
        set { userIsSupportDelete = newValue }
    }

    public var isSupportRecall: Bool {
        get { userIsSupportRecall ?? AppBuilderConfig.shared.messageActionList.contains(.recall) }
        set { userIsSupportRecall = newValue }
    }

    public var isSupportForward: Bool {
        get { userIsSupportForward ?? AppBuilderConfig.shared.messageActionList.contains(.forward) }
        set { userIsSupportForward = newValue }
    }

    public var isSupportMultiSelect: Bool {
        get { userIsSupportMultiSelect ?? true }
        set { userIsSupportMultiSelect = newValue }
    }

    public var isSupportQuote: Bool {
        get { userIsSupportQuote ?? AppBuilderConfig.shared.messageActionList.contains(.quote) }
        set { userIsSupportQuote = newValue }
    }

    public var isSupportListenFromHere: Bool {
        get { userIsSupportListenFromHere ?? true }
        set { userIsSupportListenFromHere = newValue }
    }

    public var isSupportConvertToText: Bool {
        get { userIsSupportConvertToText ?? true }
        set { userIsSupportConvertToText = newValue }
    }

    public var isSupportTranslate: Bool {
        get { userIsSupportTranslate ?? true }
        set { userIsSupportTranslate = newValue }
    }

    public var horizontalPadding: CGFloat {
        get { userHorizontalPadding ?? CGFloat(SpacingScheme.bubbleSpacing) }
        set { userHorizontalPadding = newValue }
    }

    public var avatarSpacing: CGFloat {
        get { userAvatarSpacing ?? CGFloat(SpacingScheme.smallSpacing) }
        set { userAvatarSpacing = newValue }
    }

    public var isSupportReaction: Bool {
        get { userIsSupportReaction ?? true }
        set { userIsSupportReaction = newValue }
    }

    public init(
        alignment: MessageAlignment? = nil,
        isShowTimeMessage: Bool? = nil,
        isShowLeftAvatar: Bool? = nil,
        isShowLeftNickname: Bool? = nil,
        isShowRightAvatar: Bool? = nil,
        isShowRightNickname: Bool? = nil,
        isShowTimeInBubble: Bool? = nil,
        cellSpacing: CGFloat? = nil,
        isShowSystemMessage: Bool? = nil,
        isShowUnsupportMessage: Bool? = nil,
        isSupportCopy: Bool? = nil,
        isSupportDelete: Bool? = nil,
        isSupportRecall: Bool? = nil,
        isSupportForward: Bool? = nil,
        isSupportMultiSelect: Bool? = nil,
        isSupportQuote: Bool? = nil,
        isSupportListenFromHere: Bool? = nil,
        isSupportConvertToText: Bool? = nil,
        isSupportTranslate: Bool? = nil,
        horizontalPadding: CGFloat? = nil,
        avatarSpacing: CGFloat? = nil,
        isSupportReaction: Bool? = nil,
        actionCustomizer: MessageActionCustomizer? = nil,
        defaultBubbleAppearance: MessageBubbleAppearance? = nil,
        ownBubbleAppearance: MessageBubbleAppearance? = nil,
        incomingBubbleAppearance: MessageBubbleAppearance? = nil,
        leftBubbleAppearance: MessageBubbleAppearance? = nil,
        rightBubbleAppearance: MessageBubbleAppearance? = nil,
        bubbleMaxWidthRatio: CGFloat? = nil,
        background: MessageListBackground? = nil,
        enableTyping: Bool? = nil
    ) {
        self.userBubbleMaxWidthRatio = bubbleMaxWidthRatio
        self.userBackground = background
        self.userEnableTyping = enableTyping
        self.userAlignment = alignment
        self.userIsShowTimeMessage = isShowTimeMessage
        self.userIsShowLeftAvatar = isShowLeftAvatar
        self.userIsShowLeftNickname = isShowLeftNickname
        self.userIsShowRightAvatar = isShowRightAvatar
        self.userIsShowRightNickname = isShowRightNickname
        self.userIsShowTimeInBubble = isShowTimeInBubble
        self.userCellSpacing = cellSpacing
        self.userIsShowSystemMessage = isShowSystemMessage
        self.userIsShowUnsupportMessage = isShowUnsupportMessage
        self.userIsSupportCopy = isSupportCopy
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportRecall = isSupportRecall
        self.userIsSupportForward = isSupportForward
        self.userIsSupportMultiSelect = isSupportMultiSelect
        self.userIsSupportQuote = isSupportQuote
        self.userIsSupportListenFromHere = isSupportListenFromHere
        self.userIsSupportConvertToText = isSupportConvertToText
        self.userIsSupportTranslate = isSupportTranslate
        self.userHorizontalPadding = horizontalPadding
        self.userAvatarSpacing = avatarSpacing
        self.userIsSupportReaction = isSupportReaction
        self.userActionCustomizer = actionCustomizer
        self.userDefaultBubbleAppearance = defaultBubbleAppearance
        self.userOwnBubbleAppearance = ownBubbleAppearance
        self.userIncomingBubbleAppearance = incomingBubbleAppearance
        self.userLeftBubbleAppearance = leftBubbleAppearance
        self.userRightBubbleAppearance = rightBubbleAppearance
    }

    public var messageExclusionMatchers: [MessageMatcher] {
        get { userMessageExclusionMatchers ?? [] }
        set { userMessageExclusionMatchers = newValue }
    }

    public var actionCustomizer: MessageActionCustomizer? {
        get { userActionCustomizer }
        set { userActionCustomizer = newValue }
    }

    public mutating func addMessageExclusion(_ matcher: @escaping MessageMatcher) {
        messageExclusionMatchers.append(matcher)
    }

    public mutating func excludeMessagesByType(_ types: MessageType...) {
        messageExclusionMatchers.append { types.contains($0.messageType) }
    }

    public mutating func excludeCustomMessagesByBusinessID(_ businessID: String) {
        messageExclusionMatchers.append { message in
            guard case .custom(let payload) = message.messagePayload,
                  let data = payload.customData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return false }
            return json["businessID"] as? String == businessID
        }
    }

    public mutating func clearMessageExclusions() {
        userMessageExclusionMatchers = nil
    }
}
