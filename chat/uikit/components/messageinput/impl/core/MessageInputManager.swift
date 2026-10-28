import AtomicXCore
import AVFoundation
import Foundation


class MessageInputManager {
    private let messageInputStore: MessageInputStore
    private let conversationStore = ConversationListStore.create()
    private let config: ChatMessageInputConfig
    private var toast = Toast()
    private var conversationInfo: ConversationInfo?

    init(messageInputStore: MessageInputStore, config: ChatMessageInputConfig) {
        self.messageInputStore = messageInputStore
        self.config = config
        fetchConversationInfo()
    }

    private func fetchConversationInfo() {
        conversationStore.getConversationInfo(
            conversationID: messageInputStore.conversationID,
            completion: ConversationInfoHandler(
                onSuccess: { [weak self] conversationInfo in
                    self?.conversationInfo = conversationInfo
                },
                onFailure: { _, _ in }
            )
        )
    }

    var toastInstance: Toast {
        return toast
    }


    func sendTextMessage(_ text: String, mentionList: [MentionInfo] = [], quotedMessage: MessageInfo? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var option = createSendMessageOption(
            pushDescription: EmojiManager.shared.createLocalizedStringFromEmojiCodes(text)
        )
        if !mentionList.isEmpty {
            option.atUserList = mentionList.map { $0.userID }
        }
        if let quotedMessage = quotedMessage {
            option.quotedMessage = quotedMessage
        }

        messageInputStore.sendMessage(payload: .text(TextSendMessagePayload(text: text)), option: option, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }


    func sendImageMessage(_ imagePath: String) {
        var payload = ImageSendMessagePayload(imagePath: imagePath)
        if let image = UIImage(contentsOfFile: imagePath) {
            payload.imageWidth = Int(image.size.width)
            payload.imageHeight = Int(image.size.height)
        }
        messageInputStore.sendMessage(
            payload: .image(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeImage")),
            completion: { [weak self] result in
            self?.handleSendResult(result)
        }
        )
    }


    func sendVideoMessage(_ videoPath: String, _ snapshotPath: String) {
        var snapshotWidth = 0
        var snapshotHeight = 0
        if let image = UIImage(contentsOfFile: snapshotPath) {
            snapshotWidth = Int(image.size.width)
            snapshotHeight = Int(image.size.height)
        }
        let duration: Int = {
            let videoURL = URL(fileURLWithPath: videoPath)
            let asset = AVAsset(url: videoURL)
            let duration = asset.duration
            let durationInSeconds = CMTimeGetSeconds(duration)
            return Int(durationInSeconds)
        }()
        let payload = VideoSendMessagePayload(
            videoFilePath: videoPath,
            videoType: "mp4",
            duration: duration,
            snapshotPath: snapshotPath,
            snapshotWidth: snapshotWidth,
            snapshotHeight: snapshotHeight
        )
        messageInputStore.sendMessage(
            payload: .video(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeVideo")),
            completion: { [weak self] result in
            self?.handleSendResult(result)
        }
        )
    }


    func sendFileMessage(_ filePath: String, fileName: String, fileSize: Int) {
        let payload = FileSendMessagePayload(filePath: filePath, fileName: fileName, fileSize: fileSize)
        messageInputStore.sendMessage(
            payload: .file(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeFile")),
            completion: { [weak self] result in
            self?.handleSendResult(result)
        }
        )
    }


    func sendFaceMessage(groupIndex: Int, faceData: String) {
        let payload = FaceSendMessagePayload(index: groupIndex, data: faceData)
        messageInputStore.sendMessage(
            payload: .face(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeAnimateEmoji")),
            completion: { [weak self] result in
            self?.handleSendResult(result)
        }
        )
    }


    func sendVoiceMessage(_ voicePath: String, duration: Int) {
        let payload = AudioSendMessagePayload(audioFilePath: voicePath, duration: duration)
        messageInputStore.sendMessage(
            payload: .audio(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeVoice")),
            completion: { [weak self] result in
            self?.handleSendResult(result)
        }
        )
    }


    private func handleSendResult(_ result: Result<Void, ErrorInfo>) {
        switch result {
        case .success:
            break
        case .failure:
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("sendMessageFailureNotification"),
                    object: nil,
                    userInfo: ["reason": LocalizedChatString("TUIGroupNoteSendFail")]
                )
            }
        }
    }


    private func createSendMessageOption(pushDescription: String) -> SendMessageOption {
        var option = SendMessageOption()
        option.needReadReceipt = config.enableReadReceipt
        option.offlinePushInfo = createOfflinePushInfo(pushDescription: pushDescription)
        return option
    }

    private func createOfflinePushInfo(pushDescription: String) -> OfflinePushInfo {
        let conversationID = messageInputStore.conversationID
        let isGroup = conversationID.hasPrefix("group_")
        let groupId = isGroup ? String(conversationID.dropFirst(6)) : ""

        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        let selfUserId = loginUserInfo?.userID ?? ""
        let selfName = loginUserInfo?.nickname ?? selfUserId

        let chatName = conversationInfo?.title?.isEmpty == false
            ? conversationInfo?.title
            : nil

        let senderNickName = isGroup ? (chatName ?? groupId) : selfName

        let description = trimPushDescription(pushDescription)
        let ext = createOfflinePushExtJson(
            isGroup: isGroup,
            senderId: isGroup ? groupId : selfUserId,
            senderNickName: senderNickName,
            faceUrl: loginUserInfo?.avatarURL,
            version: 1,
            action: 1,
            content: description,
            customData: nil
        )

        var pushInfo = OfflinePushInfo()
        pushInfo.title = senderNickName
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

private final class ConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
