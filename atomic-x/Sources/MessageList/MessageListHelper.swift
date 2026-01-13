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
            } else {
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
            return "\(actualShowName)\(muteTime == 0 ? LocalizedChatString("MessageTipsUnmute") : LocalizedChatString("MessageTipsMute"))"
            
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
    
    /// Get message abstract for display
    /// - Parameters:
    ///   - messageInfo: The message to get abstract from
    ///   - showMergedTitle: If true, show merged message's title; if false, show "[聊天记录]"
    /// - Returns: Message abstract string
    public static func getMessageAbstract(_ messageInfo: MessageInfo?, showMergedTitle: Bool = false) -> String {
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
            
        case .merged:
            if showMergedTitle, let title = messageInfo.messageBody?.mergedMessage?.title, !title.isEmpty {
                return title
            }
            return LocalizedChatString("MessageTypeMergedHistory")

        default:
            return ""
        }
    }
    
    static func shouldShowReadReceipt(message: MessageInfo, isInMergedDetailView: Bool = false) -> Bool {
        return !isInMergedDetailView &&
            message.isSelf &&
            message.needReadReceipt &&
            message.status == .sendSuccess &&
            message.messageType != .system
    }
    
    static func getReceiptIconName(message: MessageInfo) -> String {
        if message.groupID == nil || message.groupID?.isEmpty == true {
            if message.receipt?.isPeerRead == true {
                return "check-all-highlight"
            } else {
                return "check"
            }
        } else {
            let readCount = message.receipt?.readCount ?? 0
            let unreadCount = message.receipt?.unreadCount ?? 0
            let totalCount = readCount + unreadCount

            if readCount == 0 {
                return "check"
            } else if readCount == totalCount && totalCount > 0 {
                return "check-all-highlight"
            } else {
                return "check-all"
            }
        }
    }
    
    // MARK: - 消息转发相关
    
    /// 生成消息摘要（用于合并转发）
    public static func getMessageAbstractForForward(_ message: MessageInfo) -> String {
        let senderName: String
        if let nickname = message.sender.nickname, !nickname.isEmpty {
            senderName = nickname
        } else {
            senderName = message.sender.userID
        }
        let content = getMessageAbstract(message)
        return alignEmojiString(userName: senderName, text: content)
    }
    
    /// 对齐 Emoji 和用户名（处理中文字符对齐问题）
    private static func alignEmojiString(userName: String, text: String) -> String {
        // 简化版本：直接返回 "用户名: 内容"
        // 如果需要复杂的对齐逻辑（如Android），后续可以增强
        return "\(userName): \(text)"
    }
    
    /// Generate merged forward message title
    /// - Parameters:
    ///   - messages: Messages to be forwarded
    ///   - conversationID: Current conversation ID, used to determine C2C or group chat
    /// - Returns: Merged message title
    public static func generateMergedTitle(messages: [MessageInfo], conversationID: String) -> String {
        // Check if it's a group chat (conversationID starts with "group_")
        let isGroupChat = conversationID.hasPrefix("group_")
        
        if isGroupChat {
            // Group chat: return "群聊的聊天记录"
            return LocalizedChatString("RelayGroupChatHistory")
        } else {
            // C2C chat: collect unique senders in order of appearance
            var senderNames: [String] = []
            var seenSenders: Set<String> = []
            
            for message in messages {
                let sender = message.sender.userID
                if !seenSenders.contains(sender) {
                    seenSenders.insert(sender)
                    // Use nickName, fallback to sender ID
                    let name = message.sender.nickname ?? sender
                    senderNames.append(name)
                }
                // Only need at most 2 senders for C2C
                if senderNames.count >= 2 {
                    break
                }
            }
            
            if senderNames.count == 2 {
                // Two senders: "A 和 B 的聊天记录"
                return String(format: LocalizedChatString("RelayChatHistoryForSomebodyFormat"), senderNames[0], senderNames[1])
            } else if senderNames.count == 1 {
                // One sender: "A 的聊天记录"
                return String(format: LocalizedChatString("RelayC2CChatHistoryFormat"), senderNames[0])
            } else {
                // Fallback
                return LocalizedChatString("RelayChatHistory")
            }
        }
    }
    
    /// 生成合并转发的摘要列表（最多4条）
    public static func generateAbstractList(messages: [MessageInfo]) -> [String] {
        let maxAbstracts = 4
        return messages.prefix(maxAbstracts).map { message in
            getMessageAbstractForForward(message)
        }
    }
}
