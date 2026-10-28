import AtomicXCore
import Combine
import SwiftUI

internal struct FriendApplicationListView: View {
    private let implementation: FriendApplicationListViewImpl

    internal init(onDismiss: (() -> Void)? = nil) {
        implementation = FriendApplicationListViewImpl(
            onDismiss: onDismiss
        )
    }

    internal var body: some View { implementation }
}
