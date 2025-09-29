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
    @State private var settingStore: C2CSettingStore
    @State private var conversationStore: ConversationListStore
    private let showsOwnNavigation: Bool
    private let onSendMessageClick: (() -> Void)?

    public init(
        userID: String,
        showsOwnNavigation: Bool,
        onSendMessageClick: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.settingStore = C2CSettingStore.create(userID: userID)
        self.showsOwnNavigation = showsOwnNavigation
        self.onSendMessageClick = onSendMessageClick
        self.conversationStore = ConversationListStore.create()
    }

    private func fetchInitialInfo() {
        let group = DispatchGroup()
        var hasError = false
        group.enter()
        settingStore.fetchUserInfo(completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        conversationStore.fetchConversationInfo(ChatUtil.getC2CConversationID(userID), completion: { result in
            switch result {
            case .success:
                group.leave()
            case .failure:
                hasError = true
                group.leave()
            }
        })
        group.enter()
        settingStore.checkBlacklistStatus(completion: { result in
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
            if showsOwnNavigation {
                NavigationView {
                    contentView
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarItems(
                            leading: Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeState.colors.textColorLink)
                            }
                        )
                }
            } else {
                contentView
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                    .toast(toast)
            }
        }
        .sheet(isPresented: $showingRemarkEdit) {
            RemarkEditView(
                currentRemark: remark,
                settingStore: settingStore
            ) { _ in
                // The remark should be automatically updated by the settingStore
                // No need to manually update here since setUserRemark will update the @Published property
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
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.remark))) { remark in
            self.remark = remark
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.nickname))) { nick in
            self.nick = nick
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.avatarURL))) { avatar in
            self.avatar = avatar
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.isNotDisturb))) { isNotDisturb in
            self.isNotDisturb = isNotDisturb
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.isPinned))) { isPinned in
            self.isPinned = isPinned
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.isInBlacklist))) { isInBlacklist in
            self.isInBlacklist = isInBlacklist
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
                            conversationStore.muteConversation(ChatUtil.getC2CConversationID(userID), mute: isNotDisturb) { result in
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
                            conversationStore.pinConversation(ChatUtil.getC2CConversationID(userID), pin: isPinned, completion: { result in
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
                .background(themeState.colors.bgColorOperate)
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
                .background(themeState.colors.bgColorOperate)
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
                .background(themeState.colors.bgColorOperate)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Private Methods

    private func addToBlacklist() {
        settingStore.addToBlacklist(completion: nil)
    }

    private func removeFromBlacklist() {
        settingStore.removeFromBlacklist(completion: nil)
    }

    private func deleteFriend() {
        settingStore.deleteFriend(completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    print("Successfully deleted friend")
                    self.presentationMode.wrappedValue.dismiss()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("Failed to delete friend: \(error.code) - \(error.message)")
                    // TODO: Show error alert
                }
            }
        })
    }

    private func clearHistory() {
        conversationStore.clearConversationMessages(ChatUtil.getC2CConversationID(userID), completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    print("Successfully cleared chat history")
                    toast.simple(LocalizedChatString("ClearAllChatHistory"))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("Failed to clear chat history: \(error.code) - \(error.message)")
                    toast.simple("Failed to clear chat history")
                }
            }
        })
    }
}

// MARK: - Remark Edit View

private struct RemarkEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var remarkText: String
    @State private var isLoading = false
    let settingStore: C2CSettingStore
    let onSave: (String) -> Void

    init(currentRemark: String, settingStore: C2CSettingStore, onSave: @escaping (String) -> Void) {
        self._remarkText = State(initialValue: currentRemark)
        self.settingStore = settingStore
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
        settingStore.setUserRemark(
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
