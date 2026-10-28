import TUIChatKit_Swift
import AtomicXCore
import SwiftUI
import UIKit

struct ChatNavPage: View {
    @EnvironmentObject var themeState: ThemeState
    
    let conversation: ConversationInfo
    let locateMessage: MessageInfo?
    let onBack: () -> Void
    let onContactDelete: () -> Void
    let onGroupDelete: () -> Void
    let onNavigateToChat: ((ConversationInfo) -> Void)?
    
    @State private var showC2CChatSetting: Bool = false
    @State private var showGroupChatSetting: Bool = false
    @State private var currentC2CUserID: String? = nil
    @State private var currentGroupID: String? = nil
    @State private var showSecurityWarning: Bool = true
    @State private var hostViewController: UIViewController?
    
    init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        onBack: @escaping () -> Void,
        onContactDelete: @escaping () -> Void,
        onGroupDelete: @escaping () -> Void,
        onNavigateToChat: ((ConversationInfo) -> Void)? = nil
    ) {
        self.conversation = conversation
        self.locateMessage = locateMessage
        self.onBack = onBack
        self.onContactDelete = onContactDelete
        self.onGroupDelete = onGroupDelete
        self.onNavigateToChat = onNavigateToChat
    }
    
    var body: some View {
        ZStack {
            ChatPage(
                conversation: conversation,
                locateMessage: locateMessage,
                messageInputConfig: CustomLinkMessageManager.makeInputConfig(conversationID: conversation.conversationID),
                topBannerView: showSecurityWarning ? AnyView(ChatSecurityWarningBanner { showSecurityWarning = false }) : nil,
                onBack: onBack,
                onUserClick: { userID in
                    handleUserAvatarClick(userID: userID)
                },
                onMoreClick: {
                    handleNavigationAvatarClick()
                }
            )
            .background(ViewControllerBeacon { hostViewController = $0 })
            
            if let userID = currentC2CUserID {
                NavigationLink(
                    destination: ChatProfilePushed(
                        userID: userID,
                        parentConversationID: conversation.conversationID,
                        onContactDelete: onContactDelete
                    )
                    .id(userID),
                    isActive: $showC2CChatSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
            
            if let groupID = currentGroupID {
                NavigationLink(
                    destination: NestedGroupSetting(
                        groupID: groupID,
                        parentConversationID: conversation.conversationID,
                        onBack: {
                            dismissGroupChatSetting()
                        },
                        onGroupDelete: {
                            dismissGroupChatSetting()
                            onGroupDelete()
                        }
                    )
                    .id(groupID)
                    .navigationBarTitle(LocalizedChatString("GroupSettings"), displayMode: .inline),
                    isActive: $showGroupChatSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }
    
    
    private func handleUserAvatarClick(userID: String) {
        guard let navigationController = hostViewController?.navigationController else { return }
        let profile = ChatProfilePushed(
            userID: userID,
            parentConversationID: conversation.conversationID,
            onContactDelete: onContactDelete
        )
        .environmentObject(themeState)
        navigationController.pushViewController(UIHostingController(rootView: profile), animated: true)
    }
    
    private func handleNavigationAvatarClick() {
        if conversation.type == .c2c {
            if let userID = ChatUtil.getUserID(conversation.conversationID) {
                currentC2CUserID = userID
                showC2CChatSetting = true
            }
        } else if conversation.type == .group {
            if let groupID = ChatUtil.getGroupID(conversation.conversationID) {
                currentGroupID = groupID
                showGroupChatSetting = true
            }
        }
    }
    
    private func dismissGroupChatSetting() {
        showGroupChatSetting = false
        currentGroupID = nil
    }
}


private struct NestedC2CSetting: View {
    @EnvironmentObject var themeState: ThemeState
    
    let userID: String
    let parentConversationID: String
    let onBack: () -> Void
    let onContactDelete: () -> Void
    
    @State private var showNestedChat: Bool = false
    @State private var nestedConversation: ConversationInfo? = nil
    
    @State private var userRemark: String = ""
    @State private var userNickname: String = ""
    @State private var userAvatarURL: String = ""
    
    init(
        userID: String,
        parentConversationID: String,
        onBack: @escaping () -> Void,
        onContactDelete: @escaping () -> Void
    ) {
        self.userID = userID
        self.parentConversationID = parentConversationID
        self.onBack = onBack
        self.onContactDelete = onContactDelete
    }
    
    private var displayName: String {
        if !userRemark.isEmpty {
            return userRemark
        } else if !userNickname.isEmpty {
            return userNickname
        } else {
            return userID
        }
    }
    
    var body: some View {
        ZStack {
            C2CChatSettingView(
                userID: userID,
                onSendMessageClick: {
                    handleSendMessageClick()
                },
                onContactDelete: onContactDelete,
                onBack: onBack
            )
            
            if let conversation = nestedConversation {
                NavigationLink(
                    destination: NestedChat(
                        conversation: conversation,
                        userID: userID,
                        onBack: {
                            dismissNestedChat()
                        }
                    )
                    .navigationBarHidden(true),
                    isActive: $showNestedChat
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .onAppear {
            ContactStore.shared.getContactInfo(
                userIDList: [userID],
                completion: NestedContactInfoHandler(
                    onSuccess: { contactInfoList in
                        guard let contactInfo = contactInfoList.first else { return }
                        DispatchQueue.main.async {
                            self.userRemark = contactInfo.friendRemark ?? ""
                            self.userNickname = contactInfo.nickname ?? ""
                            self.userAvatarURL = contactInfo.avatarURL ?? ""
                        }
                    },
                    onFailure: { _, _ in }
                )
            )
        }
    }
    
    private func handleSendMessageClick() {
        let targetConversationID = ChatUtil.getC2CConversationID(userID)
        
        if parentConversationID == targetConversationID {
            onBack()
            return
        }
        
        var conversation = ConversationInfo(conversationID: targetConversationID)
        conversation.type = .c2c
        conversation.title = displayName
        conversation.avatarURL = userAvatarURL
        
        nestedConversation = conversation
        showNestedChat = true
    }
    
    private func dismissNestedChat() {
        showNestedChat = false
    }
}

private final class NestedContactInfoHandler: GetContactInfoCompletionHandler {
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


private struct NestedChat: View {
    @EnvironmentObject var themeState: ThemeState
    
    let conversation: ConversationInfo
    let userID: String
    let onBack: () -> Void
    
    @State private var showC2CChatSetting: Bool = false
    @State private var hostViewController: UIViewController?
    
    var body: some View {
        ZStack {
            ChatPage(
                conversation: conversation,
                locateMessage: nil,
                onBack: onBack,
                onUserClick: { userID in
                    openUserProfile(userID: userID)
                },
                onMoreClick: {
                    showC2CChatSetting = true
                }
            )
            .background(ViewControllerBeacon { hostViewController = $0 })
            
            NavigationLink(
                destination: NestedChatProfilePushed(
                    userID: userID,
                    onExitChat: onBack
                ),
                isActive: $showC2CChatSetting
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private func openUserProfile(userID: String) {
        guard let navigationController = hostViewController?.navigationController else { return }
        let profile = NestedChatProfilePushed(userID: userID, onExitChat: onBack)
            .environmentObject(themeState)
        navigationController.pushViewController(UIHostingController(rootView: profile), animated: true)
    }
}


private struct MemberProfilePushed: View {
    @Environment(\.presentationMode) var presentationMode
    let userID: String
    let parentConversationID: String

    var body: some View {
        FriendAwareUserProfileView(userID: userID) { uid in
            NestedC2CSetting(
                userID: uid,
                parentConversationID: parentConversationID,
                onBack: { presentationMode.wrappedValue.dismiss() },
                onContactDelete: { presentationMode.wrappedValue.dismiss() }
            )
        }
        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
    }
}

// UIKit push 的页面不能可靠地用 presentationMode 关闭，需通过所属导航控制器返回。
struct ViewControllerBeacon: UIViewRepresentable {
    let onFound: (UIViewController) -> Void

    func makeUIView(context: Context) -> BeaconView {
        BeaconView(onFound: onFound)
    }

    func updateUIView(_ uiView: BeaconView, context: Context) {}

    final class BeaconView: UIView {
        let onFound: (UIViewController) -> Void

        init(onFound: @escaping (UIViewController) -> Void) {
            self.onFound = onFound
            super.init(frame: .zero)
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder = next
            while let r = responder {
                if let vc = r as? UIViewController {
                    onFound(vc)
                    return
                }
                responder = r.next
            }
        }
    }
}

private struct ChatProfilePushed: View {
    @Environment(\.presentationMode) var presentationMode
    let userID: String
    let parentConversationID: String
    let onContactDelete: () -> Void

    @State private var hostVC: UIViewController? = nil

    private func popSelf() {
        if let nav = hostVC?.navigationController {
            nav.popViewController(animated: true)
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    var body: some View {
        FriendAwareUserProfileView(userID: userID) { uid in
            NestedC2CSetting(
                userID: uid,
                parentConversationID: parentConversationID,
                onBack: { popSelf() },
                onContactDelete: {
                    popSelf()
                    onContactDelete()
                }
            )
        }
        .background(ViewControllerBeacon { hostVC = $0 })
        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
    }
}

private struct NestedChatProfilePushed: View {
    @Environment(\.presentationMode) var presentationMode
    let userID: String
    let onExitChat: () -> Void

    @State private var hostVC: UIViewController? = nil

    private func popSelf() {
        if let nav = hostVC?.navigationController {
            nav.popViewController(animated: true)
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    var body: some View {
        C2CChatSettingView(
            userID: userID,
            onSendMessageClick: {
                popSelf()
            },
            onContactDelete: {
                popSelf()
                onExitChat()
            },
            onBack: { popSelf() }
        )
        .background(ViewControllerBeacon { hostVC = $0 })
        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
    }
}

private struct NestedGroupSetting: View {
    @EnvironmentObject var themeState: ThemeState
    
    let groupID: String
    let parentConversationID: String
    let onBack: () -> Void
    let onGroupDelete: () -> Void
    
    @State private var showMemberSetting: Bool = false
    @State private var selectedMemberUserID: String? = nil
    
    var body: some View {
        ZStack {
            GroupChatSettingView(
                groupID: groupID,
                onSendMessageClick: {
                    onBack()
                },
                onGroupDelete: onGroupDelete,
                onGroupMemberClick: { userID in
                    selectedMemberUserID = userID
                    showMemberSetting = true
                },
                memberDetailDestination: { userID in
                    AnyView(MemberProfilePushed(userID: userID, parentConversationID: parentConversationID))
                },
                onBack: onBack
            )
            
            if let userID = selectedMemberUserID {
                NavigationLink(
                    destination: FriendAwareUserProfileView(userID: userID) { uid in
                        NestedC2CSetting(
                        userID: uid,
                        parentConversationID: parentConversationID,
                        onBack: {
                            dismissMemberSetting()
                        },
                        onContactDelete: {
                            dismissMemberSetting()
                        }
                    )
                    }
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                    isActive: $showMemberSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }
    
    private func dismissMemberSetting() {
        showMemberSetting = false
        selectedMemberUserID = nil
    }
}

struct ChatSecurityWarningBanner: View {
    @EnvironmentObject var themeState: ThemeState
    var onClose: () -> Void = {}

    private static let leadingInset = CGFloat(SpacingScheme.contentSpacing)
    private static let trailingInset = CGFloat(SpacingScheme.bubbleSpacing)
    private static let verticalInset = CGFloat(SpacingScheme.bubbleSpacing)
    private static let iconSize: CGFloat = 16
    private static let iconTextGap = CGFloat(SpacingScheme.iconIconSpacing)
    private static let textCloseGap = CGFloat(SpacingScheme.smallSpacing)
    private static let closeButtonSize: CGFloat = 22

    var body: some View {
        let firstLineHeight = UIKitFontScheme.caption2Regular.lineHeight
        HStack(alignment: .top, spacing: 0) {
            Image("demo_ic_security_warning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(themeState.colors.textColorWarning)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .padding(.top, max(0, (firstLineHeight - Self.iconSize) / 2))
            Text(warningAttributed)
                .font(FontScheme.caption2Regular)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Self.iconTextGap)
                .padding(.trailing, Self.textCloseGap)
            Button(action: onClose) {
                Image("demo_ic_security_close")
                    .renderingMode(.template)
                    .foregroundColor(themeState.colors.textColorWarning)
            }
            .frame(width: Self.closeButtonSize, height: Self.closeButtonSize)
        }
        .padding(.leading, Self.leadingInset)
        .padding(.trailing, Self.trailingInset)
        .padding(.vertical, Self.verticalInset)
        .background(themeState.colors.toastColorWarning)
    }

    private var warningAttributed: AttributedString {
        var a = AttributedString(LocalizedChatString("ChatSecurityWarning") + " ")
        a.foregroundColor = themeState.colors.textColorWarning
        var b = AttributedString(LocalizedChatString("ChatSecurityWarningReport"))
        b.foregroundColor = themeState.colors.textColorLink
        return a + b
    }
}
