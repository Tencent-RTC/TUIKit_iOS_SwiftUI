import Kingfisher
import SwiftUI
import UIKit

private func chunks<T>(of array: [T], size: Int) -> [[T]] {
    stride(from: 0, to: array.count, by: size).map {
        Array(array[$0..<min($0 + size, array.count)])
    }
}

private struct EmojiCellView: View {
    let emojiData: EmojiData
    let itemWidth: CGFloat
    let onClick: (EmojiData) -> Void
    let fallbackView: () -> AnyView

    var body: some View {
        Button(action: {
            onClick(emojiData)
        }) {
            CompatibleKFImage(
                path: emojiData.path,
                width: itemWidth,
                height: itemWidth,
                fallback: fallbackView
            )
        }
    }
}

public struct EmojiPicker: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var recentEmojis: [EmojiData] = []
    private let onEmojiClick: (EmojiData) -> Void
    private let onSendClick: () -> Void
    private let onDeleteClick: () -> Void

    private var allEmojis: [EmojiData] {
        EmojiConfig.shared.emojiGroups.first?.emojis ?? []
    }

    public init(onEmojiClick: @escaping (EmojiData) -> Void,
                onSendClick: @escaping () -> Void,
                onDeleteClick: @escaping () -> Void)
    {
        _ = EmojiConfig.shared.emojiGroups
        self.onEmojiClick = onEmojiClick
        self.onSendClick = onSendClick
        self.onDeleteClick = onDeleteClick
        loadRecentEmojis()
    }

    private func loadRecentEmojis() {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        let recentIds = EmojiManager.shared.getRecentEmojis()
        let recent = recentIds.compactMap { id in
            allEmojis.first(where: { $0.name == id })
        }
        recentEmojis = recent
    }

    public var body: some View {
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
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !recentEmojis.isEmpty {
                                Text(LocalizedChatString("TUIChatFaceGroupRecentEmojiName"))
                                    .font(.system(size: 14))
                                    .foregroundColor(themeState.colors.textColorSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.top, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(chunks(of: recentEmojis, size: 8), id: \.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(row, id: \.path) { emojiData in
                                            EmojiCellView(
                                                emojiData: emojiData,
                                                itemWidth: itemWidth,
                                                onClick: handleEmojiClick,
                                                fallbackView: fallbackView
                                            )
                                        }
                                        if row.count < 8 {
                                            ForEach(0..<(8 - row.count), id: \.self) { _ in
                                                Color.clear.frame(width: itemWidth, height: itemWidth)
                                            }
                                        }
                                    }
                                }
                            }
                            Text(LocalizedChatString("TUIChatFaceGroupAllEmojiName"))
                                .font(.system(size: 14))
                                .foregroundColor(themeState.colors.textColorSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(chunks(of: allEmojis, size: 8), id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(row, id: \.path) { emojiData in
                                        EmojiCellView(
                                            emojiData: emojiData,
                                            itemWidth: itemWidth,
                                            onClick: handleEmojiClick,
                                            fallbackView: fallbackView
                                        )
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
                    }
                }
                .frame(maxWidth: .infinity)
                .background(themeState.colors.bgColorOperate)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                onDeleteClick()
                            }) {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Colors.Black2)
                                    .frame(width: 50, height: 30)
                                    .background(Colors.White1.opacity(0.9))
                                    .cornerRadius(2)
                            }
                            Button(action: {
                                onSendClick()
                            }) {
                                Text(LocalizedChatString("Send"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Colors.White1)
                                    .frame(width: 50, height: 30)
                                    .background(Colors.ThemeLight6.opacity(0.8))
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            loadRecentEmojis()
        }
    }

    private func handleEmojiClick(_ emojiData: EmojiData) {
        EmojiManager.shared.addRecentEmoji(emojiData)
        onEmojiClick(emojiData)
    }
}
