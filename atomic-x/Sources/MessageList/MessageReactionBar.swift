import AtomicXCore
import Kingfisher
import SwiftUI

private let maxDisplayReactions = 5

struct MessageReactionBar: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reactionList: [MessageReaction]
    let isLeft: Bool
    let onClick: () -> Void
    
    var body: some View {
        if reactionList.isEmpty { return AnyView(EmptyView()) }
        
        let displayReactions = Array(reactionList.prefix(maxDisplayReactions))
        let hasMore = reactionList.count > maxDisplayReactions
        
        return AnyView(
            HStack(spacing: 0) {
                if !isLeft {
                    Spacer()
                }
                
                reactionCapsule(displayReactions: displayReactions, hasMore: hasMore)
                
                if isLeft {
                    Spacer()
                }
            }
            .padding(.top, 2)
        )
    }
    
    private func reactionCapsule(displayReactions: [MessageReaction], hasMore: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(displayReactions, id: \.reactionID) { reaction in
                ReactionItem(
                    reaction: reaction,
                    showCount: displayReactions.count == 1
                )
            }
            
            if hasMore {
                Text("...")
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorTertiary)
            }
            
            if displayReactions.count > 1 || hasMore {
                let totalCount = reactionList.reduce(0) { $0 + Int($1.totalUserCount) }
                Text("\(totalCount)")
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeState.colors.bgColorBubbleReciprocal)
        .overlay(
            RoundedRectangle(cornerRadius: 51)
                .stroke(themeState.colors.strokeColorPrimary, lineWidth: 1)
        )
        .cornerRadius(51)
        .onTapGesture {
            onClick()
        }
    }
}

private struct ReactionItem: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reaction: MessageReaction
    let showCount: Bool
    
    private var emojiData: EmojiData? {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        return allEmojis.first(where: { $0.name == reaction.reactionID })
    }
    
    var body: some View {
        HStack(spacing: 2) {
            if let emoji = emojiData, let path = emoji.path {
                CompatibleKFImage(
                    path: path,
                    width: 18,
                    height: 18,
                    fallback: {
                        AnyView(
                            Image(systemName: "face.smiling")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(themeState.colors.textColorSecondary)
                        )
                    }
                )
            }
            
            if showCount && reaction.totalUserCount > 0 {
                Text("\(reaction.totalUserCount)")
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorTertiary)
            }
        }
    }
}
