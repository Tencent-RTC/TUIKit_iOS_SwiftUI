import AtomicXCore
import SwiftUI

public final class C2CChatSettingConfig {
    // 资料
    public var userIsShowHeader: Bool? = nil
    public var userIsShowRemark: Bool? = nil

    // 会话设置
    public var userIsShowDoNotDisturb: Bool? = nil
    public var userIsShowPin: Bool? = nil
    public var userIsShowChatBackground: Bool? = nil

    // 联系人关系
    public var userIsShowBlacklist: Bool? = nil

    // 消息与通话
    public var userIsShowSendMessage: Bool? = nil
    public var userIsShowVoiceCall: Bool? = nil
    public var userIsShowVideoCall: Bool? = nil

    // 历史与删除
    public var userIsShowClearHistory: Bool? = nil
    public var userIsShowDeleteFriend: Bool? = nil

    // 扩展
    public var userItemCustomizer: C2CChatSettingItemCustomizer? = nil
}

public final class GroupChatSettingConfig {
    // 群资料
    public var userIsShowHeader: Bool? = nil
    public var userIsShowMemberPreview: Bool? = nil
    public var userIsShowNotice: Bool? = nil

    // 群管理与加入方式
    public var userIsShowManagement: Bool? = nil
    public var userIsShowGroupType: Bool? = nil
    public var userIsShowJoinMethod: Bool? = nil
    public var userIsShowInviteMethod: Bool? = nil

    // 个人群设置
    public var userIsShowAlias: Bool? = nil
    public var userIsShowDoNotDisturb: Bool? = nil

    // 会话设置
    public var userIsShowPin: Bool? = nil
    public var userIsShowChatBackground: Bool? = nil

    // 群操作
    public var userIsShowTransferOwner: Bool? = nil
    public var userIsShowClearHistory: Bool? = nil
    public var userIsShowDeleteAndQuit: Bool? = nil
    public var userIsShowDismiss: Bool? = nil

    // 扩展
    public var userItemCustomizer: GroupChatSettingItemCustomizer? = nil
}

public enum C2CChatSettingSection {
    case header
    case remark
    case switches
    case background
    case blacklist
    case actions
    case end
}

public enum GroupChatSettingSection {
    case header
    case memberPreview
    case settings
    case alias
    case switches
    case background
    case actions
    case end
}

public final class ChatSettingItemEditor<Section> {
    private(set) var customRows: [(section: Section, row: AnyView)] = []

    public init() {}

    public func addCustomRow(_ view: AnyView, after section: Section) {
        customRows.append((section, view))
    }
}

public typealias C2CChatSettingItemCustomizer = (ChatSettingItemEditor<C2CChatSettingSection>) -> Void
public typealias GroupChatSettingItemCustomizer = (ChatSettingItemEditor<GroupChatSettingSection>) -> Void
