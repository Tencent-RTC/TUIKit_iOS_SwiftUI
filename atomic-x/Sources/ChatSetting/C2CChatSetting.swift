import AtomicXCore
import SwiftUI

public struct C2CChatSetting: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    @State private var showingRemarkEdit = false
    @State private var alertType: AlertType?
    @State private var remark: String = ""
    @State private var nick: String = ""
    @State private var avatar: String = ""
    @State private var isNotDisturb: Bool = false
    @State private var isPinned: Bool = false
    @State private var isInBlacklist: Bool = false
    @State private var userID: String = ""
    private let contactStore: ContactStore
    @State private var conversationStore: ConversationListStore
    private let onSendMessageClick: (() -> Void)?
    private let onContactDelete: (() -> Void)?

    private var conversationID: String {
        ChatUtil.getC2CConversationID(userID)
    }

    public init(
        userID: String,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.contactStore = ContactStore.shared
        self.onSendMessageClick = onSendMessageClick
        self.onContactDelete = onContactDelete
        self.conversationStore = ConversationListStore.create()
    }

    private func fetchInitialInfo() {
        let group = DispatchGroup()
        var hasError = false
        group.enter()
        contactStore.loadFriends(completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        contactStore.getContactInfo(
            userIDList: [userID],
            completion: ContactInfoHandler(
                onSuccess: { contactInfoList in
                    if let contactInfo = contactInfoList.first {
                        DispatchQueue.main.async {
                            self.applyContactInfo(contactInfo)
                        }
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
            completion: ConversationInfoHandler(
                onSuccess: { conversationInfo in
                    DispatchQueue.main.async {
                        self.applyConversationInfo(conversationInfo)
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
        contactStore.loadBlackList(completion: { result in
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
//                toast.error(LocalizedChatString("GetC2CSettingInfoFailed"))
                print("fetch C2CChatSetting initial info failed")
            } else {
                print("fetch C2CChatSetting initial info succeeded")
            }
        }
    }

    // Priority: remark > nick > userID
    private var displayName: String {
        if !remark.isEmpty {
            return remark
        } else if !nick.isEmpty {
            return nick
        } else {
            return userID
        }
    }

    public var body: some View {
        Group {
            contentView
                .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                .toast(toast)
        }
        .sheet(isPresented: $showingRemarkEdit) {
            RemarkEditView(
                currentRemark: remark,
                contactStore: contactStore,
                userID: userID
            ) { _ in
                // The remark is refreshed through ContactStore state updates.
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .deleteFriend:
                return Alert(
                    title: Text(LocalizedChatString("ProfileDeleteFirend")),
                    message: Text(LocalizedChatString("DeleteFriendConfirmMessage")),
                    primaryButton: .destructive(Text(LocalizedChatString("Delete"))) {
                        deleteFriend()
                    },
                    secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
                )
            case .clearHistory:
                return Alert(
                    title: Text(LocalizedChatString("ClearAllChatHistory")),
                    message: Text(LocalizedChatString("ClearAllChatHistoryTips")),
                    primaryButton: .destructive(Text(LocalizedChatString("Clear"))) {
                        clearHistory()
                    },
                    secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
                )
            case .deleteAndQuit, .dismissGroup:
                return Alert(
                    title: Text(""),
                    message: Text(""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))) { friendList in
            if let contactInfo = friendList.first(where: { $0.userID == userID }) {
                applyContactInfo(contactInfo)
            }
        }
        .onReceive(contactStore.state.subscribe(StatePublisherSelector(keyPath: \ContactState.blackList))) { blackList in
            self.isInBlacklist = blackList.contains(where: { $0.userID == userID })
        }
        .onReceive(conversationStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))) { conversationList in
            if let conversationInfo = conversationList.first(where: { $0.conversationID == conversationID }) {
                applyConversationInfo(conversationInfo)
            }
        }
        .onAppear {
            fetchInitialInfo()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with avatar and name
                VStack(spacing: 16) {
                    // Avatar
                    Avatar(
                        url: avatar,
                        name: displayName,
                        size: .xxl
                    )
                    // User name
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    // User ID
                    Text("ID：\(userID)")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                // Action buttons (Message, Audio, Video)
                HStack(spacing: 20) {
                    CustomActionButton(
                        icon: "setting_sendmsg",
                        title: LocalizedChatString("ProfileSendMessages"),
                        action: {
                            onSendMessageClick?()
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                // Group 0: Nickname
                VStack(spacing: 1) {
                    SettingRowNavigate(
                        title: LocalizedChatString("ProfileAlia"),
                        subtitle: remark.isEmpty ? LocalizedChatString("Unsetted") : remark,
                        action: {
                            showingRemarkEdit = true
                        }
                    )
                }
                .background(themeState.colors.bgColorTopBar)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                // Group 1: Message Do Not Disturb, Pin Chat
                VStack(spacing: 1) {
                    SettingRowToggle(
                        title: LocalizedChatString("ProfileMessageDoNotDisturb"),
                        isOn: $isNotDisturb,
                        onToggle: { value in
                            let opt: ReceiveMessageOption = value ? .notNotify : .receive
                            conversationStore.setReceiveMessageOpt(conversationID: conversationID, opt: opt) { result in
                                switch result {
                                case .success:
                                    print("Successfully set message do not disturb: \(value)")
                                case .failure(let error):
                                    print("Failed to set message do not disturb: \(error.code) - \(error.message)")
                                }
                            }
                        }
                    )
                    SettingRowToggle(
                        title: LocalizedChatString("ProfileStickyonTop"),
                        isOn: $isPinned,
                        onToggle: { value in
                            conversationStore.pinConversation(conversationID: conversationID, pin: value, completion: { result in
                                switch result {
                                case .success:
                                    print("Successfully set pin chat: \(value)")
                                case .failure(let error):
                                    print("Failed to set pin chat: \(error.code) - \(error.message)")
                                }
                            })
                        }
                    )
                }
                .background(themeState.colors.bgColorTopBar)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                // Group 2: Set current chat background
                /**
                 VStack(spacing: 1) {
                     SettingRowNavigate(
                         title: LocalizedChatString("ProfileSetBackgroundImage"),
                         action: {
                             // Handle set chat background
                         }
                     )
                 }
                 .background(themeState.colors.bgColorOperate)
                 .cornerRadius(12)
                 .padding(.horizontal, 16)
                 .padding(.bottom, 20)
                  */
                // Group 3: Add to blacklist
                VStack(spacing: 1) {
                    SettingRowToggle(
                        title: LocalizedChatString("ProfileBlocked"),
                        isOn: $isInBlacklist,
                        onToggle: { value in
                            if value {
                                addToBlacklist()
                            } else {
                                removeFromBlacklist()
                            }
                        }
                    )
                }
                .background(themeState.colors.bgColorTopBar)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                // Group 4: Clear chat history, delete friend
                VStack(spacing: 1) {
                    SettingRowButton(
                        title: LocalizedChatString("ClearAllChatHistory"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            alertType = .clearHistory
                        }
                    )
                    SettingRowButton(
                        title: LocalizedChatString("ProfileDeleteFirend"),
                        textColor: themeState.colors.textColorError,
                        action: {
                            alertType = .deleteFriend
                        }
                    )
                }
                .background(themeState.colors.bgColorTopBar)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
    }

    // MARK: - Private Methods

    private func addToBlacklist() {
        contactStore.addToBlacklist(userID: userID) { result in
            switch result {
            case .success:
                contactStore.loadBlackList(completion: nil)
            case .failure(let error):
                print("Failed to add user to blacklist: \(error.code) - \(error.message)")
                DispatchQueue.main.async {
                    self.isInBlacklist = false
                }
            }
        }
    }

    private func removeFromBlacklist() {
        contactStore.removeFromBlacklist(userID: userID) { result in
            switch result {
            case .success:
                contactStore.loadBlackList(completion: nil)
            case .failure(let error):
                print("Failed to remove user from blacklist: \(error.code) - \(error.message)")
                DispatchQueue.main.async {
                    self.isInBlacklist = true
                }
            }
        }
    }

    private func deleteFriend() {
        contactStore.deleteFriend(userID: userID, completion: { result in
            switch result {
            case .success:
                print("Successfully deleted friend")
                conversationStore.deleteConversation(conversationID: conversationID, completion: nil)
            case .failure(let error):
                print("Failed to delete friend: \(error.code) - \(error.message)")
            }
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
                self.onContactDelete?()
            }
        })
    }

    private func clearHistory() {
        conversationStore.clearConversationMessages(conversationID: conversationID, completion: { result in
            switch result {
            case .success:
                print("Successfully cleared chat history")
                DispatchQueue.main.async {
                    toast.simple(LocalizedChatString("ClearAllChatHistory"))
                }
            case .failure(let error):
                print("Failed to clear chat history: \(error.code) - \(error.message)")
            }
        })
    }

    private func applyContactInfo(_ contactInfo: ContactInfo) {
        if let friendRemark = contactInfo.friendRemark {
            remark = friendRemark
        }
        if let nickname = contactInfo.nickname {
            nick = nickname
        }
        if let avatarURL = contactInfo.avatarURL {
            avatar = avatarURL
        }
    }

    private func applyConversationInfo(_ conversationInfo: ConversationInfo) {
        isNotDisturb = conversationInfo.receiveOption != .receive
        isPinned = conversationInfo.isPinned
    }
}

// MARK: - Remark Edit View

private struct RemarkEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var remarkText: String
    @State private var isLoading = false
    let contactStore: ContactStore
    let userID: String
    let onSave: (String) -> Void

    init(currentRemark: String, contactStore: ContactStore, userID: String, onSave: @escaping (String) -> Void) {
        self._remarkText = State(initialValue: currentRemark)
        self.contactStore = contactStore
        self.userID = userID
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedChatString("PleaseEnterRemark"))
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                TextField(LocalizedChatString("ProfileAlia"), text: $remarkText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 16)
                Spacer()
            }
            .navigationBarTitle(LocalizedChatString("ProfileEditAlia"), displayMode: .inline)
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorSecondary),
                trailing: Button(LocalizedChatString("Save")) {
                    saveRemark()
                }
                .foregroundColor(themeState.colors.textColorLink)
                .disabled(isLoading)
            )
        }
    }

    private func saveRemark() {
        isLoading = true
        contactStore.setFriendRemark(
            userID: userID,
            remark: remarkText,
            completion: { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.onSave(self.remarkText)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        print("Failed to set nickname: \(error.code) - \(error.message)")
                    }
                }
            }
        )
    }
}

private final class ContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessHandler: ([ContactInfo]) -> Void
    private let onFailureHandler: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessHandler(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}

private final class ConversationInfoHandler: GetConversationInfoCompletionHandler {
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
