import AtomicXCore
import Foundation

internal enum GroupPermission: CaseIterable {
    case setGroupName
    case setGroupAvatar
    case sendMessage
    case setDoNotDisturb
    case pinGroup
    case setGroupNotice
    case setGroupManagement
    case getGroupType
    case setJoinGroupApprovalType
    case setInviteToGroupApprovalType
    case setGroupRemark
    case setBackground
    case getGroupMemberList
    case setGroupMemberRole
    case getGroupMemberInfo
    case removeGroupMember
    case addGroupMember
    case muteMember
    case clearHistoryMessages
    case deleteAndQuit
    case transferOwner
    case dismissGroup
    case reportGroup
}
