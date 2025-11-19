import SwiftUI

public protocol ConversationActionConfigProtocol {
    var isSupportDelete: Bool { get }
    var isSupportMute: Bool { get }
    var isSupportPin: Bool { get }
    var isSupportMarkUnread: Bool { get }
    var isSupportClearHistory: Bool { get }
}

public struct ChatConversationActionConfig: ConversationActionConfigProtocol {
    private let userIsSupportDelete: Bool?
    private let userIsSupportMute: Bool?
    private let userIsSupportPin: Bool?
    private let userIsSupportMarkUnread: Bool?
    private let userIsSupportClearHistory: Bool?

    public var isSupportDelete: Bool {
        if let userIsSupportDelete = userIsSupportDelete {
            return userIsSupportDelete
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.delete)
        }
    }

    public var isSupportMute: Bool {
        if let userIsSupportMute = userIsSupportMute {
            return userIsSupportMute
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.mute)
        }
    }

    public var isSupportPin: Bool {
        if let userIsSupportPin = userIsSupportPin {
            return userIsSupportPin
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.pin)
        }
    }

    public var isSupportMarkUnread: Bool {
        if let userIsSupportMarkUnread = userIsSupportMarkUnread {
            return userIsSupportMarkUnread
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.markUnread)
        }
    }

    public var isSupportClearHistory: Bool {
        if let userIsSupportClearHistory = userIsSupportClearHistory {
            return userIsSupportClearHistory
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.clearHistory)
        }
    }

    public init() {
        self.userIsSupportDelete = nil
        self.userIsSupportMute = nil
        self.userIsSupportPin = nil
        self.userIsSupportMarkUnread = nil
        self.userIsSupportClearHistory = nil
    }

    public init(
        isSupportDelete: Bool? = nil,
        isSupportMute: Bool? = nil,
        isSupportPin: Bool? = nil,
        isSupportMarkUnread: Bool? = nil,
        isSupportClearHistory: Bool? = nil
    ) {
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportMute = isSupportMute
        self.userIsSupportPin = isSupportPin
        self.userIsSupportMarkUnread = isSupportMarkUnread
        self.userIsSupportClearHistory = isSupportClearHistory
    }
}
