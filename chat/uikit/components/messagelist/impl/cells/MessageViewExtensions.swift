import AtomicXCore
import SwiftUI
import UIKit

struct BubbleLongPressBridge: UIViewRepresentable {
    let bubbleFrame: CGRect
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> BubbleLongPressAnchorView {
        let view = BubbleLongPressAnchorView()
        view.isUserInteractionEnabled = false
        view.bubbleFrame = bubbleFrame
        view.onLongPress = onLongPress
        return view
    }

    func updateUIView(_ uiView: BubbleLongPressAnchorView, context: Context) {
        uiView.bubbleFrame = bubbleFrame
        uiView.onLongPress = onLongPress
    }
}

final class BubbleLongPressAnchorView: UIView, UIGestureRecognizerDelegate {
    var bubbleFrame: CGRect = .null
    var onLongPress: (() -> Void)?
    private weak var recognizer: UILongPressGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let old = recognizer {
            old.view?.removeGestureRecognizer(old)
            recognizer = nil
        }
        guard let window = window else { return }
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.5
        lp.delegate = self
        window.addGestureRecognizer(lp)
        recognizer = lp
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let window, !bubbleFrame.isNull, !bubbleFrame.isEmpty else { return false }
        return bubbleFrame.insetBy(dx: -2, dy: -2).contains(gestureRecognizer.location(in: window))
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            onLongPress?()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension String {
    func imageExists() -> Bool {
        return UIImage(named: self) != nil
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

private struct BubbleFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ViewPositionKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TargetMessageIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct IsInMergedDetailViewKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var locateMessageID: String? {
        get { self[TargetMessageIDKey.self] }
        set { self[TargetMessageIDKey.self] = newValue }
    }

    var isInMergedDetailView: Bool {
        get { self[IsInMergedDetailViewKey.self] }
        set { self[IsInMergedDetailViewKey.self] = newValue }
    }

    var messageListBounds: CGRect {
        get { self[MessageListBoundsKey.self] }
        set { self[MessageListBoundsKey.self] = newValue }
    }
}

private struct MessageListBoundsKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

extension CGFloat {
    func clamped(min: CGFloat, max: CGFloat) -> CGFloat {
        if self < min { return min }
        if self > max { return max }
        return self
    }
}

extension Font {
    func toUIFont() -> UIFont {
        switch self {
        case .largeTitle: return UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title: return UIFont.preferredFont(forTextStyle: .title1)
        case .headline: return UIFont.preferredFont(forTextStyle: .headline)
        case .body: return UIFont.preferredFont(forTextStyle: .body)
        default: return UIKitFontScheme.caption1Regular
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MessageViewModifiers: ViewModifier {
    @Binding var messageBubbleFrame: CGRect
    @Binding var longPressed: Bool
    @Environment(\.messageCustomActions) var customActions: [MessageCustomAction]
    @Environment(\.messageListBounds) var messageListBounds: CGRect
    let menuManager: MessageMenuManager
    let message: MessageInfo
    let style: MessageListConfigProtocol

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ViewPositionKey.self) { frames in
                if let frame = frames.first {
                    messageBubbleFrame = frame
                }
            }
            .onTapGesture {}
    }
}

struct LocateFlashOverlay: ViewModifier {
    @EnvironmentObject var themeState: ThemeState
    let shouldHighlight: Bool
    let isSelf: Bool
    let radii: [CGFloat]

    @State private var flashOn = false
    @State private var generation = 0

    private static let segment: TimeInterval = 0.26
    private static let flashCount = 3

    private var isDarkBubble: Bool {
        let bubbleUIColor = UIColor(isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        bubbleUIColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) < 0.5
    }

    private var flashColor: Color {
        let warn = UIColor(themeState.colors.textColorWarning)
        var wr: CGFloat = 0, wg: CGFloat = 0, wb: CGFloat = 0, wa: CGFloat = 0
        warn.getRed(&wr, green: &wg, blue: &wb, alpha: &wa)
        let ratio: CGFloat = isDarkBubble ? 0.4 : 0
        return Color(UIColor(red: wr + (1 - wr) * ratio, green: wg + (1 - wg) * ratio, blue: wb + (1 - wb) * ratio, alpha: wa))
    }

    private var flashMaxAlpha: Double {
        isDarkBubble ? 128.0 / 255.0 : 72.0 / 255.0
    }

    func body(content: Content) -> some View {
        content.overlay(
            BubbleView(backgroundColor: flashColor, radii: radii) { EmptyView() }
                .opacity(flashOn ? flashMaxAlpha : 0)
                .allowsHitTesting(false)
        )
        .onAppear { if shouldHighlight { startFlashing() } }
        .onChange(of: shouldHighlight) { highlighted in
            if highlighted { startFlashing() }
        }
    }

    private func startFlashing() {
        generation += 1
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.generation == gen else { return }
            var step = 0
            Timer.scheduledTimer(withTimeInterval: Self.segment, repeats: true) { timer in
                guard self.generation == gen else { timer.invalidate(); return }
                step += 1
                if step > Self.flashCount * 2 {
                    timer.invalidate()
                    withAnimation(.linear(duration: Self.segment)) { self.flashOn = false }
                    return
                }
                withAnimation(.linear(duration: Self.segment)) {
                    self.flashOn = step % 2 == 1
                }
            }
        }
    }
}

struct BubbleBackground: ViewModifier {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    @Environment(\.messageListConfigProtocol) private var config: MessageListConfigProtocol
    let isSelf: Bool
    let isLeft: Bool
    let shouldHighlight: Bool
    let message: MessageInfo
    var isReactionContainer: Bool = false

    private static let stylerCornerRadius = CGFloat(RadiusScheme.alertRadius)

    private var defaultRadii: [CGFloat] {
        let compactRadius = CGFloat(RadiusScheme.tipsRadius)
        return isLeft ? [compactRadius, Self.stylerCornerRadius, Self.stylerCornerRadius, Self.stylerCornerRadius] : [Self.stylerCornerRadius, compactRadius, Self.stylerCornerRadius, Self.stylerCornerRadius]
    }

    private func resolvedRadii(_ appearance: MessageBubbleAppearance?) -> [CGFloat] {
        guard let cr = appearance?.cornerRadius else { return defaultRadii }
        return [
            cr.topLeft ?? Self.stylerCornerRadius,
            cr.topRight ?? Self.stylerCornerRadius,
            cr.bottomRight ?? Self.stylerCornerRadius,
            cr.bottomLeft ?? Self.stylerCornerRadius
        ]
    }

    @ViewBuilder
    private func bubbleFill(_ appearance: MessageBubbleAppearance?, radii: [CGFloat]) -> some View {
        let shape = RoundedCornerShape(radii: radii)
        switch appearance?.background {
        case .color(let color):
            shape.fill(Color(uiColor: color))
        case .gradient(let colors, let startPoint, let endPoint):
            shape.fill(
                LinearGradient(
                    gradient: Gradient(colors: colors.map { Color(uiColor: $0) }),
                    startPoint: UnitPoint(x: startPoint.x, y: startPoint.y),
                    endPoint: UnitPoint(x: endPoint.x, y: endPoint.y)
                )
            )
        case .image(let image):
            shape.fill(Color.clear)
                .background(Image(uiImage: image).resizable().scaledToFill())
                .clipShape(shape)
        case nil:
            BubbleView(
                backgroundColor: isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal,
                radii: radii
            ) {
                EmptyView()
            }
        }
    }

    func body(content: Content) -> some View {
        // 有回应条时由外层绘制完整气泡，内层不再重复绘制。
        let suppressOwnBubble = !isReactionContainer && !message.reactionList.isEmpty
        let appearance = config.resolvedBubbleAppearance(isSelf: isSelf, isLeft: isLeft)
        let radii = resolvedRadii(appearance)
        return content
            .padding(appearance?.contentInsets.map { EdgeInsets(top: $0.top, leading: $0.left, bottom: $0.bottom, trailing: $0.right) } ?? EdgeInsets())
            .frame(
                minWidth: appearance?.minimumSize?.width,
                minHeight: appearance?.minimumSize?.height
            )
            .background(
                Group {
                    if !suppressOwnBubble {
                        bubbleFill(appearance, radii: radii)
                            .overlay(
                                Group {
                                    if let stroke = appearance?.stroke {
                                        RoundedCornerShape(radii: radii)
                                            .stroke(Color(uiColor: stroke.color), lineWidth: stroke.width)
                                    }
                                }
                            )
                    }
                }
            )
            .modifier(LocateFlashOverlay(
                // 回应容器统一高亮整个气泡，内层不再单独闪烁。
                shouldHighlight: shouldHighlight && !suppressOwnBubble,
                isSelf: isSelf,
                radii: radii
            ))
    }
}

struct ReactionBubbleContainer: ViewModifier {
    enum Kind {
        case bubble
        case media
        case mergedCard
    }

    @EnvironmentObject var themeState: ThemeState
    let kind: Kind
    let isSelf: Bool
    let isLeft: Bool
    let shouldHighlight: Bool
    let message: MessageInfo

    @ViewBuilder
    func body(content: Content) -> some View {
        switch kind {
        case .mergedCard:
            content
                .background(themeState.colors.bgColorDialog)
                .cornerRadius(CGFloat(RadiusScheme.alertRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.alertRadius))
                        .stroke(themeState.colors.strokeColorPrimary, lineWidth: 1)
                )
        case .bubble, .media:
            content.modifier(BubbleBackground(
                isSelf: isSelf,
                isLeft: isLeft,
                shouldHighlight: shouldHighlight,
                message: message,
                isReactionContainer: true
            ))
        }
    }
}

extension View {
    func bubbleBackground(isSelf: Bool, isLeft: Bool, shouldHighlight: Bool = false, message: MessageInfo) -> some View {
        modifier(BubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message))
    }

    func flippedForInvertedList() -> some View {
        self.scaleEffect(x: 1, y: -1, anchor: .center)
    }
}
