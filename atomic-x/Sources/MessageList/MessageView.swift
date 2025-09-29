import AtomicXCore
import AVFoundation
import ImSDK_Plus
import QuickLook
import SwiftUI

struct MessageView: View {
    @EnvironmentObject private var menuManager: MessageMenuManager
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.MessageListConfigProtocol) var style: MessageListConfigProtocol
    @Environment(\.locateMessageID) private var locateMessageID: String?
    @StateObject private var imageViewerManager: ImageViewerManager
    @State private var isShowingEditView = false
    @State private var longPressed = false
    @State private var messageBubbleFrame: CGRect = .zero

    @State private var messageInputStore: MessageInputStore?
    let message: MessageInfo
    let onUserClick: ((String) -> Void)?
    let parentMessageList: [MessageInfo]  
    private var messageListStore: MessageListStore
    private var audioPlayer: AudioPlayer

    private func shouldHighlightMessage(_ message: MessageInfo) -> Bool {
        let shouldHighlight = locateMessageID == message.id
        return shouldHighlight
    }

    var isLeft: Bool {
        switch style.alignment {
        case 1:
            return true
        case 2:
            return false
        default:
            return !message.isSelf
        }
    }

    init(message: MessageInfo, messageListStore: MessageListStore, conversationID: String, audioPlayer: AudioPlayer, onUserClick: ((String) -> Void)? = nil, parentMessageList: [MessageInfo]) {
        self.message = message
        self.messageListStore = messageListStore
        self.onUserClick = onUserClick
        self.audioPlayer = audioPlayer
        self.parentMessageList = parentMessageList  
        self._messageInputStore = State(initialValue: nil)
        self._imageViewerManager = StateObject(wrappedValue: ImageViewerManager(
            conversationID: conversationID,
            currentMessage: message
        ))
    }

    var body: some View {
        mainContent
            .modifier(MessageViewModifiers(
                messageBubbleFrame: $messageBubbleFrame,
                longPressed: $longPressed,
                menuManager: menuManager,
                message: message,
                style: style
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
        if let timeString = getTimeString(), style.isShowTimeMessage {
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
        if let messageBody = message.messageBody, message.messageType == .system {
            systemMessageView(messageBody)
        } else if let messageBody = message.messageBody, message.messageType == .custom, isCustomSystemMessage(messageBody) {
            customSystemMessageView(messageBody)
        } else {
            messageContentWrapper
        }
    }

    private func getTimeString() -> String? {
        guard let currentIndex = parentMessageList.firstIndex(where: { $0.msgID == message.msgID }) else {
            return nil
        }
        return getMessageTimeString(for: message, at: currentIndex, messageList: parentMessageList)
    }

    public func getMessageTimeString(for message: MessageInfo, at index: Int, messageList: [MessageInfo]) -> String? {
        guard let messageDate = message.timestamp else { return nil }
        if index == 0 {
            return DateHelper.convertDateToYMDStr(messageDate)
        }
        let prev = index - 1
        guard prev >= 0, prev < messageList.count else { return nil }
        let previousMessage = messageList[prev]
        guard let previousDate = previousMessage.timestamp else { return nil }
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
                    userAvatar(isShow: style.isShowLeftAvatar, isRight: false)
                    HStack(alignment: .top, spacing: 0) {
                        if style.isShowLeftNickname, let sender = message.sender, !sender.isEmpty {
                            nicknameView(sender: sender)
                        }
                        messageContent(alignment: .leading)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    if style.isShowRightNickname && message.sender?.count != 0 {
                        nicknameView(sender: message.sender!)
                    }
                    Spacer(minLength: 0)
                    messageContent(alignment: .trailing)
                    userAvatar(isShow: style.isShowRightAvatar, isRight: true)
                }
            }
        }
        .padding(4)
        .background(messageWrapperBackground)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: isLeft ? .leading : .trailing)
    }

    private func userAvatar(isShow: Bool, isRight: Bool) -> some View {
        Group {
            if isShow {
                Avatar(url: message.rawMessage?.faceURL, name: message.rawMessage?.nickName)
                    .frame(width: 36, height: 36)
                    .padding(isRight ? .leading : .trailing, 8)
                    .contentShape(Rectangle())
                    .scaleEffect(message.isSelf ? 1.0 : 1.0)
                    .onTapGesture {
                        if !message.isSelf {
                            onUserClick?(message.sender ?? "")
                        }
                    }
            }
        }
    }

    private func nicknameView(sender: String) -> some View {
        Text("\(sender):")
            .font(style.nicknameFont)
            .foregroundColor(style.nicknameTextColor)
            .background(style.nicknameBackgroundColor)
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
                    message: LocalizedChatString("TipsConfirmResendMessage"),
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

    private func messageContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(alignment: .bottom, spacing: 4) {
                if message.isSelf && message.status == .sendFail {
                    sendFailIcon
                } else if message.isSelf && message.status == .sending {
                    sendingLoadingIcon
                }
                
                VStack(alignment: message.isSelf ? .trailing : .leading, spacing: 4) {
                    messageContentBody
                        .opacity(message.status == .sending ? 0.7 : 1.0)
                }
                .scaleEffect(longPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.3), value: longPressed)
                
                if !message.isSelf && message.status == .sendFail {
                    sendFailIcon
                } else if !message.isSelf && message.status == .sending {
                    sendingLoadingIcon
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var messageWrapperBackground: some View {
        RoundedRectangle(cornerRadius: style.bottomViewCornerRadius)
            .fill(style.bottomViewBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: style.bottomViewCornerRadius)
                    .stroke(style.bottomViewBorderColor, lineWidth: style.bottomViewBorderWidth)
            )
    }

    private func systemMessageView(_ messageBody: MessageBody) -> some View {
        guard let systemInfo = messageBody.systemMessage, style.isShowSystemMessage else {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack {
                Spacer()
                Text(MessageListHelper.getSystemInfoDisplayString(systemInfo))
                    .font(.system(size: 12))
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.vertical, 4)
        )
    }

    private func isCustomSystemMessage(_ messageBody: MessageBody) -> Bool {
        guard let data = messageBody.customMessage?.data,
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String
        else {
            return false
        }
        return businessID == "group_create"
    }

    private func customSystemMessageView(_ messageBody: MessageBody) -> some View {
        if style.isShowSystemMessage == false {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack {
                Spacer()
                if let data = messageBody.customMessage?.data,
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
            if let messageBody = message.messageBody {
                switch message.messageType {
                case .text:
                    TextMessageView(
                        messageBody: messageBody,
                        isLeft: isLeft,
                        isSelf: message.isSelf,
                        shouldHighlight: shouldHighlightMessage(message)
                    )
                case .image:
                    ImageMessageView(
                        messageBody: messageBody,
                        message: message,
                        messageListStore: messageListStore,
                        onImageTap: imageViewerManager.showImageViewerIfAvailable
                    )
                case .video:
                    VideoMessageView(
                        messageBody: messageBody,
                        message: message,
                        messageListStore: messageListStore,
                        onVideoTap: imageViewerManager.showImageViewerIfAvailable,
                        onPlayVideo: {
                            if let videoPath = messageBody.videoPath {
                                let videoData = VideoData(
                                    uri: videoPath,
                                    localPath: videoPath,
                                    width: 1920,
                                    height: 1080
                                )
                                VideoPlayer.shared.play(videoData: videoData)
                            } else {
                                messageListStore.downloadMessageResource(message, resourceType: .video, completion: { result in
                                    switch result {
                                    case .success:
                                        DispatchQueue.main.async {
                                            if let videoPath = messageBody.videoPath {
                                                let videoData = VideoData(
                                                    uri: videoPath,
                                                    localPath: videoPath,
                                                    width: 1920,
                                                    height: 1080
                                                )
                                                VideoPlayer.shared.play(videoData: videoData)
                                            }
                                        }
                                    case .failure(let error):
                                        print("\(LocalizedChatString("VideoDownloadFailed")): \(error.code), \(error.message)")
                                    }
                                })
                            }
                        }
                    )
                case .file:
                    FileMessageView(
                        messageBody: messageBody,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSelf,
                        shouldHighlight: shouldHighlightMessage(message)
                    )
                case .sound:
                    AudioMessageView(
                        messageBody: messageBody,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSelf,
                        shouldHighlight: shouldHighlightMessage(message),
                        audioPlayer: audioPlayer
                    )
                default:
                    if style.isShowUnsupportMessage {
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
        guard messageToResend.messageBody != nil else { return }
        
        var resendMessage = messageToResend
        
        self.messageInputStore = MessageInputStore.create(conversationID: self.messageListStore.conversationID)
        
        self.messageInputStore?.sendMessage(resendMessage) {  result in
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
}
