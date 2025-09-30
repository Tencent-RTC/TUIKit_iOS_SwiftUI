import AtomicXCore
import Combine
import SwiftUI

public struct ContactList: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var friendList: [ContactInfo] = []
    @State private var friendApplicationUnreadCount: Int = 0
    @State private var groupApplicationUnreadCount: Int = 0
    private let contactStore: ContactListStore
    private let onShowMessage: ((ConversationInfo) -> Void)?
    private let onContactClick: ((AZOrderedListItem) -> Void)?
    private let onGroupClick: ((AZOrderedListItem) -> Void)?
    private let onNewFriendsClick: (() -> Void)?
    private let onGroupApplicationsClick: (() -> Void)?
    private let onGroupListClick: (() -> Void)?
    private let onBlackListClick: (() -> Void)?

    public init(
        contactStore: ContactListStore = ContactListStore.create(),
        onShowMessage: ((ConversationInfo) -> Void)? = nil,
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil,
        onNewFriendsClick: (() -> Void)? = nil,
        onGroupApplicationsClick: (() -> Void)? = nil,
        onGroupListClick: (() -> Void)? = nil,
        onBlackListClick: (() -> Void)? = nil
    ) {
        self.contactStore = contactStore
        self.onShowMessage = onShowMessage
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
        self.onNewFriendsClick = onNewFriendsClick
        self.onGroupApplicationsClick = onGroupApplicationsClick
        self.onGroupListClick = onGroupListClick
        self.onBlackListClick = onBlackListClick
    }

    public var body: some View {
        let userList = friendList.map { contact in
            AZOrderedListItem(
                userID: contact.contactID,
                avatarURL: contact.avatarURL,
                title: contact.title
            )
        }

        return VStack(spacing: 0) {
            AZOrderedList(
                userList: userList,
                header: AnyView(
                    VStack(spacing: 0) {
                        Button(action: {
                            onNewFriendsClick?()
                        }) {
                            ContactNavigationRow(
                                title: LocalizedChatString("ContactsNewFriends"),
                                badge: friendApplicationUnreadCount > 0 ? friendApplicationUnreadCount : nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            onGroupApplicationsClick?()
                        }) {
                            ContactNavigationRow(
                                title: LocalizedChatString("ContactsGroupApplications"),
                                badge: groupApplicationUnreadCount > 0 ? groupApplicationUnreadCount : nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            onGroupListClick?()
                        }) {
                            ContactNavigationRow(title: LocalizedChatString("ContactsGroupChats"))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            onBlackListClick?()
                        }) {
                            ContactNavigationRow(title: LocalizedChatString("ContactsBlackList"))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .background(themeState.colors.bgColorOperate)
                ),
                onItemClick: { user in
                    onContactClick?(user)
                }
            )
        }
        .background(themeState.colors.listColorDefault)
        .onReceive(contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))
            .receive(on: RunLoop.main)
        ) { friendList in
            if friendList.isEmpty && !self.friendList.isEmpty {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.friendList = friendList
            }
        }
        .onReceive(contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactListState.friendApplicationUnreadCount))
            .receive(on: RunLoop.main)
        ) { friendApplicationUnreadCount in
            self.friendApplicationUnreadCount = friendApplicationUnreadCount
        }
        .onReceive(contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactListState.groupApplicationUnreadCount))
            .receive(on: RunLoop.main)
        ) { groupApplicationUnreadCount in
            self.groupApplicationUnreadCount = groupApplicationUnreadCount
        }
        .onAppear {
            syncCurrentStateFromStore()
            fetchData()
        }
    }

    private func fetchData() {
        contactStore.fetchFriendList(completion: nil)
        contactStore.fetchGroupApplicationList(completion: nil)
    }

    private func syncCurrentStateFromStore() {
        let state = contactStore.state.value
        DispatchQueue.main.async {
            self.friendList = state.friendList
            self.friendApplicationUnreadCount = state.friendApplicationUnreadCount
            self.groupApplicationUnreadCount = state.groupApplicationUnreadCount
        }
    }
}

private struct ContactNavigationRow: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let badge: Int?

    init(title: String, badge: Int? = nil) {
        self.title = title
        self.badge = badge
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
            if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeState.colors.textColorSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorOperate)
    }
}

private struct FriendApplicationCell: View {
    @EnvironmentObject var themeState: ThemeState
    let application: FriendApplicationInfo
    let onAccept: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Avatar(
                    url: application.avatarURL,
                    name: application.title ?? application.applicationID
                )
                Text(application.title ?? application.applicationID)
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Button(LocalizedChatString("Agree")) {
                        onAccept()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeState.colors.textColorLink)
                    .foregroundColor(themeState.colors.textColorButton)
                    .cornerRadius(6)
                    .font(.system(size: 14))
                    Button(LocalizedChatString("Decline")) {
                        onRefuse()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeState.colors.buttonColorSecondaryDefault)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .cornerRadius(6)
                    .font(.system(size: 14))
                }
            }
            if let addWording = application.addWording, !addWording.isEmpty {
                Text(addWording)
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.leading, 48)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }
}

private struct GroupApplicationCell: View {
    @EnvironmentObject var themeState: ThemeState
    let application: GroupApplicationInfo
    let onAccept: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Avatar(
                    url: application.fromUserAvatarURL,
                    name: application.fromUserNickname ?? application.fromUser ?? application.applicationID
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.fromUserNickname ?? application.fromUser ?? application.applicationID)
                        .font(.body)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    Text(application.groupID)
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)

                    Text(application.requestMsg ?? "")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }

                Spacer()

                if application.handledStatus != .unhandled {
                    Text(getHandledStatusText())
                        .font(.system(size: 14))
                        .foregroundColor(getHandledStatusColor())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    HStack(spacing: 8) {
                        Button(LocalizedChatString("Agree")) {
                            onAccept()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeState.colors.textColorLink)
                        .foregroundColor(themeState.colors.textColorButton)
                        .cornerRadius(6)
                        .font(.system(size: 14))
                        Button(LocalizedChatString("Decline")) {
                            onRefuse()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeState.colors.buttonColorSecondaryDefault)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .cornerRadius(6)
                        .font(.system(size: 14))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }

    private func getHandledStatusText() -> String {
        guard let handledResult = application.handledResult else {
            return ""
        }
        switch handledResult {
        case .agreed:
            return LocalizedChatString("Agreed")
        case .refused:
            return LocalizedChatString("Disclined")
        }
    }

    private func getHandledStatusColor() -> Color {
        guard let handledResult = application.handledResult else {
            return themeState.colors.textColorSecondary
        }

        switch handledResult {
        case .agreed:
            return .green
        case .refused:
            return .red
        }
    }
}

// MARK: - Group List View

public struct GroupListView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var groupList: [ContactInfo] = []
    private var contactStore: ContactListStore
    private let onShowMessage: ((ConversationInfo) -> Void)?
    private let onShowProfile: ((AZOrderedListItem) -> Void)?
    private let showsNavigationTitle: Bool

    public init(
        contactStore: ContactListStore,
        onShowMessage: ((ConversationInfo) -> Void)? = nil,
        onShowProfile: ((AZOrderedListItem) -> Void)? = nil,
        showsNavigationTitle: Bool = true
    ) {
        self.contactStore = contactStore
        self.onShowMessage = onShowMessage
        self.onShowProfile = onShowProfile
        self.showsNavigationTitle = showsNavigationTitle
    }

    private func fetchData() {
        contactStore.fetchJoinedGroupList(completion: nil)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(groupList, id: \.contactID) { group in
                    Button(action: {
                        if let onShowMessage = onShowMessage {
                            let conversation = createConversationFromGroup(group)
                            onShowMessage(conversation)
                        } else {
                            let groupItem = AZOrderedListItem(
                                userID: group.contactID,
                                avatarURL: group.avatarURL,
                                title: group.title ?? group.contactID
                            )
                            onShowProfile?(groupItem)
                        }
                    }) {
                        HStack {
                            Avatar(
                                url: group.avatarURL,
                                name: group.title ?? group.contactID
                            )
                            Text(group.title ?? group.contactID)
                                .font(.body)
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(themeState.colors.bgColorOperate)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            contactStore.fetchJoinedGroupList(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.groupList))) { groupList in
            self.groupList = groupList
        }
        .modifier(NavigationTitleModifier(title: showsNavigationTitle ? LocalizedChatString("ContactsGroupChats") : nil))
    }

    private func createConversationFromGroup(_ group: ContactInfo) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.contactID))
        conversation.avatarURL = group.avatarURL
        conversation.type = .group
        conversation.title = group.title ?? group.contactID
        return conversation
    }
}

// MARK: - Black List View

public struct BlackListView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var blackList: [ContactInfo] = []
    private var contactStore: ContactListStore
    private let onShowProfile: ((AZOrderedListItem) -> Void)?
    private let showsNavigationTitle: Bool

    public init(
        contactStore: ContactListStore,
        onShowProfile: ((AZOrderedListItem) -> Void)? = nil,
        showsNavigationTitle: Bool = true
    ) {
        self.contactStore = contactStore
        self.onShowProfile = onShowProfile
        self.showsNavigationTitle = showsNavigationTitle
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(blackList, id: \.contactID) { contact in
                    Button(action: {
                        let userItem = AZOrderedListItem(
                            userID: contact.contactID,
                            avatarURL: contact.avatarURL,
                            title: contact.title ?? contact.contactID
                        )
                        onShowProfile?(userItem)
                    }) {
                        HStack {
                            Avatar(
                                url: contact.avatarURL,
                                name: contact.title ?? contact.contactID
                            )
                            Text(contact.title ?? contact.contactID)
                                .font(.body)
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(themeState.colors.bgColorOperate)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            contactStore.fetchBlackList(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.blackList))) { blackList in
            self.blackList = blackList
        }
        .modifier(NavigationTitleModifier(title: showsNavigationTitle ? LocalizedChatString("ContactsBlackList") : nil))
    }
}

// MARK: - Friend Application List View

public struct FriendApplicationListView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var friendApplicationList: [FriendApplicationInfo] = []
    private var contactStore: ContactListStore

    public init(contactStore: ContactListStore) {
        self.contactStore = contactStore
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(friendApplicationList, id: \.applicationID) { application in
                    FriendApplicationCell(
                        application: application,
                        onAccept: {
                            contactStore.acceptFriendApplication(info: application) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestAccepted"), type: .success, duration: 3)
                                    case .failure(let error):
                                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestAcceptFailed"), type: .error, duration: 3)
                                    }
                                }
                            }
                        },
                        onRefuse: {
                            contactStore.refuseFriendApplication(info: application) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestDeclined"), type: .info, duration: 3)
                                    case .failure(let error):
                                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestDeclineFailed"), type: .error, duration: 3)
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            contactStore.fetchFriendApplicationList(completion: nil)
            contactStore.clearFriendApplicationUnreadCount(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendApplicationList))) { friendApplicationList in
            self.friendApplicationList = friendApplicationList
        }
    }
}

// MARK: - Group Application List View

public struct GroupApplicationListView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var groupApplicationList: [GroupApplicationInfo] = []
    private var contactStore: ContactListStore

    public init(contactStore: ContactListStore) {
        self.contactStore = contactStore
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(groupApplicationList, id: \.applicationID) { application in
                    GroupApplicationCell(
                        application: application,
                        onAccept: {
                            contactStore.acceptGroupApplication(info: application) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAccepted"), type: .success, duration: 3)
                                    case .failure(let error):
                                        WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAcceptFailed"), type: .error, duration: 3)
                                    }
                                }
                            }
                        },
                        onRefuse: {
                            contactStore.refuseGroupApplication(info: application) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclined"), type: .success, duration: 3)
                                    case .failure(let error):
                                        WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclineFailed"), type: .error, duration: 3)
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            contactStore.fetchGroupApplicationList(completion: nil)
            contactStore.clearGroupApplicationUnreadCount(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.groupApplicationList))) { groupApplicationList in
            self.groupApplicationList = groupApplicationList
        }
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
