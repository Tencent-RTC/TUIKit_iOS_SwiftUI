import SwiftUI

public struct UserPickerItem: Identifiable {
    public var id: String { userID }
    public let userID: String
    public let avatarURL: String?
    public let title: String
    public let subtitle: String?
    public let isDisabled: Bool
    public init(
        userID: String,
        avatarURL: String? = nil,
        title: String,
        subtitle: String? = nil,
        isDisabled: Bool = false
    ) {
        self.userID = userID
        self.avatarURL = avatarURL
        self.title = title
        self.subtitle = subtitle
        self.isDisabled = isDisabled
    }
}

public struct UserPicker: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var selectedUsers: Set<String> = []
    @State private var selectedUsersOrder: [String] = []
    let userList: [UserPickerItem]
    let defaultSelectedItems: Set<String>
    let maxCount: Int
    let onMaxCountExceed: (([UserPickerItem]) -> Void)?
    let onSelectedChanged: (([UserPickerItem]) -> Void)?
    let onReachEnd: (() -> Void)?

    public init(
        userList: [UserPickerItem],
        defaultSelectedItems: Set<String> = [],
        maxCount: Int = 1,
        onMaxCountExceed: (([UserPickerItem]) -> Void)? = nil,
        onSelectedChanged: (([UserPickerItem]) -> Void)?,
        onReachEnd: (() -> Void)? = nil
    ) {
        self.userList = userList
        self.defaultSelectedItems = defaultSelectedItems
        self.maxCount = maxCount
        self.onMaxCountExceed = onMaxCountExceed
        self.onSelectedChanged = onSelectedChanged
        self.onReachEnd = onReachEnd
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !selectedUsersList.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text(LocalizedChatString("Chosen") + "\(selectedUsersList.count) " + LocalizedChatString("People"))
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedUsersList, id: \.userID) { user in
                                VStack(spacing: 4) {
                                    Avatar(
                                        url: user.avatarURL,
                                        name: user.title,
                                        size: .l
                                    )
                                    Text(user.title)
                                        .font(.caption)
                                        .foregroundColor(themeState.colors.textColorPrimary)
                                        .lineLimit(1)
                                        .frame(width: 50)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                }
                .background(themeState.colors.bgColorOperate.opacity(0.05))
                Divider()
            }
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(userList, id: \.userID) { user in
                        UserPickerRow(
                            user: user,
                            isSelected: selectedUsers.contains(user.userID) || defaultSelectedItems.contains(user.userID),
                            isPreSelected: defaultSelectedItems.contains(user.userID),
                            onToggle: { isSelected in
                                if defaultSelectedItems.contains(user.userID) {
                                    return
                                }
                                if maxCount == 1 {
                                    if isSelected {
                                        selectedUsers = [user.userID]
                                        selectedUsersOrder = [user.userID]
                                    } else {
                                        selectedUsers.removeAll()
                                        selectedUsersOrder.removeAll()
                                    }
                                } else {
                                    if isSelected {
                                        selectedUsers.insert(user.userID)
                                        selectedUsersOrder.append(user.userID)
                                    } else {
                                        selectedUsers.remove(user.userID)
                                        selectedUsersOrder.removeAll { $0 == user.userID }
                                    }
                                }
                            }
                        )
                    }
                }
            }
            Spacer()
        }
        .navigationBarTitle(LocalizedChatString("ChooseUser"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(LocalizedChatString("Cancel")) {
                presentationMode.wrappedValue.dismiss()
            },
            trailing: Button(LocalizedChatString("Done")) {
                onSelectedChanged?(selectedUsersList)
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(selectedUsersList.isEmpty)
        )
    }

    private var selectedUsersList: [UserPickerItem] {
        var orderedUsers: [UserPickerItem] = []
        for userID in selectedUsersOrder {
            if let user = userList.first(where: { $0.userID == userID }) {
                orderedUsers.append(user)
            }
        }
        return orderedUsers
    }
}

struct UserPickerRow: View {
    @EnvironmentObject var themeState: ThemeState
    let user: UserPickerItem
    let isSelected: Bool
    let isPreSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(
                        (user.isDisabled || isPreSelected) ? themeState.colors.textColorTertiary : (isSelected ? themeState.colors.textColorLink : themeState.colors.textColorTertiary)
                    )
                Avatar(
                    url: user.avatarURL,
                    name: user.title
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.title)
                        .font(.body)
                        .foregroundColor(user.isDisabled || isPreSelected ? themeState.colors.textColorSecondary : themeState.colors.textColorPrimary)
                    if let subtitle = user.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
//                    if isPreSelected {
//                            .font(.caption)
//                            .foregroundColor(.orange)
//                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(user.isDisabled || isPreSelected)
    }
}
