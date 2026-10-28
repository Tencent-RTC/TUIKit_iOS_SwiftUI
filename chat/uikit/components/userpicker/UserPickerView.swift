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

public struct UserPickerView: View {
    private let implementation: UserPickerImpl

    public init(
        userList: [UserPickerItem],
        defaultSelectedItems: Set<String> = [],
        initialSelectedItems: Set<String> = [],
        showsChosenUsersHeader: Bool = true,
        maxCount: Int = 1,
        navigationTitle: String? = nil,
        confirmTitle: String? = nil,
        dismissOnConfirm: Bool = true,
        onMaxCountExceed: (([UserPickerItem]) -> Void)? = nil,
        onSelectedChanged: (([UserPickerItem]) -> Void)?,
        onLiveSelectionChanged: (([UserPickerItem]) -> Void)? = nil,
        onReachEnd: (() -> Void)? = nil
    ) {
        implementation = UserPickerImpl(
            userList: userList,
            defaultSelectedItems: defaultSelectedItems,
            initialSelectedItems: initialSelectedItems,
            showsChosenUsersHeader: showsChosenUsersHeader,
            maxCount: maxCount,
            navigationTitle: navigationTitle,
            confirmTitle: confirmTitle,
            dismissOnConfirm: dismissOnConfirm,
            onMaxCountExceed: onMaxCountExceed,
            onSelectedChanged: onSelectedChanged,
            onLiveSelectionChanged: onLiveSelectionChanged,
            onReachEnd: onReachEnd
        )
    }

    public var body: some View { implementation }
}
