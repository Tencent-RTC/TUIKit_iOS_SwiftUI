import SwiftUI
import UIKit

struct MessageInputMorePanelView: View {
    @EnvironmentObject var themeState: ThemeState
    let actions: [MessageInputMenuAction]
    var bottomSafeAreaInset: CGFloat = 0
    var dismissedRedDotIDs: Set<String> = []
    var onActionTap: ((MessageInputMenuAction) -> Void)? = nil
    var appearance: MessageInputMorePanelAppearance? = nil

    private static let columns = 4
    private static let iconSize: CGFloat = 56
    private static let iconGlyphSize: CGFloat = 28
    private static let titleAreaHeight: CGFloat = 29
    private static let redDotSize: CGFloat = 8

    var body: some View {
        let itemSize = MessageInputAppearanceLayout.dimension(appearance?.itemSize, fallback: Self.iconSize)
        let glyphSize = min(itemSize, MessageInputAppearanceLayout.dimension(appearance?.itemIconSize, fallback: Self.iconGlyphSize))
        let titleTopSpacing = CGFloat(themeState.spacing.iconTextSpacing)
        let itemVerticalSpacing = CGFloat(themeState.spacing.smallSpacing)
        let panelPadding = CGFloat(themeState.spacing.bubbleSpacing)

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: Self.columns),
            spacing: itemVerticalSpacing * 2
        ) {
            ForEach(actions, id: \.ID) { action in
                Button(action: {
                    onActionTap?(action)
                    action.onClick()
                }) {
                    VStack(spacing: 0) {
                        ZStack {
                            MessageInputAppearanceBackground(
                                fill: itemFill(for: action),
                                fallback: themeState.colors.bgColorInput,
                                cornerRadius: appearance?.itemCornerRadius,
                                defaultCornerRadius: CGFloat(themeState.radius.alertRadius)
                            )
                            morePanelIcon(for: action)
                                .frame(width: glyphSize, height: glyphSize)
                                .foregroundColor(appearance?.itemIconTint.map { Color($0) } ?? themeState.colors.textColorPrimary)
                        }
                        .frame(width: itemSize, height: itemSize)
                        .overlay(alignment: .topTrailing) {
                            if action.showRedDot && !dismissedRedDotIDs.contains(action.ID) {
                                Circle()
                                    .fill(themeState.colors.textColorError)
                                    .frame(width: Self.redDotSize, height: Self.redDotSize)
                            }
                        }

                        Text(action.title)
                            .font(.system(size: MessageInputAppearanceLayout.dimension(appearance?.itemTitleSize, fallback: UIKitFontScheme.caption3Regular.pointSize)))
                            .foregroundColor(appearance?.itemTitleColor.map { Color($0) } ?? themeState.colors.textColorSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.titleAreaHeight)
                            .padding(.top, titleTopSpacing)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, itemVerticalSpacing)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(panelPadding)
        .padding(.bottom, bottomSafeAreaInset)
        .background(MessageInputAppearanceBackground(fill: appearance?.fill, fallback: themeState.colors.bgColorOperate))
    }

    private func itemFill(for action: MessageInputMenuAction) -> MessageInputFill? {
        let fills = appearance?.itemFills ?? []
        guard !fills.isEmpty, let index = actions.firstIndex(where: { $0.ID == action.ID }) else { return nil }
        return fills[index % fills.count]
    }

    @ViewBuilder
    private func morePanelIcon(for action: MessageInputMenuAction) -> some View {
        if let uiImage = action.icon {
            // 仅模板图片随主题着色，自定义原色图片保持不变。
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(action.iconName, bundle: AtomicXChatResources.resourceBundle)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
        }
    }
}
