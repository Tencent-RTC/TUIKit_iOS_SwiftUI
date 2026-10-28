import Kingfisher
import SwiftUI

struct ChatBackgroundPickerView: View {
    let conversationID: String
    var onDismiss: () -> Void

    @EnvironmentObject var themeState: ThemeState
    @State private var selectedURI: String?

    private let items = ChatBackgroundPresetProvider.presetItems()

    private static let panelHeightRatio: CGFloat = 0.65
    private static let cellSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let gridPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let previewHeight: CGFloat = 120
    private static let cellCornerRadius = CGFloat(RadiusScheme.smallRadius)
    private static let panelCornerRadius = CGFloat(RadiusScheme.largeRadius)

    init(conversationID: String, onDismiss: @escaping () -> Void) {
        self.conversationID = conversationID
        self.onDismiss = onDismiss
        _selectedURI = State(initialValue: ChatBackgroundStore.shared.imageURI(forConversationID: conversationID))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Colors.Black1.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                panelContent
                    .frame(width: geometry.size.width, height: geometry.size.height * Self.panelHeightRatio)
                    .background(themeState.colors.bgColorOperate)
                    .clipShape(RoundedCorner(radius: Self.panelCornerRadius, corners: [.topLeft, .topRight]))
            }
            .ignoresSafeArea()
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(LocalizedChatString("SelectChatBackground"))
                    .font(themeState.fonts.caption1Bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Text("×")
                            .font(themeState.fonts.body3Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Self.cellSpacing),
                        GridItem(.flexible(), spacing: Self.cellSpacing)
                    ],
                    spacing: Self.cellSpacing
                ) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        previewCell(item)
                    }
                }
                .padding(.horizontal, Self.gridPadding)
                .padding(.bottom, Self.gridPadding)
            }
        }
    }

    private func previewCell(_ item: ChatBackgroundPresetItem) -> some View {
        let isSelected = isItemSelected(item)
        return Button(action: {
            ChatBackgroundStore.shared.setImageURI(item.imageURI, forConversationID: conversationID)
            selectedURI = item.imageURI
            onDismiss()
        }) {
            ZStack {
                themeState.colors.bgColorTopBar
                if item.isDefault {
                    Text(LocalizedChatString("ChatBackgroundDefault"))
                        .font(themeState.fonts.caption2Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                } else if let thumbnail = item.thumbnailURI {
                    KFImage(URL(string: thumbnail))
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.previewHeight)
            .cornerRadius(Self.cellCornerRadius)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: Self.cellCornerRadius)
                    .stroke(isSelected ? themeState.colors.buttonColorPrimaryDefault : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func isItemSelected(_ item: ChatBackgroundPresetItem) -> Bool {
        if item.isDefault {
            return selectedURI == nil
        }
        return item.imageURI == selectedURI
    }
}
