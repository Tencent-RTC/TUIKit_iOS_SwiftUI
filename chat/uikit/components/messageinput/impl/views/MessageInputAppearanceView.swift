import SwiftUI
import UIKit

internal enum MessageInputAppearanceLayout {
    private static let minimumTitleWidth: CGFloat = 1
    private static let two: CGFloat = 2

    internal static func dimension(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite, value > 0 else { return fallback }
        return value
    }

    internal static func padding(_ value: CGFloat?, fallback: CGFloat = 0) -> CGFloat {
        guard let value, value.isFinite, value >= 0 else { return fallback }
        return value
    }

    internal static func cornerRadius(_ value: CGFloat?, fallback: CGFloat, size: CGSize) -> CGFloat {
        guard let value, value.isFinite else { return fallback }
        if value == MessageInputButtonAppearance.cornerRadiusPill {
            return min(size.width, size.height) / two
        }
        return max(0, value)
    }

    internal static func buttonSize(_ appearance: MessageInputButtonAppearance?, fallback: CGFloat, supportsTitle: Bool = false) -> CGSize {
        var width = dimension(appearance?.width, fallback: fallback)
        let height = dimension(appearance?.height, fallback: fallback)
        if supportsTitle, appearance?.width == nil, let title = appearance?.title {
            let font = UIFont.systemFont(ofSize: dimension(appearance?.titleSize, fallback: UIKitFontScheme.caption2Regular.pointSize))
            let horizontalPadding = padding(appearance?.horizontalPadding)
            width = max(minimumTitleWidth, ceil((title as NSString).size(withAttributes: [.font: font]).width) + horizontalPadding * two)
        }
        return CGSize(width: width, height: height)
    }
}

internal struct MessageInputAppearanceBackground: View {
    internal let fill: MessageInputFill?
    internal var fallback: Color = .clear
    internal var cornerRadius: CGFloat? = nil
    internal var defaultCornerRadius: CGFloat = 0
    private static let minimumGradientColorCount = 2
    private static let midpoint: CGFloat = 0.5

    internal var body: some View {
        GeometryReader { geometry in
            fillView
                .clipShape(RoundedRectangle(cornerRadius: MessageInputAppearanceLayout.cornerRadius(
                    cornerRadius, fallback: defaultCornerRadius, size: geometry.size
                )))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var fillView: some View {
        if let fill {
            switch fill {
            case .none:
                Color.clear
            case let .color(color):
                Color(color)
            case let .gradient(colors, direction):
                if colors.count >= Self.minimumGradientColorCount {
                    LinearGradient(colors: colors.map { Color($0) }, startPoint: points(direction).start, endPoint: points(direction).end)
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private func points(_ direction: MessageInputGradientDirection) -> (start: UnitPoint, end: UnitPoint) {
        switch direction {
        case .topBottom: return (UnitPoint(x: Self.midpoint, y: 0), UnitPoint(x: Self.midpoint, y: 1))
        case .bottomTop: return (UnitPoint(x: Self.midpoint, y: 1), UnitPoint(x: Self.midpoint, y: 0))
        case .leftRight: return (UnitPoint(x: 0, y: Self.midpoint), UnitPoint(x: 1, y: Self.midpoint))
        case .rightLeft: return (UnitPoint(x: 1, y: Self.midpoint), UnitPoint(x: 0, y: Self.midpoint))
        case .topLeftBottomRight: return (UnitPoint(x: 0, y: 0), UnitPoint(x: 1, y: 1))
        case .bottomRightTopLeft: return (UnitPoint(x: 1, y: 1), UnitPoint(x: 0, y: 0))
        }
    }
}

internal struct MessageInputAppearanceButtonLabel: View {
    internal let appearance: MessageInputButtonAppearance?
    internal let active: Bool
    internal let defaultIconName: String
    internal var systemIcon = false
    internal let defaultTint: Color
    internal var defaultFill: Color = .clear
    internal var defaultCornerRadius: CGFloat = 0
    internal var supportsTitle = false
    private static let defaultSize: CGFloat = 28

    internal var body: some View {
        let size = MessageInputAppearanceLayout.buttonSize(appearance, fallback: Self.defaultSize, supportsTitle: supportsTitle)
        content(size: size)
            .frame(width: size.width, height: size.height)
            .background(MessageInputAppearanceBackground(fill: appearance?.fill, fallback: defaultFill,
                cornerRadius: appearance?.cornerRadius, defaultCornerRadius: defaultCornerRadius))
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if supportsTitle, let title = appearance?.title {
            Text(title)
                .font(.system(size: MessageInputAppearanceLayout.dimension(appearance?.titleSize, fallback: UIKitFontScheme.caption2Regular.pointSize)))
                .foregroundColor(appearance?.titleColor.map { Color($0) } ?? defaultTint)
                .padding(.horizontal, MessageInputAppearanceLayout.padding(appearance?.horizontalPadding))
                .lineLimit(1)
        } else {
            icon
                .foregroundColor(appearance?.iconTint.map { Color($0) } ?? defaultTint)
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private var icon: some View {
        let customIcon = active ? appearance?.activeIcon ?? appearance?.icon : appearance?.icon
        if let customIcon {
            resizedIcon(Image(uiImage: customIcon))
        } else if systemIcon {
            if let iconSize = appearance?.iconSize, iconSize.isFinite, iconSize > 0 {
                resizedIcon(Image(systemName: defaultIconName))
            } else {
                Image(systemName: defaultIconName).font(FontScheme.caption2Bold)
            }
        } else {
            resizedIcon(Image(defaultIconName, bundle: AtomicXChatResources.resourceBundle))
        }
    }

    private func resizedIcon(_ image: Image) -> some View {
        let size = MessageInputAppearanceLayout.buttonSize(appearance, fallback: Self.defaultSize)
        let glyphSize = min(MessageInputAppearanceLayout.dimension(appearance?.iconSize, fallback: Self.defaultSize), min(size.width, size.height))
        return image.resizable().renderingMode(.template).scaledToFit().frame(width: glyphSize, height: glyphSize)
    }
}
