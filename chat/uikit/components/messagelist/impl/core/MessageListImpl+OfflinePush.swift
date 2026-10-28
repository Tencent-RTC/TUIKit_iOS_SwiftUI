import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

extension MessageListImpl {
    func createOfflinePushInfo(
        conversationID: String? = nil,
        message: MessageInfo? = nil,
        pushDescription: String? = nil
    ) -> OfflinePushInfo {
        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        let selfUserId = loginUserInfo?.userID ?? ""
        let selfName = loginUserInfo?.nickname ?? selfUserId

        let isGroup: Bool
        let groupId: String
        let title: String
        let description: String

        if let conversationID = conversationID {
            isGroup = conversationID.hasPrefix("group_")
            groupId = isGroup ? String(conversationID.dropFirst(6)) : ""

            let chatName = conversationStore.state.value.conversationList
                .first(where: { $0.conversationID == conversationID })?
                .title
                .flatMap { $0.isEmpty ? nil : $0 }

            title = isGroup ? (chatName ?? groupId) : selfName
        } else {
            isGroup = false
            groupId = ""
            title = selfName
        }

        if let pushDescription = pushDescription {
            description = trimPushDescription(pushDescription)
        } else if let message = message {
            description = trimPushDescription(getMessageTypeAbstract(message))
        } else {
            description = ""
        }

        let ext = createOfflinePushExtJson(
            isGroup: isGroup,
            senderId: isGroup ? groupId : selfUserId,
            senderNickName: title,
            faceUrl: loginUserInfo?.avatarURL,
            version: 1,
            action: 1,
            content: description,
            customData: nil
        )

        var pushInfo = OfflinePushInfo()
        pushInfo.title = title
        pushInfo.description = description
        pushInfo.extensionInfo = [
            "ext": ext,
            "AndroidOPPOChannelID": "tuikit",
            "AndroidHuaWeiCategory": "IM",
            "AndroidVIVOCategory": "IM",
            "AndroidHonorImportance": "NORMAL",
            "AndroidMeizuNotifyType": 1,
            "iOSInterruptionLevel": "time-sensitive",
            "enableIOSBackgroundNotification": false
        ]
        return pushInfo
    }

    private func getMessageTypeAbstract(_ message: MessageInfo) -> String {
        switch message.messageType {
        case .text:
            if case .text(let payload) = message.messagePayload {
                return EmojiManager.shared.createLocalizedStringFromEmojiCodes(payload.text)
            }
            return ""
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .file:
            return LocalizedChatString("MessageTypeFile")
        case .audio:
            return LocalizedChatString("MessageTypeVoice")
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
        case .merged:
            return LocalizedChatString("MessageTypeMergedHistory")
        default:
            return ""
        }
    }

    private func trimPushDescription(_ text: String, maxLength: Int = 50) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if normalized.count <= maxLength {
            return normalized
        }
        return String(normalized.prefix(maxLength))
    }

    private func createOfflinePushExtJson(
        isGroup: Bool,
        senderId: String,
        senderNickName: String,
        faceUrl: String?,
        version: Int,
        action: Int,
        content: String?,
        customData: String?
    ) -> String {
        var entity: [String: Any] = [
            "sender": senderId,
            "nickname": senderNickName,
            "chatType": isGroup ? 2 : 1,
            "version": version,
            "action": action
        ]
        if let content = content, !content.isEmpty {
            entity["content"] = content
        }
        if let faceUrl = faceUrl {
            entity["faceUrl"] = faceUrl
        }
        if let customData = customData {
            entity["customData"] = customData
        }
        let timPushFeatures: [String: Int] = [
            "fcmPushType": 0,
            "fcmNotificationType": 0
        ]
        let extDict: [String: Any] = [
            "entity": entity,
            "timPushFeatures": timPushFeatures
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: extDict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }
        return "{}"
    }
}
