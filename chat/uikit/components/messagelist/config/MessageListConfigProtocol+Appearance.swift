import UIKit

extension MessageListConfigProtocol {
    var defaultBubbleAppearance: MessageBubbleAppearance? { nil }
    var ownBubbleAppearance: MessageBubbleAppearance? { nil }
    var incomingBubbleAppearance: MessageBubbleAppearance? { nil }
    var leftBubbleAppearance: MessageBubbleAppearance? { nil }
    var rightBubbleAppearance: MessageBubbleAppearance? { nil }

    func resolvedBubbleAppearance(isSelf: Bool, isLeft: Bool) -> MessageBubbleAppearance? {
        let slot: MessageBubbleAppearance?
        if alignment == .left {
            slot = leftBubbleAppearance
        } else if alignment == .right {
            slot = rightBubbleAppearance
        } else {
            slot = isSelf ? ownBubbleAppearance : incomingBubbleAppearance
        }
        guard let slot = slot else { return defaultBubbleAppearance }
        return slot.merged(over: defaultBubbleAppearance)
    }
}
