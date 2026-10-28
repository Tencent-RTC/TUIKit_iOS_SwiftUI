import AtomicXCore
import SwiftUI

func searchDismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

func searchResultNavigationInfo(_ result: Any) -> NavigationInfo? {
    if let friendInfo = result as? FriendSearchInfo {
        let conversationID = ChatUtil.getC2CConversationID(friendInfo.userID)
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = .c2c
        conversation.title = friendInfo.friendRemark ?? friendInfo.userInfo?.nickname ?? friendInfo.userID
        conversation.avatarURL = friendInfo.userInfo?.avatarURL
        return NavigationInfo(conversation: conversation)
    }
    if let groupInfo = result as? GroupSearchInfo {
        let conversationID = ChatUtil.getGroupConversationID(groupInfo.groupID)
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = .group
        conversation.title = groupInfo.groupName
        conversation.avatarURL = groupInfo.groupAvatarURL
        return NavigationInfo(conversation: conversation)
    }
    if let messageDict = result as? [String: Any],
       let messageInfo = messageDict["message"] as? MessageInfo,
       let conversationID = messageDict["conversationID"] as? String
    {
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = conversationID.hasPrefix("c2c_") ? .c2c : .group
        conversation.title = messageDict["conversationName"] as? String
        conversation.avatarURL = messageDict["conversationAvatar"] as? String
        return NavigationInfo(conversation: conversation, locateMessage: messageInfo)
    }
    if let conversationDict = result as? [String: Any],
       let conversationID = conversationDict["conversationID"] as? String
    {
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = conversationID.hasPrefix("c2c_") ? .c2c : .group
        conversation.title = conversationDict["conversationName"] as? String
        conversation.avatarURL = conversationDict["conversationAvatar"] as? String
        return NavigationInfo(conversation: conversation)
    }
    return nil
}

struct SearchBarImpl: View {
    @EnvironmentObject private var themeState: ThemeState
    @State private var isSearchActive = false
    let onTapItem: (Any) -> Void
    let chatDestination: ((NavigationInfo) -> AnyView)?
    let preservesSearchOnSelection: Bool

    init(onTapItem: @escaping (Any) -> Void, chatDestination: ((NavigationInfo) -> AnyView)? = nil, preservesSearchOnSelection: Bool = false) {
        self.onTapItem = onTapItem
        self.chatDestination = chatDestination
        self.preservesSearchOnSelection = preservesSearchOnSelection
    }

    var body: some View {
        NavigationLink(
            destination: SearchResultView(onTapItem: { result in
                searchDismissKeyboard()
                if chatDestination == nil {
                    if !preservesSearchOnSelection {
                        isSearchActive = false
                    }
                    onTapItem(result)
                }
            }, chatDestination: chatDestination)
            .environmentObject(themeState),
            isActive: $isSearchActive
        ) {
            HStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .font(FontScheme.caption1Regular)
                Text(LocalizedChatString("Search"))
                    .font(FontScheme.caption2Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(CGFloat(RadiusScheme.alertRadius))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
    }
}
