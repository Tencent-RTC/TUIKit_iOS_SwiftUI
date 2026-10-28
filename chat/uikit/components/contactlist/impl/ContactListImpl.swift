import AtomicXCore
import Combine
import SwiftUI

struct ContactListImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var friendList: [ContactInfo] = []
    @State private var searchText: String = ""
    @StateObject private var badgeCounts = ContactBadgeCounts()

    @State private var showNewFriends: Bool = false
    @State private var showGroupApplications: Bool = false
    @State private var showGroupList: Bool = false
    @State private var showBlackList: Bool = false

    private let config: ContactListConfigProtocol
    private let onContactClick: ((AZOrderedListItem) -> Void)?
    private let onGroupClick: ((AZOrderedListItem) -> Void)?

    init(
        config: ContactListConfigProtocol? = nil,
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil
    ) {
        self.config = config ?? ChatContactListConfig()
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
    }

    var body: some View {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let isSearching = !keyword.isEmpty
        let displayList = isSearching ? friendList.filter { matchesSearchQuery($0, query: keyword) } : friendList
        let userList = displayList.map { contact in
            AZOrderedListItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: ContactDisplayName.name(for: contact),
                extraData: contact
            )
        }

        return VStack(spacing: 0) {
            if config.showSearchBar {
                ContactSearchBar(text: $searchText)
            }
            AZOrderedListView(
                userList: userList,
                header: isSearching ? nil : AnyView(navigationHeader),
                onUserInteraction: hideKeyboard,
                onItemClick: { user in
                    onContactClick?(user)
                }
            )
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNewFriends) {
            FriendApplicationListView(onDismiss: { showNewFriends = false })
                .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $showGroupApplications) {
            GroupApplicationListView(onDismiss: { showGroupApplications = false })
                .environmentObject(themeState)
        }
        .background(
            NavigationLink(
                destination: GroupListView(
                    onGroupClick: { group in
                        onGroupClick?(group)
                    },
                    onDismiss: { showGroupList = false }
                )
                .environmentObject(themeState)
                .navigationBarHidden(true),
                isActive: $showGroupList
            ) { EmptyView() }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: BlackListView(
                    onContactClick: { contact in
                        onContactClick?(contact)
                    },
                    onDismiss: { showBlackList = false }
                )
                .environmentObject(themeState)
                .navigationBarHidden(true),
                isActive: $showBlackList
            ) { EmptyView() }
            .hidden()
        )
        .onReceive(ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: RunLoop.main)
        ) { friendList in
            if friendList.isEmpty && !self.friendList.isEmpty {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.friendList = friendList
            }
        }
        .onAppear {
            friendList = ContactStore.shared.state.value.friendList
            fetchData()
        }
    }

    private func fetchData() {
        ContactStore.shared.loadFriends(completion: nil)
        ContactStore.shared.loadFriendApplications(completion: nil)
        GroupStore.shared.loadApplications(completion: nil)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var headerItems: [ContactCustomItem] {
        var defaults: [ContactCustomItem] = []
        if config.showNewContacts {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.newContacts,
                title: LocalizedChatString("ContactsNewFriends"),
                iconName: "contact_new_contacts",
                badgeCount: badgeCounts.$friendApplicationUnreadCount.eraseToAnyPublisher(),
                onClick: { showNewFriends = true }
            ))
        }
        if config.showGroupApplications {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.groupApplications,
                title: LocalizedChatString("ContactsGroupApplications"),
                iconName: "contact_group_notification",
                badgeCount: badgeCounts.$groupApplicationUnreadCount.eraseToAnyPublisher(),
                onClick: { showGroupApplications = true }
            ))
        }
        if config.showMyGroups {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.myGroups,
                title: LocalizedChatString("ContactsGroupChats"),
                iconName: "contact_my_group",
                onClick: { hideKeyboard(); showGroupList = true }
            ))
        }
        if config.showBlacklist {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.blacklist,
                title: LocalizedChatString("ContactsBlackList"),
                iconName: "contact_blacklist",
                onClick: { hideKeyboard(); showBlackList = true }
            ))
        }
        guard let customizer = config.itemCustomizer else { return defaults }
        let editor = CustomEditor(items: defaults)
        customizer(editor)
        return editor.build()
    }

    @ViewBuilder
    private var navigationHeader: some View {
        let items = headerItems
        if !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.ID) { index, item in
                    Button(action: item.onClick) {
                        ContactNavigationRow(item: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(themeState.colors.strokeColorSecondary)
                            .frame(height: 0.5)
                            .padding(.leading, 68)
                    }
                }
            }
            .background(themeState.colors.bgColorOperate)
        }
    }

    private func matchesSearchQuery(_ contact: ContactInfo, query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return true
        }
        let candidates: [String?] = [ContactDisplayName.name(for: contact), contact.userID, contact.nickname, contact.friendRemark]
        return candidates.compactMap { $0 }.filter { !$0.isEmpty }.contains { value in
            value.range(of: keyword, options: .caseInsensitive) != nil
        }
    }
}

final class ContactBadgeCounts: ObservableObject {
    @Published var friendApplicationUnreadCount: Int = 0
    @Published var groupApplicationUnreadCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        friendApplicationUnreadCount = ContactStore.shared.state.value.friendApplicationUnreadCount
        groupApplicationUnreadCount = GroupStore.shared.state.value.unreadApplicationCount
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.friendApplicationUnreadCount = $0 }
            .store(in: &cancellables)
        GroupStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.unreadApplicationCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.groupApplicationUnreadCount = $0 }
            .store(in: &cancellables)
    }
}


struct ContactSearchBar: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var text: String
    var placeholder: String = LocalizedChatString("Search")

    private static let debounceInterval: TimeInterval = 0.3
    @State private var inputText: String = ""
    @State private var debounceWorkItem: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 36 - CGFloat(SpacingScheme.smallSpacing) - 15) {
            Image("contact_search", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.template)
                .resizable()
                .frame(width: 15, height: 15 * (29.6484 / 27.889))
                .foregroundColor(themeState.colors.textColorTertiary)
            TextField("", text: $inputText, prompt: Text(placeholder).foregroundColor(themeState.colors.textColorTertiary))
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onChange(of: inputText) { newValue in
                    debounceWorkItem?.cancel()
                    let workItem = DispatchWorkItem { text = newValue }
                    debounceWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: workItem)
                }
            if !inputText.isEmpty {
                Button(action: {
                    debounceWorkItem?.cancel()
                    inputText = ""
                    text = ""
                }) {
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
        .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
        .padding(.trailing, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(height: 36)
        .background(themeState.colors.bgColorInput)
        .cornerRadius(CGFloat(RadiusScheme.alertRadius))
        .padding(CGFloat(SpacingScheme.bubbleSpacing))
        .background(themeState.colors.bgColorOperate)
    }
}


private struct ContactNavigationRow: View {
    @EnvironmentObject var themeState: ThemeState
    let item: ContactCustomItem
    @State private var badge: Int = 0

    var body: some View {
        HStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            Image(item.iconName, bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.original)
                .resizable()
                .frame(width: 40, height: 40)
            Text(item.title)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(FontScheme.caption4Regular)
                    .foregroundColor(themeState.colors.textColorButton)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, badge > 9 ? CGFloat(SpacingScheme.iconTextSpacing) : 0)
                    .background(themeState.colors.textColorError)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .frame(height: 60)
        .background(themeState.colors.bgColorOperate)
        .contentShape(Rectangle())
        .onReceive(item.badgeCount ?? Just(0).eraseToAnyPublisher()) { badge = $0 }
    }
}


struct ContactSubPageNavigationBar: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(themeState.fonts.caption1Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorOperate)
    }
}


struct GroupListViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) private var presentationMode
    @State private var groupList: [GroupInfo] = GroupStore.shared.state.value.joinedGroupList
    @State private var searchText = ""
    private let onGroupClick: ((AZOrderedListItem) -> Void)?
    private let onDismiss: (() -> Void)?

    init(
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onGroupClick = onGroupClick
        self.onDismiss = onDismiss
    }

    var body: some View {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let isSearching = !keyword.isEmpty
        let filtered = groupList.filter { group in
            guard isSearching else { return true }
            return [ContactDisplayName.name(for: group), group.groupID]
                .filter { !$0.isEmpty }
                .contains { $0.range(of: keyword, options: .caseInsensitive) != nil }
        }
        return VStack(spacing: 0) {
            ContactSubPageNavigationBar(title: LocalizedChatString("ContactsGroupChats"), onClose: close)
            ContactSearchBar(text: $searchText)
            AZOrderedListView(
                userList: filtered.map { group in
                    AZOrderedListItem(
                        userID: group.groupID,
                        avatarURL: group.avatarURL,
                        title: ContactDisplayName.name(for: group),
                        extraData: group
                    )
                },
                emptyText: LocalizedChatString(isSearching ? "SearchGroupNotFound" : "ContactNoGroupChats"),
                onUserInteraction: hideKeyboard,
                onItemClick: { item in
                    openChat(item)
                }
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())

        .onAppear {
            GroupStore.shared.loadJoinedGroups(completion: nil)
        }
        .onReceive(GroupStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))
            .receive(on: RunLoop.main)
        ) { groupList in
            self.groupList = groupList
        }
    }

    private func close() {
        if let onDismiss = onDismiss { onDismiss() } else { presentationMode.wrappedValue.dismiss() }
    }

    private func openChat(_ item: AZOrderedListItem) {
        hideKeyboard()
        onGroupClick?(item)
    }
}


struct BlackListViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) private var presentationMode
    @State private var blackList: [ContactInfo] = ContactStore.shared.state.value.blackList
    @State private var searchText = ""
    private let onContactClick: ((AZOrderedListItem) -> Void)?
    private let onDismiss: (() -> Void)?

    init(
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onContactClick = onContactClick
        self.onDismiss = onDismiss
    }

    var body: some View {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let isSearching = !keyword.isEmpty
        let filtered = blackList.filter { contact in
            guard isSearching else { return true }
            let candidates: [String?] = [ContactDisplayName.name(for: contact), contact.userID, contact.nickname, contact.friendRemark]
            return candidates.compactMap { $0 }.filter { !$0.isEmpty }
                .contains { $0.range(of: keyword, options: .caseInsensitive) != nil }
        }
        return VStack(spacing: 0) {
            ContactSubPageNavigationBar(title: LocalizedChatString("ContactsBlackList"), onClose: close)
            ContactSearchBar(text: $searchText)
            AZOrderedListView(
                userList: filtered.map { contact in
                    AZOrderedListItem(
                        userID: contact.userID,
                        avatarURL: contact.avatarURL,
                        title: ContactDisplayName.name(for: contact),
                        extraData: contact
                    )
                },
                emptyText: LocalizedChatString(isSearching ? "SearchBlacklistUserNotFound" : "ContactNoBlacklistUsers"),
                onUserInteraction: hideKeyboard,
                onItemClick: { item in
                    openChat(item)
                }
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())

        .onAppear {
            ContactStore.shared.loadBlackList(completion: nil)
        }
        .onReceive(ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.blackList))
            .receive(on: RunLoop.main)
        ) { blackList in
            self.blackList = blackList
        }
    }

    private func close() {
        if let onDismiss = onDismiss { onDismiss() } else { presentationMode.wrappedValue.dismiss() }
    }

    private func openChat(_ item: AZOrderedListItem) {
        hideKeyboard()
        onContactClick?(item)
    }
}


struct FriendApplicationListViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var friendApplicationList: [FriendApplicationInfo] = ContactStore.shared.state.value.friendApplicationList
    private let onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactSubPageNavigationBar(title: LocalizedChatString("ContactsFriendApplicationTitle"), onClose: { onDismiss?() })
            if friendApplicationList.isEmpty {
                ContactSubPageEmptyText(text: LocalizedChatString("ContactNoFriendApplication"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(friendApplicationList, id: \.userID) { application in
                            FriendApplicationCell(
                                application: application,
                                onAccept: { accept(application) },
                                onRefuse: { refuse(application) }
                            )
                        }
                    }
                    .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                }
            }
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear {
            ContactStore.shared.loadFriendApplications(completion: nil)
            ContactStore.shared.clearFriendApplicationUnreadCount(completion: nil)
        }
        .onReceive(ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationList))
            .receive(on: RunLoop.main)
        ) { friendApplicationList in
            self.friendApplicationList = friendApplicationList
        }
    }

    private func accept(_ application: FriendApplicationInfo) {
        ContactStore.shared.acceptFriendApplication(info: application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestAccepted"), type: .success, duration: 3)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestAcceptFailed"), type: .error, duration: 3)
                }
            }
        }
    }

    private func refuse(_ application: FriendApplicationInfo) {
        ContactStore.shared.refuseFriendApplication(info: application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestDeclined"), type: .info, duration: 3)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestDeclineFailed"), type: .error, duration: 3)
                }
            }
        }
    }
}


struct GroupApplicationListViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var groupApplicationList: [GroupApplicationInfo] = GroupStore.shared.state.value.applicationList
    private let onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactSubPageNavigationBar(title: LocalizedChatString("ContactsGroupApplicationTitle"), onClose: { onDismiss?() })
            if groupApplicationList.isEmpty {
                ContactSubPageEmptyText(text: LocalizedChatString("ContactNoGroupApplication"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupApplicationList, id: \.applicationID) { application in
                            GroupApplicationCell(
                                application: application,
                                onAccept: { accept(application) },
                                onRefuse: { refuse(application) }
                            )
                        }
                    }
                    .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                }
            }
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear {
            GroupStore.shared.loadApplications(completion: nil)
            GroupStore.shared.clearApplicationUnreadCount(completion: nil)
        }
        .onReceive(GroupStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.applicationList))
            .receive(on: RunLoop.main)
        ) { groupApplicationList in
            self.groupApplicationList = groupApplicationList
        }
    }

    private func accept(_ application: GroupApplicationInfo) {
        GroupStore.shared.acceptApplication(info: application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAccepted"), type: .success, duration: 3)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAcceptFailed"), type: .error, duration: 3)
                }
            }
        }
    }

    private func refuse(_ application: GroupApplicationInfo) {
        GroupStore.shared.refuseApplication(info: application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclined"), type: .success, duration: 3)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclineFailed"), type: .error, duration: 3)
                }
            }
        }
    }
}

private struct ContactSubPageEmptyText: View {
    @EnvironmentObject var themeState: ThemeState
    let text: String

    var body: some View {
        Text(text)
            .font(FontScheme.caption1Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom)
    }
}


private struct FriendApplicationCell: View {
    @EnvironmentObject var themeState: ThemeState
    let application: FriendApplicationInfo
    let onAccept: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        let name = ContactDisplayName.name(for: application)
        HStack(spacing: 0) {
            AvatarView(url: application.avatarURL, name: name, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                .frame(width: 40, height: 40)
                .padding(.trailing, CGFloat(SpacingScheme.iconIconSpacing))
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(themeState.fonts.caption2Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                if let wording = application.addWording, !wording.isEmpty {
                    Text(wording)
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                ContactApplicationButton(title: LocalizedChatString("Agree"), isPrimary: true,
                                         width: 70, cornerRadius: CGFloat(RadiusScheme.alertRadius), font: themeState.fonts.caption2Regular, action: onAccept)
                ContactApplicationButton(title: LocalizedChatString("Decline"), isPrimary: false,
                                         width: 70, cornerRadius: CGFloat(RadiusScheme.alertRadius), font: themeState.fonts.caption2Regular, action: onRefuse)
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
        .background(themeState.colors.bgColorOperate)
    }
}

private struct GroupApplicationCell: View {
    @EnvironmentObject var themeState: ThemeState
    let application: GroupApplicationInfo
    let onAccept: () -> Void
    let onRefuse: () -> Void

    private var canHandle: Bool {
        application.handledStatus == .unhandled || application.handledStatus == nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack {
                AvatarView(url: application.fromUserAvatarURL, name: fromUserDisplayName, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                    .frame(width: 40, height: 40)
                Spacer(minLength: 0)
            }
            .padding(.trailing, CGFloat(SpacingScheme.iconIconSpacing))
            VStack(alignment: .leading, spacing: 0) {
                Text(applicationTypeText)
                    .font(themeState.fonts.caption2Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Text(personText)
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Text("\(LocalizedChatString("GroupID"))  \u{FF1A}\(application.groupID)")
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                if let requestMsg = application.requestMsg, !requestMsg.isEmpty {
                    Text(requestMsg)
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if canHandle {
                HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    ContactApplicationButton(title: LocalizedChatString("Agree"), isPrimary: true,
                                             width: 60, cornerRadius: CGFloat(RadiusScheme.smallRadius), font: themeState.fonts.caption3Regular, action: onAccept)
                    ContactApplicationButton(title: LocalizedChatString("Decline"), isPrimary: false,
                                             width: 60, cornerRadius: CGFloat(RadiusScheme.smallRadius), font: themeState.fonts.caption3Regular, action: onRefuse)
                }
            } else {
                Text(handledStatusText)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .background(themeState.colors.bgColorOperate)
    }

    private var fromUserDisplayName: String {
        if let nickname = application.fromUserNickname, !nickname.isEmpty { return nickname }
        return application.fromUser ?? ""
    }

    private var applicationTypeText: String {
        switch application.type {
        case .joinApprovedByAdmin:
            return LocalizedChatString("GroupApplicationTypeApply")
        case .inviteApprovedByInvitee, .inviteApprovedByAdmin:
            return LocalizedChatString("GroupApplicationTypeInvite")
        }
    }

    private var personText: String {
        if application.type == .joinApprovedByAdmin {
            return "\(LocalizedChatString("GroupApplicationApplicant"))\u{FF1A}\(fromUserDisplayName)"
        }
        return "\(LocalizedChatString("GroupApplicationInvitee"))\u{FF1A}\(application.toUser ?? "")"
    }

    private var handledStatusText: String {
        switch application.handledStatus {
        case .unhandled:
            return LocalizedChatString("GroupApplicationStatusPending")
        case .byOther:
            return LocalizedChatString("GroupApplicationStatusByOther")
        case .byMyself:
            switch application.handledResult {
            case .refused:
                return LocalizedChatString("Disclined")
            case .agreed:
                return LocalizedChatString("Agreed")
            default:
                return LocalizedChatString("UserStatusUnknown")
            }
        default:
            return LocalizedChatString("UserStatusUnknown")
        }
    }
}

private struct ContactApplicationButton: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let isPrimary: Bool
    let width: CGFloat
    let cornerRadius: CGFloat
    let font: Font
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundColor(isPrimary ? themeState.colors.textColorButton : themeState.colors.textColorError)
                .lineLimit(1)
                .frame(width: width, height: 32)
                .background(isPrimary ? themeState.colors.buttonColorPrimaryDefault : Color.clear)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isPrimary ? Color.clear : themeState.colors.strokeColorPrimary, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


enum ContactDisplayName {
    static func name(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }

    static func name(for group: GroupInfo) -> String {
        if let groupName = group.groupName, !groupName.isEmpty { return groupName }
        return group.groupID
    }

    static func name(for application: FriendApplicationInfo) -> String {
        if let title = application.title, !title.isEmpty { return title }
        return application.userID
    }
}

struct NavigationTitleModifier: ViewModifier {
    let title: String?

    func body(content: Content) -> some View {
        if let title = title {
            content.navigationTitle(title)
        } else {
            content
        }
    }
}
