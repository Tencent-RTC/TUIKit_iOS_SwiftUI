import AtomicXCore
import SwiftUI

struct TextMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let messageBody: MessageBody
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    var body: some View {
        if let text = messageBody.text {
            if text.contains("[TUIEmoji_") {
                let attrString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: text)
                AttributedTextContainer(
                    attributedString: attrString,
                    isSelf: isSelf,
                    isLeft: isLeft,
                    shouldHighlight: shouldHighlight
                )
            } else {
                Text(text)
                    .font(.system(size: 16))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundColor(isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary)
                    .multilineTextAlignment(.leading)
                    .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight)
            }
        }
    }
}

struct AttributedTextContainer: View {
    @State private var dynamicHeight: CGFloat = 0
    @State private var dynamicWidth: CGFloat = 0
    let attributedString: NSAttributedString
    let isSelf: Bool
    let isLeft: Bool
    let shouldHighlight: Bool
    let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.7

    var body: some View {
        HStack {
            AttributedText(
                dynamicHeight: $dynamicHeight,
                dynamicWidth: $dynamicWidth,
                attributedString: attributedString,
                maxBubbleWidth: maxBubbleWidth,
                isSelf: isSelf
            )
            .frame(width: dynamicWidth, height: dynamicHeight)
            .background(Color.clear)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight)
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
