import SwiftUI

public struct ChatMessageStyle: MessageListConfigProtocol, MessageActionConfigProtocol {
    @EnvironmentObject var themeState: ThemeState
    private let userTextColor: Color?
    private let userTextFont: Font?
    private let userTextBubbleCornerRadius: CGFloat?
    private let userTextOtherBubbleBackgroundColor: Color?
    private let userTextMyBubbleBackgroundColor: Color?
    private let userAlignment: Int?
    private let userIsShowTimeMessage: Bool?
    private let userIsShowLeftAvatar: Bool?
    private let userIsShowLeftNickname: Bool?
    private let userIsShowRightAvatar: Bool?
    private let userIsShowRightNickname: Bool?
    private let userNickNameFont: Font?
    private let userNickNameTextColor: Color?
    private let userNickNameBackgroundColor: Color?
    private let userIsShowTimeInBubble: Bool?
    private let userCellSpacing: CGFloat?
    private let userDisplayName: String?
    private let userBottomViewCornerRadius: CGFloat?
    private let userBottomViewBackgroundColor: Color?
    private let userBottomViewBorderColor: Color?
    private let userBottomViewBorderWidth: CGFloat?
    private let userIsShowSystemMessage: Bool?
    private let userIsShowUnsupportMessage: Bool?
    private let userIsSupportCopy: Bool?
    private let userIsSupportDelete: Bool?
    private let userIsSupportRecall: Bool?
    public var textColor: Color {
        return userTextColor ?? themeState.colors.textColorPrimary
    }

    public var textFont: Font {
        return userTextFont ?? .body
    }

    public var textBubbleCornerRadius: CGFloat {
        return userTextBubbleCornerRadius ?? 8.0
    }

    public var textOtherBubbleBackgroundColor: Color {
        return userTextOtherBubbleBackgroundColor ?? themeState.colors.bgColorBubbleReciprocal
    }

    public var textMyBubbleBackgroundColor: Color {
        return userTextMyBubbleBackgroundColor ?? themeState.colors.bgColorBubbleOwn
    }

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

    public var nicknameFont: Font {
        return userNickNameFont ?? .body
    }

    public var nicknameTextColor: Color {
        return userNickNameTextColor ?? themeState.colors.textColorTertiary
    }

    public var nicknameBackgroundColor: Color {
        return userNickNameBackgroundColor ?? .clear
    }

    public var isShowTimeInBubble: Bool {
        return userIsShowTimeInBubble ?? true
    }

    public var cellSpacing: CGFloat {
        return userCellSpacing ?? 8.0
    }

    public var displayName: String {
        return userDisplayName ?? "Chat Style"
    }

    public var bottomViewCornerRadius: CGFloat {
        return userBottomViewCornerRadius ?? 0
    }

    public var bottomViewBackgroundColor: Color {
        return userBottomViewBackgroundColor ?? .clear
    }

    public var bottomViewBorderColor: Color {
        return userBottomViewBorderColor ?? .clear
    }

    public var bottomViewBorderWidth: CGFloat {
        return userBottomViewBorderWidth ?? 0
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

    public init() {
        self.userTextColor = nil
        self.userTextFont = nil
        self.userTextBubbleCornerRadius = nil
        self.userTextOtherBubbleBackgroundColor = nil
        self.userTextMyBubbleBackgroundColor = nil
        self.userAlignment = nil
        self.userIsShowTimeMessage = nil
        self.userIsShowLeftAvatar = nil
        self.userIsShowLeftNickname = nil
        self.userIsShowRightAvatar = nil
        self.userIsShowRightNickname = nil
        self.userNickNameFont = nil
        self.userNickNameTextColor = nil
        self.userNickNameBackgroundColor = nil
        self.userIsShowTimeInBubble = nil
        self.userCellSpacing = nil
        self.userDisplayName = nil
        self.userBottomViewCornerRadius = nil
        self.userBottomViewBackgroundColor = nil
        self.userBottomViewBorderColor = nil
        self.userBottomViewBorderWidth = nil
        self.userIsShowSystemMessage = nil
        self.userIsShowUnsupportMessage = nil
        self.userIsSupportCopy = nil
        self.userIsSupportDelete = nil
        self.userIsSupportRecall = nil
    }

    public init(
        textColor: Color? = nil,
        textFont: Font? = nil,
        textBubbleCornerRadius: CGFloat? = nil,
        textOtherBubbleBackgroundColor: Color? = nil,
        textMyBubbleBackgroundColor: Color? = nil,
        alignment: Int? = nil,
        isShowTimeMessage: Bool? = nil,
        isShowLeftAvatar: Bool? = nil,
        isShowLeftNickname: Bool? = nil,
        isShowRightAvatar: Bool? = nil,
        isShowRightNickname: Bool? = nil,
        nicknameFont: Font? = nil,
        nicknameTextColor: Color? = nil,
        nicknameBackgroundColor: Color? = nil,
        isShowTimeInBubble: Bool? = nil,
        cellSpacing: CGFloat? = nil,
        displayName: String? = nil,
        bottomViewCornerRadius: CGFloat? = nil,
        bottomViewBackgroundColor: Color? = nil,
        bottomViewBorderColor: Color? = nil,
        bottomViewBorderWidth: CGFloat? = nil,
        isShowSystemMessage: Bool? = nil,
        isShowUnsupportMessage: Bool? = nil,
        isSupportCopy: Bool? = nil,
        isSupportDelete: Bool? = nil,
        isSupportRecall: Bool? = nil
    ) {
        self.userTextColor = textColor
        self.userTextFont = textFont
        self.userTextBubbleCornerRadius = textBubbleCornerRadius
        self.userTextOtherBubbleBackgroundColor = textOtherBubbleBackgroundColor
        self.userTextMyBubbleBackgroundColor = textMyBubbleBackgroundColor
        self.userAlignment = alignment
        self.userIsShowTimeMessage = isShowTimeMessage
        self.userIsShowLeftAvatar = isShowLeftAvatar
        self.userIsShowLeftNickname = isShowLeftNickname
        self.userIsShowRightAvatar = isShowRightAvatar
        self.userIsShowRightNickname = isShowRightNickname
        self.userNickNameFont = nicknameFont
        self.userNickNameTextColor = nicknameTextColor
        self.userNickNameBackgroundColor = nicknameBackgroundColor
        self.userIsShowTimeInBubble = isShowTimeInBubble
        self.userCellSpacing = cellSpacing
        self.userDisplayName = displayName
        self.userBottomViewCornerRadius = bottomViewCornerRadius
        self.userBottomViewBackgroundColor = bottomViewBackgroundColor
        self.userBottomViewBorderColor = bottomViewBorderColor
        self.userBottomViewBorderWidth = bottomViewBorderWidth
        self.userIsShowSystemMessage = isShowSystemMessage
        self.userIsShowUnsupportMessage = isShowUnsupportMessage
        self.userIsSupportCopy = isSupportCopy
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportRecall = isSupportRecall
    }
}

public struct RoomStyle: MessageListConfigProtocol, MessageActionConfigProtocol {
    /// MessageListConfigProtocol
    public let textColor: Color = .white
    public let textFont: Font = .body
    public let textBubbleCornerRadius: CGFloat = 0
    public let textOtherBubbleBackgroundColor: Color = .clear
    public let textMyBubbleBackgroundColor: Color = .clear
    public let alignment: Int = 1 // 0: left and right; 1: left; 2: righ
    public let isShowTimeMessage: Bool = false
    public let isShowLeftAvatar: Bool = false
    public let isShowLeftNickname: Bool = false
    public let isShowRightAvatar: Bool = false
    public let isShowRightNickname: Bool = false
    public let nicknameFont: Font = .body
    public let nicknameTextColor: Color = .white
    public let nicknameBackgroundColor: Color = .clear
    public let isShowTimeInBubble: Bool = false
    public let cellSpacing: CGFloat = 5.0
    public let displayName: String = "Room Style"
    public let bottomViewCornerRadius: CGFloat = 20
    public let bottomViewBackgroundColor: Color = Color.black.opacity(0.5)
    public let bottomViewBorderColor: Color = .clear
    public let bottomViewBorderWidth: CGFloat = 0
    public let isShowSystemMessage: Bool = false
    public let isShowUnsupportMessage: Bool = false
    /// MessageActionConfig
    public var isSupportCopy: Bool { return false }
    public var isSupportDelete: Bool { return false }
    public var isSupportRecall: Bool { return false }
    public init() {}
}

public protocol MessageListConfigProtocol {
    var textColor: Color { get }
    var textFont: Font { get }
    var textBubbleCornerRadius: CGFloat { get }
    var textOtherBubbleBackgroundColor: Color { get }
    var textMyBubbleBackgroundColor: Color { get }
    var alignment: Int { get } // 1: left; 2: right; 3: left and right;
    var isShowTimeMessage: Bool { get }
    var isShowLeftAvatar: Bool { get }
    var isShowLeftNickname: Bool { get }
    var isShowRightAvatar: Bool { get }
    var isShowRightNickname: Bool { get }
    var nicknameFont: Font { get }
    var nicknameTextColor: Color { get }
    var nicknameBackgroundColor: Color { get }
    var isShowTimeInBubble: Bool { get }
    var cellSpacing: CGFloat { get }
    var displayName: String { get }
    var bottomViewCornerRadius: CGFloat { get }
    var bottomViewBackgroundColor: Color { get }
    var bottomViewBorderColor: Color { get }
    var bottomViewBorderWidth: CGFloat { get }
    var isShowSystemMessage: Bool { get }
    var isShowUnsupportMessage: Bool { get }
}

public protocol MessageActionConfigProtocol {
    var isSupportCopy: Bool { get }
    var isSupportDelete: Bool { get }
    var isSupportRecall: Bool { get }
}
