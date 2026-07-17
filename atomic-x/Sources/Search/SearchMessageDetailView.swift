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

    init(
        conversationID: String,
        conversationName: String,
        conversationAvatar: String?,
        keyword: String,
        onTapItem: @escaping (Any) -> Void
    ) {
        self.conversationID = conversationID
        self.conversationName = conversationName
        self.conversationAvatar = conversationAvatar
        self.initialKeyword = keyword
        self.onTapItem = onTapItem
        self._searchStore = State(initialValue: SearchStore.create())
        self._searchText = State(initialValue: keyword)
    }

    public var body: some View {
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
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeState.colors.bgColorOperate)
    }

    private func buildBody() -> some View {
        // Merge all message lists from paginated results
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
            .padding(.horizontal, 16)
            buildMessagesList(messages: messages)
        }
    }

    private func buildConversationHeader() -> some View {
        Button {
            // Pass conversation info to callback
            let conversationInfo: [String: Any] = [
                "conversationID": conversationID,
                "conversationName": conversationName,
                "conversationAvatar": conversationAvatar
            ]
            onTapItem(conversationInfo)
        } label: {
            HStack(spacing: 12) {
                buildConversationAvatar()
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversationName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func buildConversationAvatar() -> some View {
        Avatar(
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
                            .padding(.all, 8)
                        Spacer()
                    }
                }
            }
        }
    }

    private func buildMessageItem(message: MessageInfo) -> some View {
        return Button {
            // Pass message with conversation info for navigation
            let result: [String: Any] = [
                "message": message,
                "conversationID": conversationID,
                "conversationName": conversationName,
                "conversationAvatar": conversationAvatar
            ]
            onTapItem(result)
            presentationMode.wrappedValue.dismiss()
        } label: {
            HStack(spacing: 12) {
                Avatar(
                    url: message.from.avatarURL,
                    name: ChatUtil.getMessageSenderName(message),
                    size: .m
                )
                .environmentObject(themeState)
                .frame(width: 40, height: 40)
                .clipped()
                VStack(alignment: .leading, spacing: 4) {
                    buildHighlightedText(
                        text: ChatUtil.getMessageSenderName(message),
                        keyword: "",
                        isTitle: true
                    )
                    buildHighlightedText(
                        text: MessageListHelper.getMessageAbstract(message, showMergedTitle: true),
                        keyword: searchText,
                        isTitle: false
                    )
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
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
