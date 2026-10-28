import AtomicXCore
import SwiftUI

public struct GroupChatSettingView: View {
    private let implementation: GroupChatSettingImpl

    public init(
        groupID: String,
        config: GroupChatSettingConfig? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onGroupDelete: (() -> Void)? = nil,
        onGroupMemberClick: ((String) -> Void)? = nil,
        memberDetailDestination: ((String) -> AnyView)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        implementation = GroupChatSettingImpl(
            groupID: groupID,
            config: config,
            onSendMessageClick: onSendMessageClick,
            onGroupDelete: onGroupDelete,
            onGroupMemberClick: onGroupMemberClick,
            memberDetailDestination: memberDetailDestination,
            onBack: onBack
        )
    }

    public var body: some View { implementation }
}
