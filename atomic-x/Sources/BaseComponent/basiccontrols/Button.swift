import SwiftUI

public enum ButtonType {
    case filled
    case outlined
    case noBorder
}

public enum ButtonColorType {
    case primary
    case secondary
    case danger
}

public enum ButtonContentType {
    case textOnly
    case iconOnly
    case iconWithText
}

public enum ButtonIconPosition {
    case start
    case end
}

public enum ButtonSize {
    case xs, s, m, l
    var height: CGFloat {
        switch self {
        case .xs: return 24
        case .s: return 32
        case .m: return 40
        case .l: return 48
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .xs: return 8
        case .s: return 12
        case .m: return 16
        case .l: return 20
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .xs: return 48
        case .s: return 64
        case .m: return 80
        case .l: return 96
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .xs: return 14
        case .s: return 16
        case .m: return 20
        case .l: return 20
        }
    }
}

struct ButtonColors {
    let backgroundColor: Color
    let textColor: Color
    let borderColor: Color
}

public enum ButtonContent {
    case textOnly(text: String)
    case iconOnly(icon: Image)
    case iconWithText(text: String, icon: Image, iconPosition: ButtonIconPosition = .start)
}

public struct FilledButton: View {
    public var text: String
    public var size: ButtonSize = .l
    public var onClick: () -> Void = {}
    public init(text: String, size: ButtonSize = .l, onClick: @escaping () -> Void = {}) {
        self.text = text
        self.size = size
        self.onClick = onClick
    }

    public var body: some View {
        ButtonView(content: .textOnly(text: text), size: size, onClick: onClick)
    }
}

public struct OutlinedButton: View {
    public var text: String
    public var size: ButtonSize = .l
    public var onClick: () -> Void = {}
    public init(text: String, size: ButtonSize = .l, onClick: @escaping () -> Void = {}) {
        self.text = text
        self.size = size
        self.onClick = onClick
    }

    public var body: some View {
        ButtonView(content: .textOnly(text: text), type: .outlined, size: size, onClick: onClick)
    }
}

public struct IconButton: View {
    public var text: String
    public var icon: Image
    public var size: ButtonSize = .l
    public var onClick: () -> Void = {}
    public init(text: String, icon: Image, size: ButtonSize = .l, onClick: @escaping () -> Void = {}) {
        self.text = text
        self.icon = icon
        self.size = size
        self.onClick = onClick
    }

    public var body: some View {
        ButtonView(content: .iconWithText(text: text, icon: icon), size: size, onClick: onClick)
    }
}

public struct ButtonView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var isPressed = false
    @State private var isHovered = false
    let content: ButtonContent
    let enabled: Bool
    let type: ButtonType
    let colorType: ButtonColorType
    let size: ButtonSize
    let onClick: () -> Void

    public init(
        content: ButtonContent,
        enabled: Bool = true,
        type: ButtonType = .filled,
        colorType: ButtonColorType = .primary,
        size: ButtonSize = .l,
        onClick: @escaping () -> Void
    ) {
        self.content = content
        self.enabled = enabled
        self.type = type
        self.colorType = colorType
        self.size = size
        self.onClick = onClick
    }

    private func getColors() -> ButtonColors {
        let colors = themeState.colors
        if !enabled {
            return getDisabledColors(type: type, colorType: colorType, colors: colors)
        } else if isPressed {
            return getActiveColors(type: type, colorType: colorType, colors: colors)
        } else if isHovered {
            return getHoverColors(type: type, colorType: colorType, colors: colors)
        } else {
            return getDefaultColors(type: type, colorType: colorType, colors: colors)
        }
    }

    private func fontForButtonSize(_ size: ButtonSize) -> Font {
        switch size {
        case .xs: return themeState.fonts.caption3Medium
        case .s: return themeState.fonts.caption2Medium
        case .m, .l: return themeState.fonts.caption1Medium
        }
    }

    public var body: some View {
        let colors = getColors()
        let minWidth: CGFloat = {
            switch content {
            case .iconOnly: return size.height
            case .iconWithText, .textOnly: return size.minWidth
            }
        }()
        let shape = Capsule()
        Button(action: {
            if enabled { onClick() }
        }) {
            HStack(spacing: {
                if case .iconWithText = content {
                    return 4
                } else {
                    return 0
                }
            }()) {
                switch content {
                case .iconOnly(let icon):
                    icon.resizable().renderingMode(.template)
                        .frame(width: size.iconSize, height: size.iconSize)
                        .foregroundColor(colors.textColor)
                case .iconWithText(let text, let icon, let iconPosition):
                    if iconPosition == .start {
                        icon.resizable().renderingMode(.template)
                            .frame(width: size.iconSize, height: size.iconSize)
                            .foregroundColor(colors.textColor)
                    }
                    Text(text)
                        .font(fontForButtonSize(size))
                        .foregroundColor(colors.textColor)
                        .lineLimit(1)
                    if iconPosition == .end {
                        icon.resizable().renderingMode(.template)
                            .frame(width: size.iconSize, height: size.iconSize)
                            .foregroundColor(colors.textColor)
                    }
                case .textOnly(let text):
                    Text(text)
                        .font(fontForButtonSize(size))
                        .foregroundColor(colors.textColor)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: minWidth, minHeight: size.height, maxHeight: size.height)
            .padding(.horizontal, {
                if case .iconOnly = content {
                    return 0
                } else {
                    return size.horizontalPadding
                }
            }())
            .background(colors.backgroundColor)
            .clipShape(shape)
            .overlay(
                shape.stroke(colors.borderColor, lineWidth: type == .outlined ? 1 : 0)
            )
            .contentShape(shape)
            .opacity(enabled ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false })
    }
}

private func getDefaultColors(type: ButtonType, colorType: ButtonColorType, colors: SemanticColorScheme) -> ButtonColors {
    switch type {
    case .filled:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: colors.buttonColorPrimaryDefault, textColor: colors.textColorButton, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: colors.buttonColorSecondaryDefault, textColor: colors.textColorPrimary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: colors.buttonColorHangupDefault, textColor: colors.textColorButton, borderColor: .clear)
        }
    case .outlined:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryDefault, borderColor: colors.buttonColorPrimaryDefault)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorPrimary, borderColor: colors.strokeColorPrimary)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupDefault, borderColor: colors.buttonColorHangupDefault)
        }
    case .noBorder:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryDefault, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorPrimary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupDefault, borderColor: .clear)
        }
    }
}

private func getHoverColors(type: ButtonType, colorType: ButtonColorType, colors: SemanticColorScheme) -> ButtonColors {
    switch type {
    case .filled:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: colors.buttonColorPrimaryHover, textColor: colors.textColorButton, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: colors.buttonColorSecondaryHover, textColor: colors.textColorSecondary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: colors.buttonColorHangupHover, textColor: colors.textColorButton, borderColor: .clear)
        }
    case .outlined:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryHover, borderColor: colors.buttonColorPrimaryHover)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorSecondary, borderColor: colors.strokeColorSecondary)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupHover, borderColor: colors.buttonColorHangupHover)
        }
    case .noBorder:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryHover, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorSecondary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupHover, borderColor: .clear)
        }
    }
}

private func getActiveColors(type: ButtonType, colorType: ButtonColorType, colors: SemanticColorScheme) -> ButtonColors {
    switch type {
    case .filled:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: colors.buttonColorPrimaryActive, textColor: colors.textColorButton, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: colors.buttonColorSecondaryActive, textColor: colors.textColorTertiary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: colors.buttonColorHangupActive, textColor: colors.textColorButton, borderColor: .clear)
        }
    case .outlined:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryActive, borderColor: colors.buttonColorPrimaryActive)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorTertiary, borderColor: colors.strokeColorModule)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupActive, borderColor: colors.buttonColorHangupActive)
        }
    case .noBorder:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryActive, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorTertiary, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupActive, borderColor: .clear)
        }
    }
}

private func getDisabledColors(type: ButtonType, colorType: ButtonColorType, colors: SemanticColorScheme) -> ButtonColors {
    switch type {
    case .filled:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: colors.buttonColorPrimaryDisabled, textColor: colors.textColorButtonDisabled, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: colors.buttonColorSecondaryDisabled, textColor: colors.textColorDisable, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: colors.buttonColorHangupDisabled, textColor: colors.textColorButtonDisabled, borderColor: .clear)
        }
    case .outlined:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryDisabled, borderColor: colors.buttonColorPrimaryDisabled)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorDisable, borderColor: colors.strokeColorSecondary)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupDisabled, borderColor: colors.buttonColorHangupDisabled)
        }
    case .noBorder:
        switch colorType {
        case .primary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorPrimaryDisabled, borderColor: .clear)
        case .secondary:
            return ButtonColors(backgroundColor: .clear, textColor: colors.textColorDisable, borderColor: .clear)
        case .danger:
            return ButtonColors(backgroundColor: .clear, textColor: colors.buttonColorHangupDisabled, borderColor: .clear)
        }
    }
}
