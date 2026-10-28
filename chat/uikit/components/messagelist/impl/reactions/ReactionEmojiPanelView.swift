import AtomicXCore
import SwiftUI

struct ReactionEmojiPanelView: View {
    let message: MessageInfo
    var onCollapse: () -> Void
    var onMore: () -> Void
    var onToggleEmoji: (EmojiData) -> Void

    @EnvironmentObject var themeState: ThemeState

    private static let columns = 6
    private static let rows = 2
    private static let maxQuickEmojiCount = 11
    private static let cellSize: CGFloat = 40
    private static let emojiGlyphInset: CGFloat = 6
    private static let horizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let topPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let headerHeight: CGFloat = 16
    private static let headerGap = CGFloat(SpacingScheme.smallSpacing)
    private static let bottomPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let collapseIconSize: CGFloat = 16
    private static let rowDividerVerticalMargin = CGFloat(SpacingScheme.iconTextSpacing)
    private static let moreButtonSize: CGFloat = 28
    private static let moreButtonGlyphInset: CGFloat = 6

    static let panelWidth: CGFloat = horizontalPadding * 2 + cellSize * CGFloat(columns)
    static let panelHeight: CGFloat = topPadding + headerHeight + headerGap + (cellSize * CGFloat(rows) + 1 + rowDividerVerticalMargin * 2) + bottomPadding

    var body: some View {
        VStack(spacing: 0) {
            header
            emojiGrid
        }
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding)
    }

    private var header: some View {
        HStack {
            Text(LocalizedChatString("Reaction"))
                .font(themeState.fonts.caption3Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
            Button(action: onCollapse) {
                Image("message_reaction_collapse", bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: Self.collapseIconSize, height: Self.collapseIconSize)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: Self.headerHeight)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.bottom, Self.headerGap)
    }

    private var emojiGrid: some View {
        let quickEmojis = quickEmojiList()
        let lastIndex = Self.columns * Self.rows - 1
        return VStack(spacing: 0) {
            ForEach(0 ..< Self.rows, id: \.self) { rowIndex in
                if rowIndex > 0 {
                    Rectangle()
                        .fill(themeState.colors.strokeColorPrimary.opacity(140.0 / 255.0))
                        .frame(height: 1)
                        .padding(.horizontal, Self.horizontalPadding)
                        .padding(.vertical, Self.rowDividerVerticalMargin)
                }
                HStack(spacing: 0) {
                    ForEach(0 ..< Self.columns, id: \.self) { column in
                        let index = rowIndex * Self.columns + column
                        cellView(index: index, lastIndex: lastIndex, quickEmojis: quickEmojis)
                            .frame(width: Self.cellSize, height: Self.cellSize)
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
            }
        }
    }

    private func cellView(index: Int, lastIndex: Int, quickEmojis: [EmojiData]) -> some View {
        Group {
            if index == lastIndex {
                moreCell
            } else if index < quickEmojis.count {
                emojiCell(quickEmojis[index])
            } else {
                Color.clear
            }
        }
    }

    private func emojiCell(_ emoji: EmojiData) -> some View {
        Button(action: { onToggleEmoji(emoji) }) {
            CompatibleKFImage(
                path: emoji.path,
                width: Self.cellSize - Self.emojiGlyphInset * 2,
                height: Self.cellSize - Self.emojiGlyphInset * 2,
                contentMode: .fit,
                fallback: {
                    AnyView(
                        Image(systemName: "face.smiling")
                            .resizable()
                            .foregroundColor(themeState.colors.textColorSecondary)
                    )
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var moreCell: some View {
        Button(action: onMore) {
            ZStack {
                Circle()
                    .fill(themeState.colors.dropdownColorHover)
                    .frame(width: Self.moreButtonSize, height: Self.moreButtonSize)
                Image("message_more", bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(
                        width: Self.moreButtonSize - Self.moreButtonGlyphInset * 2,
                        height: Self.moreButtonSize - Self.moreButtonGlyphInset * 2
                    )
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
            .frame(width: Self.cellSize, height: Self.cellSize)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func quickEmojiList() -> [EmojiData] {
        let allEmojis = EmojiManager.shared.getPickerEmojis()
        guard !allEmojis.isEmpty else { return [] }
        let emojiByName = Dictionary(uniqueKeysWithValues: allEmojis.compactMap { emoji -> (String, EmojiData)? in
            guard let name = emoji.name else { return nil }
            return (name, emoji)
        })
        var orderedNames: [String] = []
        orderedNames += message.reactionList.filter { $0.reactedByMyself }.map { $0.reactionID }
        let recentGroupID = EmojiManager.shared.reactionGroupID()
        orderedNames += EmojiManager.shared.getRecentEmojis(groupID: recentGroupID)
        orderedNames += allEmojis.compactMap { $0.name }

        var result: [EmojiData] = []
        var usedNames = Set<String>()
        for name in orderedNames {
            guard let emoji = emojiByName[name], usedNames.insert(name).inserted else { continue }
            result.append(emoji)
            if result.count >= Self.maxQuickEmojiCount { break }
        }
        return result
    }
}
