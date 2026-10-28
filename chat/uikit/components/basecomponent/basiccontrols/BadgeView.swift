import SwiftUI

public enum BadgeType {
    case text
    case dot
}

public struct BadgeView: View {
    @EnvironmentObject var themeState: ThemeState
    let text: String?
    let type: BadgeType

    public init(text: String? = nil, type: BadgeType = .text) {
        self.text = text
        self.type = type
    }

    private var colors: SemanticColorScheme {
        themeState.colors
    }

    public var body: some View {
        if text?.isEmpty != false || type == .dot {
            Circle()
                .fill(colors.textColorError)
                .frame(width: 8, height: 8)
        } else {
            Text(text!)
                .font(themeState.fonts.caption3Medium)
                .foregroundColor(colors.textColorButton)
                .lineLimit(1)
                .padding(.horizontal, CGFloat(SpacingScheme.iconTextSpacing))
                .frame(height: 16)
                .background(colors.textColorError)
                .cornerRadius(CGFloat(RadiusScheme.smallRadius))
        }
    }
}
