import AtomicXCore
import SwiftUI

private func displayName(for member: GroupMember) -> String {
    if let nameCard = member.nameCard, !nameCard.isEmpty {
        return nameCard
    } else if let friendRemark = member.friendRemark, !friendRemark.isEmpty {
        return friendRemark
    } else if let nickname = member.nickname, !nickname.isEmpty {
        return nickname
    } else {
        return member.userID
    }
}

private func displayName(for contact: ContactInfo) -> String {
    if let friendRemark = contact.friendRemark, !friendRemark.isEmpty {
        return friendRemark
    } else if let nickname = contact.nickname, !nickname.isEmpty {
        return nickname
    } else {
        return contact.userID
    }
}

struct GroupChatSettingImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    @State private var showingGroupNameEdit = false
    @State private var showingGroupNicknameEdit = false
    @State private var showingNoticeEdit = false
    @State private var showingGroupManagement = false
    @State private var showingRemoveMember = false
    @State private var showingPermissionActionSheet = false
    @State private var permissionActionSheetType: PermissionActionSheetType = .joinOption
    @State private var showingAddMember = false
    @State private var showingGroupMembers = false
    @State private var showingMemberDetail = false
    @State private var selectedMemberForDetail: GroupMember?
    @State private var alertType: AlertType?
    @State private var showingTransferOwnership = false
    @State private var showingAvatarPicker = false
    @State private var groupName: String = ""
    @State private var groupID: String = ""
    @State private var avatar: String = ""
    @State private var notice: String = ""
    @State private var isNotDisturb: Bool = false
    @State private var isPinned: Bool = false
    @State private var groupType: GroupType = .work
    @State private var showBackgroundPicker: Bool = false
    @State private var chatBackgroundIsSet: Bool = false
    @State private var memberCount: Int = 0
    @State private var currentUserRole: GroupMemberRole = .member
    @State private var selfNameCard: String? = nil
    @State private var joinGroupApprovalType: GroupJoinOption = .forbid
    @State private var inviteToGroupApprovalType: GroupInviteOption = .forbid
    @State private var appliedGroupInfo: GroupInfo?
    @State private var isAllMuted: Bool = false
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    private let groupStore: GroupStore
    @State private var memberStore: GroupMemberStore
    @State private var conversationStore: ConversationListStore
    private let onSendMessageClick: (() -> Void)?
    private let onGroupDelete: (() -> Void)?
    private let onGroupMemberClick: ((String) -> Void)?
    // 成员资料页须由成员列表所在层级 push，否则返回时会丢失列表。
    private let memberDetailDestination: ((String) -> AnyView)?
    private let config: GroupChatSettingConfigProtocol

    private static let noticeMaxInputLength: Int = 300

    private static let memberGridColumns: Int = 6

    private static let memberGridMaxCount: Int = 12

    private var conversationID: String {
        ChatUtil.getGroupConversationID(groupID)
    }

    private enum PermissionActionSheetType {
        case joinOption
        case inviteOption
    }

    private let onBack: (() -> Void)?

    init(
        groupID: String,
        config: GroupChatSettingConfigProtocol? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onGroupDelete: (() -> Void)? = nil,
        onGroupMemberClick: ((String) -> Void)? = nil,
        memberDetailDestination: ((String) -> AnyView)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.groupID = groupID
        self.config = config ?? GroupChatSettingConfig()
        self.groupStore = GroupStore.shared
        self.memberStore = GroupMemberStore.create(groupID: groupID)
        self.onSendMessageClick = onSendMessageClick
        self.onGroupDelete = onGroupDelete
        self.onGroupMemberClick = onGroupMemberClick
        self.memberDetailDestination = memberDetailDestination
        self.onBack = onBack
        self.conversationStore = ConversationListStore.create()
    }

    var body: some View {
        Group {
            contentView
                .toast(toast)
                .navigationBarTitle(LocalizedChatString("GroupChatInfoTitle"), displayMode: .inline)
                .navBackButton {
                    if let onBack = onBack { onBack() } else { presentationMode.wrappedValue.dismiss() }
                }
        }
        .overlay(
            TextInputDialog(
                isPresented: $showingGroupNameEdit,
                title: LocalizedChatString("GroupProfileEditGroupName"),
                initialText: groupName,
                onConfirm: { newName in
                    guard !newName.isEmpty else { return }
                    updateGroupProfile(name: newName, notice: nil, avatar: nil, completion: nil)
                }
            )
            .environmentObject(themeState)
        )
        .overlay(
            TextInputDialog(
                isPresented: $showingGroupNicknameEdit,
                title: LocalizedChatString("GroupEditNameCard"),
                initialText: selfNameCard ?? "",
                onConfirm: { newNameCard in
                    memberStore.setSelfNameCard(nameCard: newNameCard, completion: nil)
                }
            )
            .environmentObject(themeState)
        )
        .overlay(
            TextInputDialog(
                isPresented: $showingNoticeEdit,
                title: LocalizedChatString("GroupNotice"),
                initialText: notice,
                maxLength: Self.noticeMaxInputLength,
                multiline: true,
                onConfirm: { newNotice in
                    if newNotice != notice {
                        updateGroupProfile(name: nil, notice: newNotice, avatar: nil, completion: nil)
                    }
                }
            )
            .environmentObject(themeState)
        )
        .background(
            NavigationLink(
                destination: GroupManagementView(groupID: groupID, groupStore: groupStore, memberStore: memberStore),
                isActive: $showingGroupManagement
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: AddGroupMemberView(memberStore: memberStore)
                    .environmentObject(themeState),
                isActive: $showingAddMember
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: RemoveGroupMemberView(memberStore: memberStore, currentUserRole: currentUserRole)
                    .environmentObject(themeState),
                isActive: $showingRemoveMember
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: GroupMemberListView(groupStore: groupStore, memberStore: memberStore, onGroupMemberClick: onGroupMemberClick, memberDetailDestination: memberDetailDestination),
                isActive: $showingGroupMembers
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            Group {
                if let member = selectedMemberForDetail {
                    NavigationLink(
                        destination: FriendAwareUserProfileView(userID: member.userID),
                        isActive: $showingMemberDetail
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
        .background(
            NavigationLink(
                destination: TransferOwnershipView(groupID: groupID, groupStore: groupStore, memberStore: memberStore),
                isActive: $showingTransferOwnership
            ) {
                EmptyView()
            }
            .hidden()
        )
        .confirmationDialog(
            "",
            isPresented: $showingPermissionActionSheet,
            titleVisibility: .hidden
        ) {
            permissionActionSheetButtons(for: permissionActionSheetType)
        }
        .alert(item: $alertType) { type in
            createAlert(for: type)
        }
        .overlay {
            if showingAvatarPicker {
                AvatarPickerSheet(
                    title: LocalizedChatString("ChooseAvatar"),
                    imageUrlList: createGroupAvatarUrlList(),
                    columnCount: 4,
                    onDismiss: { showingAvatarPicker = false },
                    onImageSelected: { selectedImageUrl in
                        showingAvatarPicker = false
                        updateGroupProfile(
                            name: nil,
                            notice: nil,
                            avatar: selectedImageUrl,
                            completion: { result in
                                switch result {
                                case .success:
                                    print("Successfully set group avatar: \(selectedImageUrl)")
                                case .failure(let error):
                                    print("Failed to set group avatar: \(error.code) - \(error.message)")
                                }
                            }
                        )
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingAvatarPicker)
        .onReceive(groupStore.state.subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))) { joinedGroupList in
            if let groupInfo = joinedGroupList.first(where: { $0.groupID == groupID }), groupInfo != appliedGroupInfo {
                appliedGroupInfo = groupInfo
                applyGroupInfo(groupInfo)
            }
        }
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { memberList in
            applyMemberList(memberList)
        }
        .onReceive(conversationStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))) { conversationList in
            if let conversationInfo = conversationList.first(where: { $0.conversationID == conversationID }) {
                applyConversationInfo(conversationInfo)
            }
        }
        .onAppear {
            currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            fetchInitialInfo()
            chatBackgroundIsSet = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID) != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: ChatBackgroundStore.didChangeNotification)) { notification in
            if let changedID = notification.userInfo?[ChatBackgroundStore.conversationIDUserInfoKey] as? String, changedID == conversationID {
                chatBackgroundIsSet = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID) != nil
            }
        }
        .fullScreenCover(isPresented: $showBackgroundPicker) {
            ChatBackgroundPickerView(
                conversationID: conversationID,
                onDismiss: { showBackgroundPicker = false }
            )
            .environmentObject(themeState)
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if config.isShowHeader {
                    headerSection
                    customRowsPlain(after: .header)
                }
                if config.isShowMemberPreview {
                    SettingSectionSpacer()
                    memberSection
                    customRowsPlain(after: .memberPreview)
                }
                if showsSettingsSection {
                    SettingSectionSpacer()
                    settingsSection
                    customRowsPlain(after: .settings)
                }
                if config.isShowAlias {
                    SettingSectionSpacer()
                    SettingRowView(
                        title: LocalizedChatString("GroupProfileAlias"),
                        value: getCurrentUserNameCardOnly(),
                        accessory: canPerformAction(.setGroupRemark) ? .edit : .none,
                        isEnabled: canPerformAction(.setGroupRemark)
                    ) {
                        showingGroupNicknameEdit = true
                    }
                    customRowsPlain(after: .alias)
                }
                if showsSwitchSection {
                    SettingSectionSpacer()
                    switchSection
                    customRowsPlain(after: .switches)
                }
                if config.isShowChatBackground {
                    SettingSectionSpacer()
                    SettingRowView(
                        title: LocalizedChatString("ChatBackgroundSetting"),
                        value: chatBackgroundIsSet ? LocalizedChatString("ChatBackgroundCustom") : LocalizedChatString("ChatBackgroundDefault"),
                        accessory: .arrow
                    ) {
                        showBackgroundPicker = true
                    }
                    customRowsPlain(after: .background)
                }
                if showsActionSection {
                    SettingSectionSpacer()
                    actionSection
                    customRowsPlain(after: .actions)
                }
                customRowsPlain(after: .end)
            }
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
    }

    private var headerDisplayName: String {
        groupName.isEmpty ? groupID : groupName
    }

    private var headerSection: some View {
        HStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            AvatarView(
                url: avatar,
                name: headerDisplayName,
                size: .l,
                shape: .roundedRectangle
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if canPerformAction(.setGroupAvatar) {
                    showingAvatarPicker = true
                }
            }
            VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                Text(headerDisplayName)
                    .font(FontScheme.body4Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture {
                        if canPerformAction(.setGroupName) {
                            showingGroupNameEdit = true
                        }
                    }
                Text("\(LocalizedChatString("GroupID")): \(groupID)")
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture {
                        UIPasteboard.general.string = groupID
                        toast.success(LocalizedChatString("Copied"))
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorOperate)
    }

    private var memberSection: some View {
        VStack(spacing: 0) {
            SettingRowView(
                title: LocalizedChatString("GroupMember"),
                value: "\(memberCount)",
                accessory: .arrow,
                isEnabled: canPerformAction(.getGroupMemberList)
            ) {
                showingGroupMembers = true
            }
            memberGrid
        }
        .background(themeState.colors.bgColorOperate)
    }

    private enum MemberGridItem {
        case member(GroupMember)
        case add
        case remove
    }

    private var showAddMemberButton: Bool {
        canPerformAction(.addGroupMember) && inviteToGroupApprovalType != .forbid
    }

    private var showRemoveMemberButton: Bool {
        canPerformAction(.removeGroupMember)
    }

    private var memberGrid: some View {
        let buttonCount = (showAddMemberButton ? 1 : 0) + (showRemoveMemberButton ? 1 : 0)
        let previewMembers = Array(allMembers.prefix(max(0, Self.memberGridMaxCount - buttonCount)))
        var items: [MemberGridItem] = previewMembers.map { .member($0) }
        if showAddMemberButton {
            items.append(.add)
        }
        if showRemoveMemberButton {
            items.append(.remove)
        }
        let row1 = Array(items.prefix(Self.memberGridColumns))
        let row2 = items.count > Self.memberGridColumns ? Array(items.dropFirst(Self.memberGridColumns).prefix(Self.memberGridColumns)) : []
        return VStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            memberGridRow(row1)
            if !row2.isEmpty {
                memberGridRow(row2)
            }
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
    }

    private func memberGridRow(_ items: [MemberGridItem]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<Self.memberGridColumns, id: \.self) { index in
                if index < items.count {
                    memberGridCell(items[index])
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func memberGridCell(_ item: MemberGridItem) -> some View {
        switch item {
        case .member(let member):
            return AnyView(
                VStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    AvatarView(
                        url: member.avatarURL,
                        name: gridDisplayName(for: member),
                        size: .m,
                        shape: .roundedRectangle
                    )
                    Text(gridDisplayName(for: member))
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 40)
                .contentShape(Rectangle())
                .onTapGesture {
                    openMemberDetail(member)
                }
            )
        case .add:
            return AnyView(memberSymbolCell(symbol: "+") {
                showingAddMember = true
            })
        case .remove:
            return AnyView(memberSymbolCell(symbol: "−") {
                showingRemoveMember = true
            })
        }
    }

    private func memberSymbolCell(symbol: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
            Text(symbol)
                .font(FontScheme.body2Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(width: 40, height: 40)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
            Text(" ")
                .font(FontScheme.caption3Regular)
        }
        .frame(width: 40)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private func gridDisplayName(for member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty {
            return nameCard
        }
        if let nickname = member.nickname, !nickname.isEmpty {
            return nickname
        }
        return member.userID
    }

    private func openMemberDetail(_ member: GroupMember) {
        guard canPerformAction(.getGroupMemberInfo), member.userID != currentUserID else { return }
        if let onGroupMemberClick = onGroupMemberClick {
            onGroupMemberClick(member.userID)
        } else {
            selectedMemberForDetail = member
            showingMemberDetail = true
        }
    }

    private var showsSettingsSection: Bool {
        config.isShowNotice || config.isShowManagement || config.isShowGroupType || config.isShowJoinMethod || config.isShowInviteMethod
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            if config.isShowNotice {
                let canEditNotice = canPerformAction(.setGroupNotice)
                SettingRowView(
                    title: LocalizedChatString("GroupNotice"),
                    value: getGroupNoticePreview(),
                    accessory: canEditNotice ? .edit : .none,
                    isEnabled: canEditNotice
                ) {
                    showingNoticeEdit = true
                }
            }
            if config.isShowManagement, canPerformAction(.setGroupManagement) {
                SettingRowDivider()
                SettingRowView(title: LocalizedChatString("GroupProfileManage"), accessory: .arrow) {
                    showingGroupManagement = true
                }
            }
            if config.isShowGroupType {
                SettingRowDivider()
                SettingRowView(
                    title: LocalizedChatString("GroupProfileType"),
                    value: groupTypeDisplayName,
                    accessory: .none,
                    isEnabled: false
                )
            }
            if config.isShowJoinMethod {
                let canEditJoin = canPerformAction(.setJoinGroupApprovalType)
                SettingRowDivider()
                SettingRowView(
                    title: LocalizedChatString("GroupProfileJoinType"),
                    value: getJoinGroupDisplayName(joinGroupApprovalType),
                    accessory: canEditJoin ? .arrow : .none,
                    isEnabled: canEditJoin
                ) {
                    permissionActionSheetType = .joinOption
                    showingPermissionActionSheet = true
                }
            }
            if config.isShowInviteMethod {
                let canEditInvite = canPerformAction(.setInviteToGroupApprovalType)
                SettingRowDivider()
                SettingRowView(
                    title: LocalizedChatString("GroupProfileInviteType"),
                    value: getAppovalOptionDisplayName(inviteToGroupApprovalType),
                    accessory: canEditInvite ? .arrow : .none,
                    isEnabled: canEditInvite
                ) {
                    permissionActionSheetType = .inviteOption
                    showingPermissionActionSheet = true
                }
            }
        }
    }

    private var showsSwitchSection: Bool {
        (config.isShowDoNotDisturb && canPerformAction(.setDoNotDisturb)) || (config.isShowPin && canPerformAction(.pinGroup))
    }

    private var switchSection: some View {
        VStack(spacing: 0) {
            let showDND = config.isShowDoNotDisturb && canPerformAction(.setDoNotDisturb)
            let showPin = config.isShowPin && canPerformAction(.pinGroup)
            if showDND {
                SettingRowToggle(
                    title: LocalizedChatString("ProfileMessageDoNotDisturb"),
                    isOn: $isNotDisturb,
                    onToggle: { value in
                        let opt: ReceiveMessageOption = value ? .notNotify : .receive
                        conversationStore.setReceiveMessageOpt(conversationID: conversationID, opt: opt, completion: nil)
                    }
                )
            }
            if showDND && showPin {
                SettingRowDivider()
            }
            if showPin {
                SettingRowToggle(
                    title: LocalizedChatString("ProfileStickyonTop"),
                    isOn: $isPinned,
                    onToggle: { value in
                        conversationStore.pinConversation(conversationID: conversationID, pin: value, completion: nil)
                    }
                )
            }
        }
    }

    private var showsActionSection: Bool {
        (config.isShowTransferOwner && canPerformAction(.transferOwner))
            || (config.isShowClearHistory && canPerformAction(.clearHistoryMessages))
            || (config.isShowDeleteAndQuit && canPerformAction(.deleteAndQuit))
            || (config.isShowDismiss && canPerformAction(.dismissGroup))
    }

    private var actionSection: some View {
        VStack(spacing: 0) {
            if config.isShowTransferOwner && canPerformAction(.transferOwner) {
                SettingActionRow(
                    title: LocalizedChatString("GroupTransferOwner"),
                    textColor: themeState.colors.textColorLink
                ) {
                    showingTransferOwnership = true
                }
            }
            if config.isShowClearHistory && canPerformAction(.clearHistoryMessages) {
                if config.isShowTransferOwner && canPerformAction(.transferOwner) {
                    SettingRowDivider()
                }
                SettingActionRow(
                    title: LocalizedChatString("ClearAllChatHistory"),
                    textColor: themeState.colors.textColorError
                ) {
                    alertType = .clearHistory
                }
            }
            if config.isShowDeleteAndQuit && canPerformAction(.deleteAndQuit) {
                if showsTransferRow || showsClearHistoryRow {
                    SettingRowDivider()
                }
                SettingActionRow(
                    title: LocalizedChatString("GroupProfileDeleteAndExit"),
                    textColor: themeState.colors.textColorError
                ) {
                    alertType = .deleteAndQuit
                }
            }
            if config.isShowDismiss && canPerformAction(.dismissGroup) {
                if showsTransferRow || showsClearHistoryRow || showsQuitRow {
                    SettingRowDivider()
                }
                SettingActionRow(
                    title: LocalizedChatString("GroupProfileDissolve"),
                    textColor: themeState.colors.textColorError
                ) {
                    alertType = .dismissGroup
                }
            }
        }
    }

    private var showsTransferRow: Bool {
        config.isShowTransferOwner && canPerformAction(.transferOwner)
    }

    private var showsClearHistoryRow: Bool {
        config.isShowClearHistory && canPerformAction(.clearHistoryMessages)
    }

    private var showsQuitRow: Bool {
        config.isShowDeleteAndQuit && canPerformAction(.deleteAndQuit)
    }

    private var customSettingRows: [(section: GroupChatSettingSection, row: AnyView)] {
        let editor = ChatSettingItemEditor<GroupChatSettingSection>()
        config.itemCustomizer?(editor)
        return editor.customRows
    }

    @ViewBuilder
    private func customRowsPlain(after section: GroupChatSettingSection) -> some View {
        let rows = customSettingRows.filter { $0.section == section }
        ForEach(rows.indices, id: \.self) { rows[$0].row }
    }

    private func fetchInitialInfo() {
        let group = DispatchGroup()
        var hasError = false
        group.enter()
        groupStore.getGroupInfo(
            groupID: groupID,
            completion: GroupInfoHandler(
                onSuccess: { groupInfo in
                    DispatchQueue.main.async {
                        applyGroupInfo(groupInfo)
                    }
                    group.leave()
                },
                onFailure: { _, _ in
                    hasError = true
                    group.leave()
                }
            )
        )
        group.enter()
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: GroupConversationInfoHandler(
                onSuccess: { conversationInfo in
                    DispatchQueue.main.async {
                        applyConversationInfo(conversationInfo)
                    }
                    group.leave()
                },
                onFailure: { _, _ in
                    hasError = true
                    group.leave()
                }
            )
        )
        group.enter()
        memberStore.loadMembers(roleList: [.all], completion: { result in
            group.leave()
        })
        group.enter()
        groupStore.loadJoinedGroups(completion: { result in
            group.leave()
        })
        group.notify(queue: .main) {
            if hasError {
                print("fetch GroupChatSetting initial info failed")
            }
        }
    }


    private func canPerformAction(_ permission: GroupPermission) -> Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: permission
        )
    }

    private func getCurrentUserNameCardOnly() -> String {
        return selfNameCard?.isEmpty == false ? selfNameCard! : LocalizedChatString("Unsetted")
    }

    private var groupTypeDisplayName: String {
        switch groupType {
        case .work:
            return LocalizedChatString("CreatGroupType_Work")
        case .publicGroup:
            return LocalizedChatString("PublicGroup")
        case .meeting:
            return LocalizedChatString("MeetingGroup")
        case .community:
            return LocalizedChatString("Community")
        case .avChatRoom:
            return LocalizedChatString("LiveGroup")
        }
    }

    private func getGroupNoticePreview() -> String {
        let notice = notice.trimmingCharacters(in: .whitespacesAndNewlines)
        if notice.isEmpty {
            return LocalizedChatString("GroupNoticeNull")
        } else {
            return notice
        }
    }

    private func getAppovalOptionDisplayName(_ option: GroupInviteOption) -> String {
        switch option {
        case .forbid:
            return LocalizedChatString("GroupProfileInviteDisable")
        case .auth:
            return LocalizedChatString("GroupProfileAdminApprove")
        case .any:
            return LocalizedChatString("GroupProfileAutoApproval")
        }
    }

    private func getJoinGroupDisplayName(_ option: GroupJoinOption) -> String {
        switch option {
        case .forbid:
            return LocalizedChatString("GroupProfileJoinDisable")
        case .auth:
            return LocalizedChatString("GroupProfileAdminApprove")
        case .any:
            return LocalizedChatString("GroupProfileAutoApproval")
        }
    }

    @ViewBuilder
    private func permissionActionSheetButtons(for type: PermissionActionSheetType) -> some View {
        let isJoin = type == .joinOption
        Button(LocalizedChatString(isJoin ? "GroupProfileJoinDisable" : "GroupProfileInviteDisable")) {
            self.setGroupPermission(.forbid, isJoinOption: isJoin)
        }
        Button(LocalizedChatString("GroupProfileAdminApprove")) {
            self.setGroupPermission(.auth, isJoinOption: isJoin)
        }
        Button(LocalizedChatString("GroupProfileAutoApproval")) {
            self.setGroupPermission(.any, isJoinOption: isJoin)
        }
        Button(LocalizedChatString("Cancel"), role: .cancel) {}
    }

    private func setGroupPermission(_ option: GroupJoinOption, isJoinOption: Bool) {
        let actionType = isJoinOption ? LocalizedChatString("GroupProfileJoinType") : LocalizedChatString("GroupProfileInviteType")
        let inviteOption = GroupInviteOption(rawValue: option.rawValue) ?? .forbid
        let optionName = isJoinOption ? getJoinGroupDisplayName(option) : getAppovalOptionDisplayName(inviteOption)
        let completion: CompletionClosure = { result in
            switch result {
            case .success:
                print("Successfully set \(actionType): \(optionName)")
            case .failure(let error):
                print("Failed to set \(actionType): \(error.code) - \(error.message)")
            }
        }
        if isJoinOption {
            groupStore.setJoinOption(groupID: groupID, option: option, completion: completion)
        } else {
            groupStore.setInviteOption(groupID: groupID, option: inviteOption, completion: completion)
        }
    }

    private func createAlert(for type: AlertType) -> Alert {
        switch type {
        case .clearHistory:
            return Alert(
                title: Text(LocalizedChatString("ClearGroupHistoryTips")),
                primaryButton: .destructive(Text(LocalizedChatString("Clear"))) {
                    clearHistory()
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        case .deleteAndQuit:
            return Alert(
                title: Text(LocalizedChatString("QuitGroupConfirmTips")),
                primaryButton: .destructive(Text(LocalizedChatString("DeleteAndQuit"))) {
                    deleteAndQuit()
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        case .dismissGroup:
            return Alert(
                title: Text(LocalizedChatString("DismissGroupConfirmTitle")),
                message: Text(LocalizedChatString("DismissGroupConfirmMessage")),
                primaryButton: .destructive(Text(LocalizedChatString("DismissGroup"))) {
                    dismissGroup()
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        case .deleteFriend:
            return Alert(
                title: Text(""),
                message: Text(""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func clearHistory() {
        conversationStore.clearConversationMessages(conversationID: conversationID, completion: { result in
            switch result {
            case .success:
                print("Clear history message succeeded")
            case .failure:
                print("Clear history message failed")
            }
        })
    }

    private func deleteAndQuit() {
        groupStore.quitGroup(groupID: groupID, completion: { result in
            switch result {
            case .success:
                print("Quit group succeeded")
                conversationStore.deleteConversation(conversationID: conversationID, completion: nil)
            case .failure:
                print("Quit group failed")
            }
            DispatchQueue.main.async {
                self.onGroupDelete?()
                self.presentationMode.wrappedValue.dismiss()
            }
        })
    }

    private func dismissGroup() {
        groupStore.dismissGroup(groupID: groupID, completion: { result in
            switch result {
            case .success:
                print("Dismiss group succeeded")
                conversationStore.deleteConversation(conversationID: conversationID, completion: nil)

            case .failure:
                print("Dismiss group failed")
            }
            DispatchQueue.main.async {
                self.onGroupDelete?()
                self.presentationMode.wrappedValue.dismiss()
            }
        })
    }


    private func createGroupAvatarUrlList() -> [String] {
        return (1 ... 24).map { index in
            "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\(index).png"
        }
    }

    private func updateGroupProfile(name: String?, notice: String?, avatar: String?, completion: CompletionClosure?) {
        var groupInfo = GroupInfo(groupID: groupID)
        groupInfo.groupName = name
        groupInfo.notification = notice
        groupInfo.avatarURL = avatar
        groupStore.updateProfile(groupInfo: groupInfo, completion: completion)
    }

    private func applyGroupInfo(_ groupInfo: GroupInfo) {
        groupName = groupInfo.groupName ?? ""
        avatar = groupInfo.avatarURL ?? ""
        notice = groupInfo.notification ?? ""
        groupType = groupInfo.groupType ?? .work
        memberCount = groupInfo.memberCount ?? 0
        currentUserRole = groupInfo.selfRole ?? currentUserRole
        joinGroupApprovalType = groupInfo.joinOption ?? .forbid
        inviteToGroupApprovalType = groupInfo.inviteOption ?? .forbid
        isAllMuted = groupInfo.isAllMuted ?? false
    }

    private func applyMemberList(_ memberList: [GroupMember]) {
        guard memberList != allMembers else { return }
        allMembers = memberList
        memberCount = memberList.isEmpty ? memberCount : memberList.count
        if let selfMember = memberList.first(where: { $0.userID == currentUserID }) {
            selfNameCard = selfMember.nameCard
            currentUserRole = selfMember.role
        }
    }

    private func applyConversationInfo(_ conversationInfo: ConversationInfo) {
        let newIsNotDisturb = conversationInfo.receiveOption != .receive
        guard newIsNotDisturb != isNotDisturb || conversationInfo.isPinned != isPinned else { return }
        isNotDisturb = newIsNotDisturb
        isPinned = conversationInfo.isPinned
    }
}


struct TextEditSheetImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var newText: String = ""
    let title: String
    let currentText: String
    let placeholder: String
    let helpText: String?
    let onSave: (String) -> Void

    init(title: String, currentText: String, placeholder: String, helpText: String?, onSave: @escaping (String) -> Void) {
        self.title = title
        self.currentText = currentText
        self.placeholder = placeholder
        self.helpText = helpText
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(title)
                    .font(FontScheme.caption1Medium)
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(FontScheme.caption1Medium)
                        .foregroundColor(themeState.colors.textColorTertiary)
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.bubbleSpacing))
            Rectangle()
                .fill(themeState.colors.textColorTertiary.opacity(0.2))
                .frame(height: 0.5)
            VStack(spacing: CGFloat(SpacingScheme.contentSpacing)) {
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    TextField(placeholder, text: $newText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if let helpText = helpText {
                        Text(helpText)
                            .font(FontScheme.caption3Regular)
                            .foregroundColor(themeState.colors.textColorTertiary)
                    }
                }
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                Button(action: {
                    let finalText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(finalText)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(LocalizedChatString("Confirm"))
                        .font(FontScheme.caption1Medium)
                        .foregroundColor(themeState.colors.textColorButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.smallRadius))
                                .fill(themeState.colors.buttonColorPrimaryDefault)
                        )
                }
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.bottom, CGFloat(SpacingScheme.contentSpacing))
            }
        }
        .onAppear {
            newText = currentText
        }
    }
}


private struct GroupManagementView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMutePicker = false
    @State private var showingSetAdminPicker = false
    @State private var showingRemoveAdminPicker = false
    @State private var mutedMembers: [GroupMember] = []
    @State private var adminMembers: [GroupMember] = []
    @State private var isAllMuted: Bool = false
    @State private var groupType: GroupType = .work
    @State private var currentUserRole: GroupMemberRole = .member
    @State private var appliedGroupInfo: GroupInfo?
    @State private var adminActionTarget: GroupMember? = nil
    @State private var unmuteTarget: GroupMember? = nil
    let groupID: String
    let groupStore: GroupStore
    let memberStore: GroupMemberStore

    private static let sectionSpacerHeight = CGFloat(SpacingScheme.smallSpacing)
    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let adminItemWidth: CGFloat = 40
    private static let adminItemSpacing = CGFloat(SpacingScheme.contentSpacing)
    private static let adminRowVerticalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let adminActionBottomSpacerHeight = CGFloat(SpacingScheme.contentSpacing)

    private var canManageAdmins: Bool {
        GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupMemberRole
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if canManageAdmins {
                sectionSpacer
                adminSection
            }
            sectionSpacer
            SettingRowToggle(
                title: LocalizedChatString("AllMembersMuted"),
                isOn: $isAllMuted,
                onToggle: { value in
                    groupStore.muteAllMembers(groupID: groupID, isMuted: value, completion: nil)
                }
            )
            muteDescription
            if !isAllMuted {
                addMutedRow
                mutedList
            }
            Spacer(minLength: 0)
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .navigationBarTitle(LocalizedChatString("GroupProfileManage"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: NavBackButtonView {
                presentationMode.wrappedValue.dismiss()
            }
        )
        .onReceive(groupStore.state.subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))) { joinedGroupList in
            if let info = joinedGroupList.first(where: { $0.groupID == groupID }), info != appliedGroupInfo {
                appliedGroupInfo = info
                self.isAllMuted = info.isAllMuted ?? false
                self.groupType = info.groupType ?? .work
                self.currentUserRole = info.selfRole ?? .member
            }
        }
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { memberList in
            let muted = memberList.filter { $0.isMuted }
            let admins = memberList.filter { $0.role == .admin }
            guard muted != mutedMembers || admins != adminMembers else { return }
            self.mutedMembers = muted
            self.adminMembers = admins
        }
        .onAppear {
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
        .background(
            NavigationLink(
                destination: MuteMemberSelectionView(memberStore: memberStore),
                isActive: $showingMutePicker
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: GroupAdminPickerView(memberStore: memberStore, mode: .setAdmin),
                isActive: $showingSetAdminPicker
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: GroupAdminPickerView(memberStore: memberStore, mode: .removeAdmin),
                isActive: $showingRemoveAdminPicker
            ) {
                EmptyView()
            }
            .hidden()
        )
        .confirmationDialog(
            "",
            isPresented: Binding(
                get: { adminActionTarget != nil },
                set: { if !$0 { adminActionTarget = nil } }
            ),
            titleVisibility: .hidden
        ) {
            if let member = adminActionTarget {
                Button(LocalizedChatString("GroupManageRemoveAdmin")) {
                    memberStore.setMemberRole(userID: member.userID, role: .member, completion: nil)
                }
                Button(LocalizedChatString("Cancel"), role: .cancel) {}
            }
        }
        .confirmationDialog(
            "",
            isPresented: Binding(
                get: { unmuteTarget != nil },
                set: { if !$0 { unmuteTarget = nil } }
            ),
            titleVisibility: .hidden
        ) {
            if let member = unmuteTarget {
                Button(LocalizedChatString("GroupManageCancelMute")) {
                    memberStore.muteMember(userID: member.userID, time: 0, completion: nil)
                }
                Button(LocalizedChatString("Cancel"), role: .cancel) {}
            }
        }
    }

    private var sectionSpacer: some View {
        Color.clear.frame(height: Self.sectionSpacerHeight)
    }


    private var adminSection: some View {
        VStack(spacing: 0) {
            Text(LocalizedChatString("GroupManageAdmins"))
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.top, Self.horizontalPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Self.adminItemSpacing) {
                    ForEach(adminMembers, id: \.userID) { member in
                        adminItem(member)
                    }
                    adminActionTile(isAdd: true)
                    if !adminMembers.isEmpty {
                        adminActionTile(isAdd: false)
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.vertical, Self.adminRowVerticalPadding)
            }
        }
        .background(themeState.colors.bgColorOperate)
    }

    private func adminItem(_ member: GroupMember) -> some View {
        VStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
            AvatarView(url: member.avatarURL, name: displayName(for: member), shape: .roundedRectangle)
            Text(displayName(for: member))
                .font(themeState.fonts.caption3Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: Self.adminItemWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            adminActionTarget = member
        }
    }

    private func adminActionTile(isAdd: Bool) -> some View {
        VStack(spacing: 0) {
            Text(isAdd ? "+" : "−")
                .font(FontScheme.body2Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(width: Self.adminItemWidth, height: Self.adminItemWidth)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
            Color.clear.frame(height: Self.adminActionBottomSpacerHeight)
        }
        .frame(width: Self.adminItemWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            if isAdd {
                showingSetAdminPicker = true
            } else {
                showingRemoveAdminPicker = true
            }
        }
    }


    private var muteDescription: some View {
        Text(LocalizedChatString("AllMembersMutedDescription"))
            .font(themeState.fonts.caption2Regular)
            .foregroundColor(themeState.colors.textColorTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.top, CGFloat(SpacingScheme.iconTextSpacing))
            .padding(.bottom, Self.horizontalPadding)
            .background(themeState.colors.bgColorOperate)
    }

    private var addMutedRow: some View {
        Button(action: {
            showingMutePicker = true
        }) {
            HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                Text("+")
                    .font(themeState.fonts.body3Regular)
                    .foregroundColor(themeState.colors.textColorLink)
                Text(LocalizedChatString("GroupManageSelectMuted"))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorLink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.horizontalPadding)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var mutedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(mutedMembers, id: \.userID) { member in
                    MutedMemberRow(member: member)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            unmuteTarget = member
                        }
                }
            }
        }
        .background(themeState.colors.bgColorOperate)
    }
}


private struct MuteMemberSelectionView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    let memberStore: GroupMemberStore

    private static let muteDurationSeconds: Int64 = 7 * 24 * 60 * 60

    private var userList: [UserPickerItem] {
        allMembers.compactMap { member in
            if member.role == .owner || member.isMuted { return nil }
            let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
            return UserPickerItem(
                userID: member.userID,
                avatarURL: member.avatarURL,
                title: displayName(for: member),
                subtitle: subtitle
            )
        }
    }

    var body: some View {
        UserPickerView(
            userList: userList,
            showsChosenUsersHeader: false,
            maxCount: 0,
            navigationTitle: LocalizedChatString("GroupManageSelectMuted"),
            confirmTitle: LocalizedChatString("Confirm"),
            onSelectedChanged: { selectedUsers in
                for user in selectedUsers {
                    memberStore.muteMember(userID: user.userID, time: Self.muteDurationSeconds, completion: nil)
                }
            }
        )
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
        }
        .onAppear {
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
    }
}

private struct GroupAdminPickerView: View {
    enum Mode {
        case setAdmin
        case removeAdmin
    }

    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    let memberStore: GroupMemberStore
    let mode: Mode

    private var userList: [UserPickerItem] {
        allMembers.compactMap { member in
            switch mode {
            case .setAdmin:
                guard member.role == .member else { return nil }
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: displayName(for: member)
                )
            case .removeAdmin:
                guard member.role == .admin else { return nil }
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: displayName(for: member),
                    subtitle: LocalizedChatString("MembersRoleAdmin")
                )
            }
        }
    }

    var body: some View {
        UserPickerView(
            userList: userList,
            showsChosenUsersHeader: false,
            maxCount: 0,
            navigationTitle: LocalizedChatString(mode == .setAdmin ? "GroupManageSelectAdmin" : "GroupManageRemoveAdmin"),
            confirmTitle: LocalizedChatString("Confirm"),
            onSelectedChanged: { selectedUsers in
                let role: GroupMemberRole = mode == .setAdmin ? .admin : .member
                for user in selectedUsers {
                    memberStore.setMemberRole(userID: user.userID, role: role, completion: nil)
                }
            }
        )
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
        }
        .onAppear {
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
    }
}


private struct MutedMemberRow: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember

    var body: some View {
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            AvatarView(
                url: member.avatarURL,
                name: displayName(for: member),
                shape: .roundedRectangle
            )
            Text(displayName(for: member))
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorOperate)
    }
}


private struct AddGroupMemberView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    @State private var friendList: [ContactInfo] = []
    let memberStore: GroupMemberStore
    private let contactStore: ContactStore

    init(memberStore: GroupMemberStore) {
        self.memberStore = memberStore
        self.contactStore = ContactStore.shared
    }

    private var userList: [UserPickerItem] {
        let memberIDs = Set(allMembers.map { $0.userID })
        return friendList.compactMap { contact in
            guard !memberIDs.contains(contact.userID) else { return nil }
            return UserPickerItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: displayName(for: contact)
            )
        }
    }

    var body: some View {
        UserPickerView(
            userList: userList,
            showsChosenUsersHeader: false,
            maxCount: 0,
            navigationTitle: LocalizedChatString("GroupAddMembers"),
            confirmTitle: LocalizedChatString("Confirm"),
            onSelectedChanged: { selectedUsers in
                addSelectedMembers(selectedUsers)
            }
        )
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))) { newFriendList in
            guard newFriendList != friendList else { return }
            self.friendList = newFriendList
        }
        .onAppear {
            self.friendList = contactStore.state.value.friendList
            contactStore.loadFriends(completion: nil)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
    }

    private func addSelectedMembers(_ selectedUsers: [UserPickerItem]) {
        let userIDs = selectedUsers.map { $0.userID }
        memberStore.addMember(
            userIDList: userIDs,
            completion: nil
        )
    }
}

private struct RemoveGroupMemberView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    let memberStore: GroupMemberStore
    let currentUserRole: GroupMemberRole

    private var userList: [UserPickerItem] {
        allMembers.compactMap { member in
            guard Self.canRemove(memberRole: member.role, currentUserRole: currentUserRole) else { return nil }
            let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
            return UserPickerItem(
                userID: member.userID,
                avatarURL: member.avatarURL,
                title: displayName(for: member),
                subtitle: subtitle
            )
        }
    }

    var body: some View {
        UserPickerView(
            userList: userList,
            showsChosenUsersHeader: false,
            maxCount: 0,
            navigationTitle: LocalizedChatString("GroupRemoveMembers"),
            confirmTitle: LocalizedChatString("Confirm"),
            onSelectedChanged: { selectedUsers in
                removeSelectedMembers(selectedUsers)
            }
        )
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
        }
        .onAppear {
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
    }

    private static func canRemove(memberRole: GroupMemberRole, currentUserRole: GroupMemberRole) -> Bool {
        switch currentUserRole {
        case .owner:
            return memberRole != .owner
        case .admin:
            return memberRole == .member
        default:
            return false
        }
    }

    private func removeSelectedMembers(_ selectedUsers: [UserPickerItem]) {
        let userIDs = selectedUsers.map { $0.userID }
        memberStore.deleteMember(userIDList: userIDs, completion: nil)
    }
}


private struct GroupMemberListView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMemberActionSheet = false
    @State private var selectedMember: GroupMember?
    @State private var showingMemberDetail = false
    @State private var selectedMemberForDetail: GroupMember?
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserRole: GroupMemberRole = .member
    @State private var currentUserID: String = ""
    @State private var appliedGroupInfo: GroupInfo?
    let groupStore: GroupStore
    let memberStore: GroupMemberStore
    let onGroupMemberClick: ((String) -> Void)?
    let memberDetailDestination: ((String) -> AnyView)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(allMembers, id: \.userID) { member in
                        GroupMemberListRow(
                            member: member,
                            action: {
                                handleMemberTap(member)
                            }
                        )
                    }
                }
            }
            .background(themeState.colors.bgColorOperate)
            Spacer()
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .navigationBarTitle(String(format: LocalizedChatString("GroupMemberCountFormat"), allMembers.count), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: NavBackButtonView {
                presentationMode.wrappedValue.dismiss()
            }
        )
        .modifier(MemberActionSheetModifier(
            isPresented: $showingMemberActionSheet,
            selectedMember: selectedMember,
            canRemoveMember: canRemoveMember,
            canSetAdmin: canSetAdmin,
            canRemoveAdmin: canRemoveAdmin,
            onMemberDetail: handleMemberDetail,
            onSetMemberRole: handleSetMemberRole,
            onRemoveMember: handleRemoveMember
        ))
        .background(
            Group {
                if let member = selectedMemberForDetail {
                    NavigationLink(
                        destination: Group {
                            if let builder = memberDetailDestination {
                                builder(member.userID)
                            } else {
                                AnyView(FriendAwareUserProfileView(userID: member.userID))
                            }
                        },
                        isActive: $showingMemberDetail
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
        .onAppear {
            currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            memberStore.loadMembers(roleList: [.all], completion: { _ in
            })
        }
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
            if let selfMember = allMembers.first(where: { $0.userID == currentUserID }) {
                self.currentUserRole = selfMember.role
            }
        }
        .onReceive(groupStore.state.subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))) { joinedGroupList in
            if let info = joinedGroupList.first(where: { $0.groupID == memberStore.groupID }), info != appliedGroupInfo {
                appliedGroupInfo = info
                self.currentUserRole = info.selfRole ?? self.currentUserRole
            }
        }
    }


    private func handleMemberTap(_ member: GroupMember) {
        if member.userID == currentUserID {
            return
        }
        if hasActionPermission(for: member) {
            selectedMember = member
            showingMemberActionSheet = true
        } else {
            handleMemberDetail(member)
        }
    }


    private func hasActionPermission(for member: GroupMember) -> Bool {
        switch currentUserRole {
        case .owner:
            return member.role != .owner
        case .admin:
            return member.role == .member
        default:
            return false
        }
    }

    private func canSetAdmin(for member: GroupMember) -> Bool {
        return currentUserRole == .owner && member.role == .member
    }

    private func canRemoveAdmin(for member: GroupMember) -> Bool {
        return currentUserRole == .owner && member.role == .admin
    }

    private func canRemoveMember(_ member: GroupMember) -> Bool {
        switch currentUserRole {
        case .owner:
            return member.role != .owner
        case .admin:
            return member.role == .member
        default:
            return false
        }
    }

    private func handleMemberDetail(_ member: GroupMember) {
        if memberDetailDestination != nil {
            selectedMemberForDetail = member
            showingMemberDetail = true
        } else if let onGroupMemberClick = onGroupMemberClick {
            onGroupMemberClick(member.userID)
        } else {
            selectedMemberForDetail = member
            showingMemberDetail = true
        }
    }

    private func handleSetMemberRole(_ member: GroupMember, role: GroupMemberRole) {
        memberStore.setMemberRole(
            userID: member.userID,
            role: role,
            completion: nil
        )
    }

    private func handleRemoveMember(_ member: GroupMember) {
        let alert = UIAlertController(
            title: LocalizedChatString("RemoveMemberConfirmTips"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("RemoveMember"), style: .destructive) { _ in
            memberStore.deleteMember(userIDList: [member.userID], completion: nil)
        })
        Self.topmostViewController()?.present(alert, animated: true)
    }

    private static func topmostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows where window.isKeyWindow {
                var top = window.rootViewController
                while let presented = top?.presentedViewController {
                    top = presented
                }
                if let top = top { return top }
            }
        }
        return nil
    }
}


private struct MemberActionSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let selectedMember: GroupMember?
    let canRemoveMember: (GroupMember) -> Bool
    let canSetAdmin: (GroupMember) -> Bool
    let canRemoveAdmin: (GroupMember) -> Bool
    let onMemberDetail: (GroupMember) -> Void
    let onSetMemberRole: (GroupMember, GroupMemberRole) -> Void
    let onRemoveMember: (GroupMember) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "",
                isPresented: $isPresented,
                titleVisibility: .hidden
            ) {
                if let member = selectedMember {
                    Button(LocalizedChatString("GroupMemberDetail")) {
                        onMemberDetail(member)
                    }
                    if canRemoveMember(member) {
                        Button(LocalizedChatString("RemoveMember")) {
                            onRemoveMember(member)
                        }
                    }
                    if canSetAdmin(member) {
                        Button(LocalizedChatString("SetAsAdmin")) {
                            onSetMemberRole(member, .admin)
                        }
                    }
                    if canRemoveAdmin(member) {
                        Button(LocalizedChatString("CancelAdmin")) {
                            onSetMemberRole(member, .member)
                        }
                    }
                    Button(LocalizedChatString("Cancel"), role: .cancel) {}
                }
            }
    }
}


private struct GroupMemberListRow: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                AvatarView(
                    url: member.avatarURL,
                    name: displayName(for: member)
                )
                Text(displayName(for: member))
                    .font(themeState.fonts.body4Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                if member.role == .owner || member.role == .admin {
                    Text(member.role == .owner ? LocalizedChatString("GroupOwnerLabel") : LocalizedChatString("AdminLabel"))
                        .font(themeState.fonts.caption4Regular)
                        .foregroundColor(themeState.colors.textColorLink)
                        .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
                        .padding(.vertical, 2)
                        .background(themeState.colors.buttonColorPrimaryDisabled)
                        .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransferOwnershipView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    @State private var pendingTransfer: UserPickerItem? = nil
    @State private var showConfirmAlert = false
    let groupID: String
    let groupStore: GroupStore
    let memberStore: GroupMemberStore

    private var userList: [UserPickerItem] {
        return allMembers.compactMap { member in
            if member.userID == currentUserID {
                return nil
            }
            let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
            return UserPickerItem(
                userID: member.userID,
                avatarURL: member.avatarURL,
                title: displayName(for: member),
                subtitle: subtitle
            )
        }
    }

    var body: some View {
        UserPickerView(
            userList: userList,
            showsChosenUsersHeader: false,
            confirmTitle: LocalizedChatString("Confirm"),
            dismissOnConfirm: false,
            onSelectedChanged: { selectedUsers in
                pendingTransfer = selectedUsers.first
                showConfirmAlert = true
            }
        )
        .navigationBarTitle(LocalizedChatString("GroupTransferOwner"), displayMode: .inline)
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .alert(isPresented: $showConfirmAlert) {
            Alert(
                title: Text(LocalizedChatString("GroupTransferOwnerConfirmTips")),
                primaryButton: .destructive(Text(LocalizedChatString("Confirm"))) {
                    if let target = pendingTransfer {
                        transferOwnership(to: target)
                    }
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        }
        .onReceive(memberStore.state.subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))) { allMembers in
            guard allMembers != self.allMembers else { return }
            self.allMembers = allMembers
        }
        .onAppear {
            currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
    }

    private func transferOwnership(to selectedUser: UserPickerItem) {
        groupStore.changeOwner(
            groupID: groupID,
            newOwnerID: selectedUser.userID,
            completion: { result in
                switch result {
                case .success:
                    print(">>>>> transferOwnership succeeded to user: \(selectedUser.userID)")
                case .failure(let error):
                    print(">>>>> transferOwnership failed: \(error.code) - \(error.message)")
                }
            }
        )
    }
}

private final class GroupInfoHandler: GetGroupInfoCompletionHandler {
    private let onSuccessHandler: (GroupInfo) -> Void
    private let onFailureHandler: (Int, String) -> Void

    init(onSuccess: @escaping (GroupInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }

    func onSuccess(groupInfo: GroupInfo) {
        onSuccessHandler(groupInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}

private final class GroupConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessHandler: (ConversationInfo) -> Void
    private let onFailureHandler: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessHandler(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}
