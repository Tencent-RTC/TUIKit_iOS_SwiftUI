import SwiftUI

public struct PopMenuInfo {
    public let icon: String?
    public let title: String
    public let onClick: () -> Void
    public init(icon: String? = nil, title: String, onClick: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.onClick = onClick
    }
}

public struct PopMenuView: View {
    @EnvironmentObject var themeState: ThemeState
    let menuItems: [PopMenuInfo]

    private static let cornerRadius = CGFloat(RadiusScheme.smallRadius)
    private static let arrowWidth: CGFloat = 12
    private static let arrowHeight: CGFloat = 6
    public static let defaultArrowCenterXFromTrailing: CGFloat = 20

    let arrowCenterXFromTrailing: CGFloat

    public init(menuItems: [PopMenuInfo], arrowCenterXFromTrailing: CGFloat = defaultArrowCenterXFromTrailing) {
        self.menuItems = menuItems
        self.arrowCenterXFromTrailing = arrowCenterXFromTrailing
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                Button(action: item.onClick) {
                    PopMenuRow(icon: item.icon, title: item.title)
                }
                .buttonStyle(PopMenuRowButtonStyle())
                if index < menuItems.count - 1 {
                    Rectangle()
                        .fill(themeState.colors.strokeColorSecondary)
                        .frame(height: 1)
                        .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                }
            }
        }
        .fixedSize()
        .padding(.top, Self.arrowHeight)
        .background(
            BubbleMenuShape(
                cornerRadius: Self.cornerRadius,
                arrowWidth: Self.arrowWidth,
                arrowHeight: Self.arrowHeight,
                arrowCenterXFromTrailing: arrowCenterXFromTrailing
            )
            .fill(themeState.colors.bgColorDialog)
        )
        .compositingGroup()
        .shadow(color: Colors.Black1.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

private struct PopMenuRow: View {
    @EnvironmentObject var themeState: ThemeState
    let icon: String?
    let title: String

    var body: some View {
        HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
            if let icon = icon {
                Image(icon, bundle: AtomicXChatResources.resourceBundle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
            Text(title)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct PopMenuRowButtonStyle: ButtonStyle {
    @EnvironmentObject var themeState: ThemeState
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? themeState.colors.textColorPrimary.opacity(0.1)
                    : Color.clear
            )
    }
}

private struct BubbleMenuShape: Shape {
    var cornerRadius: CGFloat
    var arrowWidth: CGFloat
    var arrowHeight: CGFloat
    var arrowCenterXFromTrailing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyRect = CGRect(x: 0, y: arrowHeight, width: rect.width, height: rect.height - arrowHeight)
        let halfArrow = arrowWidth / 2
        let cx = min(
            max(rect.width - arrowCenterXFromTrailing, cornerRadius + halfArrow),
            rect.width - cornerRadius - halfArrow
        )
        path.move(to: CGPoint(x: cx - halfArrow, y: arrowHeight))
        path.addLine(to: CGPoint(x: cx, y: 0))
        path.addLine(to: CGPoint(x: cx + halfArrow, y: arrowHeight))
        path.closeSubpath()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}


extension View {
    // 直接回写全局锚点，避免 TabView/overlay 丢失偏好值，并兼容 iOS 15。
    func popMenuAnchor(_ anchor: Binding<CGRect>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { anchor.wrappedValue = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { anchor.wrappedValue = $0 }
            }
        )
    }
}

struct AnchoredPopMenuOverlay: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var isPresented: Bool
    let anchor: CGRect
    let items: [PopMenuInfo]

    private static let screenMargin = CGFloat(SpacingScheme.smallSpacing)
    private static let anchorGap = CGFloat(SpacingScheme.iconTextSpacing)
    private static let minContentWidth: CGFloat = 72
    private static let cornerRadius = CGFloat(RadiusScheme.smallRadius)
    private static let arrowWidth: CGFloat = 12
    private static let rowHorizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let iconSize: CGFloat = 20
    private static let iconTextSpacing = CGFloat(SpacingScheme.smallSpacing)

    var body: some View {
        GeometryReader { overlayGeo in
            if isPresented {
                let width = Self.contentWidth(for: items, maxWidth: overlayGeo.size.width - Self.screenMargin * 2)
                let bubbleX = overlayGeo.size.width - width - Self.screenMargin
                let arrowFromTrailing = Self.clampedArrowFromTrailing(anchorMidX: anchor.midX, bubbleX: bubbleX, width: width)
                let localTop = anchor.maxY + Self.anchorGap - overlayGeo.frame(in: .global).minY
                ZStack(alignment: .topTrailing) {
                    // 使用 UIKit 接收任意 touch-down，避免 SwiftUI 拖动手势被底层滚动容器抢占。
                    AnyTouchDismissBackdrop { isPresented = false }
                    PopMenuView(menuItems: items.map { item in
                        PopMenuInfo(icon: item.icon, title: item.title) {
                            isPresented = false
                            item.onClick()
                        }
                    }, arrowCenterXFromTrailing: arrowFromTrailing)
                    .frame(width: width)
                    .padding(.trailing, Self.screenMargin)
                    .padding(.top, max(0, localTop))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isPresented)
    }

    private static func contentWidth(for items: [PopMenuInfo], maxWidth: CGFloat) -> CGFloat {
        let font = UIKitFontScheme.caption1Regular
        var maxRow: CGFloat = minContentWidth
        for item in items {
            let textWidth = ceil((item.title as NSString).size(withAttributes: [.font: font]).width)
            var row = rowHorizontalPadding * 2 + textWidth
            if item.icon != nil {
                row += iconSize + iconTextSpacing
            }
            maxRow = max(maxRow, row)
        }
        return min(maxRow, maxWidth)
    }

    private static func clampedArrowFromTrailing(anchorMidX: CGFloat, bubbleX: CGFloat, width: CGFloat) -> CGFloat {
        let raw = width - (anchorMidX - bubbleX)
        let minV = cornerRadius + arrowWidth / 2
        let maxV = width - cornerRadius - arrowWidth / 2
        return min(max(raw, minV), max(minV, maxV))
    }
}


private struct AnyTouchDismissBackdrop: UIViewRepresentable {
    let onTouchDown: () -> Void

    func makeUIView(context: Context) -> TouchDownCatcherView {
        let view = TouchDownCatcherView()
        view.onTouchDown = onTouchDown
        return view
    }

    func updateUIView(_ uiView: TouchDownCatcherView, context: Context) {
        uiView.onTouchDown = onTouchDown
    }
}

private final class TouchDownCatcherView: UIView {
    var onTouchDown: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchDown?()
        super.touchesBegan(touches, with: event)
    }
}
