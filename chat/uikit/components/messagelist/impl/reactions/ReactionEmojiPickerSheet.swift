import AtomicXCore
import SwiftUI

struct ReactionFullEmojiPickerSheet: View {
    let message: MessageInfo
    var onSelectEmoji: (EmojiData) -> Void
    var onDismiss: () -> Void

    @EnvironmentObject var themeState: ThemeState
    @State private var dragOffset: CGFloat = 0

    private static let heightScreenRatio: CGFloat = 0.6
    private static let minHeight: CGFloat = 400
    private static let maxHeight: CGFloat = 520
    private static let topCornerRadius = CGFloat(RadiusScheme.superLargeRadius)
    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let bottomPadding = CGFloat(SpacingScheme.normalSpacing)
    private static let dragHandleAreaHeight: CGFloat = 32
    private static let dragHandleWidth: CGFloat = 40
    private static let dragHandleHeight: CGFloat = 16
    private static let dismissDragThresholdRatio: CGFloat = 0.15
    private static let backdropDimAlpha: CGFloat = 0.32
    private static let columns = 8
    private static let cellHeight: CGFloat = 44
    private static let emojiGlyphSize: CGFloat = 32

    private var sections: [(title: String, emojis: [EmojiData])] {
        var result: [(title: String, emojis: [EmojiData])] = []
        let allEmojis = EmojiManager.shared.getPickerEmojis()
        let emojiByName = Dictionary(uniqueKeysWithValues: allEmojis.compactMap { emoji -> (String, EmojiData)? in
            guard let name = emoji.name else { return nil }
            return (name, emoji)
        })
        let recentNames = EmojiManager.shared.getRecentEmojis(groupID: EmojiManager.shared.reactionGroupID())
        let recentEmojis = recentNames.compactMap { emojiByName[$0] }
        if !recentEmojis.isEmpty {
            result.append((LocalizedChatString("ReactionRecentUsed"), recentEmojis))
        }
        if !allEmojis.isEmpty {
            result.append((LocalizedChatString("ReactionAllEmojis"), allEmojis))
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let sheetHeight = min(max(geometry.size.height * Self.heightScreenRatio, Self.minHeight), Self.maxHeight)
            ZStack(alignment: .bottom) {
                Colors.Black1.opacity(Self.backdropDimAlpha)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                sheetContent(sheetHeight: sheetHeight)
                    .frame(width: geometry.size.width, height: sheetHeight)
                    .background(themeState.colors.bgColorDialog)
                    .clipShape(RoundedCorner(radius: Self.topCornerRadius, corners: [.topLeft, .topRight]))
                    .offset(y: dragOffset)
                    .gesture(dragGesture(sheetHeight: sheetHeight))
            }
            .ignoresSafeArea()
        }
    }

    private func sheetContent(sheetHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            dragHandle
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        Section(header: sectionHeader(section.title)) {
                            emojiGrid(section.emojis)
                        }
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.bottom, Self.bottomPadding)
            }
        }
    }

    private var dragHandle: some View {
        Image("message_chevron_down", bundle: AtomicXChatResources.resourceBundle)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: Self.dragHandleWidth, height: Self.dragHandleHeight)
            .foregroundColor(themeState.colors.strokeColorPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.dragHandleAreaHeight)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
            .background(themeState.colors.bgColorDialog)
    }

    private func emojiGrid(_ emojis: [EmojiData]) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: Self.columns)
        return LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { _, emoji in
                Button(action: { select(emoji) }) {
                    CompatibleKFImage(
                        path: emoji.path,
                        width: Self.emojiGlyphSize,
                        height: Self.emojiGlyphSize,
                        contentMode: .fit,
                        fallback: { AnyView(Color.clear.frame(width: Self.emojiGlyphSize, height: Self.emojiGlyphSize)) }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Self.cellHeight)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func dragGesture(sheetHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height >= sheetHeight * Self.dismissDragThresholdRatio {
                    onDismiss()
                } else {
                    dragOffset = 0
                }
            }
    }

    private func select(_ emoji: EmojiData) {
        onSelectEmoji(emoji)
        onDismiss()
    }
}
