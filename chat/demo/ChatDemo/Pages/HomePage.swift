import AtomicX
import AtomicXCore
import ChatUIKit
import SwiftUI

public struct HomePage: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var appStyleSettings: AppStyleSettings
    @EnvironmentObject var languageState: LanguageState
    @EnvironmentObject var pushNavigationManager: PushNavigationManager
    @StateObject private var homeToast = Toast()
    @State private var selectedTab: Tab = .chats
    @StateObject private var storeHolder = HomePageStoreHolder()
    @State private var totalUnreadCount: UInt = 0

    @State private var showChatPage: Bool = false
    @State private var showC2CChatSetting: Bool = false

    @State private var currentConversation: ConversationInfo? = nil
    @State private var currentLocateMessage: MessageInfo? = nil
    @State private var currentContactUser: AZOrderedListItem? = nil

    private var conversationListStore: ConversationListStore {
        storeHolder.conversationListStore
    }

    public init() {}

    public var body: some View {
        ZStack {
            TabView(selection: self.$selectedTab) {
                ConversationsPage(
                    onConversationClick: { navigationInfo in
                        showChatPage(conversation: navigationInfo.conversation, locateMessage: navigationInfo.locateMessage)
                    }
                )
                .navigationTitle("")
                .navigationBarHidden(true)
                .tabItem {
                    Label(LocalizedChatString("TabChats"), image: "tab_chat")
                }
                .tag(Tab.chats)
                .modifier(TabBadgeModifier(count: totalUnreadCount))

                ContactsPage(
                    onContactClick: { user in
                        showC2CChatSetting(user)
                    },
                    onGroupClick: { group in
                        let conversation = createConversationFromGroup(group)
                        showChatPage(conversation: conversation)
                    }
                )
                .tabItem {
                    Label(LocalizedChatString("TabContacts"), image: "tab_contact")
                }
                .tag(Tab.contacts)
                .navigationTitle("")
                .navigationBarHidden(true)

                SettingsPage()
                    .tabItem {
                        Label(LocalizedChatString("TabSettings"), image: "tab_setting")
                    }
                    .tag(Tab.settings)
                    .navigationTitle("")
                    .navigationBarHidden(true)
            }
            .id("TabView-\(themeState.currentTheme.mode)")
            .background(themeState.colors.bgColorOperate)
            .onAppear {
                updateTabBarAppearance()
            }
            .onChange(of: themeState.currentTheme.mode) { _ in
                updateTabBarAppearance()
            }
            .navigationBarHidden(true)
            .navigationTitle("")

            ZStack {
                if let conversation = currentConversation {
                    NavigationLink(
                        destination: ChatNavPage(
                            conversation: conversation,
                            locateMessage: currentLocateMessage,
                            onBack: {
                                dismissChatPage()
                            },
                            onContactDelete: {
                                dismissChatPage()
                            },
                            onGroupDelete: {
                                dismissChatPage()
                            },
                            onNavigateToChat: { newConversation in
                                // First dismiss current chat page, then navigate to the new chat
                                dismissChatPage()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showChatPage(conversation: newConversation)
                                }
                            }
                        )
                        .navigationBarHidden(true),
                        isActive: $showChatPage
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if let contactUser = currentContactUser {
                    NavigationLink(
                        destination: C2CChatSetting(
                            userID: contactUser.userID,
                            onSendMessageClick: {
                                let newConversation = createConversationFromUser(contactUser)
                                dismissContactDetail()
                                showChatPage(conversation: newConversation)
                            }
                        )
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                        isActive: $showC2CChatSetting
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accentColor(themeState.colors.buttonColorPrimaryDefault)
        .toast(homeToast)
        .id("HomePage-\(languageState.currentLanguage)")
        .onReceive(conversationListStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))) { unreadCount in
            self.totalUnreadCount = UInt(unreadCount)
        }
        .onAppear {
            // Initialize with current value
            conversationListStore.loadConversations(option: nil, completion: nil)
        }
        .onChange(of: pushNavigationManager.pendingNavigation) { navigationInfo in
            handlePushNavigation(navigationInfo)
        }
    }

    private func showChatPage(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        currentConversation = conversation
        currentLocateMessage = locateMessage
        showChatPage = true
    }

    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(themeState.colors.bgColorOperate)
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func showC2CChatSetting(    _ user: AZOrderedListItem) {
        currentContactUser = user
        showC2CChatSetting = true
    }

    private func dismissChatPage() {
        showChatPage = false
    }

    private func dismissContactDetail() {
        showC2CChatSetting = false
    }

    private func createConversationFromUser(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.avatarURL = user.avatarURL
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        return conversation
    }

    private func createConversationFromGroup(_ group: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.id))
        conversation.avatarURL = group.avatarURL
        conversation.type = .group
        conversation.title = group.title ?? group.id
        return conversation
    }

    // MARK: - Push Navigation Handling

    private func handlePushNavigation(_ navigationInfo: PushNavigationInfo?) {
        guard let info = navigationInfo else { return }

        // Switch to chats tab first
        selectedTab = .chats

        // Get conversationID from userID or groupID
        let conversationID: String
        let conversationType: ConversationType
        
        if let groupID = info.groupID {
            conversationID = ChatUtil.getGroupConversationID(groupID)
            conversationType = .group
        } else if let userID = info.userID {
            conversationID = ChatUtil.getC2CConversationID(userID)
            conversationType = .c2c
        } else {
            pushNavigationManager.clearPendingNavigation()
            return
        }
        
        // Try to find existing conversation from conversation list
        if let existingConversation = conversationListStore.state.value.conversationList.first(where: { $0.conversationID == conversationID }) {
            // Use existing conversation info with proper title and avatar
            print(">>>>> Found existing conversation: \(conversationID), title: \(existingConversation.title ?? "nil")")
            showChatPage(conversation: existingConversation)
        } else {
            // Conversation not in list, fetch from server
            print(">>>>> Conversation not found in list, fetching: \(conversationID)")
            conversationListStore.getConversationInfo(
                conversationID: conversationID,
                completion: HomeConversationInfoHandler(
                    onSuccess: { fetchedConversation in
                        DispatchQueue.main.async {
                            print(">>>>> Fetched conversation: \(conversationID), title: \(fetchedConversation.title ?? "nil")")
                            self.showChatPage(conversation: fetchedConversation)
                        }
                    },
                    onFailure: { _, _ in
                        DispatchQueue.main.async {
                            // Fallback: create conversation with ID as title
                            print(">>>>> Failed to fetch conversation, using fallback")
                            self.showFallbackConversation(
                                conversationID: conversationID,
                                type: conversationType,
                                fallbackTitle: info.groupID ?? info.userID ?? conversationID
                            )
                        }
                    }
                )
            )
        }

        // Clear pending navigation
        pushNavigationManager.clearPendingNavigation()
    }
    
    private func showFallbackConversation(conversationID: String, type: ConversationType, fallbackTitle: String) {
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = type
        conversation.title = fallbackTitle
        showChatPage(conversation: conversation)
    }
}

enum Tab {
    case chats, contacts, settings
}

struct TabBadgeModifier: ViewModifier {
    let count: UInt
    func body(content: Content) -> some View {
        let badgeValue = count > 0 ? (count > 99 ? "99+" : "\(count)") : nil
        return content.badge(badgeValue)
    }
}

// MARK: - FriendshipHelper

extension HomePage {
    static func checkIsFriend(userID: String, completion: @escaping (Bool) -> Void) {
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: HomeContactInfoHandler(
                onSuccess: { contactInfoList in
                    completion(contactInfoList.first?.isFriend ?? false)
                },
                onFailure: { _, _ in
                    // If failed to get user info, assume not a friend
                    completion(false)
                }
            )
        )
    }
}

private final class HomeConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}

/// Holds a single ``ConversationListStore`` instance for the lifetime of a
/// `HomePage` view. Wrapped in `ObservableObject` so it can be used with
/// `@StateObject`, which guarantees the store is constructed exactly once per
/// view identity. SwiftUI may rebuild the `HomePage` struct on environment
/// changes (theme / language / pushNavigation); if the store were a plain
/// stored property created in `init`, every rebuild would create a new
/// `ConversationListStoreImpl`, registering a fresh IM SDK listener and then
/// immediately deallocating the previous instance, eventually leaving the SDK
/// with a dangling listener pointer and crashing in `objc_retain` on the next
/// dispatch (observed on iPhone XR / iOS 16.6).
private final class HomePageStoreHolder: ObservableObject {
    let conversationListStore: ConversationListStore

    init() {
        self.conversationListStore = ConversationListStore.create()
    }
}

private final class HomeContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
