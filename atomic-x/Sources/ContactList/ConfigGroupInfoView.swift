import AtomicXCore
import SwiftUI

/// Delay before sending the "group created" tip message after a successful
/// `createGroup`. Defers the send until the ChatPage has time to mount its
/// `MessageListStore` and register the `sendBegin` listener; without it the
/// first-entry tip is dropped because the notification fires before the
/// listener exists. Mirrors Android UIKit's `GROUP_CREATE_MESSAGE_DELAY`.
private let groupCreateTipsMessageDelay: TimeInterval = 0.5

public struct ConfigGroupInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var members: [UserPickerItem]
    @State private var groupName: String = ""
    @State private var groupID: String = ""
    @State private var groupType: GroupTypeSelection = .work
    @State private var selectedAvatar: String? = nil
    @State private var isViewAppeared = false
    @State private var showGroupTypeSelector = false
    let onComplete: (String?, String?, String?) -> Void
    let onBack: () -> Void

    private var avatarList: [String] {
        (1 ... 10).map { "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\($0).png" }
    }

    public init(members: [UserPickerItem], onComplete: @escaping (String?, String?, String?) -> Void, onBack: @escaping () -> Void) {
        self._members = State(initialValue: members)
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
                }
                .foregroundColor(themeState.colors.textColorLink),

                trailing: Button(LocalizedChatString("CreateFinish")) {
                    createGroup()
                }
                .foregroundColor(themeState.colors.textColorLink)
                .disabled(groupName.isEmpty || members.isEmpty)
            )
            .onAppear {
                if !isViewAppeared {
                    setupInitialData()
                    isViewAppeared = true
                }
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
            let isCommunity = groupType == .community
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

        var params = GroupCreateParams(groupName: groupName)
        params.groupType = groupType.coreType
        params.groupID = groupID.isEmpty ? nil : groupID
        params.avatarURL = selectedAvatar
        params.memberList = members.map { $0.userID }

        GroupStore.shared.createGroup(
            params: params,
            completion: CreateGroupHandler(
                onSuccess: { createdGroupID in
                    DispatchQueue.main.async {
                        let conversationId = createdGroupID.isEmpty ? nil : "group_\(createdGroupID)"
                        self.onComplete(createdGroupID.isEmpty ? nil : createdGroupID, self.groupName, conversationId)
                        self.presentationMode.wrappedValue.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + groupCreateTipsMessageDelay) {
                            self.sendGroupCreateTipsMessage(groupID: createdGroupID, groupType: groupType.rawValue)
                        }
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.onComplete(nil, nil, nil)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        )
    }

    private func sendGroupCreateTipsMessage(groupID: String, groupType: String) {
        if !groupID.isEmpty {
            sendTipsMessageToGroup(groupID: groupID, groupType: groupType)
            return
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
        let customData = ChatUtil.dictionary2JsonData(dic)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let payload = CustomSendMessagePayload(customData: customData)
        let messageInputState = MessageInputStore.create(conversationID: "group_\(groupID)")
        messageInputState.sendMessage(payload: .custom(payload), option: nil, completion: nil)
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

private enum GroupTypeSelection: String, CaseIterable, Identifiable {
    case work = "Work"
    case publicGroup = "Public"
    case meeting = "Meeting"
    case community = "Community"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return LocalizedChatString("CreatGroupType_Work")
        case .publicGroup: return LocalizedChatString("CreatGroupType_Public")
        case .meeting: return LocalizedChatString("CreatGroupType_Meeting")
        case .community: return LocalizedChatString("CreatGroupType_Community")
        }
    }

    var description: String {
        switch self {
        case .work:
            return LocalizedChatString("CreatGroupType_Work_Desc")
        case .publicGroup:
            return LocalizedChatString("CreatGroupType_Public_Desc")
        case .meeting:
            return LocalizedChatString("CreatGroupType_Meeting_Desc")
        case .community:
            return LocalizedChatString("CreatGroupType_Community_Desc")
        }
    }

    var coreType: AtomicXCore.GroupType {
        switch self {
        case .work:
            return .work
        case .publicGroup:
            return .publicGroup
        case .meeting:
            return .meeting
        case .community:
            return .community
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
    @Binding var selectedGroupType: GroupTypeSelection
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(GroupTypeSelection.allCases) { groupType in
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
    let groupType: GroupTypeSelection
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

private final class CreateGroupHandler: CreateGroupCompletionHandler {
    private let onSuccessBlock: (String) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (String) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(groupID: String) {
        onSuccessBlock(groupID)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
