import AtomicXCore
import SwiftUI

class AsrDisplayManager: ObservableObject {
    private var expandedMessageIDs: Set<String> = []

    init() {}

    func isExpanded(_ messageID: String?) -> Bool {
        guard let messageID = messageID, !messageID.isEmpty else { return false }
        return expandedMessageIDs.contains(messageID)
    }

    func expand(_ messageID: String?) {
        guard let messageID = messageID, !messageID.isEmpty else { return }
        expandedMessageIDs.insert(messageID)
    }

    func collapse(_ messageID: String?) {
        guard let messageID = messageID, !messageID.isEmpty else { return }
        expandedMessageIDs.remove(messageID)
    }
}


class TranslationDisplayManager: ObservableObject {
    private var expandedMessageIDs: Set<String> = []

    init() {}

    func isExpanded(_ messageID: String?) -> Bool {
        guard let messageID = messageID, !messageID.isEmpty else { return false }
        return expandedMessageIDs.contains(messageID)
    }

    func expand(_ messageID: String?) {
        guard let messageID = messageID, !messageID.isEmpty else { return }
        expandedMessageIDs.insert(messageID)
    }

    func collapse(_ messageID: String?) {
        guard let messageID = messageID, !messageID.isEmpty else { return }
        expandedMessageIDs.remove(messageID)
    }
}


private struct AsrDisplayManagerKey: EnvironmentKey {
    static let defaultValue: AsrDisplayManager = .init()
}

private struct TranslationDisplayManagerKey: EnvironmentKey {
    static let defaultValue: TranslationDisplayManager = .init()
}

extension EnvironmentValues {
    var asrDisplayManager: AsrDisplayManager {
        get { self[AsrDisplayManagerKey.self] }
        set { self[AsrDisplayManagerKey.self] = newValue }
    }

    var translationDisplayManager: TranslationDisplayManager {
        get { self[TranslationDisplayManagerKey.self] }
        set { self[TranslationDisplayManagerKey.self] = newValue }
    }
}


struct AuxiliaryTextMenuAction {
    let iconName: String
    let systemIconFallback: String
    let label: String
    let action: () -> Void

    init(
        iconName: String,
        systemIconFallback: String = "",
        label: String,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.label = label
        self.action = action
    }
}


struct AuxiliaryTextMenuData {
    var isShowing: Bool = false
    var bubbleFrame: CGRect = .zero
    var shouldShowAbove: Bool = true
    var actions: [AuxiliaryTextMenuAction] = []
}


class AuxiliaryTextMenuManager: ObservableObject {
    @Published var menuData = AuxiliaryTextMenuData()

    func showMenu(bubbleFrame: CGRect, actions: [AuxiliaryTextMenuAction]) {
        let safeInsets = getSafeAreaInsets()
        let safeAreaTop = safeInsets.top
        let buttonCount = actions.count
        let dynamicMenuHeight = AuxiliaryTextMenuConfig.calculateMenuDimensions(buttonCount: buttonCount).height
        let hasEnoughSpaceAbove = bubbleFrame.minY - safeAreaTop >= dynamicMenuHeight + 40

        menuData = AuxiliaryTextMenuData(
            isShowing: true,
            bubbleFrame: bubbleFrame,
            shouldShowAbove: hasEnoughSpaceAbove,
            actions: actions
        )
    }

    func hideMenu() {
        menuData.isShowing = false
    }

    private func getSafeAreaInsets() -> UIEdgeInsets {
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
}


enum AuxiliaryTextMenuConfig {
    static let menuMaxWidth: CGFloat = 300
    static let menuCornerRadius = CGFloat(RadiusScheme.smallRadius)
    static let arrowWidth: CGFloat = 14
    static let arrowHeight: CGFloat = 8
    static let arrowLayoutHeight: CGFloat = 8
    static let cellWidth: CGFloat = 50
    static let cellHeight: CGFloat = 58
    static let pagePadding: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let rowDividerHeight: CGFloat = 1
    static let rowDividerSideMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let rowDividerAlpha: CGFloat = 140.0 / 255.0
    static let maxButtonsPerRow: Int = 5
    static let minMenuWidth: CGFloat = 60
    static let iconSize: CGFloat = 20
    static let iconTopMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let iconTitleSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let titleBottomMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let bubbleSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    static let screenPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    static let menuAppearDuration: TimeInterval = 0.2
    static let menuAppearScale: CGFloat = 0.95

    static var arrowClampMargin: CGFloat { menuCornerRadius + arrowWidth / 2 }

    static func calculateMenuDimensions(buttonCount: Int) -> (width: CGFloat, height: CGFloat) {
        let rows = calculateRowCount(buttonCount: buttonCount)
        let columnCount = max(1, min(buttonCount, maxButtonsPerRow))
        let cardWidth = cellWidth * CGFloat(columnCount) + pagePadding * 2
        let menuWidth = max(minMenuWidth, min(cardWidth, menuMaxWidth))
        let contentHeight = pagePadding * 2 + cellHeight * CGFloat(rows) + rowDividerHeight * CGFloat(max(0, rows - 1))
        return (menuWidth, contentHeight + arrowLayoutHeight)
    }

    static func calculateRowCount(buttonCount: Int) -> Int {
        return (buttonCount + maxButtonsPerRow - 1) / maxButtonsPerRow
    }
}


struct AuxiliaryTextMenuView: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject var menuManager: AuxiliaryTextMenuManager

    var body: some View {
        if menuManager.menuData.isShowing && !menuManager.menuData.actions.isEmpty {
            GeometryReader { geometry in
                let position = calculateMenuPosition(screenGeometry: geometry)

                ZStack {
                    AuxiliaryMenuShape(
                        width: position.width,
                        height: position.height,
                        arrowX: position.arrowX,
                        showAbove: position.showAbove
                    )

                    AuxiliaryMenuContent(
                        width: position.width,
                        showAbove: position.showAbove,
                        actions: menuManager.menuData.actions,
                        menuManager: menuManager
                    )
                }
                .frame(width: position.width, height: position.height)
                .position(x: position.x, y: position.y)
            }
            .edgesIgnoringSafeArea(.all)
            .transition(.scale(scale: AuxiliaryTextMenuConfig.menuAppearScale).combined(with: .opacity))
            .animation(.easeOut(duration: AuxiliaryTextMenuConfig.menuAppearDuration), value: menuManager.menuData.isShowing)
        }
    }

    private func calculateMenuPosition(screenGeometry: GeometryProxy) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, arrowX: CGFloat, showAbove: Bool) {
        let buttonCount = menuManager.menuData.actions.count
        let dimensions = AuxiliaryTextMenuConfig.calculateMenuDimensions(buttonCount: buttonCount)
        let menuWidth = dimensions.width
        let menuHeight = dimensions.height

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        let globalBubbleFrame = menuManager.menuData.bubbleFrame
        let localBubbleFrame = CGRect(
            x: globalBubbleFrame.minX - screenGeometry.frame(in: .global).minX,
            y: globalBubbleFrame.minY - screenGeometry.frame(in: .global).minY,
            width: globalBubbleFrame.width,
            height: globalBubbleFrame.height
        )

        let bubbleCenterX = localBubbleFrame.midX
        var menuX = bubbleCenterX
        var arrowOffsetX: CGFloat = 0

        let menuHalfWidth = menuWidth / 2
        let screenPadding = AuxiliaryTextMenuConfig.screenPadding

        if menuX - menuHalfWidth < screenPadding {
            menuX = screenPadding + menuHalfWidth
            arrowOffsetX = bubbleCenterX - menuX
        } else if menuX + menuHalfWidth > screenWidth - screenPadding {
            menuX = screenWidth - screenPadding - menuHalfWidth
            arrowOffsetX = bubbleCenterX - menuX
        }

        let safeArrowOffsetX = max(
            -menuHalfWidth + AuxiliaryTextMenuConfig.arrowClampMargin,
            min(arrowOffsetX, menuHalfWidth - AuxiliaryTextMenuConfig.arrowClampMargin)
        )

        let shouldShowAbove = menuManager.menuData.shouldShowAbove
        let menuY: CGFloat

        if shouldShowAbove {
            menuY = localBubbleFrame.minY - AuxiliaryTextMenuConfig.bubbleSpacing - menuHeight / 2
        } else {
            menuY = localBubbleFrame.maxY + AuxiliaryTextMenuConfig.bubbleSpacing + menuHeight / 2
        }

        return (menuX, menuY, menuWidth, menuHeight, safeArrowOffsetX, shouldShowAbove)
    }
}


struct AuxiliaryMenuShape: View {
    @EnvironmentObject var themeState: ThemeState
    let width: CGFloat
    let height: CGFloat
    let arrowX: CGFloat
    let showAbove: Bool

    var body: some View {
        AuxiliaryMenuShapePath(
            width: width,
            height: height,
            arrowX: arrowX,
            showAbove: showAbove
        )
        .fill(themeState.colors.dropdownColorDefault)
        .shadow(color: Colors.Black1.opacity(0.2), radius: 8, x: 0, y: 2)
        .zIndex(30)
    }
}

struct AuxiliaryMenuShapePath: Shape {
    let width: CGFloat
    let height: CGFloat
    let arrowX: CGFloat
    let showAbove: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = AuxiliaryTextMenuConfig.menuCornerRadius
        let arrowWidth: CGFloat = AuxiliaryTextMenuConfig.arrowWidth
        let arrowHeight: CGFloat = AuxiliaryTextMenuConfig.arrowHeight
        let centerX = rect.width / 2
        let arrowCenterX = centerX + arrowX
        let arrowLeft = arrowCenterX - arrowWidth / 2
        let arrowRight = arrowCenterX + arrowWidth / 2

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


struct AuxiliaryMenuContent: View {
    let width: CGFloat
    let showAbove: Bool
    let actions: [AuxiliaryTextMenuAction]
    @ObservedObject var menuManager: AuxiliaryTextMenuManager

    var body: some View {
        VStack(spacing: 0) {
            if !showAbove {
                Spacer().frame(height: AuxiliaryTextMenuConfig.arrowHeight)
            }

            AuxiliaryMenuButtonGrid(
                width: width,
                actions: actions,
                menuManager: menuManager
            )

            if showAbove {
                Spacer().frame(height: AuxiliaryTextMenuConfig.arrowHeight)
            }
        }
        .zIndex(35)
    }
}


struct AuxiliaryMenuButtonGrid: View {
    @EnvironmentObject var themeState: ThemeState
    let width: CGFloat
    let actions: [AuxiliaryTextMenuAction]
    @ObservedObject var menuManager: AuxiliaryTextMenuManager

    var body: some View {
        let buttonCount = actions.count
        let rowCount = AuxiliaryTextMenuConfig.calculateRowCount(buttonCount: buttonCount)

        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                buttonRow(for: rowIndex)
                if rowIndex < rowCount - 1 {
                    Rectangle()
                        .fill(themeState.colors.strokeColorPrimary.opacity(AuxiliaryTextMenuConfig.rowDividerAlpha))
                        .frame(height: AuxiliaryTextMenuConfig.rowDividerHeight)
                        .padding(.horizontal, AuxiliaryTextMenuConfig.rowDividerSideMargin)
                }
            }
        }
        .padding(AuxiliaryTextMenuConfig.pagePadding)
    }

    private func buttonRow(for rowIndex: Int) -> some View {
        let maxButtonsPerRow = AuxiliaryTextMenuConfig.maxButtonsPerRow
        let startIndex = rowIndex * maxButtonsPerRow
        let endIndex = min(startIndex + maxButtonsPerRow, actions.count)
        let rowActions = Array(actions[startIndex..<endIndex])

        return AuxiliaryMenuButtonRow(
            actions: rowActions,
            menuManager: menuManager
        )
    }
}

struct AuxiliaryMenuButtonRow: View {
    let actions: [AuxiliaryTextMenuAction]
    @ObservedObject var menuManager: AuxiliaryTextMenuManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<actions.count, id: \.self) { index in
                AuxiliaryMenuButton(
                    iconName: actions[index].iconName,
                    systemIconFallback: actions[index].systemIconFallback,
                    label: actions[index].label
                ) {
                    menuManager.hideMenu()
                    actions[index].action()
                }
            }
        }
    }
}


struct AuxiliaryMenuButton: View {
    @EnvironmentObject var themeState: ThemeState
    let iconName: String
    let systemIconFallback: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AuxiliaryTextMenuConfig.iconTitleSpacing) {
                if UIImage(named: iconName, in: AtomicXChatResources.resourceBundle, compatibleWith: nil) != nil {
                    Image(iconName, bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: AuxiliaryTextMenuConfig.iconSize, height: AuxiliaryTextMenuConfig.iconSize)
                        .foregroundColor(themeState.colors.textColorPrimary)
                } else {
                    Image(systemName: systemIconFallback)
                        .font(FontScheme.body3Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                Text(label)
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.top, AuxiliaryTextMenuConfig.iconTopMargin)
            .padding(.bottom, AuxiliaryTextMenuConfig.titleBottomMargin)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: AuxiliaryTextMenuConfig.cellWidth, height: AuxiliaryTextMenuConfig.cellHeight)
    }
}
