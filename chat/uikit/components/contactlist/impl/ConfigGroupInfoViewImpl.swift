import AtomicXCore
import SwiftUI

// 等待聊天页注册消息监听后再发送建群提示，避免首条通知丢失。
private let groupCreateTipsMessageDelay: TimeInterval = 0.5

struct ConfigGroupInfoViewImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var members: [UserPickerItem]
    @State private var groupName: String = ""
    @State private var groupID: String = ""
    @State private var groupType: GroupTypeSelection = .work
    @State private var selectedAvatar: String? = nil
    @State private var isViewAppeared = false
    @State private var pushGroupTypeSelector = false
    @FocusState private var focusedField: Field?
    let onComplete: (String?, String?, String?) -> Void
    let onBack: () -> Void

    private enum Field { case name, id }

    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let rowHeight: CGFloat = 48
    private static let dividerHeight: CGFloat = 0.5
    private static let sectionTitleTopPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let sectionTitleBottomPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let sectionBottomPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let descTopPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let avatarItemSize: CGFloat = 48
    private static let avatarItemSpacing = CGFloat(SpacingScheme.contentSpacing)
    private static let memberAvatarSize: CGFloat = 40
    private static let memberAvatarSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let createButtonWidth: CGFloat = 76
    private static let createButtonHeight: CGFloat = 30
    private static let createButtonCornerRadius = CGFloat(RadiusScheme.tipsRadius)
    private static let bottomBarTopPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let bottomBarBottomPadding = CGFloat(SpacingScheme.contentSpacing)
    private static let toastBottomOffset: CGFloat = 200
    private static let groupNamePreviewCount = 3
    private static let presetAvatarCount = 24
    private static let createErrorToastDuration: TimeInterval = 3
    private static let validationErrorToastDuration: TimeInterval = 2

    private var avatarURLList: [String] {
        (1 ... Self.presetAvatarCount).map { "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\($0).png" }
    }

    init(members: [UserPickerItem], onComplete: @escaping (String?, String?, String?) -> Void, onBack: @escaping () -> Void) {
        self._members = State(initialValue: members)
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    editableRow(title: LocalizedChatString("ConfigGroupNameLabel"), text: $groupName, hint: "", field: .name)
                    divider
                    editableRow(title: LocalizedChatString("ConfigGroupIDLabel"), text: $groupID, hint: LocalizedChatString("ConfigGroupIDOptionalHint"), field: .id)
                    divider
                    groupTypeRow
                    groupTypeDescription
                    avatarSection
                    membersSection
                }
            }
            .background(themeState.colors.bgColorOperate)
            .scrollDismissesKeyboardCompat()
            .onTapGesture { focusedField = nil }

            bottomBar
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .navigationBarTitle(LocalizedChatString("CreateGroupTitle"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            if !isViewAppeared {
                setupInitialData()
                isViewAppeared = true
            }
        }
        .background(
            NavigationLink(
                destination: ChooseGroupTypeView(selectedGroupType: $groupType, onDismiss: {
                    pushGroupTypeSelector = false
                })
                .environmentObject(themeState),
                isActive: $pushGroupTypeSelector
            ) { EmptyView() }
            .hidden()
        )
    }

    private var backButton: some View {
        NavBackButtonView {
            onBack()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: Self.dividerHeight)
    }

    private func editableRow(title: String, text: Binding<String>, hint: String, field: Field) -> some View {
        HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
            Text(title)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
            TextField("", text: text)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: text.wrappedValue.isEmpty, hint: hint, color: themeState.colors.textColorSecondary)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _ in
                    if field == .name {   }
                }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(height: Self.rowHeight)
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorTopBar)
    }

    private var groupTypeRow: some View {
        Button(action: { pushGroupTypeSelector = true }) {
            HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                Text(LocalizedChatString("CreatGroupType"))
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer(minLength: 0)
                Text(groupType.displayName)
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("›")
                    .font(themeState.fonts.body3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.rowHeight)
            .frame(maxWidth: .infinity)
            .background(themeState.colors.bgColorTopBar)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var groupTypeDescription: some View {
        Text(groupType.typeDescription)
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .lineSpacing(2.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.top, Self.descTopPadding)
    }

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedChatString("CreatGroupAvatar"))
                .font(FontScheme.caption1Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.top, Self.sectionTitleTopPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                let candidates: [String?] = [nil] + avatarURLList.map { Optional($0) }
                LazyHGrid(rows: [GridItem(.fixed(Self.avatarItemSize), spacing: Self.avatarItemSpacing), GridItem(.fixed(Self.avatarItemSize))], spacing: Self.avatarItemSpacing) {
                    ForEach(Array(candidates.enumerated()), id: \.offset) { _, url in
                        groupAvatarItem(url)
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
            }
            .frame(height: Self.avatarItemSize * 2 + Self.avatarItemSpacing)
            .padding(.top, Self.sectionTitleBottomPadding)
            .padding(.bottom, Self.sectionBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorTopBar)
    }

    private func groupAvatarItem(_ url: String?) -> some View {
        let fallback = groupName.isEmpty ? LocalizedChatString("ConfigGroupNameLabel") : groupName
        let isSelected = selectedAvatar == url
        return Button(action: { selectedAvatar = url }) {
            AvatarView(url: url ?? "", name: fallback, size: .l, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.smallRadius))
                .frame(width: Self.avatarItemSize, height: Self.avatarItemSize)
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.smallRadius))
                        .strokeBorder(isSelected ? themeState.colors.textColorLink : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedChatString("CreateMemebers"))
                .font(FontScheme.caption1Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.top, Self.sectionTitleTopPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.memberAvatarSpacing) {
                    ForEach(members) { member in
                        AvatarView(url: member.avatarURL ?? "", name: member.title, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                            .frame(width: Self.memberAvatarSize, height: Self.memberAvatarSize)
                    }
                }
                .padding(.horizontal, Self.horizontalPadding)
            }
            .frame(height: Self.memberAvatarSize)
            .padding(.top, Self.sectionTitleBottomPadding)
            .padding(.bottom, Self.sectionBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorTopBar)
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            Button(action: handleCreate) {
                Text(LocalizedChatString("CreateFinish"))
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorButton)
                    .frame(width: Self.createButtonWidth, height: Self.createButtonHeight)
                    .background(createEnabled ? themeState.colors.textColorLink : themeState.colors.textColorDisable)
                    .cornerRadius(Self.createButtonCornerRadius)
            }
            .disabled(!createEnabled)
            .padding(.trailing, Self.horizontalPadding)
        }
        .padding(.top, Self.bottomBarTopPadding)
        .padding(.bottom, Self.bottomBarBottomPadding)
        .background(themeState.colors.bgColorOperate)
    }

    private var createEnabled: Bool {
        !groupName.isEmpty && !members.isEmpty
    }

    private func setupInitialData() {
        groupName = Self.makeDefaultGroupName(from: members)
    }

    private static func makeDefaultGroupName(from members: [UserPickerItem]) -> String {
        let names = members.map { $0.title.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let preview = names.prefix(Self.groupNamePreviewCount).joined(separator: LocalizedChatString("ConfigGroupNameSeparator"))
        let remaining = names.count - Self.groupNamePreviewCount
        if remaining > 0 {
            return preview + String(format: LocalizedChatString("ConfigGroupNameSuffix"), remaining)
        }
        return preview
    }

    private func handleCreate() {
        guard validateGroupID(groupID) else { return }

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
                        self.handleCreateSuccess(createdGroupID)
                    }
                },
                onFailure: { code, _ in
                    DispatchQueue.main.async {
                        WindowToastManager.shared.show(Self.createGroupErrorText(code: code), type: .error, duration: Self.createErrorToastDuration)
                    }
                }
            )
        )
    }

    private func validateGroupID(_ groupID: String) -> Bool {
        guard !groupID.isEmpty else { return true }
        let isCommunity = groupType == .community
        let hasCommunityPrefix = groupID.hasPrefix("@TGS#_")
        let hasGroupPrefix = groupID.hasPrefix("@TGS#")
        if isCommunity && !hasCommunityPrefix {
            WindowToastManager.shared.show(LocalizedChatString("TUICommunityCreateTipsMessageRuleError"), type: .error, duration: Self.validationErrorToastDuration)
            return false
        }
        if !isCommunity && hasGroupPrefix {
            WindowToastManager.shared.show(LocalizedChatString("TUIGroupCreateTipsMessageRuleError"), type: .error, duration: Self.validationErrorToastDuration)
            return false
        }
        return true
    }

    private static func createGroupErrorText(code: Int) -> String {
        switch code {
        case 10021, 10025:
            return LocalizedChatString("GroupCreateErrorGroupIDUsed")
        default:
            return LocalizedChatString("GroupCreateFailed")
        }
    }

    private func handleCreateSuccess(_ createdGroupID: String) {
        let conversationId = createdGroupID.isEmpty ? nil : "group_\(createdGroupID)"
        onComplete(createdGroupID.isEmpty ? nil : createdGroupID, groupName.isEmpty ? nil : groupName, conversationId)
        DispatchQueue.main.asyncAfter(deadline: .now() + groupCreateTipsMessageDelay) {
            Self.sendGroupCreateTipsMessage(groupID: createdGroupID, groupType: groupType.rawValue)
        }
    }

    private static func sendGroupCreateTipsMessage(groupID: String, groupType: String) {
        guard !groupID.isEmpty else { return }
        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        let showName = (loginUserInfo?.nickname?.isEmpty == false ? loginUserInfo?.nickname : nil) ?? loginUserInfo?.userID ?? ""
        let isCommunity = groupType == "Community"
        let content = isCommunity
            ? LocalizedChatString("TUICommunityCreateTipsMessage")
            : LocalizedChatString("TUIGroupCreateTipsMessage")
        let dic: [String: Any] = [
            "version": 1,
            "businessID": "group_create",
            "opUser": showName,
            "content": content,
            "cmd": isCommunity ? 1 : 0
        ]
        let customData = ChatUtil.dictionary2JsonData(dic)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let payload = CustomSendMessagePayload(customData: customData)
        let messageInputState = MessageInputStore.create(conversationID: "group_\(groupID)")
        messageInputState.sendMessage(payload: .custom(payload), option: nil, completion: nil)
    }
}


enum GroupTypeSelection: String, CaseIterable, Identifiable {
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

    var typeDescription: String {
        switch self {
        case .work: return LocalizedChatString("CreatGroupType_Work_Desc")
        case .publicGroup: return LocalizedChatString("CreatGroupType_Public_Desc")
        case .meeting: return LocalizedChatString("CreatGroupType_Meeting_Desc")
        case .community: return LocalizedChatString("CreatGroupType_Community_Desc")
        }
    }

    var iconName: String {
        switch self {
        case .work: return "group_type_work"
        case .publicGroup: return "group_type_public"
        case .meeting: return "group_type_meeting"
        case .community: return "group_type_community"
        }
    }

    var coreType: AtomicXCore.GroupType {
        switch self {
        case .work: return .work
        case .publicGroup: return .publicGroup
        case .meeting: return .meeting
        case .community: return .community
        }
    }
}


private struct ChooseGroupTypeView: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var selectedGroupType: GroupTypeSelection
    let onDismiss: () -> Void

    private static let cardSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let containerPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let cardCornerRadius = CGFloat(RadiusScheme.alertRadius)
    private static let cardPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let cardSelectedStrokeWidth: CGFloat = 1.5
    private static let typeIconSize: CGFloat = 40
    private static let typeIconTitleGap = CGFloat(SpacingScheme.smallSpacing)
    private static let descTopMargin = CGFloat(SpacingScheme.smallSpacing)

    var body: some View {
        ScrollView {
            VStack(spacing: Self.cardSpacing) {
                ForEach(GroupTypeSelection.allCases) { type in
                    typeCard(type)
                }
            }
            .padding(.horizontal, Self.containerPadding)
            .padding(.vertical, Self.cardSpacing)
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .navigationBarTitle(LocalizedChatString("ConfigSelectGroupTypeTitle"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: NavBackButtonView {
            onDismiss()
        })
    }

    private func typeCard(_ type: GroupTypeSelection) -> some View {
        let isSelected = type == selectedGroupType
        return Button(action: {
            selectedGroupType = type
            onDismiss()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Self.typeIconTitleGap) {
                    Image(type.iconName, bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.typeIconSize, height: Self.typeIconSize)
                    Text(type.displayName)
                        .font(FontScheme.caption1Medium)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    Spacer(minLength: 0)
                }
                Text(type.typeDescription)
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineSpacing(13 * 1.3 - 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Self.descTopMargin)
            }
            .padding(Self.cardPadding)
            .background(themeState.colors.bgColorOperate)
            .cornerRadius(Self.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                    .stroke(themeState.colors.textColorLink, lineWidth: isSelected ? Self.cardSelectedStrokeWidth : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension View {
    func placeholder(when condition: Bool, hint: String, color: Color, alignment: Alignment = .trailing) -> some View {
        overlay(alignment: alignment) {
            if condition && !hint.isEmpty {
                Text(hint)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(color)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
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
