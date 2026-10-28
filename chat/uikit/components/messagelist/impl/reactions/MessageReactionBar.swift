import AtomicXCore
import Kingfisher
import SwiftUI

private let maxDisplayReactions = 10

struct MessageReactionBar: View {
    @EnvironmentObject var themeState: ThemeState

    let reactionList: [MessageReaction]
    let isLeft: Bool
    let isSentBySelf: Bool
    let onClick: () -> Void
    let maxWidth: CGFloat

    private static let chipHorizontalSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let chipVerticalSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let chipHorizontalPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let chipVerticalPadding = CGFloat(SpacingScheme.iconTextSpacing)
    private static let chipCornerRadius = CGFloat(RadiusScheme.alertRadius)
    private static let chipEmojiSize: CGFloat = 16
    private static let chipDividerWidth: CGFloat = 1
    private static let chipDividerHeight: CGFloat = 14
    private static let chipTextMaxWidth: CGFloat = 120
    private static let chipMaxWidth: CGFloat = 180
    private static let selfChipBgOpacity = 24.0 / 255.0
    private static let otherChipBgOpacity = 16.0 / 255.0
    private static let selfChipDividerOpacity = 64.0 / 255.0
    private static let otherChipDividerOpacity = 32.0 / 255.0
    private static let measureFont = UIKitFontScheme.caption3Regular

    var body: some View {
        if reactionList.isEmpty {
            return AnyView(EmptyView())
        }

        let displayReactions = Array(reactionList.prefix(maxDisplayReactions))
        let rows = Self.computeRows(reactions: displayReactions, maxWidth: maxWidth)
        let baseTextColor = isSentBySelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary

        return AnyView(
            VStack(alignment: isLeft ? .leading : .trailing, spacing: Self.chipVerticalSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.chipHorizontalSpacing) {
                        ForEach(row) { reaction in
                            chip(reaction: reaction, baseTextColor: baseTextColor)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onClick()
            }
        )
    }

    private func chip(reaction: MessageReaction, baseTextColor: Color) -> some View {
        let labelText = Self.reactionLabel(reaction)
        let layout = Self.chipLayout(reaction, maxWidth: maxWidth)
        return HStack(spacing: 0) {
            if layout.emojiSize > 0 {
                emojiImage(reactionID: reaction.reactionID, size: layout.emojiSize)
            }
            if layout.textWidth > 0 {
                if layout.emojiSize > 0 {
                    Spacer().frame(width: Self.chipHorizontalSpacing / 2)
                    Rectangle()
                        .fill(baseTextColor.opacity(isSentBySelf ? Self.selfChipDividerOpacity : Self.otherChipDividerOpacity))
                        .frame(width: Self.chipDividerWidth, height: Self.chipDividerHeight)
                    Spacer().frame(width: Self.chipHorizontalSpacing / 2)
                }
                Text(labelText)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(isSentBySelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: layout.textWidth)
            }
        }
        .padding(.horizontal, layout.padding)
        .padding(.vertical, Self.chipVerticalPadding)
        .background(baseTextColor.opacity(isSentBySelf ? Self.selfChipBgOpacity : Self.otherChipBgOpacity))
        .cornerRadius(Self.chipCornerRadius)
    }

    private func emojiImage(reactionID: String, size: CGFloat) -> some View {
        let path = Self.emojiData(for: reactionID)?.path
        return Group {
            if let path = path {
                CompatibleKFImage(
                    path: path,
                    width: size,
                    height: size,
                    fallback: {
                        AnyView(
                            Image(systemName: "face.smiling")
                                .resizable()
                                .frame(width: size, height: size)
                                .foregroundColor(themeState.colors.textColorSecondary)
                        )
                    }
                )
            }
        }
    }

    private static func emojiData(for reactionID: String) -> EmojiData? {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        return allEmojis.first(where: { $0.name == reactionID })
    }

    static func computeRows(reactions: [MessageReaction], maxWidth: CGFloat) -> [[MessageReaction]] {
        let maxRowWidth = maxWidth.isFinite ? max(0, maxWidth) : 0
        var rows: [[MessageReaction]] = []
        var currentRow: [MessageReaction] = []
        var currentWidth: CGFloat = 0

        for reaction in reactions {
            let chipWidth = Self.chipWidth(reaction, maxWidth: maxRowWidth)
            let spacing = currentRow.isEmpty ? 0 : Self.chipHorizontalSpacing
            if !currentRow.isEmpty, currentWidth + spacing + chipWidth > maxRowWidth {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }
            let rowSpacing = currentRow.isEmpty ? 0 : Self.chipHorizontalSpacing
            currentRow.append(reaction)
            currentWidth += rowSpacing + chipWidth
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }

    static func chipWidth(_ reaction: MessageReaction, maxWidth: CGFloat) -> CGFloat {
        let layout = chipLayout(reaction, maxWidth: maxWidth)
        let dividerWidth = layout.emojiSize > 0 && layout.textWidth > 0 ? chipHorizontalSpacing + chipDividerWidth : 0
        return layout.padding * 2 + layout.emojiSize + dividerWidth + layout.textWidth
    }

    static func rowWidth(_ reactions: [MessageReaction], maxWidth: CGFloat) -> CGFloat {
        reactions.reduce(0) { $0 + chipWidth($1, maxWidth: maxWidth) }
            + CGFloat(max(0, reactions.count - 1)) * chipHorizontalSpacing
    }

    private static func chipLayout(_ reaction: MessageReaction, maxWidth: CGFloat) -> (padding: CGFloat, emojiSize: CGFloat, textWidth: CGFloat) {
        let width = maxWidth.isFinite ? max(0, min(chipMaxWidth, maxWidth)) : 0
        let padding = min(chipHorizontalPadding, width / 2)
        let contentWidth = max(0, width - padding * 2)
        let emojiSize = emojiData(for: reaction.reactionID) != nil ? min(chipEmojiSize, contentWidth) : 0
        let label = reactionLabel(reaction)
        let dividerWidth = emojiSize > 0 && !label.isEmpty ? chipHorizontalSpacing + chipDividerWidth : 0
        let textWidth = min(Self.textWidth(label), max(0, contentWidth - emojiSize - dividerWidth))
        return (padding, emojiSize, textWidth)
    }

    private static func textWidth(_ text: String) -> CGFloat {
        let measured = (text as NSString).size(withAttributes: [.font: measureFont]).width
        return min(ceil(measured), chipTextMaxWidth)
    }

    private static func reactionLabel(_ reaction: MessageReaction) -> String {
        let totalUserCount = reaction.totalUserCount
        guard totalUserCount > 0 else { return "" }

        let firstUser = reaction.partialUserList.first
        var displayName: String?
        if let nickname = firstUser?.nickname,
           !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = nickname
        } else if let userID = firstUser?.userID, !userID.isEmpty {
            displayName = userID
        }
        guard let name = displayName else {
            return "\(totalUserCount)"
        }
        if totalUserCount == 1 {
            return name
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChinese = LanguageHelper.getCurrentLanguage().hasPrefix("zh")
        let count = isChinese ? totalUserCount : max(totalUserCount - 1, 1)
        let suffix = String(format: LocalizedChatString("MessageReactionUserSuffix"), Int(count))
        return isChinese ? trimmed + suffix : trimmed + " " + suffix
    }
}
