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

private extension View {
    func getScreenWidth() -> CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width
        #else
        return 390
        #endif
    }
}

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MessageInputConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageInputConfigProtocol = ChatMessageInputConfig()
}

private extension EnvironmentValues {
    var MessageInputConfigProtocol: MessageInputConfigProtocol {
        get { self[MessageInputConfigProtocolKey.self] }
        set { self[MessageInputConfigProtocolKey.self] = newValue }
    }
}

public struct MessageInput: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showingEmojiPicker = false
    @State private var showingQuickReplies = false
    @State private var textHeight: CGFloat = 40
    @State private var isLongPressingState = false
    @State private var dragOffset: CGFloat = 0
    @State private var shouldCancelRecording = false
    @State private var isShowingAudioRecorder = false
    private var messageInputStore: MessageInputStore
    private let conversationID: String
    private let config: MessageInputConfigProtocol

    public init(
        conversationID: String,
        config: MessageInputConfigProtocol = ChatMessageInputConfig()
    ) {
        self.conversationID = conversationID
        self.config = config
        self.messageInputStore = MessageInputStore.create(conversationID: conversationID)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MessageInputView(
                messageInputStore: messageInputStore,
                conversationID: conversationID,
                isLongPressingState: $isLongPressingState,
                dragOffset: $dragOffset,
                shouldCancelRecording: $shouldCancelRecording,
                isShowingAudioRecorder: $isShowingAudioRecorder,
                config: config
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ViewHeightKey.self, value: geo.size.height)
                        .onPreferenceChange(ViewHeightKey.self) { _ in }
                }
            )
            .onPreferenceChange(InputStateKey.self) { state in
                self.showingEmojiPicker = state.isShowingEmojiPicker
                self.showingQuickReplies = state.isShowingQuickReplies
                self.textHeight = state.textHeight
            }
            .environment(\.MessageInputConfigProtocol, config)
            if isShowingAudioRecorder {
                AudioRecorderView(
                    cancelRecording: $shouldCancelRecording,
                    config: AudioRecorderViewConfig(
                        primaryColor: themeState.currentPrimaryColor,
                        backgroundColor: themeState.colors.bgColorOperate.hexString()
                    ),
                    onRecordingComplete: { path, duration in
                        print("audio recorde on recording complete. path = \(path ?? "") duration = \(duration)")
                        if let path = path {
                            let messageManager = MessageInputManager(messageInputStore: messageInputStore, config: config)
                            messageManager.sendVoiceMessage(path, duration: Int(duration))
                        }
                        isShowingAudioRecorder = false
                    }
                )
                .frame(height: 100)
                .transition(.opacity)
                .allowsHitTesting(true)
            }
        }
    }
}

private struct InputState: Equatable {
    var isShowingEmojiPicker: Bool = false
    var isShowingQuickReplies: Bool = false
    var textHeight: CGFloat = 36
}

private let normalFont: UIFont = .systemFont(ofSize: 16)
private let normalColor: UIColor = .label
private struct InputStateKey: PreferenceKey {
    static var defaultValue = InputState()
    static func reduce(value: inout InputState, nextValue: () -> InputState) {
        value = nextValue()
    }
}

private class TextEditorState: ObservableObject {
    @Published var displayText: NSAttributedString?
    @Published var height: CGFloat = 36
    var verticalPadding: CGFloat = 0
    var horizontalPadding: CGFloat = 6
    var addEmojiString: ((NSAttributedString, String) -> Void)?
    var deleteLastCharacter: (() -> Void)?
    var becomeFirstResponder: (() -> Void)?
    var resignFirstResponder: (() -> Void)?
    var appendText: ((NSAttributedString) -> Void)?
}

private struct FixedHeightTextEditor: UIViewRepresentable {
    @ObservedObject var state: TextEditorState
    var maxLines: Int = 5
    var onSend: (() -> Void)? = nil
    var onAtTriggered: ((Int) -> Void)? = nil
    var onDeleteAtPosition: ((Int) -> MentionInfo?)? = nil
    var onMentionDeleted: ((MentionInfo) -> Void)? = nil
    var isGroupChat: Bool = false
    var enableMention: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.returnKeyType = .send
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.inputTextView = textView
        state.addEmojiString = { [weak textView] emojiStr, emojiName in
            guard let textView = textView else { return }
            if let attachment = emojiStr.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment,
               let image = attachment.image
            {
                image.accessibilityIdentifier = emojiName
            }
            let selectedRange = textView.selectedRange
            textView.textStorage.insert(emojiStr, at: selectedRange.location)
            let newPosition = selectedRange.location + 1
            textView.selectedRange = NSRange(location: newPosition, length: 0)
            context.coordinator.resetTextStyle()
            state.displayText = textView.attributedText
        }
        state.deleteLastCharacter = { [weak textView] in
            guard let textView = textView,
                  textView.textStorage.length > 0 else { return }
            let selectedRange = textView.selectedRange
            if selectedRange.length > 0 {
                textView.textStorage.deleteCharacters(in: selectedRange)
                textView.selectedRange = NSRange(location: selectedRange.location, length: 0)
            } else if selectedRange.location > 0 {
                let deleteRange = NSRange(location: selectedRange.location - 1, length: 1)
                textView.textStorage.deleteCharacters(in: deleteRange)
                textView.selectedRange = NSRange(location: selectedRange.location - 1, length: 0)
            }
            context.coordinator.resetTextStyle()
            state.displayText = textView.attributedText
            let newSize = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
            let singleLineHeight: CGFloat = textView.font?.lineHeight ?? 24
            let padding: CGFloat = textView.textContainerInset.top + textView.textContainerInset.bottom
            let maxHeight = singleLineHeight * 5 + padding
            let newHeight = min(max(singleLineHeight + padding, newSize.height), maxHeight)
            if state.height != newHeight {
                DispatchQueue.main.async {
                    state.height = newHeight
                }
            }
        }
        state.becomeFirstResponder = { [weak textView] in
            textView?.becomeFirstResponder()
        }
        state.resignFirstResponder = { [weak textView] in
            textView?.resignFirstResponder()
        }
        state.appendText = { [weak textView] attrStr in
            guard let textView = textView else { return }
            // Append text at the end of current content
            let endPosition = textView.textStorage.length
            textView.textStorage.insert(attrStr, at: endPosition)
            // Move cursor to the end
            let newPosition = textView.textStorage.length
            textView.selectedRange = NSRange(location: newPosition, length: 0)
            context.coordinator.resetTextStyle()
            state.displayText = textView.attributedText
            // Update height
            let newSize = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
            let singleLineHeight: CGFloat = textView.font?.lineHeight ?? 24
            let padding: CGFloat = textView.textContainerInset.top + textView.textContainerInset.bottom
            let maxHeight = singleLineHeight * 5 + padding
            let newHeight = min(max(singleLineHeight + padding, newSize.height), maxHeight)
            if state.height != newHeight {
                DispatchQueue.main.async {
                    state.height = newHeight
                }
            }
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Compare attributed text instead of plain text to preserve formatting and emoji attachments
        if let displayText = state.displayText {
            // Only update if the content is actually different to avoid update loops
            // Don't update if user is actively typing (checked via coordinator flag)
            if !context.coordinator.isUserEditing && !textView.attributedText.isEqual(to: displayText) {
                textView.attributedText = displayText
                // Move cursor to the end of the text
                let endPosition = displayText.length
                textView.selectedRange = NSRange(location: endPosition, length: 0)
                context.coordinator.resetTextStyle()
            }
        } else {
            // Clear text if displayText is nil
            if textView.attributedText.length > 0 {
                textView.attributedText = NSAttributedString(string: "")
            }
        }
        
        let newSize = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        let singleLineHeight: CGFloat = textView.font?.lineHeight ?? 24
        let padding: CGFloat = textView.textContainerInset.top + textView.textContainerInset.bottom
        let maxHeight = singleLineHeight * CGFloat(maxLines) + padding
        let newHeight = min(max(singleLineHeight + padding, newSize.height), maxHeight)
        if state.height != newHeight {
            DispatchQueue.main.async {
                self.state.height = newHeight
            }
        }
        textView.isScrollEnabled = newSize.height > maxHeight
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: FixedHeightTextEditor
        weak var inputTextView: UITextView?
        var isUserEditing = false
        
        init(_ parent: FixedHeightTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isUserEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isUserEditing = false
        }

        func textViewDidChange(_ textView: UITextView) {
            isUserEditing = true
            resetTextStyle()
            parent.state.displayText = textView.attributedText
            let newSize = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
            let singleLineHeight: CGFloat = textView.font?.lineHeight ?? 24
            let padding: CGFloat = textView.textContainerInset.top + textView.textContainerInset.bottom
            let maxHeight = singleLineHeight * CGFloat(parent.maxLines) + padding
            let newHeight = min(max(singleLineHeight + padding, newSize.height), maxHeight)
            if parent.state.height != newHeight {
                DispatchQueue.main.async {
                    self.parent.state.height = newHeight
                }
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Detect @ or ＠ input for mention
            if (text == "@" || text == "＠") && parent.isGroupChat && parent.enableMention {
                // Keep the @ character and trigger mention picker
                DispatchQueue.main.async {
                    self.parent.onAtTriggered?(range.location)
                }
                return true
            }
            
            // Handle deletion - check if deleting within a mention block
            if text.isEmpty && range.length > 0 {
                if let mentionToDelete = parent.onDeleteAtPosition?(range.location) {
                    // Validate mention range before deletion
                    let textLength = textView.textStorage.length
                    let mentionStart = mentionToDelete.startIndex
                    let mentionLength = mentionToDelete.length
                    
                    // Ensure mention range is within bounds
                    if mentionStart >= 0 && mentionStart < textLength {
                        let safeLength = min(mentionLength, textLength - mentionStart)
                        if safeLength > 0 {
                            let mentionRange = NSRange(location: mentionStart, length: safeLength)
                            textView.textStorage.deleteCharacters(in: mentionRange)
                            textView.selectedRange = NSRange(location: mentionStart, length: 0)
                            resetTextStyle()
                            parent.state.displayText = textView.attributedText
                            // Notify that mention was deleted
                            parent.onMentionDeleted?(mentionToDelete)
                            return false
                        }
                    }
                }
            }
            
            if !text.contains("[") && !text.contains("]") {
                if text == "\n" {
                    parent.onSend?()
                    return false
                }
                return true
            }
            let selectedRange = textView.selectedRange
            if selectedRange.length > 0 {
                textView.textStorage.deleteCharacters(in: selectedRange)
            }
            let textChange = EmojiManager.shared.createAttributedStringWithTextAndStyle(text: text, withFont: normalFont, textColor: normalColor)
            textView.textStorage.insert(textChange, at: selectedRange.location)
            let newPosition = selectedRange.location + 1
            textView.selectedRange = NSRange(location: newPosition, length: 0)
            resetTextStyle()
            return false
        }

        func resetTextStyle() {
            guard let inputTextView = inputTextView else { return }
            let wholeRange = NSRange(location: 0, length: inputTextView.textStorage.length)
            inputTextView.textStorage.removeAttribute(.font, range: wholeRange)
            inputTextView.textStorage.removeAttribute(.foregroundColor, range: wholeRange)
            inputTextView.textStorage.addAttribute(.foregroundColor, value: normalColor, range: wholeRange)
            inputTextView.textStorage.addAttribute(.font, value: normalFont, range: wholeRange)
            inputTextView.textAlignment = .left
            inputTextView.textColor = normalColor
        }
    }
}

private struct MessageInputView: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var isLongPressingState: Bool
    @Binding var dragOffset: CGFloat
    @Binding var shouldCancelRecording: Bool
    @Binding var isShowingAudioRecorder: Bool
    var messageInputStore: MessageInputStore
    let conversationID: String
    var onSendText: ((String) -> Void)? = nil
    var onSendImage: ((URL) -> Void)? = nil
    var onSendVideo: ((URL, URL) -> Void)? = nil
    var onSendFile: ((URL, String, Int64) -> Void)? = nil
    var onSendVoice: ((URL, Int) -> Void)? = nil
    private let messageManager: MessageInputManager

    init(
        messageInputStore: MessageInputStore,
        conversationID: String,
        isLongPressingState: Binding<Bool>,
        dragOffset: Binding<CGFloat>,
        shouldCancelRecording: Binding<Bool>,
        isShowingAudioRecorder: Binding<Bool>,
        config: MessageInputConfigProtocol
    ) {
        self.messageInputStore = messageInputStore
        self.conversationID = conversationID
        self._isLongPressingState = isLongPressingState
        self._dragOffset = dragOffset
        self._shouldCancelRecording = shouldCancelRecording
        self._isShowingAudioRecorder = isShowingAudioRecorder
        self.messageManager = MessageInputManager(messageInputStore: messageInputStore, config: config)
    }

    @State private var isShowingPhotoTaker = false
    @State private var isShowingImagePicker = false
    @State private var isShowingVideoPicker = false
    @State private var isShowingMediaActionSheet = false
    @State private var isShowingQuickReplies = false
    @State private var isShowingEmojiPicker = false
    @State private var isShowingFilePicker = false
    @State private var isShowingVideoRecorder = false
    @State private var textHeight: CGFloat = 36
    @State private var isRecording = false
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: Int = 0
    @State private var recordingAmplitude: CGFloat = 0
    @State private var audioFilePath: String = ""
    @State private var microphoneAuthorized = false
    @State private var showPermissionAlert = false
    @State private var animationTimer: Timer?
    @State private var animationValues: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var initialTouchLocation: CGPoint = .zero
    @StateObject private var textEditorState = TextEditorState()
    @Environment(\.MessageInputConfigProtocol) var inputStyle: MessageInputConfigProtocol
    @StateObject private var keyboardHandler = KeyboardHandler()
    @State private var isInputFocused = false
    @State private var draftSaveWorkItem: DispatchWorkItem?
    @State private var isLoadingDraft = false
    @State private var isShowingMentionPicker = false
    @State private var mentionList: [MentionInfo] = []
    @State private var pendingAtPosition: Int = 0
    private let conversationStore = ConversationListStore.create()
    private var totalInputAreaHeight: CGFloat {
        var height = textEditorState.height + 12
        if isShowingEmojiPicker { height += 300 }
        return height
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
                InputBarArea
                if isShowingEmojiPicker {
                    EmojiPicker { emojiData in
                        let emojiAttrStr = EmojiManager.shared.createAttributedStringFromEmojiData(emojiData)
                        let emojiName = emojiData.name ?? ""
                        textEditorState.addEmojiString?(emojiAttrStr, emojiName)
                    } onSendClick: {
                        sendTextMessage()
                    } onDeleteClick: {
                        deleteLastCharacter()
                    }
                    .frame(height: 300)
                    .background(themeState.colors.bgColorOperate)
                    .transition(.move(edge: .bottom))
                }
            }
            .background(themeState.colors.bgColorOperate)
        }
        .toast(messageManager.toastInstance)
        .animation(.easeInOut(duration: 0.2), value: isShowingQuickReplies)
        .animation(.easeInOut(duration: 0.2), value: isShowingEmojiPicker)
        .animation(.easeInOut(duration: 0.2), value: isShowingAudioRecorder)
        .animation(.easeInOut(duration: 0.2), value: textHeight)
        .frame(height: totalInputAreaHeight, alignment: .bottom)
        .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight : 0)
        .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
        .fullScreenCover(isPresented: $isShowingPhotoTaker) {
            VideoRecorder(
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
        .fullScreenCover(isPresented: $isShowingVideoPicker) {
            VideoPicker(
                config: VideoPickerConfig(
                    maxImagesCount: 9,
                    columnNumber: 4,
                    primary: themeState.currentPrimaryColor
                ),
                onFinishedSelect: { mediaCount in
                    isShowingVideoPicker = false
                    print("User selected \(mediaCount) media file(s)")
                },
                onProgress: { pickModel, index, progress in
                    print("Media \(index) processing progress: \(Int(progress * 100))%")
                    if progress >= 1.0 {
                        DispatchQueue.global(qos: .userInitiated).async {
                            if let mediaPath = pickModel.mediaPath {
                                if pickModel.mediaType == .video {
                                    createThumbnailAndSendVideo(mediaPath, pickModel.videoThumbnailPath)
                                } else if pickModel.mediaType == .image {
                                    saveAndSendImage(mediaPath)
                                }
                            }
                        }
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
                }
            )
            .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $isShowingVideoRecorder) {
            VideoRecorder(
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
        .actionSheet(isPresented: $isShowingMediaActionSheet) {
            ActionSheet(
                title: Text(LocalizedChatString("ChooseMediaType")),
                buttons: [
                    .default(Text(LocalizedChatString("MorePhoto"))) { isShowingVideoPicker = true },
                    .default(Text(LocalizedChatString("MoreCamera"))) { isShowingPhotoTaker = true },
                    .default(Text(LocalizedChatString("MoreVideo"))) { isShowingVideoRecorder = true },
                    .default(Text(LocalizedChatString("MoreFile"))) { isShowingFilePicker = true },
                    .cancel(Text(LocalizedChatString("Cancel")))
                ]
            )
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("mentionUserNotification"))) { notification in
            // Handle mention user from avatar long press (only in group chat)
            guard isGroupChat else {
                print(">>>>> mentionUserNotification ignored, not a group chat. conversationID: \(conversationID)")
                return
            }
            
            if let userInfo = notification.userInfo,
               let userID = userInfo["userID"] as? String,
               let nickname = userInfo["nickname"] as? String
            {
                // Use displayText length (UITextView position) instead of getSendText() length
                let displayTextLength = textEditorState.displayText?.length ?? 0
                let mentionText = "@\(nickname) "
                
                // Create mention info with display position
                let mentionInfo = MentionInfo(
                    userID: userID,
                    displayName: nickname,
                    startIndex: displayTextLength,
                    length: mentionText.count
                )
                
                // Create attributed string for mention text
                let mentionAttrStr = EmojiManager.shared.createAttributedStringWithTextAndStyle(
                    text: mentionText,
                    withFont: normalFont,
                    textColor: normalColor
                )
                
                // Add to mention list
                mentionList.append(mentionInfo)
                
                // Directly append text to UITextView without losing focus
                textEditorState.appendText?(mentionAttrStr)
                
                // Ensure input is focused
                textEditorState.becomeFirstResponder?()
            }
        }
        .onReceive(keyboardHandler.$isKeyboardVisible) { isVisible in
            if isVisible {
                isInputFocused = true
                if isShowingEmojiPicker {
                    withAnimation {
                        isShowingEmojiPicker = false
                    }
                }
            } else {
                if !isShowingEmojiPicker {
                    isInputFocused = false
                }
                textEditorState.resignFirstResponder?()
            }
        }
        .onChange(of: textEditorState.height) { newHeight in
            textHeight = newHeight
        }
        .onChange(of: textEditorState.displayText) { _ in
            // Don't save draft while loading draft to avoid overwriting
            if !isLoadingDraft {
                saveDraftWithDebounce()
            }
        }
        .onDisappear {
            saveDraftImmediately()
        }
    }

    private var InputBarArea: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer()
            if inputStyle.isShowMore {
                Button(action: {
                    isShowingMediaActionSheet = true
                }) {
                    Image("input_more", bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 24, height: 24)
                }
            }
            ZStack(alignment: .trailing) {
                ZStack(alignment: .leading) {
                    if textEditorState.displayText?.string.isEmpty ?? true {
                        Text(LocalizedChatString("SendMessage"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.textColorTertiary)
                            .padding(.leading, 4)
                            .frame(height: textEditorState.height)
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
                                // Remove deleted mention from list
                                mentionList.removeAll { $0.userID == mention.userID && $0.startIndex == mention.startIndex }
                            },
                            isGroupChat: isGroupChat,
                            enableMention: inputStyle.enableMention
                        )
                        .background(Color.clear)
                        .padding(.trailing, 40)
                        .onTapGesture {
                            showKeyboard()
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width - 100)
                    .frame(minHeight: textEditorState.height, maxHeight: textEditorState.height)
                }
                .frame(maxWidth: .infinity)
                Button(action: {
                    if isShowingEmojiPicker {
                        showKeyboard()
                    } else {
                        showEmojiPicker()
                    }
                }) {
                    Image(isShowingEmojiPicker ? "input_keyboard" : "input_emoji", bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 19, height: 19)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, textEditorState.verticalPadding)
            .padding(.horizontal, textEditorState.horizontalPadding)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(18)
            HStack(spacing: 10) {
                if inputStyle.isShowAudioRecorder {
                    Button(action: {}) {
                        Image("input_audio", bundle: AtomicXChatResources.resourceBundle)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            .frame(width: 24, height: 24)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingEmojiPicker = false
                                    isShowingQuickReplies = false
                                }
                                textEditorState.resignFirstResponder?()
                                isInputFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isLongPressingState = true
                                    isShowingAudioRecorder = true
                                    shouldCancelRecording = false
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if isLongPressingState {
                                    dragOffset = -value.translation.height
                                    shouldCancelRecording = dragOffset > 20
                                }
                            }
                            .onEnded { _ in
                                if isLongPressingState {
                                    isLongPressingState = false
                                    isShowingAudioRecorder = false
                                }
                            }
                    )
                }
                if inputStyle.isShowPhotoTaker {
                    Button(action: {
                        isShowingVideoRecorder = true
                    }) {
                        Image("input_camera", bundle: AtomicXChatResources.resourceBundle)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, textEditorState.verticalPadding)
        .background(themeState.colors.bgColorOperate)
        .clipped()
    }

    private func saveAndSendImage(_ imagePath: String) {
        sendImageMessage(imagePath)
        onSendImage?(URL(fileURLWithPath: imagePath))
    }

    private func createThumbnailAndSendVideo(_ videoPath: String, _ videoThumbnailPath: String?) {
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

    private func handleFileSelection(_ fileURL: URL) {
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

    private func checkMicrophonePermission() {
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

    private func sendTextMessage() {
        let text = getSendText()
        
        // Convert mention positions from display position to send text position
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
        
        messageManager.sendTextMessage(text, mentionList: convertedMentionList)
        
        // Clear draft after sending message
        conversationStore.setConversationDraft(conversationID: conversationID, draft: nil, completion: nil)
        
        // Clear mention list
        mentionList.removeAll()
        
        textEditorState.displayText = nil
        withAnimation {
            textHeight = 36
            isShowingEmojiPicker = false
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

    private func deleteLastCharacter() {
        textEditorState.deleteLastCharacter?()
    }

    private func showKeyboard() {
        withAnimation {
            isShowingEmojiPicker = false
            isShowingQuickReplies = false
            textEditorState.becomeFirstResponder?()
            isInputFocused = true
        }
    }

    private func showEmojiPicker() {
        withAnimation {
            isShowingEmojiPicker = true
            isShowingQuickReplies = false
            textEditorState.resignFirstResponder?()
            isInputFocused = false
        }
    }

    // MARK: - Mention Support
    
    /// Check if current conversation is a group chat
    private var isGroupChat: Bool {
        return conversationID.hasPrefix("group_")
    }
    
    /// Extract group ID from conversation ID
    private var groupID: String {
        if conversationID.hasPrefix("group_") {
            return String(conversationID.dropFirst(6))
        }
        return conversationID
    }
    
    /// Find mention to delete when backspace is pressed at given position
    /// Only triggers when cursor is inside the mention text (not at the position right after it)
    private func findMentionToDelete(at position: Int) -> MentionInfo? {
        for mention in mentionList {
            // Check if deletion position is strictly within mention range
            // position > startIndex: cursor is after the "@"
            // position < endIndex: cursor is before the trailing space (not at or after it)
            if position > mention.startIndex && position < mention.endIndex {
                return mention
            }
        }
        return nil
    }
    
    /// Insert multiple mentions into text and update mention list
    private func insertMentions(_ mentions: [MentionInfo], atPosition: Int) {
        guard !mentions.isEmpty else { return }
        guard let attributedString = textEditorState.displayText else { return }
        
        // Convert atPosition (in displayText) to position in text with emoji tags
        let adjustedPosition = convertDisplayPositionToTextPosition(atPosition, in: attributedString)
        var currentText = getSendText()
        
        // Handle empty text case (only "@" was typed)
        if currentText.isEmpty {
            currentText = "@"
        }
        
        // The "@" character is already in the text at adjustedPosition
        // We need to replace it with "@name1 @name2 ..."
        let atIndex = currentText.index(currentText.startIndex, offsetBy: min(adjustedPosition, currentText.count))
        let afterAtIndex = currentText.index(after: atIndex)
        
        // Build combined mention text: "@name1 @name2 @name3 "
        var combinedMentionText = ""
        var newMentions: [MentionInfo] = []
        var currentOffset = adjustedPosition
        
        for (index, mention) in mentions.enumerated() {
            var newMention = mention
            newMention.startIndex = currentOffset
            
            if index == 0 {
                // First mention replaces the existing "@"
                combinedMentionText += mention.mentionText
            } else {
                // Subsequent mentions add "@name "
                combinedMentionText += mention.mentionText
            }
            
            newMentions.append(newMention)
            currentOffset += mention.mentionText.count
        }
        
        // Replace "@" with combined mention text
        currentText.replaceSubrange(atIndex..<afterAtIndex, with: combinedMentionText)
        
        // Update existing mentions' positions (those after the insertion point)
        let insertedLength = combinedMentionText.count - 1 // -1 because we're replacing "@"
        for i in 0..<mentionList.count {
            if mentionList[i].startIndex > adjustedPosition {
                mentionList[i].startIndex += insertedLength
            }
        }
        
        // Add new mentions to list
        mentionList.append(contentsOf: newMentions)
        
        // Update text editor state
        let newAttributedString = EmojiManager.shared.createAttributedStringWithTextAndStyle(
            text: currentText,
            withFont: normalFont,
            textColor: normalColor
        )
        textEditorState.displayText = newAttributedString
    }
    
    /// Insert mention into text and update mention list
    private func insertMention(_ mention: MentionInfo, atPosition: Int) {
        insertMentions([mention], atPosition: atPosition)
    }
    
    /// Remove mention from list and update positions
    private func removeMention(_ mention: MentionInfo) {
        mentionList.removeAll { $0.userID == mention.userID && $0.startIndex == mention.startIndex }
        
        // Update positions of mentions after the removed one
        for i in 0..<mentionList.count {
            if mentionList[i].startIndex > mention.startIndex {
                mentionList[i].startIndex -= mention.length
            }
        }
    }
    
    /// Convert position in displayText (where emoji image = 1 char) to position in text with emoji tags
    /// e.g., "今天🥱@" position 3 -> "今天[TUIEmoji_Yawn]@" position 17
    private func convertDisplayPositionToTextPosition(_ displayPosition: Int, in attributedString: NSAttributedString) -> Int {
        var textPosition = 0
        var displayPos = 0
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, stop in
            if displayPos >= displayPosition {
                stop.pointee = true
                return
            }
            
            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
                // Emoji image takes 1 char in display, but emoji tag takes multiple chars in text
                if let emojiTag = attachment.emojiTag {
                    textPosition += emojiTag.count
                } else {
                    textPosition += "[emoji]".count
                }
                displayPos += range.length
            } else {
                let charsToAdd = min(range.length, displayPosition - displayPos)
                textPosition += charsToAdd
                displayPos += charsToAdd
            }
        }
        
        // Handle remaining position if not fully consumed
        if displayPos < displayPosition {
            textPosition += displayPosition - displayPos
        }
        
        return textPosition
    }

    private func getSendText() -> String {
        guard let attributedString = textEditorState.displayText else { return "" }
        var resultText = ""
        var currentPosition = 0
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { (attributes: [NSAttributedString.Key: Any], range: NSRange, _) in
            if currentPosition < range.location {
                let textRange = NSRange(location: currentPosition, length: range.location - currentPosition)
                resultText += attributedString.attributedSubstring(from: textRange).string
            }
            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
                if let emojiTag = attachment.emojiTag {
                    resultText += "\(emojiTag)"
                } else {
                    resultText += "[emoji]"
                }
            } else {
                resultText += attributedString.attributedSubstring(from: range).string
            }
            currentPosition = range.location + range.length
        }
        if currentPosition < attributedString.length {
            let textRange = NSRange(location: currentPosition, length: attributedString.length - currentPosition)
            resultText += attributedString.attributedSubstring(from: textRange).string
        }
        return resultText
    }
    
    private func saveDraftWithDebounce() {
        // Cancel previous work item
        draftSaveWorkItem?.cancel()
        
        // Create new work item with 800ms debounce
        let workItem = DispatchWorkItem {
            self.saveDraftImmediately()
        }
        draftSaveWorkItem = workItem
        
        // Execute after 800ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
    
    private func saveDraftImmediately() {
        let draftText = getSendText()
        
        if draftText.isEmpty {
            // Clear draft if input is empty
            conversationStore.setConversationDraft(conversationID: conversationID, draft: nil, completion: nil)
        } else {
            // Save draft with emoji codes
            conversationStore.setConversationDraft(conversationID: conversationID, draft: draftText, completion: nil)
        }
    }
    
    private func loadDraft() {
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: DraftConversationInfoHandler(
                onSuccess: { conversation in
                    DispatchQueue.main.async {
                        if let draft = conversation.draft,
                           !draft.isEmpty
                        {
                            // Set flag to prevent triggering save during load
                            isLoadingDraft = true

                            // Convert emoji codes to AttributedString with images
                            let draftAttributedString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: draft)

                            // Set the text editor state
                            textEditorState.displayText = draftAttributedString

                            // Auto focus and move cursor to the end after draft is loaded
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                textEditorState.becomeFirstResponder?()
                            }

                            // Reset flag after a short delay to allow UI update
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isLoadingDraft = false
                            }
                        }
                    }
                },
                onFailure: { _, desc in
                    print(">>>>> Failed to load draft: \(desc)")
                }
            )
        )
    }
}

private final class DraftConversationInfoHandler: GetConversationInfoCompletionHandler {
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
