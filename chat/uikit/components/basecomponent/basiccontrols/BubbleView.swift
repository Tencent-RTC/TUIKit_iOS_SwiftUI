import SwiftUI

public enum BubbleColorType {
    case filled
    case outlined
    case both
}

public struct LeftBottomSquareBubbleView<Content: View>: View {
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let content: () -> Content
    public init(backgroundColor: Color, highlightColors: [Color]? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.content = content
    }

    public var body: some View {
        BubbleView(bubbleColorType: .filled, backgroundColor: backgroundColor, highlightColors: highlightColors, radii: [CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), 0], content: content)
    }
}

public struct RightBottomSquareBubbleView<Content: View>: View {
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let content: () -> Content
    public init(backgroundColor: Color, highlightColors: [Color]? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.content = content
    }

    public var body: some View {
        BubbleView(bubbleColorType: .filled, backgroundColor: backgroundColor, highlightColors: highlightColors, radii: [CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), 0, CGFloat(RadiusScheme.largeRadius)], content: content)
    }
}

public struct AllRoundBubbleView<Content: View>: View {
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let content: () -> Content
    public init(backgroundColor: Color, highlightColors: [Color]? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.content = content
    }

    public var body: some View {
        BubbleView(bubbleColorType: .filled, backgroundColor: backgroundColor, highlightColors: highlightColors, radii: [CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius)], content: content)
    }
}

public struct LeftTopSquareBubbleView<Content: View>: View {
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let content: () -> Content
    public init(backgroundColor: Color, highlightColors: [Color]? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.content = content
    }

    public var body: some View {
        BubbleView(bubbleColorType: .filled, backgroundColor: backgroundColor, highlightColors: highlightColors, radii: [0, CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius)], content: content)
    }
}

public struct RightTopSquareBubbleView<Content: View>: View {
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let content: () -> Content
    public init(backgroundColor: Color, highlightColors: [Color]? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.content = content
    }

    public var body: some View {
        BubbleView(bubbleColorType: .filled, backgroundColor: backgroundColor, highlightColors: highlightColors, radii: [CGFloat(RadiusScheme.largeRadius), 0, CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius)], content: content)
    }
}

struct RoundedCornerShape: Shape {
    var radii: [CGFloat]
    func path(in rect: CGRect) -> Path {
        let topLeft = radii.count > 0 ? radii[0] : 0
        let topRight = radii.count > 1 ? radii[1] : 0
        let bottomRight = radii.count > 2 ? radii[2] : 0
        let bottomLeft = radii.count > 3 ? radii[3] : 0
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w - topRight, y: 0))
        path.addArc(center: CGPoint(x: w - topRight, y: topRight), radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - bottomRight))
        path.addArc(center: CGPoint(x: w - bottomRight, y: h - bottomRight), radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bottomLeft, y: h))
        path.addArc(center: CGPoint(x: bottomLeft, y: h - bottomLeft), radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        path.addArc(center: CGPoint(x: topLeft, y: topLeft), radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

public struct BubbleView<Content: View>: View {
    @EnvironmentObject var themeState: ThemeState
    public let bubbleColorType: BubbleColorType
    public let backgroundColor: Color
    public let highlightColors: [Color]?
    public let radii: [CGFloat]
    public let borderColor: Color?
    public let borderWidth: CGFloat
    public let content: () -> Content
    public init(
        bubbleColorType: BubbleColorType = .filled,
        backgroundColor: Color,
        highlightColors: [Color]? = nil,
        radii: [CGFloat] = [CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), 0],
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.bubbleColorType = bubbleColorType
        self.backgroundColor = backgroundColor
        self.highlightColors = highlightColors
        self.radii = radii
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.content = content
    }

    public var body: some View {
        let shape = RoundedCornerShape(radii: radii)
        ZStack {
            if let highlightColors = highlightColors, highlightColors.count > 1 {
                LinearGradient(gradient: Gradient(colors: highlightColors), startPoint: .top, endPoint: .bottom)
                    .clipShape(shape)
            } else {
                backgroundColor.clipShape(shape)
            }
            if bubbleColorType == .outlined || bubbleColorType == .both {
                shape.stroke(borderColor ?? themeState.colors.strokeColorPrimary, lineWidth: borderWidth)
            }
            if bubbleColorType == .both {
                shape.fill(backgroundColor)
            }
            content()
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        }
        .contentShape(shape)
        .clipped()
        .frame(minWidth: 40)
    }
}

public struct HighlightableBubbleView<Content: View>: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var isHighlighted: Bool = false
    @State private var highlightTimer: Timer?
    public let bubble: BubbleView<Content>
    public init(
        bubbleColorType: BubbleColorType = .filled,
        backgroundColor: Color,
        highlightColors: [Color]? = nil,
        radii: [CGFloat] = [CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), CGFloat(RadiusScheme.largeRadius), 0],
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.bubble = BubbleView(
            bubbleColorType: bubbleColorType,
            backgroundColor: backgroundColor,
            highlightColors: highlightColors,
            radii: radii,
            borderColor: borderColor,
            borderWidth: borderWidth,
            content: content
        )
    }

    public var body: some View {
        bubble
            .background(
                RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.smallRadius))
                    .fill(themeState.colors.textColorWarning.opacity(0.3))
                    .opacity(isHighlighted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            )
    }

    public func highlight(duration: TimeInterval = 3.0) {
        isHighlighted = true
        highlightTimer?.invalidate()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                isHighlighted = false
            }
        }
    }
}
