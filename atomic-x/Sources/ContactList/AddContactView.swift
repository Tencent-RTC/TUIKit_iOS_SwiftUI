import AtomicXCore
import SwiftUI

public struct AddContactPopView: View {
    let onDismiss: () -> Void
    let onShowAddFriend: () -> Void
    let onShowJoinGroup: () -> Void

    public init(onDismiss: @escaping () -> Void, onShowAddFriend: @escaping () -> Void, onShowJoinGroup: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onShowAddFriend = onShowAddFriend
        self.onShowJoinGroup = onShowJoinGroup
    }

    public var body: some View {
        PopMenu(menuItems: [
            PopMenuInfo(
                title: LocalizedChatString("ContactsAddFriends"),
                onClick: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onShowAddFriend()
                    }
                }
            ),
            PopMenuInfo(
                title: LocalizedChatString("ContactsJoinGroup"),
                onClick: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onShowJoinGroup()
                    }
                }
            )
        ])
    }
}

public struct AddFriendView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showFriendDetail = false
    @State private var addFriendInfo: ContactInfo?

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeState.colors.textColorTertiary)
                    TextField(LocalizedChatString("SearchUserID"), text: $searchText, onCommit: {
                        searchUser()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(LocalizedChatString("Search")) {
                            searchUser()
                        }
                        .foregroundColor(themeState.colors.textColorLink)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                // Search result
                if let userInfo = addFriendInfo {
                    AddFriendResultCell(
                        userInfo: userInfo,
                        onTap: {
                            showFriendDetail = true
                        }
                    )
                    .padding(.horizontal, 16)
                } else if isSearching {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text(LocalizedChatString("Searching"))
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    .padding(.top, 20)
                }
                Spacer()
            }
            .navigationTitle(LocalizedChatString("ContactsAddFriends"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            )
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showFriendDetail) {
            if let userInfo = addFriendInfo {
                AddFriendDetailView(
                    userInfo: userInfo,
                    dismissAll: {
                        showFriendDetail = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .onAppear {
            ContactStore.shared.loadFriends(completion: nil)
        }
    }

    private func searchUser() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        addFriendInfo = nil
        ContactStore.shared.getContactInfo(
            userIDList: [searchText],
            completion: ContactInfoLookupHandler(
                onSuccess: { contactInfoList in
                    DispatchQueue.main.async {
                        self.addFriendInfo = contactInfoList.first
                        self.isSearching = false
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.addFriendInfo = nil
                        self.isSearching = false
                    }
                }
            )
        )
    }
}

// MARK: - Add Friend Result Cell

struct AddFriendResultCell: View {
    @EnvironmentObject var themeState: ThemeState
    let userInfo: ContactInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Avatar
                    Avatar(
                        url: userInfo.avatarURL,
                        name: contactDisplayName(userInfo),
                        size: .l
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        // User name
                        Text(contactDisplayName(userInfo))
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        // User ID
                        Text("\(LocalizedChatString("Identity")): \(userInfo.userID)")
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorEntryCard)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

public struct JoinGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showGroupDetail = false
    @State private var joinGroupInfo: GroupInfo?

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeState.colors.textColorTertiary)
                    TextField(LocalizedChatString("SearchGroupID"), text: $searchText, onCommit: {
                        searchGroup()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(LocalizedChatString("Search")) {
                            searchGroup()
                        }
                        .foregroundColor(themeState.colors.textColorLink)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if let groupInfo = joinGroupInfo {
                    JoinGroupResultCell(
                        groupInfo: groupInfo,
                        onTap: {
                            showGroupDetail = true
                        }
                    )
                    .padding(.horizontal, 16)
                } else if isSearching {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text(LocalizedChatString("Searching"))
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    .padding(.top, 20)
                }
                Spacer()
            }
            .navigationTitle(LocalizedChatString("ContactsJoinGroup"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            )
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showGroupDetail) {
            if let groupInfo = joinGroupInfo {
                JoinGroupDetailView(
                    groupInfo: groupInfo,
                    dismissAll: {
                        showGroupDetail = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .onAppear {
            GroupStore.shared.loadJoinedGroups(completion: nil)
        }
    }

    private func searchGroup() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        joinGroupInfo = nil
        GroupStore.shared.getGroupInfo(
            groupID: searchText,
            completion: GroupInfoLookupHandler(
                onSuccess: { groupInfo in
                    DispatchQueue.main.async {
                        self.joinGroupInfo = groupInfo
                        self.isSearching = false
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.joinGroupInfo = nil
                        self.isSearching = false
                    }
                }
            )
        )
    }
}

struct JoinGroupResultCell: View {
    @EnvironmentObject var themeState: ThemeState
    let groupInfo: GroupInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Avatar
                    Avatar(
                        url: groupInfo.avatarURL,
                        name: groupDisplayName(groupInfo),
                        size: .l
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        // Group name
                        Text(groupDisplayName(groupInfo))
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        // Group ID
                        Text("\(LocalizedChatString("Identity")): \(groupInfo.groupID)")
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorTopBar)
            .cornerRadius(8)
            .shadow(color: themeState.colors.bgColorElementMask, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddFriendDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var verificationMessage = ""
    @State private var friendRemark = ""
    @State private var isAddingFriend = false
    let userInfo: ContactInfo
    let dismissAll: () -> Void

    public init(userInfo: ContactInfo, dismissAll: @escaping () -> Void) {
        self.userInfo = userInfo
        self.dismissAll = dismissAll
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    Avatar(
                        url: userInfo.avatarURL,
                        name: contactDisplayName(userInfo),
                        size: .xl
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contactDisplayName(userInfo))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("Identity"))：\(userInfo.userID)")
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedChatString("FillVerificationInfo"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.horizontal, 16)
                    TextField(LocalizedChatString("PleaseEnterVerificationInfo"), text: $verificationMessage)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(themeState.colors.bgColorInput)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedChatString("FriendRemarkSetting"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.horizontal, 16)
                    TextField(LocalizedChatString("PleaseEnterRemarkName"), text: $friendRemark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(themeState.colors.bgColorInput)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                }
                Spacer()
                Button(action: {
                    sendFriendRequest()
                }) {
                    HStack {
                        if isAddingFriend {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isAddingFriend ? LocalizedChatString("Sending") : LocalizedChatString("Send"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.textColorButton)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isAddingFriend ? themeState.colors.textColorLink.opacity(0.6) : themeState.colors.textColorLink)
                    .cornerRadius(10)
                }
                .disabled(isAddingFriend)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(
                themeState.colors.bgColorOperate
                    .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    dismissAll()
                }
                .foregroundColor(themeState.colors.textColorLink)
            )
        }
    }

    private func sendFriendRequest() {
        isAddingFriend = true
        if userInfo.isFriend {
            isAddingFriend = false
            WindowToastManager.shared.show(LocalizedChatString("AlreadyFriend"), type: .error, duration: 3)
            return
        }
        ContactStore.shared.addFriend(userID: userInfo.userID, remark: friendRemark.isEmpty ? nil : friendRemark, addWording: verificationMessage, completion: { result in
            switch result {
            case .success:
                isAddingFriend = false
                // Show success message and dismiss all
                WindowToastManager.shared.show(LocalizedChatString("FriendRequestSent"), type: .success, duration: 3)
                dismissAll()
            case .failure(let error):
                isAddingFriend = false
                print("Add friend failed: \(error.code) - \(error.message)")
                if error.code == 30515 {
                    WindowToastManager.shared.show(LocalizedChatString("AlreadyFriend"), type: .error, duration: 3)
                } else if error.code == 30516 {
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestAlreadySentForbid"), type: .error, duration: 3)
                } else if error.code == 30525 {
                    WindowToastManager.shared.show(LocalizedChatString("UserNotFound"), type: .error, duration: 3)
                } else if error.code == 30539 {
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestSent"), type: .success, duration: 3)
                } else {
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestFailed"), type: .error, duration: 3)
                }
            }
        })
    }
}

public struct JoinGroupDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var verificationMessage = LocalizedChatString("ApplyJoinGroup")
    @State private var isJoiningGroup = false
    let groupInfo: GroupInfo
    let dismissAll: () -> Void

    public init(groupInfo: GroupInfo, dismissAll: @escaping () -> Void) {
        self.groupInfo = groupInfo
        self.dismissAll = dismissAll
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    Avatar(
                        url: groupInfo.avatarURL,
                        name: groupDisplayName(groupInfo),
                        size: .xl
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(groupDisplayName(groupInfo))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("GroupID"))：\(groupInfo.groupID)")
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("GroupType"))：\(groupInfo.groupType?.rawValue ?? LocalizedChatString("NormalGroup"))")
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedChatString("FillVerificationInfo"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.horizontal, 16)
                    TextField(LocalizedChatString("PleaseEnterVerificationInfo"), text: $verificationMessage)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(themeState.colors.bgColorInput)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                }
                Spacer()
                Button(action: {
                    joinGroup()
                }) {
                    HStack {
                        if isJoiningGroup {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isJoiningGroup ? LocalizedChatString("Joining") : LocalizedChatString("Send"))
                            .font(.system(size: 16))
                            .foregroundColor(themeState.colors.textColorButton)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isJoiningGroup ? themeState.colors.textColorLink.opacity(0.6) : themeState.colors.textColorLink)
                    .cornerRadius(10)
                }
                .disabled(isJoiningGroup)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(
                themeState.colors.bgColorOperate
                    .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    dismissAll()
                }
                .foregroundColor(themeState.colors.textColorLink)
            )
        }
    }

    private func joinGroup() {
        isJoiningGroup = true

        if GroupStore.shared.state.value.joinedGroupList.contains(where: { $0.groupID == groupInfo.groupID }) {
            isJoiningGroup = false
            WindowToastManager.shared.show(LocalizedChatString("AlreadyGroupMember"), type: .error, duration: 3)
            return
        }
        GroupStore.shared.joinGroup(
            groupID: groupInfo.groupID,
            message: verificationMessage,
            completion: { result in
                switch result {
                case .success:
                    isJoiningGroup = false
                    // Show success message and dismiss all
                    WindowToastManager.shared.show(LocalizedChatString("GroupJoinRequestSent"), type: .success, duration: 3)
                    dismissAll()

                case .failure(let error):
                    isJoiningGroup = false
                    print("Join group failed: \(error.code) - \(error.message)")

                    if error.code == 10013 {
                        WindowToastManager.shared.show(LocalizedChatString("AlreadyGroupMember"), type: .error, duration: 3)
                    } else if error.code == 10010 {
                        WindowToastManager.shared.show(LocalizedChatString("GroupNotFound"), type: .error, duration: 3)
                    } else if error.code == 10015 {
                        WindowToastManager.shared.show(LocalizedChatString("GroupJoinRequestAlreadySent"), type: .error, duration: 3)
                    } else if error.code == 10016 {
                        WindowToastManager.shared.show(LocalizedChatString("GroupJoinForbidden"), type: .error, duration: 3)
                    } else {
                        WindowToastManager.shared.show(LocalizedChatString("GroupJoinRequestFailed"), type: .error, duration: 3)
                    }
                }
            }
        )
    }
}

private func contactDisplayName(_ contact: ContactInfo) -> String {
    if let remark = contact.friendRemark, !remark.isEmpty {
        return remark
    }
    if let nickname = contact.nickname, !nickname.isEmpty {
        return nickname
    }
    return contact.userID
}

private func groupDisplayName(_ group: GroupInfo) -> String {
    if let groupName = group.groupName, !groupName.isEmpty {
        return groupName
    }
    return group.groupID
}

private final class ContactInfoLookupHandler: GetContactInfoCompletionHandler {
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

private final class GroupInfoLookupHandler: GetGroupInfoCompletionHandler {
    private let onSuccessBlock: (GroupInfo) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (GroupInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(groupInfo: GroupInfo) {
        onSuccessBlock(groupInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
