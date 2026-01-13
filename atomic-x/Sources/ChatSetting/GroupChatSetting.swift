import AtomicXCore
import SwiftUI

// MARK: - GroupMember Extension

extension GroupMember {
    var displayName: String {
        if let nameCard = nameCard, !nameCard.isEmpty {
            return nameCard
        } else if let nickname = nickname, !nickname.isEmpty {
            return nickname
        } else {
            return userID
        }
    }
}

public struct GroupChatSetting: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    @State private var showingGroupNameEdit = false
    @State private var showingGroupNicknameEdit = false
    @State private var showingGroupNotice = false
    @State private var showingGroupManagement = false
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
    @State private var memberCount: UInt = 0
    @State private var currentUserRole: GroupMemberRole = .member
    @State private var selfNameCard: String? = nil
    @State private var joinGroupApprovalType: GroupJoinOption = .forbid
    @State private var inviteToGroupApprovalType: GroupJoinOption = .forbid
    @State private var isAllMuted: Bool = false
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    @State private var settingStore: GroupSettingStore
    @State private var conversationStore: ConversationListStore
    private let onSendMessageClick: (() -> Void)?
    private let onGroupDelete: (() -> Void)?
    private let onGroupMemberClick: ((String) -> Void)?

    private enum PermissionActionSheetType {
        case joinOption
        case inviteOption
    }

    public init(
        groupID: String,
        onSendMessageClick: (() -> Void)? = nil,
        onGroupDelete: (() -> Void)? = nil,
        onGroupMemberClick: ((String) -> Void)? = nil
    ) {
        self.groupID = groupID
        self.settingStore = GroupSettingStore.create(groupID: groupID)
        self.onSendMessageClick = onSendMessageClick
        self.onGroupDelete = onGroupDelete
        self.onGroupMemberClick = onGroupMemberClick
        self.conversationStore = ConversationListStore.create()
    }

    public var body: some View {
        Group {
            contentView
                .toast(toast)
                .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
        }
        .sheet(isPresented: $showingGroupNameEdit) {
            GroupNameEditSheet(
                currentName: groupName,
                onSave: { newName in
                    settingStore.updateGroupProfile(
                        name: newName,
                        notice: nil,
                        avatar: nil,
                        completion: { result in
                            switch result {
                            case .success:
                                print("Successfully modified group name: \(newName)")
                            case .failure(let error):
                                print("Failed to modify group name: \(error.code) - \(error.message)")
                            }
                        }
                    )
                }
            )
            .modifier(SheetModifier())
        }
        .sheet(isPresented: $showingGroupNicknameEdit) {
            GroupNameCardEditSheet(
                currentNameCard: selfNameCard ?? "",
                onSave: { newNameCard in
                    settingStore.setSelfGroupNameCard(
                        nameCard: newNameCard.isEmpty ? nil : newNameCard,
                        completion: { result in
                            switch result {
                            case .success:
                                print("Successfully modified my group nickname: \(newNameCard)")
                            case .failure(let error):
                                print("Failed to modify my group nickname: \(error.code) - \(error.message)")
                            }
                        }
                    )
                }
            )
            .modifier(SheetModifier())
        }
        .background(
            NavigationLink(
                destination: GroupNoticeDetailView(settingStore: settingStore),
                isActive: $showingGroupNotice
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: GroupManagementView(settingStore: settingStore),
                isActive: $showingGroupManagement
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: AddGroupMemberView(settingStore: settingStore)
                    .environmentObject(themeState),
                isActive: $showingAddMember
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            NavigationLink(
                destination: GroupMemberListView(settingStore: settingStore, onGroupMemberClick: onGroupMemberClick),
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
                destination: TransferOwnershipView(settingStore: settingStore),
                isActive: $showingTransferOwnership
            ) {
                EmptyView()
            }
            .hidden()
        )
        .actionSheet(isPresented: $showingPermissionActionSheet) {
            createPermissionActionSheet(for: permissionActionSheetType)
        }
        .alert(item: $alertType) { type in
            createAlert(for: type)
        }
        .background(
            NavigationLink(
                destination: AvatarSelector(
                    imageUrlList: createGroupAvatarUrlList(),
                    column: 4,
                    onComplete: { selectedImageUrl in
                        settingStore.updateGroupProfile(
                            name: nil,
                            notice: nil,
                            avatar: selectedImageUrl,
                            completion: { result in
                                switch result {
                                case .success:
                                    print("Successfully set group avatar: \(selectedImageUrl ?? "")")
                                case .failure(let error):
                                    print("Failed to set group avatar: \(error.code) - \(error.message)")
                                }
                            }
                        )
                    }
                ),
                isActive: $showingAvatarPicker
            ) {
                EmptyView()
            }
            .hidden()
        )
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupName))) { groupName in
            self.groupName = groupName
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.avatarURL))) { avatar in
            self.avatar = avatar
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.notice))) { notice in
            self.notice = notice
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.isNotDisturb))) { isNotDisturb in
            self.isNotDisturb = isNotDisturb
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.isPinned))) { isPinned in
            self.isPinned = isPinned
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupType))) { groupType in
            self.groupType = groupType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.memberCount))) { memberCount in
            self.memberCount = memberCount
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.currentUserRole))) { currentUserRole in
            self.currentUserRole = currentUserRole
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.selfNameCard))) { selfNameCard in
            self.selfNameCard = selfNameCard
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.joinGroupApprovalType))) { joinGroupApprovalType in
            self.joinGroupApprovalType = joinGroupApprovalType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.inviteToGroupApprovalType))) { inviteToGroupApprovalType in
            self.inviteToGroupApprovalType = inviteToGroupApprovalType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.isAllMuted))) { isAllMuted in
            self.isAllMuted = isAllMuted
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
        .onAppear {
            fetchInitialInfo()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with group avatar, name and ID
                VStack(spacing: 16) {
                    // Group avatar (centered) - clickable if has setGroupAvatar permission
                    Button(action: {
                        if canPerformAction(.setGroupAvatar) {
                            showingAvatarPicker = true
                        }
                    }) {
                        Avatar(
                            url: avatar,
                            name: groupName.isEmpty ? groupID : groupName,
                            size: .xxl
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    // Group name with edit icon if has setGroupName permission
                    if canPerformAction(.setGroupName) {
                        Button(action: {
                            showingGroupNameEdit = true
                        }) {
                            HStack(spacing: 8) {
                                Text(groupName.isEmpty ? groupID : groupName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeState.colors.textColorPrimary)
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeState.colors.textColorLink)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text(groupName.isEmpty ? groupID : groupName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    // Group ID
                    Text("ID：\(groupID)")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                // Action buttons (Message, Audio, Video)
                HStack(spacing: 20) {
                    if canPerformAction(.sendMessage) {
                        CustomActionButton(
                            icon: "setting_sendmsg",
                            title: LocalizedChatString("ProfileSendMessages"),
                            action: {
                                onSendMessageClick?()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                // Dynamic settings based on permissions
                permissionBasedSettings
            }
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
    }

    private func fetchInitialInfo() {
        let group = DispatchGroup()
        var hasError = false
        group.enter()
        settingStore.fetchGroupInfo(completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        conversationStore.fetchConversationInfo(ChatUtil.getGroupConversationID(groupID), completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        settingStore.fetchGroupMemberList(role: .all, completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        settingStore.fetchSelfMemberInfo(completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.notify(queue: .main) {
            if hasError {
//                toast.error(LocalizedChatString("GetGroupSettingInfoFailed"))
                print("fetch C2CChatSetting initial info failed")
            } else {
                print("fetch C2CChatSetting initial info succeeded")
            }
        }
    }

    // MARK: - Permission-Based Settings

    @ViewBuilder
    private var permissionBasedSettings: some View {
        VStack(spacing: 20) {
            // Group 2: Basic Settings - Message Do Not Disturb, Pin Chat
            VStack(spacing: 1) {
                if canPerformAction(.setDoNotDisturb) {
                    SettingRowToggle(
                        title: LocalizedChatString("ProfileMessageDoNotDisturb"),
                        isOn: $isNotDisturb,
                        onToggle: { value in
                            conversationStore.muteConversation(ChatUtil.getGroupConversationID(groupID), mute: isNotDisturb, completion: { result in
                                switch result {
                                case .success:
                                    print("Successfully set group message do not disturb: \(value)")
                                case .failure(let error):
                                    print("Failed to set group message do not disturb: \(error.code) - \(error.message)")
                                }
                            })
                        }
                    )
                }
                if canPerformAction(.pinGroup) {
                    SettingRowToggle(
                        title: LocalizedChatString("ProfileStickyonTop"),
                        isOn: $isPinned,
                        onToggle: { value in
                            conversationStore.pinConversation(ChatUtil.getGroupConversationID(groupID), pin: isPinned, completion: { result in
                                switch result {
                                case .success:
                                    print("Successfully set pin group chat: \(value)")
                                case .failure(let error):
                                    print("Failed to set pin group chat: \(error.code) - \(error.message)")
                                }
                            })
                        }
                    )
                }
            }
            .background(themeState.colors.bgColorTopBar)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            // Group 3: Group Notice, Group Management, Group Type, Join Group Method, Invite to Group Method
            VStack(spacing: 1) {
                // Group Notice - always clickable, goes to new page
                SettingRowNavigate(
                    title: LocalizedChatString("GroupNotice"),
                    subtitle: getGroupNoticePreview(),
                    action: {
                        showingGroupNotice = true
                    }
                )
                // Group Management - always clickable, goes to new page
                SettingRowNavigate(
                    title: LocalizedChatString("GroupProfileManage"),
                    action: {
                        showingGroupManagement = true
                    }
                )
                // Group Type - show only if has getGroupType permission
                if canPerformAction(.getGroupType) {
                    SettingRowInfo(
                        title: LocalizedChatString("GroupProfileType"),
                        value: groupTypeDisplayName
                    )
                }
                // Join Group Method - clickable only if has setJoinGroupApprovalType permission
                if canPerformAction(.setJoinGroupApprovalType) {
                    SettingRowWithValue(
                        title: LocalizedChatString("GroupProfileJoinType"),
                        value: getJoinGroupDisplayName(joinGroupApprovalType),
                        action: {
                            permissionActionSheetType = .joinOption
                            showingPermissionActionSheet = true
                        }
                    )
                } else {
                    SettingRowInfo(
                        title: LocalizedChatString("GroupProfileJoinType"),
                        value: getJoinGroupDisplayName(joinGroupApprovalType)
                    )
                }
                // Invite to Group Method - clickable only if has setInviteToGroupApprovalType permission
                if canPerformAction(.setInviteToGroupApprovalType) {
                    SettingRowWithValue(
                        title: LocalizedChatString("GroupProfileInviteType"),
                        value: getAppovalOptionDisplayName(inviteToGroupApprovalType),
                        action: {
                            permissionActionSheetType = .inviteOption
                            showingPermissionActionSheet = true
                        }
                    )
                } else {
                    SettingRowInfo(
                        title: LocalizedChatString("GroupProfileInviteType"),
                        value: getAppovalOptionDisplayName(inviteToGroupApprovalType)
                    )
                }
            }
            .background(themeState.colors.bgColorTopBar)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            // Group 4: My Group Nickname
            if canPerformAction(.setGroupRemark) {
                VStack(spacing: 1) {
                    SettingRowNavigateWithPreview(
                        title: LocalizedChatString("GroupProfileAlias"),
                        preview: getCurrentUserNameCardOnly(),
                        action: {
                            showingGroupNicknameEdit = true
                        }
                    )
                }
                .background(themeState.colors.bgColorTopBar)
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            // Group 5: Set Current Chat Background
            /**
             if canPerformAction(.setBackground) {
                 VStack(spacing: 1) {
                     SettingRowNavigate(
                         title: LocalizedChatString("ProfileSetBackgroundImage"),
                         action: {
                             // TODO: Handle set chat background
                             print("Set chat background")
                         }
                     )
                 }
                 .background(themeState.colors.bgColorOperate)
                 .cornerRadius(12)
                 .padding(.horizontal, 16)
             }
              */
            // Group 6: Group Members + Member List Preview + Add Members
            VStack(spacing: 1) {
                // Group Members - always show, but only trigger action if has getGroupMemberList permission
                SettingRowWithCount(
                    title: LocalizedChatString("GroupMember"),
                    count: allMembers.count,
                    action: {
                        if canPerformAction(.getGroupMemberList) {
                            showingGroupMembers = true
                        }
                    }
                )
                // Add Members - show only if has addGroupMember permission and invite is not forbidden
                if canPerformAction(.addGroupMember) && inviteToGroupApprovalType != .forbid {
                    SettingRowAddMember(
                        title: LocalizedChatString("GroupProfileManageAdd"),
                        action: {
                            showingAddMember = true
                        }
                    )
                }
                // Show member preview (show up to 3 members)
                ForEach(Array(allMembers.prefix(3)), id: \.id) { member in
                    GroupMemberPreviewRow(
                        member: member,
                        isCurrentUser: member.userID == currentUserID,
                        canViewDetails: canPerformAction(.getGroupMemberInfo),
                        onTap: {
                            if canPerformAction(.getGroupMemberInfo), member.userID != currentUserID {
                                if let onGroupMemberClick = onGroupMemberClick {
                                    onGroupMemberClick(member.userID)
                                } else {
                                    selectedMemberForDetail = member
                                    showingMemberDetail = true
                                }
                            }
                        }
                    )
                }
            }
            .background(themeState.colors.bgColorTopBar)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            // Group 7: Red Text Button Area - cell style
            VStack(spacing: 1) {
                if canPerformAction(.clearHistoryMessages) {
                    SettingRowButton(
                        title: LocalizedChatString("ClearAllChatHistory"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            alertType = .clearHistory
                        }
                    )
                }
                if canPerformAction(.deleteAndQuit) {
                    SettingRowButton(
                        title: LocalizedChatString("GroupProfileDeleteAndExit"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            alertType = .deleteAndQuit
                        }
                    )
                }
                if canPerformAction(.transferOwner) {
                    SettingRowButton(
                        title: LocalizedChatString("GroupTransferOwner"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            showingTransferOwnership = true
                        }
                    )
                }
                if canPerformAction(.dismissGroup) {
                    SettingRowButton(
                        title: LocalizedChatString("GroupProfileDissolve"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            alertType = .dismissGroup
                        }
                    )
                }
                /**
                 if canPerformAction(.reportGroup) {
                     SettingRowButton(
                         title: LocalizedChatString("GroupProfileReport"),
                         textColor: themeState.colors.textColorError,
                         action: {
                             // TODO: Handle report group - show report options
                             print("Report group")
                         }
                     )
                 }
                  */
            }
            .background(themeState.colors.bgColorTopBar)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Permission Helpers

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

    private func getAppovalOptionDisplayName(_ option: GroupJoinOption) -> String {
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

    private func createPermissionActionSheet(for type: PermissionActionSheetType) -> ActionSheet {
        switch type {
        case .joinOption:
            return ActionSheet(
                title: Text(LocalizedChatString("GroupProfileJoinType")),
                buttons: createPermissionButtons(
                    forbidText: LocalizedChatString("GroupProfileJoinDisable"),
                    onForbid: {
                        self.setGroupPermission(.forbid, isJoinOption: true)
                    },
                    onAuth: {
                        self.setGroupPermission(.auth, isJoinOption: true)
                    },
                    onAny: {
                        self.setGroupPermission(.any, isJoinOption: true)
                    }
                )
            )
        case .inviteOption:
            return ActionSheet(
                title: Text(LocalizedChatString("GroupProfileInviteType")),
                buttons: createPermissionButtons(
                    forbidText: LocalizedChatString("GroupProfileInviteDisable"),
                    onForbid: {
                        self.setGroupPermission(.forbid, isJoinOption: false)
                    },
                    onAuth: {
                        self.setGroupPermission(.auth, isJoinOption: false)
                    },
                    onAny: {
                        self.setGroupPermission(.any, isJoinOption: false)
                    }
                )
            )
        }
    }

    private func createPermissionButtons(
        forbidText: String,
        onForbid: @escaping () -> Void,
        onAuth: @escaping () -> Void,
        onAny: @escaping () -> Void
    ) -> [ActionSheet.Button] {
        return [
            .default(Text(forbidText), action: onForbid),
            .default(Text(LocalizedChatString("GroupProfileAdminApprove")), action: onAuth),
            .default(Text(LocalizedChatString("GroupProfileAutoApproval")), action: onAny),
            .cancel(Text(LocalizedChatString("Cancel")))
        ]
    }

    private func setGroupPermission(_ option: GroupJoinOption, isJoinOption: Bool) {
        let actionType = isJoinOption ? LocalizedChatString("GroupProfileJoinType") : LocalizedChatString("GroupProfileInviteType")
        let optionName = getAppovalOptionDisplayName(option)
        let completion: CompletionClosure = { result in
            switch result {
            case .success:
                print("Successfully set \(actionType): \(optionName)")
            case .failure(let error):
                print("Failed to set \(actionType): \(error.code) - \(error.message)")
            }
        }
        if isJoinOption {
            settingStore.setGroupJoinOption(option: option, completion: completion)
        } else {
            settingStore.setGroupInviteOption(option: option, completion: completion)
        }
    }

    private func createAlert(for type: AlertType) -> Alert {
        switch type {
        case .clearHistory:
            return Alert(
                title: Text(LocalizedChatString("ClearAllChatHistory")),
                message: Text(LocalizedChatString("ClearAllChatHistoryTips")),
                primaryButton: .destructive(Text(LocalizedChatString("Clear"))) {
                    clearHistory()
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        case .deleteAndQuit:
            return Alert(
                title: Text(LocalizedChatString("DeleteAndQuitConfirmTitle")),
                message: Text(LocalizedChatString("DeleteAndQuitConfirmMessage")),
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
        conversationStore.clearConversationMessages(ChatUtil.getGroupConversationID(groupID), completion: { result in
            switch result {
            case .success:
                print("Clear history message succeeded")
            case .failure:
                print("Clear history message failed")
            }
        })
    }

    private func deleteAndQuit() {
        settingStore.quitGroup(completion: { result in
            switch result {
            case .success:
                print("Quit group succeeded")
                conversationStore.deleteConversation(ChatUtil.getGroupConversationID(groupID), completion: nil)
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
        settingStore.dismissGroup(completion: { result in
            switch result {
            case .success:
                print("Dismiss group succeeded")
                conversationStore.deleteConversation(ChatUtil.getGroupConversationID(groupID), completion: nil)

            case .failure:
                print("Dismiss group failed")
            }
            DispatchQueue.main.async {
                self.onGroupDelete?()
                self.presentationMode.wrappedValue.dismiss()
            }
        })
    }

    // MARK: - Helper Methods

    private func createGroupAvatarUrlList() -> [String] {
        return (1 ... 24).map { index in
            "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\(index).png"
        }
    }
}

// MARK: - Group Member Preview Row

private struct GroupMemberPreviewRow: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember
    let isCurrentUser: Bool
    let canViewDetails: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if canViewDetails, !isCurrentUser {
                onTap()
            }
        }) {
            HStack {
                Avatar(
                    url: member.avatarURL,
                    name: member.nickname ?? member.userID
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(member.displayName)
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        if isCurrentUser {
                            Text(LocalizedChatString("YouLabel"))
                                .font(.caption)
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                        if member.role == .owner {
                            Text(LocalizedChatString("GroupOwnerLabel"))
                                .font(.caption)
                                .foregroundColor(Colors.GrayLight1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Colors.OrangeLight6)
                                .cornerRadius(4)
                        } else if member.role == .admin {
                            Text(LocalizedChatString("AdminLabel"))
                                .font(.caption)
                                .foregroundColor(Colors.GrayLight1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Colors.ThemeLight6)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                if canViewDetails && !isCurrentUser {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canViewDetails || isCurrentUser)
    }
}

// MARK: - Group Edit View (Simplified)

private struct GroupEditView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var editedName: String = ""
    @State private var editedIntroduction: String = ""
    @State private var groupName: String = ""
    @State private var notice: String = ""
    @State private var groupType: GroupType = .work
    @State private var currentUserRole: GroupMemberRole = .member
    let settingStore: GroupSettingStore

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if canEditName {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedChatString("GroupChatName"))
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorSecondary)
                        TextField(LocalizedChatString("GroupChatName"), text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                }
                if canEditNotice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedChatString("GroupNotice"))
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorSecondary)
                        if #available(iOS 14.0, *) {
                            TextEditor(text: $editedIntroduction)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeState.colors.textColorSecondary.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            TextField(LocalizedChatString("GroupNotice"), text: $editedIntroduction)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer()
            }
            .padding(.top, 20)
            .navigationBarTitle(LocalizedChatString("EditGroupInfo"), displayMode: .inline)
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink),
                trailing: Button(LocalizedChatString("Save")) {
                    saveChanges()
                }
                .foregroundColor(themeState.colors.textColorLink)
                .disabled(!hasAnyEditPermission)
            )
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupName))) { groupName in
            self.groupName = groupName
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.notice))) { notice in
            self.notice = notice
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupType))) { groupType in
            self.groupType = groupType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.currentUserRole))) { currentUserRole in
            self.currentUserRole = currentUserRole
        }
        .onAppear {
            editedName = groupName
            editedIntroduction = notice
        }
    }

    private var canEditName: Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupName
        )
    }

    private var canEditAvatar: Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupAvatar
        )
    }

    private var canEditNotice: Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupNotice
        )
    }

    private var hasAnyEditPermission: Bool {
        return canEditName || canEditNotice || canEditAvatar
    }

    private func saveChanges() {
        let nameToSave = canEditName ? (editedName.isEmpty ? "" : editedName) : ""
        let introToSave = canEditNotice ? (editedIntroduction.isEmpty ? "" : editedIntroduction) : ""
        settingStore.updateGroupProfile(
            name: nameToSave,
            notice: introToSave,
            avatar: nil,
            completion: { result in
                switch result {
                case .success:
                    presentationMode.wrappedValue.dismiss()
                case .failure:
                    break
                }
            }
        )
    }
}

// MARK: - Group Name Edit Sheet

private struct GroupNameEditSheet: View {
    let currentName: String
    let onSave: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var newName: String = ""
    var body: some View {
        TextEditSheet(
            title: LocalizedChatString("GroupProfileEditGroupName"),
            currentText: currentName,
            placeholder: LocalizedChatString("PleaseEnterGroupName"),
            helpText: nil,
            onSave: onSave
        )
    }
}

// MARK: - Group Name Card Edit Sheet

private struct GroupNameCardEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newNameCard: String = ""
    let currentNameCard: String
    let onSave: (String) -> Void

    var body: some View {
        TextEditSheet(
            title: LocalizedChatString("GroupProfileEditAlias"),
            currentText: currentNameCard,
            placeholder: LocalizedChatString("PleaseEnterGroupNickname"),
            helpText: LocalizedChatString("ProfileEditNameDesc"),
            onSave: onSave
        )
    }
}

// MARK: - Generic Text Edit Sheet

public struct TextEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var newText: String = ""
    let title: String
    let currentText: String
    let placeholder: String
    let helpText: String?
    let onSave: (String) -> Void

    public init(title: String, currentText: String, placeholder: String, helpText: String?, onSave: @escaping (String) -> Void) {
        self.title = title
        self.currentText = currentText
        self.placeholder = placeholder
        self.helpText = helpText
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Spacer()
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeState.colors.textColorTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            // Divider
            Rectangle()
                .fill(themeState.colors.textColorTertiary.opacity(0.2))
                .frame(height: 0.5)
            // Content
            VStack(spacing: 20) {
                // Text field with optional help text
                VStack(alignment: .leading, spacing: 8) {
                    TextField(placeholder, text: $newText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if let helpText = helpText {
                        Text(helpText)
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                // Confirm button
                Button(action: {
                    let finalText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(finalText)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(LocalizedChatString("Confirm"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(themeState.colors.textColorButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeState.colors.buttonColorPrimaryDefault)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            newText = currentText
        }
    }
}

// MARK: - Sheet Modifier for iOS Version Compatibility

private struct SheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(false)
        } else {
            content
        }
    }
}

// MARK: - Group Management View

private struct GroupManagementView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMemberSelection = false
    @State private var mutedMembers: [GroupMember] = []
    @State private var isAllMuted: Bool = false
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    let settingStore: GroupSettingStore

    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 0) {
                SettingRowToggle(
                    title: LocalizedChatString("AllMembersMuted"),
                    isOn: $isAllMuted,
                    onToggle: { value in
                        handleMuteAllToggle(value)
                    }
                )
                .padding(.horizontal, 16)

                HStack {
                    Text(LocalizedChatString("AllMembersMutedDescription"))
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
                VStack(spacing: 1) {
                    Button(action: {
                        handleAddMutedMembers()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.body)
                                .foregroundColor(themeState.colors.textColorLink)
                            Text(LocalizedChatString("AddMutedMembers"))
                                .font(.body)
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeState.colors.bgColorTopBar)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(themeState.colors.bgColorTopBar)
                .padding(.horizontal, 16)
                if !mutedMembers.isEmpty {
                    List {
                        ForEach(mutedMembers, id: \.userID) { member in
                            MutedMemberRow(member: member, onUnmute: {})
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(themeState.colors.bgColorTopBar)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive, action: {
                                        unmuteMember(member)
                                    }) {
                                        Text(LocalizedChatString("Delete"))
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 16)
                }
                if mutedMembers.isEmpty {
                    Spacer()
                }
            }
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .navigationBarTitle(LocalizedChatString("GroupProfileManage"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeState.colors.textColorLink)
            }
        )
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.isAllMuted))) { isAllMuted in
            self.isAllMuted = isAllMuted
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
        .onAppear {
            loadMutedMembers()
        }
        .background(
            NavigationLink(
                destination: MuteMemberSelectionView(
                    settingStore: settingStore,
                    onMutingCompleted: {
                        loadMutedMembers()
                    }
                ),
                isActive: $showingMemberSelection
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    private func loadMutedMembers() {
        settingStore.fetchGroupMemberList(role: .all) { result in
            switch result {
            case .success:
                let currentTimestamp = UInt(Date().timeIntervalSince1970)
                var filteredMembers: [GroupMember] = []
                for member in self.allMembers {
                    if member.muteUntil != 0, member.muteUntil > currentTimestamp {
                        filteredMembers.append(member)
                    }
                }
                self.mutedMembers = filteredMembers
            case .failure:
                break
            }
        }
    }

    private func handleMuteAllToggle(_ enabled: Bool) {
        settingStore.setMuteAllMembers(value: enabled, completion: nil)
    }

    private func unmuteMember(_ member: GroupMember) {
        settingStore.setGroupMemberMuteTime(
            userID: member.userID,
            time: 0,
            completion: { result in
                switch result {
                case .success:
                    self.loadMutedMembers()
                case .failure:
                    break
                }
            }
        )
    }

    private func handleAddMutedMembers() {
        showingMemberSelection = true
    }
}

// MARK: - Mute Member Selection View

private struct MuteMemberSelectionView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    let settingStore: GroupSettingStore
    let onMutingCompleted: () -> Void

    private var availableMembers: [GroupMember] {
        return allMembers.filter { member in
            member.role != .owner && member.userID != currentUserID
        }
    }

    private var currentlyMutedMemberIDs: Set<String> {
        let currentTimestamp = UInt(Date().timeIntervalSince1970)
        return Set(allMembers.compactMap { member in
            if member.muteUntil != 0, member.muteUntil > currentTimestamp {
                return member.userID
            }
            return nil
        })
    }

    private var userList: [UserPickerItem] {
        return availableMembers.map { member in
            let subtitle = member.role == .admin ? "管理员" : nil
            return UserPickerItem(
                userID: member.userID,
                avatarURL: member.avatarURL,
                title: member.displayName,
                subtitle: subtitle
            )
        }
    }

    var body: some View {
        UserPicker(
            userList: userList,
            defaultSelectedItems: currentlyMutedMemberIDs,
            onSelectedChanged: { selectedUsers in
                muteMembers(selectedUsers)
            }
        )
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
    }

    private func muteMembers(_ selectedUsers: [UserPickerItem]) {
        var completedCount = 0
        var hasError = false
        for user in selectedUsers {
            settingStore.setGroupMemberMuteTime(
                userID: user.userID,
                time: 7*24*60*60, // 7 days by default
                completion: { result in
                    switch result {
                    case .success:
                        completedCount += 1
                        if completedCount == selectedUsers.count, !hasError {
                            DispatchQueue.main.async {
                                self.onMutingCompleted()
                            }
                        }
                    case .failure:
                        hasError = true
                        completedCount += 1
                        if completedCount == selectedUsers.count {
                            DispatchQueue.main.async {
                                self.onMutingCompleted()
                            }
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Muted Member Row

private struct MutedMemberRow: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember
    let onUnmute: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Avatar(
                url: member.avatarURL,
                name: member.displayName
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.body)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    if member.role == .owner {
                        Text(LocalizedChatString("GroupOwnerLabel"))
                            .font(.caption)
                            .foregroundColor(Colors.GrayLight1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Colors.OrangeLight6)
                            .cornerRadius(4)
                    } else if member.role == .admin {
                        Text(LocalizedChatString("AdminLabel"))
                            .font(.caption)
                            .foregroundColor(Colors.GrayLight1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Colors.ThemeLight6)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }
}

// MARK: - Group Notice Detail View

private struct GroupNoticeDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var isEditing = false
    @State private var editedNotice = ""
    @State private var notice: String = ""
    @State private var groupType: GroupType = .work
    @State private var currentUserRole: GroupMemberRole = .member
    @FocusState private var isTextEditorFocused: Bool
    let settingStore: GroupSettingStore

    private var canEdit: Bool {
        GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupNotice
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 20) {
                if #available(iOS 16.0, *) {
                    TextEditor(text: isEditing ? $editedNotice : .constant(notice))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .disabled(!isEditing)
                        .scrollContentBackground(.hidden)
                        .background(themeState.colors.bgColorInput)
                        .focused($isTextEditorFocused)
                } else if #available(iOS 14.0, *) {
                    TextEditor(text: isEditing ? $editedNotice : .constant(notice))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .disabled(!isEditing)
                        .background(themeState.colors.bgColorInput)
                        .onAppear { UITextView.appearance().backgroundColor = .clear }
                }
                Spacer()
            }
        }
        .background(
            themeState.colors.bgColorInput
                .ignoresSafeArea(edges: .bottom)
        )
        .background(
            NavigationBarConfigurator { nav in
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(themeState.colors.bgColorOperate)
                nav.navigationBar.standardAppearance = appearance
                nav.navigationBar.scrollEdgeAppearance = appearance
            }
        )
        .navigationBarTitle(LocalizedChatString("GroupNotice"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeState.colors.textColorLink)
            },
            trailing: canEdit ? Button(isEditing ? LocalizedChatString("Done") : LocalizedChatString("Edit")) {
                if isEditing {
                    settingStore.updateGroupProfile(
                        name: nil,
                        notice: editedNotice,
                        avatar: nil,
                        completion: { result in
                            switch result {
                            case .success:
                                isEditing = false
                                isTextEditorFocused = false
                            case .failure:
                                break
                            }
                        }
                    )
                } else {
                    editedNotice = notice
                    isEditing = true
                    isTextEditorFocused = true
                }
            }
            .foregroundColor(themeState.colors.textColorLink) : nil
        )
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.notice))) { notice in
            self.notice = notice
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupType))) { groupType in
            self.groupType = groupType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.currentUserRole))) { currentUserRole in
            self.currentUserRole = currentUserRole
        }
        .onAppear {
            editedNotice = notice
        }
    }
}

// MARK: - Add Group Member View

private struct AddGroupMemberView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    @State private var friendList: [ContactInfo] = []
    let settingStore: GroupSettingStore
    @State private var contactStore: ContactListStore

    init(settingStore: GroupSettingStore) {
        self.settingStore = settingStore
        self._contactStore = State(initialValue: ContactListStore.create())
    }

    private var preSelectedUsers: Set<String> {
        return Set(allMembers.map { $0.userID })
    }

    private var userList: [UserPickerItem] {
        return friendList.map { contact in
            UserPickerItem(
                userID: contact.contactID,
                avatarURL: contact.avatarURL,
                title: contact.title ?? contact.contactID
            )
        }
    }

    var body: some View {
        VStack {
            UserPicker(
                userList: userList,
                defaultSelectedItems: preSelectedUsers,
                maxCount: 0, // 0 means unlimited selection
                onSelectedChanged: { selectedUsers in
                    addSelectedMembers(selectedUsers)
                }
            )
        }
        .navigationBarTitle(LocalizedChatString("GroupAddFirend"), displayMode: .inline)
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))) { newFriendList in
            self.friendList = newFriendList
        }
        .onAppear {
            // Initialize with current data
            self.friendList = contactStore.state.value.friendList

            // Fetch latest data
            contactStore.fetchFriendList(completion: { result in
                switch result {
                case .success:
                    print(" AddGroupMemberView: fetchFriendList success")
                case .failure(let error):
                    print(" AddGroupMemberView: fetchFriendList failed: \(error)")
                }
            })
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
    }

    private func addSelectedMembers(_ selectedUsers: [UserPickerItem]) {
        let userIDs = selectedUsers.map { $0.userID }
        settingStore.addGroupMember(
            userIDList: userIDs,
            completion: nil
        )
    }
}

// MARK: - Group Member List View

private struct GroupMemberListView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMemberActionSheet = false
    @State private var selectedMember: GroupMember?
    @State private var showingMemberDetail = false
    @State private var selectedMemberForDetail: GroupMember?
    @State private var allMembers: [GroupMember] = []
    @State private var memberCount: UInt = 0
    @State private var groupType: GroupType = .work
    @State private var currentUserRole: GroupMemberRole = .member
    @State private var currentUserID: String = ""
    let settingStore: GroupSettingStore
    let onGroupMemberClick: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(allMembers, id: \.userID) { member in
                        if #available(iOS 26.0, *) {
                            // iOS 26+: use contextMenu for proper arrow pointing
                            GroupMemberListRowContent(member: member)
                                .contextMenu {
                                    if member.userID != currentUserID {
                                        memberContextMenuContent(for: member)
                                    }
                                }
                                .onTapGesture {
                                    handleMemberTap(member)
                                }
                        } else {
                            // iOS < 26: use tap to show confirmationDialog
                            GroupMemberListRow(
                                member: member,
                                action: {
                                    handleMemberTap(member)
                                }
                            )
                        }
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
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeState.colors.textColorLink)
            }
        )
        .modifier(MemberActionSheetModifier(
            isPresented: $showingMemberActionSheet,
            selectedMember: selectedMember,
            canPerformAction: canPerformAction,
            currentUserRole: currentUserRole,
            onMemberDetail: handleMemberDetail,
            onSetMemberRole: handleSetMemberRole,
            onRemoveMember: handleRemoveMember
        ))
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
        .onAppear {
            settingStore.fetchGroupMemberList(role: .all, completion: { _ in
            })
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.memberCount))) { memberCount in
            self.memberCount = memberCount
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.groupType))) { groupType in
            self.groupType = groupType
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.currentUserRole))) { currentUserRole in
            self.currentUserRole = currentUserRole
        }
    }

    // MARK: - Context Menu Content Builder
    
    @ViewBuilder
    private func memberContextMenuContent(for member: GroupMember) -> some View {
        if canPerformAction(.getGroupMemberInfo) {
            Button {
                handleMemberDetail(member)
            } label: {
                Label(LocalizedChatString("GroupMemberDetail"), systemImage: "person.crop.circle")
            }
        }
        if member.role != .owner || currentUserRole == .owner {
            if canPerformAction(.setGroupMemberRole) {
                if member.role == .admin {
                    Button {
                        handleSetMemberRole(member, role: .member)
                    } label: {
                        Label(LocalizedChatString("CancelAdmin"), systemImage: "person.badge.minus")
                    }
                } else if member.role == .member {
                    Button {
                        handleSetMemberRole(member, role: .admin)
                    } label: {
                        Label(LocalizedChatString("SetAsAdmin"), systemImage: "person.badge.plus")
                    }
                }
            }
            if canPerformAction(.removeGroupMember) {
                Button(role: .destructive) {
                    handleRemoveMember(member)
                } label: {
                    Label(LocalizedChatString("RemoveMember"), systemImage: "person.badge.minus")
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handleMemberTap(_ member: GroupMember) {
        if member.userID == currentUserID {
            return
        }
        if #available(iOS 26.0, *) {
            // iOS 26+: tap goes to detail directly, long press shows context menu
            handleMemberDetail(member)
        } else {
            // iOS < 26: tap shows action sheet
            selectedMember = member
            showingMemberActionSheet = true
        }
    }

    private func canPerformAction(_ permission: GroupPermission) -> Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: permission
        )
    }

    private func handleMemberDetail(_ member: GroupMember) {
        if let onGroupMemberClick = onGroupMemberClick {
            onGroupMemberClick(member.userID)
        } else {
            selectedMemberForDetail = member
            showingMemberDetail = true
        }
    }

    private func handleSetMemberRole(_ member: GroupMember, role: GroupMemberRole) {
        settingStore.setGroupMemberRole(
            userID: member.userID,
            role: role,
            completion: nil
        )
    }

    private func handleRemoveMember(_ member: GroupMember) {
        settingStore.deleteGroupMember(
            members: [member],
            completion: nil
        )
    }
}

// MARK: - Member Action Sheet Modifier (iOS < 26)

private struct MemberActionSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let selectedMember: GroupMember?
    let canPerformAction: (GroupPermission) -> Bool
    let currentUserRole: GroupMemberRole
    let onMemberDetail: (GroupMember) -> Void
    let onSetMemberRole: (GroupMember, GroupMemberRole) -> Void
    let onRemoveMember: (GroupMember) -> Void
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: no action sheet needed, using contextMenu instead
            content
        } else {
            content
                .confirmationDialog(
                    selectedMember?.displayName ?? "",
                    isPresented: $isPresented,
                    titleVisibility: .visible
                ) {
                    if let member = selectedMember {
                        if canPerformAction(.getGroupMemberInfo) {
                            Button(LocalizedChatString("GroupMemberDetail")) {
                                onMemberDetail(member)
                            }
                        }
                        if member.role != .owner || currentUserRole == .owner {
                            if canPerformAction(.setGroupMemberRole) {
                                if member.role == .admin {
                                    Button(LocalizedChatString("CancelAdmin")) {
                                        onSetMemberRole(member, .member)
                                    }
                                } else if member.role == .member {
                                    Button(LocalizedChatString("SetAsAdmin")) {
                                        onSetMemberRole(member, .admin)
                                    }
                                }
                            }
                            if canPerformAction(.removeGroupMember) {
                                Button(LocalizedChatString("RemoveMember"), role: .destructive) {
                                    onRemoveMember(member)
                                }
                            }
                        }
                        Button(LocalizedChatString("Cancel"), role: .cancel) {}
                    }
                }
        }
    }
}

// MARK: - Group Member List Row Content (shared UI)

private struct GroupMemberListRowContent: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember

    var body: some View {
        HStack(spacing: 12) {
            Avatar(
                url: member.avatarURL,
                name: member.displayName
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.body)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    if member.role == .owner {
                        Text(LocalizedChatString("GroupOwnerLabel"))
                            .font(.caption)
                            .foregroundColor(Colors.GrayLight1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Colors.OrangeLight6)
                            .cornerRadius(4)
                    } else if member.role == .admin {
                        Text(LocalizedChatString("AdminLabel"))
                            .font(.caption)
                            .foregroundColor(Colors.GrayLight1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Colors.ThemeLight6)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeState.colors.textColorSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeState.colors.bgColorTopBar)
    }
}

// MARK: - Group Member List Row

private struct GroupMemberListRow: View {
    @EnvironmentObject var themeState: ThemeState
    let member: GroupMember
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(
                    url: member.avatarURL,
                    name: member.displayName
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(member.displayName)
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        if member.role == .owner {
                            Text(LocalizedChatString("GroupOwnerLabel"))
                                .font(.caption)
                                .foregroundColor(Colors.GrayLight1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Colors.OrangeLight6)
                                .cornerRadius(4)
                        } else if member.role == .admin {
                            Text(LocalizedChatString("AdminLabel"))
                                .font(.caption)
                                .foregroundColor(Colors.GrayLight1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Colors.ThemeLight6)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransferOwnershipView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var allMembers: [GroupMember] = []
    @State private var currentUserID: String = ""
    let settingStore: GroupSettingStore

    private var userList: [UserPickerItem] {
        return allMembers.compactMap { member in
            if member.userID == currentUserID {
                return nil
            }
            let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
            return UserPickerItem(
                userID: member.userID,
                avatarURL: member.avatarURL,
                title: member.displayName,
                subtitle: subtitle
            )
        }
    }

    var body: some View {
        UserPicker(
            userList: userList,
            onSelectedChanged: { selectedUsers in
                transferOwnership(selectedUsers)
            }
        )
        .navigationBarTitle(LocalizedChatString("GroupTransferOwner"), displayMode: .inline)
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \GroupSettingState.allMembers))) { allMembers in
            self.allMembers = allMembers
        }
    }

    private func transferOwnership(_ selectedUsers: [UserPickerItem]) {
        guard let selectedUser = selectedUsers.first else {
            return
        }
        settingStore.changeGroupOwner(
            newOwnerID: selectedUser.userID,
            completion: nil
        )
    }
}
