import Kingfisher
import SwiftUI
import UIKit

struct EmojiPickerImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var recentEmojis: [EmojiData] = []
    @State private var currentGroupIndex: Int = 0
    @State private var groupsVersion: Int = 0
    private let onEmojiClick: (EmojiData) -> Void
    private let onCustomEmojiSelected: ((EmojiGroup, EmojiData) -> Void)?
    private let onSendClick: () -> Void
    private let onDeleteClick: () -> Void

    private static let littleColumnCount = 8
    private static let bigColumnCount = 5
    private static let imageScaleFactor: CGFloat = 0.7
    private static let tabStripHeight: CGFloat = 40
    private static let tabIconSize: CGFloat = 28
    private static let tabContentInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let tabDividerHeight: CGFloat = 0.5
    private static let headerHeight: CGFloat = 30
    private static let headerLeadingInset: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private static let deleteButtonSize = CGSize(width: 40, height: 30)
    private static let sendButtonSize = CGSize(width: 50, height: 30)
    private static let actionButtonSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let actionButtonBottomContentInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let actionButtonCornerRadius: CGFloat = CGFloat(RadiusScheme.largeRadius)

    private var groups: [EmojiGroup] {
        _ = groupsVersion
        return EmojiConfig.shared.emojiGroups
    }

    private var currentGroup: EmojiGroup? {
        guard !groups.isEmpty else { return nil }
        let safeIndex = max(0, min(currentGroupIndex, groups.count - 1))
        return groups[safeIndex]
    }

    private var columnCount: Int {
        (currentGroup?.isLittleEmoji ?? true) ? Self.littleColumnCount : Self.bigColumnCount
    }

    init(onEmojiClick: @escaping (EmojiData) -> Void,
                onSendClick: @escaping () -> Void,
                onDeleteClick: @escaping () -> Void,
                onCustomEmojiSelected: ((EmojiGroup, EmojiData) -> Void)? = nil)
    {
        _ = EmojiConfig.shared.emojiGroups
        self.onEmojiClick = onEmojiClick
        self.onSendClick = onSendClick
        self.onDeleteClick = onDeleteClick
        self.onCustomEmojiSelected = onCustomEmojiSelected
        loadRecentEmojis()
    }

    private func loadRecentEmojis() {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        let recentIds = EmojiManager.shared.getRecentEmojis()
        recentEmojis = recentIds.compactMap { id in
            allEmojis.first(where: { $0.name == id })
        }
    }

    var body: some View {
        let horizontalInset = CGFloat(themeState.spacing.bubbleSpacing)
        let actionButtonPadding = CGFloat(themeState.spacing.normalSpacing)
        return GeometryReader { geo in
            let totalWidth = geo.size.width - horizontalInset * 2
            let columns = columnCount
            let cellWidth = floor(totalWidth / CGFloat(columns))
            let imageWidth = cellWidth * Self.imageScaleFactor
            let fallbackView: () -> AnyView = {
                AnyView(
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageWidth, height: imageWidth)
                        .foregroundColor(themeState.colors.textColorSecondary)
                )
            }
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if groups.count > 1 {
                        tabStrip
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if currentGroup?.isLittleEmoji ?? true {
                                if !recentEmojis.isEmpty {
                                    sectionHeader(LocalizedChatString("TUIChatFaceGroupRecentEmojiName"))
                                    emojiGrid(recentEmojis, cellWidth: cellWidth, imageWidth: imageWidth, columns: columns, fallbackView: fallbackView)
                                        .padding(.horizontal, horizontalInset)
                                }
                                sectionHeader(LocalizedChatString("TUIChatFaceGroupAllEmojiName"))
                            }
                            emojiGrid(currentGroup?.emojis ?? [], cellWidth: cellWidth, imageWidth: imageWidth, columns: columns, fallbackView: fallbackView)
                                .padding(.horizontal, horizontalInset)
                        }
                        .padding(.bottom, Self.actionButtonBottomContentInset)
                    }
                }
                .background(themeState.colors.bgColorOperate)

                if currentGroup?.isLittleEmoji ?? true {
                    HStack(spacing: Self.actionButtonSpacing) {
                        deleteButton
                        sendButton
                    }
                    .padding(.trailing, actionButtonPadding)
                    .padding(.bottom, actionButtonPadding)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onAppear {
            loadRecentEmojis()
        }
        .onReceive(NotificationCenter.default.publisher(for: EmojiConfig.groupsDidChangeNotification)) { _ in
            groupsVersion += 1
            loadRecentEmojis()
        }
    }

    private var tabStrip: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CGFloat(themeState.spacing.bubbleSpacing)) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        Button(action: {
                            currentGroupIndex = index
                        }) {
                            GroupTabIcon(group: group, size: Self.tabIconSize, fallbackView: {
                                AnyView(
                                    Image(systemName: "face.smiling")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: Self.tabIconSize - 8, height: Self.tabIconSize - 8)
                                        .foregroundColor(themeState.colors.textColorSecondary)
                                )
                            })
                        }
                        .opacity(index == currentGroupIndex ? 1.0 : 0.4)
                    }
                }
                .padding(.horizontal, Self.tabContentInset)
                .frame(height: Self.tabStripHeight)
            }
            .frame(height: Self.tabStripHeight)
            Rectangle()
                .fill(themeState.colors.strokeColorPrimary)
                .frame(height: Self.tabDividerHeight)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(themeState.fonts.caption2Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .padding(.leading, Self.headerLeadingInset)
            .frame(maxWidth: .infinity, minHeight: Self.headerHeight, maxHeight: Self.headerHeight, alignment: .leading)
    }

    private func emojiGrid(_ emojis: [EmojiData], cellWidth: CGFloat, imageWidth: CGFloat, columns: Int, fallbackView: @escaping () -> AnyView) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: 0), count: columns), spacing: 0) {
            ForEach(emojis, id: \.path) { emojiData in
                Button(action: {
                    handleEmojiClick(emojiData)
                }) {
                    CompatibleKFImage(path: emojiData.path, width: imageWidth, height: imageWidth, fallback: fallbackView)
                        .frame(width: cellWidth, height: cellWidth)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deleteButton: some View {
        Button(action: {
            onDeleteClick()
        }) {
            Image(systemName: "delete.left")
                .font(FontScheme.caption2Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .frame(width: Self.deleteButtonSize.width, height: Self.deleteButtonSize.height)
                .background(themeState.colors.buttonColorSecondaryDefault)
                .cornerRadius(Self.actionButtonCornerRadius)
        }
    }

    private var sendButton: some View {
        Button(action: {
            onSendClick()
        }) {
            Text(LocalizedChatString("Send"))
                .font(themeState.fonts.caption2Medium)
                .foregroundColor(themeState.colors.textColorButton)
                .frame(width: Self.sendButtonSize.width, height: Self.sendButtonSize.height)
                .background(themeState.colors.buttonColorPrimaryDefault)
                .cornerRadius(Self.actionButtonCornerRadius)
        }
    }

    private func handleEmojiClick(_ emojiData: EmojiData) {
        guard let group = currentGroup else { return }
        if group.isLittleEmoji {
            EmojiManager.shared.addRecentEmoji(emojiData)
            onEmojiClick(emojiData)
        } else {
            onCustomEmojiSelected?(group, emojiData)
        }
    }
}

private struct GroupTabIcon: View {
    let group: EmojiGroup
    let size: CGFloat
    let fallbackView: () -> AnyView

    var body: some View {
        if let menuPath = group.menuPath {
            CompatibleKFImage(path: menuPath, width: size, height: size, fallback: fallbackView)
        } else {
            fallbackView()
        }
    }
}
