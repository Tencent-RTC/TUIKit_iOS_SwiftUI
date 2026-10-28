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

extension MessageInputContentView {
    func findMentionToDelete(at position: Int) -> MentionInfo? {
        for mention in mentionList {
            if position > mention.startIndex && position < mention.endIndex {
                return mention
            }
        }
        return nil
    }

    func insertMentions(_ mentions: [MentionInfo], atPosition: Int) {
        guard !mentions.isEmpty else { return }
        guard let attributedString = textEditorState.displayText else { return }

        let adjustedPosition = convertDisplayPositionToTextPosition(atPosition, in: attributedString)
        var currentText = getSendText()

        if currentText.isEmpty {
            currentText = "@"
        }

        let atIndex = currentText.index(currentText.startIndex, offsetBy: min(adjustedPosition, currentText.count))
        let afterAtIndex = currentText.index(after: atIndex)

        var combinedMentionText = ""
        var newMentions: [MentionInfo] = []
        var currentOffset = adjustedPosition

        for (index, mention) in mentions.enumerated() {
            var newMention = mention
            newMention.startIndex = currentOffset

            if index == 0 {
                combinedMentionText += mention.mentionText
            } else {
                combinedMentionText += mention.mentionText
            }

            newMentions.append(newMention)
            currentOffset += mention.mentionText.count
        }

        currentText.replaceSubrange(atIndex..<afterAtIndex, with: combinedMentionText)

        let insertedLength = combinedMentionText.count - 1
        for i in 0..<mentionList.count {
            if mentionList[i].startIndex > adjustedPosition {
                mentionList[i].startIndex += insertedLength
            }
        }

        mentionList.append(contentsOf: newMentions)

        let newAttributedString = EmojiManager.shared.createAttributedStringWithTextAndStyle(
            text: currentText,
            withFont: normalFont,
            textColor: normalColor
        )
        textEditorState.displayText = newAttributedString
    }

    private func insertMention(_ mention: MentionInfo, atPosition: Int) {
        insertMentions([mention], atPosition: atPosition)
    }

    private func removeMention(_ mention: MentionInfo) {
        mentionList.removeAll { $0.userID == mention.userID && $0.startIndex == mention.startIndex }

        for i in 0..<mentionList.count {
            if mentionList[i].startIndex > mention.startIndex {
                mentionList[i].startIndex -= mention.length
            }
        }
    }

    func convertDisplayPositionToTextPosition(_ displayPosition: Int, in attributedString: NSAttributedString) -> Int {
        var textPosition = 0
        var displayPos = 0

        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, stop in
            if displayPos >= displayPosition {
                stop.pointee = true
                return
            }

            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
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

        if displayPos < displayPosition {
            textPosition += displayPosition - displayPos
        }

        return textPosition
    }

    func getSendText() -> String {
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

    func saveDraftWithDebounce() {
        draftSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            self.saveDraftImmediately()
        }
        draftSaveWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    func saveDraftImmediately() {
        let draftText = getSendText()

        if draftText.isEmpty {
            conversationStore.setConversationDraft(conversationID: conversationID, draft: nil, completion: nil)
        } else {
            conversationStore.setConversationDraft(conversationID: conversationID, draft: draftText, completion: nil)
        }
    }

    func loadDraft() {
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: DraftConversationInfoHandler(
                onSuccess: { conversation in
                    DispatchQueue.main.async {
                        if let draft = conversation.draft,
                           !draft.isEmpty
                        {
                            isLoadingDraft = true

                            let draftAttributedString = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: draft)

                            textEditorState.displayText = draftAttributedString

                            focusKeyboardAfterPageTransition()

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

    // 等待页面 push 完成后聚焦，避免键盘跟随页面横向滑入。
    private func focusKeyboardAfterPageTransition() {
        let focus = {
            _ = textEditorState.becomeFirstResponder?()
        }
        let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
        var topController = window?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        if let navigation = topController as? UINavigationController {
            topController = navigation.topViewController
        }
        guard let coordinator = topController?.transitionCoordinator else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: focus)
            return
        }
        coordinator.animate(alongsideTransition: nil, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: focus)
        })
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
