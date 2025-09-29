import AtomicXCore
import SwiftUI

extension String {
    func imageExists() -> Bool {
        return UIImage(named: self) != nil
    }
}

struct TriangleShape: Shape {
    public func path(in rect: CGRect) -> Path {
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

extension EnvironmentValues {
    var locateMessageID: String? {
        get { self[TargetMessageIDKey.self] }
        set { self[TargetMessageIDKey.self] = newValue }
    }
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
        default: return UIFont.systemFont(ofSize: 16)
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
            .onLongPressGesture(minimumDuration: 0.5) {
                longPressed = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                menuManager.showMenu(for: message, bubbleFrame: messageBubbleFrame)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    longPressed = false
                }
            }
    }
}

struct BubbleBackground: ViewModifier {
    @EnvironmentObject var themeState: ThemeState
    @State private var isHighlighted: Bool = false
    @State private var highlightTimer: Timer?
    let isSelf: Bool
    let isLeft: Bool
    let shouldHighlight: Bool

    func body(content: Content) -> some View {
        content.background(
            Group {
                Bubble(
                    backgroundColor: isHighlighted ? Color.yellow : isSelf ? themeState.colors.bgColorBubbleOwn : themeState.colors.bgColorBubbleReciprocal,
                    radii: isLeft ? [18, 18, 18, 0] : [18, 18, 0, 18]
                ) {
                    EmptyView()
                }
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            }
        )
        .onAppear {
            if shouldHighlight {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startBlinkingAnimation()
                }
            }
        }
    }

    private func startBlinkingAnimation() {
        highlightTimer?.invalidate()
        var blinkCount = 0
        let maxBlinks = 6
        isHighlighted = true
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            blinkCount += 1
            DispatchQueue.main.async {
                self.isHighlighted.toggle()
            }
            if blinkCount >= maxBlinks {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.isHighlighted = false
                }
            }
        }
    }
}

extension View {
    func bubbleBackground(isSelf: Bool, isLeft: Bool, shouldHighlight: Bool = false) -> some View {
        modifier(BubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight))
    }
}
