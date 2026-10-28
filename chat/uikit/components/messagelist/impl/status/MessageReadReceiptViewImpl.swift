import AtomicXCore
import SwiftUI

struct MessageReadReceiptViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode

    private static let contentHorizontalInset = CGFloat(SpacingScheme.contentSpacing)
    private static let dividerHeight: CGFloat = 0.5
    private static let contentTopInset = CGFloat(SpacingScheme.bubbleSpacing)
    private static let tabSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let tabVerticalPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let tabHorizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let tabCornerRadius = CGFloat(RadiusScheme.superLargeRadius)
    private static let listTopSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let rowAvatarSize: CGFloat = 36
    private static let rowAvatarScale = rowAvatarSize / AvatarSize.m.rawValue
    private static let rowAvatarCornerRadius = CGFloat(RadiusScheme.tipsRadius)
    private static let rowNameSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let rowHorizontalInset = CGFloat(SpacingScheme.iconTextSpacing)
    private static let rowVerticalInset = CGFloat(SpacingScheme.smallSpacing)
    private static let receiptMemberPageCount = 20
    private static let loadMoreThresholdRows = 5

    private let messageActionStore: MessageActionStore
    private let message: MessageInfo
    private let embedInNavigationView: Bool
    private let onUserClick: ((String) -> Void)?

    @State private var selectedReadTab: Bool
    @State private var readMemberList: [GroupMember] = []
    @State private var hasMoreReadMembers: Bool = false
    @State private var unReadMemberList: [GroupMember] = []
    @State private var hasMoreUnReadMembers: Bool = false
    @State private var isLoadingMoreMembers: Bool = false
    @State private var hostVC: UIViewController? = nil

    init(
        messageActionStore: MessageActionStore,
        message: MessageInfo,
        embedInNavigationView: Bool = false,
        onUserClick: ((String) -> Void)? = nil
    ) {
        self.messageActionStore = messageActionStore
        self.message = message
        self.embedInNavigationView = embedInNavigationView
        self.onUserClick = onUserClick
        _selectedReadTab = State(initialValue: (message.readReceiptInfo?.readCount ?? 0) > 0)
    }

    private var displayedMembers: [GroupMember] {
        selectedReadTab ? readMemberList : unReadMemberList
    }

    var body: some View {
        if embedInNavigationView {
            NavigationView { pageContent }
        } else {
            pageContent
        }
    }

    private var pageContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeState.colors.strokeColorSecondary)
                .frame(height: Self.dividerHeight)
            tabRow
            memberList
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .background(HostViewControllerBeacon { hostVC = $0 })
        .navigationBarTitle(LocalizedChatString("MessageReadDetail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(false)
        .navigationBarItems(leading: Button(action: {
            popSelf()
        }) {
            Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.template)
                .foregroundColor(themeState.colors.textColorPrimary)
                .frame(width: 28, height: 44, alignment: .leading)
        })
        .onAppear {
            loadInitialData()
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.readMemberList))) { members in
            readMemberList = Self.distinctMembers(members)
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.hasMoreReadMembers))) { hasMore in
            hasMoreReadMembers = hasMore
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.unreadMemberList))) { members in
            unReadMemberList = Self.distinctMembers(members)
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.hasMoreUnreadMembers))) { hasMore in
            hasMoreUnReadMembers = hasMore
        }
    }

    private func openProfile(userID: String) {
        onUserClick?(userID)
    }

    private func popSelf() {
        if let nav = hostVC?.navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var tabRow: some View {
        HStack(spacing: Self.tabSpacing) {
            tabButton(
                title: "\(LocalizedChatString("MessageReadC2CRead")) (\(readMemberList.count))",
                isSelected: selectedReadTab
            ) {
                selectedReadTab = true
            }
            tabButton(
                title: "\(LocalizedChatString("MessageReadC2CUnRead")) (\(unReadMemberList.count))",
                isSelected: !selectedReadTab
            ) {
                selectedReadTab = false
            }
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.top, Self.contentTopInset)
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(isSelected ? themeState.colors.textColorPrimary : themeState.colors.textColorSecondary)
                .padding(.vertical, Self.tabVerticalPadding)
                .padding(.horizontal, Self.tabHorizontalPadding)
                .frame(maxWidth: .infinity)
                .background(isSelected ? themeState.colors.bgColorAvatar : themeState.colors.bgColorDefault)
                .cornerRadius(Self.tabCornerRadius)
        }
    }

    private var memberList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let members = displayedMembers
                ForEach(Array(members.enumerated()), id: \.element.userID) { index, member in
                    userRow(member: member)
                        .onAppear {
                            maybeLoadMore(currentIndex: index, totalCount: members.count)
                        }
                }
            }
            .padding(.top, Self.listTopSpacing)
        }
    }

    private func userRow(member: GroupMember) -> some View {
        let name = Self.displayName(for: member)
        return HStack(spacing: Self.rowNameSpacing) {
            AvatarView(
                url: member.avatarURL,
                name: name,
                size: .m,
                shape: .roundedRectangle,
                cornerRadius: Self.rowAvatarCornerRadius
            )
            .scaleEffect(Self.rowAvatarScale)
            .frame(width: Self.rowAvatarSize, height: Self.rowAvatarSize)

            Text(name)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)

            Spacer()
        }
        .padding(.horizontal, Self.contentHorizontalInset + Self.rowHorizontalInset)
        .padding(.vertical, Self.rowVerticalInset)
        .contentShape(Rectangle())
        .onTapGesture {
            openProfile(userID: member.userID)
        }
    }

    private func loadInitialData() {
        messageActionStore.loadReadMembers(count: Self.receiptMemberPageCount) { _ in }
        messageActionStore.loadUnreadMembers(count: Self.receiptMemberPageCount) { _ in }
    }

    private func maybeLoadMore(currentIndex: Int, totalCount: Int) {
        guard totalCount > 0, currentIndex >= totalCount - Self.loadMoreThresholdRows else { return }
        let hasMore = selectedReadTab ? hasMoreReadMembers : hasMoreUnReadMembers
        guard hasMore, !isLoadingMoreMembers else { return }
        isLoadingMoreMembers = true
        messageActionStore.loadMoreMembers(isRead: selectedReadTab) { _ in
            DispatchQueue.main.async {
                isLoadingMoreMembers = false
            }
        }
    }

    private static func displayName(for member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = member.nickname, !nickname.isEmpty { return nickname }
        return member.userID
    }

    private static func distinctMembers(_ members: [GroupMember]) -> [GroupMember] {
        var seen = Set<String>()
        return members.filter { member in
            guard !member.userID.isEmpty, !seen.contains(member.userID) else { return false }
            seen.insert(member.userID)
            return true
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
