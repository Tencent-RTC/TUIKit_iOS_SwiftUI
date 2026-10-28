import AtomicXCore
import SwiftUI

struct C2CChatSettingImpl: View {
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
    @State private var showBackgroundPicker: Bool = false
    @State private var chatBackgroundIsSet: Bool = false
    @State private var aboutMe: String = ""
    @State private var userID: String = ""
    private let contactStore: ContactStore
    @State private var conversationStore: ConversationListStore
    private let onSendMessageClick: (() -> Void)?
    private let onContactDelete: (() -> Void)?
    private let onBack: (() -> Void)?

    private var conversationID: String {
        ChatUtil.getC2CConversationID(userID)
    }

    private let config: C2CChatSettingConfigProtocol

    init(
        userID: String,
        config: C2CChatSettingConfigProtocol? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.config = config ?? C2CChatSettingConfig()
        self.contactStore = ContactStore.shared
        self.onSendMessageClick = onSendMessageClick
        self.onContactDelete = onContactDelete
        self.onBack = onBack
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
                toast.error(LocalizedChatString("GetC2CSettingInfoFailed"))
            } else {
                print("fetch C2CChatSetting initial info succeeded")
            }
        }
    }

    private var displayName: String {
        nick.isEmpty ? userID : nick
    }

    private func saveRemark(_ text: String) {
        contactStore.setFriendRemark(userID: userID, remark: text, completion: nil)
    }

    var body: some View {
        Group {
            contentView
                .navigationBarTitle(LocalizedChatString("ProfileContactInfo"), displayMode: .inline)
                .navBackButton {
                    if let onBack = onBack { onBack() } else { presentationMode.wrappedValue.dismiss() }
                }
                .toast(toast)
        }
        .overlay(
            TextInputDialog(
                isPresented: $showingRemarkEdit,
                title: LocalizedChatString("ProfileEditAlia"),
                initialText: remark,
                onConfirm: saveRemark
            )
            .environmentObject(themeState)
        )
        .alert(item: $alertType) { type in
            switch type {
            case .deleteFriend:
                return Alert(
                    title: Text(LocalizedChatString("DeleteFriendConfirmTips")),
                    primaryButton: .destructive(Text(LocalizedChatString("AlertConfirm"))) {
                        deleteFriend()
                    },
                    secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
                )
            case .clearHistory:
                return Alert(
                    title: Text(LocalizedChatString("ClearContactHistoryTips")),
                    primaryButton: .destructive(Text(LocalizedChatString("Confirm"))) {
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

    private var customSettingRows: [(section: C2CChatSettingSection, row: AnyView)] {
        let editor = ChatSettingItemEditor<C2CChatSettingSection>()
        config.itemCustomizer?(editor)
        return editor.customRows
    }

    @ViewBuilder
    private func customRows(after section: C2CChatSettingSection) -> some View {
        let rows = customSettingRows.filter { $0.section == section }
        if !rows.isEmpty {
            sectionSpacer
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { rows[$0].row }
            }
            .background(themeState.colors.bgColorOperate)
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if config.isShowHeader {
                    headerSection
                }
                customRows(after: .header)
                if config.isShowRemark {
                    sectionSpacer
                    entryRow(title: LocalizedChatString("ProfileAlia"), value: remark.isEmpty ? displayName : remark) {
                        showingRemarkEdit = true
                    }
                }
                customRows(after: .remark)
                if config.isShowDoNotDisturb || config.isShowPin {
                    sectionSpacer
                    switchSection
                }
                customRows(after: .switches)
                if config.isShowChatBackground {
                    sectionSpacer
                    entryRow(title: LocalizedChatString("ChatBackgroundSetting"), value: chatBackgroundIsSet ? LocalizedChatString("ChatBackgroundCustom") : LocalizedChatString("ChatBackgroundDefault")) {
                        showBackgroundPicker = true
                    }
                }
                customRows(after: .background)
                if config.isShowBlacklist {
                    sectionSpacer
                    toggleRow(title: LocalizedChatString("ProfileBlocked"), isOn: $isInBlacklist) { value in
                        if value { addToBlacklist() } else { removeFromBlacklist() }
                    }
                }
                customRows(after: .blacklist)
                if hasActionSection {
                    sectionSpacer
                    actionSection
                }
                customRows(after: .actions)
                customRows(after: .end)
            }
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            AvatarView(url: avatar, name: displayName, size: .l, shape: .roundedRectangle)
            VStack(alignment: .leading, spacing: 0) {
                Text(displayName)
                    .font(FontScheme.body4Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(LocalizedChatString("ProfileUserID")): \(userID)")
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, CGFloat(SpacingScheme.iconTextSpacing))
                if !aboutMe.isEmpty {
                    Text(LocalizedChatString("ProfileSignaturePrefix") + aboutMe)
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorOperate)
    }

    private var sectionSpacer: some View {
        Rectangle()
            .fill(themeState.colors.bgColorTopBar)
            .frame(height: CGFloat(SpacingScheme.smallSpacing))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: 0.5)
    }

    private var arrowIcon: some View {
        Image("contact_info_arrow_right", bundle: AtomicXChatResources.resourceBundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundColor(themeState.colors.textColorTertiary)
    }

    private func entryRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                Text(value)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                arrowIcon
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleRow(title: String, isOn: Binding<Bool>, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(title)
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
            Spacer()
            Toggle("", isOn: Binding(get: { isOn.wrappedValue }, set: { isOn.wrappedValue = $0; onToggle($0) }))
                .labelsHidden()
                .tint(themeState.colors.switchColorOn)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorOperate)
    }

    private var switchSection: some View {
        VStack(spacing: 0) {
            if config.isShowDoNotDisturb {
                toggleRow(title: LocalizedChatString("ProfileMessageDoNotDisturb"), isOn: $isNotDisturb) { value in
                    let opt: ReceiveMessageOption = value ? .notNotify : .receive
                    conversationStore.setReceiveMessageOpt(conversationID: conversationID, opt: opt, completion: nil)
                }
            }
            if config.isShowDoNotDisturb && config.isShowPin {
                rowDivider
            }
            if config.isShowPin {
                toggleRow(title: LocalizedChatString("ProfileStickyonTop"), isOn: $isPinned) { value in
                    conversationStore.pinConversation(conversationID: conversationID, pin: value, completion: nil)
                }
            }
        }
    }

    private var showVoiceCall: Bool { config.isShowVoiceCall }
    private var showVideoCall: Bool { config.isShowVideoCall }

    private var hasActionSection: Bool {
        config.isShowSendMessage || showVoiceCall || showVideoCall || config.isShowClearHistory || config.isShowDeleteFriend
    }

    private func actionRow(title: String, textColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FontScheme.caption1Regular)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CGFloat(SpacingScheme.bubbleSpacing))
                .frame(minHeight: 56)
                .background(themeState.colors.bgColorOperate)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var actionSection: some View {
        VStack(spacing: 0) {
            if config.isShowSendMessage {
                actionRow(title: LocalizedChatString("ProfileSendMessages"), textColor: themeState.colors.textColorLink) { onSendMessageClick?() }
            }
            if config.isShowSendMessage && showVoiceCall { rowDivider }
            if showVoiceCall {
                actionRow(title: LocalizedChatString("MoreVoiceCall"), textColor: themeState.colors.textColorLink) {
                    ChatCallEventPublisher.publishStartCall(participantIDs: [userID], mediaType: .audio)
                }
            }
            if (config.isShowSendMessage || showVoiceCall) && showVideoCall { rowDivider }
            if showVideoCall {
                actionRow(title: LocalizedChatString("MoreVideoCall"), textColor: themeState.colors.textColorLink) {
                    ChatCallEventPublisher.publishStartCall(participantIDs: [userID], mediaType: .video)
                }
            }
            if (config.isShowSendMessage || showVoiceCall || showVideoCall) && config.isShowClearHistory { rowDivider }
            if config.isShowClearHistory {
                actionRow(title: LocalizedChatString("ClearAllChatHistory"), textColor: themeState.colors.textColorError) { alertType = .clearHistory }
            }
            if (config.isShowSendMessage || showVoiceCall || showVideoCall || config.isShowClearHistory) && config.isShowDeleteFriend { rowDivider }
            if config.isShowDeleteFriend {
                actionRow(title: LocalizedChatString("ProfileDeleteFirend"), textColor: themeState.colors.textColorError) { alertType = .deleteFriend }
            }
        }
    }



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
        if let signature = contactInfo.aboutMe {
            aboutMe = signature
        }
    }

    private func applyConversationInfo(_ conversationInfo: ConversationInfo) {
        isNotDisturb = conversationInfo.receiveOption != .receive
        isPinned = conversationInfo.isPinned
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
