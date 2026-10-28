import Foundation
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif
import AtomicXCore
import UIKit

private struct MessageActionConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageActionConfigProtocol = ChatMessageListConfig(alignment: nil)
}

extension EnvironmentValues {
    var MessageActionConfigProtocol: MessageActionConfigProtocol {
        get { self[MessageActionConfigProtocolKey.self] }
        set { self[MessageActionConfigProtocolKey.self] = newValue }
    }
}

struct ButtonConfig {
    let iconName: String
    let systemIconFallback: String
    let label: String
    let shouldShow: (MessageInfo?) -> Bool
    let actionHandler: (MessageInfo?, MessageMenuManager, MessageActionStore) -> Void
    let order: Int
    let isDangerous: Bool
    let isReactionEntry: Bool

    init(
        iconName: String,
        systemIconFallback: String,
        label: String,
        order: Int = 100,
        isDangerous: Bool = false,
        isReactionEntry: Bool = false,
        shouldShow: @escaping (MessageInfo?) -> Bool = { _ in true },
        actionHandler: @escaping (MessageInfo?, MessageMenuManager, MessageActionStore) -> Void
    ) {
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.label = label
        self.shouldShow = shouldShow
        self.actionHandler = actionHandler
        self.order = order
        self.isDangerous = isDangerous
        self.isReactionEntry = isReactionEntry
    }

    func createAction(
        for message: MessageInfo?,
        menuManager: MessageMenuManager,
        messageActionStore: MessageActionStore
    ) -> () -> Void {
        return { [actionHandler] in
            actionHandler(message, menuManager, messageActionStore)
        }
    }
}

struct MenuPositionParams {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let arrowX: CGFloat
    let showAbove: Bool

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.arrowX = arrowX
        self.showAbove = showAbove
    }
}

enum MessageMenuPlacement {
    static func verticalPosition(bubbleFrame: CGRect, visibleBounds: CGRect, menuHeight: CGFloat, preferAbove: Bool) -> (position: CGFloat, showAbove: Bool) {
        let margin = min(MessageMenuConfig.minEdgeSpacing, max(0, (visibleBounds.height - menuHeight) / 2))
        let top = visibleBounds.minY + margin
        let bottom = visibleBounds.maxY - margin
        let aboveSpace = max(0, bubbleFrame.minY - MessageMenuConfig.bubbleSpacing - top)
        let belowSpace = max(0, bottom - bubbleFrame.maxY - MessageMenuConfig.bubbleSpacing)
        let showAbove: Bool
        if aboveSpace >= menuHeight, belowSpace >= menuHeight {
            showAbove = preferAbove
        } else if aboveSpace >= menuHeight {
            showAbove = true
        } else if belowSpace >= menuHeight {
            showAbove = false
        } else {
            showAbove = aboveSpace == belowSpace ? preferAbove : aboveSpace > belowSpace
        }
        let candidate = showAbove
            ? bubbleFrame.minY - MessageMenuConfig.bubbleSpacing - menuHeight / 2
            : bubbleFrame.maxY + MessageMenuConfig.bubbleSpacing + menuHeight / 2
        let minimum = top + menuHeight / 2
        let maximum = max(minimum, bottom - menuHeight / 2)
        return (max(minimum, min(maximum, candidate)), showAbove)
    }
}

struct MessageMenuData {
    var isShowing: Bool = false
    var message: MessageInfo? = nil
    var messageBubbleFrame: CGRect = .zero
    var shouldShowAbove: Bool = true
    var customActions: [MessageCustomAction] = []
    var messageListBounds: CGRect = .zero
    var isShowingEmojiPanel: Bool = false
}

enum MessageMenuConfig {
    static let columns = 5
    static let pageRows = 2
    static let cellWidth: CGFloat = 52
    static let cellHeight: CGFloat = 68
    static let pagePadding: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let rowDividerHeight: CGFloat = 1
    static let rowDividerSideMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let rowDividerAlpha: CGFloat = 140.0 / 255.0
    static let menuCornerRadius = CGFloat(RadiusScheme.smallRadius)
    static let arrowWidth: CGFloat = 14
    static let arrowHeight: CGFloat = 8
    static let arrowLayoutHeight: CGFloat = 8
    static let indicatorDotSize: CGFloat = 6
    static let indicatorDotSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let indicatorVerticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static var indicatorAreaHeight: CGFloat { indicatorDotSize + indicatorVerticalPadding * 2 }
    static let indicatorInactiveAlpha: CGFloat = 64.0 / 255.0
    static let menuMaxWidth: CGFloat = 300
    static let minMenuWidth: CGFloat = 60
    static let screenPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let bubbleSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let minEdgeSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let iconSize = UIKitFontScheme.body3Regular.pointSize
    static let iconTopMargin: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    static let iconTitleSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let titleBottomMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let labelFontSize = UIKitFontScheme.caption3Regular.pointSize
    static let titleMaxLines = 2
    static let menuAppearDuration: TimeInterval = 0.2
    static let menuAppearScale: CGFloat = 0.95
    static var buttonsPerPage: Int { columns * pageRows }

    static func menuPageHeight(rowCount: Int) -> CGFloat {
        let rows = max(1, rowCount)
        return pagePadding * 2 + cellHeight * CGFloat(rows) + rowDividerHeight * CGFloat(rows - 1)
    }

    static func calculateMenuDimensions(buttonCount: Int, forceFullColumns: Bool = false) -> (width: CGFloat, height: CGFloat) {
        let isPaged = buttonCount > buttonsPerPage
        let columnCount = forceFullColumns ? columns : max(1, min(buttonCount, columns))
        let cardWidth = cellWidth * CGFloat(isPaged ? columns : columnCount) + pagePadding * 2
        let menuWidth = max(minMenuWidth, min(cardWidth, menuMaxWidth))
        let contentHeight: CGFloat
        if isPaged {
            contentHeight = menuPageHeight(rowCount: pageRows) + indicatorAreaHeight
        } else {
            contentHeight = menuPageHeight(rowCount: calculateRowCount(buttonCount: buttonCount))
        }
        return (menuWidth, contentHeight + arrowLayoutHeight)
    }

    static func calculateEmojiPanelDimensions(buttonCount: Int) -> (width: CGFloat, height: CGFloat) {
        let menuWidth = calculateMenuDimensions(buttonCount: buttonCount, forceFullColumns: true).width
        return (menuWidth, ReactionEmojiPanelView.panelHeight + arrowLayoutHeight)
    }

    static func calculateRowCount(buttonCount: Int) -> Int {
        return (buttonCount + columns - 1) / columns
    }

    static func calculateMenuWidth(buttonCount: Int) -> CGFloat {
        return calculateMenuDimensions(buttonCount: buttonCount).width
    }
}

class MessageMenuManager: ObservableObject {
    @Published var menuData = MessageMenuData()
    private(set) var lastMenuOpenTime: Date?

    func showMenu(for message: MessageInfo, bubbleFrame: CGRect, messageListBounds: CGRect = .zero, config: MessageActionConfigProtocol? = nil, customActions: [MessageCustomAction] = []) {
        lastMenuOpenTime = Date()
        let safeInsets = getSafeAreaInsets()
        let safeAreaTop = safeInsets.top
        let resolvedConfig = config ?? ChatMessageListConfig()
        let buttons = MenuButtonConfig.getVisibleButtons(for: message, style: resolvedConfig, customActions: customActions)
        guard !buttons.isEmpty else { return }
        let buttonCount = buttons.count
        let hasReactionEntry = buttons.contains { $0.isReactionEntry }
        let menuHeight = MessageMenuConfig.calculateMenuDimensions(buttonCount: buttonCount, forceFullColumns: hasReactionEntry).height
        let maxContentHeight = max(
            menuHeight,
            MessageMenuConfig.calculateEmojiPanelDimensions(buttonCount: buttonCount).height
        )
        let hasEnoughSpaceAbove = bubbleFrame.minY - safeAreaTop >= maxContentHeight + MessageMenuConfig.bubbleSpacing + MessageMenuConfig.minEdgeSpacing
        menuData = MessageMenuData(
            isShowing: true,
            message: message,
            messageBubbleFrame: bubbleFrame,
            shouldShowAbove: hasEnoughSpaceAbove,
            customActions: customActions,
            messageListBounds: messageListBounds
        )
    }

    func hideMenu() {
        menuData.isShowing = false
        menuData.isShowingEmojiPanel = false
    }

    func showEmojiPanel() {
        menuData.isShowingEmojiPanel = true
    }

    func hideEmojiPanel() {
        menuData.isShowingEmojiPanel = false
    }
}

func getSafeAreaInsets() -> UIEdgeInsets {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first
    {
        return window.safeAreaInsets
    }
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        return window.safeAreaInsets
    }
    return UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
}
