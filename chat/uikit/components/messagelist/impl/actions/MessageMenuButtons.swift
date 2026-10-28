import Foundation
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif
import AtomicXCore
import UIKit

private func messageActionDate(from timestamp: Int64?) -> Date? {
    guard let timestamp = timestamp else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(timestamp))
}

enum MenuButtonConfig {
    static func allButtons(asrDisplayManager: AsrDisplayManager, translationDisplayManager: TranslationDisplayManager) -> [ButtonConfig] {
        return [
            ButtonConfig(
                iconName: "message_copy",
                systemIconFallback: "doc.on.doc",
                label: LocalizedChatString("Copy"),
                order: 0,
                shouldShow: { message in
                    guard let message = message else { return false }
                    guard message.messageType == .text else { return false }
                    return message.status != .violation
                },
                actionHandler: { message, menuManager, _ in
                    if case .text(let payload) = message?.messagePayload {
                        let text = payload.text
                        UIPasteboard.general.string = text
                        WindowToastManager.shared.show(LocalizedChatString("copied"), type: .success, duration: 3)
                    }
                    menuManager.hideMenu()
                }
            ),
            ButtonConfig(
                iconName: "message_recall",
                systemIconFallback: "arrow.uturn.backward",
                label: LocalizedChatString("Revoke"),
                order: 5,
                shouldShow: { message in
                    guard let message = message else { return false }
                    guard message.isSentBySelf else { return false }
                    guard message.status == .sendSuccess else { return false }
                    guard let messageDate = messageActionDate(from: message.timestamp) else { return false }
                    let currentTime = Date()
                    let timeDifference = currentTime.timeIntervalSince(messageDate)
                    let twoMinutesInSeconds: TimeInterval = 2 * 60
                    return timeDifference < twoMinutesInSeconds
                },
                actionHandler: { message, menuManager, messageActionStore in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    messageActionStore.revoke(completion: { _ in })
                }
            ),
            ButtonConfig(
                iconName: "message_delete",
                systemIconFallback: "trash",
                label: LocalizedChatString("Delete"),
                order: 4,
                isDangerous: true,
                shouldShow: { _ in true },
                actionHandler: { message, menuManager, messageActionStore in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    MessageListHelper.presentDeleteConfirmation {
                        messageActionStore.delete(completion: { _ in })
                    }
                }
            ),
            ButtonConfig(
                iconName: "message_forward",
                systemIconFallback: "arrowshape.turn.up.right",
                label: LocalizedChatString("Forward"),
                order: 1,
                shouldShow: { message in
                    guard let message = message else { return false }
                    return message.status == .sendSuccess
                },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("showForwardTargetSelector"),
                        object: nil,
                        userInfo: ["messages": [message]]
                    )
                }
            ),
            ButtonConfig(
                iconName: "message_quote",
                systemIconFallback: "quote.bubble",
                label: LocalizedChatString("Quote"),
                order: 2,
                shouldShow: { message in
                    guard let message = message else { return false }
                    return message.status == .sendSuccess
                },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("quoteMessageNotification"),
                        object: nil,
                        userInfo: ["message": message]
                    )
                }
            ),
            ButtonConfig(
                iconName: "message_convert",
                systemIconFallback: "text.bubble",
                label: LocalizedChatString("ConvertToText"),
                order: 6,
                shouldShow: { message in
                    guard let message = message else { return false }
                    guard message.messageType == .audio else { return false }
                    guard message.status == .sendSuccess else { return false }
                    return !asrDisplayManager.isExpanded(message.msgID)
                },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("convertVoiceToText"),
                        object: nil,
                        userInfo: ["message": message]
                    )
                }
            ),
            ButtonConfig(
                iconName: "message_translate",
                systemIconFallback: "character.bubble",
                label: LocalizedChatString("Translate"),
                order: 7,
                shouldShow: { message in
                    guard let message = message else { return false }
                    guard message.messageType == .text else { return false }
                    guard message.status == .sendSuccess else { return false }
                    if case .text(let payload) = message.messagePayload {
                        let targetLanguage = AppBuilderConfig.shared.translateTargetLanguage.isEmpty
                            ? "en" : AppBuilderConfig.shared.translateTargetLanguage
                        let translatedText = payload.translatedText ?? [:]
                        if !translatedText.isEmpty {
                            return payload.translateLanguage != targetLanguage
                        }
                    }
                    return !translationDisplayManager.isExpanded(message.msgID)
                },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("translateTextMessage"),
                        object: nil,
                        userInfo: ["message": message]
                    )
                }
            ),
            ButtonConfig(
                iconName: "message_multiselect",
                systemIconFallback: "checkmark.circle",
                label: LocalizedChatString("MultiSelect"),
                order: 3,
                shouldShow: { _ in true },
                actionHandler: { message, menuManager, _ in
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("enterMultiSelectMode"),
                        object: nil,
                        userInfo: ["initialMessage": message as Any]
                    )
                }
            ),
            ButtonConfig(
                iconName: "message_listen_from_here",
                systemIconFallback: "speaker.wave.2",
                label: LocalizedChatString("VoiceListenFromHere"),
                order: 9,
                shouldShow: { message in
                    guard let message = message else { return false }
                    return true
                },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("listenFromHereNotification"),
                        object: nil,
                        userInfo: ["message": message]
                    )
                }
            ),
        ]
    }

    static func getVisibleButtons(
        for message: MessageInfo?,
        style: MessageActionConfigProtocol?,
        customActions: [MessageCustomAction] = [],
        asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
        translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
    ) -> [ButtonConfig] {
        var buttons = allButtons(asrDisplayManager: asrDisplayManager, translationDisplayManager: translationDisplayManager).filter { button in
            guard button.shouldShow(message) else { return false }
            switch button.label {
            case LocalizedChatString("Copy"):
                guard let style = style else { return false }
                return style.isSupportCopy
            case LocalizedChatString("Delete"):
                guard let style = style else { return false }
                return style.isSupportDelete
            case LocalizedChatString("Revoke"):
                guard let style = style else { return false }
                return style.isSupportRecall
            case LocalizedChatString("Forward"):
                guard let style = style else { return false }
                return style.isSupportForward
            case LocalizedChatString("MultiSelect"):
                guard let style = style else { return false }
                return style.isSupportMultiSelect
            case LocalizedChatString("Quote"):
                guard let style = style else { return false }
                return style.isSupportQuote
            case LocalizedChatString("VoiceListenFromHere"):
                guard let style = style else { return false }
                return style.isSupportListenFromHere
            case LocalizedChatString("ConvertToText"):
                guard let style = style else { return false }
                return style.isSupportConvertToText
            case LocalizedChatString("Translate"):
                guard let style = style else { return false }
                return style.isSupportTranslate
            default:
                return true
            }
        }.sorted { $0.order < $1.order }

        let customButtons = customActions.map { customAction in
            ButtonConfig(
                iconName: customAction.iconName,
                systemIconFallback: customAction.systemIconFallback,
                label: customAction.title,
                shouldShow: { _ in true },
                actionHandler: { message, menuManager, _ in
                    guard let message = message else { return }
                    menuManager.hideMenu()
                    customAction.action(message)
                }
            )
        }

        buttons.append(contentsOf: customButtons)
        if let customizer = style?.actionCustomizer {
            buttons = customizedButtons(buttons, customizer: customizer)
        }
        guard !buttons.isEmpty else { return [] }

        if let message = message,
           (style as? MessageListConfigProtocol)?.isSupportReaction ?? false,
           message.status == .sendSuccess,
           !EmojiManager.shared.getPickerEmojis().isEmpty {
            buttons.append(
                ButtonConfig(
                    iconName: "message_reaction",
                    systemIconFallback: "face.smiling",
                    label: LocalizedChatString("Reaction"),
                    isReactionEntry: true,
                    shouldShow: { _ in true },
                    actionHandler: { _, menuManager, _ in
                        menuManager.showEmojiPanel()
                    }
                )
            )
        }
        return buttons
    }

    private static func customizedButtons(_ buttons: [ButtonConfig], customizer: MessageActionCustomizer) -> [ButtonConfig] {
        let editor = CustomEditor(items: buttons.map { button in
            MessageActionMenuAction(
                ID: actionID(for: button),
                iconName: button.iconName,
                systemIconFallback: button.systemIconFallback,
                label: button.label,
                isDangerous: button.isDangerous,
                isReactionEntry: button.isReactionEntry,
                handler: { message, store in
                    button.actionHandler(message, MessageMenuManager(), store)
                }
            )
        })
        customizer(editor)
        return editor.build().map { action in
            ButtonConfig(
                iconName: action.iconName,
                systemIconFallback: action.systemIconFallback,
                label: action.label,
                isDangerous: action.isDangerous,
                isReactionEntry: action.isReactionEntry,
                actionHandler: { message, menuManager, store in
                    guard let message = message else { return }
                    if action.isReactionEntry {
                        menuManager.showEmojiPanel()
                        return
                    }
                    menuManager.hideMenu()
                    action.handler(message, store)
                }
            )
        }
    }

    private static func actionID(for button: ButtonConfig) -> String {
        switch button.iconName {
        case "message_copy": return "message.copy"
        case "message_forward": return "message.forward"
        case "message_quote": return "message.quote"
        case "message_multiselect": return "message.multiSelect"
        case "message_delete": return "message.delete"
        case "message_recall": return "message.recall"
        case "message_convert": return "message.convertToText"
        case "message_translate": return "message.translate"
        case "message_listen_from_here": return "message.listenFromHere"
        default: return button.iconName
        }
    }
}
