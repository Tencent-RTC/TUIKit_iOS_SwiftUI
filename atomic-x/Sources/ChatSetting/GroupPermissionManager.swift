import AtomicXCore
import Foundation

// MARK: - Group Permission Enums

public enum GroupPermission: CaseIterable {
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
    case clearHistoryMessages
    case deleteAndQuit
    case transferOwner
    case dismissGroup
    case reportGroup
}

public class GroupPermissionManager {
    private static let permissionMatrix: [GroupType: [GroupMemberRole: [GroupPermission: Bool]]] = [
        .work: [
            .owner: [
                .setGroupName: true,
                .setGroupAvatar: true,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // no admin role in work group
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: true,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .admin: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: true,
                .removeGroupMember: false,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .member: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: true,
                .removeGroupMember: false,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
        ],
        .publicGroup: [
            .owner: [
                .setGroupName: true,
                .setGroupAvatar: true,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: true, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: false, // Owner cannot quit, must transfer ownership first
                .transferOwner: true,
                .dismissGroup: true,
                .reportGroup: true,
            ],
            .admin: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true, // Owner cannot quit, must transfer ownership first
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .member: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: false,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true, // Owner cannot quit, must transfer ownership first
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
        ],
        .meeting: [
            .owner: [
                .setGroupName: true,
                .setGroupAvatar: true,
                .sendMessage: true,
                .setDoNotDisturb: false,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: true, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: false, // Owner cannot quit, must transfer ownership first
                .transferOwner: true,
                .dismissGroup: true,
                .reportGroup: true,
            ],
            .admin: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: false,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true, // Owner cannot quit, must transfer ownership first
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .member: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: false,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: false,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true, // Owner cannot quit, must transfer ownership first
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
        ],
        .community: [
            .owner: [
                .setGroupName: true,
                .setGroupAvatar: true,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: true,
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: false,
                .transferOwner: true,
                .dismissGroup: true,
                .reportGroup: true,
            ],
            .admin: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: true,
                .setInviteToGroupApprovalType: true,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false, // Only owner can set roles
                .getGroupMemberInfo: true,
                .removeGroupMember: true,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .member: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: true,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: true,
                .removeGroupMember: false,
                .addGroupMember: true,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
        ],
        .avChatRoom: [
            .owner: [
                .setGroupName: true,
                .setGroupAvatar: true,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: true,
                .setGroupManagement: true,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: false,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: false,
                .removeGroupMember: false,
                .addGroupMember: false,
                .clearHistoryMessages: true,
                .deleteAndQuit: false,
                .transferOwner: false,
                .dismissGroup: true,
                .reportGroup: true,
            ],
            .admin: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: false,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: false,
                .removeGroupMember: false,
                .addGroupMember: false,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
            .member: [
                .setGroupName: false,
                .setGroupAvatar: false,
                .sendMessage: true,
                .setDoNotDisturb: true,
                .pinGroup: true,
                .setGroupNotice: false,
                .setGroupManagement: false,
                .getGroupType: true,
                .setJoinGroupApprovalType: false,
                .setInviteToGroupApprovalType: false,
                .setGroupRemark: true,
                .setBackground: true,
                .getGroupMemberList: false,
                .setGroupMemberRole: false,
                .getGroupMemberInfo: false,
                .removeGroupMember: false,
                .addGroupMember: false,
                .clearHistoryMessages: true,
                .deleteAndQuit: true,
                .transferOwner: false,
                .dismissGroup: false,
                .reportGroup: true,
            ],
        ],
    ]

    // MARK: - Public Methods

    public static func hasPermission(
        groupType: GroupType,
        memberRole: GroupMemberRole,
        permission: GroupPermission
    ) -> Bool {
        return permissionMatrix[groupType]?[memberRole]?[permission] ?? false
    }

    private static func getAvailablePermissions(
        groupType: GroupType,
        memberRole: GroupMemberRole
    ) -> [GroupPermission] {
        guard let rolePermissions = permissionMatrix[groupType]?[memberRole] else {
            return []
        }
        return rolePermissions.compactMap { permission, isAllowed in
            isAllowed ? permission : nil
        }
    }
}
