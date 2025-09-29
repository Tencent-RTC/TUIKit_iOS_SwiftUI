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
    static let defaultValue: MessageInputConfigProtocol = ChatMessageInputStyle()
}

private extension EnvironmentValues {
    var MessageInputConfigProtocol: MessageInputConfigProtocol {
        get { self[MessageInputConfigProtocolKey.self] }
        set { self[MessageInputConfigProtocolKey.self] = newValue }
    }
}

public struct MessageInput: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var text: String
    @State private var showingEmojiPicker = false
    @State private var showingQuickReplies = false
    @State private var textHeight: CGFloat = 40
    @State private var isLongPressingState = false
    @State private var dragOffset: CGFloat = 0
    @State private var shouldCancelRecording = false
    @State private var isShowingAudioRecorder = false
    private var messageInputStore: MessageInputStore
    private let conversationID: String
    private let onHeightChange: (CGFloat) -> Void
    private let inputStyle: MessageInputConfigProtocol

    public init(text: Binding<String>,
                conversationID: String,
                style: MessageInputConfigProtocol, onHeightChange: @escaping (CGFloat) -> Void)
    {
        self._text = text
        self.conversationID = conversationID
        self.inputStyle = style
        self.onHeightChange = onHeightChange
        self.messageInputStore = MessageInputStore.create(conversationID: conversationID)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MessageInputView(
                text: $text,
                messageInputStore: messageInputStore,
                conversationID: conversationID,
                isLongPressingState: $isLongPressingState,
                dragOffset: $dragOffset,
                shouldCancelRecording: $shouldCancelRecording,
                isShowingAudioRecorder: $isShowingAudioRecorder
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ViewHeightKey.self, value: geo.size.height)
                        .onPreferenceChange(ViewHeightKey.self) { height in
                            onHeightChange(height)
                        }
                }
            )
            .onPreferenceChange(InputStateKey.self) { state in
                self.showingEmojiPicker = state.isShowingEmojiPicker
                self.showingQuickReplies = state.isShowingQuickReplies
                self.textHeight = state.textHeight
            }
            .environment(\.MessageInputConfigProtocol, inputStyle)
            if isShowingAudioRecorder {
                AudioRecorderView(
                    shouldCancelRecording: $shouldCancelRecording,
                    messageInputHeight: textHeight / 2,
                    enableAIDeNoise: false,
                    primary: themeState.currentPrimaryColor,
                    onRecordingComplete: { resultCode, path, duration in
                        print("audio recorde on recording complete. resultCode = \(resultCode) path = \(path) duration = \(duration)")
                        if resultCode == AudioRecordResultCode.success {
                            let messageManager = MessageInputManager(messageInputStore: messageInputStore)
                            messageManager.sendVoiceMessage(path, duration: Int(duration))
                        }
                        isShowingAudioRecorder = false
                    },
                    onTimeLimitReached: {
                        WindowToastManager.shared.show(LocalizedChatString("VoiceRecordTimeLimitReached"),type: .warning,duration: 5)
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
private let normalColor: UIColor = .black
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
}

private struct FixedHeightTextEditor: UIViewRepresentable {
    @ObservedObject var state: TextEditorState
    var maxLines: Int = 5
    var onSend: (() -> Void)? = nil

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
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != state.displayText?.string {
            textView.text = state.displayText?.string
            let currentPosition = textView.selectedRange.location
            textView.selectedRange = NSRange(location: currentPosition, length: 0)
        }
        context.coordinator.resetTextStyle()
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
        init(_ parent: FixedHeightTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {}

        func textViewDidEndEditing(_ textView: UITextView) {}

        func textViewDidChange(_ textView: UITextView) {
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
    @Binding var text: String
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

    init(text: Binding<String>,
         messageInputStore: MessageInputStore,
         conversationID: String,
         isLongPressingState: Binding<Bool>,
         dragOffset: Binding<CGFloat>,
         shouldCancelRecording: Binding<Bool>,
         isShowingAudioRecorder: Binding<Bool>)
    {
        self._text = text
        self.messageInputStore = messageInputStore
        self.conversationID = conversationID
        self._isLongPressingState = isLongPressingState
        self._dragOffset = dragOffset
        self._shouldCancelRecording = shouldCancelRecording
        self._isShowingAudioRecorder = isShowingAudioRecorder
        self.messageManager = MessageInputManager(messageInputStore: messageInputStore)
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
                if isShowingQuickReplies {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickReplies, id: \.self) { reply in
                                Button(action: {
                                    text = reply
                                    isShowingQuickReplies = false
                                }) {
                                    Text(reply)
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(themeState.colors.buttonColorPrimaryDefault.opacity(0.1))
                                        .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .frame(height: 40)
                    .background(themeState.colors.bgColorOperate)
                }
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
        .toast(self.messageManager.toastInstance)
        .animation(.easeInOut(duration: 0.2), value: isShowingQuickReplies)
        .animation(.easeInOut(duration: 0.2), value: isShowingEmojiPicker)
        .animation(.easeInOut(duration: 0.2), value: isShowingAudioRecorder)
        .animation(.easeInOut(duration: 0.2), value: textHeight)
        .frame(height: totalInputAreaHeight, alignment: .bottom)
        .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight : 0)
        .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
        .fullScreenCover(isPresented: $isShowingPhotoTaker) {
            VideoRecorderView(
                config: VideoRecorderConfigBuilder(
                    recordMode: .photoOnly,
                    primaryColor: themeState.currentPrimaryColor
                )
            ) { mediaURL, mediaType in
                var key = "lastTakenPhotoURL"
                if mediaType == .video {
                    key = "lastRecordedVideoURL"
                }
                UserDefaults.standard.set(mediaURL, forKey: key)
            }
            .onDisappear {
                if let videoURL = UserDefaults.standard.url(forKey: "lastRecordedVideoURL") {
                    UserDefaults.standard.removeObject(forKey: "lastRecordedVideoURL")
                    createThumbnailAndSendVideo(videoURL)
                } else if let photoURL = UserDefaults.standard.url(forKey: "lastTakenPhotoURL") {
                    UserDefaults.standard.removeObject(forKey: "lastTakenPhotoURL")
                    if let image = UIImage(contentsOfFile: photoURL.path) {
                        saveAndSendImage(image)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker.pickImages(sourceType: .photoLibrary, selectedImage: { image in
                if let image = image {
                    saveAndSendImage(image)
                }
            })
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker.pickVideos(selectedVideo: { videoURL in
                if let videoURL = videoURL {
                    createThumbnailAndSendVideo(videoURL)
                }
            })
        }
        .sheet(isPresented: $isShowingFilePicker) {
            FilePicker.pickFiles { selectedFile in
                if let url = selectedFile {
                    handleFileSelection(url)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingVideoRecorder) {
            VideoRecorderView(config: VideoRecorderConfigBuilder(
                recordMode: .videoPhotoMix,
                primaryColor: themeState.currentPrimaryColor
            )) { mediaURL, mediaType in
                var key = "lastRecordedVideoURL"
                if mediaType == .photo {
                    key = "lastTakenPhotoURL"
                }
                UserDefaults.standard.set(mediaURL, forKey: key)
            }
            .onDisappear {
                if let videoURL = UserDefaults.standard.url(forKey: "lastRecordedVideoURL") {
                    UserDefaults.standard.removeObject(forKey: "lastRecordedVideoURL")
                    createThumbnailAndSendVideo(videoURL)
                } else if let photoURL = UserDefaults.standard.url(forKey: "lastTakenPhotoURL") {
                    UserDefaults.standard.removeObject(forKey: "lastTakenPhotoURL")                    
                    let fileExists = FileManager.default.fileExists(atPath: photoURL.path)
                    print(" File exists: \(fileExists)")
                    if let image = UIImage(contentsOfFile: photoURL.path) {
                        saveAndSendImage(image)
                    } else {
                        print(" Failed to load image from path: \(photoURL.path)")
                        do {
                            let imageData = try Data(contentsOf: photoURL)
                            if let image = UIImage(data: imageData) {
                                print(" Successfully loaded image using Data method")
                                saveAndSendImage(image)
                            }
                        } catch {
                            print(" Failed to load image data: \(error.localizedDescription)")
                        }
                        
                    }

                }
            }
        }
        .actionSheet(isPresented: $isShowingMediaActionSheet) {
            ActionSheet(
                title: Text(LocalizedChatString("ChooseMediaType")),
                buttons: [
                    .default(Text(LocalizedChatString("MorePhoto"))) { isShowingImagePicker = true },
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
    }

    private var InputBarArea: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer()
            if inputStyle.isShowMore {
                Button(action: {
                    isShowingMediaActionSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 32, height: 32)
                }
            }
            ZStack(alignment: .trailing) {
                ZStack(alignment: .leading) {
                    if textEditorState.displayText?.string.count == 0 {
                        Text(LocalizedChatString("SendMessage"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.textColorTertiary)
                            .padding(.horizontal, textEditorState.horizontalPadding)
                            .padding(.vertical, textEditorState.verticalPadding)
                            .allowsHitTesting(false)
                    }
                    HStack {
                        FixedHeightTextEditor(state: textEditorState, maxLines: 5, onSend: {
                            sendTextMessage()
                        })
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
                VStack {
                    Button(action: {
                        if isShowingEmojiPicker {
                            showKeyboard()
                        } else {
                            showEmojiPicker()
                        }
                    }) {
                        Image(systemName: isShowingEmojiPicker ? "keyboard" : "face.smiling")
                            .font(.system(size: 20))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .padding(.top, 8)
                    Spacer()
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
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            .frame(width: 40, height: 40)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.1)
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
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .alignmentGuide(.top) { d in d[.top] }
                    .padding(.top, 6)
                }
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, textEditorState.verticalPadding)
        .background(themeState.colors.bgColorOperate)
        .clipped()
    }

    private func saveAndSendImage(_ image: UIImage) {
        let imagePath = ChatUtil.generateMediaPath(messageType: .image, withExtension: nil)
        let directory = (imagePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: URL(fileURLWithPath: imagePath))
            sendImageMessage(imagePath)
            onSendImage?(URL(fileURLWithPath: imagePath))
        }
    }

    private func createThumbnailAndSendVideo(_ videoURL: URL) {
        let videoPath = ChatUtil.generateMediaPath(messageType: .video, withExtension: "mp4")
        let thumbnailPath = ChatUtil.generateMediaPath(messageType: .image, withExtension: nil)
        let directory = (videoPath as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        let asset = AVAsset(url: videoURL)
        if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) {
            if FileManager.default.fileExists(atPath: videoPath) {
                try? FileManager.default.removeItem(atPath: videoPath)
            }
            exportSession.outputURL = URL(fileURLWithPath: videoPath)
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            let semaphore = DispatchSemaphore(value: 0)
            var exportSuccess = false
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    exportSuccess = true
                case .failed:
                    print("export video failed")
                case .cancelled:
                    print("export video cancelled")
                default:
                    print("export video status:\(exportSession.status.rawValue)")
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 60.0)
            if !exportSuccess {
                return
            }
        } else {
            return
        }
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
        if FileManager.default.fileExists(atPath: videoPath) {
        } else {}
        sendVideoMessage(videoPath, thumbnailPath)
        onSendVideo?(URL(fileURLWithPath: videoPath), URL(fileURLWithPath: thumbnailPath))
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
        messageManager.sendTextMessage(text)
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
}
