import Kingfisher
import SwiftUI

private let quickEmojiCount = 6

struct ReactionEmojiPicker: View {
    @EnvironmentObject var themeState: ThemeState
    
    let onEmojiClick: (EmojiData) -> Void
    let onExpandClick: () -> Void
    
    @State private var quickEmojis: [EmojiData] = []
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(quickEmojis, id: \.name) { emoji in
                ReactionEmojiItem(emoji: emoji) {
                    onEmojiClick(emoji)
                }
            }
            
            // "+" expand button
            Button(action: onExpandClick) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .frame(width: 28, height: 28)
                    .background(themeState.colors.dropdownColorDefault)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .background(themeState.colors.dropdownColorDefault)
        .cornerRadius(16)
        .onAppear {
            loadQuickEmojis()
        }
    }
    
    private func loadQuickEmojis() {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        guard !allEmojis.isEmpty else { return }
        
        var result: [EmojiData] = []
        let recentEmojiIds = EmojiManager.shared.getRecentEmojis()
        
        // Add recent emojis first
        for id in recentEmojiIds.prefix(quickEmojiCount) {
            if let emoji = allEmojis.first(where: { $0.name == id }) {
                result.append(emoji)
            }
        }
        
        // Fill with default emojis if needed
        if result.count < quickEmojiCount {
            for emoji in allEmojis {
                if result.count >= quickEmojiCount { break }
                if !result.contains(where: { $0.name == emoji.name }) {
                    result.append(emoji)
                }
            }
        }
        
        quickEmojis = Array(result.prefix(quickEmojiCount))
    }
}

private struct ReactionEmojiItem: View {
    @EnvironmentObject var themeState: ThemeState
    
    let emoji: EmojiData
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            if let path = emoji.path {
                CompatibleKFImage(
                    path: path,
                    width: 24,
                    height: 24,
                    fallback: {
                        AnyView(
                            Image(systemName: "face.smiling")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(themeState.colors.textColorSecondary)
                        )
                    }
                )
                .frame(width: 28, height: 28)
                .background(themeState.colors.dropdownColorDefault)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - ReactionEmojiPickerSheet

private func emojiChunks(of array: [EmojiData], size: Int) -> [[EmojiData]] {
    stride(from: 0, to: array.count, by: size).map {
        Array(array[$0..<min($0 + size, array.count)])
    }
}

struct ReactionEmojiPickerSheet: View {
    @EnvironmentObject var themeState: ThemeState
    
    let onEmojiClick: (EmojiData) -> Void
    
    private var allEmojis: [EmojiData] {
        EmojiConfig.shared.emojiGroups.first?.emojis ?? []
    }
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let itemWidth = totalWidth / 8
            let fallbackView: () -> AnyView = {
                AnyView(
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: itemWidth, height: itemWidth)
                        .foregroundColor(themeState.colors.textColorSecondary)
                )
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(emojiChunks(of: allEmojis, size: 8), id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(row, id: \.path) { emojiData in
                                    Button(action: {
                                        onEmojiClick(emojiData)
                                    }) {
                                        CompatibleKFImage(
                                            path: emojiData.path,
                                            width: itemWidth,
                                            height: itemWidth,
                                            fallback: fallbackView
                                        )
                                    }
                                }
                                if row.count < 8 {
                                    ForEach(0..<(8 - row.count), id: \.self) { _ in
                                        Color.clear.frame(width: itemWidth, height: itemWidth)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .background(themeState.colors.bgColorOperate)
        }
    }
}
