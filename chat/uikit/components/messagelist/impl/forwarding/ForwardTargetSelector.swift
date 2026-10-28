import AtomicXCore
import SwiftUI

struct ForwardTargetSelector: View {
    @EnvironmentObject var themeState: ThemeState
    private let conversationStore = ConversationListStore.create()
    private let contactStore = ContactStore.shared
    @State private var conversationList: [ConversationInfo] = []
    @State private var friendList: [ContactInfo] = []
    @State private var selectedConversationIDs: [String] = []
    @State private var showContactPicker = false
    @State private var pickerSelection: [UserPickerItem] = []
    @Environment(\.presentationMode) var presentationMode

    private static let c2cIDPrefix = "c2c_"
    private static let conversationRowHeight: CGFloat = 60
    private static let contactEntryHeight: CGFloat = 56
    private static let pickerTopBarHeight: CGFloat = 56
    private static let contentHorizontalInset = CGFloat(SpacingScheme.bubbleSpacing)
    private static let checkboxSize: CGFloat = 22
    private static let avatarSize: CGFloat = 40
    private static let horizontalSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let bottomAvatarSize: CGFloat = 32
    private static let bottomAvatarCornerRadius = CGFloat(RadiusScheme.largeRadius)
    private static let bottomAvatarSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let bottomHorizontalInset = CGFloat(SpacingScheme.iconIconSpacing)
    private static let bottomVerticalInset = CGFloat(SpacingScheme.iconIconSpacing)
    private static let confirmCornerRadius = CGFloat(RadiusScheme.smallRadius)

    let onConfirm: ([String]) -> Void
    let onDismiss: () -> Void

    var body: some View {
        Group {
            VStack(spacing: 0) {
                contactEntryView
                sectionBand
                conversationListView
                bottomBar
            }
            .background(themeState.colors.bgColorOperate)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(LocalizedChatString("Forward"))
                        .font(themeState.fonts.caption1Bold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedChatString("Cancel")) {
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorLink)
                }
            }
        }
        .fullScreenCover(isPresented: $showContactPicker) {
            contactPickerPage
        }
        .onAppear {
            loadConversations()
            loadFriends()
        }
    }

    private var contactPickerPage: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(LocalizedChatString("RelayTargetSelectFromContacts"))
                    .font(themeState.fonts.caption1Bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                HStack {
                    Button(LocalizedChatString("Cancel")) {
                        showContactPicker = false
                    }
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorLink)
                    Spacer()
                    Button(LocalizedChatString("Confirm")) {
                        applyContactPickerResult(pickerSelection)
                        showContactPicker = false
                    }
                    .font(FontScheme.caption1Medium)
                    .foregroundColor(themeState.colors.textColorLink)
                }
                .padding(.horizontal, Self.contentHorizontalInset)
            }
            .frame(height: Self.pickerTopBarHeight)
            .background(themeState.colors.bgColorOperate)
            UserPickerView(
                userList: friendList.map { contact in
                    UserPickerItem(
                        userID: contact.userID,
                        avatarURL: contact.avatarURL,
                        title: contactTitle(contact)
                    )
                },
                initialSelectedItems: selectedContactUserIDs,
                showsChosenUsersHeader: false,
                maxCount: .max,
                onSelectedChanged: nil,
                onLiveSelectionChanged: { newItems in
                    pickerSelection = newItems
                }
            )
            .environmentObject(themeState)
        }
        .background(themeState.colors.bgColorOperate)
    }

    private var contactEntryView: some View {
        Button(action: {
            if !friendList.isEmpty {
                pickerSelection = friendList
                    .filter { selectedContactUserIDs.contains($0.userID) }
                    .map { UserPickerItem(userID: $0.userID, avatarURL: $0.avatarURL, title: contactTitle($0)) }
                showContactPicker = true
            }
        }) {
            HStack {
                Text(LocalizedChatString("RelayTargetSelectFromContacts"))
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, Self.contentHorizontalInset)
            .frame(height: Self.contactEntryHeight)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var sectionBand: some View {
        Text(LocalizedChatString("RelayRecentMessages"))
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.contentHorizontalInset)
            .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
            .background(themeState.colors.bgColorInput)
    }

    private var conversationListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(conversationList) { conversation in
                    conversationRow(conversation)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleConversationSelection(conversation)
                        }
                        .onAppear {
                            if conversation.conversationID == conversationList.last?.conversationID {
                                conversationStore.loadMoreConversations(completion: nil)
                            }
                        }
                }
            }
        }
        .background(themeState.colors.bgColorOperate)
    }

    private func conversationRow(_ conversation: ConversationInfo) -> some View {
        let isSelected = selectedConversationIDs.contains(conversation.conversationID)
        let title = (conversation.title?.isEmpty == false) ? conversation.title! : conversation.conversationID
        return HStack(spacing: 0) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(FontScheme.body3Regular)
                .foregroundColor(isSelected ? themeState.colors.textColorLink : themeState.colors.textColorTertiary)
                .frame(width: Self.checkboxSize, height: Self.checkboxSize)
                .padding(.trailing, Self.horizontalSpacing)
            AvatarView(url: conversation.avatarURL ?? "", name: title, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.superLargeRadius))
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .padding(.trailing, Self.horizontalSpacing)
            Text(title)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .frame(height: Self.conversationRowHeight)
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorOperate)
    }

    private var bottomBar: some View {
        HStack(spacing: Self.bottomHorizontalInset) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.bottomAvatarSpacing) {
                    ForEach(selectedBottomItems, id: \.key) { item in
                        AvatarView(url: item.avatarURL, name: item.fallbackName, size: .s, shape: .roundedRectangle, cornerRadius: Self.bottomAvatarCornerRadius)
                            .frame(width: Self.bottomAvatarSize, height: Self.bottomAvatarSize)
                    }
                }
            }
            .frame(height: Self.bottomAvatarSize)

            Button(action: {
                guard !selectedConversationIDs.isEmpty else { return }
                onConfirm(selectedConversationIDs)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LocalizedChatString("Forward") + (selectedConversationIDs.isEmpty ? "" : "(\(selectedConversationIDs.count))"))
                    .font(themeState.fonts.caption2Bold)
                    .foregroundColor(selectedConversationIDs.isEmpty ? themeState.colors.textColorTertiary : themeState.colors.textColorButton)
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                    .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
                    .background(selectedConversationIDs.isEmpty ? themeState.colors.buttonColorPrimaryDisabled : themeState.colors.buttonColorPrimaryDefault)
                    .cornerRadius(Self.confirmCornerRadius)
            }
            .disabled(selectedConversationIDs.isEmpty)
        }
        .padding(.horizontal, Self.bottomHorizontalInset)
        .padding(.vertical, Self.bottomVerticalInset)
        .background(themeState.colors.bgColorOperate)
    }

    private struct BottomItem {
        let key: String
        let avatarURL: String
        let fallbackName: String
    }

    private var selectedBottomItems: [BottomItem] {
        selectedConversationIDs.map { id in
            if let conversation = conversationList.first(where: { $0.conversationID == id }) {
                return BottomItem(key: id, avatarURL: conversation.avatarURL ?? "", fallbackName: conversation.title ?? conversation.conversationID)
            }
            let userID = id.hasPrefix(Self.c2cIDPrefix) ? String(id.dropFirst(Self.c2cIDPrefix.count)) : id
            if let contact = friendList.first(where: { $0.userID == userID }) {
                return BottomItem(key: id, avatarURL: contact.avatarURL ?? "", fallbackName: contact.nickname ?? contact.userID)
            }
            return BottomItem(key: id, avatarURL: "", fallbackName: userID)
        }
    }

    private var selectedContactUserIDs: Set<String> {
        var ids = Set<String>()
        for id in selectedConversationIDs where id.hasPrefix(Self.c2cIDPrefix) {
            let userID = String(id.dropFirst(Self.c2cIDPrefix.count))
            if friendList.contains(where: { $0.userID == userID }) {
                ids.insert(userID)
            }
        }
        return ids
    }

    private func contactTitle(_ contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }

    private func toggleConversationSelection(_ conversation: ConversationInfo) {
        if let idx = selectedConversationIDs.firstIndex(of: conversation.conversationID) {
            selectedConversationIDs.remove(at: idx)
        } else {
            selectedConversationIDs.append(conversation.conversationID)
        }
    }

    private func applyContactPickerResult(_ newItems: [UserPickerItem]) {
        let preSelected = selectedContactUserIDs
        let returnedUserIDs = Set(newItems.map { $0.userID })
        selectedConversationIDs.removeAll { id in
            id.hasPrefix(Self.c2cIDPrefix) && preSelected.contains(String(id.dropFirst(Self.c2cIDPrefix.count))) && !returnedUserIDs.contains(String(id.dropFirst(Self.c2cIDPrefix.count)))
        }
        for item in newItems {
            let c2cID = Self.c2cIDPrefix + item.userID
            if !selectedConversationIDs.contains(c2cID) {
                selectedConversationIDs.append(c2cID)
            }
        }
    }

    private func loadConversations() {
        let option = ConversationLoadOption()
        conversationStore.loadConversations(option: option) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.conversationList = self.conversationStore.state.value.conversationList
                }
            case .failure(let error):
                print("ForwardTargetSelector: Failed to load conversations: \(error.code), \(error.message)")
            }
        }
    }

    private func loadFriends() {
        contactStore.loadFriends(completion: { [weak contactStore] _ in
            DispatchQueue.main.async {
                self.friendList = contactStore?.state.value.friendList ?? []
            }
        })
    }
}
