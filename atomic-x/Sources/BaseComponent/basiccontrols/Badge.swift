import SwiftUI

public enum BadgeType {
    case text
    case dot
}

public struct Badge: View {
    @Environment(\.colorScheme) var colorScheme
    let text: String?
    let type: BadgeType

    public init(text: String? = nil, type: BadgeType = .text) {
        self.text = text
        self.type = type
    }

    private var colors: SemanticColorScheme {
        return colorScheme == .dark ? DarkSemanticScheme : LightSemanticScheme
    }

    public var body: some View {
        if text?.isEmpty != false || type == .dot {
            Circle()
                .fill(colors.textColorError)
                .frame(width: 8, height: 8)
        } else {
            Text(text!)
                .font(.system(size: 12, weight: .semibold)) // fontWeight.W600
                .foregroundColor(colors.textColorButton)
                .lineLimit(1)
                .padding(.horizontal, 5)
                .frame(height: 16)
                .background(colors.textColorError)
                .cornerRadius(8)
        }
    }
}
