import SwiftUI

internal protocol C2CChatSettingConfigProtocol {
    var isShowHeader: Bool { get }
    var isShowRemark: Bool { get }
    var isShowDoNotDisturb: Bool { get }
    var isShowPin: Bool { get }
    var isShowChatBackground: Bool { get }
    var isShowBlacklist: Bool { get }
    var isShowSendMessage: Bool { get }
    var isShowVoiceCall: Bool { get }
    var isShowVideoCall: Bool { get }
    var isShowClearHistory: Bool { get }
    var isShowDeleteFriend: Bool { get }
    var itemCustomizer: C2CChatSettingItemCustomizer? { get }
}

internal extension C2CChatSettingConfigProtocol {
    var itemCustomizer: C2CChatSettingItemCustomizer? { nil }
}
