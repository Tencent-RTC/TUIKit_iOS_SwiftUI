import Foundation
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif
import AtomicXCore
import UIKit

private struct MessageActionConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageActionConfigProtocol = ChatMessageStyle()
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

    init(
        iconName: String,
        systemIconFallback: String,
        label: String,
        shouldShow: @escaping (MessageInfo?) -> Bool = { _ in true },
        actionHandler: @escaping (MessageInfo?, MessageMenuManager, MessageActionStore) -> Void
    ) {
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.label = label
        self.shouldShow = shouldShow
        self.actionHandler = actionHandler
    }

    func createAction(for message: MessageInfo?, menuManager: MessageMenuManager, messageActionStore: MessageActionStore) -> () -> Void {
        return { [actionHandler] in
            actionHandler(message, menuManager, messageActionStore)
        }
    }
}

struct MenuPositionParams {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    public let arrowX: CGFloat
    public let showAbove: Bool

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.arrowX = arrowX
        self.showAbove = showAbove
    }
}

struct MessageMenuData {
    var isShowing: Bool = false
    var message: MessageInfo? = nil
    var messageBubbleFrame: CGRect = .zero
    var shouldShowAbove: Bool = true
}

enum MessageMenuConfig {
    static let menuHeight: CGFloat = 80
    static let menuMaxWidth: CGFloat = 300
    static let menuHorizontalPadding: CGFloat = 30
    static let menuCornerRadius: CGFloat = 14
    static let menuContentTopPadding: CGFloat = 16
    static let menuContentBottomPadding: CGFloat = 16
    static let menuContentSidePadding: CGFloat = 1
    static let arrowWidth: CGFloat = 22
    static let arrowHeight: CGFloat = 11
    static let buttonWidth: CGFloat = 42
    static let buttonHeight: CGFloat = 30
    static let buttonSideInset: CGFloat = 10
    static let buttonMinSpacing: CGFloat = 5
    static let maxButtonsPerRow: Int = 5
    static let rowSpacing: CGFloat = 18
    static let minMenuWidth: CGFloat = 60
    static let iconSize: CGFloat = 18
    static let labelFontSize: CGFloat = 10
    static let iconLabelSpacing: CGFloat = 6
    static let menuBubbleSpacing: CGFloat = 0
    static let menuSafeSpacing: CGFloat = 60
    static let menuMinEdgeSpacing: CGFloat = 20
    static let arrowMinMargin: CGFloat = 30

    static func calculateMenuDimensions(buttonCount: Int) -> (width: CGFloat, height: CGFloat) {
        let rows = calculateRowCount(buttonCount: buttonCount)
        let buttonsInFullRow = min(buttonCount, maxButtonsPerRow)
        let totalButtonWidth = CGFloat(buttonsInFullRow) * buttonWidth
        let totalSpacing = CGFloat(max(0, buttonsInFullRow - 1)) * buttonMinSpacing
        let totalSideInsets = buttonSideInset * 2
        let contentPadding = menuContentSidePadding * 2
        let calculatedWidth = totalButtonWidth + totalSpacing + totalSideInsets + contentPadding
        let menuWidth = max(minMenuWidth, min(calculatedWidth, menuMaxWidth))
        let buttonAreaHeight = CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * rowSpacing
        let contentHeight = buttonAreaHeight + menuContentTopPadding + menuContentBottomPadding
        let totalHeight = contentHeight + arrowHeight + contentPadding
        return (menuWidth, totalHeight)
    }

    static func calculateRowCount(buttonCount: Int) -> Int {
        return (buttonCount + maxButtonsPerRow - 1)/maxButtonsPerRow
    }

    static func calculateMenuWidth(buttonCount: Int) -> CGFloat {
        return calculateMenuDimensions(buttonCount: buttonCount).width
    }
}

enum MenuButtonConfig {
    static let allButtons: [ButtonConfig] = [
        ButtonConfig(
            iconName: "copy_icon_figma",
            systemIconFallback: "doc.on.doc",
            label: LocalizedChatString("Copy"),
            shouldShow: { _ in true },
            actionHandler: { message, menuManager, _ in
                if let text = message?.messageBody?.text {
                    UIPasteboard.general.string = text
//                    Toast.simple(LocalizedChatString("copied"))
                }
                menuManager.hideMenu()
            }
        ),
        // ButtonConfig(
        //     iconName: "quote_icon_figma",
        //     systemIconFallback: "text.quote",
        //     label: LocalizedChatString("Quote"),
        //     shouldShow: { _ in true },
        //     actionHandler: { _, menuManager, _ in
        //         menuManager.hideMenu()
        //     }
        // ),
        ButtonConfig(
            iconName: "recall_icon_figma",
            systemIconFallback: "arrow.uturn.backward",
            label: LocalizedChatString("Revoke"),
            shouldShow: { message in
                guard let message = message else { return false }
                guard message.isSelf else { return false }
                guard let messageDate = message.timestamp else { return false }
                let currentTime = Date()
                let timeDifference = currentTime.timeIntervalSince(messageDate)
                let twoMinutesInSeconds: TimeInterval = 2 * 60
                return timeDifference < twoMinutesInSeconds
            },
            actionHandler: { message, menuManager, messageActionStore in
                guard let message = message else { return }
                menuManager.hideMenu()
                messageActionStore.recallMessage(message, completion: { _ in })
            }
        ),
        ButtonConfig(
            iconName: "delete_icon_figma",
            systemIconFallback: "trash",
            label: LocalizedChatString("Delete"),
            shouldShow: { _ in true },
            actionHandler: { message, menuManager, messageActionStore in
                guard let message = message else { return }
                menuManager.hideMenu()
                messageActionStore.deleteMessage(message, completion: { _ in })
            }
        )
    ]

    static func getVisibleButtons(for message: MessageInfo?, style: MessageActionConfigProtocol?) -> [ButtonConfig] {
        return allButtons.filter { button in
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
            default:
                return true
            }
        }
    }
}

class MessageMenuManager: ObservableObject {
    @Published var menuData = MessageMenuData()
    static let shared = MessageMenuManager()

    func showMenu(for message: MessageInfo, bubbleFrame: CGRect) {
        let safeInsets = getSafeAreaInsets()
        let safeAreaTop = safeInsets.top
        let buttonCount = MenuButtonConfig.getVisibleButtons(for: message, style: ChatMessageStyle()).count
        let dynamicMenuHeight = MessageMenuConfig.calculateMenuDimensions(buttonCount: buttonCount).height
        let hasEnoughSpaceAbove = bubbleFrame.minY - safeAreaTop >= dynamicMenuHeight + 40
        menuData = MessageMenuData(
            isShowing: true,
            message: message,
            messageBubbleFrame: bubbleFrame,
            shouldShowAbove: hasEnoughSpaceAbove
        )
    }

    func hideMenu() {
        menuData.isShowing = false
    }
}

func getSafeAreaInsets() -> UIEdgeInsets {
    if #available(iOS 15.0, *) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first
        {
            return window.safeAreaInsets
        }
    }
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        return window.safeAreaInsets
    }
    return UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
}

struct MessageActionView: View {
    @EnvironmentObject var menuManager: MessageMenuManager
    @Environment(\.MessageActionConfigProtocol) var style: MessageActionConfigProtocol
    private var messageActionStore: MessageActionStore

    public init() {
        self.messageActionStore = MessageActionStore.create()
    }

    public var body: some View {
        if let message = menuManager.menuData.message,
           menuManager.menuData.isShowing,
           MenuButtonConfig.getVisibleButtons(for: message, style: style).count > 0
        {
            ZStack {
                menuContent(message: message)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: menuManager.menuData.isShowing)
        }
    }

    private func menuContent(message: MessageInfo) -> some View {
        MenuPositionWrapper(message: message, menuManager: menuManager, messageActionStore: messageActionStore, style: style)
    }

    public struct MenuPositionWrapper: View {
        let message: MessageInfo
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        public init(message: MessageInfo, menuManager: MessageMenuManager, messageActionStore: MessageActionStore, style: MessageActionConfigProtocol) {
            self.message = message
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        public var body: some View {
            MenuContentCalculator(
                message: message,
                menuManager: menuManager,
                messageActionStore: messageActionStore,
                style: style
            )
        }
    }

    public struct MenuContentCalculator: View {
        let message: MessageInfo
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        public var menuHeight: CGFloat { MessageMenuConfig.menuHeight }
        public var horizontalPadding: CGFloat { MessageMenuConfig.menuHorizontalPadding }
        public var safeSpacing: CGFloat { MessageMenuConfig.menuSafeSpacing }
        public init(message: MessageInfo, menuManager: MessageMenuManager, messageActionStore: MessageActionStore, style: MessageActionConfigProtocol) {
            self.message = message
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        public var body: some View {
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
                    style: style
                )
            }
            .edgesIgnoringSafeArea(.all)
        }

        public func calculateMenuPosition(screenGeometry: GeometryProxy) -> MenuPositionParams {
            let buttonCount = MenuButtonConfig.getVisibleButtons(for: message, style: style).count
            let dimensions = MessageMenuConfig.calculateMenuDimensions(buttonCount: buttonCount)
            let menuWidth = dimensions.width
            let dynamicMenuHeight = dimensions.height
            let screenHeight = UIScreen.main.bounds.height
            let screenWidth = UIScreen.main.bounds.width
            let safeInsets = getSafeAreaInsets()
            let safeAreaTop = safeInsets.top
            let safeAreaBottom = safeInsets.bottom
            let globalBubbleFrame = menuManager.menuData.messageBubbleFrame
            let localBubbleFrame = CGRect(
                x: globalBubbleFrame.minX - screenGeometry.frame(in: .global).minX,
                y: globalBubbleFrame.minY - screenGeometry.frame(in: .global).minY,
                width: globalBubbleFrame.width,
                height: globalBubbleFrame.height
            )
            let bubbleCenterX = calculateBubbleCenterX(bubbleFrame: localBubbleFrame)
            let menuX = bubbleCenterX
            let arrowOffsetX = 0
            let menuHalfWidth = menuWidth/2
            let screenPadding: CGFloat = 20
            let adjustedMenuX: CGFloat
            let adjustedArrowOffsetX: CGFloat
            if menuX - menuHalfWidth < screenPadding {
                adjustedMenuX = screenPadding + menuHalfWidth
                adjustedArrowOffsetX = bubbleCenterX - adjustedMenuX
            } else if menuX + menuHalfWidth > screenWidth - screenPadding {
                adjustedMenuX = screenWidth - screenPadding - menuHalfWidth
                adjustedArrowOffsetX = bubbleCenterX - adjustedMenuX
            } else {
                adjustedMenuX = menuX
                adjustedArrowOffsetX = CGFloat(arrowOffsetX)
            }
            let safeArrowOffsetX = max(
                -menuHalfWidth + MessageMenuConfig.arrowMinMargin,
                min(adjustedArrowOffsetX, menuHalfWidth - MessageMenuConfig.arrowMinMargin)
            )
            let minVerticalPosition = safeAreaTop + dynamicMenuHeight/2 + MessageMenuConfig.menuMinEdgeSpacing
            let maxVerticalPosition = screenHeight - safeAreaBottom - dynamicMenuHeight/2 - MessageMenuConfig.menuMinEdgeSpacing
            let shouldShowAbove = menuManager.menuData.shouldShowAbove
            let menuY = calculateMenuY(
                shouldShowAbove: shouldShowAbove,
                bubbleFrame: localBubbleFrame,
                minPosition: minVerticalPosition,
                maxPosition: maxVerticalPosition,
                screenHeight: screenHeight,
                safeAreaTop: safeAreaTop,
                safeAreaBottom: safeAreaBottom,
                menuHeight: dynamicMenuHeight
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

        public func calculateBubbleCenterX(bubbleFrame: CGRect) -> CGFloat {
            return bubbleFrame.midX
        }

        public func calculateMenuY(
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

        public func calculateMenuYAbove(
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
                bubbleFrame.minY - MessageMenuConfig.menuBubbleSpacing - menuHeight/2
            )
            if menuY + menuHeight/2 + 5 > bubbleFrame.minY {
                menuY = bubbleFrame.minY - MessageMenuConfig.menuBubbleSpacing - menuHeight/2
                if menuY - menuHeight/2 < safeAreaTop + MessageMenuConfig.menuMinEdgeSpacing {
                    let belowY = min(
                        maxPosition,
                        bubbleFrame.maxY + menuHeight/2 + MessageMenuConfig.menuBubbleSpacing
                    )
                    if belowY + menuHeight/2 < screenHeight - safeAreaBottom - MessageMenuConfig.menuMinEdgeSpacing {
                        return (belowY, false)
                    }
                }
            }
            return (menuY, true)
        }

        public func calculateMenuYBelow(
            bubbleFrame: CGRect,
            minPosition: CGFloat,
            maxPosition: CGFloat,
            screenHeight: CGFloat,
            safeAreaTop: CGFloat,
            safeAreaBottom: CGFloat,
            menuHeight: CGFloat
        ) -> (position: CGFloat, showAbove: Bool) {
            var menuY = min(
                maxPosition,
                bubbleFrame.maxY + menuHeight/2 + MessageMenuConfig.menuBubbleSpacing
            )
            if menuY + menuHeight/2 > screenHeight - safeAreaBottom - MessageMenuConfig.menuMinEdgeSpacing {
                let aboveY = max(
                    minPosition,
                    bubbleFrame.minY - MessageMenuConfig.menuBubbleSpacing - menuHeight/2
                )
                if aboveY - menuHeight/2 > safeAreaTop + MessageMenuConfig.menuMinEdgeSpacing {
                    return (aboveY, true)
                }
                menuY = screenHeight - safeAreaBottom - menuHeight/2 - MessageMenuConfig.menuMinEdgeSpacing
            }
            return (menuY, false)
        }
    }

    public struct MenuMainContentView: View {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        @ObservedObject var menuManager: MessageMenuManager
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol
        public init(
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat,
            arrowX: CGFloat,
            showAbove: Bool,
            menuManager: MessageMenuManager,
            messageActionStore: MessageActionStore,
            style: MessageActionConfigProtocol
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
        }

        public var body: some View {
            ZStack {
                UnifiedMenuShape(
                    width: width,
                    height: height,
                    arrowX: arrowX,
                    showAbove: showAbove
                )
                MenuContentView(
                    width: width,
                    showAbove: showAbove,
                    menuManager: menuManager,
                    messageActionStore: messageActionStore,
                    style: style
                )
            }
            .frame(width: width, height: height)
            .position(x: x, y: y)
        }
    }

    public struct UnifiedMenuShape: View {
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        public init(width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
            self.width = width
            self.height = height
            self.arrowX = arrowX
            self.showAbove = showAbove
        }

        public var body: some View {
            MenuShapePath(
                width: width,
                height: height,
                arrowX: arrowX,
                showAbove: showAbove
            )
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
            .zIndex(30)
        }
    }

    public struct MenuShapePath: Shape {
        let width: CGFloat
        let height: CGFloat
        let arrowX: CGFloat
        let showAbove: Bool
        public init(width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
            self.width = width
            self.height = height
            self.arrowX = arrowX
            self.showAbove = showAbove
        }

        public func path(in rect: CGRect) -> Path {
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

    public struct MenuBackgroundView: View {
        let width: CGFloat
        let height: CGFloat
        public init(width: CGFloat, height: CGFloat) {
            self.width = width
            self.height = height
        }

        public var body: some View {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .frame(width: width + 4, height: height + 4)
                .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 5)
                .zIndex(10)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .frame(width: width, height: height)
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
                .zIndex(20)
        }
    }

//    public struct MenuArrowView: View {
//        let width: CGFloat
//        let height: CGFloat
//        let arrowX: CGFloat
//        let showAbove: Bool
//        public init(width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
//            self.width = width
//            self.height = height
//            self.arrowX = arrowX
//            self.showAbove = showAbove
//        }
//        public var body: some View {
//            Group {
//                if showAbove {
//                    TriangleShape()
//                        .fill(Color.white)
//                        .frame(width: 16, height: 8)
//                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
//                        .rotationEffect(.degrees(180))
//                        .offset(x: arrowX, y: height/2 + 1)
//                        .zIndex(40)
//                } else {
//                    TriangleShape()
//                        .fill(Color.white)
//                        .frame(width: 16, height: 8)
//                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: -2)
//                        .offset(x: arrowX, y: -height/2 - 1)
//                        .zIndex(40)
//                }
//            }
//        }
//    }
    public struct MenuContentView: View {
        @ObservedObject var menuManager: MessageMenuManager
        let width: CGFloat
        let showAbove: Bool
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol

        public init(width: CGFloat, showAbove: Bool, menuManager: MessageMenuManager, messageActionStore: MessageActionStore, style: MessageActionConfigProtocol) {
            self.width = width
            self.showAbove = showAbove
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        public var body: some View {
            VStack(spacing: 0) {
                if !showAbove {
                    Spacer().frame(height: MessageMenuConfig.arrowHeight)
                }
                FlexibleButtonGridView(
                    width: width,
                    menuManager: menuManager,
                    messageActionStore: messageActionStore,
                    style: style
                )
                .padding(.top, MessageMenuConfig.menuContentTopPadding)
                .padding(.bottom, MessageMenuConfig.menuContentBottomPadding)
                if showAbove {
                    Spacer().frame(height: MessageMenuConfig.arrowHeight)
                }
                // Rectangle()
                //     .fill(Color(hex: 0xE5E5E5))
                //     .frame(height: 1)
                //     .padding(.horizontal, 0)
            }
            .padding(MessageMenuConfig.menuContentSidePadding)
            .zIndex(35)
        }
    }

    public struct FlexibleButtonGridView: View {
        @ObservedObject var menuManager: MessageMenuManager
        let width: CGFloat
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol

        public init(width: CGFloat, menuManager: MessageMenuManager, messageActionStore: MessageActionStore, style: MessageActionConfigProtocol) {
            self.width = width
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        private var buttonData: [ButtonConfig] {
            return MenuButtonConfig.getVisibleButtons(for: menuManager.menuData.message, style: style)
        }

        public var body: some View {
            let buttons = buttonData
            let buttonCount = buttons.count
            let rowCount = MessageMenuConfig.calculateRowCount(buttonCount: buttonCount)
            VStack(spacing: MessageMenuConfig.rowSpacing) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    buttonRow(for: rowIndex, buttons: buttons)
                }
            }
        }

        private func buttonRow(for rowIndex: Int, buttons: [ButtonConfig]) -> some View {
            let maxButtonsPerRow = MessageMenuConfig.maxButtonsPerRow
            let startIndex = rowIndex * maxButtonsPerRow
            let endIndex = min(startIndex + maxButtonsPerRow, buttons.count)
            let rowButtons = Array(buttons[startIndex..<endIndex])
            return ButtonRowView(
                buttons: rowButtons,
                width: width,
                menuManager: menuManager,
                messageActionStore: messageActionStore,
                style: style
            )
        }
    }

    public struct ButtonRowView: View {
        @ObservedObject var menuManager: MessageMenuManager
        let buttons: [ButtonConfig]
        let width: CGFloat
        var messageActionStore: MessageActionStore
        let style: MessageActionConfigProtocol

        public init(buttons: [ButtonConfig], width: CGFloat, menuManager: MessageMenuManager, messageActionStore: MessageActionStore, style: MessageActionConfigProtocol) {
            self.buttons = buttons
            self.width = width
            self.menuManager = menuManager
            self.messageActionStore = messageActionStore
            self.style = style
        }

        public var body: some View {
            let sideInset = MessageMenuConfig.buttonSideInset
            let buttonWidth = MessageMenuConfig.buttonWidth
            let fixedSpacing = MessageMenuConfig.buttonMinSpacing
            HStack(spacing: 0) {
                Spacer().frame(width: sideInset)
                HStack(spacing: fixedSpacing) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        MenuActionButton(
                            iconName: buttons[index].iconName,
                            systemIconFallback: buttons[index].systemIconFallback,
                            label: buttons[index].label,
                            width: buttonWidth,
                            height: MessageMenuConfig.buttonHeight,
                            action: buttons[index].createAction(for: menuManager.menuData.message, menuManager: menuManager, messageActionStore: messageActionStore)
                        )
                    }
                }
                Spacer()
            }
            .frame(width: width)
        }
    }

    public struct MenuActionButton: View {
        let iconName: String
        let systemIconFallback: String
        let label: String
        let width: CGFloat
        let height: CGFloat
        let action: () -> Void

        public init(iconName: String, systemIconFallback: String, label: String, width: CGFloat, height: CGFloat, action: @escaping () -> Void) {
            self.iconName = iconName
            self.systemIconFallback = systemIconFallback
            self.label = label
            self.width = width
            self.height = height
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                VStack(spacing: MessageMenuConfig.iconLabelSpacing) {
                    ZStack {
                        if UIImage(named: iconName) != nil {
                            Image(iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: MessageMenuConfig.iconSize, height: MessageMenuConfig.iconSize)
                                .foregroundColor(.gray)
                        } else {
                            Image(systemName: systemIconFallback)
                                .font(.system(size: MessageMenuConfig.iconSize - 2))
                                .foregroundColor(.gray)
                        }
                    }
                    Text(label)
                        .font(.system(size: MessageMenuConfig.labelFontSize))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: width, height: height)
        }
    }
}
