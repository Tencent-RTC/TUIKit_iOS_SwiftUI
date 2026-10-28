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

enum SettingRowAccessory {
    case none
    case arrow
    case edit
}

struct SettingRowView: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let value: String
    let accessory: SettingRowAccessory
    let isEnabled: Bool
    let action: () -> Void

    init(title: String, value: String = "", accessory: SettingRowAccessory = .arrow, isEnabled: Bool = true, action: @escaping () -> Void = {}) {
        self.title = title
        self.value = value
        self.accessory = accessory
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .fixedSize()
                Spacer(minLength: 16)
                if !value.isEmpty {
                    Text(value)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                }
                if accessory != .none {
                    accessoryIcon
                        .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minHeight: 48)
            .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var accessoryIcon: some View {
        let name = accessory == .edit ? "group_setting_edit_icon" : "contact_info_arrow_right"
        if let icon = AtomicXChatResources.image(named: name) {
            Image(uiImage: icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundColor(themeState.colors.textColorTertiary)
        }
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
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    onToggle(newValue)
                }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: themeState.colors.switchColorOn))
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .background(themeState.colors.bgColorOperate)
    }
}

struct SettingActionRow: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let textColor: Color
    let action: () -> Void

    init(title: String, textColor: Color, action: @escaping () -> Void) {
        self.title = title
        self.textColor = textColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FontScheme.caption1Regular)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CGFloat(SpacingScheme.bubbleSpacing))
                .frame(minHeight: 56)
                .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingRowDivider: View {
    @EnvironmentObject var themeState: ThemeState

    var body: some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: 0.5)
    }
}

struct SettingSectionSpacer: View {
    var body: some View {
        Color.clear.frame(height: CGFloat(SpacingScheme.smallSpacing))
    }
}

struct AvatarSelectorImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var selectedImageUrl: String?
    @State private var showingImagePicker = false
    let imageUrlList: [String]
    let column: Int
    let onComplete: (String?) -> Void

    init(
        imageUrlList: [String],
        column: Int = 3,
        onComplete: @escaping (String?) -> Void
    ) {
        self.imageUrlList = imageUrlList
        self.column = column
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            avatarGridView
                .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
            Spacer()
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .navigationBarTitle(LocalizedChatString("ChooseAvatar"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: NavBackButtonView {
                presentationMode.wrappedValue.dismiss()
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
                VStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                    ForEach(self.rows, id: \.self) { row in
                        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
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
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.bottom, CGFloat(SpacingScheme.contentSpacing))
            }
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: imageUrlList.count, by: column).map {
            Array(imageUrlList[$0..<min($0 + column, imageUrlList.count)])
        }
    }

    private func calculateImageSize(screenWidth: CGFloat) -> CGFloat {
        let inset = CGFloat(SpacingScheme.iconIconSpacing)
        let availableWidth = screenWidth - inset * 2
        let spacingWidth = CGFloat(column - 1) * inset
        let imageWidth = (availableWidth - spacingWidth) / CGFloat(column)
        return imageWidth
    }
}

struct AvatarPickerSheet: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let imageUrlList: [String]
    let columnCount: Int
    let onDismiss: () -> Void
    let onImageSelected: (String) -> Void

    private let panelHeightRatio: CGFloat = 0.6
    private let panelCornerRadius = CGFloat(RadiusScheme.largeRadius)
    private let headerHorizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private let headerVerticalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private let gridPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private let cellAvatarSize: CGFloat = 64
    private let cellAvatarPadding = CGFloat(SpacingScheme.smallSpacing)
    private let cellAvatarCornerRadius = CGFloat(RadiusScheme.smallRadius)

    init(
        title: String,
        imageUrlList: [String],
        columnCount: Int = 4,
        onDismiss: @escaping () -> Void,
        onImageSelected: @escaping (String) -> Void
    ) {
        self.title = title
        self.imageUrlList = imageUrlList
        self.columnCount = max(1, columnCount)
        self.onDismiss = onDismiss
        self.onImageSelected = onImageSelected
    }

    var body: some View {
        // ignoresSafeArea 须作用于 GeometryReader，确保按全屏高度测量。
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Colors.Black1.opacity(0.4)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                VStack(spacing: 0) {
                    ZStack {
                        Text(title)
                            .font(FontScheme.caption1Bold)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        HStack {
                            Spacer()
                            Button(action: onDismiss) {
                                Text("✕")
                                    .font(FontScheme.body4Regular)
                                    .foregroundColor(themeState.colors.textColorSecondary)
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .padding(.top, headerVerticalPadding)
                    .padding(.horizontal, headerHorizontalPadding)
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount),
                            spacing: 0
                        ) {
                            ForEach(imageUrlList, id: \.self) { url in
                                CompatibleKFImage(
                                    url: URL(string: url),
                                    width: cellAvatarSize,
                                    height: cellAvatarSize,
                                    contentMode: .fill,
                                    fallback: {
                                        AnyView(
                                            RoundedRectangle(cornerRadius: cellAvatarCornerRadius)
                                                .fill(themeState.colors.bgColorInput)
                                        )
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cellAvatarCornerRadius))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, cellAvatarPadding)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onImageSelected(url)
                                }
                            }
                        }
                        .padding(.horizontal, gridPadding)
                        .padding(.bottom, gridPadding)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height * panelHeightRatio)
                .background(themeState.colors.bgColorOperate)
                .clipShape(RoundedCornerShape(radii: [panelCornerRadius, panelCornerRadius, 0, 0]))
            }
        }
        .ignoresSafeArea()
    }
}

struct AvatarPickerCell: View {
    @EnvironmentObject var themeState: ThemeState
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
                            RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.alertRadius))
                                .fill(themeState.colors.bgColorInput)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(FontScheme.body2Regular)
                                        .foregroundColor(themeState.colors.textColorSecondary)
                                )
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.alertRadius)))
                // 选中环半径须随外扩距离增加，以保持同心。
                RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.alertRadius) + 3)
                    .stroke(isSelected ? themeState.colors.buttonColorPrimaryDefault : Color.clear, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
                    .allowsHitTesting(false)
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(FontScheme.body2Regular)
                                .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                                .background(Circle().fill(themeState.colors.textColorButton))
                        }
                        Spacer()
                    }
                    .padding(CGFloat(SpacingScheme.smallSpacing))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
