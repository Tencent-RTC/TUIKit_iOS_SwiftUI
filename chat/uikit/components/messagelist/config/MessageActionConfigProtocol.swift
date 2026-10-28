import AtomicXCore
import SwiftUI

protocol MessageActionConfigProtocol {
    var isSupportCopy: Bool { get }
    var isSupportDelete: Bool { get }
    var isSupportRecall: Bool { get }
    var isSupportForward: Bool { get }
    var isSupportMultiSelect: Bool { get }
    var isSupportQuote: Bool { get }
    var isSupportListenFromHere: Bool { get }
    var isSupportConvertToText: Bool { get }
    var isSupportTranslate: Bool { get }
    var actionCustomizer: MessageActionCustomizer? { get }
}

extension ChatMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {}

extension MessageActionConfigProtocol {
    var isSupportQuote: Bool { true }
    var isSupportListenFromHere: Bool { true }
    var isSupportConvertToText: Bool { true }
    var isSupportTranslate: Bool { true }
    var actionCustomizer: MessageActionCustomizer? { nil }
}
