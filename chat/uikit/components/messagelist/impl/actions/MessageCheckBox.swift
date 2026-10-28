import SwiftUI

struct MessageCheckBox: View {
    static let size: CGFloat = 20

    let isSelected: Bool
    let isEnabled: Bool

    @EnvironmentObject var themeState: ThemeState

    init(isSelected: Bool, isEnabled: Bool = true) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? themeState.colors.buttonColorPrimaryDefault : Color.clear)
                .frame(width: Self.size, height: Self.size)

            if !isSelected {
                Circle()
                    .strokeBorder(
                        isEnabled ? themeState.colors.strokeColorPrimary : themeState.colors.textColorDisable,
                        lineWidth: 1.5
                    )
                    .frame(width: Self.size, height: Self.size)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .font(FontScheme.caption3Bold)
                    .foregroundColor(themeState.colors.textColorButton)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
