import AtomicXCore
import SwiftUI
import UIKit

struct SearchMessageDetailView: View {
    @EnvironmentObject private var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String
    @State private var searchTask: Task<Void, Never>?
    @State private var messageResults: [MessageSearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreResults: Bool = true
    @State private var hasPerformedInitialSearch: Bool = false
    @State private var searchStore: SearchStore
    let conversationID: String
    let conversationName: String
    let conversationAvatar: String?
    let initialKeyword: String
    let onTapItem: (Any) -> Void
    let chatDestination: ((NavigationInfo) -> AnyView)?
    @State private var pendingChat: NavigationInfo? = nil

    init(
        conversationID: String,
        conversationName: String,
        conversationAvatar: String?,
        keyword: String,
        onTapItem: @escaping (Any) -> Void,
        chatDestination: ((NavigationInfo) -> AnyView)? = nil
    ) {
        self.conversationID = conversationID
        self.conversationName = conversationName
        self.conversationAvatar = conversationAvatar
        self.initialKeyword = keyword
        self.onTapItem = onTapItem
        self.chatDestination = chatDestination
        self._searchStore = State(initialValue: SearchStore.create())
        self._searchText = State(initialValue: keyword)
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
            if !initialKeyword.isEmpty && !hasPerformedInitialSearch {
                hasPerformedInitialSearch = true
                performSearch(initialKeyword)
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.messageResults))) { messageResults in
            self.messageResults = messageResults
            self.isSearching = false
        }
        .onReceive(searchStore.state.subscribe(StatePublisherSelector(keyPath: \SearchState.hasMoreMessageResults))) { hasMore in
            self.hasMoreResults = hasMore
            self.isLoadingMore = false
        }
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
            .padding(.leading, CGFloat(SpacingScheme.iconTextSpacing))
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        .background(themeState.colors.bgColorOperate)
    }

    private func buildBody() -> some View {
        let conversationMessages = messageResults.flatMap { $0.messageList }
        return Group {
            if isSearching && conversationMessages.isEmpty {
                buildLoadingBody()
            } else {
                buildContentWithHeader(messages: conversationMessages)
            }
        }
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

    private func buildContentWithHeader(messages: [MessageInfo]) -> some View {
        VStack(spacing: 0) {
            buildConversationHeader()
            HStack {
                Divider()
                    .frame(height: 0.5)
                    .background(themeState.colors.strokeColorPrimary)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            buildMessagesList(messages: messages)
        }
    }

    private func buildConversationHeader() -> some View {
        Button {
            let conversationInfo: [String: Any] = [
                "conversationID": conversationID,
                "conversationName": conversationName,
                "conversationAvatar": conversationAvatar
            ]
            openChat(conversationInfo)
        } label: {
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                buildConversationAvatar()
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    Text(conversationName)
                        .font(FontScheme.caption1Bold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func buildConversationAvatar() -> some View {
        AvatarView(
            url: conversationAvatar,
            name: conversationName,
            size: .m
        )
        .environmentObject(themeState)
    }

    private func buildMessagesList(messages: [MessageInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages.indices, id: \.self) { index in
                    buildMessageItem(message: messages[index])
                        .onAppear {
                            if index == messages.count - 3 {
                                loadMoreIfNeeded()
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

    private func buildMessageItem(message: MessageInfo) -> some View {
        return Button {
            let result: [String: Any] = [
                "message": message,
                "conversationID": conversationID,
                "conversationName": conversationName,
                "conversationAvatar": conversationAvatar
            ]
            openChat(result)
        } label: {
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                AvatarView(
                    url: message.from.avatarURL,
                    name: ChatUtil.getMessageSenderName(message),
                    size: .m
                )
                .environmentObject(themeState)
                .frame(width: 40, height: 40)
                .clipped()
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    buildHighlightedText(
                        text: ChatUtil.getMessageSenderName(message),
                        keyword: "",
                        isTitle: true
                    )
                    buildHighlightedText(
                        text: MessageListView.getMessageAbstract(message, showMergedTitle: true),
                        keyword: searchText,
                        isTitle: false
                    )
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
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
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        )
    }

    private func loadMoreIfNeeded() {
        guard !isLoadingMore, hasMoreResults else {
            return
        }
        isLoadingMore = true
        searchStore.searchMore(searchType: .message) { _ in }
    }

    private func performSearch(_ text: String) {
        guard !text.isEmpty else { return }
        isSearching = true
        var option = SearchOption()
        option.searchScope = [.message]
        option.pageSize = 10
        var messageFilter = MessageSearchFilter()
        messageFilter.conversationID = conversationID
        option.messageFilter = messageFilter
        searchStore.search(keywordList: [text], option: option) { _ in }
    }

    private func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if text.isEmpty {
                await MainActor.run {
                    messageResults = []
                    isSearching = false
                }
            } else {
                await MainActor.run {
                    isSearching = true
                }
                var option = SearchOption()
                option.searchScope = [.message]
                option.pageSize = 10
                var messageFilter = MessageSearchFilter()
                messageFilter.conversationID = conversationID
                option.messageFilter = messageFilter
                searchStore.search(keywordList: [text], option: option) { _ in }
            }
        }
    }
}
