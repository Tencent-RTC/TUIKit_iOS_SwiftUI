import AtomicXCore
import SwiftUI

struct AddContactPopViewImpl: View {
    let onDismiss: () -> Void
    let onShowAddFriend: () -> Void
    let onShowJoinGroup: () -> Void

    init(onDismiss: @escaping () -> Void, onShowAddFriend: @escaping () -> Void, onShowJoinGroup: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onShowAddFriend = onShowAddFriend
        self.onShowJoinGroup = onShowJoinGroup
    }

    var body: some View {
        PopMenuView(menuItems: [
            PopMenuInfo(
                icon: "contact_add_friend",
                title: LocalizedChatString("ContactsAddFriends"),
                onClick: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onShowAddFriend()
                    }
                }
            ),
            PopMenuInfo(
                icon: "contact_add_group",
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


struct ContactFlowNavigationBar: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(FontScheme.caption1Medium)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing) * 2 + 28)
                HStack(spacing: 0) {
                    Button(action: onBack) {
                        Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                            .renderingMode(.template)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .frame(width: 28, height: 28, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(.leading, CGFloat(SpacingScheme.bubbleSpacing))
            }
            .frame(height: 56)
            Rectangle()
                .fill(themeState.colors.strokeColorSecondary)
                .frame(height: 0.5)
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea(edges: .top))
    }
}

struct ContactSearchResultCell: View {
    @EnvironmentObject var themeState: ThemeState
    let avatarURL: String?
    let name: String
    let identityLabel: String
    let identityValue: String
    let tip: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                AvatarView(url: avatarURL, name: name, size: .l, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                    identityText
                        .font(themeState.fonts.caption3Regular)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                if let tip = tip {
                    Text(tip)
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var identityText: Text {
        let full = String(format: LocalizedChatString("ContactLabelValueFormat"), identityLabel, identityValue)
        guard let range = full.range(of: identityValue, options: .backwards) else {
            return Text(full).foregroundColor(themeState.colors.textColorSecondary)
        }
        return Text(String(full[..<range.lowerBound])).foregroundColor(themeState.colors.textColorSecondary)
            + Text(String(full[range])).foregroundColor(themeState.colors.textColorLink)
            + Text(String(full[range.upperBound...])).foregroundColor(themeState.colors.textColorSecondary)
    }
}

private func contactFlowHideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private func selfDisplayName() -> String {
    let info = LoginStore.shared.state.value.loginUserInfo
    if let nickname = info?.nickname, !nickname.isEmpty { return nickname }
    return info?.userID ?? ""
}

private func labelValueText(_ label: String, _ value: String) -> String {
    let isChinese = LanguageHelper.getCurrentLanguage().hasPrefix("zh")
    return isChinese ? "\(label)：\(value)" : "\(label): \(value)"
}


struct AddFriendViewImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var foundContact: ContactInfo?
    @State private var showAddContact = false

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            ContactFlowNavigationBar(title: LocalizedChatString("ContactListAddContact")) {
                presentationMode.wrappedValue.dismiss()
            }
            ContactFlowSearchField(
                text: $searchText,
                placeholder: LocalizedChatString("ProfileUserID"),
                onSubmit: searchUser
            )
            ZStack(alignment: .top) {
                if let contact = foundContact {
                    ContactSearchResultCell(
                        avatarURL: contact.avatarURL,
                        name: ContactDisplayName.name(for: contact),
                        identityLabel: LocalizedChatString("ProfileUserID"),
                        identityValue: contact.userID,
                        tip: contact.isFriend ? LocalizedChatString("AlreadyFriendTip") : nil,
                        onTap: {
                            guard !contact.isFriend else { return }
                            contactFlowHideKeyboard()
                            showAddContact = true
                        }
                    )
                } else if isSearching {
                    ProgressView()
                        .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                } else if hasSearched {
                    Text(LocalizedChatString("ContactNoInformation"))
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                        .padding(.top, 80)
                } else {
                    Text(String(format: LocalizedChatString("ContactLabelValueFormat"),
                                LocalizedChatString("ContactMyUserID"),
                                LoginStore.shared.state.value.loginUserInfo?.userID ?? ""))
                        .font(themeState.fonts.caption2Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                        .padding(.top, 80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { contactFlowHideKeyboard() }
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: Group {
                    if let contact = foundContact {
                        AddContactDetailView(
                            userID: contact.userID,
                            contactInfo: contact,
                            onFinished: {
                                showAddContact = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                        .environmentObject(themeState)
                    }
                },
                isActive: $showAddContact
            ) { EmptyView() }
            .hidden()
        )
        .onChange(of: searchText) { text in
            if text.isEmpty {
                hasSearched = false
                foundContact = nil
            }
        }
        .onAppear {
            ContactStore.shared.loadFriends(completion: nil)
        }
    }

    private func searchUser() {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        hasSearched = true
        foundContact = nil
        isSearching = true
        ContactStore.shared.getContactInfo(
            userIDList: [keyword],
            completion: ContactInfoLookupHandler(
                onSuccess: { contactInfoList in
                    DispatchQueue.main.async {
                        self.foundContact = contactInfoList.first
                        self.isSearching = false
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.foundContact = nil
                        self.isSearching = false
                    }
                }
            )
        )
    }
}

struct ContactFlowSearchField: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 36 - 8 - 15) {
            Image("contact_search", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.template)
                .resizable()
                .frame(width: 15, height: 15 * (29.6484 / 27.889))
                .foregroundColor(themeState.colors.textColorTertiary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(themeState.colors.textColorTertiary))
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image("contact_search_clear", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
        .padding(.trailing, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(height: 36)
        .background(themeState.colors.bgColorInput)
        .cornerRadius(CGFloat(RadiusScheme.alertRadius))
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .background(themeState.colors.bgColorOperate)
    }
}


struct AddContactDetailViewImpl: View {
    private enum Step { case detail, form }

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var step: Step = .detail
    @State private var contactInfo: ContactInfo?
    @State private var wording = ""
    @State private var remark = ""
    @State private var isSending = false
    @State private var hostViewController: UIViewController?

    let userID: String
    let onFinished: (() -> Void)?

    init(userID: String, contactInfo: ContactInfo? = nil, onFinished: (() -> Void)? = nil) {
        self.userID = userID
        self.onFinished = onFinished
        self._contactInfo = State(initialValue: contactInfo)
    }

    private var displayName: String {
        contactInfo.map { ContactDisplayName.name(for: $0) } ?? userID
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactFlowNavigationBar(title: LocalizedChatString("ContactListAddContact")) {
                if step == .form {
                    contactFlowHideKeyboard()
                    step = .detail
                } else {
                    popSelf()
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    infoCard
                    if step == .detail {
                        sectionSpacer
                        actionRow(LocalizedChatString("ContactListAddContact")) {
                            applyFormDefaults()
                            step = .form
                        }
                    } else {
                        sectionTitle(LocalizedChatString("ContactListFillValidationMessage"))
                        wordingCard
                        sectionSpacer
                        remarkRow
                        sectionSpacer
                        actionRow(LocalizedChatString("Send"), action: send)
                            .disabled(isSending)
                    }
                }
            }
            .scrollDismissesKeyboardCompat()
        }
        .background(themeState.colors.bgColorDefault.ignoresSafeArea())
        .background(HostViewControllerBeacon { hostViewController = $0 })
        .navigationBarHidden(true)
        .onAppear {
            if contactInfo == nil { fetchUserInfo() }
        }
    }

    private var infoCard: some View {
        HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
            AvatarView(url: contactInfo?.avatarURL, name: displayName, size: .l)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(themeState.fonts.caption1Bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                Text(labelValueText(LocalizedChatString("ProfileUserID"), userID))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(1)
                Text(labelValueText(LocalizedChatString("ProfileSignature"), signatureText))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorOperate)
    }

    private var signatureText: String {
        let aboutMe = contactInfo?.aboutMe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return aboutMe.isEmpty ? LocalizedChatString("ContactListNoContent") : aboutMe
    }

    private var sectionSpacer: some View {
        themeState.colors.bgColorDefault.frame(height: CGFloat(SpacingScheme.smallSpacing))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(themeState.fonts.caption2Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.top, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))
            .background(themeState.colors.bgColorDefault)
    }

    private var wordingCard: some View {
        TextEditor(text: $wording)
            .font(themeState.fonts.caption1Regular)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(minHeight: 120 - 28)
            .padding(CGFloat(SpacingScheme.bubbleSpacing))
            .background(themeState.colors.bgColorOperate)
            .onAppear { UITextView.appearance().backgroundColor = .clear }
    }

    private var remarkRow: some View {
        HStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
            Text(LocalizedChatString("ContactListRemark"))
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .fixedSize()
            TextField("", text: $remark)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .frame(height: 52)
        .background(themeState.colors.bgColorOperate)
    }

    private func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorLink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(themeState.colors.bgColorOperate)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func applyFormDefaults() {
        wording = String(format: LocalizedChatString("ContactListAddWordingIAm"), selfDisplayName())
        remark = displayName
    }

    private func fetchUserInfo() {
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: ContactInfoLookupHandler(
                onSuccess: { list in
                    DispatchQueue.main.async {
                        self.contactInfo = list.first
                        if self.step == .form { self.applyFormDefaults() }
                    }
                },
                onFailure: { _, _ in }
            )
        )
    }

    private func send() {
        guard !isSending else { return }
        contactFlowHideKeyboard()
        var finalRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalRemark.isEmpty {
            finalRemark = contactInfo?.nickname ?? userID
        }
        isSending = true
        ContactStore.shared.addFriend(
            userID: userID,
            remark: finalRemark,
            addWording: wording.isEmpty ? nil : wording
        ) { result in
            DispatchQueue.main.async {
                self.isSending = false
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("ContactListAddFriendSuccess"), type: .success, duration: 2)
                    self.finish()
                case .failure(let error):
                    if error.code == 30539 {
                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestSent"), type: .success, duration: 2)
                        self.finish()
                    } else if error.code == 30001 && error.message == "Err_SNS_FriendAdd_Friend_Exist" {
                        WindowToastManager.shared.show(LocalizedChatString("AlreadyFriendTip"), type: .info, duration: 2)
                    } else {
                        WindowToastManager.shared.show(LocalizedChatString("ContactListAddFriendFailed"), type: .error, duration: 2)
                    }
                }
            }
        }
    }

    private func finish() {
        if let onFinished = onFinished {
            onFinished()
        } else {
            popSelf()
        }
    }

    private func popSelf() {
        if let navigationController = hostViewController?.navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}


struct JoinGroupViewImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var foundGroup: GroupInfo?
    @State private var showGroupDetail = false
    @State private var joinedGroupIDs: Set<String> = []

    let onEnterGroupChat: ((GroupInfo) -> Void)?
    init(onEnterGroupChat: ((GroupInfo) -> Void)? = nil) {
        self.onEnterGroupChat = onEnterGroupChat
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactFlowNavigationBar(title: LocalizedChatString("ContactsJoinGroupTitle")) {
                presentationMode.wrappedValue.dismiss()
            }
            ContactFlowSearchField(
                text: $searchText,
                placeholder: LocalizedChatString("GroupID"),
                onSubmit: searchGroup
            )
            ZStack(alignment: .top) {
                if let group = foundGroup {
                    let isJoined = isJoinedGroup(group)
                    ContactSearchResultCell(
                        avatarURL: group.avatarURL,
                        name: ContactDisplayName.name(for: group),
                        identityLabel: LocalizedChatString("GroupID"),
                        identityValue: group.groupID,
                        tip: isJoined ? LocalizedChatString("AlreadyInGroupTip") : nil,
                        onTap: {
                            contactFlowHideKeyboard()
                            if isJoined {
                                onEnterGroupChat?(group)
                            } else {
                                showGroupDetail = true
                            }
                        }
                    )
                } else if isSearching {
                    ProgressView()
                        .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                } else if hasSearched {
                    Text(LocalizedChatString("ContactNoInformation"))
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, CGFloat(SpacingScheme.cardSpacing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { contactFlowHideKeyboard() }
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: Group {
                    if let group = foundGroup {
                        JoinGroupDetailView(
                            groupInfo: group,
                            dismissAll: {
                                showGroupDetail = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                        .environmentObject(themeState)
                    }
                },
                isActive: $showGroupDetail
            ) { EmptyView() }
            .hidden()
        )

        .onAppear {
            GroupStore.shared.loadJoinedGroups(completion: nil)
            joinedGroupIDs = Set(GroupStore.shared.state.value.joinedGroupList.map { $0.groupID })
        }
        .onReceive(GroupStore.shared.state.subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))) { list in
            joinedGroupIDs = Set(list.map { $0.groupID })
        }
    }

    private func isJoinedGroup(_ group: GroupInfo) -> Bool {
        return joinedGroupIDs.contains(group.groupID)
    }

    private func searchGroup() {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        hasSearched = true
        foundGroup = nil
        isSearching = true
        GroupStore.shared.getGroupInfo(
            groupID: keyword,
            completion: GroupInfoLookupHandler(
                onSuccess: { groupInfo in
                    GroupStore.shared.loadJoinedGroups { _ in
                        DispatchQueue.main.async {
                            self.foundGroup = groupInfo
                            self.isSearching = false
                        }
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.foundGroup = nil
                        self.isSearching = false
                    }
                }
            )
        )
    }
}


struct JoinGroupDetailViewImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var wording: String = String(format: LocalizedChatString("ContactListAddWordingIAm"), selfDisplayName())
    @State private var isSending = false
    let groupInfo: GroupInfo
    let dismissAll: () -> Void

    init(groupInfo: GroupInfo, dismissAll: @escaping () -> Void) {
        self.groupInfo = groupInfo
        self.dismissAll = dismissAll
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactFlowNavigationBar(title: LocalizedChatString("GroupDetailTitle")) {
                presentationMode.wrappedValue.dismiss()
            }
            ScrollView {
                VStack(spacing: 0) {
                    let name = ContactDisplayName.name(for: groupInfo)
                    HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                        AvatarView(url: groupInfo.avatarURL, name: name, size: .l, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(themeState.fonts.caption1Bold)
                                .foregroundColor(themeState.colors.textColorPrimary)
                                .lineLimit(1)
                            Text(String(format: LocalizedChatString("ContactLabelValueFormat"), LocalizedChatString("GroupID"), groupInfo.groupID))
                                .font(FontScheme.caption3Regular)
                                .foregroundColor(themeState.colors.textColorSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                    .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                    .background(themeState.colors.bgColorOperate)

                    Text(LocalizedChatString("FillVerificationInfo"))
                        .font(themeState.fonts.caption2Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                        .padding(.top, CGFloat(SpacingScheme.bubbleSpacing))
                        .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))

                    TextEditor(text: $wording)
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(minHeight: 120 - 28)
                        .padding(CGFloat(SpacingScheme.bubbleSpacing))
                        .background(themeState.colors.bgColorOperate)
                        .onAppear { UITextView.appearance().backgroundColor = .clear }

                    themeState.colors.bgColorDefault.frame(height: CGFloat(SpacingScheme.smallSpacing))

                    Button(action: send) {
                        Text(LocalizedChatString(isSending ? "Joining" : "Send"))
                            .font(themeState.fonts.caption1Regular)
                            .foregroundColor(themeState.colors.textColorLink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(themeState.colors.bgColorOperate)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSending)
                }
            }
            .scrollDismissesKeyboardCompat()
        }
        .background(themeState.colors.bgColorDefault.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func send() {
        guard !isSending else { return }
        contactFlowHideKeyboard()
        if GroupStore.shared.state.value.joinedGroupList.contains(where: { $0.groupID == groupInfo.groupID }) {
            WindowToastManager.shared.show(LocalizedChatString("AlreadyGroupMember"), type: .error, duration: 2)
            return
        }
        isSending = true
        GroupStore.shared.joinGroup(groupID: groupInfo.groupID, message: wording) { result in
            DispatchQueue.main.async {
                self.isSending = false
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("GroupJoinRequestSent"), type: .success, duration: 2)
                    self.dismissAll()
                case .failure(let error):
                    let text: String
                    switch error.code {
                    case 10013: text = LocalizedChatString("AlreadyGroupMember")
                    case 10010: text = LocalizedChatString("GroupNotFound")
                    case 10015: text = LocalizedChatString("GroupJoinRequestAlreadySent")
                    case 10016: text = LocalizedChatString("GroupJoinForbidden")
                    default: text = LocalizedChatString("GroupJoinRequestFailed")
                    }
                    WindowToastManager.shared.show(text, type: .error, duration: 2)
                }
            }
        }
    }
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
