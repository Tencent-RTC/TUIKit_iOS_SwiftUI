import AtomicXCore
import SwiftUI

struct TextMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    let payload: TextMessagePayload
    let message: MessageInfo
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool
    let maxContentWidth: CGFloat?

    private var currentPayload: TextMessagePayload {
        if case .text(let payload) = message.messagePayload {
            return payload
        }
        return payload
    }

    init(payload: TextMessagePayload, message: MessageInfo, isLeft: Bool, isSelf: Bool, shouldHighlight: Bool, maxContentWidth: CGFloat? = nil) {
        self.payload = payload
        self.message = message
        self.isLeft = isLeft
        self.isSelf = isSelf
        self.shouldHighlight = shouldHighlight
        self.maxContentWidth = maxContentWidth
    }

    private var shouldShowReceipt: Bool {
        MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: isInMergedDetailView)
    }

    var body: some View {
        let text = currentPayload.text
        if !text.isEmpty {
            textBubbleContent(text: text)
        }
    }


    @ViewBuilder
    private func textBubbleContent(text: String) -> some View {
        if text.contains("[TUIEmoji_") {
            let attrString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: text)
            AttributedTextContainer(
                attributedString: attrString,
                message: message,
                isSelf: isSelf,
                isLeft: isLeft,
                shouldHighlight: shouldHighlight,
                maxBubbleWidth: maxContentWidth ?? UIScreen.main.bounds.width * 0.7
            )
        } else {
            Text(text)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(TextBubbleMetrics.lineSpacing)
                .padding(.horizontal, TextBubbleMetrics.horizontalInset)
                .padding(.vertical, TextBubbleMetrics.verticalInset)
                .frame(minHeight: TextBubbleMetrics.minHeight)
                .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
        }
    }

}


struct TranslationBubbleView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var auxiliaryTextMenuManager: AuxiliaryTextMenuManager
    @Environment(\.translationDisplayManager) private var translationDisplayManager
    @State private var isTranslating: Bool = false
    @State private var isTranslationExpanded: Bool = false
    @State private var translationBubbleFrame: CGRect = .zero
    @State private var pendingSplitResult: [String: Any]? = nil
    @State private var pendingOriginalText: String? = nil
    let message: MessageInfo
    let isSelf: Bool
    var maxWidth: CGFloat = UIScreen.main.bounds.width * ChatMessageListConfig.defaultBubbleMaxWidthRatio

    private var currentPayload: TextMessagePayload? {
        if case .text(let payload) = message.messagePayload {
            return payload
        }
        return nil
    }

    private var shouldShowTranslationBubble: Bool {
        if isTranslating { return true }
        let translatedText = currentPayload?.translatedText ?? [:]
        return !translatedText.isEmpty
    }

    var body: some View {
        Group {
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
            isTranslationExpanded = translationDisplayManager.isExpanded(message.msgID)
            guard !message.atUserList.isEmpty, !(currentPayload?.translatedText ?? [:]).isEmpty else { return }
            let originalText = currentPayload?.text ?? ""
            TranslationTextParser.getAtUserNames(from: message) { names in
                DispatchQueue.main.async {
                    guard !self.isTranslating, self.currentPayload?.text == originalText else { return }
                    self.pendingSplitResult = TranslationTextParser.splitTextByEmojiAndAtUsers(originalText, atUserNames: names)
                    self.pendingOriginalText = originalText
                }
            }
        }
    }


    @ViewBuilder
    private var translationBubbleView: some View {
        let translatedTextMap = currentPayload?.translatedText ?? [:]
        let originalText = currentPayload?.text ?? ""
        let translatedText = buildTranslatedDisplayText(originalText: originalText, translatedTextMap: translatedTextMap)

        Group {
            if isTranslating {
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
                VStack(alignment: .leading, spacing: AuxiliaryTextBubbleMetrics.footerTopSpacing) {
                    if translatedText.contains("[TUIEmoji_") {
                        let attrString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: translatedText)
                        TranslationAttributedText(
                            attributedString: attrString,
                            textColor: isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary,
                            font: UIKitFontScheme.caption2Regular,
                            maxBubbleWidth: max(1, maxWidth - AuxiliaryTextBubbleMetrics.horizontalInset * 2)
                        )
                    } else {
                        Text(translatedText)
                            .font(themeState.fonts.caption2Regular)
                            .lineSpacing(AuxiliaryTextBubbleMetrics.contentLineSpacing)
                            .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                    }
                    Text(LocalizedChatString("TranslateDefaultTips"))
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary.opacity(0.6) : themeState.colors.textColorSecondary)
                }
                .frame(maxWidth: max(1, maxWidth - AuxiliaryTextBubbleMetrics.horizontalInset * 2), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, AuxiliaryTextBubbleMetrics.verticalInset)
                .padding(.horizontal, AuxiliaryTextBubbleMetrics.horizontalInset)
                .background(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: AuxiliaryTextBubbleMetrics.cornerRadius)
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


    private func translateText() {
        guard !isTranslating else { return }

        isTranslating = true
        isTranslationExpanded = true
        translationDisplayManager.expand(message.msgID)

        let text = currentPayload?.text ?? ""
        guard !text.isEmpty else {
            isTranslating = false
            return
        }

        TranslationTextParser.getAtUserNames(from: message) { atUserNames in
            self.performTranslation(text: text, atUserNames: atUserNames)
        }
    }

    private func performTranslation(text: String, atUserNames: [String]?) {
        let splitResult = TranslationTextParser.splitTextByEmojiAndAtUsers(text, atUserNames: atUserNames)
        pendingSplitResult = splitResult
        pendingOriginalText = text
        let textArray = splitResult?[TranslationTextParser.kSplitStringTextKey] as? [String] ?? []

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
                    WindowToastManager.shared.error(LocalizedChatString("TranslateFailed"))
                }
            }
        }
    }


    private func handleTranslationResult(userInfo: [AnyHashable: Any]) {
        guard let _ = userInfo["translatedTextMap"] as? [String: String] else {
            print(">>>>> TextMessageView: No translatedTextMap in notification")
            isTranslating = false
            return
        }

        isTranslating = false

        NotificationCenter.default.post(
            name: NSNotification.Name("translationCompleted"),
            object: nil,
            userInfo: ["msgID": message.msgID]
        )
    }


    private func forwardTranslatedText() {
        let translatedTextMap = currentPayload?.translatedText ?? [:]
        let originalText = currentPayload?.text ?? ""
        let translatedText = buildTranslatedDisplayText(originalText: originalText, translatedTextMap: translatedTextMap)
        guard !translatedText.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("forwardTranslatedText"),
            object: nil,
            userInfo: ["translatedText": translatedText]
        )
    }


    private func buildTranslatedDisplayText(originalText: String, translatedTextMap: [String: String]) -> String {
        guard !translatedTextMap.isEmpty else { return "" }

        let splitResult = pendingOriginalText == originalText
            ? pendingSplitResult
            : TranslationTextParser.splitTextByEmojiAndAtUsers(originalText, atUserNames: nil)
        let resultArray = splitResult?[TranslationTextParser.kSplitStringResultKey] as? [String] ?? []
        let textIndexArray = splitResult?[TranslationTextParser.kSplitStringTextIndexKey] as? [Int] ?? []

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
    let maxBubbleWidth: CGFloat

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
        .padding(.horizontal, TextBubbleMetrics.horizontalInset)
        .padding(.vertical, TextBubbleMetrics.verticalInset)
        .frame(minHeight: TextBubbleMetrics.minHeight)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
    }
}

enum TextBubbleMetrics {
    static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)
    static let verticalInset = CGFloat(SpacingScheme.smallSpacing)
    static let minHeight: CGFloat = 40
    static let lineSpacing = UIKitFontScheme.caption1Regular.lineHeight * 0.3
}

enum AuxiliaryTextBubbleMetrics {
    static let cornerRadius = CGFloat(RadiusScheme.smallRadius)
    static let verticalInset = CGFloat(SpacingScheme.smallSpacing)
    static let horizontalInset = CGFloat(SpacingScheme.smallSpacing)
    static let footerTopSpacing = CGFloat(SpacingScheme.iconTextSpacing)
    static let contentLineSpacing = UIKitFontScheme.caption2Regular.lineHeight * 0.3
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
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
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
                let font = UIKitFontScheme.caption1Regular
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


struct TranslationAttributedText: View {
    @State private var dynamicHeight: CGFloat = 0
    @State private var dynamicWidth: CGFloat = 0
    let attributedString: NSAttributedString
    let textColor: Color
    let font: UIFont
    var maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * ChatMessageListConfig.defaultBubbleMaxWidthRatio

    var body: some View {
        TranslationAttributedTextRepresentable(
            dynamicHeight: $dynamicHeight,
            dynamicWidth: $dynamicWidth,
            attributedString: attributedString,
            textColor: textColor,
            font: font,
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
    let font: UIFont
    let maxBubbleWidth: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
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
                mutable.addAttribute(.font, value: font, range: range)
                mutable.addAttribute(.foregroundColor, value: textColor.toUIColor(), range: range)
            }
        }
        uiView.attributedText = mutable

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
