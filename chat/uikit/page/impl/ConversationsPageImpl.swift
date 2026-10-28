import AtomicXCore
import SwiftUI

class SelectedUsersContainer: ObservableObject {
    @Published var users: [UserPickerItem] = []
}

struct ConversationsPageImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var selectedUsersContainer = SelectedUsersContainer()
    @State private var showUserPicker = false
    @State private var showConfigSheet = false
    @State private var showStartConversation = false
    @State private var showCreateGroup = false
    @State private var showChatsMenu = false
    @State private var chatsMenuAnchor: CGRect = .zero
    @State var friendList: [ContactInfo] = []
    @State private var hostViewController: UIViewController?
    @State private var pendingCreatedChat: NavigationInfo?

    var onConversationClick: ((NavigationInfo) -> Void)?
    private let config: ConversationActionConfig

    init(
        config: ConversationActionConfig? = nil,
        onConversationClick: ((NavigationInfo) -> Void)? = nil
    ) {
        self.config = config ?? ConversationActionConfig()
        self.onConversationClick = onConversationClick
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            SearchBarView(onTapItem: { result in
                handleSearchResult(result)
            }, preservesSearchOnSelection: true)
            .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))

            ConversationListView(
                onConversationClick: { conversation in
                    onConversationClick?(NavigationInfo(conversation: conversation))
                },
                config: config
            )
            .environmentObject(themeState)
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea(edges: .top))
        .background(HostViewControllerBeacon { hostViewController = $0 })
        .onChange(of: pendingCreatedChat?.conversation.conversationID) { _ in
            deliverCreatedChatIfReady()
        }
        .onReceive(ContactStore.shared.state.subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))) { friendList in
            if self.friendList != friendList {
                self.friendList = friendList
            }
        }
        .onAppear {
            ContactStore.shared.loadFriends(completion: nil)
            deliverCreatedChatIfReady()
        }
        .overlay(
            ChatsMenuOverlay(
                showChatsMenu: $showChatsMenu,
                showStartConversation: $showStartConversation,
                showUserPicker: $showUserPicker,
                anchor: chatsMenuAnchor
            )
        )
        .onDisappear { showChatsMenu = false }
        .background(
            NavigationLink(
                destination: StartConversationSheet(
                    onUserSelected: { user in
                        let conversation = createConversationFromUser(user)
                        pendingCreatedChat = NavigationInfo(conversation: conversation)
                        showStartConversation = false
                    }
                ),
                isActive: $showStartConversation
            ) { EmptyView() }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: CreateGroupMemberPickerView(
                    userList: friendList.map { contact in
                        UserPickerItem(
                            userID: contact.userID,
                            avatarURL: contact.avatarURL,
                            title: contactDisplayName(contact)
                        )
                    },
                    onGroupCreated: { createdGroupID, groupName, conversationId in
                        showUserPicker = false
                        if let groupID = createdGroupID,
                           let name = groupName,
                           let convId = conversationId
                        {
                            let conversation = createConversationFromGroupInfo(
                                groupID: groupID,
                                groupName: name,
                                conversationId: convId
                            )
                            pendingCreatedChat = NavigationInfo(conversation: conversation)
                        }
                    },
                    onCancel: {
                        showUserPicker = false
                    }
                ),
                isActive: $showUserPicker
            ) { EmptyView() }
            .hidden()
        )
    }

    private var headerView: some View {
        Text(LocalizedChatString("TabChats"))
            .font(themeState.fonts.body4Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
            .overlay(headerAddButton, alignment: .trailing)
    }

    private var headerAddButton: some View {
        Group {
            HStack {
                Spacer()
                if AppBuilderConfig.shared.enableCreateConversation {
                    Button(action: {
                        showChatsMenu.toggle()
                    }) {
                        Image("contact_add_circle", bundle: AtomicXChatResources.resourceBundle)
                            .renderingMode(.template)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .frame(width: 24, height: 24)
                    }
                    .popMenuAnchor($chatsMenuAnchor)
                    .padding(.trailing, CGFloat(SpacingScheme.bubbleSpacing))
                }
            }
        }
    }


    private func deliverCreatedChatIfReady() {
        guard let navigationInfo = pendingCreatedChat,
              !showUserPicker, !showStartConversation,
              let hostViewController = hostViewController,
              let navigationController = hostViewController.navigationController else { return }
        if let transition = navigationController.transitionCoordinator {
            transition.animate(alongsideTransition: nil) { _ in
                DispatchQueue.main.async {
                    deliverCreatedChatIfReady()
                }
            }
            return
        }
        guard navigationController.topViewController === hostViewController else { return }
        pendingCreatedChat = nil
        onConversationClick?(navigationInfo)
    }

    private func handleSearchResult(_ result: Any) {
        if let info = searchResultNavigationInfo(result) {
            onConversationClick?(info)
        }
    }

    private func createConversationFromUser(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.avatarURL = user.avatarURL
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        return conversation
    }

    private func createConversationFromGroupInfo(groupID: String, groupName: String, conversationId: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: conversationId)
        conversation.type = .group
        conversation.title = groupName
        conversation.avatarURL = nil
        return conversation
    }
}

struct ChatsMenuOverlay: View {
    @Binding var showChatsMenu: Bool
    @Binding var showStartConversation: Bool
    @Binding var showUserPicker: Bool
    let anchor: CGRect

    var body: some View {
        AnchoredPopMenuOverlay(
            isPresented: $showChatsMenu,
            anchor: anchor,
            items: [
                PopMenuInfo(icon: "contact_add_friend", title: LocalizedChatString("ChatsNewChatText")) {
                    showStartConversation = true
                },
                PopMenuInfo(icon: "contact_add_group", title: LocalizedChatString("ChatsNewGroupText")) {
                    showUserPicker = true
                }
            ]
        )
    }
}

struct StartConversationSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var friendList: [ContactInfo] = []
    @State private var isLoading = true
    var onUserSelected: (AZOrderedListItem) -> Void

    var body: some View {
        VStack {
            if isLoading && friendList.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                AZOrderedListView(
                    userList: orderedListItems,
                    onItemClick: { user in
                        onUserSelected(user)
                    }
                )
            }
        }
        .navigationBarTitle(LocalizedChatString("ChatsNewChatText"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: NavBackButtonView {
            presentationMode.wrappedValue.dismiss()
        })
        .onAppear {
            loadFriendList()
        }
        .onReceive(ContactStore.shared.state.subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))) { newFriendList in
            DispatchQueue.main.async {
                self.friendList = newFriendList
            }
        }
    }

    private func loadFriendList() {
        isLoading = true

        let currentFriendList = ContactStore.shared.state.value.friendList
        if !currentFriendList.isEmpty {
            DispatchQueue.main.async {
                self.friendList = currentFriendList
                self.isLoading = false
            }
        }

        ContactStore.shared.loadFriends(completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("StartConversationSheet: Successfully fetched friend list")
                case .failure(let error):
                    print("StartConversationSheet: Failed to fetch friend list: \(error)")
                    self.isLoading = false
                }
            }
        })
    }

    private var orderedListItems: [AZOrderedListItem] {
        return friendList.map { contact in
            AZOrderedListItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: contactDisplayName(contact)
            )
        }
    }
}

private func contactDisplayName(_ contact: ContactInfo) -> String {
    if let friendRemark = contact.friendRemark, !friendRemark.isEmpty {
        return friendRemark
    } else if let nickname = contact.nickname, !nickname.isEmpty {
        return nickname
    } else {
        return contact.userID
    }
}
