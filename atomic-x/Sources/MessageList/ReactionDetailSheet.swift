import AtomicXCore
import Kingfisher
import SwiftUI

// MARK: - Half Sheet Modifier for iOS 16+

extension View {
    @ViewBuilder
    func bottomSheet() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

struct ReactionDetailSheet: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reactionList: [MessageReaction]
    let currentUserID: String?
    let onFetchUsers: (String) -> Void
    let onRemoveReaction: (String) -> Void
    
    @State private var selectedReactionID: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Reaction tabs
            if !reactionList.isEmpty {
                ReactionTabRow(
                    reactionList: reactionList,
                    selectedReactionID: selectedReactionID,
                    onTabSelected: { reactionID in
                        selectedReactionID = reactionID
                        onFetchUsers(reactionID)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 26)
                .padding(.bottom, 16)
            }
            
            // User list
            if let selectedReaction = reactionList.first(where: { $0.reactionID == selectedReactionID }) {
                ReactionUserList(
                    reaction: selectedReaction,
                    currentUserID: currentUserID,
                    onRemoveReaction: {
                        onRemoveReaction(selectedReactionID)
                    }
                )
                .padding(.horizontal, 16)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeState.colors.bgColorOperate)
        .onAppear {
            if selectedReactionID.isEmpty, let firstReaction = reactionList.first {
                selectedReactionID = firstReaction.reactionID
                onFetchUsers(firstReaction.reactionID)
            }
        }
    }
}

private struct ReactionTabRow: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reactionList: [MessageReaction]
    let selectedReactionID: String
    let onTabSelected: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(reactionList, id: \.reactionID) { reaction in
                    ReactionTab(
                        reaction: reaction,
                        isSelected: reaction.reactionID == selectedReactionID,
                        onTap: { onTabSelected(reaction.reactionID) }
                    )
                }
            }
        }
    }
}

private struct ReactionTab: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reaction: MessageReaction
    let isSelected: Bool
    let onTap: () -> Void
    
    private var emojiData: EmojiData? {
        let allEmojis = EmojiConfig.shared.emojiGroups.first?.emojis ?? []
        return allEmojis.first(where: { $0.name == reaction.reactionID })
    }
    
    var body: some View {
        HStack(spacing: 4) {
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
            
            Text("\(reaction.totalUserCount)")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? themeState.colors.buttonColorPrimaryDefault : themeState.colors.textColorSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ? themeState.colors.buttonColorPrimaryDefault.opacity(0.1) : themeState.colors.bgColorInput
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? themeState.colors.buttonColorPrimaryDefault : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .cornerRadius(16)
        .onTapGesture {
            onTap()
        }
    }
}

private struct ReactionUserList: View {
    @EnvironmentObject var themeState: ThemeState
    
    let reaction: MessageReaction
    let currentUserID: String?
    let onRemoveReaction: () -> Void
    
    private var sortedUsers: [UserProfile] {
        var users = reaction.partialUserList
        if reaction.reactedByMyself, let currentUserID = currentUserID {
            if let selfIndex = users.firstIndex(where: { $0.userID == currentUserID }), selfIndex > 0 {
                let selfUser = users.remove(at: selfIndex)
                users.insert(selfUser, at: 0)
            }
        }
        return users
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedUsers, id: \.userID) { user in
                    let isSelf = user.userID == currentUserID && reaction.reactedByMyself
                    ReactionUserItem(
                        user: user,
                        isSelf: isSelf,
                        onClick: {
                            if isSelf {
                                onRemoveReaction()
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct ReactionUserItem: View {
    @EnvironmentObject var themeState: ThemeState
    
    let user: UserProfile
    let isSelf: Bool
    let onClick: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Avatar(
                url: user.avatarURL ?? "",
                name: user.nickname ?? user.userID ?? ""
            )
            .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.nickname ?? user.userID ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeState.colors.textColorPrimary)
                
                if isSelf {
                    Text(LocalizedChatString("ChatTap2Remove"))
                        .font(.system(size: 12))
                        .foregroundColor(themeState.colors.textColorTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelf {
                onClick()
            }
        }
    }
}
