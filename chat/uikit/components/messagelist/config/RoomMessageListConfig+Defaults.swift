import SwiftUI

extension RoomMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {
    init(alignment: MessageAlignment? = nil) { userAlignment = alignment }

    var textFont: Font {
        get { userTextFont ?? FontScheme.caption1Regular }
        set { userTextFont = newValue }
    }

    var textBubbleCornerRadius: CGFloat {
        get { userTextBubbleCornerRadius ?? 0 }
        set { userTextBubbleCornerRadius = newValue }
    }

    var alignment: MessageAlignment {
        get { userAlignment ?? .left }
        set { userAlignment = newValue }
    }

    var isShowTimeMessage: Bool {
        get { userIsShowTimeMessage ?? false }
        set { userIsShowTimeMessage = newValue }
    }

    var isShowLeftAvatar: Bool {
        get { userIsShowLeftAvatar ?? false }
        set { userIsShowLeftAvatar = newValue }
    }

    var isShowLeftNickname: Bool {
        get { userIsShowLeftNickname ?? false }
        set { userIsShowLeftNickname = newValue }
    }

    var isShowRightAvatar: Bool {
        get { userIsShowRightAvatar ?? false }
        set { userIsShowRightAvatar = newValue }
    }

    var isShowRightNickname: Bool {
        get { userIsShowRightNickname ?? false }
        set { userIsShowRightNickname = newValue }
    }

    var nicknameFont: Font {
        get { userNicknameFont ?? FontScheme.caption1Regular }
        set { userNicknameFont = newValue }
    }

    var isShowTimeInBubble: Bool {
        get { userIsShowTimeInBubble ?? false }
        set { userIsShowTimeInBubble = newValue }
    }

    var isShowSystemMessage: Bool {
        get { userIsShowSystemMessage ?? false }
        set { userIsShowSystemMessage = newValue }
    }

    var isShowUnsupportMessage: Bool {
        get { userIsShowUnsupportMessage ?? false }
        set { userIsShowUnsupportMessage = newValue }
    }

    var isSupportCopy: Bool {
        get { userIsSupportCopy ?? false }
        set { userIsSupportCopy = newValue }
    }

    var isSupportDelete: Bool {
        get { userIsSupportDelete ?? false }
        set { userIsSupportDelete = newValue }
    }

    var isSupportRecall: Bool {
        get { userIsSupportRecall ?? false }
        set { userIsSupportRecall = newValue }
    }

    var isSupportForward: Bool {
        get { userIsSupportForward ?? false }
        set { userIsSupportForward = newValue }
    }

    var isSupportMultiSelect: Bool {
        get { userIsSupportMultiSelect ?? false }
        set { userIsSupportMultiSelect = newValue }
    }

    var isSupportReaction: Bool {
        get { userIsSupportReaction ?? false }
        set { userIsSupportReaction = newValue }
    }

    var isSupportQuote: Bool {
        get { userIsSupportQuote ?? false }
        set { userIsSupportQuote = newValue }
    }

    var isSupportListenFromHere: Bool {
        get { userIsSupportListenFromHere ?? false }
        set { userIsSupportListenFromHere = newValue }
    }

    var isSupportConvertToText: Bool {
        get { userIsSupportConvertToText ?? false }
        set { userIsSupportConvertToText = newValue }
    }

    var isSupportTranslate: Bool {
        get { userIsSupportTranslate ?? false }
        set { userIsSupportTranslate = newValue }
    }

    var cellSpacing: CGFloat {
        get { userCellSpacing ?? CGFloat(SpacingScheme.iconTextSpacing) }
        set { userCellSpacing = newValue }
    }

    var horizontalPadding: CGFloat {
        get { userHorizontalPadding ?? CGFloat(SpacingScheme.bubbleSpacing) }
        set { userHorizontalPadding = newValue }
    }

    var avatarSpacing: CGFloat {
        get { userAvatarSpacing ?? CGFloat(SpacingScheme.iconIconSpacing) }
        set { userAvatarSpacing = newValue }
    }
}
