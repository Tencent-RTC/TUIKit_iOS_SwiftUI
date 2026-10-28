import AtomicXCore
import SwiftUI

enum ConversationActionIDs {
    static let delete = "conversation.delete"
    static let mute = "conversation.mute"
    static let pin = "conversation.pin"
    static let markUnread = "conversation.markUnread"
    static let clearHistory = "conversation.clearHistory"
}

extension Notification.Name {
    static let chatConversationUnreadDidClear = Notification.Name("ChatConversationUnreadDidClear")
    static let chatConversationUnreadMarkDidChange = Notification.Name("ChatConversationUnreadMarkDidChange")
}

private final class RefreshedConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccess: (ConversationInfo) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void) {
        self.onSuccess = onSuccess
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccess(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {}
}

extension ConversationInfo {
    // 会议群的默认免打扰不是用户主动选择，列表不展示免打扰标识。
    var shouldShowDoNotDisturbIndicator: Bool {
        guard receiveOption == .notNotify else { return false }
        return groupType != .meeting
    }
}



struct ConversationListImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showDeleteConfirmation = false
    @State private var selectedConversation: ConversationInfo?
    @State private var pendingDeleteAction: ConversationCustomAction?
    @State private var conversationList: [ConversationInfo] = []
    @StateObject private var storeHolder = ConversationListStoreHolder()
    @State private var isLoadingConversations = false
    @State private var hasLoadedConversations = false
    @State private var isInitialLoadFinished = false
    private let onConversationClick: (ConversationInfo) -> Void
    private let customActions: [ConversationCustomAction]
    private let config: ConversationActionConfigProtocol

    init(onConversationClick: @escaping (ConversationInfo) -> Void,
                config: ConversationActionConfigProtocol? = nil,
                customActions: [ConversationCustomAction] = [])
    {
        self.onConversationClick = onConversationClick
        self.customActions = customActions
        self.config = config ?? ChatConversationActionConfig()
    }

    private var store: ConversationListStore { storeHolder.store }

    var body: some View {
        List {
            ForEach(conversationList) { conversation in
                conversationRow(for: conversation)
                    .listRowSeparatorIfAvailable(visibility: .hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        let actions = configuredActions(for: conversation)
                        if let action = actions.first(where: { $0.ID == ConversationActionIDs.delete }) {
                            Button(action.title) {
                                selectedConversation = conversation
                                pendingDeleteAction = action
                                showDeleteConfirmation = true
                            }
                            .tint(.red)
                        }
                        if let action = actions.first(where: { $0.ID == ConversationActionIDs.markUnread }) {
                            Button(action.title) {
                                action.action(conversation)
                            }
                            .tint(themeState.colors.buttonColorPrimaryDefault)
                        }
                        buildMoreActions(for: conversation)
                    }
            }
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList)).receive(on: DispatchQueue.main)) { conversationList in
            self.conversationList = conversationList
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatConversationUnreadDidClear)) { notification in
            guard let conversationID = notification.userInfo?["conversationID"] as? String else { return }
            refreshConversation(conversationID: conversationID)
        }
        .listStyle(PlainListStyle())
        .onAppear {
            if !hasLoadedConversations {
                conversationList = store.state.value.conversationList
                loadConversations()
            }
        }
        .listRowSeparatorIfAvailable(visibility: .hidden)
        .background(themeState.colors.listColorDefault)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(LocalizedChatString("ConversationDeleteChatConfirmTitle")),
                primaryButton: .destructive(Text(LocalizedChatString("Delete"))) {
                    if let conversation = selectedConversation {
                        if let pendingDeleteAction = pendingDeleteAction {
                            pendingDeleteAction.action(conversation)
                        } else {
                            deleteConversation(conversation)
                        }
                    }
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        }
        .overlay(
            Group {
                if isInitialLoadFinished && conversationList.isEmpty {
                    emptyStateView
                }
            }
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            Spacer()
            Image("uikit_empty_illustration", bundle: AtomicXChatResources.resourceBundle)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
            Text(LocalizedChatString("EmptyContent"))
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeState.colors.listColorDefault)
    }


    private func conversationRow(for conversation: ConversationInfo) -> some View {
        Button(action: {
            onConversationClick(conversation)
        }) {
            ConversationCell(conversation: conversation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 72)
        .listRowInsets(EdgeInsets(top: 0, leading: CGFloat(SpacingScheme.bubbleSpacing), bottom: 0, trailing: CGFloat(SpacingScheme.bubbleSpacing)))
        .listRowBackground(conversationBackgroundColor(for: conversation))
        .id("\(conversation.conversationID)-\(conversation.isPinned)")
    }

    @ViewBuilder
    private func buildMoreActions(for conversation: ConversationInfo) -> some View {
        if !moreActions(for: conversation).isEmpty {
            Button(LocalizedChatString("More"), action: {
                presentMoreActionSheet(for: conversation)
            })
            .tint(Color(.systemOrange))
        }
    }

    @ViewBuilder
    private func buildContextMenuActions(for conversation: ConversationInfo) -> some View {
        if let action = configuredActions(for: conversation).first(where: { $0.ID == ConversationActionIDs.markUnread }) {
            Button(action.title) {
                action.action(conversation)
            }
        }

        buildMoreActions(for: conversation)
    }

    private func presentMoreActionSheet(for conversation: ConversationInfo) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for action in moreActions(for: conversation) {
            alert.addAction(UIAlertAction(title: action.title, style: action.dangerous ? .destructive : .default) { _ in
                action.action(conversation)
            })
        }
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        if let presenter = ConversationListImpl.topmostViewController() {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = presenter.view.bounds
            }
            presenter.present(alert, animated: true)
        }
    }

    func configuredActions(for conversation: ConversationInfo) -> [ConversationCustomAction] {
        var actions = defaultActions(for: conversation)
        actions.append(contentsOf: customActions)
        guard let customizer = config.actionCustomizer else { return actions }
        let editor = CustomEditor(items: actions)
        customizer(editor)
        return editor.build()
    }

    private func defaultActions(for conversation: ConversationInfo) -> [ConversationCustomAction] {
        var actions: [ConversationCustomAction] = []
        if config.isSupportMarkUnread {
            let isUnread = conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread)
            actions.append(ConversationCustomAction(ID: ConversationActionIDs.markUnread, title: LocalizedChatString(isUnread ? "MarkAsRead" : "MarkAsUnRead")) { conversation in
                if isUnread {
                    markConversationAsRead(conversation)
                } else {
                    markConversationAsUnread(conversation)
                }
            })
        }
        if config.isSupportMute {
            let willMute = conversation.receiveOption != .notNotify
            actions.append(ConversationCustomAction(ID: ConversationActionIDs.mute, title: LocalizedChatString(willMute ? "ConversationMute" : "ConversationUnmute")) { conversation in
                muteConversation(conversation, mute: willMute)
            })
        }
        if config.isSupportPin {
            actions.append(ConversationCustomAction(ID: ConversationActionIDs.pin, title: LocalizedChatString(conversation.isPinned ? "UnPin" : "Pin")) { conversation in
                if conversation.isPinned {
                    unpinConversation(conversation)
                } else {
                    pinConversation(conversation)
                }
            })
        }
        if config.isSupportClearHistory {
            actions.append(ConversationCustomAction(ID: ConversationActionIDs.clearHistory, title: LocalizedChatString("ConversationClearChatHistory")) { conversation in
                confirmClearHistory(conversation)
            })
        }
        if config.isSupportDelete {
            actions.append(ConversationCustomAction(ID: ConversationActionIDs.delete, title: LocalizedChatString("Delete"), dangerous: true) { conversation in
                deleteConversation(conversation)
            })
        }
        return actions
    }

    private func moreActions(for conversation: ConversationInfo) -> [ConversationCustomAction] {
        configuredActions(for: conversation).filter {
            $0.ID != ConversationActionIDs.delete && $0.ID != ConversationActionIDs.markUnread
        }
    }

    private static func topmostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func loadConversations() {
        guard !isLoadingConversations, !hasLoadedConversations else { return }
        isLoadingConversations = true
        let currentStore = store
        currentStore.loadConversations(option: ConversationLoadOption(), completion: { result in
            DispatchQueue.main.async {
                guard self.store === currentStore else { return }
                self.isLoadingConversations = false
                if case .success = result {
                    self.hasLoadedConversations = true
                }
                self.isInitialLoadFinished = true
            }
        })
    }

    private func refreshConversation(conversationID: String) {
        let currentStore = store
        currentStore.getConversationInfo(conversationID: conversationID, completion: RefreshedConversationInfoHandler { conversation in
            DispatchQueue.main.async {
                guard self.store === currentStore,
                      let index = self.conversationList.firstIndex(where: { $0.conversationID == conversationID }) else { return }
                self.conversationList[index] = conversation
            }
        })
    }

    private func deleteConversation(_ conversation: ConversationInfo) {
        store.deleteConversation(conversationID: conversation.conversationID, completion: nil)
    }

    private func muteConversation(_ conversation: ConversationInfo, mute: Bool) {
        store.setReceiveMessageOpt(conversationID: conversation.conversationID, opt: mute ? .notNotify : .receive, completion: nil)
    }

    private func pinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversationID: conversation.conversationID, pin: true, completion: nil)
    }

    private func unpinConversation(_ conversation: ConversationInfo) {
        store.pinConversation(conversationID: conversation.conversationID, pin: false, completion: nil)
    }

    private func confirmClearHistory(_ conversation: ConversationInfo) {
        let titleKey = conversation.type == .group ? "ClearGroupHistoryTips" : "ClearContactHistoryTips"
        let alert = UIAlertController(
            title: LocalizedChatString(titleKey),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("Confirm"), style: .destructive) { _ in
            clearConversationMessages(conversation)
        })
        ConversationListImpl.topmostViewController()?.present(alert, animated: true)
    }

    private func clearConversationMessages(_ conversation: ConversationInfo) {
        store.clearConversationMessages(conversationID: conversation.conversationID, completion: nil)
    }

    private func conversationBackgroundColor(for conversation: ConversationInfo) -> Color {
        conversation.isPinned ? themeState.colors.bgColorDefault : themeState.colors.listColorDefault
    }

    private func clearConversationUnreadCount(_ conversation: ConversationInfo) {
        markConversationAsRead(conversation)
    }

    private func markConversationAsRead(_ conversation: ConversationInfo) {
        let currentStore = store
        currentStore.clearConversationUnreadCount(conversationID: conversation.conversationID) { result in
            guard case .success = result else { return }
            currentStore.markConversation(conversationIDList: [conversation.conversationID], markType: .unread, enable: false) { result in
                guard case .success = result else { return }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .chatConversationUnreadMarkDidChange, object: nil,
                        userInfo: ["conversationID": conversation.conversationID, "enabled": false])
                    NotificationCenter.default.post(name: .chatConversationUnreadDidClear, object: nil,
                        userInfo: ["conversationID": conversation.conversationID])
                }
            }
        }
    }

    private func markConversationAsUnread(_ conversation: ConversationInfo) {
        store.markConversation(conversationIDList: [conversation.conversationID], markType: .unread, enable: true) { result in
            guard case .success = result else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .chatConversationUnreadMarkDidChange, object: nil,
                    userInfo: ["conversationID": conversation.conversationID, "enabled": true])
            }
        }
    }
}


private final class ConversationListStoreHolder: ObservableObject {
    let store = ConversationListStore.create()
}

private struct ConversationCell: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject private var mentionReadState = MessageMentionReadState.shared
    let conversation: ConversationInfo

    var body: some View {
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            ZStack(alignment: .topTrailing) {
                AvatarView(
                    url: conversation.avatarURL,
                    name: conversation.title,
                    size: .l,
                    shape: .roundedRectangle,
                    cornerRadius: CGFloat(RadiusScheme.tipsRadius)
                )
                avatarBadge
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(conversation.title ?? "")
                    .font(themeState.fonts.body4Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .padding(.top, 1)
                Spacer(minLength: CGFloat(SpacingScheme.iconTextSpacing))
                HStack(alignment: .center, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    sendStatusIcon(for: conversation.lastMessage?.status)
                    let subtitle = (conversation.draft?.isEmpty ?? true)
                        ? MessageListView.getMessageAbstract(conversation.lastMessage) : ""
                    buildSubtitleView(subtitle: subtitle, conversation: conversation)
                }
                .padding(.bottom, 1)
            }
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .topLeading)
            VStack(alignment: .trailing, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                if let timestamp = conversation.lastMessage?.timestamp, timestamp > 0 {
                    Text(DateHelper.convertDateToYMDStr(Date(timeIntervalSince1970: TimeInterval(timestamp))))
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                if conversation.shouldShowDoNotDisturbIndicator {
                    Image(systemName: "bell.slash.fill")
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
            }
            .padding(.leading, CGFloat(SpacingScheme.iconTextSpacing))
        }
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeState.colors.strokeColorSecondary)
                .frame(height: 0.5)
                .padding(.leading, 76)
        }
    }

    @ViewBuilder
    private var avatarBadge: some View {
        let isUnread = conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread)
        if conversation.shouldShowDoNotDisturbIndicator {
            if isUnread {
                Circle()
                    .fill(themeState.colors.textColorError)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
                    .accessibilityIdentifier("chat_conversation_unread_\(conversation.conversationID)")
            }
        } else if isUnread {
            let count = conversation.unreadCount
            let text = count > 99 ? "99+" : "\(max(count, 1))"
            BadgeView(text: text, type: .text)
                .offset(x: 6, y: -6)
                .accessibilityIdentifier("chat_conversation_unread_\(conversation.conversationID)")
        }
    }

    @ViewBuilder
    private func sendStatusIcon(for status: MessageStatus?) -> some View {
        switch status {
        case .sendFail, .violation:
            Image(systemName: "exclamationmark.circle.fill")
                .font(themeState.fonts.caption2Regular)
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

    private func buildSubtitleView(subtitle: String, conversation: ConversationInfo) -> some View {
        TruncatingSubtitleLabel(attributedText: buildSubtitleAttributedText(subtitle: subtitle, conversation: conversation))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buildSubtitleAttributedText(subtitle: String, conversation: ConversationInfo) -> NSAttributedString {
        let font = UIKitFontScheme.caption2Regular
        let secondary = UIColor(themeState.colors.textColorSecondary)
        let error = UIColor(themeState.colors.textColorError)
        let countUnit = LocalizedChatString("MessageCount")
        let atTagText = buildAtTagText(conversation: conversation)
        let hasUnreadPrefix = conversation.receiveOption != .receive && conversation.unreadCount > 0
        let result = NSMutableAttributedString()

        if let draft = conversation.draft, !draft.isEmpty {
            if hasUnreadPrefix {
                result.append(ConversationCell.makeAttr("[\(conversation.unreadCount)\(countUnit)] ", secondary, font))
            }
            result.append(ConversationCell.makeAttr(atTagText, error, font))
            result.append(ConversationCell.makeAttr(LocalizedChatString("MessageTypeDraftFormat"), error, font))
            result.append(ConversationCell.emojiRenderedAttr(draft, color: secondary, font: font))
            return result
        }

        let finalText = hasUnreadPrefix ? "[\(conversation.unreadCount)\(countUnit)] \(subtitle)" : subtitle
        result.append(ConversationCell.makeAttr(atTagText, error, font))
        result.append(ConversationCell.emojiRenderedAttr(finalText, color: secondary, font: font))
        return result
    }

    private static func makeAttr(_ text: String, _ color: UIColor, _ font: UIFont) -> NSAttributedString {
        guard !text.isEmpty else { return NSAttributedString() }
        return NSAttributedString(string: text, attributes: [.foregroundColor: color, .font: font])
    }

    private static func emojiRenderedAttr(_ text: String, color: UIColor, font: UIFont) -> NSAttributedString {
        guard text.contains("[TUIEmoji_") else { return makeAttr(text, color, font) }
        return EmojiManager.shared.createStyledAttributedString(fromEmojiCodes: text, font: font, textColor: color)
    }

    private func buildAtTagText(conversation: ConversationInfo) -> String {
        guard conversation.unreadCount > 0,
              conversation.conversationID.hasPrefix("group_"),
              let atInfoList = conversation.groupAtInfoList,
              !atInfoList.isEmpty
        else {
            return ""
        }

        let scopeKey = MessageMentionReadState.scopeKey(conversationID: conversation.conversationID)
        let unreadMentions = mentionReadState.unconsumed(atInfoList, scopeKey: scopeKey)
        var hasAtAll = false
        var hasAtMe = false

        for atInfo in unreadMentions {
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
}

private enum ListRowSeparatorVisibility {
    case visible
    case hidden
}

private struct ListRowSeparatorModifier: ViewModifier {
    let visibility: ListRowSeparatorVisibility
    func body(content: Content) -> some View {
        content.listRowSeparator(visibility == .hidden ? .hidden : .visible)
    }
}

private extension View {
    func listRowSeparatorIfAvailable(visibility: ListRowSeparatorVisibility) -> some View {
        modifier(ListRowSeparatorModifier(visibility: visibility))
    }
}

private struct TruncatingSubtitleLabel: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        guard uiView.attributedText?.isEqual(to: attributedText) != true else { return }
        uiView.attributedText = attributedText
    }
}
