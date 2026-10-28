import AtomicXCore
import SwiftUI
import UIKit

struct SearchResultView: View {
    @EnvironmentObject private var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAutoFocusedSearchField = false
    @State private var selectedConversationForDetail: MessageSearchResultItem?
    @State private var selectedMoreView: (searchType: SearchType, keyword: String)?
    @State private var searchTask: Task<Void, Never>?
    @State private var friendList: [FriendSearchInfo] = []
    @State private var groupList: [GroupSearchInfo] = []
    @State private var messageResults: [MessageSearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    let onTapItem: (Any) -> Void
    let chatDestination: ((NavigationInfo) -> AnyView)?
    @State private var pendingChat: NavigationInfo? = nil
    @State private var searchStore: SearchStore

    internal init(onTapItem: @escaping (Any) -> Void, chatDestination: ((NavigationInfo) -> AnyView)? = nil) {
        self.onTapItem = onTapItem
        self.chatDestination = chatDestination
        self._searchStore = State(initialValue: SearchStore.create())
    }

    func openChat(_ result: Any) {
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
        .background(themeState.colors.bgColorDefault.ignoresSafeArea())
        .onAppear {
            guard !hasAutoFocusedSearchField else { return }
            hasAutoFocusedSearchField = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchTask?.cancel()
            isSearchFieldFocused = false
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
                            onTapItem: onTapItem,
                            chatDestination: chatDestination
                        )
                        .environmentObject(themeState)
                    } else if let moreView = selectedMoreView {
                        SearchResultMoreView(
                            searchType: moreView.searchType,
                            keyword: moreView.keyword,
                            onTapItem: onTapItem,
                            chatDestination: chatDestination
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
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            HStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                Image(systemName: "magnifyingglass")
                    .font(FontScheme.caption2Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                TextField("", text: $searchText, prompt: Text(LocalizedChatString("Search")).foregroundColor(themeState.colors.textColorTertiary))
                    .font(themeState.fonts.caption2Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .accentColor(themeState.colors.textColorLink)
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { newValue in
                        onSearchTextChanged(newValue)
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image("contact_search_clear", bundle: AtomicXChatResources.resourceBundle)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(height: 40)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
            Button(action: {
                searchText = ""
                onSearchTextChanged("")
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LocalizedChatString("Cancel"))
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
        .padding(.bottom, CGFloat(SpacingScheme.bubbleSpacing))
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
        VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(themeState.colors.textColorSecondary)
            Text(LocalizedChatString("SearchNoResultInConversation"))
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func buildSearchResults() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !friendList.isEmpty {
                    friendSection
                }
                if !groupList.isEmpty {
                    groupSection
                }
                if !messageResults.isEmpty {
                    messageSection
                }
            }
        }
        .background(themeState.colors.bgColorDefault)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10).onChanged { _ in
                searchDismissKeyboard()
            }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(themeState.colors.bgColorDefault).frame(height: 1)
            Text(title)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.bottom, 2)
                .background(themeState.colors.bgColorOperate)
        }
    }

    private func moreFooterRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorLink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .background(themeState.colors.bgColorOperate)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func resultRow<Subtitle: View>(avatarURL: String?, avatarName: String, title: String, action: @escaping () -> Void, @ViewBuilder subtitle: () -> Subtitle) -> some View {
        Button(action: {
            searchDismissKeyboard()
            action()
        }) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    AvatarView(url: avatarURL, name: avatarName, size: .m, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                        .environmentObject(themeState)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        buildHighlightedText(text: title, keyword: searchText, fontSize: UIKitFontScheme.caption1Regular.pointSize, normalColor: themeState.colors.textColorPrimary)
                        subtitle()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                Rectangle()
                    .fill(themeState.colors.strokeColorPrimary)
                    .frame(height: 0.5)
                    .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                    .padding(.bottom, 3)
            }
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var friendSection: some View {
        VStack(spacing: 0) {
            sectionHeader(LocalizedChatString("SearchItemHeaderTitleContact"))
            ForEach(Array(friendList.prefix(3)), id: \.userID) { friend in
                resultRow(avatarURL: friend.userInfo?.avatarURL, avatarName: getFriendDisplayName(friend), title: getFriendDisplayName(friend), action: { openChat(friend) }) {
                    buildHighlightedText(text: "ID: \(friend.userID)", keyword: searchText, fontSize: UIKitFontScheme.caption2Regular.pointSize, normalColor: themeState.colors.textColorTertiary)
                }
            }
            if friendList.count > 3 {
                moreFooterRow(LocalizedChatString("SearchItemFooterTitleContact")) { selectedMoreView = (searchType: .friend, keyword: searchText) }
            }
        }
    }

    private var groupSection: some View {
        VStack(spacing: 0) {
            sectionHeader(LocalizedChatString("SearchItemHeaderTitleGroup"))
            ForEach(Array(groupList.prefix(3)), id: \.groupID) { group in
                let displayName = (group.groupName ?? "").isEmpty ? group.groupID : (group.groupName ?? group.groupID)
                resultRow(avatarURL: group.groupAvatarURL, avatarName: displayName, title: displayName, action: { openChat(group) }) {
                    buildHighlightedText(text: String(format: LocalizedChatString("SearchResultGroupIDFormat"), group.groupID), keyword: searchText, fontSize: UIKitFontScheme.caption2Regular.pointSize, normalColor: themeState.colors.textColorTertiary)
                }
            }
            if groupList.count > 3 {
                moreFooterRow(LocalizedChatString("SearchItemFooterTitleGroup")) { selectedMoreView = (searchType: .group, keyword: searchText) }
            }
        }
    }

    private var messageSection: some View {
        VStack(spacing: 0) {
            sectionHeader(LocalizedChatString("SearchItemHeaderTitleChatHistory"))
            ForEach(Array(messageResults.prefix(3)), id: \.conversationID) { item in
                resultRow(avatarURL: item.conversationAvatarURL, avatarName: item.conversationShowName, title: item.conversationShowName, action: {
                    isSearchFieldFocused = false
                    selectedConversationForDetail = item
                }) {
                    if item.messageCount > 1 {
                        Text(String(format: LocalizedChatString("SearchResultDisplayChatHistoryCountFormat"), item.messageCount))
                            .font(themeState.fonts.caption2Regular)
                            .foregroundColor(themeState.colors.textColorTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        let abstract = item.messageList.first.map { MessageListView.getMessageAbstract($0) } ?? ""
                        buildHighlightedText(text: abstract, keyword: searchText, fontSize: UIKitFontScheme.caption2Regular.pointSize, normalColor: themeState.colors.textColorTertiary)
                    }
                }
            }
            if messageResults.count > 3 {
                moreFooterRow(LocalizedChatString("SearchItemFooterTitleChatHistory")) {
                    isSearchFieldFocused = false
                    selectedMoreView = (searchType: .message, keyword: searchText)
                }
            }
        }
    }

    private func buildHighlightedText(text: String, keyword: String, fontSize: CGFloat, normalColor: Color) -> AnyView {
        let attributedString = SearchHighlightBuilder.attributedTextWithEmoji(
            text: text,
            keyword: keyword,
            fontSize: fontSize,
            normalColor: UIColor(normalColor),
            highlightColor: UIColor(themeState.colors.textColorLink)
        )
        return AnyView(
            UILabelWrapper(attributedString: attributedString)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }


    private func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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

}

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
