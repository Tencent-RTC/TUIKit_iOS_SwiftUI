import SwiftUI

public protocol MessageListConfigProtocol {
    var alignment: Int { get } // 0: left; 1: right; 2: left and right;
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
}

public protocol MessageActionConfigProtocol {
    var isSupportCopy: Bool { get }
    var isSupportDelete: Bool { get }
    var isSupportRecall: Bool { get }
}

public struct ChatMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {
    @EnvironmentObject var themeState: ThemeState
    private let userAlignment: Int?
    private let userIsShowTimeMessage: Bool?
    private let userIsShowLeftAvatar: Bool?
    private let userIsShowLeftNickname: Bool?
    private let userIsShowRightAvatar: Bool?
    private let userIsShowRightNickname: Bool?
    private let userIsShowTimeInBubble: Bool?
    private let userCellSpacing: CGFloat?
    private let userIsShowSystemMessage: Bool?
    private let userIsShowUnsupportMessage: Bool?
    private let userIsSupportCopy: Bool?
    private let userIsSupportDelete: Bool?
    private let userIsSupportRecall: Bool?
    private let userHorizontalPadding: CGFloat?
    private let userAvatarSpacing: CGFloat?

    public var alignment: Int {
        if let userAlignment = userAlignment {
            return userAlignment
        } else {
            let config = AppBuilderConfig.shared
            switch config.messageAlignment {
            case .left:
                return 1
            case .right:
                return 2
            case .twoSided:
                return 0
            }
        }
    }

    public var isShowTimeMessage: Bool {
        return userIsShowTimeMessage ?? true
    }

    public var isShowLeftAvatar: Bool {
        return userIsShowLeftAvatar ?? true
    }

    public var isShowLeftNickname: Bool {
        return userIsShowLeftNickname ?? false
    }

    public var isShowRightAvatar: Bool {
        return userIsShowRightAvatar ?? false
    }

    public var isShowRightNickname: Bool {
        return userIsShowRightNickname ?? false
    }

    public var isShowTimeInBubble: Bool {
        return userIsShowTimeInBubble ?? true
    }

    public var cellSpacing: CGFloat {
        return userCellSpacing ?? 8.0
    }

    public var isShowSystemMessage: Bool {
        return userIsShowSystemMessage ?? true
    }

    public var isShowUnsupportMessage: Bool {
        return userIsShowUnsupportMessage ?? true
    }

    /// MessageActionConfig
    public var isSupportCopy: Bool {
        if let userIsSupportCopy = userIsSupportCopy {
            return userIsSupportCopy
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.copy)
        }
    }

    public var isSupportDelete: Bool {
        if let userIsSupportDelete = userIsSupportDelete {
            return userIsSupportDelete
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.delete)
        }
    }

    public var isSupportRecall: Bool {
        if let userIsSupportRecall = userIsSupportRecall {
            return userIsSupportRecall
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.recall)
        }
    }

    public var horizontalPadding: CGFloat {
        return userHorizontalPadding ?? 16.0
    }

    public var avatarSpacing: CGFloat {
        return userAvatarSpacing ?? 12.0
    }

    public init() {
        self.userAlignment = nil
        self.userIsShowTimeMessage = nil
        self.userIsShowLeftAvatar = nil
        self.userIsShowLeftNickname = nil
        self.userIsShowRightAvatar = nil
        self.userIsShowRightNickname = nil
        self.userIsShowTimeInBubble = nil
        self.userCellSpacing = nil
        self.userIsShowSystemMessage = nil
        self.userIsShowUnsupportMessage = nil
        self.userIsSupportCopy = nil
        self.userIsSupportDelete = nil
        self.userIsSupportRecall = nil
        self.userHorizontalPadding = nil
        self.userAvatarSpacing = nil
    }

    public init(
        textFont: Font? = nil,
        textBubbleCornerRadius: CGFloat? = nil,
        alignment: Int? = nil,
        isShowTimeMessage: Bool? = nil,
        isShowLeftAvatar: Bool? = nil,
        isShowLeftNickname: Bool? = nil,
        isShowRightAvatar: Bool? = nil,
        isShowRightNickname: Bool? = nil,
        nicknameFont: Font? = nil,
        isShowTimeInBubble: Bool? = nil,
        cellSpacing: CGFloat? = nil,
        displayName: String? = nil,
        bottomViewCornerRadius: CGFloat? = nil,
        bottomViewBorderWidth: CGFloat? = nil,
        isShowSystemMessage: Bool? = nil,
        isShowUnsupportMessage: Bool? = nil,
        isSupportCopy: Bool? = nil,
        isSupportDelete: Bool? = nil,
        isSupportRecall: Bool? = nil,
        horizontalPadding: CGFloat? = nil,
        avatarSpacing: CGFloat? = nil
    ) {
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
        self.userHorizontalPadding = horizontalPadding
        self.userAvatarSpacing = avatarSpacing
    }
}

public struct RoomMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {
    /// MessageListConfigProtocol
    public let textFont: Font = .body
    public let textBubbleCornerRadius: CGFloat = 0
    public let alignment: Int = 1 // 0: left and right; 1: left; 2: righ
    public let isShowTimeMessage: Bool = false
    public let isShowLeftAvatar: Bool = false
    public let isShowLeftNickname: Bool = false
    public let isShowRightAvatar: Bool = false
    public let isShowRightNickname: Bool = false
    public let nicknameFont: Font = .body
    public let isShowTimeInBubble: Bool = false
    public let cellSpacing: CGFloat = 5.0
    public let isShowSystemMessage: Bool = false
    public let isShowUnsupportMessage: Bool = false
    public let horizontalPadding: CGFloat = 16.0
    public let avatarSpacing: CGFloat = 12.0
    /// MessageActionConfig
    public var isSupportCopy: Bool { return false }
    public var isSupportDelete: Bool { return false }
    public var isSupportRecall: Bool { return false }
    public init() {}
}
