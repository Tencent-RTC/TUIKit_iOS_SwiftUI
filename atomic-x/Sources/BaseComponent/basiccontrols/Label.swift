import SwiftUI

public enum LabelSize {
    case s
    case m
    case l
}

public enum LabelIconPosition {
    case start
    case end
}

public struct TitleLabel: View {
    let size: LabelSize
    let text: String
    @EnvironmentObject var themeState: ThemeState
    public init(size: LabelSize, text: String) {
        self.size = size
        self.text = text
    }

    private var font: Font {
        switch size {
        case .s: return themeState.fonts.caption2Bold
        case .m: return themeState.fonts.caption1Bold
        case .l: return themeState.fonts.title3Bold
        }
    }

    public var body: some View {
        Label(
            text: text,
            font: font,
            textColor: themeState.colors.textColorPrimary,
            backgroundColor: themeState.colors.clearColor
        )
        .environmentObject(themeState)
    }
}

public struct SubTitleLabel: View {
    @EnvironmentObject var themeState: ThemeState
    let size: LabelSize
    let text: String

    public init(
        size: LabelSize,
        text: String,
        icon: String? = nil,
        iconPosition: LabelIconPosition = .start
    ) {
        self.size = size
        self.text = text
    }

    private var font: Font {
        switch size {
        case .s: return themeState.fonts.caption3Regular
        case .m: return themeState.fonts.caption2Regular
        case .l: return themeState.fonts.caption1Regular
        }
    }

    public var body: some View {
        Label(
            text: text,
            font: font,
            textColor: themeState.colors.textColorSecondary,
            backgroundColor: themeState.colors.clearColor
        )
        .environmentObject(themeState)
    }
}

public struct ItemLabel: View {
    @EnvironmentObject var themeState: ThemeState
    let size: LabelSize
    let text: String

    public init(
        size: LabelSize,
        text: String,
        icon: String? = nil,
        iconPosition: LabelIconPosition = .start
    ) {
        self.size = size
        self.text = text
    }

    private var font: Font {
        switch size {
        case .s: return themeState.fonts.caption2Regular
        case .m: return themeState.fonts.caption1Regular
        case .l: return themeState.fonts.body4Regular
        }
    }

    private var textColor: Color { themeState.colors.textColorPrimary }
    private var backgroundColor: Color { .clear }
    public var body: some View {
        Label(
            text: text,
            font: font,
            textColor: themeState.colors.textColorPrimary,
            backgroundColor: themeState.colors.clearColor
        )
        .environmentObject(themeState)
    }
}

public struct DangerLabel: View {
    @EnvironmentObject var themeState: ThemeState
    let size: LabelSize
    let text: String

    public init(
        size: LabelSize,
        text: String,
        icon: String? = nil,
        iconPosition: LabelIconPosition = .start
    ) {
        self.size = size
        self.text = text
    }

    private var font: Font {
        switch size {
        case .s: return themeState.fonts.caption2Regular
        case .m: return themeState.fonts.caption1Regular
        case .l: return themeState.fonts.body4Regular
        }
    }

    private var textColor: Color { themeState.colors.textColorError }
    private var backgroundColor: Color { .clear }
    public var body: some View {
        Label(
            text: text,
            font: font,
            textColor: themeState.colors.textColorError,
            backgroundColor: themeState.colors.clearColor
        )
        .environmentObject(themeState)
    }
}

public struct CustomLabel: View {
    let text: String
    let font: Font
    let textColor: Color
    let backgroundColor: Color
    let lineLimit: Int
    let icon: String?
    let iconPosition: LabelIconPosition
    
    public init(
        text: String,
        font: Font,
        textColor: Color,
        backgroundColor: Color = .clear,
        lineLimit: Int = 1,
        icon: String? = nil,
        iconPosition: LabelIconPosition = .start
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.lineLimit = lineLimit
        self.icon = icon
        self.iconPosition = iconPosition
    }

    public var body: some View {
        Label(
            text: text,
            font: font,
            textColor: textColor,
            backgroundColor: backgroundColor,
            lineLimit: lineLimit,
            icon: icon,
            iconPosition: iconPosition
        )
    }
}

// MARK: - Base Label

private struct Label: View {
    @EnvironmentObject var themeState: ThemeState
    let text: String
    let font: Font
    let textColor: Color
    let backgroundColor: Color
    let lineLimit: Int
    let icon: String?
    let iconPosition: LabelIconPosition
    
    init(text: String, font: Font, textColor: Color, backgroundColor: Color, lineLimit: Int = 1, icon: String? = nil, iconPosition: LabelIconPosition = .start) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.lineLimit = lineLimit
        self.icon = icon
        self.iconPosition = iconPosition
    }

    public var body: some View {
        Group {
            if let icon = icon, !icon.isEmpty {
                HStack(spacing: 4) {
                    if iconPosition == .start {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    Text(text)
                        .font(font)
                        .foregroundColor(textColor)
                        .lineLimit(lineLimit)
                    if iconPosition == .end {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.horizontal, 4)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(textColor)
                    .lineLimit(lineLimit)
                    .padding(.horizontal, 4)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
