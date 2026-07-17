import AtomicXCore
import Foundation

public class MessageListHelper {
    public static func getGroupTipsDisplayString(_ groupTips: [GroupTipsInfo]?) -> String {
        guard let groupTips = groupTips, !groupTips.isEmpty else {
            return ""
        }
        
        let parts = groupTips.compactMap { info -> String? in
            let result = getGroupTipDisplayString(info)
            return result.isEmpty ? nil : result
        }
        
        return parts.isEmpty ? LocalizedChatString("unknown") : parts.joined(separator: LocalizedChatString("MessageTipsSeparator"))
    }

    public static func getGroupTipDisplayString(_ groupTip: GroupTipsInfo) -> String {
        switch groupTip {
        case .unknown:
            return ""
            
        case .joinGroup(let joinMember):
            return String(format: LocalizedChatString("MessageTipsJoinGroupFormat"), displayName(joinMember))
            
        case .inviteToGroup(let inviter, let invitees):
            let inviteesShowName = invitees.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsInviteJoinGroupFormat"), displayName(inviter), inviteesShowName)
            
        case .quitGroup(let quitMember):
            return String(format: LocalizedChatString("MessageTipsLeaveGroupFormat"), displayName(quitMember))
            
        case .kickedFromGroup(let opUser, let kickedMembers):
            let kickedMembersShowName = kickedMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsKickoffGroupFormat"), displayName(opUser), kickedMembersShowName)
            
        case .setGroupAdmin(_, let setAdminMembers):
            let setAdminMembersShowName = setAdminMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsSettAdminFormat"), setAdminMembersShowName)
            
        case .cancelGroupAdmin(_, let cancelAdminMembers):
            let cancelAdminMembersShowName = cancelAdminMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsCancelAdminFormat"), cancelAdminMembersShowName)
            
        case .muteGroupMember(_, let isSelfMuted, let mutedGroupMembers, let muteTime):
            let mutedGroupMembersShowName = mutedGroupMembers.map { displayName($0) }.joined(separator: ", ")
            let actualShowName = isSelfMuted ? LocalizedChatString("You") : mutedGroupMembersShowName
            return "\(actualShowName)\(muteTime == 0 ? LocalizedChatString("MessageTipsUnmute") : LocalizedChatString("MessageTipsMute"))"
            
        case .pinGroupMessage(let opUser):
            return String(format: LocalizedChatString("MessageTipsGroupPinMessage"), displayName(opUser))
            
        case .unpinGroupMessage(let opUser):
            return String(format: LocalizedChatString("MessageTipsGroupUnPinMessage"), displayName(opUser))
            
        case .changeGroupName(let opUser, let groupName):
            return String(format: LocalizedChatString("MessageTipsEditGroupNameFormat"), displayName(opUser), groupName)
            
        case .changeGroupIntroduction(let opUser, let groupIntroduction):
            return String(format: LocalizedChatString("MessageTipsEditGroupIntroFormat"), displayName(opUser), groupIntroduction)
            
        case .changeGroupNotification(let opUser, let groupNotification):
            let format = groupNotification.isEmpty ? LocalizedChatString("MessageTipsDeleteGroupAnnounceFormat") : LocalizedChatString("MessageTipsEditGroupAnnounceFormat")
            return String(format: format, displayName(opUser), groupNotification)
            
        case .changeGroupAvatar(let opUser, _):
            return String(format: LocalizedChatString("MessageTipsEditGroupAvatarFormat"), displayName(opUser))
            
        case .changeGroupOwner(let opUser, let groupOwner):
            return String(format: LocalizedChatString("MessageTipsEditGroupOwnerFormat"), displayName(opUser), groupOwner)
            
        case .changeGroupMuteAll(let opUser, let isMuteAll):
            let format = isMuteAll ? LocalizedChatString("SetShutupAllFormatString") : LocalizedChatString("CancelShutupAllFormatString")
            return String(format: format, displayName(opUser))
            
        case .changeJoinGroupApproval(let opUser, let groupJoinOption):
            var desc = ""
            switch groupJoinOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileJoinDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupAddOptFormat"), displayName(opUser), desc)
            
        case .changeInviteToGroupApproval(let opUser, let groupInviteOption):
            var desc = ""
            switch groupInviteOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileInviteDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupInviteOptFormat"), displayName(opUser), desc)
        }
    }
    
    /// Get message abstract for display
    /// - Parameters:
    ///   - messageInfo: The message to get abstract from
    ///   - showMergedTitle: If true, show merged message's title; if false, show "[聊天记录]"
    /// - Returns: Message abstract string
    public static func getMessageAbstract(_ messageInfo: MessageInfo?, showMergedTitle: Bool = false) -> String {
        guard let messageInfo = messageInfo else { return "" }
        
        // Show recall status instead of original content for revoked messages
        if messageInfo.status == .revoked {
            if messageInfo.isSentBySelf {
                return LocalizedChatString("MessageTipsYouRecallMessage")
            } else if messageInfo.conversationType == .c2c {
                return LocalizedChatString("MessageTipsOthersRecallMessage")
            } else {
                return String(format: LocalizedChatString("MessageTipsRecallMessageFormat"), messageInfo.from.userID)
            }
        }
        
        switch messageInfo.messageType {
        case .text:
            if case .text(let payload) = messageInfo.messagePayload {
                return payload.text
            }
            return ""
            
        case .image:
            return LocalizedChatString("MessageTypeImage")
            
        case .audio:
            return LocalizedChatString("MessageTypeVoice")
            
        case .file:
            return LocalizedChatString("MessageTypeFile")
            
        case .video:
            return LocalizedChatString("MessageTypeVideo")
            
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
            
        case .custom:
            if case .custom(let payload) = messageInfo.messagePayload,
               let data = payload.customData.data(using: .utf8),
               let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
               let businessID = customInfo["businessID"] as? String,
               businessID == "group_create"
            {
                let sender = customInfo["opUser"] as? String ?? ""
                let cmd = customInfo["cmd"] as? Int ?? 0
                
                return String(format: cmd == 1 ? LocalizedChatString("TUICommunityCreateTipsMessage") : LocalizedChatString("TUIGroupCreateTipsMessage"), sender)
            }
            return LocalizedChatString("MessageTypeCustom")
            
        case .tips:
            if case .tips(let payload) = messageInfo.messagePayload {
                return getGroupTipsDisplayString(payload.groupTips)
            }
            return ""
            
        case .merged:
            if showMergedTitle, case .merged(let payload) = messageInfo.messagePayload, !payload.title.isEmpty {
                let title = payload.title
                return title
            }
            return LocalizedChatString("MessageTypeMergedHistory")

        default:
            return ""
        }
    }
    
    static func shouldShowReadReceipt(message: MessageInfo, isInMergedDetailView: Bool = false) -> Bool {
        return !isInMergedDetailView &&
            message.isSentBySelf &&
            message.needReadReceipt &&
            message.status == .sendSuccess &&
            message.messageType != .tips
    }
    
    static func getReceiptIconName(message: MessageInfo) -> String {
        if message.conversationType != .group {
            if message.readReceiptInfo?.isPeerRead == true {
                return "check-all-highlight"
            } else {
                return "check"
            }
        } else {
            let readCount = message.readReceiptInfo?.readCount ?? 0
            let unreadCount = message.readReceiptInfo?.unreadCount ?? 0
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
    
    // MARK: - Message Forwarding
    
    /// Generates a message abstract for merged forwarding.
    public static func getMessageAbstractForForward(_ message: MessageInfo) -> String {
        let senderName: String
        if let nickname = message.from.nickname, !nickname.isEmpty {
            senderName = nickname
        } else {
            senderName = message.from.userID
        }
        let content = getMessageAbstract(message)
        return alignEmojiString(userName: senderName, text: content)
    }
    
    private static func alignEmojiString(userName: String, text: String) -> String {
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
            let sender = message.from.userID
                if !seenSenders.contains(sender) {
                    seenSenders.insert(sender)
                    // Use nickName, fallback to sender ID
                    let name = message.from.nickname ?? sender
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
    
    /// Generates merged forward abstract list, capped at four messages.
    public static func generateAbstractList(messages: [MessageInfo]) -> [String] {
        let maxAbstracts = 4
        return messages.prefix(maxAbstracts).map { message in
            getMessageAbstractForForward(message)
        }
    }

    private static func displayName(_ member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty {
            return nameCard
        }
        if let remark = member.friendRemark, !remark.isEmpty {
            return remark
        }
        if let nickname = member.nickname, !nickname.isEmpty {
            return nickname
        }
        return member.userID
    }
}
