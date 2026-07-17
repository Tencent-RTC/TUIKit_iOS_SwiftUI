import AtomicXCore
import SwiftUI

extension ConversationInfo {
    // Meeting groups carry an SDK-default do-not-disturb flag that the user did not explicitly
    // opt into, so we keep the mute indicator out of the conversation list for them. This
    // matches the Android and Flutter behavior.
    var shouldShowDoNotDisturbIndicator: Bool {
        guard receiveOption == .notNotify else { return false }
        return groupType != .meeting
    }
}

public struct ConversationCustomAction {
    public let title: String
    public let action: (ConversationInfo) -> Void

    public init(title: String, action: @escaping (ConversationInfo) -> Void) {
        self.title = title
        self.action = action
    }
}

public struct ConversationList: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showingActionSheet = false
    @State private var selectedConversation: ConversationInfo?
    @State private var conversationList: [ConversationInfo] = []
    @State private var conversationStore: ConversationListStore? = nil
    @State private var isStoreInitialized = false
    @State private var isRefreshing = false
    private let onConversationClick: (ConversationInfo) -> Void
    private let customActions: [ConversationCustomAction]
    private let config: ConversationActionConfigProtocol

    public init(onConversationClick: @escaping (ConversationInfo) -> Void,
                config: ConversationActionConfigProtocol = ChatConversationActionConfig(),
                customActions: [ConversationCustomAction] = [])
    {
        self.onConversationClick = onConversationClick
        self.customActions = customActions
        self.config = config
    }

    private var store: ConversationListStore {
        guard let store = conversationStore else {
            return ConversationListStore.create()
        }
        return store
    }

    public var body: some View {
        List {
            ForEach(conversationList) { conversation in
                conversationRow(for: conversation)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if config.isSupportMarkUnread {
                            Button {
                                if conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread) {
                                    markConversationAsRead(conversation)
                                } else {
                                    markConversationAsUnread(conversation)
                                }
                            } label: {
                                if conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread) {
                                    Text(LocalizedChatString("MarkAsRead"))
                                } else {
                                    Text(LocalizedChatString("MarkAsUnRead"))
                                }
                            }
                            .tint(themeState.colors.textColorLink)
                        }

                        buildMoreActions(for: conversation)
                    }
            }
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList)).dropFirst()) { conversationList in
            self.conversationList = conversationList
        }
        .listStyle(PlainListStyle())
        .onAppear {
            initializeStoreIfNeeded()
            loadConversations()
            UITableView.appearance().separatorStyle = .none
            UITableView.appearance().backgroundColor = .clear
        }
        .refreshableIfAvailable {
            isRefreshing = true
            loadConversations()
        }
        .listRowSeparatorIfAvailable(visibility: .hidden)
        .background(themeState.colors.listColorDefault)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text(LocalizedChatString("ChooseAnAction")),
                buttons: buildActionSheetButtons()
            )
        }
    }

    // MARK: - Helper Methods

    private func initializeStoreIfNeeded() {
        guard !isStoreInitialized else { return }

        conversationStore = ConversationListStore.create()
        isStoreInitialized = true
    }

    private func conversationRow(for conversation: ConversationInfo) -> some View {
        Button(action: {
            clearConversationUnreadCount(conversation)
            onConversationClick(conversation)
        }) {
            ConversationCell(conversation: conversation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 70)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(conversationBackgroundColor(for: conversation))
        .id("\(conversation.conversationID)-\(conversation.isPinned)")
    }

    @ViewBuilder
    private func buildMoreActions(for conversation: ConversationInfo) -> some View {
        if config.isSupportDelete || config.isSupportPin || config.isSupportClearHistory || !customActions.isEmpty {
            Button(LocalizedChatString("More"), action: {
                selectedConversation = conversation
                showingActionSheet = true
            })
            .tint(themeState.colors.textColorAntiPrimary)
        }
    }

    @ViewBuilder
    private func buildContextMenuActions(for conversation: ConversationInfo) -> some View {
        if config.isSupportMarkUnread {
            if conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread) {
                Button(action: {
                    markConversationAsRead(conversation)
                }) {
                    Text(LocalizedChatString("MarkAsRead"))
                }
            } else {
                Button(action: {
                    markConversationAsUnread(conversation)
                }) {
                    Text(LocalizedChatString("MarkAsUnRead"))
                }
            }
        }

        buildMoreActions(for: conversation)
    }

    private func buildActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []

        if config.isSupportPin {
            if selectedConversation?.isPinned == true {
                buttons.append(.default(Text(LocalizedChatString("UnPin"))) {
                    if let conversation = selectedConversation {
                        unpinConversation(conversation)
                    }
                })
            } else {
                buttons.append(.default(Text(LocalizedChatString("Pin"))) {
                    if let conversation = selectedConversation {
                        pinConversation(conversation)
                    }
                })
            }
        }
        if config.isSupportDelete {
            buttons.append(.default(Text(LocalizedChatString("Delete"))) {
                if let conversation = selectedConversation {
                    deleteConversation(conversation)
                }
            })
        }
        if config.isSupportClearHistory {
            buttons.append(.default(Text(LocalizedChatString("ClearHistoryChatMessage"))) {
                if let conversation = selectedConversation {
                    clearConversationMessages(conversation)
                }
            })
        }
        for customAction in customActions {
            buttons.append(.default(Text(customAction.title)) {
                if let conversation = selectedConversation {
                    customAction.action(conversation)
                }
            })
        }
        buttons.append(.cancel(Text(LocalizedChatString("Cancel"))))
        return buttons
    }

    private func loadConversations() {
        let option = ConversationLoadOption()
        store.loadConversations(option: option, completion: { _ in
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
        })
    }

    private func deleteConversation(_ conversation: ConversationInfo) {
        store.deleteConversation(conversationID: conversation.conversationID, completion: nil)
    }

    private func pinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversationID: conversation.conversationID, pin: true, completion: nil)
    }

    private func unpinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversationID: conversation.conversationID, pin: false, completion: nil)
    }

    private func clearConversationMessages(_ conversation: ConversationInfo) {
        store.clearConversationMessages(conversationID: conversation.conversationID, completion: nil)
    }

    private func conversationBackgroundColor(for conversation: ConversationInfo) -> Color {
        conversation.isPinned ? themeState.colors.bgColorDefault : themeState.colors.listColorDefault
    }

    private func clearConversationUnreadCount(_ conversation: ConversationInfo) {
        store.clearConversationUnreadCount(conversationID: conversation.conversationID, completion: nil)
        store.markConversation(conversationIDList: [conversation.conversationID], markType: .unread, enable: false, completion: nil)
    }

    private func markConversationAsRead(_ conversation: ConversationInfo) {
        store.clearConversationUnreadCount(conversationID: conversation.conversationID, completion: nil)
        store.markConversation(conversationIDList: [conversation.conversationID], markType: .unread, enable: false, completion: nil)
    }

    private func markConversationAsUnread(_ conversation: ConversationInfo) {
        store.markConversation(conversationIDList: [conversation.conversationID], markType: .unread, enable: true, completion: nil)
    }
}

// MARK: - ConversationCell

private struct ConversationCell: View {
    @EnvironmentObject var themeState: ThemeState
    let conversation: ConversationInfo

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Avatar(
                    url: conversation.avatarURL,
                    name: conversation.title,
                    size: .m
                )
                if conversation.shouldShowDoNotDisturbIndicator && (conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread)) {
                    Circle()
                        .fill(themeState.colors.textColorError)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    TitleLabel(size: .s, text: conversation.title ?? "")
                    Spacer()
                    if conversation.shouldShowDoNotDisturbIndicator {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeState.colors.textColorSecondary)
                    } else {
                        if conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread) {
                            if conversation.unreadCount > 0 {
                                Badge(text: "\(conversation.unreadCount)", type: .text)
                            } else {
                                Badge(text: "1", type: .text)
                            }
                        }
                    }
                }
                HStack(alignment: .center, spacing: 4) {
                    sendStatusIcon(for: conversation.lastMessage?.status)

                    let subtitle = MessageListHelper.getMessageAbstract(conversation.lastMessage)

                    buildSubtitleView(subtitle: subtitle, conversation: conversation)

                    Spacer()
                    HStack(spacing: 4) {
                        if let timestamp = conversation.lastMessage?.timestamp, timestamp > 0 {
                            let dateStr = DateHelper.convertDateToYMDStr(Date(timeIntervalSince1970: TimeInterval(timestamp)))
                            if dateStr.contains("PM") {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeState.colors.textColorLink)
                            }
                            ItemLabel(size: .s, text: dateStr)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func sendStatusIcon(for status: MessageStatus?) -> some View {
        switch status {
        case .sendFail, .violation:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(themeState.colors.textColorError)
        case .sending:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeState.colors.textColorSecondary))
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func buildSubtitleView(subtitle: String, conversation: ConversationInfo) -> some View {
        let countUnit = LocalizedChatString("MessageCount")
        let font = themeState.fonts.caption3Regular
        let atTagText = buildAtTagText(conversation: conversation)

        // Check if there's a draft - if so, prioritize showing the draft
        if let draft = conversation.draft, !draft.isEmpty {
            let draftLabel = LocalizedChatString("MessageTypeDraftFormat")
            let draftContent = EmojiManager.shared.createLocalizedStringFromEmojiCodes(draft)

            // Build the text with red draft label and @ tag
            Group {
                if conversation.receiveOption == .notNotify && conversation.unreadCount >= 2 {
                    (Text("[\(conversation.unreadCount)\(countUnit)]")
                        .foregroundColor(themeState.colors.textColorSecondary) +
                        Text(atTagText)
                        .foregroundColor(themeState.colors.textColorError) +
                        Text(draftLabel)
                        .foregroundColor(themeState.colors.textColorError) +
                        Text(draftContent)
                        .foregroundColor(themeState.colors.textColorSecondary))
                        .font(font)
                        .lineLimit(1)
                } else {
                    (Text(atTagText)
                        .foregroundColor(themeState.colors.textColorError) +
                        Text(draftLabel)
                        .foregroundColor(themeState.colors.textColorError) +
                        Text(draftContent)
                        .foregroundColor(themeState.colors.textColorSecondary))
                        .font(font)
                        .lineLimit(1)
                }
            }
        } else {
            // No draft - check for @ tag
            let finalText = buildFinalText(subtitle: subtitle, conversation: conversation)

            if !atTagText.isEmpty {
                // Show @ tag in red before the message
                (Text(atTagText)
                    .foregroundColor(themeState.colors.textColorError) +
                    Text(finalText)
                    .foregroundColor(themeState.colors.textColorSecondary))
                    .font(font)
                    .lineLimit(1)
            } else {
                SubTitleLabel(size: .s, text: finalText)
            }
        }
    }

    /// Build @ tag text based on groupAtInfoList
    private func buildAtTagText(conversation: ConversationInfo) -> String {
        // Only show @ tag for group chats with unread messages
        guard conversation.unreadCount > 0,
              conversation.conversationID.hasPrefix("group_"),
              let atInfoList = conversation.groupAtInfoList,
              !atInfoList.isEmpty
        else {
            return ""
        }

        var hasAtAll = false
        var hasAtMe = false

        for atInfo in atInfoList {
            switch atInfo.atType {
            case .atMe:
                hasAtMe = true
            case .atAll:
                hasAtAll = true
            case .atAllAtMe:
                hasAtAll = true
                hasAtMe = true
            }
        }

        var result = ""
        if hasAtAll {
            result += LocalizedChatString("MentionAtAllTag")
        }
        if hasAtMe {
            result += LocalizedChatString("MentionAtMeTag")
        }
        return result
    }

    private func buildFinalText(subtitle: String, conversation: ConversationInfo) -> String {
        let countUnit = LocalizedChatString("MessageCount")

        // Process text with emoji codes
        let processedText: String
        if subtitle.contains("\(LocalizedChatString("You")):") {
            // "You:" prefix doesn't need emoji processing
            processedText = subtitle
        } else {
            processedText = EmojiManager.shared.createLocalizedStringFromEmojiCodes(subtitle)
        }

        if conversation.receiveOption == .notNotify && conversation.unreadCount >= 2 {
            return "[\(conversation.unreadCount)\(countUnit)] \(processedText)"
        } else {
            return processedText
        }
    }
}

private enum ListRowSeparatorVisibility {
    case visible
    case hidden
}

private struct RefreshableModifier: ViewModifier {
    let action: () -> Void
    @State private var isRefreshing = false

    func body(content: Content) -> some View {
        content.refreshable {
            action()
        }
    }
}

private struct ListRowSeparatorModifier: ViewModifier {
    let visibility: ListRowSeparatorVisibility
    func body(content: Content) -> some View {
        content.listRowSeparator(visibility == .hidden ? .hidden : .visible)
    }
}

private extension View {
    func refreshableIfAvailable(action: @escaping () -> Void) -> some View {
        modifier(RefreshableModifier(action: action))
    }

    func listRowSeparatorIfAvailable(visibility: ListRowSeparatorVisibility) -> some View {
        modifier(ListRowSeparatorModifier(visibility: visibility))
    }

    func pullToRefresh(isRefreshing: Binding<Bool>, onRefresh: @escaping () -> Void) -> some View {
        background(
            PullToRefreshView(isRefreshing: isRefreshing, onRefresh: onRefresh)
        )
    }
}

private struct PullToRefreshView: UIViewRepresentable {
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let tableView = findTableView(in: uiView) {
                setupRefreshControl(for: tableView, context: context)

                if isRefreshing {
                    if tableView.refreshControl?.isRefreshing == false {
                        tableView.refreshControl?.beginRefreshing()
                    }
                } else {
                    tableView.refreshControl?.endRefreshing()
                }
            }
        }
    }

    private func findTableView(in view: UIView) -> UITableView? {
        // Look for UITableView in the view hierarchy
        var currentView: UIView? = view.superview
        while currentView != nil {
            if let tableView = currentView as? UITableView {
                return tableView
            }
            currentView = currentView?.superview
        }
        return nil
    }

    private func setupRefreshControl(for tableView: UITableView, context: Context) {
        if tableView.refreshControl == nil {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(
                context.coordinator,
                action: #selector(Coordinator.refresh),
                for: .valueChanged
            )
            tableView.refreshControl = refreshControl
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: PullToRefreshView

        init(_ parent: PullToRefreshView) {
            self.parent = parent
        }

        @objc func refresh() {
            parent.onRefresh()
        }
    }
}
