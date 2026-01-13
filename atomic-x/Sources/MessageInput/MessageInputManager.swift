import AtomicXCore
import AVFoundation
import Foundation

// MARK: - MessageInputManager

class MessageInputManager {
    private let messageInputStore: MessageInputStore
    private let conversationStore = ConversationListStore.create()
    private let config: MessageInputConfigProtocol
    private var toast = Toast()
    private var conversationInfo: ConversationInfo?

    init(messageInputStore: MessageInputStore, config: MessageInputConfigProtocol) {
        self.messageInputStore = messageInputStore
        self.config = config
        fetchConversationInfo()
    }

    private func fetchConversationInfo() {
        conversationStore.fetchConversationInfo(messageInputStore.conversationID) { [weak self] result in
            guard let self = self else { return }
            if case .success = result {
                self.conversationInfo = self.conversationStore.state.value.conversationList.first {
                    $0.conversationID == self.messageInputStore.conversationID
                }
            }
        }
    }

    var toastInstance: Toast {
        return toast
    }

    // MARK: - Text Message

    func sendTextMessage(_ text: String, mentionList: [MentionInfo] = []) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.text = text
        message.messageBody = messageBody
        message.messageType = .text
        message.needReadReceipt = config.enableReadReceipt
        message.offlinePushInfo = createOfflinePushInfo(for: message)

        // Set atUserList if there are mentions
        if !mentionList.isEmpty {
            message.atUserList = mentionList.map { $0.userID }
        }

        messageInputStore.sendMessage(message, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }

    // MARK: - Image Message

    func sendImageMessage(_ imagePath: String) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.originalImagePath = imagePath
        if let image = UIImage(contentsOfFile: imagePath) {
            messageBody.originalImagePath = imagePath
            messageBody.originalImageWidth = Int(image.size.width)
            messageBody.originalImageHeight = Int(image.size.height)
        }
        message.messageBody = messageBody
        message.messageType = .image
        message.needReadReceipt = config.enableReadReceipt
        message.offlinePushInfo = createOfflinePushInfo(for: message)
        messageInputStore.sendMessage(message, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }

    // MARK: - Video Message

    func sendVideoMessage(_ videoPath: String, _ snapshotPath: String) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.videoPath = videoPath
        messageBody.videoSnapshotPath = snapshotPath
        messageBody.videoType = "mp4"
        if let image = UIImage(contentsOfFile: snapshotPath) {
            messageBody.videoSnapshotPath = snapshotPath
            messageBody.videoSnapshotWidth = Int(image.size.width)
            messageBody.videoSnapshotHeight = Int(image.size.height)
        }
        messageBody.videoDuration = {
            let videoURL = URL(fileURLWithPath: videoPath)
            let asset = AVAsset(url: videoURL)
            let duration = asset.duration
            let durationInSeconds = CMTimeGetSeconds(duration)
            return Int(durationInSeconds)
        }()
        message.messageBody = messageBody
        message.messageType = .video
        message.needReadReceipt = config.enableReadReceipt
        message.offlinePushInfo = createOfflinePushInfo(for: message)
        messageInputStore.sendMessage(message, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }

    // MARK: - File Message

    func sendFileMessage(_ filePath: String, fileName: String, fileSize: Int) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.filePath = filePath
        messageBody.fileName = fileName
        messageBody.fileSize = Int32(fileSize)
        message.messageBody = messageBody
        message.messageType = .file
        message.needReadReceipt = config.enableReadReceipt
        message.offlinePushInfo = createOfflinePushInfo(for: message)
        messageInputStore.sendMessage(message, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }

    // MARK: - Voice Message

    func sendVoiceMessage(_ voicePath: String, duration: Int) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.soundPath = voicePath
        messageBody.soundDuration = duration
        message.messageBody = messageBody
        message.messageType = .sound
        message.needReadReceipt = config.enableReadReceipt
        message.offlinePushInfo = createOfflinePushInfo(for: message)
        messageInputStore.sendMessage(message, completion: { [weak self] result in
            self?.handleSendResult(result)
        })
    }

    // MARK: - Private Methods

    private func handleSendResult(_ result: Result<Void, ErrorInfo>) {
        switch result {
        case .success:
            // Message sent successfully - no action needed
            break
        case .failure:
            // Show toast for send failure with localized message
            DispatchQueue.main.async { [weak self] in
                self?.toast.simple(LocalizedChatString("TUIGroupNoteSendFail"))
            }
        }
    }

    // MARK: - Offline Push Info

    private func createOfflinePushInfo(for message: MessageInfo) -> OfflinePushInfo {
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

        let description = createOfflinePushDescription(for: message)
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

    private func createOfflinePushDescription(for message: MessageInfo) -> String {
        let content: String
        switch message.messageType {
        case .text:
            content = EmojiManager.shared.createLocalizedStringFromEmojiCodes(message.messageBody?.text ?? "")
        case .image:
            content = LocalizedChatString("MessageTypeImage")
        case .video:
            content = LocalizedChatString("MessageTypeVideo")
        case .file:
            content = LocalizedChatString("MessageTypeFile")
        case .sound:
            content = LocalizedChatString("MessageTypeVoice")
        case .face:
            content = LocalizedChatString("MessageTypeAnimateEmoji")
        case .merged:
            content = LocalizedChatString("MessageTypeMergedHistory")
        default:
            content = ""
        }
        return trimPushDescription(content)
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
