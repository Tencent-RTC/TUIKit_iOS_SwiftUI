import SwiftUI

public protocol ConversationListConfigProtocol {
    var isSupportDelete: Bool { get }
    var isSupportMute: Bool { get }
    var isSupportPin: Bool { get }
    var isSupportMarkUnread: Bool { get }
}

public struct ChatConversationStyle: ConversationListConfigProtocol {
    private let userIsSupportDelete: Bool?
    private let userIsSupportMute: Bool?
    private let userIsSupportPin: Bool?
    private let userIsSupportMarkUnread: Bool?
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

    public init() {
        self.userIsSupportDelete = nil
        self.userIsSupportMute = nil
        self.userIsSupportPin = nil
        self.userIsSupportMarkUnread = nil
    }

    public init(
        isSupportDelete: Bool? = nil,
        isSupportMute: Bool? = nil,
        isSupportPin: Bool? = nil,
        isSupportMarkUnread: Bool? = nil
    ) {
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportMute = isSupportMute
        self.userIsSupportPin = isSupportPin
        self.userIsSupportMarkUnread = isSupportMarkUnread
    }
}
