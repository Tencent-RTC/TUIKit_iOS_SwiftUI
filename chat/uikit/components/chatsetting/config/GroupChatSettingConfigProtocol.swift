import SwiftUI

internal protocol GroupChatSettingConfigProtocol {
    var isShowHeader: Bool { get }
    var isShowMemberPreview: Bool { get }
    var isShowNotice: Bool { get }
    var isShowManagement: Bool { get }
    var isShowGroupType: Bool { get }
    var isShowJoinMethod: Bool { get }
    var isShowInviteMethod: Bool { get }
    var isShowAlias: Bool { get }
    var isShowDoNotDisturb: Bool { get }
    var isShowPin: Bool { get }
    var isShowChatBackground: Bool { get }
    var isShowTransferOwner: Bool { get }
    var isShowClearHistory: Bool { get }
    var isShowDeleteAndQuit: Bool { get }
    var isShowDismiss: Bool { get }
    var itemCustomizer: GroupChatSettingItemCustomizer? { get }
}

internal extension GroupChatSettingConfigProtocol {
    var itemCustomizer: GroupChatSettingItemCustomizer? { nil }
}
