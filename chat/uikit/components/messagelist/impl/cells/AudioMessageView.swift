import AtomicXCore
import SwiftUI

struct AudioMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject private var audioPlayer: AudioPlayer
    @ObservedObject private var audioPlaybackManager: AudioPlaybackManager
    @State private var currentPlayTime: Double = 0
    @State private var timer: Timer?
    let payload: AudioMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    private var currentAudioPayload: AudioMessagePayload? {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .audio(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return nil
    }

    init(payload: AudioMessagePayload, message: MessageInfo, messageListStore: MessageListStore, isLeft: Bool, isSelf: Bool, shouldHighlight: Bool, audioPlayer: AudioPlayer, audioPlaybackManager: AudioPlaybackManager) {
        self.payload = payload
        self.message = message
        self.messageListStore = messageListStore
        self.isLeft = isLeft
        self.isSelf = isSelf
        self.shouldHighlight = shouldHighlight
        self.audioPlayer = audioPlayer
        self.audioPlaybackManager = audioPlaybackManager
    }

    var body: some View {
        let duration = payload.audioDuration
        let isCurrentlyPlaying: Bool = {
            guard audioPlayer.isPlaying else {
                return false
            }
            return audioPlaybackManager.isPlaying(msgID: message.msgID)
        }()
        let displayText = formatDuration(duration)

        return audioBubbleView(isCurrentlyPlaying: isCurrentlyPlaying, displayText: displayText)
        .onDisappear {
            stopTimer()
        }
        // 旧停止事件可能延迟到达；读取当前播放状态，避免清掉新消息的播放标记。
        .onReceive(audioPlayer.$isPlaying) { _ in
            if !audioPlayer.isPlaying {
                stopTimer()
                audioPlaybackManager.clearCurrentPlayingMsgID()
            } else {
                if audioPlaybackManager.isPlaying(msgID: message.msgID) {
                    currentPlayTime = 0
                    startTimer()
                }
            }
        }
        .onReceive(audioPlaybackManager.$currentPlayingMsgID) { _ in
            if audioPlaybackManager.isPlaying(msgID: message.msgID) {
                if audioPlayer.isPlaying {
                    currentPlayTime = 0
                    startTimer()
                }
            } else {
                stopTimer()
            }
        }
    }


    @ViewBuilder
    private func audioBubbleView(isCurrentlyPlaying: Bool, displayText: String) -> some View {
        let contentColor = isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary
        HStack {
            if isSelf { Spacer(minLength: 0) }
            HStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                VoiceIconView(isPlaying: isCurrentlyPlaying, color: contentColor)
                Text(displayText)
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(contentColor)
                    .lineLimit(1)
            }
            if !isSelf { Spacer(minLength: 0) }
        }
        .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(width: Self.computeAudioBubbleWidth(duration: payload.audioDuration))
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrentlyPlaying {
                audioPlayer.pause()
                stopTimer()
            } else {
                handlePlayTap()
            }
        }
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
    }

    private static func computeAudioBubbleWidth(duration: Int) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let minWidth = min(max(screenWidth * 0.22, 80), 260)
        let maxWidth = min(max(screenWidth * 0.55, minWidth), 260)
        let clamped = min(max(CGFloat(duration), 1), 60)
        return minWidth + (maxWidth - minWidth) * (clamped / 60)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d\"", max(seconds, 0))
    }

    private func handlePlayTap() {
        if let path = currentAudioPayload?.audioPath ?? payload.audioPath,
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path)
        {
            startPlayback(url: URL(fileURLWithPath: path), msgID: message.msgID)
            return
        }
        if let urlString = currentAudioPayload?.audioURL ?? payload.audioURL,
           !urlString.isEmpty,
           let url = URL(string: urlString)
        {
            startPlayback(url: url, msgID: message.msgID)
            return
        }
        MessageActionStore.create(message: message).downloadMedia(quality: nil) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if let path = self.currentAudioPayload?.audioPath ?? self.payload.audioPath,
                       !path.isEmpty,
                       FileManager.default.fileExists(atPath: path)
                    {
                        self.startPlayback(url: URL(fileURLWithPath: path), msgID: self.message.msgID)
                    } else if let urlString = self.currentAudioPayload?.audioURL ?? self.payload.audioURL,
                              !urlString.isEmpty,
                              let url = URL(string: urlString)
                    {
                        self.startPlayback(url: url, msgID: self.message.msgID)
                    }
                }
            case .failure:
                break
            }
        }
    }

    private func startPlayback(url: URL, msgID: String?) {
        print("AudioMessageView: Starting playback for \(url.lastPathComponent)")
        currentPlayTime = 0
        audioPlayer.play(url)
        audioPlaybackManager.setCurrentPlayingMsgID(msgID)
        startTimer()
    }

    private func startTimer() {
        print("AudioMessageView: Starting timer")
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if audioPlayer.isPlaying {
                currentPlayTime += 0.1
                if Int(currentPlayTime) >= payload.audioDuration {
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


struct AsrTextBubbleView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var auxiliaryTextMenuManager: AuxiliaryTextMenuManager
    @Environment(\.asrDisplayManager) private var asrDisplayManager
    @State private var isConverting: Bool = false
    @State private var isAsrExpanded: Bool = false
    @State private var asrBubbleFrame: CGRect = .zero
    let payload: AudioMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isSelf: Bool
    var maxWidth: CGFloat = UIScreen.main.bounds.width * ChatMessageListConfig.defaultBubbleMaxWidthRatio

    private var currentAudioPayload: AudioMessagePayload? {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .audio(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return nil
    }

    private var shouldShowAsrBubble: Bool {
        if isConverting { return true }
        let asrText = currentAudioPayload?.asrText ?? payload.asrText ?? ""
        return !asrText.isEmpty
    }

    var body: some View {
        Group {
            if shouldShowAsrBubble {
                asrTextBubbleView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("convertVoiceToText"))) { notification in
            guard let userInfo = notification.userInfo,
                  let notificationMessage = userInfo["message"] as? MessageInfo,
                  notificationMessage.msgID == message.msgID else { return }

            convertVoiceToText()
        }
        .onAppear {
            isAsrExpanded = asrDisplayManager.isExpanded(message.msgID)
        }
    }


    @ViewBuilder
    private var asrTextBubbleView: some View {
        let asrText = currentAudioPayload?.asrText ?? payload.asrText ?? ""

        Group {
            if isConverting {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                .padding(.vertical, AuxiliaryTextBubbleMetrics.verticalInset)
                .padding(.horizontal, AuxiliaryTextBubbleMetrics.horizontalInset)
                .background(
                    RoundedRectangle(cornerRadius: AuxiliaryTextBubbleMetrics.cornerRadius)
                        .fill(isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal)
                )
            } else {
                Text(asrText)
                    .font(FontScheme.caption2Regular)
                    .lineSpacing(AuxiliaryTextBubbleMetrics.contentLineSpacing)
                    .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                    .frame(maxWidth: max(1, maxWidth - AuxiliaryTextBubbleMetrics.horizontalInset * 2), alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, AuxiliaryTextBubbleMetrics.verticalInset)
                    .padding(.horizontal, AuxiliaryTextBubbleMetrics.horizontalInset)
                    .background(
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: AuxiliaryTextBubbleMetrics.cornerRadius)
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


    private func showAsrTextMenu(asrText: String) {
        let actions = [
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
                    let messageList = self.messageListStore.state.value.messageList
                    let updatedMessage = messageList.first { $0.msgID == self.message.msgID }
                    let asrText: String
                    if case .audio(let payload) = updatedMessage?.messagePayload {
                        asrText = payload.asrText ?? ""
                    } else {
                        asrText = ""
                    }

                    if asrText.isEmpty {
                        print(">>>>> AsrTextBubbleView: asrText is empty after conversion")
                        WindowToastManager.shared.error(LocalizedChatString("ConvertToTextFailed"))
                        self.isAsrExpanded = false
                        self.asrDisplayManager.collapse(self.message.msgID)
                    } else {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("asrTextConversionCompleted"),
                            object: nil,
                            userInfo: ["msgID": self.message.msgID]
                        )
                    }
                case .failure(let error):
                    print(">>>>> AsrTextBubbleView: Voice to text conversion failed: \(error)")
                    WindowToastManager.shared.error(LocalizedChatString("ConvertToTextFailed"))
                }
            }
        }
    }


    private func forwardAsrText() {
        let asrText = currentAudioPayload?.asrText ?? payload.asrText ?? ""
        guard !asrText.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("forwardAsrText"),
            object: nil,
            userInfo: ["asrText": asrText]
        )
    }
}

private struct VoiceIconView: View {
    let isPlaying: Bool
    let color: Color

    private static let viewportSize: CGFloat = 33.7525
    private static let displaySize: CGFloat = 16
    private static let pathScale = displaySize / viewportSize
    private static let dimmedOpacity: Double = 76.0 / 255.0
    private static let animationStepInterval: TimeInterval = 0.3

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var step = 0
    @State private var animationTimer: Timer? = nil

    var body: some View {
        ZStack {
            Path(Self.buildDotPath(scale: Self.pathScale))
                .fill(color)
                .opacity(!isPlaying || step == 0 ? 1 : Self.dimmedOpacity)
            Path(Self.buildArcInnerPath(scale: Self.pathScale))
                .fill(color)
                .opacity(!isPlaying || step == 1 ? 1 : Self.dimmedOpacity)
            Path(Self.buildArcOuterPath(scale: Self.pathScale))
                .fill(color)
                .opacity(!isPlaying || step == 2 ? 1 : Self.dimmedOpacity)
        }
        .frame(width: Self.displaySize, height: Self.displaySize, alignment: .topLeading)
        .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)
        .onChange(of: isPlaying) { playing in
            if playing { startAnimating() } else { stopAnimating() }
        }
        .onDisappear { stopAnimating() }
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        step = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: Self.animationStepInterval, repeats: true) { _ in
            step = (step + 1) % 3
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        step = 0
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    private static func buildDotPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(10.12625, 17.0747, scale))
        path.addQuadCurve(to: point(9.13775, 14.6976, scale), controlPoint: point(10.12625, 15.6822, scale))
        path.addQuadCurve(to: point(6.75125, 13.7129, scale), controlPoint: point(8.14925, 13.7129, scale))
        path.addQuadCurve(to: point(4.36475, 14.6976, scale), controlPoint: point(5.35325, 13.7129, scale))
        path.addQuadCurve(to: point(3.37625, 17.0747, scale), controlPoint: point(3.37625, 15.6822, scale))
        path.addQuadCurve(to: point(4.36475, 19.4519, scale), controlPoint: point(3.37625, 18.4672, scale))
        path.addQuadCurve(to: point(6.75125, 20.4365, scale), controlPoint: point(5.35325, 20.4365, scale))
        path.addQuadCurve(to: point(9.13775, 19.4519, scale), controlPoint: point(8.14925, 20.4365, scale))
        path.addQuadCurve(to: point(10.12625, 17.0747, scale), controlPoint: point(10.12625, 18.4672, scale))
        path.close()
        return path.cgPath
    }

    private static func buildArcInnerPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(20.25125, 17.0745, scale))
        path.addCurve(to: point(16.05425, 7.3301, scale),
                      controlPoint1: point(20.25125, 13.2397, scale),
                      controlPoint2: point(18.63975, 9.7797, scale))
        path.addLine(to: point(13.73595, 9.7733, scale))
        path.addCurve(to: point(16.87625, 17.0745, scale),
                      controlPoint1: point(15.67065, 11.6102, scale),
                      controlPoint2: point(16.87625, 14.2021, scale))
        path.addCurve(to: point(13.89755, 24.2189, scale),
                      controlPoint1: point(16.87625, 19.8661, scale),
                      controlPoint2: point(15.73755, 22.3928, scale))
        path.addLine(to: point(16.27795, 26.6021, scale))
        path.addCurve(to: point(20.25125, 17.0745, scale),
                      controlPoint1: point(18.73225, 24.1672, scale),
                      controlPoint2: point(20.25125, 20.7975, scale))
        path.close()
        return path.cgPath
    }

    private static func buildArcOuterPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(27.00125, 17.0746, scale))
        path.addCurve(to: point(20.69045, 2.4432, scale),
                      controlPoint1: point(27.00125, 11.3146, scale),
                      controlPoint2: point(24.57745, 6.1186, scale))
        path.addLine(to: point(22.00875, 0, scale))
        path.addCurve(to: point(30.37625, 17.0746, scale),
                      controlPoint1: point(27.54645, 4.2882, scale),
                      controlPoint2: point(30.37625, 10.3522, scale))
        path.addCurve(to: point(23.41855, 33.7525, scale),
                      controlPoint1: point(30.37625, 23.5922, scale),
                      controlPoint2: point(27.71625, 29.491, scale))
        path.addLine(to: point(21.03815, 31.3693, scale))
        path.addCurve(to: point(27.00125, 17.0746, scale),
                      controlPoint1: point(24.72155, 27.7166, scale),
                      controlPoint2: point(27.00125, 22.6608, scale))
        path.close()
        return path.cgPath
    }
}


