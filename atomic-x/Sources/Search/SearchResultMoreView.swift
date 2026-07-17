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
    private var searchStore: SearchStore

    init(searchType: SearchType, keyword: String, onTapItem: @escaping (Any) -> Void) {
        self.searchType = searchType
        self.initialKeyword = keyword
        self.onTapItem = onTapItem
        self._searchText = State(initialValue: keyword)
        self.searchStore = SearchStore.create()
    }

    public var body: some View {
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
            self.friendList = friendList
            self.isSearching = false
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.groupList))) { groupList in
            self.groupList = groupList
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.messageResults))) { messageResults in
            self.messageResults = messageResults
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.hasMoreMessageResults))) { hasMore in
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
                            onTapItem: onTapItem
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
    }

    private func buildNavigationBar() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .font(.system(size: 20))
                TextField(LocalizedChatString("Search"), text: $searchText, onEditingChanged: { _ in }) {
                    onSearchTextChanged(searchText)
                }
                .font(.system(size: 16))
                .foregroundColor(themeState.colors.textColorPrimary)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { newValue in
                    onSearchTextChanged(newValue)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(10)
            Button(action: {
                searchText = ""
                onSearchTextChanged("")
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LocalizedChatString("Cancel"))
                    .font(.system(size: 17))
                    .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.leading, 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    private func buildResultsList() -> some View {
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
                            .padding(.all, 8)
                        Spacer()
                    }
                }
            }
        }
    }

    private func buildFriendResultItem(result: FriendSearchInfo) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                onTapItem(result)
            }) {
                HStack(spacing: 12) {
                    Avatar(
                        url: result.userInfo?.avatarURL,
                        name: getFriendDisplayName(result),
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: 4) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
                onTapItem(result)
            }) {
                HStack(spacing: 12) {
                    Avatar(
                        url: result.groupAvatarURL,
                        name: displayName,
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: 4) {
                        buildHighlightedText(
                            text: displayName,
                            keyword: searchText,
                            isTitle: true
                        )
                        // Show "Contains group ID: xxx" if group ID matches but name doesn't
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeState.colors.bgColorTopBar)
            }
            .buttonStyle(PlainButtonStyle())
            buildDivider()
        }
    }

    private func buildMessageResultItem(result: MessageSearchResultItem) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                selectedConversationForDetail = result
            }) {
                HStack(spacing: 12) {
                    Avatar(
                        url: result.conversationAvatarURL,
                        name: result.conversationShowName,
                        size: .m
                    )
                    .environmentObject(themeState)
                    .frame(width: 40, height: 40)
                    .clipped()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.conversationShowName)
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: LocalizedChatString("SearchResultDisplayChatHistoryCountFormat"), result.messageCount))
                            .font(.system(size: 14))
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeState.colors.bgColorTopBar)
            }
            .buttonStyle(PlainButtonStyle())
            buildDivider()
        }
    }

    private func buildDivider() -> some View {
        HStack {
            Spacer()
                .frame(width: 16 + 40 + 16) // leadingPadding + avatarWidth + titleLeftPadding
            Divider()
                .frame(height: 0.5)
                .background(themeState.colors.strokeColorPrimary)
        }
    }

    private func buildHighlightedText(text: String, keyword: String, isTitle: Bool) -> AnyView {
        let fontSize: CGFloat = isTitle ? 16 : 14
        let color = isTitle ? themeState.colors.textColorPrimary : themeState.colors.textColorSecondary
        let highlightColor = themeState.colors.textColorLink
        if keyword.isEmpty || !text.lowercased().contains(keyword.lowercased()) {
            return AnyView(
                Text(text)
                    .font(.system(size: fontSize))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
        let attributedString = NSMutableAttributedString(string: text)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(color),
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(highlightColor),
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        attributedString.addAttributes(normalAttributes, range: NSRange(location: 0, length: text.count))

        let lowercasedText = text.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        var searchRange = NSRange(location: 0, length: lowercasedText.count)
        while searchRange.location < lowercasedText.count {
            let foundRange = (lowercasedText as NSString).range(of: lowercasedKeyword, options: [], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            attributedString.addAttributes(highlightAttributes, range: foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = lowercasedText.count - searchRange.location
        }

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

    private func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            if text.isEmpty {
                await MainActor.run {
                    friendList = []
                    groupList = []
                    messageResults = []
                    isSearching = false
                }
            } else {
                await MainActor.run {
                    isSearching = true
                }
                var option = SearchOption()
                option.searchScope = [searchType]
                option.pageSize = 20
                searchStore.search(keywordList: [text], option: option) { _ in }
            }
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
