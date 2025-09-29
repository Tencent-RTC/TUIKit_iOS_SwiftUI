import AtomicXCore
import SwiftUI

public struct ContactListWithNavigation: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var friendList: [ContactInfo] = []
    @State private var friendApplicationUnreadCount: Int = 0
    @State private var groupApplicationUnreadCount: Int = 0
    private var contactStore: ContactListStore
    private let onShowMessage: ((ConversationInfo) -> Void)?
    private let onContactClick: ((AZOrderedListItem) -> Void)?
    private let onGroupClick: ((AZOrderedListItem) -> Void)?
    private let onNewFriendsClick: (() -> Void)?
    private let onGroupApplicationsClick: (() -> Void)?
    private let onGroupListClick: (() -> Void)?
    private let onBlackListClick: (() -> Void)?

    public init(
        onShowMessage: ((ConversationInfo) -> Void)? = nil,
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil,
        onNewFriendsClick: (() -> Void)? = nil,
        onGroupApplicationsClick: (() -> Void)? = nil,
        onGroupListClick: (() -> Void)? = nil,
        onBlackListClick: (() -> Void)? = nil
    ) {
        self.contactStore = ContactListStore.create()
        self.onShowMessage = onShowMessage
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
        self.onNewFriendsClick = onNewFriendsClick
        self.onGroupApplicationsClick = onGroupApplicationsClick
        self.onGroupListClick = onGroupListClick
        self.onBlackListClick = onBlackListClick
        fetchData()
    }

    public var body: some View {
        VStack(spacing: 0) {
            AZOrderedList(
                userList: friendList.map { contact in
                    AZOrderedListItem(
                        userID: contact.contactID,
                        avatarURL: contact.avatarURL,
                        title: contact.title
                    )
                },
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
            .id(friendList.map { "\($0.contactID)-\($0.title ?? "")" }.joined(separator: ","))
        }
        .background(themeState.colors.listColorDefault)
        .onAppear {
            fetchData()
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))) { friendList in
            self.friendList = friendList
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendApplicationUnreadCount))) { friendApplicationUnreadCount in
            self.friendApplicationUnreadCount = friendApplicationUnreadCount
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.groupApplicationUnreadCount))) { groupApplicationUnreadCount in
            self.groupApplicationUnreadCount = groupApplicationUnreadCount
        }
    }

    private func fetchData() {
        contactStore.fetchFriendList(completion: nil)
        contactStore.fetchGroupApplicationList(completion: nil)
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
