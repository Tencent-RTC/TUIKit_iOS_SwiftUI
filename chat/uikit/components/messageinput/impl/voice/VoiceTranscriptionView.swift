import AVFoundation
import SwiftUI
import UIKit


enum VoiceTranscriptionLanguageStore {
    struct Option {
        let code: String
        let nativeName: String
    }

    static let options: [Option] = [
        Option(code: "zh", nativeName: "简体中文"),
        Option(code: "zh-TW", nativeName: "繁體中文"),
        Option(code: "en", nativeName: "English"),
        Option(code: "ja", nativeName: "日本語"),
        Option(code: "ko", nativeName: "한국어"),
        Option(code: "fr", nativeName: "Français"),
        Option(code: "es", nativeName: "Español"),
        Option(code: "it", nativeName: "Italiano"),
        Option(code: "de", nativeName: "Deutsch"),
        Option(code: "tr", nativeName: "Türkçe"),
        Option(code: "ru", nativeName: "Русский"),
        Option(code: "pt", nativeName: "Português"),
        Option(code: "vi", nativeName: "Tiếng Việt"),
        Option(code: "id", nativeName: "Bahasa Indonesia"),
        Option(code: "th", nativeName: "ภาษาไทย"),
        Option(code: "ms", nativeName: "Bahasa Melayu"),
        Option(code: "hi", nativeName: "हिन्दी"),
    ]

    private static let key = "AtomicXRecordTranslateTargetLanguage"

    static var selected: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}


final class VoiceTranscriptionController: ObservableObject {
    enum State {
        case loading
        case text
        case empty
    }

    @Published private(set) var state: State = .loading
    @Published var editText: String = ""
    @Published private(set) var translatedText: String?
    @Published private(set) var translationFailed = false
    @Published private(set) var isTranslating = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPreviewPlaying = false
    @Published private(set) var waveformDurationMs: Int = 0
    @Published private(set) var waveformPseudoSpeaking = false
    @Published private(set) var waveformFlat = true

    private(set) var audioPath: String = ""
    private(set) var durationSec: Int = 0
    private(set) var originalAudioDurationMs: Int = 0
    private var originalText: String = ""
    private var session = 0
    private var audioPlayer: AVAudioPlayer?

    var bubbleTextColor_isWhite: Bool { true }


    func transcribe(filePath: String, durationSec: Int) {
        session += 1
        let currentSession = session
        audioPath = filePath
        self.durationSec = durationSec
        originalAudioDurationMs = durationSec * 1000
        waveformDurationMs = originalAudioDurationMs
        state = .loading
        editText = ""
        translatedText = nil
        translationFailed = false
        isTranslating = false
        isSpeaking = false
        isPreviewPlaying = false
        originalText = ""
        ExperimentalAPI.convertLocalAudioToText(filePath: filePath, onSuccess: { [weak self] text in
            guard let self = self, currentSession == self.session else { return }
            self.updateResult(text)
        }, onFailure: { [weak self] _, _ in
            guard let self = self, currentSession == self.session else { return }
            self.updateResult(nil)
        })
    }

    private func updateResult(_ resultText: String?) {
        translationFailed = false
        if let resultText = resultText, !resultText.isEmpty {
            state = .text
            if originalText.isEmpty {
                originalText = resultText
            }
            translatedText = nil
            isTranslating = false
            if isSpeaking {
                isSpeaking = false
                stopAllAudio()
            }
            editText = resultText
        } else {
            state = .empty
            editText = LocalizedChatString("message_input_voice_transcription_empty")
        }
        waveformFlat = true
        waveformPseudoSpeaking = false
    }

    func cancel() {
        session += 1
        stopAllAudio()
    }


    func handleTranslateChip(onLanguageNeeded: @escaping (@escaping (String) -> Void) -> Void) {
        if isTranslating { return }
        let lang = VoiceTranscriptionLanguageStore.selected
        if lang.isEmpty {
            onLanguageNeeded { [weak self] picked in
                VoiceTranscriptionLanguageStore.selected = picked
                self?.translateWith(picked)
            }
        } else {
            translateWith(lang)
        }
    }

    func handleSwitchLanguage(onLanguageNeeded: @escaping (@escaping (String) -> Void) -> Void) {
        if isTranslating { return }
        onLanguageNeeded { [weak self] picked in
            VoiceTranscriptionLanguageStore.selected = picked
            self?.translateWith(picked)
        }
    }

    func handleUndoTranslate() {
        session += 1
        if isSpeaking {
            stopReadAloud()
        }
        translatedText = nil
        translationFailed = false
        isTranslating = false
        editText = originalText
    }

    private func translateWith(_ languageCode: String) {
        guard !originalText.isEmpty, !isTranslating else { return }
        let currentSession = session
        isTranslating = true
        ExperimentalAPI.translateSingleText(
            text: originalText,
            targetLanguage: languageCode,
            onSuccess: { [weak self] translated in
                guard let self = self, currentSession == self.session else { return }
                guard !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.handleTranslationFailure()
                    return
                }
                self.isTranslating = false
                self.translationFailed = false
                self.translatedText = translated
                self.editText = translated
            },
            onFailure: { [weak self] _, _ in
                guard let self = self, currentSession == self.session else { return }
                self.handleTranslationFailure()
            }
        )
    }

    private func handleTranslationFailure() {
        isTranslating = false
        translationFailed = true
        WindowToastManager.shared.error(LocalizedChatString("voice_message_translate_failed"))
    }


    func handleReadAloud() {
        if isSpeaking {
            stopReadAloud()
            return
        }
        let current = editText
        guard !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSpeaking = true
        waveformPseudoSpeaking = true
        ExperimentalAPI.convertTextToVoice(text: current, onSuccess: { [weak self] urlString in
            guard let self = self, self.isSpeaking else { return }
            guard let audioURL = URL(string: urlString) else {
                self.stopReadAloud()
                return
            }
            URLSession.shared.downloadTask(with: audioURL) { [weak self] localURL, _, error in
                let data = (localURL.flatMap { try? Data(contentsOf: $0) })
                DispatchQueue.main.async {
                    guard let self = self, self.isSpeaking else { return }
                    guard error == nil, let data = data else {
                        self.stopReadAloud()
                        return
                    }
                    self.playAudioData(data, isTTS: true)
                }
            }.resume()
        }, onFailure: { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self = self, self.isSpeaking else { return }
                self.stopReadAloud()
            }
        })
    }

    func stopReadAloud() {
        isSpeaking = false
        waveformPseudoSpeaking = false
        waveformDurationMs = originalAudioDurationMs
        stopAllAudio()
    }


    func toggleWaveformPlayback() {
        if isPreviewPlaying {
            audioPlayer?.pause()
            isPreviewPlaying = false
            waveformFlat = true
            return
        }
        let url = URL(fileURLWithPath: audioPath)
        playAudio(url, isTTS: false)
    }

    private func playAudio(_ url: URL, isTTS: Bool) {
        stopAllAudio()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        startPlayer(player, isTTS: isTTS)
    }

    private func playAudioData(_ data: Data, isTTS: Bool) {
        stopAllAudio()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        guard let player = try? AVAudioPlayer(data: data) else {
            if isTTS { stopReadAloud() }
            return
        }
        startPlayer(player, isTTS: isTTS)
    }

    private func startPlayer(_ player: AVAudioPlayer, isTTS: Bool) {
        audioPlayer = player
        player.play()
        if isTTS {
            let ttsMs = Int(player.duration * 1000)
            if ttsMs > 0 {
                waveformDurationMs = ttsMs
            }
        } else {
            isPreviewPlaying = true
            waveformFlat = false
        }
    }

    private func stopAllAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPreviewPlaying = false
        waveformFlat = true
        waveformPseudoSpeaking = false
    }

    func handlePlaybackFinished() {
        audioPlayer = nil
        isPreviewPlaying = false
        waveformFlat = true
        if isSpeaking {
            stopReadAloud()
        }
    }

    var playerIsPlaying: Bool {
        audioPlayer?.isPlaying == true
    }

    var hasPlayer: Bool {
        audioPlayer != nil
    }


    var canSendText: Bool {
        state == .text && !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func renderedTextExceedsSingleLine(bubbleWidth: CGFloat) -> Bool {
        let width = bubbleWidth - 32
        guard width > 0, !editText.isEmpty else { return false }
        let height = (editText as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIKitFontScheme.caption1Regular],
            context: nil
        ).height
        return height > UIKitFontScheme.caption1Regular.lineHeight + 1
    }
}


struct VoiceTranscriptionView: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject var controller: VoiceTranscriptionController
    let onCancel: () -> Void
    let onSendAudio: (String, Int) -> Void
    let onSendText: (String) -> Void

    private let designWidthDP: CGFloat = 375
    private let bubbleTriangleHeight: CGFloat = 14
    private let chipRowHeight: CGFloat = 26
    private let bubbleWidthDP: CGFloat = 330
    private let bubbleLeftMarginDP: CGFloat = 22
    private let waveformHorizontalMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private let iconButtonSize: CGFloat = 48
    private let sendTextButtonSize: CGFloat = 80
    private let labelHeight: CGFloat = 20
    private let waveformHeight: CGFloat = 40
    private let waveformBottom: CGFloat = 43
    private let labelToWaveformGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)
    private let iconToLabelGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    private let sendTextToWaveformGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)
    private let chipRowToActionGap: CGFloat = CGFloat(SpacingScheme.titleSpacing)
    private let bubbleToKeyboardGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)
    private let bubbleToChipGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    private let cancelButtonLeftDP: CGFloat = 48
    private let sendAudioButtonLeftDP: CGFloat = 142
    private let sendTextButtonLeftDP: CGFloat = 247
    private let smallBubbleHeight: CGFloat = 68
    private let largeBubbleHeight: CGFloat = 104

    @State private var keyboardHeight: CGFloat = 0

    private func scaleX(_ dp: CGFloat, width: CGFloat) -> CGFloat {
        dp * width / designWidthDP
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let bubbleWidth = scaleX(bubbleWidthDP, width: width)
            let multiLine = controller.state == .text && controller.renderedTextExceedsSingleLine(bubbleWidth: bubbleWidth)
            let bubbleHeight = multiLine ? largeBubbleHeight : smallBubbleHeight
            let layout = calculateLayout(rootHeight: height, bubbleHeight: bubbleHeight)
            let bubbleX = scaleX(bubbleLeftMarginDP, width: width)
            let sendTextCenterX = scaleX(sendTextButtonLeftDP, width: width) + sendTextButtonSize / 2

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: themeState.colors.bgColorOperate.opacity(0), location: 0),
                        .init(color: themeState.colors.bgColorOperate.opacity(0), location: 0.442),
                        .init(color: themeState.colors.bgColorOperate, location: 0.632),
                        .init(color: themeState.colors.bgColorOperate, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

                bubbleContent(bubbleWidth: bubbleWidth, bubbleHeight: bubbleHeight, arrowCenterX: sendTextCenterX - bubbleX)
                    .frame(width: bubbleWidth, height: bubbleHeight)
                    .position(x: bubbleX + bubbleWidth / 2, y: layout.bubbleTop + bubbleHeight / 2)

                if controller.state == .text {
                    chipRow
                        .frame(width: width - bubbleX * 2, height: chipRowHeight)
                        .position(x: bubbleX + (width - bubbleX * 2) / 2, y: layout.chipRowTop + chipRowHeight / 2)
                }

                circleIconButton(systemIcon: "xmark", action: onCancel)
                    .frame(width: iconButtonSize, height: iconButtonSize)
                    .position(
                        x: scaleX(cancelButtonLeftDP, width: width) + iconButtonSize / 2,
                        y: layout.iconButtonTop + iconButtonSize / 2
                    )
                circleIconButton(systemIcon: "waveform", action: {
                    onSendAudio(controller.audioPath, max(controller.durationSec, 1))
                })
                .frame(width: iconButtonSize, height: iconButtonSize)
                .position(
                    x: scaleX(sendAudioButtonLeftDP, width: width) + iconButtonSize / 2,
                    y: layout.iconButtonTop + iconButtonSize / 2
                )
                Button(action: {
                    onSendText(controller.editText)
                }) {
                    Text(LocalizedChatString("message_input_send"))
                        .font(themeState.fonts.caption1Medium)
                        .foregroundColor(themeState.colors.textColorButton)
                        .frame(width: sendTextButtonSize, height: sendTextButtonSize)
                        .background(controller.canSendText ? themeState.colors.buttonColorPrimaryDefault : themeState.colors.buttonColorPrimaryDisabled)
                        .clipShape(Circle())
                }
                .disabled(!controller.canSendText)
                .position(
                    x: sendTextCenterX,
                    y: layout.sendTextButtonTop + sendTextButtonSize / 2
                )

                Text(LocalizedChatString("message_input_cancel"))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .frame(width: 96, height: labelHeight)
                    .position(
                        x: scaleX(cancelButtonLeftDP, width: width) + iconButtonSize / 2,
                        y: layout.labelTop + labelHeight / 2
                    )
                Text(LocalizedChatString("message_input_send_original_voice"))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .frame(width: 96, height: labelHeight)
                    .position(
                        x: scaleX(sendAudioButtonLeftDP, width: width) + iconButtonSize / 2,
                        y: layout.labelTop + labelHeight / 2
                    )

                TranscriptionWaveformRepresentable(controller: controller, themeState: themeState)
                    .frame(width: width - scaleX(waveformHorizontalMargin, width: width) * 2, height: waveformHeight)
                    .position(
                        x: width / 2,
                        y: layout.waveformTop + waveformHeight / 2
                    )
                    .onTapGesture {
                        controller.toggleWaveformPlayback()
                    }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity.animation(.easeIn(duration: 0.12)))
        .onAppear {
            PlaybackFinishWatcher.shared.attach(controller: controller)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenH = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }.first ?? 0
            keyboardHeight = frame.minY < screenH ? max(screenH - frame.minY, 0) : 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private struct OverlayLayout {
        let bubbleTop: CGFloat
        let chipRowTop: CGFloat
        let iconButtonTop: CGFloat
        let sendTextButtonTop: CGFloat
        let labelTop: CGFloat
        let waveformTop: CGFloat
    }

    private func calculateLayout(rootHeight: CGFloat, bubbleHeight: CGFloat) -> OverlayLayout {
        let safeRootHeight = max(rootHeight, 1)
        let chipBlock: CGFloat = controller.state == .text ? (chipRowHeight + bubbleToChipGap) : 0

        let waveformTop = max(safeRootHeight - waveformBottom - waveformHeight, 0)
        let labelTop = max(waveformTop - labelToWaveformGap - labelHeight, 0)
        let iconButtonTop = max(labelTop - iconToLabelGap - iconButtonSize, 0)
        let sendTextButtonTop = max(waveformTop - sendTextToWaveformGap - sendTextButtonSize, 0)
        let firstActionTop = min(iconButtonTop, sendTextButtonTop)

        let bubbleTopAboveActions = max(firstActionTop - chipRowToActionGap - chipBlock - bubbleHeight, 0)
        let maxBubbleTopBeforeKeyboard: CGFloat = keyboardHeight > 0
            ? max(safeRootHeight - keyboardHeight - bubbleToKeyboardGap - chipBlock - bubbleHeight, 0)
            : .greatestFiniteMagnitude
        let bubbleTop = min(bubbleTopAboveActions, maxBubbleTopBeforeKeyboard)
        return OverlayLayout(
            bubbleTop: bubbleTop,
            chipRowTop: bubbleTop + bubbleHeight + bubbleToChipGap,
            iconButtonTop: iconButtonTop,
            sendTextButtonTop: sendTextButtonTop,
            labelTop: labelTop,
            waveformTop: waveformTop
        )
    }

    private func bubbleContent(bubbleWidth: CGFloat, bubbleHeight: CGFloat, arrowCenterX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TranscriptionBubbleShape(arrowCenterX: arrowCenterX, triangleHeight: bubbleTriangleHeight)
                .fill(controller.state == .empty ? themeState.colors.buttonColorHangupDefault : themeState.colors.buttonColorPrimaryDefault)
            Group {
                if controller.state == .loading {
                    HStack {
                        LoadingDotsView(dotColor: themeState.colors.textColorButton)
                            .frame(width: 48, height: 20)
                            .padding(.leading, CGFloat(SpacingScheme.contentSpacing))
                        Spacer()
                    }
                } else {
                    BubbleTextView(
                        text: $controller.editText,
                        isEditable: controller.state == .text,
                        textColor: UIColor(themeState.colors.textColorButton)
                    )
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                }
            }
            .frame(width: bubbleWidth, height: bubbleHeight - bubbleTriangleHeight)
        }
    }

    private func circleIconButton(systemIcon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(FontScheme.body3Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeState.colors.buttonColorSecondaryDefault)
                .clipShape(Circle())
        }
    }

    private var chipRow: some View {
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            if controller.translatedText == nil {
                chip(title: LocalizedChatString("voice_message_translate"), enabled: !controller.isTranslating) {
                    controller.handleTranslateChip(onLanguageNeeded: presentLanguageSelector)
                }
            } else {
                chip(title: LocalizedChatString("voice_message_undo_translate"), enabled: true) {
                    controller.handleUndoTranslate()
                }
            }
            if controller.translatedText != nil || controller.translationFailed {
                dualPill(
                    leftTitle: LocalizedChatString("voice_message_switch_language"),
                    leftEnabled: !controller.isTranslating,
                    rightTitle: controller.isSpeaking
                        ? LocalizedChatString("voice_message_stop")
                        : LocalizedChatString("voice_message_read_aloud"),
                    onLeft: {
                        controller.handleSwitchLanguage(onLanguageNeeded: presentLanguageSelector)
                    },
                    onRight: {
                        controller.handleReadAloud()
                    }
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(themeState.fonts.caption3Regular)
                .foregroundColor(enabled ? themeState.colors.textColorSecondary : themeState.colors.textColorDisable)
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.vertical, 3)
                .frame(height: chipRowHeight)
                .background(themeState.colors.buttonColorSecondaryDefault)
                .cornerRadius(CGFloat(RadiusScheme.roundRadius))
        }
        .disabled(!enabled)
    }

    private func dualPill(leftTitle: String, leftEnabled: Bool, rightTitle: String, onLeft: @escaping () -> Void, onRight: @escaping () -> Void) -> some View {
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            Button(action: onLeft) {
                Text(leftTitle)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(leftEnabled ? themeState.colors.textColorSecondary : themeState.colors.textColorDisable)
            }
            .disabled(!leftEnabled)
            Rectangle()
                .fill(themeState.colors.strokeColorPrimary)
                .frame(width: 0.5, height: 12)
            Button(action: onRight) {
                Text(rightTitle)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
        .padding(.vertical, 3)
        .frame(height: chipRowHeight)
        .background(themeState.colors.buttonColorSecondaryDefault)
        .cornerRadius(CGFloat(RadiusScheme.roundRadius))
    }

    private func presentLanguageSelector(onPicked: @escaping (String) -> Void) {
        let sheet = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        let current = VoiceTranscriptionLanguageStore.selected
        for option in VoiceTranscriptionLanguageStore.options {
            let action = UIAlertAction(title: option.nativeName, style: .default) { _ in
                onPicked(option.code)
            }
            if option.code == current {
                action.setValue(true, forKey: "checked")
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        if let overlayRoot = WindowOverlayPresenter.shared.overlayRootViewController {
            overlayRoot.present(sheet, animated: true)
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(sheet, animated: true)
    }
}


private struct TranscriptionBubbleShape: Shape {
    var arrowCenterX: CGFloat
    var triangleHeight: CGFloat
    var cornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)
    var halfArrow: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyBottom = rect.height - triangleHeight
        let bodyRect = CGRect(x: 0, y: 0, width: rect.width, height: bodyBottom)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        let centerX = min(max(arrowCenterX, cornerRadius + halfArrow), rect.width - cornerRadius - halfArrow)
        path.move(to: CGPoint(x: centerX - halfArrow, y: bodyBottom))
        path.addLine(to: CGPoint(x: centerX, y: rect.height))
        path.addLine(to: CGPoint(x: centerX + halfArrow, y: bodyBottom))
        path.closeSubpath()
        return path
    }
}


private final class VerticalCenteringTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let topOffset = max(0, (bounds.height - contentSize.height) / 2)
        if abs(textContainerInset.top - topOffset) > 0.5 {
            textContainerInset.top = topOffset
        }
    }
}

private struct BubbleTextView: UIViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = VerticalCenteringTextView()
        textView.backgroundColor = .clear
        textView.font = UIKitFontScheme.caption1Regular
        textView.textColor = textColor
        textView.textAlignment = .left
        textView.semanticContentAttribute = .forceLeftToRight
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.returnKeyType = .done
        textView.delegate = context.coordinator
        textView.text = text
        textView.isEditable = isEditable
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEditable = isEditable
        uiView.textColor = textColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BubbleTextView

        init(_ parent: BubbleTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                textView.resignFirstResponder()
                return false
            }
            return true
        }
    }
}


private struct LoadingDotsView: View {
    let dotColor: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 0.9) / 0.9
            HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = (progress + CGFloat(index) * 0.18).truncatingRemainder(dividingBy: 1)
                    let alpha = (90 + 165 * abs(sin(phase * .pi))) / 255
                    Circle()
                        .fill(dotColor.opacity(alpha))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}


private struct TranscriptionWaveformRepresentable: UIViewRepresentable {
    @ObservedObject var controller: VoiceTranscriptionController
    var themeState: ThemeState

    func makeUIView(context: Context) -> RecorderBubbleUIView {
        let view = RecorderBubbleUIView()
        view.setBubbleColor(UIColor(themeState.colors.bgColorInput))
        view.setContentColor(UIColor(themeState.colors.textColorPrimary))
        view.setPowerLevel(60)
        view.setDurationText(formatDuration(controller.waveformDurationMs))
        view.setFlat(true)
        view.stopAnimating()
        return view
    }

    func updateUIView(_ uiView: RecorderBubbleUIView, context: Context) {
        uiView.setBubbleColor(UIColor(themeState.colors.bgColorInput))
        uiView.setContentColor(UIColor(themeState.colors.textColorPrimary))
        uiView.setPowerLevel(60)
        uiView.setDurationText(formatDuration(controller.waveformDurationMs))
        if controller.waveformPseudoSpeaking {
            uiView.setPseudoSpeaking(true)
        } else {
            uiView.setPseudoSpeaking(false)
            uiView.setFlat(controller.waveformFlat)
            if !controller.waveformFlat {
                uiView.startAnimating()
            } else {
                uiView.stopAnimating()
            }
        }
    }

    static func dismantleUIView(_ uiView: RecorderBubbleUIView, coordinator: ()) {
        uiView.stopAnimating()
    }

    private func formatDuration(_ ms: Int) -> String {
        guard ms > 0 else { return "--:--" }
        let seconds = ms / 1000
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}


private final class PlaybackFinishWatcher {
    static let shared = PlaybackFinishWatcher()
    private var timer: Timer?
    private weak var controller: VoiceTranscriptionController?

    func attach(controller: VoiceTranscriptionController) {
        self.controller = controller
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak controller] timer in
            guard let self = self, let controller = controller else {
                timer.invalidate()
                return
            }
            if (controller.isPreviewPlaying || controller.isSpeaking), controller.hasPlayer, !controller.playerIsPlaying {
                controller.handlePlaybackFinished()
            }
        }
    }
}
