import AtomicXCore
import SwiftUI

// MARK: - AudioPlaybackManager

/// Manages the currently playing audio message ID
/// This is separate from AudioPlayer to avoid modifying its interface
public class AudioPlaybackManager: ObservableObject {
    @Published public var currentPlayingMsgID: String? = nil
    
    public init() {}
    
    public func setCurrentPlayingMsgID(_ msgID: String?) {
        currentPlayingMsgID = msgID
    }
    
    public func clearCurrentPlayingMsgID() {
        currentPlayingMsgID = nil
    }
    
    public func isPlaying(msgID: String?) -> Bool {
        guard let msgID = msgID, let currentMsgID = currentPlayingMsgID else {
            return false
        }
        return msgID == currentMsgID
    }
}

// MARK: - AudioMessageView

struct AudioMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var auxiliaryTextMenuManager: AuxiliaryTextMenuManager
    @Environment(\.asrDisplayManager) private var asrDisplayManager
    @ObservedObject private var audioPlayer: AudioPlayer
    @ObservedObject private var audioPlaybackManager: AudioPlaybackManager
    @State private var currentPlayTime: Double = 0
    @State private var timer: Timer?
    @State private var isConverting: Bool = false
    @State private var isAsrExpanded: Bool = false
    @State private var asrBubbleFrame: CGRect = .zero
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool
    
    init(messageBody: MessageBody, message: MessageInfo, messageListStore: MessageListStore, isLeft: Bool, isSelf: Bool, shouldHighlight: Bool, audioPlayer: AudioPlayer, audioPlaybackManager: AudioPlaybackManager) {
        self.messageBody = messageBody
        self.message = message
        self.messageListStore = messageListStore
        self.isLeft = isLeft
        self.isSelf = isSelf
        self.shouldHighlight = shouldHighlight
        self.audioPlayer = audioPlayer
        self.audioPlaybackManager = audioPlaybackManager
        // isAsrExpanded will be initialized from Environment in onAppear
    }
    
    // Check if ASR text bubble should be displayed
    private var shouldShowAsrBubble: Bool {
        if isConverting { return true }
        if !isAsrExpanded { return false }
        let asrText = messageBody.asrText ?? ""
        return !asrText.isEmpty
    }

    var body: some View {
        let duration = messageBody.soundDuration
        let isCurrentlyPlaying: Bool = {
            guard audioPlayer.isPlaying else {
                return false
            }
            return audioPlaybackManager.isPlaying(msgID: message.msgID)
        }()
        let displayText = isCurrentlyPlaying ? formatDuration(Int(currentPlayTime)) : formatDuration(duration)
        
        return VStack(alignment: isSelf ? .trailing : .leading, spacing: 6) {
            // Audio bubble
            audioBubbleView(isCurrentlyPlaying: isCurrentlyPlaying, displayText: displayText)
            
            // ASR text bubble
            if shouldShowAsrBubble {
                asrTextBubbleView
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onReceive(audioPlayer.$isPlaying) { isPlaying in
            if !isPlaying {
                stopTimer()
                audioPlaybackManager.clearCurrentPlayingMsgID()
            } else {
                if audioPlaybackManager.isPlaying(msgID: message.msgID) {
                    currentPlayTime = 0
                    startTimer()
                }
            }
        }
        .onReceive(audioPlaybackManager.$currentPlayingMsgID) { currentMsgID in
            if currentMsgID == message.msgID {
                if audioPlayer.isPlaying {
                    currentPlayTime = 0
                    startTimer()
                }
            } else {
                stopTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("convertVoiceToText"))) { notification in
            guard let userInfo = notification.userInfo,
                  let notificationMessage = userInfo["message"] as? MessageInfo,
                  notificationMessage.msgID == message.msgID else { return }
            
            convertVoiceToText()
        }
        .onAppear {
            // Initialize isAsrExpanded from in-memory state
            isAsrExpanded = asrDisplayManager.isExpanded(message.msgID)
        }
    }
    
    // MARK: - Audio Bubble View

    @ViewBuilder
    private func audioBubbleView(isCurrentlyPlaying: Bool, displayText: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCurrentlyPlaying {
                    audioPlayer.pause()
                    stopTimer()
                } else {
                    if messageBody.soundPath == nil || !FileManager.default.fileExists(atPath: messageBody.soundPath!) {
                        messageListStore.downloadMessageResource(message, resourceType: .sound, completion: { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async {
                                    if let soundPath = messageBody.soundPath {
                                        let url = URL(fileURLWithPath: soundPath)
                                        self.startPlayback(url: url, msgID: message.msgID)
                                    }
                                }
                            case .failure(let error):
                                break
                            }
                        })
                    } else {
                        if let soundPath = messageBody.soundPath {
                            let url = URL(fileURLWithPath: soundPath)
                            startPlayback(url: url, msgID: message.msgID)
                        }
                    }
                }
            }
            HStack(spacing: 2) {
                ForEach(0 ..< 8, id: \.self) { index in
                    let heights: [CGFloat] = [8, 16, 12, 20, 10, 14, 17, 8]
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 2, height: heights[index])
                        .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                        .opacity(isCurrentlyPlaying ? 0.4 + Double(index % 3) * 0.2 : 0.6)
                        .scaleEffect(y: isCurrentlyPlaying ? (0.3 + Double(index % 4) * 0.2) : 1.0)
                        .animation(
                            isCurrentlyPlaying ?
                                .easeInOut(duration: 0.4 + Double(index) * 0.1)
                                .repeatForever(autoreverses: true) :
                                .default,
                            value: isCurrentlyPlaying
                        )
                }
            }
            .frame(height: 24)
            Text(displayText)
                .font(.system(size: 12))
                .foregroundColor(isSelf ? themeState.colors.textColorSecondary : themeState.colors.textColorSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
    }
    
    // MARK: - ASR Text Bubble View

    @ViewBuilder
    private var asrTextBubbleView: some View {
        let asrText = messageBody.asrText ?? ""
        
        Group {
            if isConverting {
                // Loading state
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal)
                )
            } else {
                // Text display state
                Text(asrText)
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal)
                                .onAppear {
                                    asrBubbleFrame = geometry.frame(in: .global)
                                }
                                .onChange(of: geometry.frame(in: .global)) { newFrame in
                                    asrBubbleFrame = newFrame
                                }
                        }
                    )
                    .onLongPressGesture {
                        showAsrTextMenu(asrText: asrText)
                    }
            }
        }
    }
    
    // MARK: - Show ASR Text Menu

    private func showAsrTextMenu(asrText: String) {
        let actions = [
            AuxiliaryTextMenuAction(
                iconName: "message_hide",
                systemIconFallback: "eye.slash",
                label: LocalizedChatString("Hide")
            ) {
                isAsrExpanded = false
                asrDisplayManager.collapse(message.msgID)
            },
            AuxiliaryTextMenuAction(
                iconName: "message_forward",
                systemIconFallback: "arrowshape.turn.up.right",
                label: LocalizedChatString("Forward")
            ) {
                forwardAsrText()
            },
            AuxiliaryTextMenuAction(
                iconName: "message_copy",
                systemIconFallback: "doc.on.doc",
                label: LocalizedChatString("Copy")
            ) {
                UIPasteboard.general.string = asrText
                WindowToastManager.shared.show(LocalizedChatString("Copied"), type: .success, duration: 2)
            }
        ]
        
        auxiliaryTextMenuManager.showMenu(bubbleFrame: asrBubbleFrame, actions: actions)
    }
    
    // MARK: - Voice to Text Conversion

    private func convertVoiceToText() {
        guard !isConverting else { return }
        
        isConverting = true
        isAsrExpanded = true
        asrDisplayManager.expand(message.msgID)
        
        let messageActionStore = MessageActionStore.create(message: message)
        messageActionStore.convertVoiceToText(language: "") { result in
            DispatchQueue.main.async {
                self.isConverting = false
                
                switch result {
                case .success:
                    // Check if asrText is empty from the latest state
                    let messageList = self.messageListStore.state.value.messageList
                    let updatedMessage = messageList.first { $0.msgID == self.message.msgID }
                    let asrText = updatedMessage?.messageBody?.asrText ?? ""
                    
                    if asrText.isEmpty {
                        // Voice message has no content
                        print(">>>>> AudioMessageView: asrText is empty after conversion")
                        WindowToastManager.shared.error(LocalizedChatString("ConvertToTextFailed"))
                        self.isAsrExpanded = false
                        self.asrDisplayManager.collapse(self.message.msgID)
                    } else {
                        // Notify MessageList to scroll if needed
                        NotificationCenter.default.post(
                            name: NSNotification.Name("asrTextConversionCompleted"),
                            object: nil,
                            userInfo: ["msgID": self.message.msgID ?? ""]
                        )
                    }
                case .failure(let error):
                    print(">>>>> AudioMessageView: Voice to text conversion failed: \(error)")
                    WindowToastManager.shared.error(LocalizedChatString("ConvertToTextFailed"))
                }
            }
        }
    }
    
    // MARK: - Forward ASR Text

    private func forwardAsrText() {
        let asrText = messageBody.asrText ?? ""
        guard !asrText.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("forwardAsrText"),
            object: nil,
            userInfo: ["asrText": asrText]
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func startPlayback(url: URL, msgID: String?) {
        print("AudioMessageView: Starting playback for \(url.lastPathComponent)")
        currentPlayTime = 0
        audioPlaybackManager.setCurrentPlayingMsgID(msgID)
        audioPlayer.play(url)
        startTimer()
    }
    
    private func startTimer() {
        print("AudioMessageView: Starting timer")
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if audioPlayer.isPlaying {
                currentPlayTime += 0.1
                if Int(currentPlayTime) >= messageBody.soundDuration {
                    print("AudioMessageView: Playback completed")
                    stopTimer()
                }
            } else {
                print("AudioMessageView: Player not playing, stopping timer")
                stopTimer()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
