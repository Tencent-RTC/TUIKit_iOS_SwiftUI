import AtomicXCore
import SwiftUI

// MARK: - ASR Display Manager (In-Memory, Not Persisted)

class AsrDisplayManager: ObservableObject {
    // Key: messageID, stores expanded message IDs
    // Default behavior: ASR bubble is hidden (not expanded)
    // When user triggers voice-to-text conversion, add messageID to this set to show bubble
    // When user hides ASR bubble, remove messageID from this set
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

// MARK: - Translation Display Manager (In-Memory, Not Persisted)

class TranslationDisplayManager: ObservableObject {
    // Key: messageID, stores expanded message IDs
    // Default behavior: translation bubble is hidden (not expanded)
    // When user triggers translation, add messageID to this set to show bubble
    // When user hides translation, remove messageID from this set
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

// MARK: - Environment Keys for Display Managers

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

// MARK: - Menu Action

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

// MARK: - Menu Data

struct AuxiliaryTextMenuData {
    var isShowing: Bool = false
    var bubbleFrame: CGRect = .zero
    var shouldShowAbove: Bool = true
    var actions: [AuxiliaryTextMenuAction] = []
}

// MARK: - Menu Manager

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

// MARK: - Menu Config

enum AuxiliaryTextMenuConfig {
    static let menuHeight: CGFloat = 80
    static let menuMaxWidth: CGFloat = 300
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
        return (buttonCount + maxButtonsPerRow - 1) / maxButtonsPerRow
    }
}

// MARK: - Menu View

struct AuxiliaryTextMenuView: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject var menuManager: AuxiliaryTextMenuManager
    
    var body: some View {
        if menuManager.menuData.isShowing && !menuManager.menuData.actions.isEmpty {
            GeometryReader { geometry in
                let position = calculateMenuPosition(screenGeometry: geometry)
                
                ZStack {
                    // Menu shape with arrow
                    AuxiliaryMenuShape(
                        width: position.width,
                        height: position.height,
                        arrowX: position.arrowX,
                        showAbove: position.showAbove
                    )
                    
                    // Menu content
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
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: menuManager.menuData.isShowing)
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
        
        // Calculate menu X position (centered on bubble)
        let bubbleCenterX = localBubbleFrame.midX
        var menuX = bubbleCenterX
        var arrowOffsetX: CGFloat = 0
        
        let menuHalfWidth = menuWidth / 2
        let screenPadding: CGFloat = 20
        
        if menuX - menuHalfWidth < screenPadding {
            menuX = screenPadding + menuHalfWidth
            arrowOffsetX = bubbleCenterX - menuX
        } else if menuX + menuHalfWidth > screenWidth - screenPadding {
            menuX = screenWidth - screenPadding - menuHalfWidth
            arrowOffsetX = bubbleCenterX - menuX
        }
        
        // Clamp arrow offset
        let safeArrowOffsetX = max(
            -menuHalfWidth + AuxiliaryTextMenuConfig.arrowMinMargin,
            min(arrowOffsetX, menuHalfWidth - AuxiliaryTextMenuConfig.arrowMinMargin)
        )
        
        // Calculate menu Y position
        let shouldShowAbove = menuManager.menuData.shouldShowAbove
        let menuY: CGFloat
        
        if shouldShowAbove {
            menuY = localBubbleFrame.minY - AuxiliaryTextMenuConfig.menuBubbleSpacing - menuHeight / 2
        } else {
            menuY = localBubbleFrame.maxY + AuxiliaryTextMenuConfig.menuBubbleSpacing + menuHeight / 2
        }
        
        return (menuX, menuY, menuWidth, menuHeight, safeArrowOffsetX, shouldShowAbove)
    }
}

// MARK: - Menu Shape

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
        .fill(themeState.colors.floatingColorDefault)
        .shadow(color: themeState.colors.shadowColor, radius: 8, x: 0, y: 2)
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

// MARK: - Menu Content

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
            .padding(.top, AuxiliaryTextMenuConfig.menuContentTopPadding)
            .padding(.bottom, AuxiliaryTextMenuConfig.menuContentBottomPadding)
            
            if showAbove {
                Spacer().frame(height: AuxiliaryTextMenuConfig.arrowHeight)
            }
        }
        .padding(AuxiliaryTextMenuConfig.menuContentSidePadding)
        .zIndex(35)
    }
}

// MARK: - Button Grid

struct AuxiliaryMenuButtonGrid: View {
    let width: CGFloat
    let actions: [AuxiliaryTextMenuAction]
    @ObservedObject var menuManager: AuxiliaryTextMenuManager
    
    var body: some View {
        let buttonCount = actions.count
        let rowCount = AuxiliaryTextMenuConfig.calculateRowCount(buttonCount: buttonCount)
        
        VStack(spacing: AuxiliaryTextMenuConfig.rowSpacing) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                buttonRow(for: rowIndex)
            }
        }
    }
    
    private func buttonRow(for rowIndex: Int) -> some View {
        let maxButtonsPerRow = AuxiliaryTextMenuConfig.maxButtonsPerRow
        let startIndex = rowIndex * maxButtonsPerRow
        let endIndex = min(startIndex + maxButtonsPerRow, actions.count)
        let rowActions = Array(actions[startIndex..<endIndex])
        
        return AuxiliaryMenuButtonRow(
            width: width,
            actions: rowActions,
            menuManager: menuManager
        )
    }
}

struct AuxiliaryMenuButtonRow: View {
    let width: CGFloat
    let actions: [AuxiliaryTextMenuAction]
    @ObservedObject var menuManager: AuxiliaryTextMenuManager
    
    var body: some View {
        let sideInset = AuxiliaryTextMenuConfig.buttonSideInset
        let buttonWidth = AuxiliaryTextMenuConfig.buttonWidth
        let fixedSpacing = AuxiliaryTextMenuConfig.buttonMinSpacing
        
        HStack(spacing: 0) {
            Spacer().frame(width: sideInset)
            HStack(spacing: fixedSpacing) {
                ForEach(0..<actions.count, id: \.self) { index in
                    AuxiliaryMenuButton(
                        iconName: actions[index].iconName,
                        systemIconFallback: actions[index].systemIconFallback,
                        label: actions[index].label,
                        width: buttonWidth,
                        height: AuxiliaryTextMenuConfig.buttonHeight
                    ) {
                        menuManager.hideMenu()
                        actions[index].action()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Menu Button

struct AuxiliaryMenuButton: View {
    @EnvironmentObject var themeState: ThemeState
    let iconName: String
    let systemIconFallback: String
    let label: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AuxiliaryTextMenuConfig.iconLabelSpacing) {
                ZStack {
                    if UIImage(named: iconName, in: AtomicXChatResources.resourceBundle, compatibleWith: nil) != nil {
                        Image(iconName, bundle: AtomicXChatResources.resourceBundle)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: AuxiliaryTextMenuConfig.iconSize, height: AuxiliaryTextMenuConfig.iconSize)
                            .foregroundColor(themeState.colors.textColorLink)
                    } else {
                        Image(systemName: systemIconFallback)
                            .font(.system(size: AuxiliaryTextMenuConfig.iconSize - 2))
                            .foregroundColor(themeState.colors.textColorLink)
                    }
                }
                Text(label)
                    .font(.system(size: AuxiliaryTextMenuConfig.labelFontSize))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
        .frame(width: width, height: height)
    }
}
