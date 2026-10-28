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

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MessageInputImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showingEmojiPicker = false
    @State private var showingQuickReplies = false
    @State private var textHeight: CGFloat = 40
    @State private var isLongPressingState = false
    @State private var dragOffset: CGFloat = 0
    @State private var shouldCancelRecording = false
    @State private var isShowingAudioRecorder = false
    @StateObject private var voiceRecordController: VoiceInputRecordController
    @StateObject private var voiceTranscriptionController = VoiceTranscriptionController()
    @State private var isShowingVoiceTranscription = false
    private var messageInputStore: MessageInputStore
    private let conversationID: String
    private let config: ChatMessageInputConfig
    private let messageManager: MessageInputManager

    init(
        conversationID: String,
        config: ChatMessageInputConfig? = nil
    ) {
        let resolvedConfig = config ?? ChatMessageInputConfig()
        self.conversationID = conversationID
        self.config = resolvedConfig
        let configuredDuration = resolvedConfig.audioMaxRecordDurationMs
        let duration = configuredDuration > 0 ? configuredDuration : ChatMessageInputConfig.defaultAudioMaxRecordDurationMs
        self._voiceRecordController = StateObject(wrappedValue: VoiceInputRecordController(maxDurationMs: duration))
        self.messageInputStore = MessageInputStore.create(conversationID: conversationID)
        self.messageManager = MessageInputManager(messageInputStore: messageInputStore, config: resolvedConfig)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MessageInputContentView(
                messageInputStore: messageInputStore,
                conversationID: conversationID,
                isLongPressingState: $isLongPressingState,
                dragOffset: $dragOffset,
                shouldCancelRecording: $shouldCancelRecording,
                isShowingAudioRecorder: $isShowingAudioRecorder,
                isShowingVoiceTranscription: $isShowingVoiceTranscription,
                voiceRecordController: voiceRecordController,
                voiceTranscriptionController: voiceTranscriptionController,
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
            .environment(\.messageInputConfig, config)
        }
        .onChange(of: isShowingAudioRecorder) { showing in
            if showing {
                WindowOverlayPresenter.shared.show(
                    VoiceRecordOverlayView(controller: voiceRecordController),
                    themeState: themeState,
                    interactive: false
                )
            } else {
                WindowOverlayPresenter.shared.dismiss()
            }
        }
        .onChange(of: isShowingVoiceTranscription) { showing in
            if showing {
                WindowOverlayPresenter.shared.show(
                    VoiceTranscriptionView(
                        controller: voiceTranscriptionController,
                        onCancel: {
                            isShowingVoiceTranscription = false
                            voiceTranscriptionController.cancel()
                        },
                        onSendAudio: { path, duration in
                            messageManager.sendVoiceMessage(path, duration: duration)
                            isShowingVoiceTranscription = false
                        },
                        onSendText: { text in
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                messageManager.sendTextMessage(trimmed, mentionList: [])
                            }
                            isShowingVoiceTranscription = false
                        }
                    ),
                    themeState: themeState,
                    interactive: true
                )
            } else {
                WindowOverlayPresenter.shared.dismiss()
            }
        }
    }
}

private extension View {
    func getScreenWidth() -> CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width
        #else
        return 390
        #endif
    }
}

private struct ChatMessageInputConfigKey: EnvironmentKey {
    static let defaultValue = ChatMessageInputConfig()
}

extension EnvironmentValues {
    var messageInputConfig: ChatMessageInputConfig {
        get { self[ChatMessageInputConfigKey.self] }
        set { self[ChatMessageInputConfigKey.self] = newValue }
    }
}

struct InputState: Equatable {
    var isShowingEmojiPicker: Bool = false
    var isShowingQuickReplies: Bool = false
    var textHeight: CGFloat = 36
}

let normalFont = UIKitFontScheme.caption1Regular
let normalColor = UIColor { _ in
    UIColor(ThemeState.shared.colors.textColorPrimary)
}

struct InputStateKey: PreferenceKey {
    static var defaultValue = InputState()
    static func reduce(value: inout InputState, nextValue: () -> InputState) {
        value = nextValue()
    }
}

class TextEditorState: ObservableObject {
    @Published var displayText: NSAttributedString?
    @Published var height: CGFloat = 36
    var verticalPadding: CGFloat = 0
    var horizontalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    var addEmojiString: ((NSAttributedString, String) -> Void)?
    var deleteLastCharacter: (() -> Void)?
    var becomeFirstResponder: (() -> Void)?
    var resignFirstResponder: (() -> Void)?
    var appendText: ((NSAttributedString) -> Void)?
}
