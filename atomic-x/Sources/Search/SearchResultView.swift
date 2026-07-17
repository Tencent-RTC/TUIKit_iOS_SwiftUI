import AtomicXCore
import SwiftUI
import UIKit

struct SearchResultView: View {
    @EnvironmentObject private var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var selectedConversationForDetail: MessageSearchResultItem?
    @State private var selectedMoreView: (searchType: SearchType, keyword: String)?
    @State private var searchTask: Task<Void, Never>?
    @State private var friendList: [FriendSearchInfo] = []
    @State private var groupList: [GroupSearchInfo] = []
    @State private var messageResults: [MessageSearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    let onTapItem: (Any) -> Void
    private var searchStore: SearchStore

    public init(onTapItem: @escaping (Any) -> Void) {
        self.onTapItem = onTapItem
        self.searchStore = SearchStore.create()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar with Search
            buildNavigationBar()
            // Search Results Body
            buildBody()
        }
        .navigationBarHidden(true)
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear {
            // Auto focus on search field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.friendList))) { friendList in
            self.friendList = friendList
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.groupList))) { groupList in
            self.groupList = groupList
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.messageResults))) { messageResults in
            self.messageResults = messageResults
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
                    } else if let moreView = selectedMoreView {
                        SearchResultMoreView(
                            searchType: moreView.searchType,
                            keyword: moreView.keyword,
                            onTapItem: onTapItem
                        )
                        .environmentObject(themeState)
                    }
                },
                isActive: Binding(
                    get: { selectedConversationForDetail != nil || selectedMoreView != nil },
                    set: { if !$0 {
                        selectedConversationForDetail = nil
                        selectedMoreView = nil
                    } }
                )
            ) {
                EmptyView()
            }
        )
    }

    private func buildNavigationBar() -> some View {
        HStack(spacing: 0) {
            // Search Input Container
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
                .focused($isSearchFieldFocused)
                .onChange(of: searchText) { newValue in
                    onSearchTextChanged(newValue)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(10)
            // Cancel Button
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
        Group {
            if searchText.isEmpty {
                buildInitialBody()
            } else if isSearching {
                buildLoadingBody()
            } else if hasSearchResults() {
                buildSearchResults()
            } else if hasSearched {
                buildNoResultsBody()
            } else {
                buildLoadingBody()
            }
        }
    }

    private func buildInitialBody() -> some View {
        // Empty state when no search is performed
        Color.clear
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

    private func buildNoResultsBody() -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(themeState.colors.textColorSecondary)
            Text("无法找到相关结果") // TODO: Add to localization when available
                .font(.system(size: 16))
                .foregroundColor(themeState.colors.textColorSecondary)
            Spacer()
        }
    }

    private func buildSearchResults() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Display search results by type
                if !friendList.isEmpty {
                    buildFriendResultSection(
                        title: LocalizedChatString("SearchItemHeaderTitleContact"),
                        results: friendList
                    )
                }
                if !groupList.isEmpty {
                    buildGroupResultSection(
                        title: LocalizedChatString("SearchItemHeaderTitleGroup"),
                        results: groupList
                    )
                }
                if !messageResults.isEmpty {
                    buildMessageResultSection(
                        title: LocalizedChatString("SearchItemHeaderTitleChatHistory"),
                        results: messageResults
                    )
                }
            }
            .padding(.top, 8)
        }
    }

    private func buildFriendResultSection(title: String, results: [FriendSearchInfo]) -> some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                if results.count > 3 {
                    Button(action: {
                        selectedMoreView = (searchType: .friend, keyword: searchText)
                    }) {
                        Text(LocalizedChatString("SearchItemFooterTitleContact"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            let displayResults = results.count > 3 ? Array(results.prefix(3)) : results
            ForEach(displayResults.indices, id: \.self) { index in
                buildFriendResultItem(result: displayResults[index])
            }
        }
        .padding(.bottom, 16)
    }

    private func buildGroupResultSection(title: String, results: [GroupSearchInfo]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                if results.count > 3 {
                    Button(action: {
                        selectedMoreView = (searchType: .group, keyword: searchText)
                    }) {
                        Text(LocalizedChatString("SearchItemFooterTitleGroup"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            let displayResults = results.count > 3 ? Array(results.prefix(3)) : results
            ForEach(displayResults.indices, id: \.self) { index in
                buildGroupResultItem(result: displayResults[index])
            }
        }
        .padding(.bottom, 16)
    }

    private func buildMessageResultSection(title: String, results: [MessageSearchResultItem]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                if results.count > 3 {
                    Button(action: {
                        selectedMoreView = (searchType: .message, keyword: searchText)
                    }) {
                        Text(LocalizedChatString("SearchItemFooterTitleChatHistory"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            let displayResults = results.count > 3 ? Array(results.prefix(3)) : results
            ForEach(displayResults.indices, id: \.self) { index in
                buildMessageResultItem(result: displayResults[index])
            }
        }
        .padding(.bottom, 16)
    }

    private func buildFriendResultItem(result: FriendSearchInfo) -> some View {
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
    }

    private func buildGroupResultItem(result: GroupSearchInfo) -> some View {
        let resolvedGroupName = result.groupName ?? ""
        let displayName = resolvedGroupName.isEmpty ? result.groupID : resolvedGroupName
        let nameContainsKeyword = displayName.lowercased().contains(searchText.lowercased())
        let groupIDContainsKeyword = result.groupID.lowercased().contains(searchText.lowercased())

        return Button(action: {
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
    }

    private func buildMessageResultItem(result: MessageSearchResultItem) -> some View {
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
        // Create attributed text with highlighting
        let attributedString = NSMutableAttributedString(string: text)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(color),
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(highlightColor),
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        // Apply normal attributes to the entire string first
        attributedString.addAttributes(normalAttributes, range: NSRange(location: 0, length: text.count))
        // Find and highlight keyword occurrences
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
        // Use UILabel for attributed text compatibility with iOS 14
        return AnyView(
            UILabelWrapper(attributedString: attributedString)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    // MARK: - Helper Methods

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
                    hasSearched = false
                }
            } else {
                await MainActor.run {
                    isSearching = true
                    hasSearched = false
                }
                var option = SearchOption()
                option.searchScope = [.friend, .group, .message]
                option.pageSize = 20
                searchStore.search(keywordList: [text], option: option) { _ in
                    DispatchQueue.main.async {
                        self.isSearching = false
                        self.hasSearched = true
                    }
                }
            }
        }
    }

    private func hasSearchResults() -> Bool {
        return !friendList.isEmpty || !groupList.isEmpty || !messageResults.isEmpty
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
        // Extract conversation name from conversationID
        // Format: c2c_userID or group_groupID
        let conversationID = item.conversationID
        if conversationID.hasPrefix("c2c_") {
            return String(conversationID.dropFirst(4))
        } else if conversationID.hasPrefix("group_") {
            return String(conversationID.dropFirst(6))
        }
        return conversationID
    }
}

// UILabelWrapper for iOS 14 compatibility with attributed text
struct UILabelWrapper: UIViewRepresentable {
    let attributedString: NSAttributedString
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = attributedString
    }
}
