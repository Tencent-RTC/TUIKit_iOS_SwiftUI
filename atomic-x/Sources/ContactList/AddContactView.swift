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
                icon: "person.badge.plus",
                title: LocalizedChatString("ContactsAddFriends"),
                onClick: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onShowAddFriend()
                    }
                }
            ),
            PopMenuInfo(
                icon: "person.3.fill",
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
    private let contactStore: ContactListStore

    public init(contactStore: ContactListStore = ContactListStore.create()) {
        self.contactStore = contactStore
    }

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
            )
        }
        .background(themeState.colors.bgColorOperate)
        .sheet(isPresented: $showFriendDetail) {
            if let userInfo = addFriendInfo {
                AddFriendDetailView(
                    userInfo: userInfo,
                    contactStore: contactStore,
                    dismissAll: {
                        showFriendDetail = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .onAppear {
            contactStore.fetchFriendList(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.addFriendInfo))) { addFriendInfo in
            self.addFriendInfo = addFriendInfo
        }
    }

    private func searchUser() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        addFriendInfo = nil
        contactStore.fetchUserInfo(userID: searchText, completion: { result in
            switch result {
            case .success:
                isSearching = false
            case .failure:
                isSearching = false
            }
        })
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
                        name: userInfo.title ?? userInfo.contactID,
                        size: .l
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        // User name
                        Text(userInfo.title ?? userInfo.contactID)
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        // User ID
                        Text("\(LocalizedChatString("Identity")): \(userInfo.contactID)")
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
    @State private var joinGroupInfo: ContactInfo?
    private let contactStore: ContactListStore

    public init(contactStore: ContactListStore = ContactListStore.create()) {
        self.contactStore = contactStore
    }

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
            )
        }
        .sheet(isPresented: $showGroupDetail) {
            if let groupInfo = joinGroupInfo {
                JoinGroupDetailView(
                    groupInfo: groupInfo,
                    contactStore: contactStore,
                    dismissAll: {
                        showGroupDetail = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .onAppear {
            contactStore.fetchFriendList(completion: nil)
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.joinGroupInfo))) { joinGroupInfo in
            self.joinGroupInfo = joinGroupInfo
        }
    }

    private func searchGroup() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        joinGroupInfo = nil
        contactStore.fetchGroupInfo(groupID: searchText, completion: { result in
            switch result {
            case .success:
                isSearching = false
            case .failure(let error):
                isSearching = false
            }
        })
    }
}

struct JoinGroupResultCell: View {
    @EnvironmentObject var themeState: ThemeState
    let groupInfo: ContactInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Avatar
                    Avatar(
                        url: groupInfo.avatarURL,
                        name: groupInfo.title ?? groupInfo.contactID,
                        size: .l
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        // Group name
                        Text(groupInfo.title ?? groupInfo.contactID)
                            .font(.body)
                            .foregroundColor(themeState.colors.textColorPrimary)
                        // Group ID
                        Text("\(LocalizedChatString("Identity")): \(groupInfo.contactID)")
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorOperate)
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
    var contactStore: ContactListStore
    let userInfo: ContactInfo
    let dismissAll: () -> Void

    public init(userInfo: ContactInfo, contactStore: ContactListStore, dismissAll: @escaping () -> Void) {
        self.userInfo = userInfo
        self.contactStore = contactStore
        self.dismissAll = dismissAll
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    Avatar(
                        url: userInfo.avatarURL,
                        name: userInfo.title ?? userInfo.contactID,
                        size: .xl
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(userInfo.title ?? userInfo.contactID)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("Identity"))：\(userInfo.contactID)")
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
            .background(themeState.colors.bgColorOperate)
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
        if userInfo.isContact {
            isAddingFriend = false
            WindowToastManager.shared.show(LocalizedChatString("AlreadyFriend"), type: .error, duration: 3)
            return
        }
        contactStore.addFriend(userID: userInfo.contactID, remark: friendRemark.isEmpty ? nil : friendRemark, addWording: verificationMessage, completion: { result in
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
    var contactStore: ContactListStore
    let groupInfo: ContactInfo
    let dismissAll: () -> Void

    public init(groupInfo: ContactInfo, contactStore: ContactListStore, dismissAll: @escaping () -> Void) {
        self.groupInfo = groupInfo
        self.contactStore = contactStore
        self.dismissAll = dismissAll
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    Avatar(
                        url: groupInfo.avatarURL,
                        name: groupInfo.title ?? groupInfo.contactID,
                        size: .xl
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(groupInfo.title ?? groupInfo.contactID)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("GroupID"))：\(groupInfo.contactID)")
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Text("\(LocalizedChatString("GroupType"))：\(LocalizedChatString("NormalGroup"))")
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
            .background(themeState.colors.bgColorOperate)
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
        
        if groupInfo.isInGroup {
            isJoiningGroup = false
            WindowToastManager.shared.show(LocalizedChatString("AlreadyGroupMember"), type: .error, duration: 3)
            return
        }
        contactStore.joinGroup(
            groupID: groupInfo.contactID,
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
