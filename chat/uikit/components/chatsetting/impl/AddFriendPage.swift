import AtomicXCore
import SwiftUI

internal struct AddFriendPage: View {
    private let implementation: AddFriendPageImpl

    internal init(
        userID: String,
        showsOwnNavigation: Bool = true,
        onSendMessageClick: (() -> Void)? = nil,
        onAddFriendSuccess: (() -> Void)? = nil
    ) {
        implementation = AddFriendPageImpl(
            userID: userID,
            showsOwnNavigation: showsOwnNavigation,
            onSendMessageClick: onSendMessageClick,
            onAddFriendSuccess: onAddFriendSuccess
        )
    }

    internal var body: some View { implementation }
}
