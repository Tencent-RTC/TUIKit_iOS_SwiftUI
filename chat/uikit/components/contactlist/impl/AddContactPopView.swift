import AtomicXCore
import SwiftUI

internal struct AddContactPopView: View {
    private let implementation: AddContactPopViewImpl

    internal init(onDismiss: @escaping () -> Void, onShowAddFriend: @escaping () -> Void, onShowJoinGroup: @escaping () -> Void) {
        implementation = AddContactPopViewImpl(
            onDismiss: onDismiss,
            onShowAddFriend: onShowAddFriend,
            onShowJoinGroup: onShowJoinGroup
        )
    }

    internal var body: some View { implementation }
}
