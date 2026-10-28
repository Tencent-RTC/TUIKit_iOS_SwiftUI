import AtomicXCore
import SwiftUI

extension C2CChatSettingConfig: C2CChatSettingConfigProtocol {
    public var isShowHeader: Bool {
        get { userIsShowHeader ?? true }
        set { userIsShowHeader = newValue }
    }

    public var isShowRemark: Bool {
        get { userIsShowRemark ?? true }
        set { userIsShowRemark = newValue }
    }

    public var isShowDoNotDisturb: Bool {
        get { userIsShowDoNotDisturb ?? true }
        set { userIsShowDoNotDisturb = newValue }
    }

    public var isShowPin: Bool {
        get { userIsShowPin ?? true }
        set { userIsShowPin = newValue }
    }

    public var isShowChatBackground: Bool {
        get { userIsShowChatBackground ?? true }
        set { userIsShowChatBackground = newValue }
    }

    public var isShowBlacklist: Bool {
        get { userIsShowBlacklist ?? true }
        set { userIsShowBlacklist = newValue }
    }

    public var isShowSendMessage: Bool {
        get { userIsShowSendMessage ?? true }
        set { userIsShowSendMessage = newValue }
    }

    public var isShowVoiceCall: Bool {
        get { userIsShowVoiceCall ?? true }
        set { userIsShowVoiceCall = newValue }
    }

    public var isShowVideoCall: Bool {
        get { userIsShowVideoCall ?? true }
        set { userIsShowVideoCall = newValue }
    }

    public var isShowClearHistory: Bool {
        get { userIsShowClearHistory ?? true }
        set { userIsShowClearHistory = newValue }
    }

    public var isShowDeleteFriend: Bool {
        get { userIsShowDeleteFriend ?? true }
        set { userIsShowDeleteFriend = newValue }
    }

    public var itemCustomizer: C2CChatSettingItemCustomizer? {
        get { userItemCustomizer }
        set { userItemCustomizer = newValue }
    }

    public convenience init(
        isShowHeader: Bool? = nil,
        isShowRemark: Bool? = nil,
        isShowDoNotDisturb: Bool? = nil,
        isShowPin: Bool? = nil,
        isShowChatBackground: Bool? = nil,
        isShowBlacklist: Bool? = nil,
        isShowSendMessage: Bool? = nil,
        isShowVoiceCall: Bool? = nil,
        isShowVideoCall: Bool? = nil,
        isShowClearHistory: Bool? = nil,
        isShowDeleteFriend: Bool? = nil,
        itemCustomizer: C2CChatSettingItemCustomizer? = nil
    ) {
        self.init()
        self.userIsShowHeader = isShowHeader
        self.userIsShowRemark = isShowRemark
        self.userIsShowDoNotDisturb = isShowDoNotDisturb
        self.userIsShowPin = isShowPin
        self.userIsShowChatBackground = isShowChatBackground
        self.userIsShowBlacklist = isShowBlacklist
        self.userIsShowSendMessage = isShowSendMessage
        self.userIsShowVoiceCall = isShowVoiceCall
        self.userIsShowVideoCall = isShowVideoCall
        self.userIsShowClearHistory = isShowClearHistory
        self.userIsShowDeleteFriend = isShowDeleteFriend
        self.userItemCustomizer = itemCustomizer
    }
}
