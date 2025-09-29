import SwiftUI

public enum SwitchSize {
    case s, m, l
    var width: CGFloat {
        switch self {
        case .s: return 26
        case .m: return 32
        case .l: return 40
        }
    }

    var height: CGFloat {
        switch self {
        case .s: return 16
        case .m: return 20
        case .l: return 24
        }
    }

    var thumbSize: CGFloat {
        switch self {
        case .s: return 12
        case .m: return 15
        case .l: return 18
        }
    }

    var padding: CGFloat {
        switch self {
        case .s: return 2
        case .m: return 2.5
        case .l: return 3
        }
    }

    var textSize: CGFloat {
        switch self {
        case .s: return 10
        case .m: return 12
        case .l: return 14
        }
    }
}

public enum SwitchType {
    case basic
    case withText
    case withIcon
}

public struct BasicSwitch: View {
    public var checked: Bool
    public var onCheckedChange: ((Bool) -> Void)? = nil
    public init(
        checked: Bool,
        onCheckedChange: ((Bool) -> Void)? = nil,
        enabled: Bool = true,
        loading: Bool = false
    ) {
        self.checked = checked
        self.onCheckedChange = onCheckedChange
    }

    public var body: some View {
        SwitchView(
            checked: checked,
            onCheckedChange: onCheckedChange,
            enabled: true,
            loading: false,
            size: .m,
            type: .basic
        )
    }
}

public struct SwitchView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var animValue: CGFloat = 0
    public var checked: Bool
    public var onCheckedChange: ((Bool) -> Void)? = nil
    public var enabled: Bool = true
    public var loading: Bool = false
    public var size: SwitchSize = .l
    public var type: SwitchType = .basic

    public init(
        checked: Bool,
        onCheckedChange: ((Bool) -> Void)? = nil,
        enabled: Bool = true,
        loading: Bool = false,
        size: SwitchSize = .l,
        type: SwitchType = .basic
    ) {
        self.checked = checked
        self.onCheckedChange = onCheckedChange
        self.enabled = enabled
        self.loading = loading
        self.size = size
        self.type = type
    }

    public var body: some View {
        let colors = themeState.colors
        let checkedIcon = Image(systemName: "checkmark")
        let uncheckedIcon = Image(systemName: "xmark")
        let width: CGFloat = {
            switch type {
            case .basic: return size.width
            case .withIcon, .withText: return size.height * 2
            }
        }()
        let maxOffset = width - size.thumbSize - size.padding * 2
        let trackColor: Color = {
            var c = checked ? colors.switchColorOn : colors.switchColorOff
            if !enabled { c = c.opacity(0.6) }
            return c
        }()
        let thumbColor: Color = {
            var c = colors.switchColorButton
            if !enabled { c = c.opacity(0.6) }
            return c
        }()
        ZStack {
            RoundedRectangle(cornerRadius: size.height / 2)
                .fill(trackColor)
                .frame(width: width, height: size.height)
            HStack(spacing: 0) {
                if type == .withText || type == .withIcon {
                    if checked {
                        Spacer()
                    }
                    if type == .withIcon {
                        (checked ? checkedIcon : uncheckedIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size.thumbSize, height: size.thumbSize)
                            .foregroundColor(colors.textColorButton)
                    } else if type == .withText {
                        Text(checked ? "开" : "关")
                            .font(.system(size: size.textSize, weight: .medium))
                            .foregroundColor(colors.textColorButton)
                            .frame(width: width - size.thumbSize - size.padding * 2, height: size.height)
                            .lineLimit(1)
                    }
                    if !checked {
                        Spacer()
                    }
                }
            }
            .frame(width: width, height: size.height)
            Circle()
                .fill(thumbColor)
                .frame(width: size.thumbSize, height: size.thumbSize)
                .shadow(color: Color.black.opacity(0.12), radius: size == .s ? 1.6 : (size == .m ? 2 : 2.4), x: 0, y: 0)
                .offset(x: checked ? maxOffset : 0)
                .overlay(
                    Group {
                        if loading {
                            if #available(iOS 14.0, *) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: colors.switchColorOn))
                                    .frame(width: size.thumbSize * 0.6, height: size.thumbSize * 0.6)
                            } else {
                                Image(systemName: "arrow.2.circlepath")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: size.thumbSize * 0.6, height: size.thumbSize * 0.6)
                                    .rotationEffect(.degrees(loading ? 360 : 0))
                                    .animation(loading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default)
                            }
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: checked)
                .animation(.easeInOut(duration: 0.3), value: loading)
                .padding(.horizontal, size.padding)
                .frame(width: width, height: size.height, alignment: .leading)
        }
        .frame(width: width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            if enabled, !loading {
                onCheckedChange?(!checked)
            }
        }
    }
}
