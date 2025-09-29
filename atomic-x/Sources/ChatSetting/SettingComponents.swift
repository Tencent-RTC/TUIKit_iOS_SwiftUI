import SwiftUI

enum AlertType: Identifiable {
    case clearHistory
    case deleteAndQuit
    case dismissGroup
    case deleteFriend
    var id: String {
        switch self {
        case .clearHistory: return "clearHistory"
        case .deleteAndQuit: return "deleteAndQuit"
        case .dismissGroup: return "dismissGroup"
        case .deleteFriend: return "deleteFriend"
        }
    }
}

struct CustomActionButton: View {
    @EnvironmentObject var themeState: ThemeState
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(icon,bundle: AtomicXChatResources.resourceBundle)
                    .font(.system(size: 20))
                    .foregroundColor(themeState.colors.textColorLink)
                Text(title)
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
            .frame(width: 80, height: 80)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeState.colors.bgColorTopBar)
        )
    }
}

struct SettingRowToggle: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var isOn: Bool
    let title: String
    let onToggle: (Bool) -> Void

    init(title: String, isOn: Binding<Bool>, onToggle: @escaping (Bool) -> Void) {
        self.title = title
        self._isOn = isOn
        self.onToggle = onToggle
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    onToggle(newValue)
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: themeState.colors.switchColorOn))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }
}

struct SettingRowButton: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let textColor: Color
    let action: () -> Void

    init(title: String, textColor: Color = .primary, action: @escaping () -> Void) {
        self.title = title
        self.textColor = textColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(textColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowNavigate: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let subtitle: String?
    let action: () -> Void

    init(title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowInfo: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let value: String

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(themeState.colors.textColorSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }
}

struct SettingRowNavigateWithPreview: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let preview: String
    let action: () -> Void

    init(title: String, preview: String, action: @escaping () -> Void) {
        self.title = title
        self.preview = preview
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(preview)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowWithValue: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let value: String
    let action: () -> Void

    init(title: String, value: String, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowWithCount: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let count: Int
    let action: () -> Void

    init(title: String, count: Int, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text("\(count)")
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowAddMember: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(themeState.colors.textColorLink)
                Text(title)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

public struct AvatarSelector: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var selectedImageUrl: String?
    @State private var showingImagePicker = false
    let imageUrlList: [String]
    let column: Int
    let onComplete: (String?) -> Void

    public init(
        imageUrlList: [String],
        column: Int = 3,
        onComplete: @escaping (String?) -> Void
    ) {
        self.imageUrlList = imageUrlList
        self.column = column
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            avatarGridView
                .padding(.top, 10)
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationBarTitle(LocalizedChatString("ChooseAvatar"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeState.colors.textColorLink)
            },
            trailing: Button(LocalizedChatString("Done")) {
                onComplete(selectedImageUrl)
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(selectedImageUrl == nil)
        )
    }

    private var avatarGridView: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(self.rows, id: \ .self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { imageUrl in
                                AvatarPickerCell(
                                    imageUrl: imageUrl,
                                    isSelected: selectedImageUrl == imageUrl,
                                    size: calculateImageSize(screenWidth: geometry.size.width),
                                    onTap: {
                                        selectedImageUrl = imageUrl
                                    }
                                )
                            }
                            if row.count < column {
                                ForEach(0..<(column - row.count), id: \.self) { _ in
                                    Spacer().frame(width: calculateImageSize(screenWidth: geometry.size.width), height: calculateImageSize(screenWidth: geometry.size.width))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: imageUrlList.count, by: column).map {
            Array(imageUrlList[$0..<min($0 + column, imageUrlList.count)])
        }
    }

    private func calculateImageSize(screenWidth: CGFloat) -> CGFloat {
        let availableWidth = screenWidth - 20
        let spacingWidth = CGFloat(column - 1) * 10
        let imageWidth = (availableWidth - spacingWidth) / CGFloat(column)
        return imageWidth
    }
}

struct AvatarPickerCell: View {
    let imageUrl: String
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                CompatibleKFImage(
                    url: URL(string: imageUrl),
                    width: size,
                    height: size,
                    contentMode: .fill,
                    fallback: {
                        AnyView(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.systemGray))
                                )
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(.systemBlue) : Color.clear, lineWidth: 3)
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(.systemBlue))
                                .background(Circle().fill(Color.white))
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
