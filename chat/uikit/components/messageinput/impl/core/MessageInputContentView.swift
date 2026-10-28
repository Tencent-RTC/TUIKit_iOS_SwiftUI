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

struct MessageInputContentView: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var isLongPressingState: Bool
    @Binding var dragOffset: CGFloat
    @Binding var shouldCancelRecording: Bool
    @Binding var isShowingAudioRecorder: Bool
    @Binding var isShowingVoiceTranscription: Bool
    @ObservedObject var voiceRecordController: VoiceInputRecordController
    @ObservedObject var voiceTranscriptionController: VoiceTranscriptionController
    var messageInputStore: MessageInputStore
    let conversationID: String
    var onSendText: ((String) -> Void)? = nil
    var onSendImage: ((URL) -> Void)? = nil
    var onSendVideo: ((URL, URL) -> Void)? = nil
    var onSendFile: ((URL, String, Int64) -> Void)? = nil
    var onSendVoice: ((URL, Int) -> Void)? = nil
    let messageManager: MessageInputManager

    init(
        messageInputStore: MessageInputStore,
        conversationID: String,
        isLongPressingState: Binding<Bool>,
        dragOffset: Binding<CGFloat>,
        shouldCancelRecording: Binding<Bool>,
        isShowingAudioRecorder: Binding<Bool>,
        isShowingVoiceTranscription: Binding<Bool>,
        voiceRecordController: VoiceInputRecordController,
        voiceTranscriptionController: VoiceTranscriptionController,
        config: ChatMessageInputConfig
    ) {
        self.messageInputStore = messageInputStore
        self.conversationID = conversationID
        self._isLongPressingState = isLongPressingState
        self._dragOffset = dragOffset
        self._shouldCancelRecording = shouldCancelRecording
        self._isShowingAudioRecorder = isShowingAudioRecorder
        self._isShowingVoiceTranscription = isShowingVoiceTranscription
        self.voiceRecordController = voiceRecordController
        self.voiceTranscriptionController = voiceTranscriptionController
        self.messageManager = MessageInputManager(messageInputStore: messageInputStore, config: config)
    }

    @State private var isShowingPhotoTaker = false
    @State var isShowingQuickReplies = false
    @State var isShowingEmojiPicker = false
    @State var isShowingMorePanel = false
    // 红点状态由输入栏持有，避免销毁并重建面板后恢复。
    @State private var dismissedMorePanelRedDotIDs: Set<String> = []
    @State var isVoiceInputMode = false
    @State private var isShowingFilePicker = false
    @State var quotedMessage: MessageInfo? = nil
    @State var typingController: TypingIndicatorController? = nil
    @State private var isShowingVideoRecorder = false
    @State var textHeight: CGFloat = 36
    @State private var isRecording = false
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: Int = 0
    @State private var recordingAmplitude: CGFloat = 0
    @State private var audioFilePath: String = ""
    @State var microphoneAuthorized = false
    @State private var showPermissionAlert = false
    @State private var animationTimer: Timer?
    @State private var animationValues: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var initialTouchLocation: CGPoint = .zero
    @StateObject var textEditorState = TextEditorState()
    @Environment(\.messageInputConfig) var inputStyle: ChatMessageInputConfig
    @StateObject var keyboardHandler = KeyboardHandler()
    @State var isInputFocused = false
    @State var draftSaveWorkItem: DispatchWorkItem?
    @State var isLoadingDraft = false
    @State private var isShowingMentionPicker = false
    @State var mentionList: [MentionInfo] = []
    @State private var pendingAtPosition: Int = 0
    @State private var groupCallPickerMediaType: ChatCallEventPublisher.MediaType? = nil
    let conversationStore = ConversationListStore.create()
    private var keyboardFillHeight: CGFloat {
        keyboardHandler.keyboardHeight
    }

    private var visiblePanelHeight: CGFloat {
        if isShowingEmojiPicker { return Self.emojiPanelHeight }
        if isShowingMorePanel { return morePanelHeight }
        return 0
    }

    private var totalInputAreaHeight: CGFloat {
        var height = max(fieldHeight, inputButtonHeight) + Self.inputRowVerticalPadding * 2
        if inputStyle.appearance?.showTopDivider != false { height += Self.topDividerHeight }
        if quotedMessage != nil { height += Self.quotePreviewBarHeight }
        height += max(keyboardFillHeight, visiblePanelHeight)
        return height
    }

    private static let emojiPanelHeight: CGFloat = 280

    private static let quotePreviewBarHeight: CGFloat = 48

    private static let inputRowVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let topDividerHeight: CGFloat = 0.5
    private static let inputButtonSize: CGFloat = 28
    private static let sendButtonCornerRadius: CGFloat = 14
    private static let morePanelItemSize: CGFloat = 56
    private static let morePanelTitleHeight: CGFloat = 29

    private var inputButtonHeight: CGFloat {
        let appearance = inputStyle.appearance
        var heights: [CGFloat] = []
        if inputStyle.isShowAudioRecorder { heights.append(MessageInputAppearanceLayout.buttonSize(appearance?.audioRecordButton, fallback: Self.inputButtonSize).height) }
        if inputStyle.isShowEmoji { heights.append(MessageInputAppearanceLayout.buttonSize(appearance?.emojiButton, fallback: Self.inputButtonSize).height) }
        if shouldShowSendButton { heights.append(MessageInputAppearanceLayout.buttonSize(appearance?.sendButton, fallback: Self.inputButtonSize, supportsTitle: true).height) }
        if shouldShowMoreButton { heights.append(MessageInputAppearanceLayout.buttonSize(appearance?.moreButton, fallback: Self.inputButtonSize).height) }
        return heights.max() ?? 0
    }

    private var morePanelHeight: CGFloat {
        let columns: CGFloat = 4
        let rows = max(1, (CGFloat(morePanelActions.count) / columns).rounded(.up))
        let itemSize = MessageInputAppearanceLayout.dimension(inputStyle.appearance?.morePanel?.itemSize, fallback: Self.morePanelItemSize)
        let itemHeight = itemSize + CGFloat(SpacingScheme.iconTextSpacing) + Self.morePanelTitleHeight + CGFloat(SpacingScheme.smallSpacing)
        let rowSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
        let panelPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
        return rows * itemHeight + max(0, rows - 1) * rowSpacing + panelPadding * 2
    }

    private var morePanelActions: [MessageInputMenuAction] {
        var defaults: [MessageInputMenuAction] = [
            MessageInputMenuAction(ID: MessageInputActionIDs.album, title: LocalizedChatString("MorePhoto"), iconName: "more_picture") {
                isShowingMorePanel = false
                showAlbumPicker()
            }
        ]
        if inputStyle.isShowPhotoTaker {
            defaults.append(MessageInputMenuAction(ID: MessageInputActionIDs.takePhoto, title: LocalizedChatString("MoreCamera"), iconName: "more_camera") {
                isShowingMorePanel = false
                isShowingPhotoTaker = true
            })
            defaults.append(MessageInputMenuAction(ID: MessageInputActionIDs.recordVideo, title: LocalizedChatString("MoreVideo"), iconName: "more_video") {
                isShowingMorePanel = false
                isShowingVideoRecorder = true
            })
        }
        defaults.append(MessageInputMenuAction(ID: MessageInputActionIDs.file, title: LocalizedChatString("MoreFile"), iconName: "more_file") {
            isShowingMorePanel = false
            isShowingFilePicker = true
        })
        if inputStyle.isShowVideoCall {
            defaults.append(MessageInputMenuAction(ID: MessageInputActionIDs.videoCall, title: LocalizedChatString("MoreVideoCall"), iconName: "more_video_call") {
                isShowingMorePanel = false
                startCall(mediaType: .video)
            })
        }
        if inputStyle.isShowAudioCall {
            defaults.append(MessageInputMenuAction(ID: MessageInputActionIDs.audioCall, title: LocalizedChatString("MoreVoiceCall"), iconName: "more_voice_call") {
                isShowingMorePanel = false
                startCall(mediaType: .audio)
            })
        }
        if let customizer = inputStyle.actionCustomizer {
            let editor = CustomEditor(items: defaults)
            customizer(editor)
            return editor.build()
        }
        return defaults
    }

    private func startCall(mediaType: ChatCallEventPublisher.MediaType) {
        if !isGroupChat, conversationID.hasPrefix("c2c_"), let targetUserID = ChatUtil.getUserID(conversationID) {
            ChatCallEventPublisher.publishStartCall(participantIDs: [targetUserID], mediaType: mediaType)
            return
        }
        if isGroupChat {
            groupCallPickerMediaType = mediaType
        }
    }

    private let quickReplies = [
        LocalizedChatString("QuickReplyOK"),
        LocalizedChatString("QuickReplyWait"),
        LocalizedChatString("QuickReplyThanks"),
        LocalizedChatString("QuickReplyReceived"),
        LocalizedChatString("QuickReplyProcessing")
    ]
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if inputStyle.appearance?.showTopDivider != false {
                    themeState.colors.strokeColorPrimary.frame(height: Self.topDividerHeight)
                }
                InputBarArea
                if let quoted = quotedMessage {
                    MessageInputQuotePreviewBar(
                        senderName: quoteSenderName(for: quoted),
                        summary: MessageInputQuoteSummaryFormatter.format(message: quoted),
                        onClose: { clearQuote() }
                    )
                    .environmentObject(themeState)
                    .frame(height: Self.quotePreviewBarHeight)
                    .transition(.move(edge: .bottom))
                }
                ZStack(alignment: .bottom) {
                    if isShowingEmojiPicker {
                        EmojiPickerView { emojiData in
                            let emojiAttrStr = EmojiManager.shared.createAttributedStringFromEmojiData(emojiData)
                            let emojiName = emojiData.name ?? ""
                            textEditorState.addEmojiString?(emojiAttrStr, emojiName)
                        } onSendClick: {
                            sendTextMessage()
                        } onDeleteClick: {
                            deleteLastCharacter()
                        } onCustomEmojiSelected: { group, emoji in
                            guard let groupIndex = EmojiConfig.shared.emojiGroups.firstIndex(where: { $0.id == group.id }),
                                  let key = emoji.name, !key.isEmpty else { return }
                            messageManager.sendFaceMessage(groupIndex: groupIndex, faceData: key)
                        }
                        .frame(height: Self.emojiPanelHeight)
                        .background(themeState.colors.bgColorOperate)
                        .transition(.identity)
                    }
                    if isShowingMorePanel {
                        MessageInputMorePanelView(
                            actions: morePanelActions,
                            dismissedRedDotIDs: dismissedMorePanelRedDotIDs,
                            onActionTap: { action in
                                if action.showRedDot {
                                    dismissedMorePanelRedDotIDs.insert(action.ID)
                                }
                            },
                            appearance: inputStyle.appearance?.morePanel
                        )
                            .environmentObject(themeState)
                            .frame(height: morePanelHeight)
                            .transition(.identity)
                    }
                    Color.clear
                        .frame(height: keyboardFillHeight)
                }
            }
            .background(MessageInputAppearanceBackground(fill: inputStyle.appearance?.fill, fallback: themeState.colors.bgColorOperate))
        }
        .toast(messageManager.toastInstance)
        .frame(height: totalInputAreaHeight, alignment: .bottom)
        .clipped()
        // 动画须位于尺寸修饰之后，面板高度变化才能参与过渡。
        .animation(.easeInOut(duration: 0.2), value: quotedMessage != nil)
        .animation(.easeInOut(duration: 0.2), value: isShowingQuickReplies)
        .animation(.easeInOut(duration: 0.2), value: isShowingEmojiPicker)
        .animation(.easeInOut(duration: 0.2), value: isShowingMorePanel)
        .animation(.easeInOut(duration: 0.2), value: isShowingAudioRecorder)
        .animation(.easeInOut(duration: 0.2), value: textHeight)
        .fullScreenCover(isPresented: $isShowingPhotoTaker) {
            VideoRecorderView(
                config: VideoRecorderConfig(
                    recordMode: .photoOnly
                ),
                onVideoCaptured: { _, _, _ in },
                onPhotoCaptured: { imagePath in
                    if let imagePath = imagePath {
                        saveAndSendImage(imagePath)
                    }
                }
            )
        }

        .sheet(isPresented: $isShowingFilePicker) {
            FilePicker.pickFiles { selectedFile in
                if let url = selectedFile {
                    handleFileSelection(url)
                }
            }
        }
        .sheet(isPresented: $isShowingMentionPicker) {
            MentionMemberPicker(
                groupID: groupID,
                atPosition: pendingAtPosition,
                onMembersSelected: { mentionInfos, position in
                    insertMentions(mentionInfos, atPosition: position)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        textEditorState.becomeFirstResponder?()
                    }
                }
            )
            .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $isShowingVideoRecorder) {
            VideoRecorderView(
                config: VideoRecorderConfig(
                    recordMode: .videoPhotoMix
                ),
                onVideoCaptured: { videoPath, _, thumbPath in
                    if let videoPath = videoPath {
                        createThumbnailAndSendVideo(videoPath, thumbPath)
                    }
                },
                onPhotoCaptured: { imagePath in
                    if let imagePath = imagePath {
                        saveAndSendImage(imagePath)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { groupCallPickerMediaType != nil },
            set: { if !$0 { groupCallPickerMediaType = nil } }
        )) {
            if let mediaType = groupCallPickerMediaType {
                GroupCallMemberPickerView(
                    groupID: groupID,
                    title: mediaType == .video ? LocalizedChatString("MoreVideoCall") : LocalizedChatString("MoreVoiceCall"),
                    onConfirm: { userIDs in
                        ChatCallEventPublisher.publishStartCall(participantIDs: userIDs, mediaType: mediaType, chatGroupID: groupID)
                    }
                )
                .environmentObject(themeState)
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text(LocalizedChatString("InputNoMicTitle")),
                message: Text(LocalizedChatString("InputNoMicTips")),
                primaryButton: .default(Text(LocalizedChatString("InputNoMicOperateEnable")), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        .preference(key: InputStateKey.self, value: InputState(
            isShowingEmojiPicker: isShowingEmojiPicker,
            isShowingQuickReplies: isShowingQuickReplies,
            textHeight: textHeight
        ))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkMicrophonePermission()
            }
            loadDraft()
            setupTypingControllerIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("mentionUserNotification"))) { notification in
            guard isGroupChat else {
                print(">>>>> mentionUserNotification ignored, not a group chat. conversationID: \(conversationID)")
                return
            }

            if let userInfo = notification.userInfo,
               let userID = userInfo["userID"] as? String,
               let nickname = userInfo["nickname"] as? String
            {
                let displayTextLength = textEditorState.displayText?.length ?? 0
                let mentionText = "@\(nickname) "

                let mentionInfo = MentionInfo(
                    userID: userID,
                    displayName: nickname,
                    startIndex: displayTextLength,
                    length: mentionText.count
                )

                let mentionAttrStr = EmojiManager.shared.createAttributedStringWithTextAndStyle(
                    text: mentionText,
                    withFont: normalFont,
                    textColor: normalColor
                )

                mentionList.append(mentionInfo)

                textEditorState.appendText?(mentionAttrStr)

                textEditorState.becomeFirstResponder?()
            }
        }
        .onReceive(keyboardHandler.$isKeyboardVisible) { isVisible in
            if isVisible {
                postInputInteract()
                isInputFocused = true
            } else {
                if !isShowingEmojiPicker {
                    isInputFocused = false
                }
                textEditorState.resignFirstResponder?()
            }
        }
        .onReceive(keyboardHandler.didShowPublisher) { _ in
            isShowingEmojiPicker = false
            isShowingMorePanel = false
        }
        .onChange(of: textEditorState.height) { newHeight in
            textHeight = newHeight
        }
        .onChange(of: textEditorState.displayText) { _ in
            if !isLoadingDraft {
                saveDraftWithDebounce()
                postInputInteract()
            }
            let hasContent = !(textEditorState.displayText?.string.isEmpty ?? true)
            typingController?.sendTypingStatus(hasContent: hasContent)
        }
        .onDisappear {
            saveDraftImmediately()
            typingController?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("quoteMessageNotification"))) { notification in
            guard let message = notification.userInfo?["message"] as? MessageInfo else { return }
            setQuoteMessage(message)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("messageListBlankAreaClickNotification"))) { _ in
            isShowingEmojiPicker = false
            isShowingMorePanel = false
            isShowingQuickReplies = false
        }
    }

    var hasText: Bool {
        !(textEditorState.displayText?.string.isEmpty ?? true)
    }

    private var shouldShowSendButton: Bool {
        inputStyle.isShowSendButton && !isVoiceInputMode && (hasText || inputStyle.keepSendButtonVisible)
    }

    private var shouldShowMoreButton: Bool {
        inputStyle.isShowMore && (inputStyle.keepSendButtonVisible || !shouldShowSendButton)
    }

    private var fieldHeight: CGFloat {
        max(textEditorState.height, MessageInputAppearanceLayout.dimension(inputStyle.appearance?.field?.minHeight, fallback: textEditorState.height))
    }

    private var InputBarArea: some View {
        HStack(alignment: .center, spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            if inputStyle.isShowAudioRecorder {
                voiceModeToggleButton
            }
            inputFieldContainer
            if inputStyle.isShowEmoji {
                emojiToggleButton
            }
            if shouldShowSendButton {
                sendButton
            }
            if shouldShowMoreButton {
                moreToggleButton
            }
        }
        .padding(.vertical, Self.inputRowVerticalPadding)
        .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
        .background(Color.clear)
        .clipped()
    }

    private var voiceModeToggleButton: some View {
        MessageInputAppearanceButtonLabel(
            appearance: inputStyle.appearance?.audioRecordButton,
            active: isVoiceInputMode,
            defaultIconName: isVoiceInputMode ? "input_keyboard" : "input_audio",
            defaultTint: themeState.colors.textColorSecondary
        )
            .accessibilityElement()
            .accessibilityLabel(isVoiceInputMode ? "input_keyboard" : "input_audio")
            .accessibilityAddTraits(.isButton)
            .overlay(HoldToTalkArea(
                onTap: { toggleVoiceInputMode() },
                onPressBegan: voicePressBegan,
                onPressChanged: voicePressChanged,
                onPressEnded: voicePressEnded
            ))
    }

    private var inputFieldContainer: some View {
        ZStack(alignment: .leading) {
            if isVoiceInputMode {
                holdToTalkButton
            } else {
                textEditorField
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, textEditorState.verticalPadding)
        .padding(.horizontal, MessageInputAppearanceLayout.padding(inputStyle.appearance?.field?.horizontalPadding, fallback: textEditorState.horizontalPadding))
        .background(MessageInputAppearanceBackground(
            fill: inputStyle.appearance?.field?.fill,
            fallback: themeState.colors.bgColorInput,
            cornerRadius: inputStyle.appearance?.field?.cornerRadius,
            defaultCornerRadius: CGFloat(themeState.radius.tipsRadius)
        ))
    }

    private var holdToTalkButton: some View {
        Text(LocalizedChatString("InputHoldToTalk"))
            .font(FontScheme.caption1Regular)
            .foregroundColor(inputStyle.appearance?.field?.textColor.map { Color($0) } ?? themeState.colors.textColorPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: fieldHeight)
            .contentShape(Rectangle())
            .overlay(HoldToTalkArea(
                onPressBegan: voicePressBegan,
                onPressChanged: voicePressChanged,
                onPressEnded: voicePressEnded
            ))
    }

    private var textEditorField: some View {
        ZStack(alignment: .leading) {
            if !hasText && !isInputFocused && !isShowingEmojiPicker && !isShowingMorePanel {
                Text(inputStyle.appearance?.field?.hintText ?? LocalizedChatString(inputStyle.enableLongPressToTalk ? "SendMessage" : "SendMessageTextOnly"))
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(inputStyle.appearance?.field?.hintColor.map { Color($0) } ?? themeState.colors.textColorTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: fieldHeight)
                    .allowsHitTesting(false)
            }
            HStack {
                FixedHeightTextEditor(
                    state: textEditorState,
                    maxLines: 5,
                    onSend: {
                        sendTextMessage()
                    },
                    onAtTriggered: { position in
                        if isGroupChat {
                            pendingAtPosition = position
                            isShowingMentionPicker = true
                        }
                    },
                    onDeleteAtPosition: { position in
                        findMentionToDelete(at: position)
                    },
                    onMentionDeleted: { mention in
                        mentionList.removeAll { $0.userID == mention.userID && $0.startIndex == mention.startIndex }
                    },
                    isGroupChat: isGroupChat,
                    enableMention: inputStyle.enableMention,
                    appearance: inputStyle.appearance?.field,
                    onVoiceLongPress: { state, fingerGlobal in
                        handleTextInputVoiceLongPress(state: state, fingerGlobal: fingerGlobal)
                    }
                )
                .background(Color.clear)
            }
            .frame(minHeight: fieldHeight, maxHeight: fieldHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private var emojiToggleButton: some View {
        Button(action: {
            if isShowingEmojiPicker {
                showKeyboard()
            } else {
                showEmojiPicker()
            }
        }) {
            MessageInputAppearanceButtonLabel(
                appearance: inputStyle.appearance?.emojiButton,
                active: isShowingEmojiPicker,
                defaultIconName: isShowingEmojiPicker ? "input_keyboard" : "input_emoji",
                defaultTint: themeState.colors.textColorSecondary
            )
        }
    }

    private var hasVisibleMorePanelRedDot: Bool {
        morePanelActions.contains { $0.showRedDot && !dismissedMorePanelRedDotIDs.contains($0.ID) }
    }

    private var moreToggleButton: some View {
        Button(action: {
            toggleMorePanel()
        }) {
            MessageInputAppearanceButtonLabel(
                appearance: inputStyle.appearance?.moreButton,
                active: isShowingMorePanel,
                defaultIconName: "input_more",
                defaultTint: themeState.colors.textColorSecondary
            )
                .overlay(alignment: .topTrailing) {
                    if hasVisibleMorePanelRedDot {
                        Circle()
                            .fill(themeState.colors.textColorError)
                            .frame(width: 8, height: 8)
                            .offset(x: -1, y: 1)
                    }
                }
        }
    }

    private var sendButton: some View {
        Button(action: {
            sendTextMessage()
        }) {
            MessageInputAppearanceButtonLabel(
                appearance: inputStyle.appearance?.sendButton,
                active: false,
                defaultIconName: "arrow.up",
                systemIcon: true,
                defaultTint: themeState.colors.textColorButton,
                defaultFill: themeState.colors.buttonColorPrimaryDefault,
                defaultCornerRadius: Self.sendButtonCornerRadius,
                supportsTitle: true
            )
        }
        .disabled(!hasText)
    }

    @State var voiceBeginWorkItem: DispatchWorkItem? = nil
    @State var voicePressStartGlobalY: CGFloat? = nil
}
