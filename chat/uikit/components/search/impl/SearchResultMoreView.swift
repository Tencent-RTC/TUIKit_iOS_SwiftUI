import AtomicXCore
import SwiftUI
import UIKit

struct SearchResultMoreView: View {
    @EnvironmentObject private var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String
    @State private var selectedConversationForDetail: MessageSearchResultItem?
    @State private var searchTask: Task<Void, Never>?
    @State private var friendList: [FriendSearchInfo] = []
    @State private var groupList: [GroupSearchInfo] = []
    @State private var messageResults: [MessageSearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreResults: Bool = true
    @State private var hasPerformedInitialSearch: Bool = false
    let searchType: SearchType
    let initialKeyword: String
    let onTapItem: (Any) -> Void
    let chatDestination: ((NavigationInfo) -> AnyView)?
    @State private var pendingChat: NavigationInfo? = nil
    @State private var searchStore: SearchStore

    init(searchType: SearchType, keyword: String, onTapItem: @escaping (Any) -> Void, chatDestination: ((NavigationInfo) -> AnyView)? = nil) {
        self.searchType = searchType
        self.initialKeyword = keyword
        self.onTapItem = onTapItem
        self.chatDestination = chatDestination
        self._searchText = State(initialValue: keyword)
        self._searchStore = State(initialValue: SearchStore.create())
    }

    private func openChat(_ result: Any) {
        if chatDestination != nil, let info = searchResultNavigationInfo(result) {
            searchDismissKeyboard()
            pendingChat = info
        } else {
            onTapItem(result)
        }
    }

    internal var body: some View {
        VStack(spacing: 0) {
            buildNavigationBar()
            buildBody()
        }
        .navigationBarHidden(true)
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear {
            if !hasPerformedInitialSearch {
                hasPerformedInitialSearch = true
                onSearchTextChanged(initialKeyword)
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.friendList))) { friendList in
            guard !searchText.isEmpty else { return }
            self.friendList = friendList
            self.isSearching = false
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.groupList))) { groupList in
            guard !searchText.isEmpty else { return }
            self.groupList = groupList
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.messageResults))) { messageResults in
            guard !searchText.isEmpty else { return }
            self.messageResults = messageResults
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.hasMoreMessageResults))) { hasMore in
            guard !searchText.isEmpty else { return }
            self.hasMoreResults = hasMore
            self.isLoadingMore = false
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let messageItem = selectedConversationForDetail {
                        SearchMessageDetailView(
                            conversationID: messageItem.conversationID,
                            conversationName: messageItem.conversationShowName,
                            conversationAvatar: messageItem.conversationAvatarURL,
                            keyword: searchText,
                            onTapItem: onTapItem,
                            chatDestination: chatDestination
                        )
                        .environmentObject(themeState)
                    }
                },
                isActive: Binding(
                    get: { selectedConversationForDetail != nil },
                    set: { if !$0 { selectedConversationForDetail = nil } }
                )
            ) {
                EmptyView()
            }
        )
        .background(
            NavigationLink(
                destination: Group {
                    if let info = pendingChat, let chatDestination = chatDestination {
                        chatDestination(info)
                    }
                },
                isActive: Binding(
                    get: { pendingChat != nil },
                    set: { if !$0 { pendingChat = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    private func buildNavigationBar() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .font(FontScheme.body3Regular)
                TextField(LocalizedChatString("Search"), text: $searchText, onEditingChanged: { _ in }) {
                    onSearchTextChanged(searchText)
                }
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { newValue in
                    onSearchTextChanged(newValue)
                }
                if !searchText.isEmpty {
                    Button(action: clearSearchText) {
                        if let icon = AtomicXChatResources.image(named: "contact_search_clear") {
                            Image(uiImage: icon)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
            .frame(height: 36)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(CGFloat(RadiusScheme.alertRadius))
            Button(action: {
                searchText = ""
                onSearchTextChanged("")
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LocalizedChatString("Cancel"))
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.leading, CGFloat(SpacingScheme.bubbleSpacing))
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        .background(themeState.colors.bgColorOperate)
    }

    private func buildBody() -> some View {
        return Group {
            if isSearching && getCurrentResults().isEmpty {
                buildLoadingBody()
            } else {
                buildResultsList()
            }
        }
    }

    private func getCurrentResults() -> [Any] {
        if searchType == .friend {
            return friendList
        } else if searchType == .group {
            return groupList
        } else if searchType == .message {
            return messageResults
        }
        return []
    }

    private func buildLoadingBody() -> some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Spacer()
        }
    }

    private var sectionTitle: String {
        switch searchType {
        case .friend: return LocalizedChatString("SearchItemHeaderTitleContact")
        case .group: return LocalizedChatString("SearchItemHeaderTitleGroup")
        case .message: return LocalizedChatString("SearchItemHeaderTitleChatHistory")
        default: return ""
        }
    }

    private func buildResultsList() -> some View {
        VStack(spacing: 0) {
            if !isSearching && !getCurrentResults().isEmpty {
                Text(sectionTitle)
                    .font(themeState.fonts.body2Bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                    .padding(.top, CGFloat(SpacingScheme.smallSpacing))
                    .padding(.bottom, CGFloat(SpacingScheme.iconTextSpacing))
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                if searchType == .friend {
                    ForEach(friendList.indices, id: \.self) { index in
                        buildFriendResultItem(result: friendList[index])
                    }
                } else if searchType == .group {
                    ForEach(groupList.indices, id: \.self) { index in
                        buildGroupResultItem(result: groupList[index])
                    }
                } else if searchType == .message {
                    ForEach(messageResults.indices, id: \.self) { index in
                        buildMessageResultItem(result: messageResults[index])
                            .onAppear {
                                if index == messageResults.count - 3 {
                                    loadMoreIfNeeded()
                                }
                            }
                    }
                }
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.all, CGFloat(SpacingScheme.smallSpacing))
                        Spacer()
                    }
                }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10).onChanged { _ in
                    searchDismissKeyboard()
                }
            )
        }
    }

    private func buildFriendResultItem(result: FriendSearchInfo) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                openChat(result)
            }) {
                HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                    AvatarView(
                        url: result.userInfo?.avatarURL,
                        name: getFriendDisplayName(result),
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                        buildHighlightedText(
                            text: getFriendDisplayName(result),
                            keyword: searchText,
                            isTitle: true
                        )
                        buildHighlightedText(
                            text: "ID:\(result.userID)",
                            keyword: searchText,
                            isTitle: false
                        )
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .background(themeState.colors.bgColorTopBar)
            }
            .buttonStyle(PlainButtonStyle())
            buildDivider()
        }
    }

    private func buildGroupResultItem(result: GroupSearchInfo) -> some View {
        let resolvedGroupName = result.groupName ?? ""
        let displayName = resolvedGroupName.isEmpty ? result.groupID : resolvedGroupName
        let nameContainsKeyword = displayName.lowercased().contains(searchText.lowercased())
        let groupIDContainsKeyword = result.groupID.lowercased().contains(searchText.lowercased())

        return VStack(spacing: 0) {
            Button(action: {
                openChat(result)
            }) {
                HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                    AvatarView(
                        url: result.groupAvatarURL,
                        name: displayName,
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                        buildHighlightedText(
                            text: displayName,
                            keyword: searchText,
                            isTitle: true
                        )
                        if !nameContainsKeyword && groupIDContainsKeyword {
                            buildHighlightedText(
                                text: String(format: LocalizedChatString("SearchResultMatchGroupIDFormat"), result.groupID),
                                keyword: searchText,
                                isTitle: false
                            )
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .background(themeState.colors.bgColorTopBar)
            }
            .buttonStyle(PlainButtonStyle())
            buildDivider()
        }
    }

    private func buildMessageResultItem(result: MessageSearchResultItem) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                searchDismissKeyboard()
                selectedConversationForDetail = result
            }) {
                HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                    AvatarView(
                        url: result.conversationAvatarURL,
                        name: result.conversationShowName,
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                        Text(result.conversationShowName)
                            .font(FontScheme.caption1Regular)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: LocalizedChatString("SearchResultDisplayChatHistoryCountFormat"), result.messageCount))
                            .font(FontScheme.caption2Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .background(themeState.colors.bgColorTopBar)
            }
            .buttonStyle(PlainButtonStyle())
            buildDivider()
        }
    }

    private func buildDivider() -> some View {
        HStack {
            Spacer()
                .frame(width: 16 + 40 + 16)
            Divider()
                .frame(height: 0.5)
                .background(themeState.colors.strokeColorPrimary)
        }
    }

    private func buildHighlightedText(text: String, keyword: String, isTitle: Bool) -> AnyView {
        let fontSize = isTitle ? UIKitFontScheme.caption1Regular.pointSize : UIKitFontScheme.caption2Regular.pointSize
        let color = isTitle ? themeState.colors.textColorPrimary : themeState.colors.textColorSecondary
        let highlightColor = themeState.colors.textColorLink
        let attributedString = SearchHighlightBuilder.attributedTextWithEmoji(
            text: text,
            keyword: keyword,
            fontSize: fontSize,
            normalColor: UIColor(color),
            highlightColor: UIColor(highlightColor)
        )
        return AnyView(
            UILabelWrapper(attributedString: attributedString)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    private func loadMoreIfNeeded() {
        guard searchType == .message,
              !isLoadingMore,
              hasMoreResults
        else {
            return
        }
        isLoadingMore = true
        searchStore.searchMore(searchType: .message) { _ in }
    }

    private func clearSearchText() {
        searchText = ""
    }

    private func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        if text.isEmpty {
            friendList = []
            groupList = []
            messageResults = []
            isSearching = false
            isLoadingMore = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isSearching = true
            }
            var option = SearchOption()
            option.searchScope = [searchType]
            option.pageSize = 20
            searchStore.search(keywordList: [text], option: option) { _ in }
        }
    }

    private func getFriendDisplayName(_ friend: FriendSearchInfo) -> String {
        if let remark = friend.friendRemark, !remark.isEmpty {
            return remark
        }
        if let nickname = friend.userInfo?.nickname, !nickname.isEmpty {
            return nickname
        }
        return friend.userID
    }

    private func getConversationName(for item: MessageSearchResultItem) -> String {
        let conversationID = item.conversationID
        if conversationID.hasPrefix("c2c_") {
            return String(conversationID.dropFirst(4))
        } else if conversationID.hasPrefix("group_") {
            return String(conversationID.dropFirst(6))
        }
        return conversationID
    }
}
