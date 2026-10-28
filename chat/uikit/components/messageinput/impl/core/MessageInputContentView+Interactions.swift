import AVFoundation
import AVKit
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Combine
import QuickLook
import UniformTypeIdentifiers
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
import AtomicXCore

extension MessageInputContentView {
    func toggleVoiceInputMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isVoiceInputMode.toggle()
            isShowingEmojiPicker = false
            isShowingMorePanel = false
            isShowingQuickReplies = false
        }
        textEditorState.resignFirstResponder?()
        isInputFocused = false
        postInputInteract()
    }

    private func beginVoiceRecordingFromGesture() {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingEmojiPicker = false
            isShowingMorePanel = false
            isShowingQuickReplies = false
        }
        textEditorState.resignFirstResponder?()
        isInputFocused = false
        postInputInteract()
        // 同步设置长按状态，确保快速松手可取消尚未启动的录音。
        isLongPressingState = true
        shouldCancelRecording = false
        dragOffset = 0
        let work = DispatchWorkItem {
            voiceRecordController.beginRecording { outcome, path, duration in
                DispatchQueue.main.async {
                    isShowingAudioRecorder = false
                    handleVoiceRecordOutcome(outcome, path: path, duration: duration)
                }
            }
            isShowingAudioRecorder = true
        }
        voiceBeginWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func endVoiceRecordingFromGesture() {
        guard isLongPressingState else { return }
        isLongPressingState = false
        voiceBeginWorkItem?.cancel()
        voiceBeginWorkItem = nil
        voiceRecordController.endRecording()
    }

    func handleTextInputVoiceLongPress(state: UIGestureRecognizer.State, fingerGlobal: CGPoint) {
        switch state {
        case .began:
            guard inputStyle.enableLongPressToTalk,
                  !hasText,
                  !isVoiceInputMode,
                  !isShowingEmojiPicker,
                  !isShowingMorePanel
            else { return }
            voicePressStartGlobalY = fingerGlobal.y
            beginVoiceRecordingFromGesture()
        case .changed:
            guard isLongPressingState else { return }
            if let startY = voicePressStartGlobalY {
                dragOffset = startY - fingerGlobal.y
            }
            voiceRecordController.updateZone(fingerGlobal: fingerGlobal)
            shouldCancelRecording = voiceRecordController.activeZone == .cancel
        case .ended, .cancelled:
            voicePressStartGlobalY = nil
            endVoiceRecordingFromGesture()
        default:
            break
        }
    }

    func voicePressBegan(_ fingerGlobal: CGPoint) {
        voicePressStartGlobalY = fingerGlobal.y
        beginVoiceRecordingFromGesture()
    }

    func voicePressChanged(_ fingerGlobal: CGPoint) {
        guard isLongPressingState else { return }
        if let startY = voicePressStartGlobalY {
            dragOffset = startY - fingerGlobal.y
        }
        voiceRecordController.updateZone(fingerGlobal: fingerGlobal)
        shouldCancelRecording = voiceRecordController.activeZone == .cancel
    }

    func voicePressEnded() {
        voicePressStartGlobalY = nil
        endVoiceRecordingFromGesture()
    }

    func saveAndSendImage(_ imagePath: String) {
        sendImageMessage(imagePath)
        onSendImage?(URL(fileURLWithPath: imagePath))
    }

    func showAlbumPicker() {
        MessageInputAlbumPicker.shared.show(
            conversationID: conversationID,
            config: inputStyle,
            primaryColor: UIColor(themeState.colors.buttonColorPrimaryDefault)
        )
    }

    func createThumbnailAndSendVideo(_ videoPath: String, _ videoThumbnailPath: String?) {
        var thumbnailPath = videoThumbnailPath
        if videoThumbnailPath == nil {
            thumbnailPath = ChatUtil.generateMediaPath(messageType: .image, withExtension: nil)

            guard let thumbnailPath = thumbnailPath else {
                return
            }

            let directory = (thumbnailPath as NSString).deletingLastPathComponent
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {}

            if let thumbnail = createThumbnail(from: URL(fileURLWithPath: videoPath)) {
                if let imageData = thumbnail.jpegData(compressionQuality: 0.7) {
                    do {
                        try imageData.write(to: URL(fileURLWithPath: thumbnailPath))
                    } catch {
                        try? Data().write(to: URL(fileURLWithPath: thumbnailPath))
                    }
                } else {
                    try? Data().write(to: URL(fileURLWithPath: thumbnailPath))
                }
            } else {
                try? Data().write(to: URL(fileURLWithPath: thumbnailPath))
            }
        }

        if let thumbnailPath = thumbnailPath {
            sendVideoMessage(videoPath, thumbnailPath)
            onSendVideo?(URL(fileURLWithPath: videoPath), URL(fileURLWithPath: thumbnailPath))
        }
    }

    private func createThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            let thumbnailCGImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailCGImage)
        } catch {
            return nil
        }
    }

    func handleFileSelection(_ fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let filePath = ChatUtil.generateMediaPath(messageType: .file, withExtension: fileName)
        let directory = (filePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        let fullFilePath = (filePath as NSString).appendingPathExtension(fileURL.pathExtension)!
        do {
            if FileManager.default.fileExists(atPath: fullFilePath) {
                try FileManager.default.removeItem(atPath: fullFilePath)
            }
            try FileManager.default.copyItem(at: fileURL, to: URL(fileURLWithPath: fullFilePath))
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fullFilePath)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            if fileSize > 1000000000 || fileSize == 0 {
                WindowAlertManager.shared.showAlert(
                    message: LocalizedChatString("FileSizeCheckLimited"),
                    confirmText: LocalizedChatString("Confirm")
                )
                return
            }
            sendFileMessage(fullFilePath, fileName: fileName, fileSize: Int(fileSize))
            onSendFile?(URL(fileURLWithPath: fullFilePath), fileName, fileSize)
        } catch {}
    }

    func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphoneAuthorized = true
        case .denied:
            microphoneAuthorized = false
        case .undetermined:
            microphoneAuthorized = false
        @unknown default:
            microphoneAuthorized = false
        }
    }

    func sendTextMessage() {
        let text = getSendText()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var convertedMentionList: [MentionInfo] = []
        if let attributedString = textEditorState.displayText {
            for mention in mentionList {
                let convertedStartIndex = convertDisplayPositionToTextPosition(mention.startIndex, in: attributedString)
                let convertedMention = MentionInfo(
                    userID: mention.userID,
                    displayName: mention.displayName,
                    startIndex: convertedStartIndex,
                    length: mention.length
                )
                convertedMentionList.append(convertedMention)
            }
        }

        messageManager.sendTextMessage(text, mentionList: convertedMentionList, quotedMessage: quotedMessage)

        clearQuote()

        conversationStore.setConversationDraft(conversationID: conversationID, draft: nil, completion: nil)

        mentionList.removeAll()

        textEditorState.displayText = nil
        withAnimation {
            textHeight = 36
            isShowingQuickReplies = false
        }
    }

    private func sendImageMessage(_ imagePath: String) {
        messageManager.sendImageMessage(imagePath)
    }

    private func sendVideoMessage(_ videoPath: String, _ snapshotPath: String) {
        messageManager.sendVideoMessage(videoPath, snapshotPath)
    }

    private func sendFileMessage(_ filePath: String, fileName: String, fileSize: Int) {
        messageManager.sendFileMessage(filePath, fileName: fileName, fileSize: fileSize)
    }

    private func sendVoiceMessage(_ voicePath: String, duration: Int) {
        messageManager.sendVoiceMessage(voicePath, duration: duration)
    }

    private func handleVoiceRecordOutcome(_ outcome: VoiceRecordOutcome, path: String?, duration: Int) {
        textEditorState.resignFirstResponder?()
        isInputFocused = false
        switch outcome {
        case .send:
            if let path = path, !path.isEmpty {
                messageManager.sendVoiceMessage(path, duration: duration)
            }
        case .transcribe:
            if let path = path, !path.isEmpty {
                voiceTranscriptionController.transcribe(filePath: path, durationSec: duration)
                isShowingVoiceTranscription = true
            }
        case .cancel, .none:
            break
        }
    }

    func setQuoteMessage(_ message: MessageInfo) {
        quotedMessage = message
        if isVoiceInputMode {
            withAnimation(.easeInOut(duration: 0.2)) {
                isVoiceInputMode = false
            }
            // 等文本框重建并绑定新聚焦闭包后再弹键盘，避免调用已销毁视图的闭包。
            DispatchQueue.main.async {
                showKeyboard()
            }
        } else {
            showKeyboard()
        }
        postInputInteract()
    }

    func clearQuote() {
        quotedMessage = nil
    }

    func quoteSenderName(for message: MessageInfo) -> String {
        let sender = message.from
        if let remark = sender.friendRemark, !remark.isEmpty { return remark }
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }

    func setupTypingControllerIfNeeded() {
        guard inputStyle.enableTyping, conversationID.hasPrefix("c2c_") else { return }
        if let typingController = typingController {
            typingController.activate()
        } else {
            let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID
            typingController = TypingIndicatorController(conversationID: conversationID, currentUserID: currentUserID)
        }
    }

    func deleteLastCharacter() {
        textEditorState.deleteLastCharacter?()
    }

    func postInputInteract() {
        NotificationCenter.default.post(name: MessageInputView.didInteractNotification, object: nil)
    }

    func showKeyboard() {
        withAnimation(keyboardHandler.keyboardAnimation) {
            isShowingQuickReplies = false
            textEditorState.becomeFirstResponder?()
            isInputFocused = true
        }
    }

    func showEmojiPicker() {
        withAnimation(keyboardHandler.keyboardAnimation) {
            isShowingEmojiPicker = true
            isShowingQuickReplies = false
            isShowingMorePanel = false
            textEditorState.resignFirstResponder?()
            isInputFocused = false
        }
        postInputInteract()
    }

    func toggleMorePanel() {
        if isShowingMorePanel {
            hideMorePanel()
        } else {
            showMorePanel()
        }
    }

    private func showMorePanel() {
        withAnimation(keyboardHandler.keyboardAnimation) {
            isShowingEmojiPicker = false
            isShowingQuickReplies = false
            isShowingMorePanel = true
            textEditorState.resignFirstResponder?()
            isInputFocused = false
        }
        postInputInteract()
    }

    private func hideMorePanel() {
        withAnimation {
            isShowingMorePanel = false
        }
    }




    var isGroupChat: Bool {
        return conversationID.hasPrefix("group_")
    }

    var groupID: String {
        if conversationID.hasPrefix("group_") {
            return String(conversationID.dropFirst(6))
        }
        return conversationID
    }
}
