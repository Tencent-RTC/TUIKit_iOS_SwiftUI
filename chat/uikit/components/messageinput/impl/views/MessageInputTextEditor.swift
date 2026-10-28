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

struct FixedHeightTextEditor: UIViewRepresentable {
    @ObservedObject var state: TextEditorState
    var maxLines: Int = 5
    var onSend: (() -> Void)? = nil
    var onAtTriggered: ((Int) -> Void)? = nil
    var onDeleteAtPosition: ((Int) -> MentionInfo?)? = nil
    var onMentionDeleted: ((MentionInfo) -> Void)? = nil
    var isGroupChat: Bool = false
    var enableMention: Bool = true
    var appearance: MessageInputFieldAppearance? = nil
    // UIKit 手势保证开始与结束、取消事件配对，避免松手后仍录音。
    var onVoiceLongPress: ((UIGestureRecognizer.State, CGPoint) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.accessibilityIdentifier = "chat_message_input"
        textView.delegate = context.coordinator
        if onVoiceLongPress != nil {
            let longPress = UILongPressGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleVoiceLongPress(_:))
            )
            longPress.minimumPressDuration = 0.2
            longPress.delegate = context.coordinator
            textView.addGestureRecognizer(longPress)
        }
        textView.font = UIKitFontScheme.caption1Regular
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(
            top: CGFloat(SpacingScheme.smallSpacing),
            left: CGFloat(SpacingScheme.iconTextSpacing),
            bottom: CGFloat(SpacingScheme.smallSpacing),
            right: CGFloat(SpacingScheme.iconTextSpacing)
        )
        textView.returnKeyType = .send
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.inputTextView = textView
        state.addEmojiString = { [weak textView] emojiStr, emojiName in
            guard let textView = textView, emojiStr.length > 0 else { return }
            if let attachment = emojiStr.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment,
               let image = attachment.image
            {
                image.accessibilityIdentifier = emojiName
            }
            context.coordinator.replaceText(in: textView, range: textView.selectedRange, with: emojiStr)
        }
        state.deleteLastCharacter = { [weak textView] in
            guard let textView = textView,
                  textView.textStorage.length > 0 else { return }
            textView.deleteBackward()
            context.coordinator.textViewDidChange(textView)
        }
        state.becomeFirstResponder = { [weak textView] in
            textView?.becomeFirstResponder()
        }
        state.resignFirstResponder = { [weak textView] in
            textView?.resignFirstResponder()
        }
        state.appendText = { [weak textView] attrStr in
            guard let textView = textView else { return }
            let endPosition = textView.textStorage.length
            textView.textStorage.insert(attrStr, at: endPosition)
            let newPosition = textView.textStorage.length
            textView.selectedRange = NSRange(location: newPosition, length: 0)
            context.coordinator.resetTextStyle()
            state.displayText = NSAttributedString(attributedString: textView.textStorage)
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
        context.coordinator.parent = self
        let textColor = appearance?.textColor ?? normalColor
        if textView.textColor != textColor {
            textView.textColor = textColor
            context.coordinator.resetTextStyle()
        }
        if let displayText = state.displayText {
            if !context.coordinator.isUserEditing && !textView.attributedText.isEqual(to: displayText) {
                textView.attributedText = displayText
                let endPosition = displayText.length
                textView.selectedRange = NSRange(location: endPosition, length: 0)
                context.coordinator.resetTextStyle()
            }
        } else {
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

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: FixedHeightTextEditor
        weak var inputTextView: UITextView?
        var isUserEditing = false

        init(_ parent: FixedHeightTextEditor) {
            self.parent = parent
        }

        @objc func handleVoiceLongPress(_ gesture: UILongPressGestureRecognizer) {
            let point = gesture.location(in: gesture.view?.window)
            parent.onVoiceLongPress?(gesture.state, point)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isUserEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isUserEditing = false
        }

        func textViewDidChange(_ textView: UITextView) {
            isUserEditing = true
            if textView.markedTextRange == nil {
                resetTextStyle()
            }
            parent.state.displayText = NSAttributedString(attributedString: textView.textStorage)
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

        func replaceText(in textView: UITextView, range: NSRange, with replacement: NSAttributedString) {
            let storage = textView.textStorage
            guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
                  range.location <= storage.length, range.length <= storage.length - range.location,
                  Range(range, in: storage.string) != nil else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: range, with: replacement)
            storage.endEditing()
            textView.selectedRange = NSRange(location: range.location + replacement.length, length: 0)
            textViewDidChange(textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if textView.markedTextRange != nil { return true }
            if (text == "@" || text == "＠") && parent.isGroupChat && parent.enableMention {
                DispatchQueue.main.async {
                    self.parent.onAtTriggered?(range.location)
                }
                return true
            }

            if text.isEmpty && range.length > 0 {
                if let mentionToDelete = parent.onDeleteAtPosition?(range.location) {
                    let textLength = textView.textStorage.length
                    let mentionStart = mentionToDelete.startIndex
                    let mentionLength = mentionToDelete.length

                    if mentionStart >= 0 && mentionStart < textLength {
                        let safeLength = min(mentionLength, textLength - mentionStart)
                        if safeLength > 0 {
                            let mentionRange = NSRange(location: mentionStart, length: safeLength)
                            textView.textStorage.deleteCharacters(in: mentionRange)
                            textView.selectedRange = NSRange(location: mentionStart, length: 0)
                            resetTextStyle()
                            parent.state.displayText = textView.attributedText
                            parent.onMentionDeleted?(mentionToDelete)
                            return false
                        }
                    }
                }
            }

            if !text.contains("[") && !text.contains("]") {
                if text == "\n" {
                    textViewDidChange(textView)
                    guard !textView.textStorage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return false
                    }
                    parent.onSend?()
                    return false
                }
                return true
            }
            let textChange = EmojiManager.shared.createAttributedStringWithTextAndStyle(text: text, withFont: normalFont, textColor: normalColor)
            replaceText(in: textView, range: range, with: textChange)
            return false
        }

        func resetTextStyle() {
            guard let inputTextView = inputTextView else { return }
            let wholeRange = NSRange(location: 0, length: inputTextView.textStorage.length)
            let textColor = parent.appearance?.textColor ?? normalColor
            inputTextView.textStorage.removeAttribute(.font, range: wholeRange)
            inputTextView.textStorage.removeAttribute(.foregroundColor, range: wholeRange)
            inputTextView.textStorage.addAttribute(.foregroundColor, value: textColor, range: wholeRange)
            inputTextView.textStorage.addAttribute(.font, value: normalFont, range: wholeRange)
            inputTextView.textAlignment = .left
            inputTextView.textColor = textColor
            inputTextView.typingAttributes[.foregroundColor] = textColor
        }
    }
}

final class HoldToTalkTouchView: UIView {
    var onTap: (() -> Void)?
    var onPressBegan: ((CGPoint) -> Void)?
    var onPressChanged: ((CGPoint) -> Void)?
    var onPressEnded: (() -> Void)?
    private var didLongPress = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.2
        addGestureRecognizer(longPress)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        didLongPress = false
        super.touchesBegan(touches, with: event)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: nil)
        switch gesture.state {
        case .began:
            didLongPress = true
            onPressBegan?(point)
        case .changed:
            onPressChanged?(point)
        case .ended, .cancelled, .failed:
            onPressEnded?()
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if !didLongPress { onTap?() }
        didLongPress = false
    }
}

struct HoldToTalkArea: UIViewRepresentable {
    var onTap: (() -> Void)? = nil
    var onPressBegan: (CGPoint) -> Void
    var onPressChanged: (CGPoint) -> Void
    var onPressEnded: () -> Void

    func makeUIView(context: Context) -> HoldToTalkTouchView {
        let view = HoldToTalkTouchView()
        updateCallbacks(view)
        return view
    }

    func updateUIView(_ uiView: HoldToTalkTouchView, context: Context) {
        updateCallbacks(uiView)
    }

    private func updateCallbacks(_ view: HoldToTalkTouchView) {
        view.onTap = onTap
        view.onPressBegan = onPressBegan
        view.onPressChanged = onPressChanged
        view.onPressEnded = onPressEnded
    }
}
