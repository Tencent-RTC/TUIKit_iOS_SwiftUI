import AtomicXCore
import Foundation

internal class GroupPermissionManager {
    internal static func hasPermission(
        groupType: GroupType,
        memberRole: GroupMemberRole,
        permission: GroupPermission
    ) -> Bool {
        GroupPermissionManagerImpl.hasPermission(groupType: groupType, memberRole: memberRole, permission: permission)
    }
}
