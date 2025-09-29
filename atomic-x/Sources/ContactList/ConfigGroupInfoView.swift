import AtomicXCore
import SwiftUI

public struct ConfigGroupInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var members: [UserPickerItem]
    @State private var groupName: String = ""
    @State private var groupID: String = ""
    @State private var groupType: GroupType = .Work
    @State private var selectedAvatar: String? = nil
    @State private var isViewAppeared = false
    @State private var showGroupTypeSelector = false
    @State private var groupList: [ContactInfo] = []
    let contactListStore: ContactListStore
    let onComplete: (String?, String?, String?) -> Void
    let onBack: () -> Void

    private var avatarList: [String] {
        (1 ... 10).map { "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\($0).png" }
    }

    public init(members: [UserPickerItem], contactListStore: ContactListStore, onComplete: @escaping (String?, String?, String?) -> Void, onBack: @escaping () -> Void) {
        self._members = State(initialValue: members)
        self.contactListStore = contactListStore
        self.onComplete = onComplete
        self.onBack = onBack
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    groupNameSection
                    groupIDSection
                    groupTypeSection
                    groupTypeDescription
                    avatarGridSection
                    membersSection
                }
                .padding(16)
            }
            .background(themeState.colors.bgColorOperate.ignoresSafeArea())
            .navigationBarTitle(LocalizedChatString("ChatsNewGroupText"), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    onBack()
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(LocalizedChatString("CreateFinish")) {
                    createGroup()
                }
                .disabled(groupName.isEmpty || members.isEmpty)
            )
            .onAppear {
                if !isViewAppeared {
                    setupInitialData()
                    isViewAppeared = true
                }
            }
            .onReceive(contactListStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.groupList))) { groupList in
                self.groupList = groupList
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showGroupTypeSelector) {
            ChooseGroupTypeView(
                selectedGroupType: $groupType,
                onDismiss: {
                    showGroupTypeSelector = false
                }
            )
        }
    }

    private func setupInitialData() {
        let defaultName = members.map { $0.title }.joined(separator: "、")
        groupName = String(defaultName.prefix(10))
    }

    private func removeMember(_ member: UserPickerItem) {
        members.removeAll { $0.id == member.id }
        if !members.isEmpty {
            let defaultName = members.map { $0.title }.joined(separator: "、")
            groupName = String(defaultName.prefix(10))
        }
    }

    private func createGroup() {
        if !groupID.isEmpty {
            let isCommunity = groupType == .Community
            let hasCorrectPrefix = groupID.hasPrefix("@TGS#_")
            let hasCorrectPrefixWithoutUnderline = groupID.hasPrefix("@TGS#")

            if isCommunity && !hasCorrectPrefix {
                WindowToastManager.shared.show(LocalizedChatString("TUICommunityCreateTipsMessageRuleError"), type: .error, duration: 3)
                return
            } else if !isCommunity && hasCorrectPrefixWithoutUnderline {
                WindowToastManager.shared.show(LocalizedChatString("TUIGroupCreateTipsMessageRuleError"), type: .error, duration: 3)
                return
            }
        }

        let memberList = members.map { user in
            var contact = ContactInfo(identifier: user.userID)
            contact.avatarURL = user.avatarURL
            contact.title = user.title
            return contact
        }
        contactListStore.createGroup(
            groupType: groupType.rawValue,
            groupName: groupName,
            groupID: groupID.isEmpty ? nil : groupID,
            avatarURL: selectedAvatar,
            memberList: memberList,
            completion: { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        let createdGroupID = self.contactListStore.state.value.createdGroupID
                        let conversationId = createdGroupID != nil ? "group_\(createdGroupID!)" : nil
                        self.onComplete(createdGroupID, self.groupName, conversationId)
                        self.presentationMode.wrappedValue.dismiss()
                        self.sendGroupCreateTipsMessage(groupID: createdGroupID ?? "", groupType: groupType.rawValue)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.onComplete(nil, nil, nil)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        )
    }

    private func sendGroupCreateTipsMessage(groupID: String, groupType: String) {
        if !groupID.isEmpty {
            sendTipsMessageToGroup(groupID: groupID, groupType: groupType)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.findAndSendTipsMessage(groupType: groupType)
        }
    }

    private func sendTipsMessageToGroup(groupID: String, groupType: String) {
        let showName = LoginStore.shared.state.value.loginUserInfo?.userID ?? "用户"

        var content = LocalizedChatString("TUIGroupCreateTipsMessage")
        if groupType == "Community" {
            content = LocalizedChatString("TUICommunityCreateTipsMessage")
        }
        let dic: [String: Any] = [
            "version": 1,
            "businessID": "group_create",
            "opUser": showName,
            "content": content,
            "cmd": groupType == "Community" ? 1 : 0
        ]
        var message = MessageInfo()
        var messageBody = MessageBody()
        var customMessage = CustomMessageInfo()
        customMessage.data = ChatUtil.dictionary2JsonData(dic)
        messageBody.customMessage = customMessage
        message.messageBody = messageBody
        message.messageType = .custom
        let messageInputState = MessageInputStore.create(conversationID: "group_\(groupID)")
        messageInputState.sendMessage(message, completion: nil)
    }

    private func findAndSendTipsMessage(groupType: String) {
        contactListStore.fetchJoinedGroupList(completion: { result in
            switch result {
            case .success:
                if let createdGroup = self.groupList.first(where: { $0.title == self.groupName }) {
                    self.sendTipsMessageToGroup(groupID: createdGroup.contactID, groupType: groupType)
                }
            case .failure(let error):
                break
            }
        })
    }

    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(LocalizedChatString("CreatGroupNamed_Placeholder"), text: $groupName)
                .padding(12)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(8)
        }
    }

    private var groupIDSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(LocalizedChatString("CreatGroupID_Placeholder"), text: $groupID)
                .padding(12)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(8)
        }
    }

    private var groupTypeSection: some View {
        Button(action: {
            showGroupTypeSelector = true
        }) {
            HStack {
                Text(LocalizedChatString("CreatGroupType"))
                    .font(.system(size: 16))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(groupType.displayName)
                    .font(.system(size: 16))
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: "chevron.right")
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(themeState.colors.bgColorOperate)
            .cornerRadius(8)
        }
    }

    private var groupTypeDescription: some View {
        Text(groupType.description)
            .font(.system(size: 13))
            .foregroundColor(themeState.colors.textColorSecondary)
            .padding(.horizontal, 2)
    }

    private var avatarGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedChatString("CreatGroupAvatar"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeState.colors.textColorSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(avatarList, id: \.self) { url in
                    Button(action: { selectedAvatar = url }) {
                        ZStack {
                            Avatar(url: url, name: nil, size: .l)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(selectedAvatar == url ? themeState.colors.textColorLink : themeState.colors.clearColor, lineWidth: 3)
                                )
                            if selectedAvatar == url {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(themeState.colors.textColorLink)
                                    .background(Circle().fill(themeState.colors.bgColorOperate))
                                    .offset(x: 16, y: -16)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 2 * 48 + 10)
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(LocalizedChatString("CreateMemebers"))(\(members.count))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeState.colors.textColorSecondary)
            if members.isEmpty {
                Text(LocalizedChatString("NoSelectedMembers"))
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(members) { user in
                            VStack(spacing: 4) {
                                ZStack {
                                    Avatar(url: user.avatarURL, name: user.title)
                                    Button(action: {
                                        removeMember(user)
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(themeState.colors.textColorPrimary)
                                                .frame(width: 14, height: 14)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(themeState.colors.strokeColorPrimary)
                                        }
                                    }
                                    .offset(x: 14, y: -14)
                                }
                                Text(user.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(themeState.colors.textColorPrimary)
                                    .lineLimit(1)
                                    .frame(width: 48)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private enum GroupType: String, CaseIterable, Identifiable {
    case Work
    case Public
    case Meeting
    case Community
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .Work: return LocalizedChatString("CreatGroupType_Work")
        case .Public: return LocalizedChatString("CreatGroupType_Public")
        case .Meeting: return LocalizedChatString("CreatGroupType_Meeting")
        case .Community: return LocalizedChatString("CreatGroupType_Community")
        }
    }

    var description: String {
        switch self {
        case .Work:
            return LocalizedChatString("CreatGroupType_Work_Desc")
        case .Public:
            return LocalizedChatString("CreatGroupType_Public_Desc")
        case .Meeting:
            return LocalizedChatString("CreatGroupType_Meeting_Desc")
        case .Community:
            return LocalizedChatString("CreatGroupType_Community_Desc")
        }
    }
}

private struct UserInfo: Identifiable {
    let id: String
    let avatarURL: String?
    let title: String?
}

private struct ChooseGroupTypeView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @Binding var selectedGroupType: GroupType
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(GroupType.allCases) { groupType in
                            GroupTypeOptionView(
                                groupType: groupType,
                                isSelected: selectedGroupType == groupType,
                                onTap: {
                                    selectedGroupType = groupType
                                    presentationMode.wrappedValue.dismiss()
                                    onDismiss()
                                }
                            )
                        }
                        Button(action: {}) {
                            Text(LocalizedChatString("CreatGroupType_See_Doc_Simple"))
                                .font(.system(size: 16))
                                .foregroundColor(themeState.colors.textColorLink)
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
                Spacer()
            }
            .background(themeState.colors.bgColorOperate.ignoresSafeArea())
            .navigationBarTitle(LocalizedChatString("CreatGroupType"), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct GroupTypeOptionView: View {
    @EnvironmentObject var themeState: ThemeState
    let groupType: GroupType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? themeState.colors.textColorLink : themeState.colors.clearColor)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(themeState.colors.bgColorOperate)
                        } else {
                            Circle()
                                .stroke(themeState.colors.strokeColorPrimary, lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                        }
                    }
                    Text(groupType.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                Text(groupType.description)
                    .font(.system(size: 12))
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            .padding(16)
            .background(themeState.colors.bgColorOperate)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? themeState.colors.textColorLink : themeState.colors.strokeColorPrimary,
                        lineWidth: 1
                    )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
