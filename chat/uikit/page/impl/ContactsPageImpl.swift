import AtomicXCore
import SwiftUI

struct ContactsPageImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showAddContactMenu = false
    @State private var showAddFriend = false
    @State private var showJoinGroup = false
    @State private var addMenuAnchor: CGRect = .zero
    let config: ContactListConfig
    let onContactClick: ((ContactInfo) -> Void)?
    let onGroupClick: ((GroupInfo) -> Void)?

    init(
        config: ContactListConfig? = nil,
        onContactClick: ((ContactInfo) -> Void)? = nil,
        onGroupClick: ((GroupInfo) -> Void)? = nil
    ) {
        self.config = config ?? ContactListConfig()
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            ContactListView(
                config: config,
                onContactClick: onContactClick,
                onGroupClick: onGroupClick
            )
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea(edges: .top))
        .overlay(
            AnchoredPopMenuOverlay(
                isPresented: $showAddContactMenu,
                anchor: addMenuAnchor,
                items: [
                    PopMenuInfo(icon: "contact_add_friend", title: LocalizedChatString("ContactsAddFriends")) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showAddFriend = true }
                    },
                    PopMenuInfo(icon: "contact_add_group", title: LocalizedChatString("ContactsJoinGroup")) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showJoinGroup = true }
                    }
                ]
            )
        )
        .onDisappear { showAddContactMenu = false }
        .background(
            NavigationLink(destination: AddFriendView(), isActive: $showAddFriend) { EmptyView() }.hidden()
        )
        .background(
            NavigationLink(
                destination: JoinGroupView(
                    onEnterGroupChat: { groupInfo in
                        onGroupClick?(groupInfo)
                    }
                ),
                isActive: $showJoinGroup
            ) { EmptyView() }.hidden()
        )
    }


    private var headerView: some View {
        Text(LocalizedChatString("ContactsPageTitle"))
            .font(themeState.fonts.body4Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
            .overlay(
                Button(action: {
                    showAddContactMenu = true
                }) {
                    Image("contact_add_circle", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(width: 24, height: 24)
                }
                .popMenuAnchor($addMenuAnchor)
                .padding(.trailing, CGFloat(SpacingScheme.bubbleSpacing)),
                alignment: .trailing
            )
    }
}
