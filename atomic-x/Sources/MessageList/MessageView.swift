import AtomicXCore
import AVFoundation
import QuickLook
import SwiftUI

/// Display mode for MessageView
enum MessageDisplayMode {
    case normal // Normal chat list mode
    case merged // Merged message detail mode (all messages left-aligned with avatar)
}

struct MessageView: View {
    @EnvironmentObject private var menuManager: MessageMenuManager
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject private var multiSelectManager: MultiSelectManager
    @Environment(\.messageListConfigProtocol) var config: MessageListConfigProtocol
    @Environment(\.locateMessageID) private var locateMessageID: String?
    @Environment(\.toggleMessageSelection) private var toggleMessageSelection: ((MessageInfo) -> Void)?
    @StateObject private var imageViewerManager: ImageViewerManager
    @State private var isShowingEditView = false
    @State private var longPressed = false
    @State private var messageBubbleFrame: CGRect = .zero
    @State private var showReactionDetail = false

    @State private var messageInputStore: MessageInputStore?
    let message: MessageInfo
    let onUserClick: ((String) -> Void)?
    let parentMessageList: [MessageInfo]
    let displayMode: MessageDisplayMode
    private var messageListStore: MessageListStore
    private var audioPlayer: AudioPlayer
    private var audioPlaybackManager: AudioPlaybackManager

    private var isSelected: Bool {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return false }
        return multiSelectManager.selectedMessageIDs.contains(msgID)
    }

    private var isMultiSelectMode: Bool {
        return multiSelectManager.isMultiSelectMode
    }

    private func shouldHighlightMessage(_ message: MessageInfo) -> Bool {
        let shouldHighlight = locateMessageID == message.id
        return shouldHighlight
    }

    var isLeft: Bool {
        // In merged mode, all messages are left-aligned
        if displayMode == .merged {
            return true
        }
        switch config.alignment {
        case 1:
            return true
        case 2:
            return false
        default:
            return !message.isSentBySelf
        }
    }

    /// Whether to show avatar (in merged mode, always show)
    private var shouldShowAvatar: Bool {
        if displayMode == .merged {
            return true
        }
        return isLeft ? config.isShowLeftAvatar : config.isShowRightAvatar
    }

    init(message: MessageInfo, messageListStore: MessageListStore, conversationID: String, audioPlayer: AudioPlayer, audioPlaybackManager: AudioPlaybackManager = AudioPlaybackManager(), onUserClick: ((String) -> Void)? = nil, parentMessageList: [MessageInfo], displayMode: MessageDisplayMode = .normal) {
        self.message = message
        self.messageListStore = messageListStore
        self.onUserClick = onUserClick
        self.audioPlayer = audioPlayer
        self.audioPlaybackManager = audioPlaybackManager
        self.parentMessageList = parentMessageList
        self.displayMode = displayMode
        self._messageInputStore = State(initialValue: nil)
        // In merged detail mode the sub-messages are not backed by a MessageListStore. Hand
        // them to ImageViewerManager so it can build the preview list statically instead of
        // calling `loadMessages` on an empty store (which would yield a black screen).
        let staticMessages: [MessageInfo]? = displayMode == .merged ? parentMessageList : nil
        self._imageViewerManager = StateObject(wrappedValue: ImageViewerManager(
            conversationID: conversationID,
            currentMessage: message,
            staticMessages: staticMessages
        ))
    }

    var body: some View {
        mainContent
            .modifier(MessageViewModifiers(
                messageBubbleFrame: $messageBubbleFrame,
                longPressed: $longPressed,
                menuManager: menuManager,
                message: message,
                style: config
            ))
            .fullScreenCover(isPresented: $imageViewerManager.isShowingImageViewer) {
                imageViewerManager.imageViewerContent()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            timeDisplayView
            contentView
        }
    }

    @ViewBuilder
    private var timeDisplayView: some View {
        if let timeString = getTimeString(), config.isShowTimeMessage {
            HStack {
                Spacer()
                Text(timeString)
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if message.status == .revoked {
            revokedMessageView
        } else if case .tips(let payload) = message.messagePayload {
            systemMessageView(payload)
        } else if case .custom(let payload) = message.messagePayload, isCustomSystemMessage(payload) {
            customSystemMessageView(payload)
        } else {
            messageContentWrapper
        }
    }

    @ViewBuilder
    private var revokedMessageView: some View {
        // Rendered in place of the original message so the chat history makes sense, e.g.
        // "You recalled a message" / ""xxx" recalled a message". Reuses the existing
        // localized strings and abstraction logic from MessageListHelper to stay in sync
        // with the conversation-list summary.
        let text = MessageListHelper.getMessageAbstract(message)
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(themeState.colors.textColorTertiary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func getTimeString() -> String? {
        guard let currentIndex = parentMessageList.firstIndex(where: { $0.msgID == message.msgID }) else {
            return nil
        }
        return getMessageTimeString(for: message, at: currentIndex, messageList: parentMessageList)
    }

    public func getMessageTimeString(for message: MessageInfo, at index: Int, messageList: [MessageInfo]) -> String? {
        guard let messageDate = date(from: message.timestamp) else { return nil }
        if index == 0 {
            return DateHelper.convertDateToYMDStr(messageDate)
        }
        let prev = index - 1
        guard prev >= 0, prev < messageList.count else { return nil }
        let previousMessage = messageList[prev]
        guard let previousDate = date(from: previousMessage.timestamp) else { return nil }
        let timeDifference = messageDate.timeIntervalSince(previousDate)
        let timeThreshold: TimeInterval = 300
        if timeDifference > timeThreshold {
            return DateHelper.convertDateToYMDStr(messageDate)
        }
        return nil
    }

    @ViewBuilder
    private var messageContentWrapper: some View {
        Group {
            if isLeft {
                HStack(alignment: .top, spacing: 0) {
                    // Checkbox in multi-select mode (left message)
                    if isMultiSelectMode {
                        MessageCheckBox(isSelected: isSelected)
                            .padding(.trailing, 8)
                            .onTapGesture {
                                toggleMessageSelection?(message)
                            }
                    }

                    userAvatar(isShow: shouldShowAvatar, isRight: false)
                    HStack(alignment: .top, spacing: 0) {
                        if config.isShowLeftNickname, let sender = message.from.nickname, !sender.isEmpty {
                            nicknameView(sender: sender)
                        }
                        messageContent(alignment: .leading)
                    }
                    Spacer(minLength: config.horizontalPadding)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // Checkbox in multi-select mode (right message - also at leading position)
                    if isMultiSelectMode {
                        MessageCheckBox(isSelected: isSelected)
                            .padding(.trailing, 8)
                            .onTapGesture {
                                toggleMessageSelection?(message)
                            }
                    }

                    Spacer(minLength: config.horizontalPadding)
                    if config.isShowRightNickname {
                        if let sender = message.from.nickname, !sender.isEmpty {
                            nicknameView(sender: sender)
                        }
                    }
                    messageContent(alignment: .trailing)
                    userAvatar(isShow: shouldShowAvatar, isRight: true)
                }
            }
        }
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: isLeft ? .leading : .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            if isMultiSelectMode {
                toggleMessageSelection?(message)
            }
        }
    }

    private func userAvatar(isShow: Bool, isRight: Bool) -> some View {
        Group {
            if isShow {
                Avatar(url: message.from.avatarURL ?? "", name: message.from.nickname ?? "")
                    .frame(width: 36, height: 36)
                    .padding(isRight ? .leading : .trailing, config.avatarSpacing)
                    .contentShape(Rectangle())
                    .scaleEffect(message.isSentBySelf ? 1.0 : 1.0)
                    .onTapGesture {
                        if !message.isSentBySelf {
                            onUserClick?(message.from.userID)
                        }
                    }
                    .onLongPressGesture {
                        // Long press to trigger mention user
                        if !message.isSentBySelf {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("mentionUserNotification"),
                                object: nil,
                                userInfo: [
                                    "userID": message.from.userID,
                                    "nickname": message.from.nickname ?? ""
                                ]
                            )
                        }
                    }
            }
        }
    }

    private func nicknameView(sender: String) -> some View {
        Text("\(sender):")
            .foregroundColor(themeState.colors.textColorPrimary)
            .padding(.leading, 2)
            .padding(.top, 8)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var sendFailIcon: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 16))
            .foregroundColor(themeState.colors.textColorError)
            .padding(.bottom, 2)
            .onTapGesture {
                print("MessageView: Send fail icon tapped")
                WindowAlertManager.shared.showAlert(
                    title: LocalizedChatString("TipsConfirmResendMessage"),
                    cancelText: LocalizedChatString("Cancel"),
                    confirmText: LocalizedChatString("Confirm"),
                    onConfirm: {
                        print("MessageView: Resend confirmed")
                        self.resendMessage(message)
                    }
                )
            }
    }

    private var sendingLoadingIcon: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: themeState.colors.textColorSecondary))
            .scaleEffect(0.8)
            .padding(.bottom, 2)
    }

    // Violation message icon (no tap action, no popup)
    private var violationIcon: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 16))
            .foregroundColor(themeState.colors.textColorError)
            .padding(.bottom, 2)
    }

    // Violation message hint text
    private var violationHintText: some View {
        Text(LocalizedChatString("MessageTypeSecurityStrikeInfo"))
            .font(.system(size: 12))
            .foregroundColor(themeState.colors.textColorError)
    }

    private func messageContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                if message.isSentBySelf && message.status == .sendFail {
                    sendFailIcon
                } else if message.isSentBySelf && message.status == .violation {
                    violationIcon
                } else if message.isSentBySelf && message.status == .sending {
                    sendingLoadingIcon
                }

                VStack(alignment: isLeft ? .leading : .trailing, spacing: 4) {
                    messageContentBody
                        .opacity(message.status == .sending ? 0.7 : 1.0)

                    // Message Reaction Bar
                    if config.isSupportReaction && !message.reactionList.isEmpty {
                        MessageReactionBar(
                            reactionList: message.reactionList,
                            isLeft: isLeft,
                            onClick: {
                                showReactionDetail = true
                            }
                        )
                        .environmentObject(themeState)
                    }
                }
                .scaleEffect(longPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.3), value: longPressed)

                if !message.isSentBySelf && message.status == .sendFail {
                    sendFailIcon
                } else if !message.isSentBySelf && message.status == .violation {
                    violationIcon
                } else if !message.isSentBySelf && message.status == .sending {
                    sendingLoadingIcon
                }
            }

            // Violation hint text below the bubble (outside HStack, aligned with bubble)
            if message.status == .violation {
                violationHintText
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showReactionDetail) {
            if config.isSupportReaction && !message.reactionList.isEmpty {
                let actionStore = MessageActionStore.create(
                    message: message
                )
                ReactionDetailSheet(
                    reactionList: message.reactionList,
                    currentUserID: LoginStore.shared.state.value.loginUserInfo?.userID ?? "",
                    onFetchUsers: { reactionID in
                        actionStore.loadReactionUsers(
                            reactionID: reactionID,
                            count: 100,
                            completion: nil
                        )
                    },
                    onRemoveReaction: { reactionID in
                        actionStore.removeReaction(
                            reactionID: reactionID,
                            completion: { result in
                                DispatchQueue.main.async {
                                    let message: String
                                    switch result {
                                    case .success:
                                        message = "Remove reaction success"
                                    case .failure(let error):
                                        print(">>>>> removeMessageReaction failed: \(error.code), \(error.message)")
                                        message = "Remove reaction failed: \(error.message)"
                                    }
                                    // Show alert on the topmost presented view controller (sheet)
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.windows.first?.rootViewController
                                    {
                                        var topVC = rootVC
                                        while let presented = topVC.presentedViewController {
                                            topVC = presented
                                        }
                                        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                                        topVC.present(alert, animated: true)
                                    }
                                }
                            }
                        )
                    }
                )
                .environmentObject(themeState)
                .bottomSheet()
            }
        }
        .onChange(of: message.reactionList.isEmpty) { isEmpty in
            if isEmpty {
                // Auto-dismiss sheet when all reactions are removed
                showReactionDetail = false
            } else {
                // Reaction bar appeared, notify to scroll
                NotificationCenter.default.post(
                    name: NSNotification.Name("reactionBarAppeared"),
                    object: nil,
                    userInfo: ["msgID": message.msgID]
                )
            }
        }
    }

    private func systemMessageView(_ payload: TipsMessagePayload) -> some View {
        guard let groupTips = payload.groupTips, config.isShowSystemMessage else {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack {
                Spacer()
                Text(MessageListHelper.getGroupTipsDisplayString(groupTips))
                    .font(.system(size: 12))
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.vertical, 4)
        )
    }

    private func isCustomSystemMessage(_ payload: CustomMessagePayload) -> Bool {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String
        else {
            return false
        }
        return businessID == "group_create"
    }

    private func customSystemMessageView(_ payload: CustomMessagePayload) -> some View {
        if config.isShowSystemMessage == false {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack {
                Spacer()
                if let data = payload.customData.data(using: .utf8),
                   let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
                   let businessID = customInfo["businessID"] as? String,
                   businessID == "group_create"
                {
                    let opUser = customInfo["opUser"] as? String ?? ""
                    let content = customInfo["content"] as? String ?? ""
                    let displayText = !opUser.isEmpty && !content.isEmpty ? "\(opUser) \(content)" : (opUser.isEmpty ? content : opUser)

                    if !displayText.isEmpty {
                        Text(displayText)
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorTertiary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        )
    }

    @ViewBuilder
    private var messageContentBody: some View {
        Group {
            if let payload = message.messagePayload {
                switch payload {
                case .merged:
                    MergeMessageView(message: message)
                        .allowsHitTesting(!isMultiSelectMode)
                case .text(let payload):
                    TextMessageView(
                        payload: payload,
                        message: message,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message)
                    )
                case .image(let payload):
                    ImageMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        onImageTap: imageViewerManager.showImageViewerIfAvailable
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                case .video(let payload):
                    VideoMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        onVideoTap: imageViewerManager.showImageViewerIfAvailable,
                        onPlayVideo: {
                            playVideoMessage(fallbackPayload: payload)
                        }
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                case .file(let payload):
                    FileMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message)
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                case .audio(let payload):
                    AudioMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message),
                        audioPlayer: audioPlayer,
                        audioPlaybackManager: audioPlaybackManager
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                default:
                    if config.isShowUnsupportMessage {
                        Text(LocalizedChatString("NotSupportThisMessage"))
                            .font(.system(size: 14))
                            .padding(12)
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                }
            } else {
                Text(LocalizedChatString("NoMessageContent"))
                    .font(.system(size: 14))
                    .padding(12)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
        }
        .background(
            GeometryReader { contentGeometry in
                Color.clear
                    .preference(
                        key: ViewPositionKey.self,
                        value: [contentGeometry.frame(in: .global)]
                    )
            }
        )
    }

    private func resendMessage(_ messageToResend: MessageInfo) {
        guard let payload = sendPayload(from: messageToResend) else { return }
        var option = SendMessageOption()
        option.needReadReceipt = messageToResend.needReadReceipt
        option.atUserList = messageToResend.atUserList.isEmpty ? nil : messageToResend.atUserList
        option.isExtensionEnabled = messageToResend.isExtensionEnabled
        option.offlinePushInfo = messageToResend.offlinePushInfo
        messageListStore.deleteMessages(messageList: [messageToResend]) { _ in }
        messageInputStore = MessageInputStore.create(conversationID: messageListStore.conversationID)
        messageInputStore?.sendMessage(payload: payload, option: option) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Message resent successfully")
                case .failure(let error):
                    print("Failed to resend message: \(error.code), \(error.message)")
                }
            }
        }
    }

    private func date(from timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private func currentVideoPayload(fallback: VideoMessagePayload) -> VideoMessagePayload {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .video(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return fallback
    }

    /// Decide how to play a video message: prefer a local file, otherwise stream from the
    /// remote URL (filled by `MessageActionStoreImpl.fillMediaURLsForMergedMessages` for
    /// merged sub-messages), otherwise trigger a download and retry on completion. This
    /// mirrors Android's strategy of letting the player consume either local path or URL.
    private func playVideoMessage(fallbackPayload: VideoMessagePayload) {
        let current = currentVideoPayload(fallback: fallbackPayload)
        if let videoPath = current.videoPath, !videoPath.isEmpty,
           FileManager.default.fileExists(atPath: videoPath)
        {
            presentVideo(uri: videoPath, localPath: videoPath)
            return
        }
        if let url = current.videoURL, !url.isEmpty {
            presentVideo(uri: url, localPath: nil)
            return
        }
        MessageActionStore.create(message: message).downloadMedia(quality: .standard) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    let refreshed = currentVideoPayload(fallback: fallbackPayload)
                    if let videoPath = refreshed.videoPath, !videoPath.isEmpty {
                        presentVideo(uri: videoPath, localPath: videoPath)
                    } else if let url = refreshed.videoURL, !url.isEmpty {
                        presentVideo(uri: url, localPath: nil)
                    }
                }
            case .failure(let error):
                print("\(LocalizedChatString("VideoDownloadFailed")): \(error.code), \(error.message)")
            }
        }
    }

    private func presentVideo(uri: String, localPath: String?) {
        let videoData = VideoData(
            uri: uri,
            localPath: localPath,
            width: 1920,
            height: 1080
        )
        // Use UIKit presentation in merged detail view to avoid dismissing the sheet
        if displayMode == .merged {
            VideoPlayer.shared.playWithUIKit(videoData: videoData)
        } else {
            VideoPlayer.shared.play(videoData: videoData)
        }
    }

    private func sendPayload(from message: MessageInfo) -> SendMessagePayload? {
        guard let payload = message.messagePayload else { return nil }
        switch payload {
        case .text(let text):
            return .text(TextSendMessagePayload(text: text.text))
        case .custom(let custom):
            return .custom(CustomSendMessagePayload(
                customData: custom.customData,
                description: custom.description,
                extensionInfo: custom.extensionInfo
            ))
        case .image(let image):
            guard let imagePath = image.originalImagePath else { return nil }
            return .image(ImageSendMessagePayload(
                imagePath: imagePath,
                imageWidth: image.originalImageWidth,
                imageHeight: image.originalImageHeight
            ))
        case .audio(let audio):
            guard let audioPath = audio.audioPath else { return nil }
            return .audio(AudioSendMessagePayload(audioFilePath: audioPath, duration: audio.audioDuration))
        case .video(let video):
            guard let videoPath = video.videoPath,
                  let snapshotPath = video.videoSnapshotPath else { return nil }
            return .video(VideoSendMessagePayload(
                videoFilePath: videoPath,
                videoType: video.videoType ?? "mp4",
                duration: video.videoDuration,
                snapshotPath: snapshotPath,
                snapshotWidth: video.videoSnapshotWidth,
                snapshotHeight: video.videoSnapshotHeight
            ))
        case .file(let file):
            guard let filePath = file.filePath else { return nil }
            return .file(FileSendMessagePayload(
                filePath: filePath,
                fileName: file.fileName ?? URL(fileURLWithPath: filePath).lastPathComponent,
                fileSize: file.fileSize
            ))
        case .face(let face):
            return .face(FaceSendMessagePayload(index: face.faceIndex, data: face.faceData ?? ""))
        case .tips, .merged, .stream:
            return nil
        }
    }
}
