import AtomicXCore
import Foundation

public class MessageListHelper {
    public static func getSystemInfoDisplayString(_ systemMessages: [SystemMessageInfo]?) -> String {
        guard let systemMessages = systemMessages, !systemMessages.isEmpty else {
            return ""
        }
        
        let parts = systemMessages.compactMap { info -> String? in
            let result: String
            switch info {
            case .recallMessage:
                result = getRecallDisplayString(info)
            default:
                result = getGroupTipsDisplayString(info)
            }
            return result.isEmpty ? nil : result
        }
        
        return parts.isEmpty ? LocalizedChatString("unknown") : parts.joined(separator: "")
    }
    
    public static func getRecallDisplayString(_ systemInfo: SystemMessageInfo) -> String {
        guard case .recallMessage(_, let recallMessageOperator, let isRecalledBySelf, let isInGroup, let recallReason) = systemInfo else {
            return LocalizedChatString("MessageTipsNormalRecallMessage")
        }
        
        var str: String
        
        if isInGroup {
            str = String(format: LocalizedChatString("MessageTipsRecallMessageFormat"), recallMessageOperator)
        } else {
            if isRecalledBySelf {
                str = LocalizedChatString("MessageTipsYouRecallMessage")
            }
            else {
                str = LocalizedChatString("MessageTipsOthersRecallMessage")
            }
        }
        
        if !recallReason.isEmpty {
            str = "\(str): \(recallReason)"
        }
        
        return str
    }

    public static func getGroupTipsDisplayString(_ systemInfo: SystemMessageInfo) -> String {
        switch systemInfo {
        case .unknown:
            return ""
            
        case .joinGroup(_, let joinMember):
            return String(format: LocalizedChatString("MessageTipsJoinGroupFormat"), joinMember)
            
        case .inviteToGroup(_, let inviter, let inviteesShowName):
            return String(format: LocalizedChatString("MessageTipsInviteJoinGroupFormat"), inviter, inviteesShowName)
            
        case .quitGroup(_, let quitMember):
            return String(format: LocalizedChatString("MessageTipsLeaveGroupFormat"), quitMember)
            
        case .kickedFromGroup(_, let kickOperator, let kickedMembersShowName):
            return String(format: LocalizedChatString("MessageTipsKickoffGroupFormat"), kickOperator, kickedMembersShowName)
            
        case .setGroupAdmin(_, _, let setAdminMembersShowName):
            return String(format: LocalizedChatString("MessageTipsSettAdminFormat"), setAdminMembersShowName)
            
        case .cancelGroupAdmin(_, _, let cancelAdminMembersShowName):
            return String(format: LocalizedChatString("MessageTipsCancelAdminFormat"), cancelAdminMembersShowName)
            
        case .muteGroupMember(_, _, let isSelfMuted, let mutedGroupMembersShowName, let muteTime):
            let actualShowName = isSelfMuted ? LocalizedChatString("You") : mutedGroupMembersShowName
            return "\(actualShowName)\(muteTime == 0 ? LocalizedChatString("MessageTipsUnMute") : LocalizedChatString("MessageTipsMute"))"
            
        case .pinGroupMessage(_, let pinGroupMessageOperator):
            return String(format: LocalizedChatString("MessageTipsGroupPinMessage"), pinGroupMessageOperator)
            
        case .unpinGroupMessage(_, let unpinGroupMessageOperator):
            return String(format: LocalizedChatString("MessageTipsGroupUnPinMessage"), unpinGroupMessageOperator)
            
        case .changeGroupName(_, let groupNameOperator, let groupName):
            return String(format: LocalizedChatString("MessageTipsEditGroupNameFormat"), groupNameOperator, groupName)
            
        case .changeGroupIntroduction(_, let groupIntroductionOperator, let groupIntroduction):
            return String(format: LocalizedChatString("MessageTipsEditGroupIntroFormat"), groupIntroductionOperator, groupIntroduction)
            
        case .changeGroupNotification(_, let groupNotificationOperator, let groupNotification):
            let format = groupNotification.isEmpty ? LocalizedChatString("MessageTipsDeleteGroupAnnounceFormat") : LocalizedChatString("MessageTipsEditGroupAnnounceFormat")
            return String(format: format, groupNotificationOperator, groupNotification)
            
        case .changeGroupAvatar(_, let groupAvatarOperator, _):
            return String(format: LocalizedChatString("MessageTipsEditGroupAvatarFormat"), groupAvatarOperator)
            
        case .changeGroupOwner(_, let groupOwnerOperator, let groupOwner):
            return String(format: LocalizedChatString("MessageTipsEditGroupOwnerFormat"), groupOwnerOperator, groupOwner)
            
        case .changeGroupMuteAll(_, let groupMuteAllOperator, let isMuteAll):
            let format = isMuteAll ? LocalizedChatString("SetShutupAllFormatString") : LocalizedChatString("CancelShutupAllFormatString")
            return String(format: format, groupMuteAllOperator)
            
        case .changeJoinGroupApproval(_, let groupJoinApprovalOperator, let groupJoinOption):
            var desc = ""
            switch groupJoinOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileJoinDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupAddOptFormat"), groupJoinApprovalOperator, desc)
            
        case .changeInviteToGroupApproval(_, let groupInviteApprovalOperator, let groupInviteOption):
            var desc = ""
            switch groupInviteOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileInviteDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupInviteOptFormat"), groupInviteApprovalOperator, desc)
            
        case .recallMessage:
            return ""
        }
    }
    
    public static func getMessageAbstract(_ messageInfo: MessageInfo?) -> String {
        guard let messageInfo = messageInfo else { return "" }
        
        switch messageInfo.messageType {
        case .text:
            return messageInfo.messageBody?.text ?? ""
            
        case .image:
            return LocalizedChatString("MessageTypeImage")
            
        case .sound:
            return LocalizedChatString("MessageTypeVoice")
            
        case .file:
            return LocalizedChatString("MessageTypeFile")
            
        case .video:
            return LocalizedChatString("MessageTypeVideo")
            
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
            
        case .custom:
            if let data = messageInfo.messageBody?.customMessage?.data,
               let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
               let businessID = customInfo["businessID"] as? String,
               businessID == "group_create"
            {
                let sender = customInfo["opUser"] as? String ?? ""
                let cmd = customInfo["cmd"] as? Int ?? 0
                
                return String(format: cmd == 1 ? LocalizedChatString("TUICommunityCreateTipsMessage") : LocalizedChatString("TUIGroupCreateTipsMessage"), sender)
            }
            return LocalizedChatString("MessageTypeCustom")
            
        case .system:
            if let systemInfo = messageInfo.messageBody?.systemMessage {
                return getSystemInfoDisplayString(systemInfo)
            }
            return ""

        default:
            return ""
        }
    }
}
