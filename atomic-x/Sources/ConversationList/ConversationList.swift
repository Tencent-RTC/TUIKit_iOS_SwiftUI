import AtomicXCore
import SwiftUI

private struct ConversationListStyleKey: EnvironmentKey {
    static let defaultValue: ConversationListConfigProtocol = ChatConversationStyle()
}

extension EnvironmentValues {
    var ConversationListStyle: ConversationListConfigProtocol {
        get { self[ConversationListStyleKey.self] }
        set { self[ConversationListStyleKey.self] = newValue }
    }
}

public struct ConversationList: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.ConversationListStyle) var style: ConversationListConfigProtocol
    @State private var showingActionSheet = false
    @State private var selectedConversation: ConversationInfo?
    @State private var conversationList: [ConversationInfo] = []
    @State private var conversationStore: ConversationListStore? = nil
    @State private var isStoreInitialized = false
    @State private var isRefreshing = false
    private let onConversationClick: (ConversationInfo) -> Void

    public init(onConversationClick: @escaping (ConversationInfo) -> Void) {
        self.onConversationClick = onConversationClick
    }

    private var store: ConversationListStore {
        guard let store = conversationStore else {
            return ConversationListStore.create()
        }
        return store
    }

    public var body: some View {
        List {
            if #available(iOS 15.0, *) {
                ForEach(conversationList) { conversation in
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
                    .id(conversation.conversationID)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Mark Read/Unread Button
                        if style.isSupportMarkUnread {
                            if conversation.unreadCount > 0 {
                                Button(LocalizedChatString("MarkAsRead"), action: {
                                    markConversationAsRead(conversation)
                                })
                                .tint(.green)
                            } 
                        }
                        
                        // More Actions Button
                        if style.isSupportMute || style.isSupportPin || style.isSupportMarkUnread {
                            Button(LocalizedChatString("More"), action: {
                                selectedConversation = conversation
                                showingActionSheet = true
                            })
                            .tint(.blue)
                        }
                    }
                }
            } else {
                ForEach(conversationList) { conversation in
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
                    .id(conversation.conversationID)
                    .contextMenu {
                        buildContextMenu(for: conversation)
                    }
                }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let conversation = conversationList[index]
                                if style.isSupportDelete {
                                    deleteConversation(conversation)
                                }
                            }
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

    private func getConversationList() -> [ConversationInfo] {
        return conversationList
    }

    @ViewBuilder
    private func buildContextMenu(for conversation: ConversationInfo) -> some View {
        if style.isSupportDelete {
            if #available(iOS 15.0, *) {
                Button(role: .destructive, action: {
                    deleteConversation(conversation)
                }) {
                    Label(LocalizedChatString("Delete"), systemImage: "trash")
                }
            } else {
                Button(action: {
                    deleteConversation(conversation)
                }) {
                    Label(LocalizedChatString("Delete"), systemImage: "trash")
                }
            }
        }

        if style.isSupportMute || style.isSupportPin || style.isSupportMarkUnread {
            Button(action: {
                selectedConversation = conversation
                showingActionSheet = true
            }) {
                Label(LocalizedChatString("More"), systemImage: "ellipsis")
            }
        }
    }

    private func buildActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if style.isSupportPin {
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
        if style.isSupportDelete {
            buttons.append(.default(Text(LocalizedChatString("Delete"))) {
                if let conversation = selectedConversation {
                    deleteConversation(conversation)
                }
            })
        }
        buttons.append(.default(Text(LocalizedChatString("ClearHistoryChatMessage"))) {
            if let conversation = selectedConversation {
                clearConversationMessages(conversation)
            }
        })
        buttons.append(.cancel(Text(LocalizedChatString("Cancel"))))
        return buttons
    }

    private func loadConversations() {
        let option = ConversationFetchOption()
        store.fetchConversationList(option, completion: {  result in
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
        })
    }

    private func deleteConversation(_ conversation: ConversationInfo) {
        store.deleteConversation(conversation.conversationID, completion: nil)
    }

    private func pinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversation.conversationID, pin: true, completion: nil)
    }

    private func unpinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversation.conversationID, pin: false, completion: nil)
    }

    private func clearConversationMessages(_ conversation: ConversationInfo) {
        store.clearConversationMessages(conversation.conversationID, completion: nil)
    }

    private func conversationBackgroundColor(for conversation: ConversationInfo) -> Color {
        conversation.isPinned ? themeState.colors.bgColorDefault : themeState.colors.listColorDefault
    }

    private func clearConversationUnreadCount(_ conversation: ConversationInfo) {
        store.clearConversationUnreadCount(conversation.conversationID, completion: nil)
    }
    
    private func markConversationAsRead(_ conversation: ConversationInfo) {
        store.clearConversationUnreadCount(conversation.conversationID, completion: nil)
    }
    
    private func markConversationAsUnread(_ conversation: ConversationInfo) {
        store.markConversationUnread(conversation.conversationID, unread: true, completion: nil)
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
                if conversation.receiveOption == .notNotify && conversation.unreadCount > 0 {
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
                    if conversation.receiveOption == .notNotify  && conversation.groupType != GroupType.meeting {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeState.colors.textColorSecondary)
                    } else {
                        if conversation.unreadCount > 0 {
                            Badge(text: "\(conversation.unreadCount)", type: .text)
                        }
                    }
                }
                HStack(alignment: .center) {
                    let subtitle = MessageListHelper.getMessageAbstract(conversation.lastMessage)
                    let finalText = buildFinalText(subtitle: subtitle, conversation: conversation)
                    
                    SubTitleLabel(size: .s, text: finalText)
                    Spacer()
                    HStack(spacing: 4) {
                        if conversation.timestamp > 0 {
                            let dateStr = DateHelper.convertDateToYMDStr(Date(timeIntervalSince1970: TimeInterval(conversation.timestamp)))
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
    
    private func buildFinalText(subtitle: String, conversation: ConversationInfo) -> String {
        let countUnit = LocalizedChatString("MessageCount")
        
        if subtitle.contains("@") {
            let baseText = "@\(subtitle.dropFirst(1))"
            if conversation.receiveOption == .notNotify && conversation.unreadCount > 0 {
                return "[\(conversation.unreadCount)\(countUnit)] \(baseText)"
            } else {
                return baseText
            }
        } else if subtitle.contains("\(LocalizedChatString("You")):") {
            if conversation.receiveOption == .notNotify && conversation.unreadCount > 0 {
                return "[\(conversation.unreadCount)\(countUnit)] \(subtitle)"
            } else {
                return subtitle
            }
        } else {
            let processedText = EmojiManager.shared.createLocalizedStringFromEmojiCodes(subtitle)
            if conversation.receiveOption == .notNotify && conversation.unreadCount > 0 {
                return "[\(conversation.unreadCount)\(countUnit)] \(processedText)"
            } else {
                return processedText
            }
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
        if #available(iOS 15.0, *) {
            content.refreshable {
                action()
            }
        } else {
            content
                .pullToRefresh(isRefreshing: $isRefreshing) {
                    isRefreshing = true
                    action()
                }
        }
    }
}

private struct ListRowSeparatorModifier: ViewModifier {
    let visibility: ListRowSeparatorVisibility
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.listRowSeparator(visibility == .hidden ? .hidden : .visible)
        } else {
            content
        }
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
