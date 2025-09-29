import SwiftUI

public struct PopMenuInfo {
    public let icon: String
    public let title: String
    public let onClick: () -> Void
    public init(icon: String, title: String, onClick: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.onClick = onClick
    }
}

public struct PopMenu: View {
    @EnvironmentObject var themeState: ThemeState
    let menuItems: [PopMenuInfo]

    public init(menuItems: [PopMenuInfo]) {
        self.menuItems = menuItems
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                Button(action: item.onClick) {
                    PopMenuRow(
                        icon: item.icon,
                        title: item.title
                    )
                }
                .buttonStyle(PlainButtonStyle())
                if index < menuItems.count - 1 {
                    Divider()
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.leading, 38)
                }
            }
        }
        .background(themeState.colors.dropdownColorDefault)
        .cornerRadius(12)
        .shadow(color: Colors.Black1.opacity(0.15), radius: 8, x: 0, y: 4)
        .frame(width: 160)
    }
}

private struct PopMenuRow: View {
    @EnvironmentObject var themeState: ThemeState
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeState.colors.textColorLink)
                .frame(width: 18, height: 18)
                .padding(.leading, 12)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(themeState.colors.textColorPrimary)
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.vertical, 14)
        .background(themeState.colors.dropdownColorDefault)
        .contentShape(Rectangle())
    }
}
