import AtomicXCore
import SwiftUI

struct TextMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var auxiliaryTextMenuManager: AuxiliaryTextMenuManager
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    @Environment(\.translationDisplayManager) private var translationDisplayManager
    @State private var isTranslating: Bool = false
    @State private var isTranslationExpanded: Bool = false
    @State private var translationBubbleFrame: CGRect = .zero
    @State private var pendingSplitResult: [String: Any]? = nil
    @State private var pendingOriginalText: String? = nil
    let payload: TextMessagePayload
    let message: MessageInfo
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    private var currentPayload: TextMessagePayload {
        if case .text(let payload) = message.messagePayload {
            return payload
        }
        return payload
    }
    
    init(payload: TextMessagePayload, message: MessageInfo, isLeft: Bool, isSelf: Bool, shouldHighlight: Bool) {
        self.payload = payload
        self.message = message
        self.isLeft = isLeft
        self.isSelf = isSelf
        self.shouldHighlight = shouldHighlight
        // isTranslationExpanded will be initialized from Environment in onAppear
    }
    
    private var shouldShowReceipt: Bool {
        MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: isInMergedDetailView)
    }
    
    // Check if translation bubble should be displayed
    private var shouldShowTranslationBubble: Bool {
        if isTranslating { return true }
        if !isTranslationExpanded { return false }
        let translatedText = currentPayload.translatedText ?? [:]
        return !translatedText.isEmpty
    }

    var body: some View {
        let text = currentPayload.text
        if !text.isEmpty {
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 6) {
                // Text bubble
                textBubbleContent(text: text)
                
                // Translation bubble
                if shouldShowTranslationBubble {
                    translationBubbleView
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("translateTextMessage"))) { notification in
                guard let userInfo = notification.userInfo,
                      let notificationMessage = userInfo["message"] as? MessageInfo,
                      notificationMessage.msgID == message.msgID else { return }
                translateText()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("translateMessage"))) { notification in
                guard let userInfo = notification.userInfo,
                      let messageID = userInfo["messageID"] as? String,
                      messageID == message.msgID,
                      isTranslating else { return }
                handleTranslationResult(userInfo: userInfo)
            }
            .onAppear {
                // Initialize isTranslationExpanded from in-memory state
                isTranslationExpanded = translationDisplayManager.isExpanded(message.msgID)
            }
        }
    }
    
    // MARK: - Text Bubble Content
    
    @ViewBuilder
    private func textBubbleContent(text: String) -> some View {
        if text.contains("[TUIEmoji_") {
            let attrString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: text)
            AttributedTextContainer(
                attributedString: attrString,
                message: message,
                isSelf: isSelf,
                isLeft: isLeft,
                shouldHighlight: shouldHighlight
            )
        } else {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .padding(.trailing, shouldShowReceipt ? 22 : 0)
                .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
        }
    }
    
    // MARK: - Translation Bubble View
    
    @ViewBuilder
    private var translationBubbleView: some View {
        let translatedTextMap = currentPayload.translatedText ?? [:]
        let originalText = currentPayload.text
        let translatedText = buildTranslatedDisplayText(originalText: originalText, translatedTextMap: translatedTextMap)
        
        Group {
            if isTranslating {
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
                VStack(alignment: .leading, spacing: 6) {
                    // Translated text content
                    if translatedText.contains("[TUIEmoji_") {
                        let attrString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: translatedText)
                        TranslationAttributedText(
                            attributedString: attrString,
                            textColor: isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary,
                            fontSize: 14
                        )
                    } else {
                        Text(translatedText)
                            .font(.system(size: 14))
                            .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                    }
                    
                    // Bottom tips
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary.opacity(0.6) : themeState.colors.textColorSecondary)
                        Text(LocalizedChatString("TranslateDefaultTips"))
                            .font(.system(size: 10))
                            .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary.opacity(0.6) : themeState.colors.textColorSecondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal)
                            .onAppear {
                                translationBubbleFrame = geometry.frame(in: .global)
                            }
                            .onChange(of: geometry.frame(in: .global)) { newFrame in
                                translationBubbleFrame = newFrame
                            }
                    }
                )
                .onLongPressGesture {
                    showTranslationMenu(translatedText: translatedText)
                }
            }
        }
    }
    
    // MARK: - Show Translation Menu
    
    private func showTranslationMenu(translatedText: String) {
        let actions = [
            AuxiliaryTextMenuAction(
                iconName: "message_forward",
                systemIconFallback: "arrowshape.turn.up.right",
                label: LocalizedChatString("Forward")
            ) {
                forwardTranslatedText()
            },
            AuxiliaryTextMenuAction(
                iconName: "message_copy",
                systemIconFallback: "doc.on.doc",
                label: LocalizedChatString("Copy")
            ) {
                UIPasteboard.general.string = translatedText
                WindowToastManager.shared.show(LocalizedChatString("Copied"), type: .success, duration: 2)
            }
        ]
        
        auxiliaryTextMenuManager.showMenu(bubbleFrame: translationBubbleFrame, actions: actions)
    }
    
    // MARK: - Translate Text
    
    private func translateText() {
        guard !isTranslating else { return }
        
        isTranslating = true
        isTranslationExpanded = true
        translationDisplayManager.expand(message.msgID)
        
        // Get text to translate
        let text = currentPayload.text
        guard !text.isEmpty else {
            isTranslating = false
            return
        }
        
        // Get @ user names first, then parse and translate
        TranslationTextParser.getAtUserNames(from: message) { atUserNames in
            self.performTranslation(text: text, atUserNames: atUserNames)
        }
    }
    
    private func performTranslation(text: String, atUserNames: [String]?) {
        // Parse text to separate emoji and @ from translatable text
        let splitResult = TranslationTextParser.splitTextByEmojiAndAtUsers(text, atUserNames: atUserNames)
        let textArray = splitResult?[TranslationTextParser.kSplitStringTextKey] as? [String] ?? []
        
        // If nothing to translate (pure emoji/@ message), show original text
        if textArray.isEmpty {
            DispatchQueue.main.async {
                self.isTranslating = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("translationCompleted"),
                    object: nil,
                    userInfo: ["msgID": self.message.msgID]
                )
            }
            return
        }
        
        // Store split result for later use when notification arrives
        pendingSplitResult = splitResult
        pendingOriginalText = text
        
        let messageActionStore = MessageActionStore.create(message: message)
        let targetLanguage = AppBuilderConfig.shared.translateTargetLanguage.isEmpty ? "en" : AppBuilderConfig.shared.translateTargetLanguage
        messageActionStore.translateText(sourceTextList: textArray, sourceLanguage: nil, targetLanguage: targetLanguage) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print(">>>>> TextMessageView: Translation failed: \(error)")
                    self.isTranslating = false
                    self.pendingSplitResult = nil
                    self.pendingOriginalText = nil
                    WindowToastManager.shared.error(LocalizedChatString("TranslateFailed"))
                }
            }
        }
    }
    
    // MARK: - Handle Translation Result
    
    private func handleTranslationResult(userInfo: [AnyHashable: Any]) {
        guard let _ = userInfo["translatedTextMap"] as? [String: String] else {
            print(">>>>> TextMessageView: No translatedTextMap in notification")
            isTranslating = false
            pendingSplitResult = nil
            pendingOriginalText = nil
            return
        }
        
        isTranslating = false
        pendingSplitResult = nil
        pendingOriginalText = nil
        
        // Translation result is persisted into messagePayload by AtomicXCore.
        NotificationCenter.default.post(
            name: NSNotification.Name("translationCompleted"),
            object: nil,
            userInfo: ["msgID": message.msgID]
        )
    }
    
    // MARK: - Forward Translated Text
    
    private func forwardTranslatedText() {
        let translatedTextMap = currentPayload.translatedText ?? [:]
        let originalText = currentPayload.text
        let translatedText = buildTranslatedDisplayText(originalText: originalText, translatedTextMap: translatedTextMap)
        guard !translatedText.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("forwardTranslatedText"),
            object: nil,
            userInfo: ["translatedText": translatedText]
        )
    }
    
    // MARK: - Build Translated Display Text
    
    private func buildTranslatedDisplayText(originalText: String, translatedTextMap: [String: String]) -> String {
        guard !translatedTextMap.isEmpty else { return "" }
        
        // Get @ user names for parsing
        var atUserNames: [String]? = nil
        let groupAtUserList = message.atUserList
        if !groupAtUserList.isEmpty {
            // For simplicity, use cached names if available
            atUserNames = nil
        }
        
        // Parse original text to get structure
        let splitResult = TranslationTextParser.splitTextByEmojiAndAtUsers(originalText, atUserNames: atUserNames)
        let resultArray = splitResult?[TranslationTextParser.kSplitStringResultKey] as? [String] ?? []
        let textIndexArray = splitResult?[TranslationTextParser.kSplitStringTextIndexKey] as? [Int] ?? []
        
        // Reconstruct with translated text
        return TranslationTextParser.replacedStringWithArray(resultArray, index: textIndexArray, replaceDict: translatedTextMap) ?? originalText
    }
}

struct AttributedTextContainer: View {
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    @State private var dynamicHeight: CGFloat = 0
    @State private var dynamicWidth: CGFloat = 0
    let attributedString: NSAttributedString
    let message: MessageInfo
    let isSelf: Bool
    let isLeft: Bool
    let shouldHighlight: Bool
    let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.7
    
    private var shouldShowReceipt: Bool {
        MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: isInMergedDetailView)
    }

    var body: some View {
        AttributedText(
            dynamicHeight: $dynamicHeight,
            dynamicWidth: $dynamicWidth,
            attributedString: attributedString,
            maxBubbleWidth: maxBubbleWidth,
            isSelf: isSelf
        )
        .frame(width: dynamicWidth, height: dynamicHeight)
        .background(Color.clear)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .padding(.trailing, shouldShowReceipt ? 22 : 0)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
    }
}

struct AttributedText: UIViewRepresentable {
    @EnvironmentObject var themeState: ThemeState
    @Binding var dynamicHeight: CGFloat
    @Binding var dynamicWidth: CGFloat
    let attributedString: NSAttributedString
    let maxBubbleWidth: CGFloat
    let isSelf: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textAlignment = .left
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            if value == nil {
                let font = UIFont.systemFont(ofSize: 16)
                let color = isSelf ? themeState.colors.textColorAntiPrimary.toUIColor() : themeState.colors.textColorPrimary.toUIColor()
                mutable.addAttribute(.font, value: font, range: range)
                mutable.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
        if uiView.attributedText != mutable {
            uiView.attributedText = mutable
        }
        let contentSize = uiView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let contentWidth = min(contentSize.width, maxBubbleWidth)
        let size = uiView.sizeThatFits(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        DispatchQueue.main.async {
            if self.dynamicHeight != size.height {
                self.dynamicHeight = size.height
            }
            if self.dynamicWidth != contentWidth {
                self.dynamicWidth = contentWidth
            }
        }
    }
}

// MARK: - Translation Attributed Text

struct TranslationAttributedText: View {
    @State private var dynamicHeight: CGFloat = 0
    @State private var dynamicWidth: CGFloat = 0
    let attributedString: NSAttributedString
    let textColor: Color
    let fontSize: CGFloat
    let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.7
    
    var body: some View {
        TranslationAttributedTextRepresentable(
            dynamicHeight: $dynamicHeight,
            dynamicWidth: $dynamicWidth,
            attributedString: attributedString,
            textColor: textColor,
            fontSize: fontSize,
            maxBubbleWidth: maxBubbleWidth
        )
        .frame(width: dynamicWidth > 0 ? dynamicWidth : nil, height: dynamicHeight > 0 ? dynamicHeight : nil)
    }
}

struct TranslationAttributedTextRepresentable: UIViewRepresentable {
    @Binding var dynamicHeight: CGFloat
    @Binding var dynamicWidth: CGFloat
    let attributedString: NSAttributedString
    let textColor: Color
    let fontSize: CGFloat
    let maxBubbleWidth: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textAlignment = .left
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            if value == nil {
                let font = UIFont.systemFont(ofSize: fontSize)
                mutable.addAttribute(.font, value: font, range: range)
                mutable.addAttribute(.foregroundColor, value: textColor.toUIColor(), range: range)
            }
        }
        uiView.attributedText = mutable
        
        // Calculate content size
        let contentSize = uiView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let contentWidth = min(contentSize.width, maxBubbleWidth)
        let size = uiView.sizeThatFits(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        DispatchQueue.main.async {
            if self.dynamicHeight != size.height {
                self.dynamicHeight = size.height
            }
            if self.dynamicWidth != contentWidth {
                self.dynamicWidth = contentWidth
            }
        }
    }
}
