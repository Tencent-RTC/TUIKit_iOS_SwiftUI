import Foundation
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif
import AtomicXCore
import UIKit

struct MessageActionView: View {
    @EnvironmentObject var menuManager: MessageMenuManager
    @Environment(\.messageCustomActions) var customActions: [MessageCustomAction]
    @Environment(\.asrDisplayManager) var asrDisplayManager: AsrDisplayManager
    @Environment(\.translationDisplayManager) var translationDisplayManager: TranslationDisplayManager
    private var config: MessageActionConfigProtocol

    init(config: MessageActionConfigProtocol) {
        self.config = config
    }

    var body: some View {
        if let message = menuManager.menuData.message,
           menuManager.menuData.isShowing,
           MenuButtonConfig.getVisibleButtons(for: message, style: config, customActions: menuManager.menuData.customActions, asrDisplayManager: asrDisplayManager, translationDisplayManager: translationDisplayManager).count > 0
        {
            let messageActionStore = MessageActionStore.create(message: message)
            ZStack {
                menuContent(message: message, messageActionStore: messageActionStore)
                    .transition(.scale(scale: MessageMenuConfig.menuAppearScale).combined(with: .opacity))
            }
            .animation(.easeOut(duration: MessageMenuConfig.menuAppearDuration), value: menuManager.menuData.isShowing)
        }
    }

    private func menuContent(message: MessageInfo, messageActionStore: MessageActionStore) -> some View {
        MenuPositionWrapper(
            message: message,
            menuManager: menuManager,
            messageActionStore: messageActionStore,
            style: config,
            customActions: menuManager.menuData.customActions,
            asrDisplayManager: asrDisplayManager,
            translationDisplayManager: translationDisplayManager
        )
    }

    struct MenuPositionWrapper: View {
        let message: MessageInfo
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        let customActions: [MessageCustomAction]
        let asrDisplayManager: AsrDisplayManager
        let translationDisplayManager: TranslationDisplayManager

        init(
            message: MessageInfo,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol,
            customActions: [MessageCustomAction] = [],
            asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
            translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
        ) {
            self.message = message
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
            self.customActions = customActions
            self.asrDisplayManager = asrDisplayManager
            self.translationDisplayManager = translationDisplayManager
        }

        var body: some View {
            MenuContentCalculator(
                message: message,
                menuManager: menuManager,
                messageActionStore: messageActionStore,
                style: style,
                customActions: customActions,
                asrDisplayManager: asrDisplayManager,
                translationDisplayManager: translationDisplayManager
            )
        }
    }

    struct MenuContentCalculator: View {
        @Environment(\.messageListBounds) private var liveMessageListBounds
        let message: MessageInfo
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        let customActions: [MessageCustomAction]
        let asrDisplayManager: AsrDisplayManager
        let translationDisplayManager: TranslationDisplayManager
        var minEdgeSpacing: CGFloat { MessageMenuConfig.minEdgeSpacing }

        init(
            message: MessageInfo,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol,
            customActions: [MessageCustomAction] = [],
            asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
            translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
        ) {
            self.message = message
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
            self.customActions = customActions
            self.asrDisplayManager = asrDisplayManager
            self.translationDisplayManager = translationDisplayManager
        }

        var body: some View {
            GeometryReader { screenGeometry in
                let calculatedPosition = calculateMenuPosition(screenGeometry: screenGeometry)
                MenuMainContentView(
                    x: calculatedPosition.x,
                    y: calculatedPosition.y,
                    width: calculatedPosition.width,
                    height: calculatedPosition.height,
                    arrowX: calculatedPosition.arrowX,
                    showAbove: calculatedPosition.showAbove,
                    menuManager: menuManager,
                    messageActionStore: messageActionStore,
                    style: style,
                    customActions: customActions,
                    asrDisplayManager: asrDisplayManager,
                    translationDisplayManager: translationDisplayManager
                )
            }
            .edgesIgnoringSafeArea(.all)
        }

        func calculateMenuPosition(screenGeometry: GeometryProxy) -> MenuPositionParams {
            let buttons = MenuButtonConfig.getVisibleButtons(for: message, style: style, customActions: customActions, asrDisplayManager: asrDisplayManager, translationDisplayManager: translationDisplayManager)
            let buttonCount = buttons.count
            let hasReactionEntry = buttons.contains { $0.isReactionEntry }
            let dimensions: (width: CGFloat, height: CGFloat)
            if menuManager.menuData.isShowingEmojiPanel {
                dimensions = MessageMenuConfig.calculateEmojiPanelDimensions(buttonCount: buttonCount)
            } else {
                dimensions = MessageMenuConfig.calculateMenuDimensions(buttonCount: buttonCount, forceFullColumns: hasReactionEntry)
            }
            let screenGeometryGlobal = screenGeometry.frame(in: .global)
            let listBounds = liveMessageListBounds.isEmpty ? menuManager.menuData.messageListBounds : liveMessageListBounds
            let intersection = screenGeometryGlobal.intersection(listBounds)
            let globalVisibleBounds = listBounds.isEmpty || intersection.isNull || intersection.isEmpty
                ? screenGeometryGlobal : intersection
            let visibleBounds = globalVisibleBounds.offsetBy(dx: -screenGeometryGlobal.minX, dy: -screenGeometryGlobal.minY)
            let menuWidth = min(dimensions.width, max(1, visibleBounds.width - MessageMenuConfig.screenPadding * 2))
            let dynamicMenuHeight = min(dimensions.height, max(1, visibleBounds.height - MessageMenuConfig.minEdgeSpacing * 2))
            let globalBubbleFrame = menuManager.menuData.messageBubbleFrame
            let localBubbleFrame = CGRect(
                x: globalBubbleFrame.minX - screenGeometryGlobal.minX,
                y: globalBubbleFrame.minY - screenGeometryGlobal.minY,
                width: globalBubbleFrame.width,
                height: globalBubbleFrame.height
            )
            let bubbleCenterX = calculateBubbleCenterX(bubbleFrame: localBubbleFrame)
            let menuX = bubbleCenterX
            let arrowOffsetX = 0
            let menuHalfWidth = menuWidth/2
            let screenPadding = MessageMenuConfig.screenPadding
            let adjustedMenuX: CGFloat
            let adjustedArrowOffsetX: CGFloat
            if menuX - menuHalfWidth < visibleBounds.minX + screenPadding {
                adjustedMenuX = visibleBounds.minX + screenPadding + menuHalfWidth
                adjustedArrowOffsetX = bubbleCenterX - adjustedMenuX
            } else if menuX + menuHalfWidth > visibleBounds.maxX - screenPadding {
                adjustedMenuX = visibleBounds.maxX - screenPadding - menuHalfWidth
                adjustedArrowOffsetX = bubbleCenterX - adjustedMenuX
            } else {
                adjustedMenuX = menuX
                adjustedArrowOffsetX = CGFloat(arrowOffsetX)
            }
            let arrowClampMargin = MessageMenuConfig.menuCornerRadius + MessageMenuConfig.arrowWidth / 2
            let safeArrowOffsetX = max(
                -menuHalfWidth + arrowClampMargin,
                min(adjustedArrowOffsetX, menuHalfWidth - arrowClampMargin)
            )
            let menuY = MessageMenuPlacement.verticalPosition(
                bubbleFrame: localBubbleFrame,
                visibleBounds: visibleBounds,
                menuHeight: dynamicMenuHeight,
                preferAbove: menuManager.menuData.shouldShowAbove
            )
            return MenuPositionParams(
                x: adjustedMenuX,
                y: menuY.position,
                width: menuWidth,
                height: dynamicMenuHeight,
                arrowX: safeArrowOffsetX,
                showAbove: menuY.showAbove
            )
        }

        func calculateBubbleCenterX(bubbleFrame: CGRect) -> CGFloat {
            return bubbleFrame.midX
        }

        func calculateMenuY(
            shouldShowAbove: Bool,
            bubbleFrame: CGRect,
            minPosition: CGFloat,
            maxPosition: CGFloat,
            screenHeight: CGFloat,
            safeAreaTop: CGFloat,
            safeAreaBottom: CGFloat,
            menuHeight: CGFloat
        ) -> (position: CGFloat, showAbove: Bool) {
            if shouldShowAbove {
                return calculateMenuYAbove(
                    bubbleFrame: bubbleFrame,
                    minPosition: minPosition,
                    maxPosition: maxPosition,
                    screenHeight: screenHeight,
                    safeAreaTop: safeAreaTop,
                    safeAreaBottom: safeAreaBottom,
                    menuHeight: menuHeight
                )
            } else {
                return calculateMenuYBelow(
                    bubbleFrame: bubbleFrame,
                    minPosition: minPosition,
                    maxPosition: maxPosition,
                    screenHeight: screenHeight,
                    safeAreaTop: safeAreaTop,
                    safeAreaBottom: safeAreaBottom,
                    menuHeight: menuHeight
                )
            }
        }

        func calculateMenuYAbove(
            bubbleFrame: CGRect,
            minPosition: CGFloat,
            maxPosition: CGFloat,
            screenHeight: CGFloat,
            safeAreaTop: CGFloat,
            safeAreaBottom: CGFloat,
            menuHeight: CGFloat
        ) -> (position: CGFloat, showAbove: Bool) {
            var menuY = max(
                minPosition,
                bubbleFrame.minY - MessageMenuConfig.bubbleSpacing - menuHeight/2
            )
            if menuY + menuHeight/2 + 5 > bubbleFrame.minY {
                menuY = bubbleFrame.minY - MessageMenuConfig.bubbleSpacing - menuHeight/2
                if menuY - menuHeight/2 < safeAreaTop + MessageMenuConfig.minEdgeSpacing {
                    let belowY = min(
                        maxPosition,
                        bubbleFrame.maxY + menuHeight/2 + MessageMenuConfig.bubbleSpacing
                    )
                    if belowY + menuHeight/2 < screenHeight - safeAreaBottom - MessageMenuConfig.minEdgeSpacing {
                        return (belowY, false)
                    }
                }
            }
            menuY = max(minPosition, min(maxPosition, menuY))
            return (menuY, true)
        }

        func calculateMenuYBelow(
            bubbleFrame: CGRect,
            minPosition: CGFloat,
            maxPosition: CGFloat,
            screenHeight: CGFloat,
            safeAreaTop: CGFloat,
            safeAreaBottom: CGFloat,
            menuHeight: CGFloat
        ) -> (position: CGFloat, showAbove: Bool) {
            let messageListBounds = menuManager.menuData.messageListBounds

            var menuY = bubbleFrame.maxY + menuHeight/2 + MessageMenuConfig.bubbleSpacing

            if messageListBounds != .zero {
                let listHeight = messageListBounds.height
                let topPadding = CGFloat(SpacingScheme.iconIconSpacing)
                let bottomPadding = CGFloat(SpacingScheme.iconIconSpacing)

                let menuTop = menuY - menuHeight/2
                if menuTop < topPadding {
                    menuY = topPadding + menuHeight/2
                }

                let menuBottom = menuY + menuHeight/2
                if menuBottom > listHeight - bottomPadding {
                    let overflow = menuBottom - (listHeight - bottomPadding)
                    menuY = menuY - overflow
                }
            } else {
                if menuY + menuHeight/2 > screenHeight - safeAreaBottom - MessageMenuConfig.minEdgeSpacing {
                    let aboveY = max(
                        minPosition,
                        bubbleFrame.minY - MessageMenuConfig.bubbleSpacing - menuHeight/2
                    )
                    if aboveY - menuHeight/2 > safeAreaTop + MessageMenuConfig.minEdgeSpacing {
                        return (aboveY, true)
                    }
                    menuY = screenHeight - safeAreaBottom - menuHeight/2 - MessageMenuConfig.minEdgeSpacing
                }
                menuY = max(minPosition, min(maxPosition, menuY))
            }

            return (menuY, false)
        }
    }

    struct MenuMainContentView: View {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        let customActions: [MessageCustomAction]
        let asrDisplayManager: AsrDisplayManager
        let translationDisplayManager: TranslationDisplayManager

        init(
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat,
            arrowX: CGFloat,
            showAbove: Bool,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol,
            customActions: [MessageCustomAction] = [],
            asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
            translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
        ) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.arrowX = arrowX
            self.showAbove = showAbove
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
            self.customActions = customActions
            self.asrDisplayManager = asrDisplayManager
            self.translationDisplayManager = translationDisplayManager
        }

        var body: some View {
            ZStack(alignment: showAbove ? .top : .bottom) {
                UnifiedMenuShape(
                    width: width,
                    height: height,
                    arrowX: arrowX,
                    showAbove: showAbove
                )
                if fullContentHeight > height {
                    ScrollView(.vertical, showsIndicators: false) {
                        menuContent
                            .frame(height: fullContentHeight)
                    }
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: MessageMenuConfig.menuCornerRadius))
                    .zIndex(35)
                } else {
                    menuContent
                }
            }
            .frame(width: width, height: height)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chat_message_action_menu")
            .position(x: x, y: y)
        }

        private var fullContentHeight: CGFloat {
            let buttons = MenuButtonConfig.getVisibleButtons(for: menuManager.menuData.message, style: style, customActions: customActions, asrDisplayManager: asrDisplayManager, translationDisplayManager: translationDisplayManager)
            let count = buttons.count
            let hasReactionEntry = buttons.contains { $0.isReactionEntry }
            return menuManager.menuData.isShowingEmojiPanel
                ? MessageMenuConfig.calculateEmojiPanelDimensions(buttonCount: count).height
                : MessageMenuConfig.calculateMenuDimensions(buttonCount: count, forceFullColumns: hasReactionEntry).height
        }

        private var menuContent: some View {
            MenuContentView(
                width: width,
                showAbove: showAbove,
                menuManager: menuManager,
                messageActionStore: messageActionStore,
                style: style,
                customActions: customActions,
                asrDisplayManager: asrDisplayManager,
                translationDisplayManager: translationDisplayManager
            )
        }
    }

    struct UnifiedMenuShape: View {
        @EnvironmentObject var themeState: ThemeState
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        init(width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
            self.width = width
            self.height = height
            self.arrowX = arrowX
            self.showAbove = showAbove
        }

        var body: some View {
            MenuShapePath(
                width: width,
                height: height,
                arrowX: arrowX,
                showAbove: showAbove
            )
            .fill(themeState.colors.dropdownColorDefault)
            .shadow(color: themeState.colors.shadowColor, radius: CGFloat(RadiusScheme.smallRadius), x: 0, y: 2)
            .zIndex(30)
        }
    }

    struct MenuShapePath: Shape {
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        init(width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
            self.width = width
            self.height = height
            self.arrowX = arrowX
            self.showAbove = showAbove
        }

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let cornerRadius: CGFloat = MessageMenuConfig.menuCornerRadius
            let arrowWidth: CGFloat = MessageMenuConfig.arrowWidth
            let arrowHeight: CGFloat = MessageMenuConfig.arrowHeight
            let centerX = rect.width/2
            let arrowCenterX = centerX + arrowX
            let arrowLeft = arrowCenterX - arrowWidth/2
            let arrowRight = arrowCenterX + arrowWidth/2
            if showAbove {
                let menuBottom = rect.maxY - arrowHeight
                path.move(to: CGPoint(x: cornerRadius, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                    control: CGPoint(x: rect.maxX, y: rect.minY)
                )
                path.addLine(to: CGPoint(x: rect.maxX, y: menuBottom - cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - cornerRadius, y: menuBottom),
                    control: CGPoint(x: rect.maxX, y: menuBottom)
                )
                path.addLine(to: CGPoint(x: arrowRight, y: menuBottom))
                path.addLine(to: CGPoint(x: arrowCenterX, y: rect.maxY))
                path.addLine(to: CGPoint(x: arrowLeft, y: menuBottom))
                path.addLine(to: CGPoint(x: cornerRadius, y: menuBottom))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: menuBottom - cornerRadius),
                    control: CGPoint(x: rect.minX, y: menuBottom)
                )
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: rect.minY),
                    control: CGPoint(x: rect.minX, y: rect.minY)
                )
            } else {
                let menuTop = rect.minY + arrowHeight
                path.move(to: CGPoint(x: arrowLeft, y: menuTop))
                path.addLine(to: CGPoint(x: arrowCenterX, y: rect.minY))
                path.addLine(to: CGPoint(x: arrowRight, y: menuTop))
                path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: menuTop))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: menuTop + cornerRadius),
                    control: CGPoint(x: rect.maxX, y: menuTop)
                )
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: cornerRadius, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX, y: menuTop + cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: menuTop),
                    control: CGPoint(x: rect.minX, y: menuTop)
                )
                path.addLine(to: CGPoint(x: arrowLeft, y: menuTop))
            }
            path.closeSubpath()
            return path
        }
    }

    struct MenuBackgroundView: View {
        @EnvironmentObject var themeState: ThemeState
        let width: CGFloat
        let height: CGFloat
        init(width: CGFloat, height: CGFloat) {
            self.width = width
            self.height = height
        }

        var body: some View {
            RoundedRectangle(cornerRadius: CGFloat(themeState.radius.alertRadius))
                .fill(themeState.colors.floatingColorDefault)
                .frame(width: width + 4, height: height + 4)
                .shadow(color: themeState.colors.shadowColor, radius: CGFloat(themeState.radius.largeRadius), x: 0, y: CGFloat(themeState.spacing.iconTextSpacing))
                .zIndex(10)
            RoundedRectangle(cornerRadius: CGFloat(themeState.radius.alertRadius))
                .fill(themeState.colors.floatingColorDefault)
                .frame(width: width, height: height)
                .shadow(color: themeState.colors.shadowColor, radius: CGFloat(themeState.radius.alertRadius), x: 0, y: CGFloat(themeState.spacing.iconTextSpacing))
                .zIndex(20)
        }
    }

    struct MenuContentView: View {
        @EnvironmentObject var themeState: ThemeState
        @ObservedObject var menuManager: MessageMenuManager
        let width: CGFloat
        let showAbove: Bool
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        let customActions: [MessageCustomAction]
        let asrDisplayManager: AsrDisplayManager
        let translationDisplayManager: TranslationDisplayManager

        init(
            width: CGFloat,
            showAbove: Bool,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol,
            customActions: [MessageCustomAction] = [],
            asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
            translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
        ) {
            self.width = width
            self.showAbove = showAbove
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
            self.customActions = customActions
            self.asrDisplayManager = asrDisplayManager
            self.translationDisplayManager = translationDisplayManager
        }

        var body: some View {
            VStack(spacing: 0) {
                if !showAbove {
                    Spacer().frame(height: MessageMenuConfig.arrowHeight)
                }

                if menuManager.menuData.isShowingEmojiPanel, let message = menuManager.menuData.message {
                    ReactionEmojiPanelView(
                        message: message,
                        onCollapse: {
                            menuManager.hideEmojiPanel()
                        },
                        onMore: {
                            menuManager.hideMenu()
                            NotificationCenter.default.post(
                                name: NSNotification.Name("showReactionFullEmojiPicker"),
                                object: nil,
                                userInfo: ["message": message]
                            )
                        },
                        onToggleEmoji: { emoji in
                            guard let emojiName = emoji.name else { return }
                            let hasReacted = message.reactionList.contains { $0.reactionID == emojiName && $0.reactedByMyself }
                            if !hasReacted {
                                EmojiManager.shared.addRecentEmoji(emoji, groupID: EmojiManager.shared.reactionGroupID())
                            }
                            NotificationCenter.default.post(
                                name: NSNotification.Name("messageReactionToggle"),
                                object: nil,
                                userInfo: ["message": message, "reactionID": emojiName]
                            )
                            menuManager.hideMenu()
                        }
                    )
                    .environmentObject(themeState)
                } else {
                    FlexibleButtonGridView(
                        width: width,
                        menuManager: menuManager,
                        messageActionStore: messageActionStore,
                        style: style,
                        customActions: customActions,
                        asrDisplayManager: asrDisplayManager,
                        translationDisplayManager: translationDisplayManager
                    )
                }
                if showAbove {
                    Spacer().frame(height: MessageMenuConfig.arrowHeight)
                }
            }
            .zIndex(35)
        }
    }

    struct FlexibleButtonGridView: View {
        @ObservedObject var menuManager: MessageMenuManager
        @EnvironmentObject var themeState: ThemeState
        @State private var currentPage = 0
        let width: CGFloat
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        let customActions: [MessageCustomAction]
        let asrDisplayManager: AsrDisplayManager
        let translationDisplayManager: TranslationDisplayManager

        init(
            width: CGFloat,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol,
            customActions: [MessageCustomAction] = [],
            asrDisplayManager: AsrDisplayManager = AsrDisplayManager(),
            translationDisplayManager: TranslationDisplayManager = TranslationDisplayManager()
        ) {
            self.width = width
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
            self.customActions = customActions
            self.asrDisplayManager = asrDisplayManager
            self.translationDisplayManager = translationDisplayManager
        }

        private var buttonData: [ButtonConfig] {
            return MenuButtonConfig.getVisibleButtons(for: menuManager.menuData.message, style: style, customActions: customActions, asrDisplayManager: asrDisplayManager, translationDisplayManager: translationDisplayManager)
        }
        private var forceFullColumns: Bool {
            buttonData.contains { $0.isReactionEntry }
        }

        var body: some View {
            let buttons = buttonData
            let pages = chunked(buttons, into: MessageMenuConfig.buttonsPerPage)
            if pages.count <= 1 {
                menuPage(buttons: buttons)
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { pageIndex in
                            menuPage(buttons: pages[pageIndex])
                                .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: MessageMenuConfig.menuPageHeight(rowCount: MessageMenuConfig.pageRows))

                    HStack(spacing: MessageMenuConfig.indicatorDotSpacing) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(themeState.colors.textColorPrimary.opacity(index == currentPage ? 1.0 : MessageMenuConfig.indicatorInactiveAlpha))
                                .frame(width: MessageMenuConfig.indicatorDotSize, height: MessageMenuConfig.indicatorDotSize)
                        }
                    }
                    .frame(height: MessageMenuConfig.indicatorAreaHeight)
                }
            }
        }

        private func menuPage(buttons: [ButtonConfig]) -> some View {
            let rows = chunked(buttons, into: MessageMenuConfig.columns)
            return VStack(spacing: 0) {
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    ButtonRowView(
                        buttons: rows[rowIndex],
                        columnCount: forceFullColumns ? MessageMenuConfig.columns : rows[rowIndex].count,
                        menuManager: menuManager,
                        messageActionStore: messageActionStore,
                        style: style
                    )
                    if rowIndex < rows.count - 1 {
                        Rectangle()
                            .fill(themeState.colors.strokeColorPrimary.opacity(MessageMenuConfig.rowDividerAlpha))
                            .frame(height: MessageMenuConfig.rowDividerHeight)
                            .padding(.horizontal, MessageMenuConfig.rowDividerSideMargin)
                    }
                }
            }
            .padding(MessageMenuConfig.pagePadding)
        }

        private func chunked(_ array: [ButtonConfig], into size: Int) -> [[ButtonConfig]] {
            guard size > 0 else { return [array] }
            var result: [[ButtonConfig]] = []
            var index = 0
            while index < array.count {
                let end = min(index + size, array.count)
                result.append(Array(array[index..<end]))
                index = end
            }
            return result
        }
    }

    struct ButtonRowView: View {
        @ObservedObject var menuManager: MessageMenuManager
        let buttons: [ButtonConfig]
        let columnCount: Int
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol

        init(
            buttons: [ButtonConfig],
            columnCount: Int,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol
        ) {
            self.buttons = buttons
            self.columnCount = columnCount
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        var body: some View {
            HStack(spacing: 0) {
                ForEach(0..<buttons.count, id: \.self) { index in
                    MenuActionButton(
                        iconName: buttons[index].iconName,
                        systemIconFallback: buttons[index].systemIconFallback,
                        label: buttons[index].label,
                        action: buttons[index].createAction(
                            for: menuManager.menuData.message,
                            menuManager: menuManager,
                            messageActionStore: messageActionStore
                        )
                    )
                }
                if buttons.count < columnCount {
                    ForEach(0..<(columnCount - buttons.count), id: \.self) { _ in
                        Color.clear
                            .frame(width: MessageMenuConfig.cellWidth, height: MessageMenuConfig.cellHeight)
                    }
                }
            }
        }
    }

    struct MenuActionButton: View {
        @EnvironmentObject var themeState: ThemeState
        let iconName: String
        let systemIconFallback: String
        let label: String
        let action: () -> Void

        init(iconName: String, systemIconFallback: String, label: String, action: @escaping () -> Void) {
            self.iconName = iconName
            self.systemIconFallback = systemIconFallback
            self.label = label
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                VStack(spacing: MessageMenuConfig.iconTitleSpacing) {
                    if UIImage(named: iconName, in: AtomicXChatResources.resourceBundle, compatibleWith: nil) != nil {
                        Image(iconName, bundle: AtomicXChatResources.resourceBundle)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: MessageMenuConfig.iconSize, height: MessageMenuConfig.iconSize)
                            .foregroundColor(themeState.colors.textColorPrimary)
                    } else {
                        Image(systemName: systemIconFallback)
                            .font(themeState.fonts.body3Regular)
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    Text(label)
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(MessageMenuConfig.titleMaxLines)
                        .truncationMode(.tail)
                }
                .padding(.top, MessageMenuConfig.iconTopMargin)
                .padding(.bottom, MessageMenuConfig.titleBottomMargin)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: MessageMenuConfig.cellWidth, height: MessageMenuConfig.cellHeight)
        }
    }
}
