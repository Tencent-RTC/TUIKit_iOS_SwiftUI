import AtomicXCore
import AVFoundation
import Foundation

// MARK: - MessageInputManager

class MessageInputManager {
    private let messageInputStore: MessageInputStore
    private var toast = Toast()
    init(messageInputStore: MessageInputStore) {
        self.messageInputStore = messageInputStore
    }
    var toastInstance: Toast {
        return toast
    }
    
    // MARK: - Text Message

    func sendTextMessage(_ text: String) {
        var message = MessageInfo()
        var messageBody = MessageBody()
        messageBody.text = text
        message.messageBody = messageBody
        message.messageType = .text
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
        case .failure(_):
            // Show toast for send failure with localized message
            DispatchQueue.main.async { [weak self] in
                self?.toast.simple(LocalizedChatString("TUIGroupNoteSendFail"))
            }
        }
    }
}
